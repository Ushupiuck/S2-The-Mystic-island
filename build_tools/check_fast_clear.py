#!/usr/bin/env python3
"""Break a temporary shoes monitor in $0B and clear using controller input.

Only level selection and monitor placement are RAM fixtures. No teleporting,
forced rewards, timer edits, forced results or forced next-act transitions.
"""
from pathlib import Path
import argparse
import ctypes as C
import hashlib
import json
import math
import struct
import numpy as np
from genesis_test_core import Genesis

p = argparse.ArgumentParser(description=__doc__)
for name in ('rom', 'listing', 'core', 'output'):
	p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--system-directory', type=Path)
p.add_argument('--player', type=int, choices=(0, 1, 2), default=0)
p.add_argument('--pal', action='store_true')
a = p.parse_args()
g = Genesis(a.core, a.rom, a.listing, a.output, a.pal, system_directory=a.system_directory,
	core_options=None if a.system_directory else {b'genesis_plus_gx_add_on': b'none'})
zram = (C.c_uint8 * 8192).in_dll(g.core, 'zram')
report = {'pal': a.pal, 'player_mode': a.player,
	'rom_sha256': hashlib.sha256(a.rom.read_bytes()).hexdigest(),
	'fixture': 'Temporary shoes monitor at $0100,$0170; controller-driven play', 'events': [], 'audio': {}}
phase = 'boot'


def audio(data, frames):
	values = np.frombuffer(C.string_at(data, frames * 4), '<i2').astype('int64')
	stats = report['audio'].setdefault(phase, {'samples': 0, 'sum_squares': 0})
	stats['samples'] += int(values.size)
	stats['sum_squares'] += int(np.dot(values, values))
	return frames


g.callbacks[3] = C.CFUNCTYPE(C.c_size_t, C.c_void_p, C.c_size_t)(audio)
g.core.retro_set_audio_sample_batch(g.callbacks[3])


def step(n=1):
	for _ in range(n):
		g.run()
		assert not g.read('v_errortype'), ('CPU exception', g.frame)


def hold(keys, n):
	g.buttons = set(keys)
	step(n)


def card(scene):
	rom = a.rom.read_bytes()
	root = g.s['DPLC_Cards']
	ptr = root + struct.unpack_from('>h', rom, root + scene * 2)[0]
	expected = bytearray()
	for i in range(struct.unpack_from('>H', rom, ptr)[0]):
		word = struct.unpack_from('>H', rom, ptr + 2 + i * 2)[0]
		src = g.s['Art_CardFont'] + (word & 0xFFF) * 32
		expected += rom[src:src + ((word >> 12) + 1) * 32]
	start = g.s['ArtTile_Title_Card'] * 32
	assert bytes(g.vram[(start + i) ^ 1] for i in range(len(expected))) == expected, ('Card DMA', scene)


def event(name, frame):
	report['events'].append({'event': name, 'frame': frame,
		'zone_act': f"{g.read('Current_ZoneAndAct', 2):04X}",
		'primary_shoes': g.get('v_player', 'shoetime', 2), 'partner_shoes': g.get('v_player2', 'shoetime', 2),
		'music_speed': int(zram[g.s['zAbsVar.SpeedUpFlag']]),
		'no_speed_up': int(zram[g.s['zCanNotBeSpedUp']])})
	g.video.save(a.output / (name + '.png'))


for _ in range(1800):
	step()
	if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
		break
else:
	raise AssertionError('Title timeout')
cd_status = g.read('MCD_status') if 'MCD_status' in g.s else 0
assert cd_status == (1 if a.system_directory else 0)
g.write('f_levselcheat', 1)
hold({3}, 2); hold({}, 100)
g.write('Player_mode', a.player, 2)
g.write('v_levselitem', 0x10C, 2)
hold({3}, 2); hold({}, 1)
for _ in range(700):
	step()
	if g.read('v_vbla_routine', 2) == g.s['Vint_Level'] and g.read('f_timecount'):
		break
else:
	raise AssertionError('$0B timeout')
assert g.read('Current_ZoneAndAct', 2) == 0x0B00
monitor = next(x for x in range(g.s['v_lvlobjspace'] & 65535, g.s['v_lvlobjend'] & 65535, g.s['object_size']) if not g.get(x, 'code'))
for key, value, size in (('code', g.s['Obj26'], 4), ('obX', 0x100, 2), ('obY', 0x170, 2), ('obSubtype', 5, 1)):
	g.put(monitor, key, value, size)
hold({}, 30)
event('monitor', 0)
phase = 'stage-1'
hold({5}, 5)
for _ in range(3):
	hold({5, 0}, 2); hold({5}, 3)
hold({7}, 1)
shoes = signpost = results = next_act = None
for elapsed in range(2400):
	step()
	zone = g.read('Current_ZoneAndAct', 2)
	if shoes is None and g.get('v_player', 'obStatusSecondary') & 4:
		shoes = elapsed
		assert zram[g.s['zAbsVar.SpeedUpFlag']] == 8
		event('shoes', elapsed)
	if signpost is None and shoes is not None and not g.read('f_timecount'):
		signpost = elapsed
		event('signpost', elapsed)
	if results is None and g.get('v_endcard', 'code'):
		results = elapsed
		phase = 'results'
	if results is not None and elapsed == results + 80:
		card(65 if a.player == 2 else 64)
		assert zram[g.s['zCanNotBeSpedUp']], 'Act-clear NoSpeedUp flag lost'
		event('results', elapsed)
	if zone != 0x0B00:
		assert zone == 0x0B01
		g.buttons = set()
		phase = 'transition'
		if g.read('f_timecount') and g.read('v_vbla_routine', 2) == g.s['Vint_Level']:
			next_act = elapsed
			phase = 'stage-2'
			step(120)
			event('next-act', elapsed + 120)
			break
else:
	g.video.save(a.output / 'timeout.png')
	raise AssertionError(('Next-act timeout', report['events'], g.get('v_player', 'obX', 2)))
assert shoes is not None and signpost < 600
if 'MCD_status' in g.s:
	assert g.read('MCD_status') == cd_status and not g.read('MCD_dma_pending')
assert not g.get('v_player', 'obStatusSecondary') & 4
assert not g.get('v_player2', 'obStatusSecondary') & 4
report['frames_from_launch'] = dict(shoes=shoes, signpost=signpost, results=results, next_act=next_act)
report['music_speed_reset'] = not zram[g.s['zAbsVar.SpeedUpFlag']] and not zram[g.s['zSaveVar.SpeedUpFlag']]
for name, stats in report['audio'].items():
	stats['rms'] = math.sqrt(stats.pop('sum_squares') / max(1, stats['samples']))
for name in ('stage-1', 'results', 'stage-2'):
	assert report['audio'][name]['rms'] > 1, ('Silent audio', name)
(a.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
g.close()
assert report['music_speed_reset'], 'Speed-up leaked into the next act'
print('Shoes, quick finish, results and next act passed:', report['frames_from_launch'], flush=True)
