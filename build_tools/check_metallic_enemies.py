#!/usr/bin/env python3
"""Check MMZ enemy motion, independent attachments and allocation lifetimes.

Native Mecha-Bu cases stub only floor distance and sound/DMA boundaries.
Optional core scenes use the actual MMZ terrain, PLCs and touch handler.
"""
from pathlib import Path
import argparse
import json
import struct
from native_test_core import Native, UC_M68K_REG_A1, UC_M68K_REG_D7

ROOT = Path(__file__).resolve().parents[1]
SENTINEL = 0x3579006F


def native(a):
	n = Native(a.rom, a.listing)
	# Flat floor is an explicit boundary; actor contact uses the real handler.
	n.cpu.mem_write(n.s['ObjHitFloor'], bytes.fromhex('72004E75'))
	slots = list(range(n.s['v_lvlobjspace'] & 0xFFFFFF,
		n.s['v_lvlobjend'] & 0xFFFFFF, n.s['object_size']))
	states = {n.s[name]: name for name in
		('MMZ_MechaBu', 'MMZ_MechaBu_Fall', 'MMZ_MechaBu_Walk', 'MMZ_MechaBu_Blade')}

	def step(obj, entry=None):
		n.act(entry or states[n.get(obj, 'code')], obj,
			regs={UC_M68K_REG_D7: SENTINEL})
		assert n.cpu.reg_read(UC_M68K_REG_D7) == SENTINEL

	def setup(subtype=0, flip=0, index=5, era=0):
		n.start()
		n.write('Camera_X_pos', 440, 2)
		n.write('Current_Timezone', era)
		body = slots[index]
		for field, value, size in (('code', n.s['MMZ_MechaBu'], 4),
			('obX', 600, 2), ('obY', 500, 2), ('obSubtype', subtype, 2),
			('obStatus', flip, 1)):
			n.put(body, field, value, size)
		return body

	updates = 0
	for subtype in (0, 1):
		for flip in (0, 1):
			for index in (0, 5):
				body = setup(subtype, flip, index)
				step(body)
				blade = n.get(body, 'MMZ_bu_child', 2) | 0xFF0000
				assert blade != body and n.get(blade, 'code') == n.s['MMZ_MechaBu_Blade']
				assert not n.get(blade, 'respawn_addr', 2)
				assert n.get(body, 'obColType') == n.s['Touch_Size_MMZMechaBu_ID']
				assert n.get(blade, 'obColType') == 0x89
				assert n.get(body, 'obGfx', 2) == n.s['ArtTile_MMZ_Atlas']
				assert n.get(blade, 'obGfx', 2) == n.s['ArtTile_MMZ_Atlas']
				n.put(body, 'code', n.s['MMZ_MechaBu_Walk'])
				origin = n.get(body, 'obX', 4)
				positions, frames = [], set()
				for tick in range(1000):
					# The allocator can place the child before or after the root.
					for obj in sorted((body, blade)):
						step(obj)
					phase = (tick // 61) & 1
					anim = 0 if subtype else phase ^ 1
					assert n.get(blade, 'obAnim') == anim
					dx, dy = (-19, -15) if anim else (-25, 0)
					if flip:
						dx = -dx
					assert n.get(blade, 'obX', 2) == n.get(body, 'obX', 2) + dx
					assert n.get(blade, 'obY', 2) == n.get(body, 'obY', 2) + dy
					positions.append(n.get(body, 'obX', 4))
					frames.add(n.get(blade, 'obFrame'))
					updates += 1
				# CD steps left once, then holds each patrol direction for 410 updates.
				assert positions[0] == origin - 0x5000
				assert positions[410] == origin + 409 * 0x5000
				assert positions[820] == origin - 0x5000
				assert frames == ({0, 1} if subtype else {0, 1, 2, 3})

	# A full pool changes no root fields and never borrows another placement.
	body = setup()
	for obj in slots:
		if obj != body:
			n.put(obj, 'code', n.s['DisplaySprite'])
	before = bytes(n.cpu.mem_read(body, n.s['object_size']))
	step(body)
	assert bytes(n.cpu.mem_read(body, n.s['object_size'])) == before
	n.put(slots[2], 'code', 0)
	step(body)
	assert n.get(body, 'MMZ_bu_child', 2) == slots[2] & 65535

	# A destroyed or same-family recycled owner cannot retain an old blade.
	for recycled in (False, True):
		body = setup()
		step(body)
		blade = n.get(body, 'MMZ_bu_child', 2) | 0xFF0000
		if recycled:
			n.put(body, 'MMZ_bu_child', slots[3] & 65535, 2)
		else:
			n.put(body, 'code', n.s['Explosion'])
		step(blade)
		assert not n.get(blade, 'code')

	# Unload releases the root's placement and deletes only its matching child.
	for recycled in (False, True):
		body = setup()
		n.put(body, 'respawn_addr', 1, 2)
		n.placement_write(0, 0x80)
		step(body)
		blade = n.get(body, 'MMZ_bu_child', 2) | 0xFF0000
		if recycled:
			n.put(blade, 'MMZ_bu_parent', slots[3] & 65535, 2)
		n.act('MMZ_MechaBu_Unload', body)
		assert not n.get(body, 'code') and not n.placement_read(0) & 0x80
		assert bool(n.get(blade, 'code')) == recycled

	for era in range(4):
		body = setup(era=era)
		step(body)
		assert bool(n.get(body, 'code')) == (era != 2)

	rom = a.rom.read_bytes()
	assert rom[n.s['Touch_Sizes'] + (n.s['Touch_Size_MMZMechaBu_ID'] - 1) * 2:][:2] == bytes((16, 14))
	return dict(motion_updates=updates, both_slot_orders=True, full_pool_retry=True,
		recycled_links=True, placement_release=True, good_future_suppression=True)


def dango_native(a):
	n = Native(a.rom, a.listing)
	s = n.s
	body = s['v_lvlobjspace']
	# Test state timing on level ground and cross the actual touch dispatcher.
	for label in ('ObjHitFloor', 'ObjHitWallLeft', 'ObjHitWallRight'):
		n.cpu.mem_write(s[label], bytes.fromhex('72004E75'))
	cases = []
	for subtype in (0, 1):
		for actor, facing in (('v_player', 0), ('v_player2', 1)):
			n.start()
			n.write('Camera_X_pos', 440, 2)
			n.put(body, 'code', s['MMZ_Dango'])
			n.put(body, 'obSubtype', subtype)
			n.put(body, 'obStatus', facing)
			n.put(body, 'obX', 600, 2)
			n.put(body, 'obY', 500, 2)
			n.act('MMZ_Dango', body)
			n.put(body, 'obRoutine', 4)
			n.act('MMZ_Dango_WalkSpeed', body)
			direction = 1 if facing else -1
			foot = n.get(body, 'obY', 2)+9
			assert n.get(body, 'obVelX', 2) == (direction*(0x10 if subtype else 0x60)) & 0xFFFF
			for rider in ('v_player', 'v_player2'):
				n.put(rider, 'obX', 600-direction*64, 2)
				n.put(rider, 'obY', 500, 2)
			n.act('MMZ_Dango_Run', body)
			assert n.get(body, 'obRoutine') == 4, (subtype, actor, 'target behind')
			n.put(actor, 'obX', 600+direction*64, 2)
			for _ in range(160):
				n.act('MMZ_Dango_Run', body)
				assert n.get(body, 'obY', 2)+n.get(body, 'obHeight') == foot
				if n.get(body, 'obRoutine') == 14:
					break
			else:
				raise AssertionError((subtype, actor, 'no roll'))
			assert n.get(body, 'obVelX', 2) == (direction*(0x100 if subtype else 0x400)) & 0xFFFF
			assert n.get(body, 'obColType') == 0xC0|s['Touch_Size_DangoShell_ID']
			for _ in range(160):
				n.act('MMZ_Dango_Run', body)
				assert n.get(body, 'obY', 2)+n.get(body, 'obHeight') == foot
				if n.get(body, 'obRoutine') == 4:
					break
			else:
				raise AssertionError((subtype, actor, 'no unroll'))
			assert n.get(body, 'obColType') == s['Touch_Size_DangoBody_ID']

			n.put(body, 'obRoutine', 14)
			n.put(body, 'obColType', 0xC0|s['Touch_Size_DangoShell_ID'])
			n.put(actor, 'obX', n.get(body, 'obX', 2)+16, 2)
			n.put(actor, 'obY', n.get(body, 'obY', 2)-8, 2)
			n.put(actor, 'obAnim', s['AniIDSonAni_Roll'])
			n.put(actor, 'obStatus', 6)
			n.act('Touch_Special', actor, regs={UC_M68K_REG_A1:body})
			assert n.get(body, 'obRoutine') == s['MMZ_Dango_Rebounding']
			assert 0 < n.get(actor, 'obVelX', 2) < 0x8000
			assert n.get(actor, 'obVelY', 2) >= 0x8000
			assert n.get(body, 'obVelX', 2) == (-n.get(actor, 'obVelX', 2)) & 0xFFFF
			assert n.get(actor, 'obRoutine') == 2
			cases.append(dict(subtype=subtype, actor=actor, facing=facing))
	return cases


def poh_bee_native(a):
	"""Follow both patrol and pendulum profiles through several reversals."""
	n = Native(a.rom, a.listing)
	s = n.s
	body = s['v_lvlobjspace']
	sine = struct.unpack_from('>256h', a.rom.read_bytes(), s['Sine_Data'])
	results = []

	for subtype in (0, 1):
		n.start()
		n.write('Camera_X_pos_coarse_back', 384, 2)
		n.put(body, 'code', s['MMZ_PohBee'])
		n.put(body, 'obSubtype', subtype)
		n.put(body, 'obX', 600, 2)
		n.put(body, 'obY', 500, 2)
		n.act('MMZ_PohBee', body)

		x, vx, turn, phase = 600 << 16, -128 if subtype else -256, 0, 0
		chains = [('poh_long_tip', 'poh_long_links', 2, 0x800, 5)]
		if not subtype:
			chains.append(('poh_short_tip', 'poh_short_links', 1, 0x1000, 4))
		angles = [[initial, 0, 8] for _, _, _, initial, _ in chains]
		assert n.get(body, 'platgroup_count') == (3 if subtype else 5)
		for tick in range(550):
			x += vx << 8
			turn -= 1
			if turn < 0:
				turn = 256 if subtype else 128
				vx = -vx
			phase = (phase+(0x300 if subtype else 0x400)) & 0xFFFF
			y = (500 << 16)+(sine[phase >> 8] << (12 if subtype else 13))
			assert (n.get(body, 'obX', 4), n.get(body, 'obY', 4)) == (x, y), (subtype, tick, 'patrol')
			for (tip, links, group_count, _, group_length), angle in zip(chains, angles):
				previous, speed, accel = angle
				speed += accel
				current = (previous+speed) & 0xFFFF
				if (previous < 0x4000) != (current < 0x4000):
					accel = -accel
				angle[:] = [current, speed, accel]
				index = current >> 8
				dx, dy = sine[(index+64) & 255] << 11, sine[index] << 11
				harmful = n.get(body, tip, 2) | 0xFF0000
				last = 1+group_count*group_length
				assert n.get(harmful, 'obX', 4) == x+last*dx
				assert n.get(harmful, 'obY', 4) == y+(12 << 16)+last*dy
				assert n.get(harmful, 'obColType') == 0x8B
				segment = 1
				for group_index in range(group_count):
					group = n.get(body+2*group_index, links, 2) | 0xFF0000
					assert n.get(group, 'mainspr_childsprites') == group_length-1
					for j in range(group_length):
						xfield, yfield = ('obX', 'obY') if not j else (f'sub{j+1}_x_pos', f'sub{j+1}_y_pos')
						assert n.get(group, xfield, 2) == (x+segment*dx) >> 16
						assert n.get(group, yfield, 2) == (y+(12 << 16)+segment*dy) >> 16
						segment += 1
			n.act('MMZ_PohBee_Move', body, regs={UC_M68K_REG_D7:0x13572468})
			assert n.cpu.reg_read(UC_M68K_REG_D7) == 0x13572468

		tip = n.get(body, 'poh_long_tip', 2) | 0xFF0000
		n.write('v_rings', 10, 2)
		n.write('Collision_response_list', 0xFFFF, 2)
		for actor in ('v_player', 'v_player2'):
			n.put(actor, 'obX', n.get(tip, 'obX', 2), 2)
			n.put(actor, 'obY', n.get(tip, 'obY', 2), 2)
			n.act('TouchResponse', actor)
			assert n.get(actor, 'obRoutine') == 4, (subtype, actor)
		results.append(dict(subtype=subtype, updates=550, both_players_hurt=True))
	return results


def game(a):
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_companion_followup import isolate, place, spawn, reset_cpu
	from check_sprite_assets import frames
	g = Genesis(a.core, a.rom, a.listing, a.output.with_suffix(''), a.pal,
		system_directory=a.system_directory)
	initial, report = g.save(), []
	rom = a.rom.read_bytes()
	states = {g.s['MMZ_MechaBu_Fall'], g.s['MMZ_MechaBu_Walk']}
	body_tiles = {g.s['ArtTile_MMZ_Atlas'] + (w & 2047)
		for row in frames(rom, g.s['Map_MMZ_MechaBu'], g.s['Map_MMZ_MechaBu_frames'])
		for y, size, w, x in row}
	blade_tiles = {g.s['ArtTile_MMZ_Atlas'] + (w & 2047)
		for row in frames(rom, g.s['Map_MMZ_MechaBuSaw'], g.s['Map_MMZ_MechaBuSaw_frames'])
		for y, size, w, x in row}
	def run(count=1):
		for _ in range(count):
			g.run()
			assert not g.read('v_errortype'), ('MMZ enemy exception', g.frame)
	def hardware_tiles():
		visible, link = set(), 0
		for _ in range(80):
			words = [int.from_bytes(bytes(g.vram[(g.s['vram_sprites'] + link*8 + j+k) ^ 1]
				for k in range(2)), 'big') for j in (0, 2, 4, 6)]
			visible.add(words[2] & 2047)
			link = words[1] & 127
			if not link:
				break
		return visible
	for act in (0, 1):
		for era in range(4):
			g.restore(initial)
			boot_level(g, zone=15, act=act, timezone=era)
			isolate(g)
			camx, camy = g.read('Camera_X_pos', 2), g.read('Camera_Y_pos', 2)
			for name, value in (('Camera_Min_X_pos', camx), ('Camera_Max_X_pos', camx),
				('Camera_Max_X_pos_target', camx), ('Camera_Min_Y_pos', camy),
				('Camera_Max_Y_pos', camy), ('Camera_Max_Y_pos_target', camy)):
				g.write(name, value, 2)
			for actor in ('v_player', 'v_player2'):
				place(g, actor, camx+280, camy+40)
				g.put(actor, 'obControl', 0x81)
			stage = g.save()
			for flip in (0, 1):
				g.restore(stage)
				body = spawn(g, 'MMZ_MechaBu', camx+150, camy+120)
				g.put(body, 'obStatus', flip)
				run(3)
				if era == 2:
					assert not g.get(body, 'code')
					continue
				blade = g.get(body, 'MMZ_bu_child', 2)
				assert g.get(blade, 'code') == g.s['MMZ_MechaBu_Blade']
				for _ in range(120):
					run()
					assert g.get(body, 'code') in states
					dx = g.get(blade, 'MMZ_bu_dx', 2)
					dx -= 65536 if dx & 32768 else 0
					assert g.get(blade, 'obX', 2) == g.get(body, 'obX', 2)+dx
				for _ in range(6):
					visible = hardware_tiles()
					if visible & body_tiles and visible & blade_tiles:
						break
					run()
				else:
					raise AssertionError((act, era, flip, 'Mecha-Bu missing from hardware SAT'))
				g.video.save(g.output/f'act{act+1}-era{era}-flip{flip}.png')
				unit = g.save()
				for actor in ('v_player', 'v_player2'):
					g.restore(unit)
					place(g, actor, g.get(body, 'obX', 2) + (-8 if flip else 8),
						g.get(body, 'obY', 2)-4)
					for field, value, size in (('obAnim', 2, 1), ('obStatus', 6, 1),
						('obHeight', 9, 1), ('obWidth', 7, 1), ('jumping', 1, 1),
						('obVelY', 0x100, 2), ('obStatusSecondary', 0, 1), ('obControl', 1, 1)):
						g.put(actor, field, value, size)
					g.buttons2 = {4}
					reset_cpu(g)
					run(10)
					assert g.get(body, 'code') not in states, (act, era, flip, actor, 'body survives rolling hit')
					assert g.get(blade, 'code') != g.s['MMZ_MechaBu_Blade'], (act, era, flip, actor, 'orphan blade survives hit')
					g.restore(unit)
					place(g, actor, g.get(blade, 'obX', 2)+(10 if flip else -10),
						g.get(blade, 'obY', 2))
					g.put(actor, 'obStatusSecondary', 0)
					g.put(actor, 'obControl', 1)
					g.write('v_rings', 10, 2)
					g.buttons2 = {4}
					reset_cpu(g)
					run(8)
					assert g.get(actor, 'obRoutine') == 4, (act, era, flip, actor, 'blade did not hurt')
					assert g.get(body, 'code') in states
			report.append(dict(act=act+1, era=era, suppressed=era == 2,
				both_facings=True, both_actors=True))
	report.extend(dango_game(g, initial, hardware_tiles))
	report.extend(poh_bee_game(g, initial, hardware_tiles))
	g.close()
	return report


def dango_game(g, initial, hardware_tiles):
	from check_object_course import boot_level
	from check_rising_crushers import seek
	from check_sprite_assets import frames
	from object_layout import decode

	s = g.s
	slots = range(s['v_lvlobjspace'] & 0xFFFF, s['v_lvlobjend'] & 0xFFFF, s['object_size'])
	rows = decode((ROOT/'level/objects/LV0F_2.bin').read_bytes())
	assert sum(row[2] == 0xBA for row in rows) == 8
	rom = bytes(g.rom)
	tiles = [
		{s['ArtTile_MMZ_Atlas']+(word & 2047)
			for row in frames(rom, s[map_label], s[map_label+'_frames'])
			for _, _, word, _ in row}
		for map_label in ('Map_MMZ_Dango', 'Map_MMZ_DangoSlow')
	]
	report = []
	for era, presence in enumerate((0x40, 0x20, 0x80, 0x80)):
		g.restore(initial)
		g.buttons, g.buttons2 = set(), set()
		boot_level(g, zone=15, act=1, timezone=era)
		level = g.save()
		seen = 0
		for index, (x, y, oid, mask, subtype) in enumerate(rows):
			if oid != 0xBA or not mask & presence:
				continue
			assert subtype in (0, 1)
			g.restore(level)
			seek(g, x, y)
			handle = g.placement_handle(index)
			for _ in range(40):
				assert not g.read('v_errortype')
				body = next((slot for slot in slots if g.get(slot, 'code')
					and g.get(slot, 'respawn_addr', 2) == handle), None)
				if era == 2:
					if body is None and g.placement_read(index) & 0x80:
						break
				elif body is not None and g.get(body, 'code') == s['MMZ_Dango_Run'] and hardware_tiles() & tiles[subtype]:
					break
				g.run()
			else:
				raise AssertionError((era, x, y, 'Dango did not reach its expected era state'))
			if era == 2:
				continue
			assert g.get(body, 'obSubtype', 2) == subtype
			assert g.get(body, 'obMap', 4) == s['Map_MMZ_DangoSlow' if subtype else 'Map_MMZ_Dango']
			g.video.save(g.output/f'dango-era{era}-{x:04x}.png')
			seen += 1
		report.append(dict(era=era, dango_placements=seen, suppressed=era==2))
	return report


def poh_bee_game(g, initial, hardware_tiles):
	from check_object_course import boot_level
	from check_rising_crushers import seek
	from check_sprite_assets import frames
	from object_layout import decode

	rows = decode((ROOT/'level/objects/LV0F_1.bin').read_bytes())
	assert sum(row[2] == 0xBE for row in rows) == 5
	s = g.s
	slots = range(s['v_lvlobjspace'] & 65535, s['v_lvlobjend'] & 65535, s['object_size'])
	tips = []
	for label in ('Map_MMZ_PohBee', 'Map_MMZ_PohBeeSlow'):
		row = frames(bytes(g.rom), s[label], 5)[3]
		tips.append(s['ArtTile_MMZ_Atlas']+(row[0][2]&2047))
	results = []
	for era, mask in enumerate((0x40, 0x20, 0x80, 0x80)):
		g.restore(initial)
		g.buttons, g.buttons2 = set(), set()
		boot_level(g, zone=15, timezone=era)
		level = g.save()
		seen = 0
		for index, (x, y, oid, eras, subtype) in enumerate(rows):
			if oid != 0xBE or not eras & mask:
				continue
			g.restore(level)
			seek(g, x, max(y+60, 132))
			handle = g.placement_handle(index)
			for _ in range(40):
				assert not g.read('v_errortype')
				body = next((slot for slot in slots if g.get(slot, 'code')
					and g.get(slot, 'respawn_addr', 2) == handle), None)
				if era == 2:
					if body is None and g.placement_read(index) & 0x80:
						break
				elif body is not None and g.get(body, 'platgroup_state', 4) == s['MMZ_PohBee_Move'] and tips[subtype] in hardware_tiles():
					break
				g.run()
			else:
				raise AssertionError((era,x,y,subtype,'Poh Bee failed to appear in its intended era'))
			if era != 2:
				assert g.get(body, 'platgroup_count') == (3 if subtype else 5)
				g.video.save(g.output/f'poh-bee-era{era}-{x:04x}.png')
				seen += 1
		results.append(dict(era=era, poh_bee_placements=seen, suppressed=era==2))
	return results


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--core', type=Path)
	p.add_argument('--system-directory', type=Path)
	p.add_argument('--pal', action='store_true')
	a = p.parse_args()
	report = {'native': native(a), 'dango_native': dango_native(a), 'poh_bee_native': poh_bee_native(a)}
	if a.core:
		report['game'] = game(a)
	a.output.parent.mkdir(parents=True, exist_ok=True)
	a.output.write_bytes((json.dumps(report, indent=2) + '\n').replace('\n', '\r\n').encode())
	print(json.dumps(report, indent=2))


if __name__ == '__main__':
	main()
