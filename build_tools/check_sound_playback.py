#!/usr/bin/env python3
from pathlib import Path
import argparse
import configparser
import ctypes as C
import hashlib
import json
import struct
import sys
import wave

import numpy as np

project = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(project / 'build_tools'))
from genesis_test_core import Genesis
from check_music_sequences import current_music

p = argparse.ArgumentParser(description='Play music, effects and 1-up restoration on a Genesis Plus GX libretro core.')
p.add_argument('--core', type=Path, required=True)
p.add_argument('--rom', type=Path, default=project / 's2built.bin')
p.add_argument('--listing', type=Path, default=project / 'md-main.lst')
p.add_argument('--output', type=Path)
p.add_argument('--effects', action='store_true')
p.add_argument('--jingles', action='store_true')
p.add_argument('--priority', action='store_true', help='Check bumper/Continue SFX arbitration and priority release.')
p.add_argument('--switches', action='store_true', help='Trace DPCM continuity while rapidly selecting different songs.')
p.add_argument('--pal', action='store_true')
p.add_argument('--system-directory', type=Path)
p.add_argument('--songs', nargs='*')
p.add_argument('--frames', type=int, default=600)
args = p.parse_args()
source = project
output = args.output or project / '.sound-build' / ('playback-pal' if args.pal else 'playback-ntsc')
output.mkdir(parents=True, exist_ok=True)
g = Genesis(args.core, args.rom, args.listing, output, args.pal,
            system_directory=args.system_directory)

class Geometry(C.Structure):
	_fields_ = [('base_width', C.c_uint), ('base_height', C.c_uint), ('max_width', C.c_uint), ('max_height', C.c_uint), ('aspect_ratio', C.c_float)]
class Timing(C.Structure):
	_fields_ = [('fps', C.c_double), ('sample_rate', C.c_double)]
class AVInfo(C.Structure):
	_fields_ = [('geometry', Geometry), ('timing', Timing)]
av = AVInfo()
g.core.retro_get_system_av_info(C.byref(av))
print('Audio configuration:', av.timing.fps, av.timing.sample_rate, flush=True)

chunks = []
capture = False
def batch(data, frames):
	if capture:
		chunks.append(C.string_at(data, frames * 4))
	return frames
def sample(left, right):
	if capture:
		chunks.append(struct.pack('<hh', left, right))
Batch = C.CFUNCTYPE(C.c_size_t, C.c_void_p, C.c_size_t)
Sample = C.CFUNCTYPE(None, C.c_int16, C.c_int16)
g.callbacks[2] = Sample(sample)
g.callbacks[3] = Batch(batch)
g.core.retro_set_audio_sample(g.callbacks[2])
g.core.retro_set_audio_sample_batch(g.callbacks[3])

def step(count=1):
	for _ in range(count):
		g.run()
		assert not g.read('v_errortype'), ('CPU exception', g.frame, g.read('v_errortype'))

for _ in range(1800):
	step()
	if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
		break
else:
	raise AssertionError('Title did not start')
g.write('f_levselcheat', 1)
g.buttons = {3}
step(2)
g.buttons = set()
step(100)
g.write('v_levselitem', g.s['LevelSelect_SoundItem'], 2)
step(5)
g.video.save(output / 'sound-test.png')
menu = g.save()
ini = configparser.ConfigParser(interpolation=None)
ini.read(source / 'sound/music/music.ini')
rom = args.rom.read_bytes()
streamed = 'Music_Index' in g.s
report = {'region': 'PAL' if args.pal else 'NTSC', 'sample_rate': av.timing.sample_rate, 'emulator': 'Genesis Plus GX', 'rom_sha256': hashlib.sha256(rom).hexdigest(), 'songs': []}

for index, name in enumerate(ini.sections(), 1):
	if args.songs and name not in args.songs:
		continue
	g.restore(menu)
	g.write('v_levselsound', index, 2)
	step(2)
	g.buttons = {0}
	step(2)
	g.buttons = set()
	step(15)
	chunks.clear()
	capture = True
	before = g.read('Vint_runcount', 4)
	step(args.frames)
	after = g.read('Vint_runcount', 4)
	capture = False
	pcm = b''.join(chunks)
	values = np.frombuffer(pcm, dtype='<i2').astype(np.float64)
	assert values.size > av.timing.sample_rate * 2, ('No audio callback output', name)
	assert np.count_nonzero(values) > 1000, ('Silent music', name)
	assert before != after, ('Game stalled', name)
	assert g.read('v_levselitem', 2) == g.s['LevelSelect_SoundItem'], ('Sound test exited', name)
	if streamed:
		bank = None
		flags = rom[g.s['Music_Index'] + (index - 1) * 8 + 6]
	else:
		bank, low, high, flags = rom[g.s['zMasterPlaylist'] + (index - 1) * 4:g.s['zMasterPlaylist'] + index * 4]
	entry = {'id': index, 'name': name, 'title': ini[name]['Title'], 'bank': bank, 'compressed_in_rom': not bool(flags & 0x10), 'frames': args.frames, 'pcm_sha256': hashlib.sha256(pcm).hexdigest(), 'sample_frames': len(pcm) // 4, 'rms': float(np.sqrt(np.mean(values * values))), 'peak': int(np.max(np.abs(values))), 'nonzero_samples': int(np.count_nonzero(values))}
	report['songs'].append(entry)
	if name in ['GHZ', 'SBZ', 'LBZ2_S3', 'EHZ', 'ExtraLife']:
		with wave.open(str(output / (name + '.wav')), 'wb') as wav:
			wav.setnchannels(2)
			wav.setsampwidth(2)
			wav.setframerate(round(av.timing.sample_rate))
			wav.writeframes(pcm)
	print(f'{report["region"]}: {index:02X} {name} {"streamed" if streamed else f"bank {bank}"} {"Kos+" if entry["compressed_in_rom"] else "raw"} RMS={entry["rms"]:.1f}', flush=True)
	(output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

zram = (C.c_uint8 * 8192).in_dll(g.core, 'zram')


def zr(name, size=1):
	address = g.s[name] if isinstance(name, str) else name
	return int.from_bytes(bytes(zram[address:address + size]), 'little')


def play(sound_id):
	g.write('v_levselsound', sound_id, 2)
	step(2)
	g.buttons = {0}
	step(2)
	g.buttons = set()
	step(1)


if args.switches:
	# AF' is the running DPCM accumulator between interrupts. Check each real
	# DAC write against the previous accumulator plus the current delta-table
	# byte; a newly queued sample explicitly resets the accumulator to $80.
	from check_z80_kosinski_plus import Registers
	g.restore(menu)
	regs = Registers.in_dll(g.core, 'Z80')
	Write = C.CFUNCTYPE(None, C.c_uint, C.c_uint8)
	writer_slot = C.c_void_p.in_dll(g.core, 'z80_writemem')
	original_address = writer_slot.value
	original_writer = Write(original_address)
	state = {'accumulator': (regs.af2.d >> 8) & 255, 'requested': 'menu',
		'samples': 0, 'restarts': 0, 'dac_enabled': bool(zr('zDACEnabled') & 128)}
	corruptions = []; loads = []
	def trace_write(address, value):
		pc = regs.pc.d
		if address == g.s['zCurDAC'] and not value & 128 and g.s['zUpdateDAC'] <= pc < g.s['zloc_104']:
			state['accumulator'] = 0x80
			state['restarts'] += 1
		if address == g.s['zDACEnabled']:
			state['dac_enabled'] = bool(value & 128)
		if address == g.s.get('zAbsVar.MusicSlot' if streamed else 'zMusicData') and (not streamed or value):
			loads.append({'frame': g.frame, 'song': state['requested']})
		if address == 0x4001 and g.s['zWriteDPCMtoDAC'] <= pc < g.s['zDPCMWaitLoop']:
			expected = (state['accumulator'] + zram[regs.hl.d & 0x1FFF]) & 255
			if value != expected:
				corruptions.append({'frame': g.frame, 'song': state['requested'],
					'expected': expected, 'actual': value, 'audible': state['dac_enabled'], 'pc': pc})
			state['accumulator'] = value
			state['samples'] += 1
		original_writer(address, value)
	writer = Write(trace_write)
	writer_slot.value = C.cast(writer, C.c_void_p).value
	chunks.clear(); capture = True; selections = 0
	try:
		for interval in (2, 5, 12, 24):
			for index, name in enumerate(ini.sections(), 1):
				state['requested'] = name
				if interval == 2:
					g.write('v_levselsound', index, 2)
					g.buttons = {0}
					step()
					g.buttons = set()
					step()
				else:
					play(index)
					step(interval - 5)
				selections += 1
		state['requested'] = 'GHZ settle'
		play(g.s['MusID_GHZ']); step(120)
	finally:
		writer_slot.value = original_address
		capture = False
	with wave.open(str(output / 'rapid-switches.wav'), 'wb') as wav:
		wav.setnchannels(2); wav.setsampwidth(2); wav.setframerate(round(av.timing.sample_rate))
		wav.writeframes(b''.join(chunks))
	report['switches'] = {'selections': selections, 'dpcm_samples': state['samples'],
		'sample_restarts': state['restarts'], 'ram_loads': loads, 'corruptions': corruptions}
	(output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
	assert state['samples'] > 1000 and state['restarts'] > 10, 'Rapid switching did not exercise DPCM playback'
	assert len(loads) > 100, 'Rapid switching did not exercise music decoding'
	assert not corruptions, ('DPCM accumulator changed outside sample playback', corruptions[:3])
	assert zr('zSongFM1.PlaybackControl') & 128, 'Final song did not settle'
	assert current_music(g, rom, zram) == g.s['MusID_GHZ'], 'Wrong song after rapid selections'
	print('Rapid music switching:', selections, 'selections;', state['samples'], 'DPCM writes; accumulator continuity passed.', flush=True)


if args.priority:
	# Both real bumper callers must use PlaySound's priority queue. The
	# PlaySound_Special fast path writes QueueToPlay and bypasses arbitration.
	request=bytes.fromhex('303C')+g.s['SndID_Bumper'].to_bytes(2,'big')
	for opcode in ('4EB9','4EF9'):
		assert request+bytes.fromhex(opcode)+g.s['PlaySound'].to_bytes(4,'big') in rom,'Bumper bypasses SFX priority'
	start,end=g.s['zTracksSFXStart'],g.s['zTracksSFXEnd']
	tracks=[g.s[name] for name in ('zSFX_FM3','zSFX_FM4','zSFX_FM5')]
	def active():return [bool(zram[p]&128) for p in tracks]
	def priority():return zr('zAbsVar.SFXPriorityVal')
	def queue(name):zram[g.s['zAbsVar.SFXUnknown']]=g.s['SndID_'+name]
	def blocked(saved,delay):
		g.restore(saved);step(delay);point=g.save();step(3)
		expected=bytes(zram[start:end])
		g.restore(point);queue('Bumper');step(3)
		assert bytes(zram[start:end])==expected,('Bumper interrupted Continue',delay)
		if any(active()):assert priority()==0x7F,('Continue lost priority',delay)
	g.restore(menu);play(g.s['MusID_Stop']);step(30)
	queue('ContinueJingle');step(2);assert priority()==0x7F and all(active())
	jingle=g.save();tail=None;finished=None
	for tick in range(350):
		if any(active()):
			assert priority()==0x7F,('Priority dropped before the final channel stopped',tick,active())
			if not all(active()) and tail is None:tail=tick
		else:
			assert priority()==0;finished=tick;break
		step()
	assert tail is not None and finished is not None
	for delay in (0,40,100,200,tail,tail+2):blocked(jingle,delay)
	# A short PSG effect may end while the higher-priority FM jingle remains.
	g.restore(jingle);queue('Jump');step(2)
	assert zr('zSFX_PSG1.PlaybackControl')&128,'Higher-priority Jump was rejected'
	for _ in range(100):
		step()
		if not zr('zSFX_PSG1.PlaybackControl')&128:break
	else:raise AssertionError('Jump never stopped')
	assert priority()==0x7F and any(active())
	blocked(g.save(),0)
	# Equal priority can still retrigger the jingle.
	g.restore(jingle);step(40);queue('ContinueJingle');step(2)
	assert all(active()) and priority()==0x7F
	assert zr('zSFX_FM3.Volume')==6,'Equal-priority jingle did not restart'
	# Once all jingle channels stop, ordinary bumpers must work again.
	g.restore(jingle);step(finished+2);queue('Bumper');step(2)
	assert all(active()) and priority()==0x70,'Bumper stayed blocked after Continue'
	step(40);assert not any(active()) and priority()==0,'SFX priority did not clear'
	report['priority']={'protected_delays':[0,40,100,200,tail,tail+2],'tail_start':tail,'finished':finished,
		'psg_stop_preserved_priority':True,'equal_priority_retrigger':True,'bumper_after_jingle':True}
	(output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
	print('Continue/bumper priority: early/middle/tail, PSG stop, retrigger and release passed.',flush=True)


if args.effects:
	effects = configparser.ConfigParser(interpolation=None)
	effects.read(project / 'sound/SFX/SFX.ini')
	report['effects'] = []
	for name in effects.sections():
		g.restore(menu)
		play(g.s['MusID_Stop'])
		step(30)
		chunks.clear()
		capture = True
		play(g.s['SndID_' + name])
		step(180)
		capture = False
		pcm = b''.join(chunks)
		values = np.frombuffer(pcm, dtype='<i2').astype(np.float64)
		assert np.count_nonzero(values) > 100, ('Silent sound effect', name)
		report['effects'].append({'name': name, 'pcm_sha256': hashlib.sha256(pcm).hexdigest(), 'rms': float(np.sqrt(np.mean(values * values))), 'frames': 185})
		print('SFX:', name, flush=True)
	(output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

if args.jingles:
	report['restoration'] = []
	# Include both small and large scores in the 1-up restoration cases.
	for name, jingle in (('GHZ', 'ExtraLife'), ('LBZ2_S3', 'ExtraLife'),
			('Test6', 'ExtraLife'), ('Test6', 'DoubleLife')):
		g.restore(menu)
		play(g.s['MusID_' + name])
		step(120)
		music_context = 'zAbsVar.MusicSlot' if streamed else 'zAbsVar.MusicBankNumber'
		bank = zr(music_context)
		voice = zr('zSongFM1.VoicePtrLow', 2)
		is_compressed = ini[name].getboolean('IsCompressed', fallback=bool(ini[name].get('OutputFile')))
		raw_size = ini[name].getint('UncompressedSize', fallback=0)
		if streamed:
			stage = g.s['Music_StageData'] + (bank - 1) * g.s['Music_StageCapacity']
			before = bytes(g.ram[stage & 0xFFFF:(stage & 0xFFFF) + raw_size])
		else:
			before = bytes(zram[g.s['zMusicData']:g.s['zMusicData'] + raw_size]) if is_compressed else None
		play(g.s['MusID_' + jingle])
		assert zr('zAbsVar.1upPlaying'), ('1-up did not start', name)
		for elapsed in range(900):
			step()
			if not zr('zAbsVar.1upPlaying'):
				break
		else:
			raise AssertionError(('1-up did not restore music', name))
		step(200)
		assert zr(music_context) == bank, ('Wrong restored music context', name)
		assert zr('zSongFM1.VoicePtrLow', 2) == voice, ('Wrong restored instruments', name)
		assert zr('zSongFM1.PlaybackControl') & 0x80, ('Restored FM track is stopped', name)
		if streamed:
			assert before == bytes(g.ram[stage & 0xFFFF:(stage & 0xFFFF) + raw_size]), ('Saved song was overwritten', name)
		elif is_compressed:
			assert before == bytes(zram[g.s['zMusicData']:g.s['zMusicData'] + raw_size]), ('Compressed music buffer was not restored', name)
		chunks.clear()
		capture = True
		step(180)
		capture = False
		values = np.frombuffer(b''.join(chunks), dtype='<i2')
		assert np.count_nonzero(values) > 1000, ('Restored music is silent', name)
		report['restoration'].append({'name': name, 'jingle': jingle, 'compressed': is_compressed, 'restored_after_frames': elapsed + 1, 'bank': bank})
		print('1-up restoration:', jingle, 'to', name, flush=True)
	(output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

g.close()
print('Playback checks passed:', len(report['songs']), 'music,', len(report.get('effects', [])), 'effects,', len(report.get('restoration', [])), 'restoration cases.', flush=True)
