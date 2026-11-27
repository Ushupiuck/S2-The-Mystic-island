#!/usr/bin/env python3
"""Exercise the shared Bomb family, resident art and allocation-failure paths.

Native cases replace only terrain distance, sound and DMA boundaries. Optional
core visits use the actual act loaders, terrain, rendering and actor contacts.
"""
from pathlib import Path
import argparse
import json
import struct
from native_test_core import Native, UC_M68K_REG_D7
from check_sprite_assets import frames
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]
SENTINEL = 0x3579006F


def native(a):
	n = Native(a.rom, a.listing)
	slots = list(range(n.s['v_lvlobjspace'] & 0xFFFFFF,
		n.s['v_lvlobjend'] & 0xFFFFFF, n.s['object_size']))
	states = {v: k for k, v in n.s.items() if k == 'Bomb' or k.startswith('Bomb_')}
	states[n.s['FieryExplosion']] = 'FieryExplosion'
	updates = 0

	def probe(distance):
		for entry in ('ObjHitFloor', 'ObjHitCeiling'):
			n.cpu.mem_write(n.s[entry], bytes.fromhex('323C') + struct.pack('>h', distance) + bytes.fromhex('4E75'))
			n.cpu.ctl_remove_cache(n.s[entry], n.s[entry] + 6)

	def step(obj, entry=None):
		n.act(entry or states[n.get(obj, 'code')], obj,
			regs={UC_M68K_REG_D7: SENTINEL})
		assert n.cpu.reg_read(UC_M68K_REG_D7) == SENTINEL

	def setup(subtype=0, flip=0, index=5, zone=15):
		n.start()
		n.write('Camera_X_pos', 440, 2)
		n.write('Current_Zone', zone)
		obj = slots[index]
		for f, v, z in (('code', n.s['Bomb'], 4), ('obX', 600, 2),
			('obY', 500, 2), ('obSubtype', subtype, 2), ('obStatus', flip, 1)):
			n.put(obj, f, v, z)
		probe(-1)
		step(obj)
		probe(0)
		return obj

	# All speed nibbles construct bodies, including 4/6 (formerly internal IDs).
	# Every case checks fractional-X rollback on both roof and floor edges.
	for kind in (0, 0x10):
		for speed in range(16):
			for flip in range(4):
				obj = setup(kind | speed, flip)
				expected = speed * 64 if speed else (160 if kind else 16)
				assert n.get(obj, 'Bomb_speed', 2) == expected
				assert n.get(obj, 'obMap', 4) == n.s['Map_Bigbom' if kind else 'Map_SMZ_Bomb']
				assert n.get(obj, 'obGfx', 2) == (n.s['ArtTile_MMZ_Atlas'] | 0x8000 if kind else n.s['ArtTile_Bomb_MMZ'])
				for distance in (0, 7, -7, 8, -8, 24):
					probe(distance)
					x, y = n.get(obj, 'obX', 4), n.get(obj, 'obY', 2)
					v = n.get(obj, 'obVelX', 2)
					v -= 65536 if v & 32768 else 0
					status = n.get(obj, 'obStatus')
					step(obj, 'Bomb_SurfaceMove')
					edge = abs(distance) > 7
					assert n.get(obj, 'obX', 4) == x + (0 if edge else v * 256)
					assert n.get(obj, 'obY', 2) == y + (0 if edge else -distance if flip & 2 else distance), (kind, speed, flip, distance, y, n.get(obj, 'obY', 2), n.get(obj, 'obVelY', 2))
					assert n.get(obj, 'obStatus') == status ^ int(edge)
					updates += 1
				probe(0)

	# Triggering is per actor; dead or debug actors never arm either size.
	for kind in (0, 0x10):
		for actor in ('v_player', 'v_player2'):
			obj = setup(kind)
			for f, v, z in (('obX', 600, 2), ('obY', 450, 2), ('obRoutine', 6, 1)):
				n.put(actor, f, v, z)
			entry = 'Bomb_BigRange' if kind else 'Bomb_SmallRange'
			step(obj, entry)
			from native_test_core import UC_M68K_REG_D0
			assert n.cpu.reg_read(UC_M68K_REG_D0) == 0
			n.put(actor, 'obRoutine', 2)
			step(obj, entry)
			assert n.cpu.reg_read(UC_M68K_REG_D0) == 1
			n.write('Debug_placement_mode', 1, 2)
			step(obj, entry)
			assert n.cpu.reg_read(UC_M68K_REG_D0) == 0

	# Source gait: the first left step reverses into 205/26-update patrols.
	for subtype, period in ((0x10, 205), (0x110, 26)):
		obj = setup(subtype)
		x = n.get(obj, 'obX', 4)
		phases = []
		for tick in range(period * 4):
			step(obj)
			phases.append((n.get(obj, 'obX', 4), n.get(obj, 'obFrame')))
			updates += 1
		assert phases[0][0] == x - 0xA000
		assert phases[period][0] == x + (period - 1) * 0xA000
		assert phases[period * 2][0] == x - 0xA000
		assert [p[1] for p in phases[:26]] == [0] * 26
		assert [p[1] for p in phases[26:42]] == [1] * 16

	# Original small patrol and pause lengths survive the family merge.
	obj = setup()
	x = n.get(obj, 'obX', 4)
	for _ in range(1536):
		step(obj)
	assert n.get(obj, 'obX', 4) == x-1535*0x1000
	assert n.get(obj, 'code') == n.s['Bomb_SmallWait']
	for _ in range(180):
		step(obj)
	assert n.get(obj, 'code') == n.s['Bomb_SmallWalk']
	assert n.get(obj, 'obVelX', 2) == 16

	# Scripted charges honor speed and the triggering actor's own path.
	for speed, velocity in ((0, 0x280), (4, 0x100)):
		obj = setup(0x210 | speed)
		n.put('v_player2', 'obX', 620, 2)
		n.put('v_player2', 'obY', 500, 2)
		n.put('v_player2', 'obTopSolidBit', 14)
		step(obj)
		assert n.get(obj, 'code') == n.s['Bomb_BigWaitCharge']
		n.put('v_player2', 'obTopSolidBit', 12)
		x = n.get(obj, 'obX', 4)
		step(obj)
		for _ in range(230):
			camera = n.get(obj, 'obX', 2)-160
			n.write('Camera_X_pos', camera, 2)
			n.write('Camera_X_pos_coarse_back', (camera-128) & 0xFF80, 2)
			step(obj)
		assert n.get(obj, 'code') == n.s['Bomb_BigWaitTarget']
		assert n.get(obj, 'obX', 4) == x + 231*velocity*256
		n.put('v_player2', 'obX', n.get(obj, 'obX', 2)+20, 2)
		step(obj)
		assert n.get(obj, 'code') == n.s['Bomb_BigPreFuse']
	updates += 1536+180+2*234

	# The countdown and position agree even when the visual fuse updates first.
	for kind in (0, 0x10):
		for flip in (0, 2):
			for index in (0, 5):
				obj = setup(kind, flip, index)
				step(obj, 'Bomb_BigArm' if kind else 'Bomb_SmallArm')
				if kind:
					for _ in range(30):
						step(obj)
				child = n.get(obj, 'Bomb_child', 2) | 0xFF0000
				assert n.get(child, 'code') == n.s['Bomb_Fuse']
				assert not n.get(child, 'respawn_addr', 2)
				assert n.get(child, 'obPriority', 2) > n.get(obj, 'obPriority', 2)
				limit = 138 if kind else 144
				for tick in range(1, limit):
					for unit in sorted((obj, child)):
						step(unit)
					elapsed = max(0, tick - 60) * 0x5000 - 31 * 65536 if kind else tick * 0x1000
					if flip:
						elapsed = -elapsed
					assert n.get(child, 'obY', 4) == n.get(obj, 'obY', 4) + elapsed
					updates += 1
				step(obj)
				assert n.get(child, 'code') != n.s['Bomb_Fuse']
				if kind:
					for _ in range(32):
						step(obj)
					assert not n.get(obj, 'code')
				else:
					assert n.get(obj, 'code') == n.s['FieryExplosion']
				fragments = [p for p in slots if n.get(p, 'code') == n.s['Bomb_Debris']]
				assert len(fragments) == (7 if kind else 4)
				assert all(not n.get(p, 'respawn_addr', 2) for p in fragments)
				velocities = [(n.get(p, 'obVelX', 2), n.get(p, 'obVelY', 2)) for p in fragments]
				expected = [(-256,-1056),(-512,-1312),(-768,-1568),(256,-1056),(512,-1312),(768,-1568),(0,-800)] if kind else [(-512,-768),(-256,-512),(512,-768),(256,-512)]
				assert velocities == [(x & 65535, y & 65535) for x, y in expected]

	# Full pools cannot prevent detonation or corrupt occupied neighbors.
	for kind, duration in ((0, 144), (0x10, 200)):
		obj = setup(kind)
		for p in slots:
			if p != obj:
				n.put(p, 'code', n.s['DisplaySprite'])
		occupied = {p: bytes(n.cpu.mem_read(p, n.s['object_size'])) for p in slots if p != obj}
		step(obj, 'Bomb_BigArm' if kind else 'Bomb_SmallArm')
		for _ in range(duration):
			step(obj)
		assert n.get(obj, 'code') == (0 if kind else n.s['FieryExplosion'])
		assert all(bytes(n.cpu.mem_read(p, n.s['object_size'])) == data for p, data in occupied.items())

	# Recycling either side never transfers ownership; offscreen unload releases
	# only this placement, and may not delete somebody else's visual helper.
	for recycled in (False, True):
		obj = setup()
		n.put(obj, 'respawn_addr', 1, 2)
		n.placement_write(0, 0x80)
		step(obj, 'Bomb_SmallArm')
		child = n.get(obj, 'Bomb_child', 2) | 0xFF0000
		if recycled:
			n.put(child, 'Bomb_parent', slots[3] & 65535, 2)
		step(obj, 'Bomb_Unload')
		assert not n.get(obj, 'code') and not n.placement_read(0) & 0x80
		assert bool(n.get(child, 'code')) == recycled
		if recycled:
			step(child)
			assert not n.get(child, 'code')

	rom = a.rom.read_bytes()
	raw = (ROOT/'art/uncompressed/Enemy Bomb.unc').read_bytes()
	assert len(raw) == 41 * 32
	assert kosinski_plus_decode((ROOT/'art/moduled kosinski/Enemy Bomb.kospm').read_bytes()[2:])[0] == raw
	for act in ('SMZ1', 'SMZ2', 'SMZ3', 'SMZ4', 'LVF1', 'LVF2'):
		at = n.s['PLCKosM_' + act]
		count = struct.unpack_from('>h', rom, at)[0]+1
		requests = list(struct.iter_unpack('>IH', rom[at+2:at+2+count*6]))
		bank = n.s['ArtTile_Bomb_MMZ' if act.startswith('LVF') else 'ArtTile_Bomb']
		assert requests.count((n.s['Kospm_Bomb'], bank*32)) == 1, act
	for row in frames(rom, n.s['Map_SMZ_Bomb'], n.s['Map_SMZ_Bomb_frames']):
		for y, size, word, x in row:
			assert (word & 2047) + ((size >> 2)+1)*((size & 3)+1) <= 41
	return dict(updates=updates, speed_and_edge_cases=128*6, both_actors=True,
		full_pool_detonation=True, reciprocal_links=True, resident_small_tiles=41)


def terrain_edges(a):
	"""Run edge reversal through the assembled MD/CD floor and roof solvers."""
	from level_layout import encode
	n = Native(a.rom, a.listing)
	cases = 0
	for roof in (False, True):
		for radius in (16, 26):
			n.start()
			n.resident_terrain = True
			n.sub.mem_write(n.s['MCD_TerrainLayout_Sub'], encode([[1]*8 for _ in range(8)], [[0]]))
			n.sub.mem_write(n.s['MCD_SubMainArgument'], bytes(2))
			n.sub_call('MCD_SubTerrainInitLayout')
			n.cpu.mem_write(0x3E0000, bytes([255])*n.s['MCD_TerrainIndexCapacity'])
			n.write('v_colladdr1', 0x3E0000, 4)
			n.write('v_colladdr2', 0x3E0001, 4)
			cells = [0xF001 if x < 2 and ((y < 4) if roof else (y >= 4)) else 0
				for y in range(8) for x in range(8)]
			n.sub.mem_write(n.s['MCD_ChunkTable_SubStart']+128, struct.pack('>64H', *cells))
			obj = n.s['v_lvlobjspace'] & 0xFFFFFF
			x = (543 << 16) | 0x8000
			y = 576+radius if roof else 576-radius-1
			for f, v, z in (('obX', x, 4), ('obY', y, 2), ('obHeight', radius, 1),
				('obWidth', 12, 1), ('obStatus', 3 if roof else 1, 1), ('obVelX', 0x280, 2)):
				n.put(obj, f, v, z)
			entry = 'ObjHitCeiling' if roof else 'ObjHitFloor'
			from native_test_core import UC_M68K_REG_D1
			n.act(entry, obj)
			assert n.cpu.reg_read(UC_M68K_REG_D1) & 65535 == 0, (roof, radius, 'fixture support')
			n.act('Bomb_SurfaceMove', obj, regs={UC_M68K_REG_D7: SENTINEL})
			assert n.get(obj, 'obX', 4) == x, (roof, radius, 'walked off real terrain')
			assert n.get(obj, 'obY', 2) == y
			assert n.get(obj, 'obVelX', 2) == 0xFD80
			assert n.get(obj, 'obStatus') == (2 if roof else 0)
			assert n.cpu.reg_read(UC_M68K_REG_D7) == SENTINEL
			cases += 1
	return cases


def game(a):
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_companion_followup import isolate, spawn, place
	g = Genesis(a.core, a.rom, a.listing, a.output.with_suffix(''), a.pal,
		system_directory=a.system_directory)
	initial, report = g.save(), []
	rom = a.rom.read_bytes()

	def run(count=1):
		for _ in range(count):
			g.run()
			assert not g.read('v_errortype'), ('Bomb exception', g.frame)

	def hardware_tiles():
		visible, link = [], 0
		for _ in range(80):
			words = [int.from_bytes(bytes(g.vram[(g.s['vram_sprites'] + link*8 + j+k) ^ 1]
				for k in range(2)), 'big') for j in (0, 2, 4, 6)]
			visible.append(words[2] & 2047)
			link = words[1] & 127
			if not link:
				break
		return visible

	def bank_matches(label, raw):
		at = g.s[label] * 32
		return bytes(g.vram[(at+i) ^ 1] for i in range(len(raw))) == raw

	for zone, act, era in [(8, act, 0) for act in (0, 1)] + [
		(15, act, era) for act in (0, 1) for era in range(4)]:
		g.restore(initial)
		boot_level(g, zone=zone, act=act, timezone=era)
		isolate(g)
		cx, cy = g.read('Camera_X_pos', 2), g.read('Camera_Y_pos', 2)
		for name, value in (('Camera_Min_X_pos', cx), ('Camera_Max_X_pos', cx),
			('Camera_Max_X_pos_target', cx), ('Camera_Min_Y_pos', cy),
			('Camera_Max_Y_pos', cy), ('Camera_Max_Y_pos_target', cy)):
			g.write(name, value, 2)
		for actor in ('v_player', 'v_player2'):
			place(g, actor, cx+300, cy+40)
			g.put(actor, 'obControl', 0x81)
		stage = g.save()
		assert bank_matches('ArtTile_Bomb_MMZ' if zone == 15 else 'ArtTile_Bomb',
			(ROOT/'art/uncompressed/Enemy Bomb.unc').read_bytes()), (zone, act, era, 'Bomb module not resident')
		if zone == 15 and act == 1:
			at = (g.s['ArtTile_MMZ_Atlas']+110)*32
			raw = (ROOT/'art/uncompressed/MMZ2 Bomb and crushers.unc').read_bytes()
			assert bytes(g.vram[(at+i) ^ 1] for i in range(len(raw))) == raw
		for kind in ((0, 0x10) if zone == 15 and act == 1 else (0,)):
			for flip in (0, 2):
				g.restore(stage)
				body = spawn(g, 'Bomb', cx+140, cy+120, kind)
				g.put(body, 'obStatus', flip)
				run(3)
				mapping = 'Map_Bigbom' if kind else 'Map_SMZ_Bomb'
				base = g.s['ArtTile_MMZ_Atlas'] if kind else g.s['ArtTile_Bomb_MMZ' if zone == 15 else 'ArtTile_Bomb']
				tiles = {base+(word & 2047)
					for row in frames(rom, g.s[mapping], g.s[mapping+'_frames'])
					for y, size, word, x in row}
				assert tiles.intersection(hardware_tiles()), (zone, act, era, kind, flip, 'body missing from SAT')
				g.video.save(g.output/f'z{zone}-a{act+1}-era{era}-kind{kind}-flip{flip}-body.png')
				unit = g.save()
				for actor in ('v_player', 'v_player2'):
					for path in (12, 14):
						g.restore(unit)
						# Hold movement while ordinary touch response runs; the same
						# contact must select this actor's path, independently.
						g.put(body, 'code', g.s['Bomb_BigBurn' if kind else 'Bomb_SmallBurn'])
						g.put(body, 'Bomb_timer', 250, 2)
						g.put(body, 'obVelX', 0, 2)
						if kind:
							g.put(body, 'obSubtype', 0x210)
							g.put(body, 'obColType', g.s['Touch_Size_BigbomBody_ID'] | 0xC0)
						place(g, actor, g.get(body, 'obX', 2), g.get(body, 'obY', 2))
						g.put(actor, 'obControl', 1)
						g.put(actor, 'obTopSolidBit', path)
						run(2)
						expected = path == 12 or not kind
						assert (g.get(actor, 'obRoutine') == 4) == expected, (zone, act, era, kind, flip, actor, path, g.get(actor, 'obRoutine'))
				g.restore(unit)
				g.put(body, 'code', g.s['Bomb_BigArm' if kind else 'Bomb_SmallArm'])
				run(34 if kind else 4)
				child = g.get(body, 'Bomb_child', 2)
				assert child and g.get(child, 'code') == g.s['Bomb_Fuse']
				fuse_frames = frames(rom, g.get(child, 'obMap', 4))
				fuse_frames = fuse_frames if kind else fuse_frames[8:10]
				fuse_tiles = {base+(word & 2047) for row in fuse_frames for _, _, word, _ in row}
				body_frame = frames(rom, g.s[mapping], g.s[mapping+'_frames'])[g.get(body, 'obFrame')]
				body_tiles = [base+(word & 2047) for _, _, word, _ in body_frame]
				sat = hardware_tiles()
				body_end = next(i+len(body_tiles) for i in range(len(sat)) if sat[i:i+len(body_tiles)] == body_tiles)
				fuse_at = next(i for i, tile in enumerate(sat) if tile in fuse_tiles)
				assert body_end <= fuse_at, (zone, act, era, kind, flip, body_end, fuse_at)
				g.video.save(g.output/f'z{zone}-a{act+1}-era{era}-kind{kind}-flip{flip}-fuse.png')
				g.put(body, 'Bomb_timer', 1, 2)
				run(36 if kind else 4)
				debris = [p for p in range(g.s['v_lvlobjspace'] & 65535,
					g.s['v_lvlobjend'] & 65535, g.s['object_size']) if g.get(p, 'code') == g.s['Bomb_Debris']]
				assert len(debris) == (7 if kind else 4), (zone, act, era, kind, 'debris count', len(debris))
				g.video.save(g.output/f'z{zone}-a{act+1}-era{era}-kind{kind}-flip{flip}-burst.png')
				report.append(dict(zone=zone, act=act+1, era=era, kind=kind,
					flip=flip, actual_plc_bytes=True, both_actor_contacts=True,
					fuse=True, debris=len(debris)))
		if zone == 15 and act == 1:
			g.restore(stage)
			for actor in ('v_player', 'v_player2'):
				place(g, actor, cx+480, cy+40)
				g.put(actor, 'obControl', 0x81)
			bodies = [spawn(g, 'Bomb', cx+55+i*65, cy+120, 0x10) for i in range(4)]
			run(3)
			for i, body in enumerate(bodies):
				g.put(body, 'code', g.s['Bomb_BigBurn'])
				g.put(body, 'Bomb_timer', 250, 2)
				g.put(body, 'obFrame', i)
			run(3)
			assert all(g.get(body, 'obRender') & 0x80 for body in bodies)
			assert sum(g.get(p, 'code') == g.s['Bomb_BigBurn'] for p in range(
				g.s['v_lvlobjspace'] & 65535, g.s['v_lvlobjend'] & 65535, g.s['object_size'])) == 4
			at = (g.s['ArtTile_MMZ_Atlas']+110)*32
			raw = (ROOT/'art/uncompressed/MMZ2 Bomb and crushers.unc').read_bytes()
			assert bytes(g.vram[(at+i) ^ 1] for i in range(len(raw))) == raw
			g.video.save(g.output/f'four-bigboms-era{era}.png')
			report.append(dict(zone=zone, act=2, era=era, simultaneous_bigboms=4,
				resident_bank_unchanged=True))
	return report


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--core', type=Path)
	p.add_argument('--system-directory', type=Path)
	p.add_argument('--pal', action='store_true')
	p.add_argument('--output', type=Path, default=ROOT/'test-results/bomb.json')
	a = p.parse_args()
	report = dict(native=native(a), real_md_cd_edges=terrain_edges(a))
	if a.core:
		report['game'] = game(a)
	a.output.parent.mkdir(parents=True, exist_ok=True)
	a.output.write_text(json.dumps(report, indent=2)+'\n')
	print(json.dumps(report))


if __name__ == '__main__':
	main()
