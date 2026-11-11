#!/usr/bin/env python3
"""Check the S1 fireball port using real 68000 calls and full game frames.

Direct calls use the loaded game's CD terrain executor, including a disposable
solid test block. The final scenes exercise both-player damage and actual
Debug selection/placement in EHZ. No game instructions are replaced.
"""
from pathlib import Path
import argparse
import json
import struct

from check_caterkiller import Fixture
from check_object_course import boot_level
from check_companion_followup import isolate, place, spawn


def main():
	p = argparse.ArgumentParser(description=__doc__)
	for name in ('core', 'rom', 'listing', 'output'):
		p.add_argument('--' + name, type=Path, required=True)
	p.add_argument('--pal', action='store_true')
	p.add_argument('--system-directory', type=Path, required=True)
	a = p.parse_args()
	a.output.mkdir(parents=True, exist_ok=True)
	for bios in a.system_directory.glob('bios_*.bin'):
		target = a.output / bios.name
		if not target.exists():
			target.write_bytes(bios.read_bytes())
	a.baseline = False
	f = Fixture(a)
	g = f.g
	report = []
	g.core.retro_reset()
	boot_level(g, zone=3)
	stage = g.save()
	isolate(g)
	for actor in ('v_player', 'v_player2'):
		g.put(actor, 'obControl', 0x81)
	g.write('Camera_X_pos', 0, 2)
	g.write('Camera_X_pos_coarse_back', 0xFF80, 2)
	g.write('Camera_Y_pos', 480, 2)
	unit = g.save()

	def finish(case, **detail):
		assert not g.read('v_errortype'), (case, 'ROM exception')
		report.append(dict(case=case, **detail))
		print(report[-1], flush=True)

	def act(obj):
		for priority in range(8):
			g.write(g.s['v_spritequeue'] + priority * 128, 0, 2)
		entry = 'S1Fireball' if g.get(obj, 'code') == g.s['S1Fireball'] else 'S1FireballSpawner_Wait'
		if g.get(obj, 'code') == g.s['S1FireballSpawner']:
			entry = 'S1FireballSpawner'
		f.act(entry, obj)

	# Independent 8.8 velocity / 16.16 position model for all four S1 arcs.
	for kind, speed in enumerate((-0x400, -0x500, -0x600, -0x700)):
		g.restore(unit)
		obj = spawn(g, 'S1Fireball', 160, 600, 0xA500 | kind)
		y, velocity, deleting = 600 << 16, speed, False
		for tick in range(200):
			if deleting:
				act(obj)
				assert not g.get(obj, 'code')
				break
			deleting = (y >> 16) > 600
			velocity += 0x18
			y += velocity << 8
			act(obj)
			assert g.get(obj, 'obY', 4) == y & 0xFFFFFFFF, (kind, tick)
			assert g.get(obj, 'obVelY', 2) == velocity & 65535, (kind, tick)
			assert bool(g.get(obj, 'obStatus') & 2) == (velocity < 0)
			assert g.get(obj, 'obSubtype') == 0xA500 | kind
		else:
			raise AssertionError(('Arc never expired', kind))
		finish('arc-' + str(kind), updates=tick + 1)

	for rate in range(6):
		g.restore(unit)
		obj = spawn(g, 'S1FireballSpawner', 160, 600, 0xA500 | rate << 4 | 7)
		interval = (rate + 1) * 30
		for tick in range(interval * 2):
			act(obj)
			children = [o for o in f.pool() if g.get(o, 'code') == g.s['S1Fireball']]
			assert len(children) == (tick + 1) // interval, (rate, tick, len(children))
			assert all(not g.get(o, 'respawn_addr', 2) and
				g.get(o, 'obSubtype') == 0xA500 | rate << 4 | 7 for o in children)
		finish('interval-' + str(interval), children=len(children))

	# Offscreen timers and full-pool failures must not produce phantom children.
	g.restore(unit)
	obj = spawn(g, 'S1FireballSpawner', 500, 600, 0)
	for _ in range(60):
		act(obj)
	assert not any(g.get(o, 'code') == g.s['S1Fireball'] for o in f.pool())
	g.restore(unit)
	obj = spawn(g, 'S1FireballSpawner', 160, 600, 0)
	for o in f.pool():
		if o != obj:
			g.put(o, 'code', g.s['DisplaySprite'])
	for _ in range(30):
		act(obj)
	assert g.get(obj, 'S1Fireball_Timer') == 30
	free = next(o for o in f.pool() if o != obj)
	g.write(free, 0, g.s['object_size'])
	for _ in range(30):
		act(obj)
	assert g.get(free, 'code') == g.s['S1Fireball']
	finish('visibility-and-pool-retry')

	# A fully solid 128px block uses the existing ROM collision profile.
	g.restore(unit)
	f.stepped_floor()
	for row in range(16):
		for col in range(3, 11):
			g.layout_cell(row, col, 0)
	g.layout_cell(6, 5, 255)
	chunk = g.terrain_address('chunks') + 255 * 128
	for offset in range(0, 128, 2):
		g.write(chunk + offset, 0xF3FF, 2)
	g.write('Collision_addr', g.read('v_colladdr1', 4), 4)
	box = g.save()
	for kind, x, y, expected in ((4, 704, 928, 2), (5, 704, 736, 2),
			(6, 800, 832, 5), (7, 608, 832, 5)):
		g.restore(box)
		g.write('Camera_X_pos', x - 160, 2)
		g.write('Camera_X_pos_coarse_back', (x - 288) & 0xFF80, 2)
		obj = spawn(g, 'S1Fireball', x, y, kind)
		seen = set()
		for tick in range(80):
			act(obj)
			if not g.get(obj, 'code'):
				break
			seen.add(g.get(obj, 'obFrame'))
		else:
			raise AssertionError(('No terrain impact/deletion', kind))
		assert expected in seen, (kind, seen)
		finish('terrain-impact-' + str(kind), frames=sorted(seen), updates=tick + 1)

	for victim, other in (('v_player', 'v_player2'), ('v_player2', 'v_player')):
		g.restore(unit)
		place(g, victim, 160, 600)
		g.put(victim, 'obControl', 1)
		place(g, other, 64, 560)
		g.put(other, 'obControl', 0x81)
		g.write('Tails_CPU_idle_timer', 600, 2)
		spawn(g, 'S1Fireball', 160, 600, 8)
		for _ in range(12):
			g.run()
			if g.get(victim, 'obRoutine') >= 4:
				break
		assert g.get(victim, 'obRoutine') == 4, victim
		finish('real-damage-' + victim)

	# Select/place every new preset through the real 14-byte Debug list.
	g.restore(stage)
	g.put('v_player2', 'code', 0)
	g.write('Debug_mode_flag', 1)
	g.buttons = {0}; g.run(2); g.buttons = set(); g.run(3)
	assert g.read('Debug_placement_type') == 1
	base = g.s['Debug_EHZ']
	rom = a.rom.read_bytes()
	count = struct.unpack_from('>H', rom, base)[0]
	entries = list(struct.iter_unpack('>IIHBBH', rom[base + 2:base + 2 + count * 14]))
	for subtype in (0x30, 0x34, 0x35, 0x36, 0x37):
		index = next(i for i, row in enumerate(entries) if row[0] == g.s['S1FireballSpawner'] and row[2] == subtype)
		g.write('Debug_object', (index - 1) % count)
		g.buttons = {1}; g.run(2); g.buttons = set(); g.run(2)
		assert g.read('Debug_object') == index
		g.buttons = {8}; g.run(2); g.buttons = set(); g.run(4)
		assert any(g.get(o, 'code') in (g.s['S1FireballSpawner'], g.s['S1FireballSpawner_Wait']) and
			g.get(o, 'obSubtype') == subtype for o in f.pool()), subtype
	for tick in range(240):
		g.run()
		children = [o for o in f.pool() if g.get(o, 'code') == g.s['S1Fireball'] and
			g.get(o, 'obRoutine') == 2]
		if children:
			break
	assert children, 'Debug spawners never emitted a live fireball'
	assert all(g.get(o, 'obMap', 4) == g.s['Map_Fireballs'] and
		g.get(o, 'obGfx', 2) == g.s['ArtTile_Fireball'] for o in children)
	g.run(3)
	g.video.save(a.output / 'debug-fireball-spawner.png')
	finish('real-debug-presets', count=5, emission_wait=tick + 1)
	(a.output / 'report.json').write_text(json.dumps(dict(passed=True,
		region='PAL' if a.pal else 'NTSC', checks=report), indent=2) + '\n')
	g.close()


if __name__ == '__main__':
	main()
