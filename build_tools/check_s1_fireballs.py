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

	projectile_labels = ('S1Fireball','S1Fireball_Arc','S1Fireball_ArcDown',
		'S1Fireball_Up','S1Fireball_Down','S1Fireball_Left','S1Fireball_Right',
		'S1Fireball_Impact','S1Fireball_Delete')
	projectile_codes = {g.s[label] for label in projectile_labels}
	flight_codes = projectile_codes - {g.s['S1Fireball_Impact'],g.s['S1Fireball_Delete']}
	entries_by_code = {g.s[label]:label for label in projectile_labels +
		('S1FireballSpawner','S1FireballSpawner_Wait')}

	def is_ball(obj):
		return g.get(obj, 'code') in projectile_codes

	def act(obj):
		for priority in range(8):
			g.write(g.s['v_spritequeue'] + priority * 128, 0, 2)
		f.act(entries_by_code[g.get(obj, 'code')], obj)

	# Independent 8.8 velocity / 16.16 position model, mirrored at the roof.
	for kind, speed in enumerate((-0x400, -0x500, -0x600, -0x700)):
		for roof in (False,True):
			g.restore(unit)
			obj = spawn(g, 'S1Fireball', 160, 600, 0xA500 | kind)
			g.put(obj, 'obStatus', 2 if roof else 0)
			y, velocity, deleting = 600 << 16, -speed if roof else speed, False
			for tick in range(200):
				if deleting:
					act(obj)
					assert not g.get(obj, 'code')
					break
				deleting = (y >> 16) < 600 if roof else (y >> 16) > 600
				velocity += -0x18 if roof else 0x18
				y += velocity << 8
				act(obj)
				assert g.get(obj, 'obY', 4) == y & 0xFFFFFFFF, (kind, roof, tick)
				assert g.get(obj, 'obVelY', 2) == velocity & 65535, (kind, roof, tick)
				assert bool(g.get(obj, 'obStatus') & 2) == (velocity < 0)
				assert g.get(obj, 'obSubtype') == 0xA500 | kind
			else:
				raise AssertionError(('Arc never expired', kind, roof))
			finish('arc-' + str(kind) + ('-roof' if roof else '-floor'), updates=tick + 1)

	# All low-nibble settings and both placement flips are independent fields.
	for subtype in range(16):
		for flips in range(4):
			g.restore(unit)
			obj = spawn(g, 'S1Fireball', 160, 600, 0xA500 | subtype)
			g.put(obj, 'obStatus', flips)
			act(obj)
			if subtype & 4:
				vx,vy = ((-0x200 if flips & 1 else 0x200),0) if subtype & 8 else (0,0x200 if flips & 2 else -0x200)
			else:
				vx,vy = 0,(-0x400-(subtype & 3)*0x100+0x18)*(-1 if flips & 2 else 1)
			assert g.get(obj, 'obVelX', 2) == vx & 65535, (subtype,flips,'X')
			assert g.get(obj, 'obVelY', 2) == vy & 65535, (subtype,flips,'Y')
			assert g.get(obj, 'obX', 4) == (160<<16)+(vx<<8)
			assert g.get(obj, 'obY', 4) == (600<<16)+(vy<<8)
			assert g.get(obj, 'obSubtype') == 0xA500 | subtype
	finish('movement-settings-and-flips', cases=64)

	for rate in range(6):
		g.restore(unit)
		obj = spawn(g, 'S1FireballSpawner', 160, 600, 0xA500 | rate << 4 | 12)
		g.put(obj, 'obStatus', rate & 3)
		interval = (rate + 1) * 30
		for tick in range(interval * 2):
			act(obj)
			children = [o for o in f.pool() if is_ball(o)]
			assert len(children) == (tick + 1) // interval, (rate, tick, len(children))
			assert all(not g.get(o, 'respawn_addr', 2) and
				g.get(o, 'obSubtype') == 0xA500 | rate << 4 | 12 and
				g.get(o, 'obStatus') == rate & 3 for o in children)
		assert all(g.get(o, 'obX', 2) == 160+(-16 if rate & 1 else 16) for o in children)
		act(children[0])
		assert g.get(children[0], 'obVelX', 2) == (-0x200 if rate & 1 else 0x200) & 65535
		finish('interval-' + str(interval), children=len(children), inherited_flips=rate & 3)

	for flips in (0,2):
		g.restore(unit)
		maker = spawn(g, 'S1FireballSpawner', 160, 600, 0xA504)
		g.put(maker, 'obStatus', flips)
		for _ in range(30):act(maker)
		child = next(o for o in f.pool() if is_ball(o))
		assert g.get(child, 'obSubtype') == 0xA504 and g.get(child, 'obStatus') == flips
		assert g.get(child, 'obY', 2) == 600+(16 if flips else -16)
		act(child)
		assert g.get(child, 'obVelY', 2) == (0x200 if flips else -0x200) & 65535
		assert g.get(maker, 'obStatus') == flips
	finish('maker-vertical-flips', directions=2)
	g.restore(unit)
	maker = spawn(g, 'S1FireballSpawner', 160, 600, 0xA5FC)
	for _ in range(180):act(maker)
	assert g.get(maker, 'S1Fireball_Interval') == 180
	assert len([o for o in f.pool() if is_ball(o)]) == 1
	finish('reserved-interval-clamps')

	# Offscreen timers and full-pool failures must not produce phantom children.
	g.restore(unit)
	obj = spawn(g, 'S1FireballSpawner', 500, 600, 0)
	for _ in range(60):
		act(obj)
	assert not any(is_ball(o) for o in f.pool())
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
	assert is_ball(free)
	finish('visibility-and-pool-retry')
	# The LRZ-style allocation prefers later slots, but must still use an
	# earlier free slot when the maker occupies the last SST entry.
	g.restore(unit)
	last = list(f.pool())[-1]
	for obj in f.pool():g.put(obj, 'code', g.s['DisplaySprite'])
	for obj in (last,list(f.pool())[0]):g.write(obj,0,g.s['object_size'])
	for field,value,size in (('code',g.s['S1FireballSpawner'],4),('obX',160,2),
			('obY',600,2),('obSubtype',0xC,2)):
		g.put(last,field,value,size)
	for _ in range(30):act(last)
	assert is_ball(list(f.pool())[0])
	finish('last-slot-maker-allocation')

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
	for kind, flips, x, y, expected in ((4, 0, 704, 928, 2), (4, 2, 704, 736, 2),
			(12, 1, 800, 832, 5), (12, 0, 608, 832, 5)):
		g.restore(box)
		g.write('Camera_X_pos', x - 160, 2)
		g.write('Camera_X_pos_coarse_back', (x - 288) & 0xFF80, 2)
		obj = spawn(g, 'S1Fireball', x, y, kind)
		g.put(obj, 'obStatus', flips)
		seen = set()
		for tick in range(80):
			act(obj)
			if not g.get(obj, 'code'):
				break
			seen.add(g.get(obj, 'obFrame'))
		else:
			raise AssertionError(('No terrain impact/deletion', kind))
		assert expected in seen, (kind, seen)
		finish('terrain-impact-' + str((kind,flips)), frames=sorted(seen), updates=tick + 1)

	# Directly placed projectiles release their own handle; emitted shots have none.
	g.restore(unit)
	obj = spawn(g, 'S1Fireball', 160, 600, 0)
	g.put(obj, 'respawn_addr', g.placement_handle(0), 2)
	g.placement_write(0, 0x80)
	f.act('S1Fireball_Delete', obj)
	assert not g.get(obj, 'code') and not g.placement_read(0) & 0x80
	finish('individual-placement-release')

	for victim, other in (('v_player', 'v_player2'), ('v_player2', 'v_player')):
		g.restore(unit)
		place(g, victim, 160, 600)
		g.put(victim, 'obControl', 1)
		place(g, other, 64, 560)
		g.put(other, 'obControl', 0x81)
		g.write('Tails_CPU_idle_timer', 600, 2)
		spawn(g, 'S1Fireball', 160, 600, 12)
		for _ in range(12):
			g.run()
			if g.get(victim, 'obRoutine') >= 4:
				break
		assert g.get(victim, 'obRoutine') == 4, victim
		finish('real-damage-' + victim)

	# Select/place both maker and individual presets through the real Debug list.
	g.restore(stage)
	g.put('v_player2', 'code', 0)
	g.write('Debug_mode_flag', 1)
	g.buttons = {0}; g.run(2); g.buttons = set(); g.run(3)
	assert g.read('Debug_placement_type') == 1
	base = g.s['Debug_EHZ']
	rom = a.rom.read_bytes()
	count = struct.unpack_from('>H', rom, base)[0]
	entries = list(struct.iter_unpack('>IIHBBH', rom[base + 2:base + 2 + count * 14]))
	g.put('v_player', 'obX', 160, 2);g.put('v_player', 'obY', 600, 2)
	for code,subtype,flips in (('S1FireballSpawner',0x30,0),('S1FireballSpawner',0x34,2),
			('S1FireballSpawner',0x3C,1),('S1Fireball',0,0),('S1Fireball',4,2),('S1Fireball',12,1)):
		index = next(i for i, row in enumerate(entries) if row[0] == g.s[code] and row[2] == subtype)
		g.write('Debug_object', (index - 1) % count)
		g.buttons = {1}; g.run(2); g.buttons = set(); g.run(2)
		assert g.read('Debug_object') == index
		g.put('v_player', 'obRender', 4 | flips)
		g.buttons = {8}; g.run(2); g.buttons = set(); g.run(4)
		assert any((is_ball(o) if code == 'S1Fireball' else g.get(o, 'code') == g.s['S1FireballSpawner_Wait']) and
			g.get(o, 'obSubtype') == subtype for o in f.pool()), (code,subtype)
	emitted = set()
	for tick in range(240):
		g.run()
		children = [o for o in f.pool() if is_ball(o) and
			g.get(o, 'code') in flight_codes and g.get(o, 'obSubtype') in (0x30,0x34,0x3C)]
		for child in children:
			subtype = g.get(child, 'obSubtype')
			if subtype == 0x34:assert g.get(child, 'obVelY', 2) == 0x200
			if subtype == 0x3C:assert g.get(child, 'obVelX', 2) == 0xFE00
			emitted.add(subtype)
		if emitted == {0x30,0x34,0x3C}:break
	assert emitted == {0x30,0x34,0x3C}, ('Debug makers failed to emit',emitted)
	assert all(g.get(o, 'obMap', 4) == g.s['Map_Fireballs'] and
		g.get(o, 'obGfx', 2) == g.s['ArtTile_Fireball'] for o in children)
	g.run(3)
	g.video.save(a.output / 'debug-fireball-spawner.png')
	finish('real-debug-presets', count=6, emission_wait=tick + 1)
	(a.output / 'report.json').write_text(json.dumps(dict(passed=True,
		region='PAL' if a.pal else 'NTSC', checks=report), indent=2) + '\n')
	g.close()


if __name__ == '__main__':
	main()
