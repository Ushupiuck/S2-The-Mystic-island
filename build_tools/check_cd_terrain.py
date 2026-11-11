#!/usr/bin/env python3
"""Compare actual MD/CD terrain calls and tilemaps with a reference ROM.

First run the previous ROM with --baseline, then pass its report as --reference.
CPU costs include the complete mailbox wait; full frames use the real scheduler.
Direct probes reset both clock origins between slices, as in the ring-job check.
"""
from pathlib import Path
import argparse
import ctypes as C
import hashlib
import json
import random
import struct

from genesis_test_core import Genesis
from check_caterkiller import CpuPrefix
from check_object_course import boot_level

ROOT = Path(__file__).resolve().parents[1]


def ground_attachment(args):
	"""Probe real planes across the S2/S3&K speed-dependent reach boundary."""
	from native_test_core import Native, UC_M68K_REG_D1, UC_M68K_REG_D7
	from level_layout import encode
	n = Native(args.rom, args.listing)
	n.start()
	n.resident_terrain = True
	n.sub.mem_write(n.s['MCD_TerrainLayout_Sub'], encode([[1]*8 for _ in range(8)], [[0]]))
	n.cpu.mem_write(0x3E0000, bytes([255])*n.s['MCD_TerrainIndexCapacity'])
	n.write('v_colladdr1', 0x3E0000, 4)
	n.write('v_colladdr2', 0x3E0001, 4)
	speeds = ((0, 0), (0, 0x900), (0x900, 0), (-0x80, 0x880),
		(0x80, -0x880), (-0x280, 0x380), (0xA00, -0xA00), (0x7F00, -0x8000))
	count = 0
	for quadrant in range(4):
		# Four rotations of a plane through the middle of chunk 1. The generic
		# full-solid profile retains the actor's current cardinal orientation.
		cells = [0xF001 if ((quadrant == 0 and y >= 4) or
			(quadrant == 1 and x < 4) or (quadrant == 2 and y < 4) or
			(quadrant == 3 and x >= 4)) else 0 for y in range(8) for x in range(8)]
		n.sub.mem_write(n.s['MCD_ChunkTable_SubStart']+128, struct.pack('>64H', *cells))
		for actor, radius in (('v_player', 19), ('v_player2', 15)):
			for path in (12, 14):
				for stick in (0, 1):
					for vx, vy in speeds:
						for gap in (-15, -14, -1, 0, *range(1, 17)):
							x, y = 560, 560
							if quadrant == 0:
								y = 576-radius-1-gap
							elif quadrant == 1:
								x = 576+radius+gap
							elif quadrant == 2:
								y = 576+radius+gap
							else:
								x = 576-radius-1-gap
							for field, value, size in (('obX', x, 2), ('obY', y, 2),
								('obHeight', radius, 1), ('obWidth', 9, 1),
								('obAngle', quadrant*64, 1), ('obStatus', 33, 1),
								('obPrevAni', 0xA5, 1), ('obTopSolidBit', path, 1),
								('obLRBSolidBit', path+1, 1), ('obVelX', vx, 2),
								('obVelY', vy, 2), ('stick_to_convex', stick, 1)):
								n.put(actor, field, value, size)
							n.write('MCD_MainToken', 0x1357, 2)
							n.act('AnglePos', actor, {UC_M68K_REG_D7: 0x24681357})
							limit = min(14, 4+abs((vx if quadrant % 2 == 0 else vy) >> 8))
							leave = gap > limit and not stick
							shift = gap if not leave and gap >= -14 else 0
							expected = (x+(0, -shift, 0, shift)[quadrant],
								y+(shift, 0, -shift, 0)[quadrant], 3 if leave else 33,
								1 if leave else 0xA5)
							actual = tuple(n.get(actor, f, z) for f, z in
								(('obX', 2), ('obY', 2), ('obStatus', 1), ('obPrevAni', 1)))
							assert actual == expected, (quadrant, actor, path, stick, vx, vy, gap, actual, expected)
							assert n.cpu.reg_read(UC_M68K_REG_D1) & 65535 == gap & 65535
							assert n.cpu.reg_read(UC_M68K_REG_D7) == 0x24681357
							assert n.read('MCD_MainToken', 2) == 0x1357, 'Ground snapshot overwrote the token'
							assert (n.get(actor, 'obVelX', 2), n.get(actor, 'obVelY', 2)) == (vx & 65535, vy & 65535)
							count += 1
	print(f'{count} ground-attachment boundaries: both actors/paths, four orientations, signed speeds and disc override.', flush=True)
	return count


def hpz_ledge(g, output):
	"""Reproduce the steep HPZ cliff with manual input, including the uphill turn."""
	from check_companion_followup import isolate, place, reset_cpu
	g.buttons = g.buttons2 = set()
	g.write('v_gamemode', g.s['SegaScreen'], 2)
	g.run()
	boot_level(g, zone=4, act=0, player=0)
	level = g.save()
	results = []
	for actor in ('v_player', 'v_player2'):
		g.restore(level)
		isolate(g)
		reset_cpu(g)
		for who in ('v_player', 'v_player2'):
			height = g.get(who, 'default_y_radius')
			place(g, who, 3066 if who == actor else 3096, 767-height, False)
			g.put(who, 'obControl', 0x81)
			g.put(who, 'invtime', 6000, 2)
			g.put(who, 'obStatusSecondary', 2)
		g.write('Camera_X_pos', 2936, 2)
		g.write('Camera_X_pos_coarse_back', (2936-128) & 0xFF80, 2)
		g.write('Camera_Y_pos', 640, 2)
		g.write('Screen_redraw_flag', 1)
		g.run(20)
		g.put(actor, 'obControl', 0)
		top = g.get(actor, 'obY', 2)
		trace = []
		for tick in range(240):
			buttons = {6} if tick < 30 else {7}
			if actor == 'v_player2':
				g.buttons2 = buttons
			else:
				g.buttons = buttons
			g.run()
			row = {f: g.get(actor, f, size) for f, size in (('obX', 2),
				('obY', 2), ('obAngle', 1), ('obStatus', 1), ('obVelX', 2), ('obVelY', 2))}
			trace.append(row)
			assert not g.read('v_errortype'), (actor, tick, 'ROM exception')
			if tick in (20, 160):
				g.video.save(output/f'hpz-{actor}-{tick}.png')
		first_air = next((i for i, row in enumerate(trace) if row['obStatus'] & 2), None)
		assert first_air is not None and trace[first_air]['obY'] <= top+4, (actor, 'Walked down the cliff', trace[:32])
		assert min(row['obX'] for row in trace[:100]) < 3000, (actor, 'Did not fall onto the lower slope')
		assert any(not row['obStatus'] & 2 and 0xC0 < row['obAngle'] < 0xFF
			for row in trace[30:]), (actor, 'Lost the slope angle after landing')
		assert not any(row['obStatus'] & 32 for row in trace[30:]), (actor, 'False wall push on the uphill turn')
		(output/f'hpz-{actor}.json').write_text(json.dumps(trace, indent=2)+'\n')
		results.append(dict(actor=actor, first_air=first_air, frames=len(trace), false_pushes=0))
		g.buttons = g.buttons2 = set()
	print('HPZ cliff: Sonic and controller-2 Tails leave the ledge, acquire slope angles and turn uphill without false pushing.', flush=True)
	return results


def main():
	p = argparse.ArgumentParser(description=__doc__)
	for n in ('core', 'output'):
		p.add_argument('--' + n, type=Path, required=True)
	p.add_argument('--system-directory', type=Path)
	p.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
	p.add_argument('--baseline', action='store_true')
	p.add_argument('--reference', type=Path)
	p.add_argument('--pal', action='store_true')
	p.add_argument('--zone', type=int, default=0)
	args = p.parse_args()
	ground_cases = 0 if args.baseline else ground_attachment(args)
	g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
				system_directory=args.system_directory)
	boot_level(g, zone=args.zone)
	stage = g.save()
	maincpu = CpuPrefix.in_dll(g.core, 'm68k')
	subcpu = CpuPrefix.in_dll(g.core, 's68k')
	g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
	g.core.s68k_set_reg.argtypes = [C.c_int, C.c_uint]
	g.core.m68k_run.argtypes = [C.c_uint]
	prg = g.memory_domains.get('PRGRAM')
	stop = g.s['Free_RAM_Start'] & 0xFFFFFF
	stack = (g.s['v_systemstack'] & 0xFFFFFF) - 4

	def act(name, regs=None):
		for cpu in (maincpu, subcpu):
			cpu.cycles = 0
			cpu.poll[0] = cpu.poll[1] = 0
		g.core.m68k_set_reg(17, 0x2700)
		for reg, value in (regs or {}).items():
			g.core.m68k_set_reg(reg, value & 0xFFFFFFFF)
		g.write(stack, stop, 4)
		g.write(stop, 0x60FE, 2)
		g.core.m68k_set_reg(15, stack)
		g.core.m68k_set_reg(16, g.s[name])
		start = maincpu.cycles
		for _ in range(300000):
			if g.core.m68k_get_reg(16) == stop:
				assert g.core.m68k_get_reg(15) == stack + 4, name
				return (maincpu.cycles - start) // 7
			g.core.m68k_run(maincpu.cycles + 1)
		gate = (C.c_uint8 * 512).from_address(C.addressof(prg) + 0x102000)
		g.core.s68k_get_reg.argtypes = [C.c_int]
		g.core.s68k_get_reg.restype = C.c_uint
		raise AssertionError((name, hex(g.core.m68k_get_reg(16)),
								'Sub', [hex(g.core.s68k_get_reg(i)) for i in (0, 6, 7, 15, 16)],
								'clocks', maincpu.cycles, subcpu.cycles,
								'gate', bytes(gate[:0x30]).hex()))

	def subwrite(name, value, size):
		address = g.s[name]
		for i, b in enumerate(value.to_bytes(size, 'big')):
			prg[(address + i) ^ 1] = b

	# Calls use the level's genuine resident collision data on both CPUs.
	cases, costs, planes = {}, {}, {}
	methods = ('AnglePos', 'CalcRoomInFront', 'sub_13102', 'loc_13146',
				'Sonic_DontRunOnWalls', 'ChkFloorEdge', 'ChkFloorEdge_Part2',
				'ObjHitFloor', 'ObjHitFloor2', 'sub_132EE', 'Sonic_HitWall',
				'ObjHitWallRight', 'ObjHitWallLeft', 'ObjHitCeiling',
				'Sonic_DoLevelCollision', 'Tails_DoLevelCollision')
	rng = random.Random(0x68000)
	points = [(rng.randrange(32, 2048), rng.randrange(160, 1024)) for _ in range(40)]
	points += [(128 + x, 944 + y) for x in (0, 7, 15, 16, 127, 128)
				for y in (-16, -1, 0, 1, 15, 16)]
	actor = g.s['v_player']
	for label in methods:
		total = 0
		for i, (x, y) in enumerate(points):
			for field, value, size in (
					('obX', x, 2), ('obY', y, 2), ('obHeight', 19, 1),
					('obWidth', 9, 1), ('obStatus', 0, 1),
					('obAngle', (i % 4) * 64, 1), ('obPrevAni', 0, 1),
					('stick_to_convex', i % 2, 1), ('obTopSolidBit', 12, 1),
					('obLRBSolidBit', 13, 1), ('obVelX', 0x280 if i % 2 else 0xFD80, 2),
					('obVelY', 0x180 if i % 4 < 2 else 0xFE80, 2),
					('obInertia', 0x1234, 2), ('default_y_radius', 19, 1),
					('default_x_radius', 9, 1), ('spindash_flag', 0, 1)):
				g.put(actor, field, value, size)
			g.write('Collision_addr', g.read('v_colladdr1', 4), 4)
			g.write('Primary_Angle', 3)
			g.write('Secondary_Angle', 3)
			if args.baseline:
				act('MCD_AcquireProgramRAM')
			else:
				subwrite('MCD_TerrainPrimary_Sub', 0x0303, 2)
				subwrite('MCD_TerrainPath_Sub', g.s['MCD_TerrainIndex_Sub'], 4)
			# These internal-style entries inherit d5's solidity bit from the
			# surrounding contact pass. Set it on the executing CPU explicitly;
			# a standalone probe must not inherit the previous method's d5.
			if label in ('Sonic_DontRunOnWalls', 'sub_132EE', 'Sonic_HitWall'):
				g.core.s68k_set_reg(5, 13)
			total += act(label, {0: (i % 4) * 64, 3: x, 5: 13, 7: 0x24681357, 8: actor})
			assert g.core.m68k_get_reg(7) == 0x24681357, label
			row = {f: g.get(actor, f, z) for f, z in (
				('obX', 2), ('obY', 2), ('obAngle', 1), ('obStatus', 1), ('obPrevAni', 1),
				('obVelX', 2), ('obVelY', 2), ('obInertia', 2), ('obHeight', 1), ('obWidth', 1))}
			if label not in ('AnglePos', 'Sonic_DoLevelCollision', 'Tails_DoLevelCollision'):
				row.update(distance=g.core.m68k_get_reg(1) & 65535,
							angle=g.core.m68k_get_reg(3) & 255)
				if label in ('sub_13102', 'loc_13146', 'Sonic_DontRunOnWalls'):
					row['other_distance'] = g.core.m68k_get_reg(0) & 65535
			cases[f'{label}/{i}'] = row
		costs[label] = total / len(points)
	(args.output / 'costs.json').write_text(json.dumps(costs, indent=2) + '\n')
	print(f'{len(cases)} complete actor/sensor operations executed.', flush=True)

	if args.reference:
		reference = json.loads(args.reference.read_text())
		assert reference['cases'] == cases, next(
			(k, reference['cases'].get(k), v) for k, v in cases.items()
			if reference['cases'].get(k) != v)

	# Full planes span multiple clock slices. Run them through retro_run so the
	# core normalizes its clocks; direct single-instruction probes can overflow
	# Genesis Plus GX's 32-bit clock-conversion multiplication on this long job.
	for x, y in ((0, 0), (112, 112), (128, 128), (496, 240), (512, 256), (1023, 1023)):
		g.restore(stage)
		for field, value in (('Camera_X_pos', x), ('Camera_Y_pos', y),
								('Camera_BG_X_pos', x // 2), ('Camera_BG_Y_pos', y // 2)):
			g.write(field, value, 2)
		g.write('Scroll_flags', 0, 4)
		g.write('Scroll_flags_BG2', 0, 4)
		g.write('Screen_redraw_flag', 0)
		code = b''
		if 'MCD_FlushDecodeDMA' in g.s:
			# Frame snapshots can hold a prepared art DMA. Keep V-int enabled
			# until its real VBlank consumes Word RAM, then disable it for drawing.
			code += bytes.fromhex('33FC813400C000044EB9') + struct.pack('>I', g.s['MCD_FlushDecodeDMA'])
		code += bytes.fromhex('33FC811400C0000433FC8F0200C00004')
		if args.baseline:
			code += bytes.fromhex('4EB9') + struct.pack('>I', g.s['MCD_RequireProgramRAM'])
		code += bytes.fromhex('4EB9') + struct.pack('>I', g.s['LoadTilesFromStart'])
		done = stop + len(code)
		code += bytes.fromhex('60FE')
		for i, value in enumerate(code):
			g.write(stop + i, value)
		for reg, value in ((17, 0x2700), (15, stack), (16, stop)):
			g.core.m68k_set_reg(reg, value)
		for frame in range(32):
			g.run()
			if g.core.m68k_get_reg(16) == done:
				break
		else:
			raise AssertionError(('Full terrain construction stalled', x, y,
									hex(g.core.m68k_get_reg(16))))
		planes[f'{x}/{y}'] = hashlib.sha256(bytes(g.vram[0xC000:0xD000]) + bytes(g.vram[0xE000:0xF000])).hexdigest()
	print('Full plane construction and VDP output executed at six wrap/boundary positions.', flush=True)

	if args.reference:
		reference = json.loads(args.reference.read_text())
		assert reference['cases'] == cases, next(
			(k, reference['cases'].get(k), v) for k, v in cases.items()
			if reference['cases'].get(k) != v)
		assert reference['planes'] == planes, (reference['planes'], planes)
		print('Distances, angles, attachment state and complete tilemaps match the reference.', flush=True)

	# Resume whole frames only from a genuine frame-boundary state.
	g.restore(stage)
	walking = []
	for frame in range(180):
		g.buttons = {7}
		g.run()
		walking.append([g.get('v_player', 'obX', 2), g.get('v_player', 'obY', 2),
						hashlib.sha256(bytes(g.vram[0xC000:0xD000]) + bytes(g.vram[0xE000:0xF000])).hexdigest()])
	g.restore(stage)
	free = slice(g.s['Free_RAM_Start'] & 65535, (g.s['Free_RAM_End'] & 65535) or 0x10000)
	canary = bytes((i * 37 + 19) & 255 for i in range(free.stop - free.start))
	g.ram[free] = canary
	gameplay = []
	for frame in range(600):
		g.buttons = {7} | ({0} if frame % 120 < 20 else set())
		g.run()
		assert not g.read('v_errortype'), frame
		assert bytes(g.ram[free]) == canary, frame
		gameplay.append([g.get('v_player', 'obX', 2), g.get('v_player', 'obY', 2),
							hashlib.sha256(bytes(g.vram[0xC000:0xD000]) + bytes(g.vram[0xE000:0xF000])).hexdigest()])
	g.video.save(args.output / 'gameplay.png')
	hpz = hpz_ledge(g, args.output) if args.zone == 4 and not args.baseline else []
	g.close()
	if args.reference:
		assert reference['walking'] == walking, next(
			(i, a, b) for i, (a, b) in enumerate(zip(reference['walking'], walking)) if a != b)
	report = dict(cases=cases, planes=planes, walking=walking, gameplay=gameplay, md_cpu_cycles=costs,
					pal=args.pal, zone=args.zone, baseline=args.baseline,
					rom_sha256=hashlib.sha256(args.rom.read_bytes()).hexdigest(),
					ground_attachment_cases=ground_cases, hpz_ledge=hpz)
	(args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
	print('600 controller-driven frames preserve the complete free MD RAM block.', flush=True)


if __name__ == '__main__':
	main()
