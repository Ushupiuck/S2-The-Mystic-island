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
	bank, low, high, flags = rom[g.s['zMasterPlaylist'] + (index - 1) * 4:g.s['zMasterPlaylist'] + index * 4]
	entry = {'id': index, 'name': name, 'title': ini[name]['Title'], 'bank': bank, 'compressed_to_z80_ram': not bool(flags & 0x10), 'frames': args.frames, 'pcm_sha256': hashlib.sha256(pcm).hexdigest(), 'sample_frames': len(pcm) // 4, 'rms': float(np.sqrt(np.mean(values * values))), 'peak': int(np.max(np.abs(values))), 'nonzero_samples': int(np.count_nonzero(values))}
	report['songs'].append(entry)
	if name in ['GHZ', 'SBZ', 'LBZ2_S3', 'EHZ', 'ExtraLife']:
		with wave.open(str(output / (name + '.wav')), 'wb') as wav:
			wav.setnchannels(2)
			wav.setsampwidth(2)
			wav.setframerate(round(av.timing.sample_rate))
			wav.writeframes(pcm)
	print(f'{report["region"]}: {index:02X} {name} bank {bank} {"RAM" if entry["compressed_to_z80_ram"] else "ROM"} RMS={entry["rms"]:.1f}', flush=True)
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
	for name in ['GHZ', 'LBZ2_S3']:
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

g.close()
print('Playback checks passed:', len(report['songs']), 'music,', len(report.get('effects', [])), 'effects,', len(report.get('restoration', [])), 'restoration cases.', flush=True)
