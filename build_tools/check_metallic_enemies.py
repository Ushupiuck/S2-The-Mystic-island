#!/usr/bin/env python3
"""Check MMZ enemy motion, independent attachments and allocation lifetimes.

Native Mecha-Bu cases stub only floor distance and sound/DMA boundaries.
Optional core scenes use the actual MMZ terrain, PLCs and touch handler.
"""
from pathlib import Path
import argparse
import json
from native_test_core import Native, UC_M68K_REG_D7

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
	g.close()
	return report


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--core', type=Path)
	p.add_argument('--system-directory', type=Path)
	p.add_argument('--pal', action='store_true')
	a = p.parse_args()
	report = {'native': native(a)}
	if a.core:
		report['game'] = game(a)
	a.output.parent.mkdir(parents=True, exist_ok=True)
	a.output.write_bytes((json.dumps(report, indent=2) + '\n').replace('\n', '\r\n').encode())
	print(json.dumps(report, indent=2))


if __name__ == '__main__':
	main()
