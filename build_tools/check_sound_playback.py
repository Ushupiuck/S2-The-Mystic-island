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

p = argparse.ArgumentParser(description='Play music, effects and 1-up restoration on a Genesis Plus GX libretro core.')
p.add_argument('--core', type=Path, required=True)
p.add_argument('--rom', type=Path, default=project / 's2built.bin')
p.add_argument('--listing', type=Path, default=project / 'md-main.lst')
p.add_argument('--output', type=Path)
p.add_argument('--effects', action='store_true')
p.add_argument('--jingles', action='store_true')
p.add_argument('--priority', action='store_true', help='Check bumper/Continue SFX arbitration and priority release.')
p.add_argument('--switches', action='store_true', help='Trace DPCM continuity while rapidly selecting different songs.')
p.add_argument('--stress', action='store_true', help='Exercise shared-channel ownership, pause, tempo and music loads inside Scrap Madness Act 2.')
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
clone = 'Sound_MusicBuffer' in g.s

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
	if clone:
		address = g.s['MusicIndex'] + (index - 1) * g.s['Sound_MusicEntry.len']
		flags = rom[address + g.s['Sound_MusicEntry.Flags']]
		if not flags & 0x80:
			assert g.read('Sound_CurrentSong') == index, ('Wrong current song', name)
		from check_sound_tools import kosinski_plus
		packed = rom[g.s['Mus_' + name]:g.s['Mus_' + name] + ini[name].getint('Size')]
		expected = kosinski_plus(packed) if flags & 1 else packed
		buffer = g.s['Sound_JingleBuffer' if flags & 0x80 else 'Sound_MusicBuffer']
		# Finite jingles may already have restored the menu music.
		if not flags & 0x80:
			assert bytes(g.read(buffer + i) for i in range(len(expected))) == expected, ('MD decoded music differs', name)
		bank = None
	else:
		bank, low, high, flags = rom[g.s['zMasterPlaylist'] + (index - 1) * 4:g.s['zMasterPlaylist'] + index * 4]
	entry = {'id': index, 'name': name, 'title': ini[name]['Title'], 'bank': bank, 'compressed_to_md_ram': clone and bool(flags & 1), 'compressed_to_z80_ram': not clone and not bool(flags & 0x10), 'frames': args.frames, 'pcm_sha256': hashlib.sha256(pcm).hexdigest(), 'sample_frames': len(pcm) // 4, 'rms': float(np.sqrt(np.mean(values * values))), 'peak': int(np.max(np.abs(values))), 'nonzero_samples': int(np.count_nonzero(values))}
	report['songs'].append(entry)
	if name in ['GHZ', 'SBZ', 'LBZ2_S3', 'EHZ', 'ExtraLife']:
		with wave.open(str(output / (name + '.wav')), 'wb') as wav:
			wav.setnchannels(2)
			wav.setsampwidth(2)
			wav.setframerate(round(av.timing.sample_rate))
			wav.writeframes(pcm)
	print(f'{report["region"]}: {index:02X} {name} bank {bank} {"MD RAM" if clone else "Z80 RAM" if entry["compressed_to_z80_ram"] else "ROM"} RMS={entry["rms"]:.1f}', flush=True)
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
	from genesis_test_core import Z80Registers as Registers
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
		if not clone and address == g.s['zMusicData']:
			loads.append({'frame': g.frame, 'song': state['requested']})
		if address == 0x4001 and g.s['zWriteDPCMtoDAC'] <= pc < g.s['zDPCMWaitLoop']:
			expected = (state['accumulator'] + zram[regs.hl.d & 0x1FFF]) & 255
			if value != expected:
				corruptions.append({'frame': g.frame, 'song': state['requested'],
					'expected': expected, 'actual': value, 'audible': bool(zr('zDACEnabled') & 128), 'pc': pc})
			state['accumulator'] = value
			state['samples'] += 1
		original_writer(address, value)
	writer = Write(trace_write)
	writer_slot.value = C.cast(writer, C.c_void_p).value
	chunks.clear(); capture = True; selections = 0
	try:
		for delay in (0, 7, 19):
			for index, name in enumerate(ini.sections(), 1):
				state['requested'] = name
				play(index); step(delay); selections += 1
				if clone: loads.append({'frame': g.frame, 'song': name})
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
	if clone:
		assert g.read(g.s['Clone_Driver_RAM'] + g.s['SMPS_RAM.v_music_fm1_track'] + g.s['SMPS_Track.PlaybackControl']) & 128, 'Final song did not settle'
	else:
		assert zr('zSongFM1.PlaybackControl') & 128, 'Final song did not settle'
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

if args.jingles and clone:
	report['restoration'] = []
	track = g.s['Clone_Driver_RAM'] + g.s['SMPS_RAM.v_music_fm1_track']
	for name in ('GHZ', 'LBZ2_S3', 'Test6'):
		for jingle in ('ExtraLife', 'DoubleLife'):
			g.restore(menu); play(g.s['MusID_' + name]); step(120)
			assert not zr('zAbsVar.1upPlaying'), ('Ordinary song marked as jingle', name)
			voice = g.read(track + g.s['SMPS_Track.VoicePtr'], 4)
			size = ini[name].getint('UncompressedSize')
			buffer = g.s['Sound_MusicBuffer']
			before = bytes(g.read(buffer + i) for i in range(size))
			play(g.s['MusID_' + jingle])
			assert zr('zAbsVar.1upPlaying'), ('Jingle did not start', name, jingle)
			assert g.read('Sound_CurrentSong') == g.s['MusID_' + jingle]
			for elapsed in range(900):
				step()
				if not zr('zAbsVar.1upPlaying'): break
			else: raise AssertionError(('Jingle did not restore', name, jingle))
			step(200)
			assert g.read('Sound_CurrentSong') == g.s['MusID_' + name], ('Restored wrong song', name, jingle)
			assert g.read(track + g.s['SMPS_Track.PlaybackControl']) & 128
			assert g.read(track + g.s['SMPS_Track.VoicePtr'], 4) == voice, ('Restored wrong instruments', name)
			assert before == bytes(g.read(buffer + i) for i in range(size)), ('Jingle replaced main buffer', name)
			chunks.clear(); capture = True; step(180); capture = False
			assert np.count_nonzero(np.frombuffer(b''.join(chunks), dtype='<i2')) > 1000
			report['restoration'].append({'name': name, 'jingle': jingle, 'restored_after_frames': elapsed + 1})
			print('MD jingle restoration:', name, jingle, flush=True)
	(output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

if args.jingles and not clone:
	report['restoration'] = []
	# Include the largest newly RAM-loaded prototype song near the $A40 limit.
	for name in ['GHZ', 'LBZ2_S3', 'Test6']:
		g.restore(menu)
		play(g.s['MusID_' + name])
		step(120)
		bank = zr('zAbsVar.MusicBankNumber')
		voice = zr('zSongFM1.VoicePtrLow', 2)
		is_compressed = ini[name].getboolean('IsCompressed', fallback=bool(ini[name].get('OutputFile')))
		raw_size = ini[name].getint('UncompressedSize', fallback=0)
		before = bytes(zram[g.s['zMusicData']:g.s['zMusicData'] + raw_size]) if is_compressed else None
		play(g.s['MusID_ExtraLife'])
		assert zr('zAbsVar.1upPlaying'), ('1-up did not start', name)
		for elapsed in range(900):
			step()
			if not zr('zAbsVar.1upPlaying'):
				break
		else:
			raise AssertionError(('1-up did not restore music', name))
		step(200)
		assert zr('zAbsVar.MusicBankNumber') == bank, ('Wrong restored bank', name)
		assert zr('zSongFM1.VoicePtrLow', 2) == voice, ('Wrong restored instruments', name)
		assert zr('zSongFM1.PlaybackControl') & 0x80, ('Restored FM track is stopped', name)
		if is_compressed:
			assert before == bytes(zram[g.s['zMusicData']:g.s['zMusicData'] + raw_size]), ('Compressed music buffer was not restored', name)
		chunks.clear()
		capture = True
		step(180)
		capture = False
		values = np.frombuffer(b''.join(chunks), dtype='<i2')
		assert np.count_nonzero(values) > 1000, ('Restored music is silent', name)
		report['restoration'].append({'name': name, 'compressed': is_compressed, 'restored_after_frames': elapsed + 1, 'bank': bank})
		print('1-up restoration:', name, 'RAM' if is_compressed else 'ROM', flush=True)
	(output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

if args.stress:
	assert clone, 'The hybrid ownership stress check requires the experimental driver'
	g.restore(menu)
	zone = g.s['id_SMZ']
	g.write('v_levselitem', (zone // 8) * 256 + (zone % 8) * 4 + 1, 2); step(5)
	g.buttons = {3}; step(2); g.buttons = set()
	for _ in range(700):
		step()
		if g.read('v_vbla_routine', 2) == g.s['Vint_Level'] and g.read('f_timecount'): break
	else: raise AssertionError('SMZ2 did not start')
	step(30)
	assert g.read('Current_ZoneAndAct', 2) == g.s['id_SMZ'] * 256 + 1
	# Freeze the player on the real level's starting floor; terrain, actors,
	# animation, interrupts, CD services and both sound CPUs keep executing.
	g.put('v_player', 'obControl', 0x81)
	g.put('v_player2', 'obControl', 0x81)
	g.put('v_player2', 'obAnim', 0)
	g.write('Tails_CPU_idle_timer', 6000, 2)
	for who in ('v_player', 'v_player2'):
		if g.get(who, 'code'): g.put(who, 'flashtime', 6000, 2)
	base = g.s['Clone_Driver_RAM']; stride = g.s['SMPS_Track.len']
	md_tracks = [base + g.s['SMPS_RAM.v_music_' + name + '_track'] for name in ('fm3', 'fm4', 'fm5', 'psg1', 'psg2', 'psg3')]
	z_tracks = [g.s['zSFX_' + name] for name in ('FM3', 'FM4', 'FM5', 'PSG1', 'PSG2', 'PSG3')]
	# Observe the common chip entry point, including both CPU bus paths.
	# A register selector and its data must belong to the same CPU. DAC data
	# intentionally reuse the $2A selector restored before releasing Z80.
	FMWrite = C.CFUNCTYPE(None, C.c_uint, C.c_uint, C.c_uint)
	fm_slot = C.c_void_p.in_dll(g.core, 'fm_write')
	fm_address = fm_slot.value; fm_original = FMWrite(fm_address)
	latches = [None, None]; registers = {}; collisions = []; stolen = []
	writes = {'MD': 0, 'Z80': 0}; covered = set(); released = set(); ambient = 0
	def fm_trace(cycles, port, value):
		owner = 'MD' if zr('zAbsVar.MDLock') and not zr('zAbsVar.FMBusy') else 'Z80'
		part = port >> 1
		if not port & 1: latches[part] = (value, owner)
		elif latches[part] is not None:
			reg, selector_owner = latches[part]
			writes[owner] += 1; registers[part, reg] = value
			if reg != 0x2A and selector_owner != owner:
				collisions.append((g.frame, part, reg, selector_owner, owner))
			if owner == 'MD' and g.read('Sound_CurrentSong') and not g.read(base + g.s['SMPS_RAM.f_pause']):
				channel = None
				if 0x30 <= reg <= 0x9F or 0xA0 <= reg <= 0xB6:
					if reg & 3 != 3: channel = part * 3 + (reg & 3)
				elif part == 0 and reg == 0x28:
					channel = (value & 3) + (3 if value & 4 else 0)
				if channel in (2, 3, 4) and zram[z_tracks[channel - 2]] & 128:
					stolen.append((g.frame, channel, reg, value))
		fm_original(cycles, port, value)
	fm_callback = FMWrite(fm_trace); fm_slot.value = C.cast(fm_callback, C.c_void_p).value
	effects = configparser.ConfigParser(interpolation=None); effects.read(project / 'sound/SFX/SFX.ini')
	try:
		# Every effect is also played over real level music, then explicitly
		# stopped. Check the live override flags and restored hardware patches.
		for name in effects.sections():
			g.write('Sound_SFXImmediate', g.s['SndID_' + name]); step(4)
			affected = {i for i, zt in enumerate(z_tracks) if zram[zt] & 128}
			for i, (zt, mt) in enumerate(zip(z_tracks, md_tracks)):
				if zram[zt] & 128:
					covered.add(i)
					assert g.read(mt) & 4, ('Music did not yield channel', name, i)
			g.write(base + g.s['SMPS_RAM.variables.queue.v_playsnd2'], g.s['MusID_StopSFX']); step(4)
			for i, (zt, mt) in enumerate(zip(z_tracks, md_tracks)):
				# Live flamethrowers can immediately queue a new FireBurn. Their
				# channel must stay owned; verify release when actually inactive.
				if zram[zt] & 128:
					ambient += 1
					assert g.read(mt) & 4, ('Ambient effect lost ownership', name, i)
					continue
				assert not g.read(mt) & 4, ('Inactive effect retained channel', name, i)
				if i in affected: released.add(i)
				if i in affected and i < 3 and g.read(mt) & 128:
					voice = g.read(mt + g.s['SMPS_Track.VoicePtr'], 4) + g.read(mt + g.s['SMPS_Track.VoiceIndex']) * 25
					part, channel = (0, 2) if i == 0 else (1, i - 1)
					for start, offset in ((0x30, 1), (0x50, 9), (0x60, 13), (0x70, 17), (0x80, 21)):
						for op in range(4):
							assert registers[part, start + channel + op * 4] == g.read(voice + offset + op), ('Instrument not restored', name, i, start, op)
		assert covered == released == set(range(6)), ('SFX handoff coverage incomplete', covered, released)
		# Dense repeated normal/stereo/immediate queues, song decompression,
		# speed shoes and real Start-button pause/resume in one continuous run.
		storm = ['Ring', 'Jump', 'Skidding', 'SpindashRev', 'Bumper', 'FireBurn', 'Gloop', 'Spring', 'Checkpoint']
		storm = [name for name in storm if 'SndID_' + name in g.s]
		for tick in range(1800):
			if tick % 3 == 0: g.write('Sound_SFXNormal', g.s['SndID_' + storm[(tick // 3) % len(storm)]])
			if tick % 7 == 0: g.write('Sound_SFXStereo', g.s['SndID_Ring'])
			if tick % 61 == 0: g.write('Sound_SFXImmediate', g.s['SndID_Jump'])
			if tick in (200, 1000): g.write('Sound_TempoAdjust', 8)
			if tick in (400, 1200): g.write('Sound_TempoAdjust', 0)
			if tick in (500, 1300): g.write('Sound_PendingSong', g.s['MusID_LBZ2_S3'])
			if tick in (700, 1500): g.write('Sound_PendingSong', g.s['bgm_SBZ'])
			step()
			assert g.read('v_gamemode', 2) == g.s['Level'], ('Stress test left SMZ2', tick)
			if tick in (300, 1100):
				g.buttons = {3}; step(2); g.buttons = set(); step(3)
				assert g.read('f_pause', 2), 'Game did not pause'
				state = bytes(g.read(base + i) for i in range(g.s['SMPS_RAM.v_music_track_ram_end']))
				zstate = bytes(zram[g.s['zTracksSFXStart']:g.s['zTracksSFXEnd']])
				step(90)
				assert state == bytes(g.read(base + i) for i in range(len(state))), 'Music advanced while paused'
				assert zstate == bytes(zram[g.s['zTracksSFXStart']:g.s['zTracksSFXEnd']]), 'Effects advanced while paused'
				g.buttons = {3}; step(2); g.buttons = set(); step(3)
				assert not g.read('f_pause', 2), 'Game did not resume'
		step(30)
	finally:
		fm_slot.value = fm_address
	assert not collisions, ('YM selector/data interleaving', collisions[:5])
	assert not stolen, ('Music overwrote an active SFX channel', stolen[:5])
	assert writes['MD'] > 1000 and writes['Z80'] > 1000
	assert g.read('Sound_CurrentSong') == g.s['bgm_SBZ']
	report['stress'] = {'level': 'Scrap Madness Act 2', 'effects_over_music': len(effects.sections()), 'channels_tested': sorted(covered), 'channels_released': sorted(released), 'ambient_requeues': ambient, 'storm_frames': 1800, 'pause_frames': 180, 'fm_writes': writes, 'selector_collisions': collisions, 'stolen_channels': stolen}
	(output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
	print('SMZ2 stress: 86 effects over music, six channel handoffs, dense queues, CD song loads, tempo and pause/resume passed.', flush=True)

	# Execute both compiled V-int epilogues, including the localized fast
	# return. A synthetic exception frame exercises the real RTE and audio
	# body; no game routine or chip access is stubbed.
	from check_caterkiller import CpuPrefix
	cpu = CpuPrefix.in_dll(g.core, 'm68k')
	g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
	g.core.m68k_run.argtypes = [C.c_uint]
	boundary = g.save(); returns = []; reached = set()
	cases = [('common', 'VintRet', 0, 0, 0, False),
		('lag-owned', 'Vint_Lag_Main', 255, 0, 0, False),
		('lag-title', 'Vint_Lag_Main', 0, 0, 0, False),
		('lag-dry-level', 'Vint_Lag_Main', 0, 0, 0, True),
		('lag-water', 'Vint_Lag_Main', 0, 1, 0, True),
		('lag-submerged', 'Vint_Lag_Main', 0, 1, 1, True),
		('called-lag-water', 'Vint_Lag', 0, 1, 0, True)]
	for name, entry, counter, water, submerged, level in cases:
		g.restore(boundary)
		g.write('v_vbla_counter', counter); g.write('Water_flag', water); g.write('f_wtr_state', submerged)
		g.write('v_gamemode', g.s['Level'] if level else g.s['TitleScreen'], 2)
		g.write('Sound_LoadBusy', 0); g.write('Sound_UpdateRunning', 0); g.write('Sound_ReadySong', 0)
		# Interrupt epilogue expects D0-A6, then the six-byte exception frame.
		stack = 0xFFAA00; sentinel = 0xFFAC00
		for i in range(15): g.write(stack + i * 4, 0x12340000 + i, 4)
		g.write(stack + 60, 0x2700, 2); g.write(stack + 62, sentinel, 4)
		g.write(sentinel, 0x60FE, 2)
		if entry == 'Vint_Lag': stack -= 4; g.write(stack, g.s['VintRet'], 4)
		g.core.m68k_set_reg(15, stack); g.core.m68k_set_reg(17, 0x2700)
		g.core.m68k_set_reg(13, 0xC00004); g.core.m68k_set_reg(14, 0xC00000)
		g.core.m68k_set_reg(16, g.s[entry])
		calls = ticks = 0; exited = None
		for _ in range(200000):
			pc = g.core.m68k_get_reg(16)
			if pc == sentinel: break
			if pc == g.s['Sound_Update']: calls += 1
			if pc == g.s['SMPS_UpdateDriver']: ticks += 1
			if pc < len(rom) and rom[pc:pc + 2] == b'\x4e\x73': exited = pc; reached.add(pc)
			g.core.m68k_run(cpu.cycles + 1)
		else: raise AssertionError(('V-int exit did not return', name, hex(pc)))
		assert calls == ticks == 1, ('V-int must tick audio exactly once', name, calls, ticks)
		assert g.core.m68k_get_reg(15) == 0xFFAA00 + 66, ('V-int stack imbalance', name)
		assert all(g.core.m68k_get_reg(i) == 0x12340000 + i for i in range(15)), ('V-int register corruption', name)
		returns.append({'path': name, 'exit': exited, 'updates': ticks})
	expected = {pc for pc in range(g.s['V_Int'], g.s['H_Int'], 2) if rom[pc:pc + 2] == b'\x4e\x73'}
	assert reached == expected, ('Untested localized V-int return', reached, expected)
	g.restore(boundary)
	report['stress']['vint_returns'] = returns
	(output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
	print('V-int exits: both compiled RTE paths preserve registers/stack and update audio exactly once in all seven cases.', flush=True)

g.close()
print('Playback checks passed:', len(report['songs']), 'music,', len(report.get('effects', [])), 'effects,', len(report.get('restoration', [])), 'restoration cases.', flush=True)
