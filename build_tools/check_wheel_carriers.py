#!/usr/bin/env python3
"""Check wheel walls, terrain following, payloads and riders in Genesis Plus GX.

Walls use a RAM chunk with the level's real full-block collision shape. Native
GHZ terrain remains intact for the slope/bump cases. No ROM code is patched.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import isolate, place, spawn

ROOT = Path(__file__).resolve().parents[1]


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--core', type=Path, required=True)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'main.lst')
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--pal', action='store_true')
	p.add_argument('--probe', action='store_true')
	args = p.parse_args()
	g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
	checks = []
	try:
		boot_level(g, zone=0, act=0)
		isolate(g)
		length = g.s['Object_Respawn_Table_end']-g.s['Object_Respawn_Table']
		g.write('Object_Respawn_Table', int.from_bytes(b'\x80'*length, 'big'), length)
		stage = g.save()

		def setup(x, y, payload, facing, course=False, phase=0, wall_rows=(0, 1, 2, 3)):
			g.restore(stage)
			for actor in ('v_player', 'v_player2'):
				place(g, actor, x-64, y-64)
				g.put(actor, 'obControl', 0x81)
			g.write('Camera_X_pos', max(0, x-160), 2)
			g.write('Camera_X_pos_coarse_back', (max(0, x-160)-128) & 0xFF80, 2)
			g.write('Camera_Y_pos', max(0, y-112), 2)
			g.write('Collision_addr', g.read('v_colladdr1', 4), 4)
			if course:
				layout, chunks = g.terrain_address('layout'), g.terrain_address('chunks')
				ground = g.read(layout+7*256+2)
				block = g.read(chunks+ground*128+7*16, 2) | 0xF000
				shape = bytes(g.rom)[g.read('v_colladdr1', 4)+(block & 0x3FF)*2]
				assert set(bytes(g.rom)[g.s['ColArray2']+shape*16:g.s['ColArray2']+(shape+1)*16]) == {16}
				g.write(layout+6*256+4, 255)
				for row in range(8):
					for col in range(8):
						g.write(chunks+255*128+row*16+col*2, block if row >= 4 or (col in (0, 7) and row in wall_rows) else 0, 2)
			a = spawn(g, 'WheelCarrier', x, y, payload)
			g.put(a, 'obStatus', facing)
			g.run(2)
			g.write('v_framecount', phase, 2)
			return a

		def trace(a, count):
			rows = []
			for _ in range(count):
				g.run()
				assert not g.read('v_errortype'), 'ROM exception'
				assert g.get(a, 'code') == g.s['WheelCarrier']
				child = g.get(a, 'wheel_child', 4) & 65535
				assert g.get(child, 'code') == g.get(a, 'wheel_type', 4)
				assert g.get(child, 'obX', 4) == g.get(a, 'obX', 4)
				offset = g.get(a, 'wheel_offset', 2)
				offset -= 65536 if offset & 32768 else 0
				assert g.get(child, 'obY', 4) == (g.get(a, 'obY', 4)+(offset << 16)) & 0xFFFFFFFF
				rows.append([g.get(a, 'obX', 2), g.get(a, 'obY', 2), g.get(a, 'obVelX', 2), g.get(a, 'obRoutine')])
			return rows

		def finish(name, passed, **detail):
			checks.append(dict(case=name, passed=bool(passed), **detail))
			print(checks[-1], flush=True)
			assert passed or args.probe, checks[-1]

		def payload_bounds(a):
			# Independent oracle: read the child's actual resting mapping,
			# rather than duplicating the carrier's configured collision box.
			rom = bytes(g.rom)
			child = g.get(a, 'wheel_child', 4) & 65535
			base = g.get(child, 'obMap', 4)
			ptr = base+struct.unpack_from('>h', rom, base+g.get(child, 'obFrame')*2)[0]
			count = struct.unpack_from('>H', rom, ptr)[0]
			pieces = [struct.unpack_from('>bBHh', rom, ptr+2+i*6) for i in range(count)]
			left = min(x for y, size, tile, x in pieces)
			right = max(x+((size>>2)+1)*8 for y, size, tile, x in pieces)
			if g.get(child, 'obStatus') & 1:
				left, right = -right, -left
			return left, right

		for payload in range(8):
			for facing in (0, 1):
				for phase in range(4):
					a = setup(576, 824, payload, facing, True, phase)
					g.put(a, 'obY', 824 << 16, 4)
					g.put(a, 'obVelY', 0, 2)
					g.put(a, 'obRoutine', 4)
					left, right = payload_bounds(a)
					rows = trace(a, 150)
					turns = sum(a[2] != b[2] for a, b in zip(rows, rows[1:]))
					xs = [r[0] for r in rows]
					finish(f'wall-payload-{payload}-facing-{facing}-phase-{phase}',
						min(xs) >= 528-min(-8, left) and max(xs) <= 624-max(8, right) and turns >= 2,
						x_range=[min(xs), max(xs)], turns=turns)

		# The low band meets the payload but leaves room for the wheels;
		# the higher band meets only the upper part of a monitor.
		for payload in range(8):
			for facing in (0, 1):
				a = setup(576, 824, payload, facing, True, wall_rows=(2,))
				g.put(a, 'obY', 824 << 16, 4)
				g.put(a, 'obVelY', 0, 2)
				g.put(a, 'obRoutine', 4)
				left, right = payload_bounds(a)
				rows = trace(a, 150)
				xs = [r[0] for r in rows]
				turns = sum(a[2] != b[2] for a, b in zip(rows, rows[1:]))
				finish(f'payload-only-wall-{payload}-facing-{facing}',
					min(xs) >= 528-left and max(xs) <= 624-right and turns >= 2,
					x_range=[min(xs), max(xs)], turns=turns)
		for facing in (0, 1):
			a = setup(576, 824, 5, facing, True, wall_rows=(1,))
			g.put(a, 'obY', 824 << 16, 4)
			g.put(a, 'obVelY', 0, 2)
			g.put(a, 'obRoutine', 4)
			rows = trace(a, 100)
			finish(f'monitor-upper-edge-wall-facing-{facing}', all(544 <= r[0] <= 608 for r in rows))

		for facing in (0, 1):
			a = setup(552 if facing else 600, 780, 0, facing, True)
			rows = trace(a, 100)
			finish(f'airborne-wall-facing-{facing}',
				all(528 <= r[0] < 624 for r in rows) and any(a[2] != b[2] and b[3] == 2 for a, b in zip(rows, rows[1:])))

		for facing in (0, 1):
			a = setup(576, 824, 5, facing, True)
			g.put(a, 'obY', 824 << 16, 4)
			g.put(a, 'obVelY', 0, 2)
			g.put(a, 'obRoutine', 4)
			child = g.get(a, 'wheel_child', 4) & 65535
			for actor in ('v_player', 'v_player2'):
				radius = g.get(actor, 'default_y_radius')
				place(g, actor, g.get(child, 'obX', 2), 803-15-radius-3)
				g.put(actor, 'flashtime', 6000, 2)
			g.buttons2 = {4}
			both = 0
			turns = 0
			previous = g.get(a, 'obVelX', 2)
			for _ in range(150):
				trace(a, 1)
				both += all(g.get(actor, 'obStatus') & 8 for actor in ('v_player', 'v_player2'))
				turns += previous != g.get(a, 'obVelX', 2)
				previous = g.get(a, 'obVelX', 2)
			finish(f'both-riders-at-walls-facing-{facing}', both >= 120 and turns >= 2, rider_frames=both, turns=turns)

		# A reused child slot must no longer contribute its old wall box.
		a = setup(576, 824, 5, 0, True)
		g.put(a, 'obY', 824 << 16, 4)
		g.put(a, 'obVelY', 0, 2)
		g.put(a, 'obRoutine', 4)
		child = g.get(a, 'wheel_child', 4) & 65535
		g.put(child, 'code', g.s['Explosion'], 4)
		xs = []
		for _ in range(150):
			g.run()
			assert g.get(a, 'code') == g.s['WheelCarrier']
			xs.append(g.get(a, 'obX', 2))
		finish('replaced-payload-restores-wheel-clearance', not g.get(a, 'wheel_child', 4) and 608 < max(xs) <= 616 and 536 <= min(xs) < 544)

		# A real broken monitor keeps Obj26 as its code while animating the
		# shell. Attack it through the normal player/touch response, then
		# verify the intact screen's box no longer steers the carrier.
		a = setup(576, 824, 5, 0, True)
		g.put(a, 'obY', 824 << 16, 4)
		g.put(a, 'obVelY', 0, 2)
		g.put(a, 'obRoutine', 4)
		child = g.get(a, 'wheel_child', 4) & 65535
		place(g, 'v_player', g.get(child, 'obX', 2), g.get(child, 'obY', 2)-20)
		for field, value, size in (('obAnim', 2, 1), ('obStatus', 6, 1),
			('obHeight', 9, 1), ('obWidth', 7, 1), ('jumping', 1, 1), ('obVelY', 0x100, 2)):
			g.put('v_player', field, value, size)
		for _ in range(12):
			g.run()
			if g.get(child, 'obRoutine') >= 4:
				break
		assert g.get(child, 'code') == g.s['Obj26'] and g.get(child, 'obRoutine') >= 4, 'monitor was not broken'
		for actor in ('v_player', 'v_player2'):
			place(g, actor, 500, 700)
			g.put(actor, 'obControl', 0x81)
		xs = []
		for _ in range(150):
			trace(a, 1)
			xs.append(g.get(a, 'obX', 2))
		finish('broken-monitor-restores-wheel-clearance', 608 < max(xs) <= 616 and 536 <= min(xs) < 544)

		# Save native terrain traces for comparison with the previous ROM.
		terrain = {}
		for name, x, y, facing in (
			('bumps-right', 0x100, 920, 0), ('bumps-left', 0x200, 920, 1),
			('slope-right', 0x620, 840, 0), ('slope-left', 0x6F0, 910, 1),
			('curve-right', 0x700, 880, 0), ('curve-left', 0x780, 840, 1)):
			a = setup(x, y, 5, facing)
			rows = trace(a, 100)
			terrain[name] = rows
			finish(name, max(r[0] for r in rows)-min(r[0] for r in rows) > 60)
		(args.output/'terrain.json').write_text(json.dumps(terrain, indent=2)+'\n')
		(args.output/'report.json').write_text(json.dumps(dict(
			rom_sha256=hashlib.sha256(args.rom.read_bytes()).hexdigest(),
			region='PAL' if args.pal else 'NTSC', checks=checks), indent=2)+'\n')
	finally:
		g.close()


if __name__ == '__main__':
	main()
