#!/usr/bin/env python3
"""Run Caterkiller terrain, scratch, lifecycle and timing fixtures in Genesis Plus GX.

The real ROM routines execute against GHZ terrain. Synthetic steps/gaps use
ordinary RAM chunks and existing ROM collision shapes; no code is replaced.
Direct CPU calls isolate object cost from VDP/audio work. --baseline records
an older ROM without applying the new scratch/independent-landing assertions.
The final smoke fixtures also run complete emulator frames with both players.
"""
from pathlib import Path
import argparse
import ctypes as C
import hashlib
import json
import math

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import isolate, place, spawn

ROOT = Path(__file__).resolve().parents[1]
COMMANDS = ('flat', 'up', 'down', 'turn', 'vup', 'vdown')


class MemoryMap(C.Structure):
	_fields_ = [(name, C.c_void_p) for name in
		('base', 'read8', 'read16', 'write8', 'write16')]


class CpuPrefix(C.Structure):
	# Public core/m68k/m68k.h layout, through the master cycle counter.
	# Pointer-sized map entries keep this valid on 32- and 64-bit hosts.
	_fields_ = [('map', MemoryMap * 256), ('poll', C.c_uint * 3),
		('cycles', C.c_int), ('refresh', C.c_int), ('end', C.c_uint)]


class Fixture:
	def __init__(self, args):
		self.args = args
		self.g = g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
		self.cpu = CpuPrefix.in_dll(g.core, 'm68k')
		self.subcpu = CpuPrefix.in_dll(g.core, 's68k') if 'MCD_SubObjects' in g.s else None
		g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
		g.core.m68k_run.argtypes = [C.c_uint]
		boot_level(g, zone=0, act=0, player=0)
		self.stage = g.save()
		isolate(g)
		for a in self.pool():
			g.write(a, 0, g.s['object_size'])
		g.write('Collision_addr', g.read('v_colladdr1', 4), 4)
		self.initial = g.save()
		self.report = []
		self.canary = bytes(range(0xA0, 0xA0 + g.s['object_size'] - 0x40))

	def pool(self):
		g = self.g
		return range(g.s['v_lvlobjspace'] & 65535,
			g.s['v_lvlobjend'] & 65535, g.s['object_size'])

	def act(self, routine, obj=None, regs=None):
		g, cpu = self.g, self.cpu
		if self.subcpu is not None:
			for core_cpu in (cpu, self.subcpu):
				core_cpu.cycles = 0
				core_cpu.poll[0] = core_cpu.poll[1] = 0
		g.core.m68k_set_reg(17, 0x2700)  # isolate calls from IRQs
		g.core.m68k_set_reg(7, 0x3579006F)
		if obj is not None:
			g.core.m68k_set_reg(8, 0xFF0000 | (obj & 65535))
		for reg, value in (regs or {}).items():
			g.core.m68k_set_reg(reg, value & 0xFFFFFFFF)
		g.core.m68k_set_reg(15, 0xFF8000)
		g.write(0x8000, 0xFF8004, 4)
		g.core.m68k_set_reg(16, g.s[routine])
		start = cpu.cycles
		for _ in range(20000):
			if g.core.m68k_get_reg(16) == 0xFF8004:
				assert g.core.m68k_get_reg(15) == 0xFF8004, (routine, 'unbalanced stack')
				if routine.startswith('Cat'):
					assert g.core.m68k_get_reg(7) == 0x3579006F, (routine, 'clobbered object-loop counter')
					assert g.core.m68k_get_reg(8) & 65535 == obj & 65535, (routine, 'clobbered a0')
				return cpu.cycles - start
			g.core.m68k_run(cpu.cycles + 1)
		raise AssertionError((routine, hex(g.core.m68k_get_reg(16))))

	def floor(self, x, near_y):
		g = self.g
		a = g.s['v_player']
		g.put(a, 'obX', x, 2)
		g.put(a, 'obY', near_y, 2)
		g.put(a, 'obHeight', 0)
		self.act('ObjHitFloor', a)
		d = g.core.m68k_get_reg(1) & 65535
		return near_y + (d - 65536 if d & 32768 else d)

	def group(self, x, y, facing=0, subtype=0):
		g = self.g
		g.restore(self.initial)
		if not self.args.baseline:
			for a in self.pool():
				g.write(a + 0x40, int.from_bytes(self.canary, 'big'), len(self.canary))
		a = spawn(g, 'Caterkiller', x, y, subtype)
		if not self.args.baseline:
			g.write(a + 0x40, int.from_bytes(self.canary, 'big'), len(self.canary))
		g.put(a, 'obStatus', facing)
		g.put(a, 'obRender', facing)
		return a

	def parts(self, head):
		g = self.g
		return list(range(head, head + 4*g.s['object_size'], g.s['object_size']))

	def frame(self, head):
		g = self.g
		x = g.get(head, 'obX', 2)
		g.write('Camera_X_pos', max(0, x - 128), 2)
		g.write('Camera_X_pos_coarse_back', (max(0, x - 128) - 128) & 0xFF80, 2)
		g.write('Camera_Y_pos', max(0, g.get(head, 'obY', 2) - 128), 2)
		for priority in range(8):
			g.write(g.s['v_spritequeue'] + 128*priority, 0, 2)
		cost = 0
		for a in self.parts(head):
			if g.get(a, 'code') == g.s['Caterkiller']:
				g.put(a, 'obRender', g.get(a, 'obRender') | 128)
				cost += self.act('Caterkiller', a)
				if not self.args.baseline and g.get(a, 'code') == g.s['Caterkiller']:
					assert g.read(a + 0x40, len(self.canary)) == int.from_bytes(self.canary, 'big'), ('SST overflow', hex(a))
		return cost

	def sample(self, head):
		g = self.g
		return [{f: g.get(a, f, n) for f, n in (
			('code', 4), ('obRoutine', 1), ('ob2ndRout', 1), ('obX', 2), ('obY', 2),
			('obStatus', 1), ('obFrame', 1), ('obHeight', 1), ('cat_mode', 1),
			('cat_segment_pos', 1), ('cat_path_credit', 2))} for a in self.parts(head)]

	def finish(self, label, **details):
		assert not self.g.read('v_errortype'), (label, 'ROM exception')
		row = dict(case=label, passed=True, **details)
		self.report.append(row)
		print(row, flush=True)

	def stepped_floor(self):
		"""Repeat 8px up/down steps across a 512px floor bounded by real gaps."""
		g = self.g
		rom = bytes(g.rom)[:-1]
		collision = g.read('Collision_addr', 4) & 0xFFFFFF
		shapes = {}
		for shape in range(1, 256):
			profile = rom[g.s['ColArray1'] + shape*16:g.s['ColArray1'] + (shape+1)*16]
			for height in (8, 16):
				if profile == bytes([height])*16:
					shapes.setdefault(height, shape)
		assert len(shapes) == 2, shapes
		# Use spare entries in the live CD index, or clone the ROM index into
		# disposable MD chunk RAM. The actual collision profiles stay intact.
		if 'MCD_TerrainIndex_Sub' in g.s:
			index = 0x420000 + g.s['MCD_TerrainIndex_Sub']
		else:
			index = 0xFF7000
			g.write(index, int.from_bytes(rom[collision:collision+0x800], 'big'), 0x800)
			g.write('Collision_addr', index, 4)
		for block, height in ((0x3FE, 8), (0x3FF, 16)):
			g.write(index + block*2, shapes[height]*0x101, 2)
		layout, chunks = g.terrain_address('layout'), g.terrain_address('chunks')
		blocks = {8: 0xF3FE, 16: 0xF3FF}
		for row in range(16):
			for col in range(3, 11):
				g.write(layout + row*256 + col, 0)
		for col in range(4, 8):
			g.write(layout + 6*256 + col, 255)
		for by in range(8):
			for bx in range(8):
				block = 0 if by < 3 else blocks[8 if by == 3 and bx >= 4 else 16]
				g.write(chunks + 255*128 + by*16 + bx*2, block, 2)


def encoding_and_spacing(f):
	g = f.g
	g.restore(f.initial)
	a, parent = list(f.pool())[:2]
	values = {name: g.s['cat_floor_'+name] for name in COMMANDS}
	pattern = [values[COMMANDS[i % 6]] for i in range(16)]
	for i, value in enumerate(pattern):
		f.act('Cat_WriteFloor', a, {0: i, 1: value})
	checks = 0
	for index in range(16):
		for value in values.values():
			pattern[index] = value
			f.act('Cat_WriteFloor', a, {0: index, 1: value})
			for i, expected in enumerate(pattern):
				f.act('Cat_ReadFloor', parent, {0: i, 9: 0xFF0000 | a})
				assert g.core.m68k_get_reg(1) & 65535 == expected, (index, i, expected)
				checks += 1
	f.finish('packed-trail-neighbours', checks=checks, entries=16)

	checks = 0
	for name, value in values.items():
		for facing in (0, 1):
			g.put(a, 'obX', 500, 2)
			g.put(a, 'obY', 500, 2)
			g.put(a, 'obXSub', 0x1234, 2)
			g.put(a, 'obYSub', 0x5678, 2)
			g.put(a, 'obStatus', facing)
			f.act('Cat_ApplyPathStep', a, {0: 7, 1: value})
			dx = (-1 if facing == 0 else 1) if name in ('flat', 'up', 'down') else 0
			dy = -1 if name in ('up', 'vup') else 1 if name in ('down', 'vdown') else 0
			assert (g.get(a, 'obX', 2), g.get(a, 'obY', 2)) == (500+dx, 500+dy)
			assert g.get(a, 'obStatus') & 1 == facing ^ (name == 'turn')
			assert g.get(a, 'obXSub', 2) == 0x1234 and g.get(a, 'obYSub', 2) == 0x5678
			g.put(a, 'obX', 500, 2)
			g.put(a, 'obY', 500, 2)
			g.put(a, 'obStatus', facing)
			for parent_facing in (0, 1):
				g.put(parent, 'obStatus', parent_facing)
				# Caterkiller uses equal radii; the intact and damaged
				# Kemusi's first link has a 1px or 5px center offset.
				for anchor_delta in ((0,) if f.args.baseline else (0, 1, 5)):
					if not f.args.baseline:
						g.put(a, 'cat_anchor_delta', anchor_delta, 2)
					for px in range(-9, 10):
						for py in range(-9, 10):
							g.put(parent, 'obX', 500+px, 2)
							g.put(parent, 'obY', 500+py, 2)
							f.act('Cat_CheckSpacing', a, {0: 7, 1: value, 9: 0xFF0000 | parent})
							blocked = bool(g.core.m68k_get_reg(17) & 1)
							expected = name != 'turn' and facing == parent_facing and (px-dx)**2 + (py+anchor_delta-dy)**2 < 64
							assert blocked == expected, (name, facing, parent_facing, anchor_delta, px, py)
							checks += 1
	f.finish('command-and-spacing-semantics', checks=checks)


def terrain(f, variant=0):
	g = f.g
	cases = (
		('flat-left', 0x190, 920, 0), ('flat-right', 0x190, 920, 1),
		('bumps-left', 0x180, 920, 0), ('bumps-right', 0x100, 920, 1),
		('slope-left', 0x6F0, 910, 0), ('slope-right', 0x620, 840, 1),
		('curve-left', 0x780, 840, 0), ('curve-right', 0x700, 880, 1),
		('slope-drop-left', 0x690, 820, 0), ('slope-drop-right', 0x690, 820, 1),
		('curve-drop-left', 0x758, 820, 0), ('curve-drop-right', 0x758, 820, 1),
		('wall-right', 0x850, 840, 1), ('ledge-left', 0x900, 780, 0),
		('steps-left', 0x370, 760, 0), ('steps-right', 0x270, 760, 1))
	for label, x, y, facing in cases:
		head = f.group(x, y, facing, variant)
		if label.startswith('steps'):
			f.stepped_floor()
		costs, xs, ys, faces = [], [], [], set()
		first_lands, started = {}, None
		floor_error, minimum = 0, 1000
		previous_faces, reversing = None, None
		for frame in range(1440 if label.startswith('steps') else 960):
			costs.append(f.frame(head))
			rows = f.sample(head)
			assert all(r['code'] == g.s['Caterkiller'] for r in rows), (label, frame, rows)
			for i, row in enumerate(rows):
				if row['ob2ndRout'] in (2, 6, 0x82, 0x86):
					first_lands.setdefault(i, frame)
			if rows[0]['ob2ndRout'] in (2, 4) and started is None:
				started = frame
				if not f.args.baseline:
					assert len(first_lands) == 4, (label, 'started before every landing', first_lands)
			if started is not None:
				current_faces = [r['obStatus'] & 1 for r in rows]
				# The older object never assigned body collision radii:
				# every body center followed the head's seven-pixel offset.
				radii = [rows[0]['obHeight']]*4 if f.args.baseline else [r['obHeight'] for r in rows]
				distances = [math.hypot(rows[i]['obX'] - rows[i-1]['obX'],
					rows[i]['obY'] + radii[i] - rows[i-1]['obY'] - radii[i-1]) for i in range(1, 4)]
				if previous_faces is not None and current_faces != previous_faces:
					reversing = frame if reversing is None else reversing
				if len(set(current_faces)) == 1 and min(distances) >= 8:
					reversing = None
				if reversing is not None:
					assert frame - reversing < 300, (label, 'turn did not propagate', rows)
				previous_faces = current_faces
				for i, row in enumerate(rows):
					if frame % 8 == 0:
						surface = f.floor(row['obX'], row['obY'] + radii[i])
						floor_error = max(floor_error, abs(surface - row['obY'] - radii[i]))
					if i and reversing is None and not (row['obStatus'] ^ rows[i-1]['obStatus']) & 1:
						distance = distances[i-1]
						minimum = min(minimum, distance)
						assert distance >= 8, (label, frame, i, rows)
				faces.add(rows[0]['obStatus'] & 1)
				xs.append(rows[0]['obX'])
				ys.append(rows[0]['obY'])
		assert started is not None and max(xs)-min(xs) >= (40 if variant == 2 else 64), (label, 'stalled', started)
		if label.startswith(('wall', 'ledge')):
			assert faces == {0, 1}, (label, 'did not turn')
		if not f.args.baseline:
			assert floor_error <= 11, (label, floor_error)
		f.finish(('kemusi-' if variant == 1 else 'damaged-kemusi-' if variant == 2 else '')+label,
			first_lands=first_lands, started=started,
			minimum_spacing=round(minimum, 3), maximum_floor_error=floor_error,
			x_range=[min(xs), max(xs)], y_range=[min(ys), max(ys)],
			startup_peak_68k_cycles=round(max(costs[:started+1])/7, 2),
			mean_68k_cycles=round(sum(costs[192:])/len(costs[192:])/7, 2))


def lifecycle(f):
	g = f.g
	for lost in range(3):
		for replacement in ('Explosion', 'SpindashDust'):
			head = f.group(0x190, 920)
			for _ in range(100):
				f.frame(head)
			parent = f.parts(head)[lost]
			g.put(parent, 'code', g.s[replacement])
			before = g.read(parent, g.s['object_size'])
			f.frame(head)
			assert g.read(parent, g.s['object_size']) == before, ('modified foreign parent', lost, replacement)
			assert all(g.get(a, 'code') == 0 for a in f.parts(head)[lost+1:])
			f.finish(f'parent-{lost}-reused-by-{replacement}')
	for hit in range(4):
		head = f.group(0x190, 920)
		for _ in range(100):
			f.frame(head)
		part = f.parts(head)[hit]
		g.put(part, 'obStatus', g.get(part, 'obStatus') | 128)
		for _ in range(4):
			f.frame(head)
		assert all(g.get(a, 'obRoutine') == 12 for a in f.parts(head)), ('scatter propagation', hit)
		assert all(g.get(a, 'obXSub', 2) in (0, 0x8000) for a in f.parts(head))
		for _ in range(120):
			f.frame(head)
		f.finish(f'scatter-from-part-{hit}')
	for free in range(3):
		head = f.group(0x190, 920)
		pool = list(f.pool())
		for a in pool[free+1:]:
			g.put(a, 'code', g.s['SpindashDust'])
		owner = g.placement_handle(0)
		g.placement_write(0, 0x80)
		g.put(head, 'respawn_addr', owner, 2)
		f.frame(head)
		assert g.get(head, 'obRoutine') == 10 and not g.placement_read() & 128
		f.frame(head)
		assert all(g.get(a, 'code') != g.s['Caterkiller'] for a in pool)
		f.finish(f'partial-allocation-{free}')
	for lost in (0, 1, 2, 3):
		head = f.group(0x190, 600)
		f.frame(head)
		g.put(f.parts(head)[lost], 'obY', 0x810, 2)
		for _ in range(100):
			f.frame(head)
		assert all(g.get(a, 'code') != g.s['Caterkiller'] for a in f.parts(head))
		f.finish(f'lost-landing-part-{lost}')
	# Allocation is allowed to skip occupied slots. Every link must still
	# refer to the preceding piece, and all four must leave landing together.
	head = f.group(0x190, 920)
	gap = f.parts(head)[1]
	g.put(gap, 'code', g.s['SpindashDust'])
	for frame in range(120):
		for priority in range(8):
			g.write(g.s['v_spritequeue'] + 128*priority, 0, 2)
		for a in f.pool():
			if g.get(a, 'code') == g.s['Caterkiller']:
				f.act('Caterkiller', a)
	parts = [a for a in f.pool() if g.get(a, 'code') == g.s['Caterkiller']]
	assert len(parts) == 4 and gap not in parts
	assert all(g.get(a, 'cat_parent', 2) == parts[i-1] for i, a in enumerate(parts) if i)
	assert all(g.get(a, 'ob2ndRout') in (2, 4) for a in parts)
	f.finish('noncontiguous-allocation-and-word-links')


def complete_frames(f):
	g = f.g
	actors = ('v_player', 'v_player2')

	def scene():
		g.restore(f.stage)
		isolate(g)
		for actor, x in zip(actors, (0x310, 0x300)):
			place(g, actor, x, 0x3A0)
			g.put(actor, 'obControl', 0x81)
		g.write('Camera_X_pos', 0x260, 2)
		g.write('Camera_X_pos_coarse_back', 0x180, 2)
		g.write('Camera_Y_pos', 0x320, 2)
		g.buttons2 = {4}
		return spawn(g, 'Caterkiller', 0x360, 920)

	head = scene()
	frames = set()
	for _ in range(360):
		g.run()
		parts = [a for a in f.pool() if g.get(a, 'code') == g.s['Caterkiller']]
		assert len(parts) == 4, ('complete-frame patrol', parts)
		frames.add(g.get(head, 'obFrame'))
	assert len(frames) > 8 and g.get(head, 'obX', 2) < 0x320
	f.finish('complete-frame-patrol', frames=360, head_animation_frames=len(frames))

	for actor in actors:
		for target in ('head', 'body'):
			head = scene()
			g.run(100)
			parts = [a for a in f.pool() if g.get(a, 'code') == g.s['Caterkiller']]
			part = head if target == 'head' else parts[-1]
			g.write('v_rings', 99, 2)
			for other in actors:
				if other != actor:
					place(g, other, 0x300, 0x3A0)
			place(g, actor, g.get(part, 'obX', 2), g.get(part, 'obY', 2)-8)
			for field, value, size in (
				('obControl', 0, 1), ('obAnim', 2, 1), ('obStatus', 6, 1),
				('obHeight', 9, 1), ('obWidth', 7, 1), ('jumping', 1, 1), ('obVelY', 0x100, 2)):
				g.put(actor, field, value, size)
			for _ in range(12):
				g.run()
				if target == 'head' and g.get(head, 'code') != g.s['Caterkiller']:
					break
				if target == 'body' and g.get(actor, 'obRoutine') == 4:
					break
			if target == 'head':
				assert g.get(head, 'code') == g.s['Explosion'], (actor, target, hex(g.get(head, 'code')))
				g.run(2)
				assert not any(g.get(a, 'code') == g.s['Caterkiller'] for a in parts)
			else:
				assert g.get(actor, 'obRoutine') == 4, (actor, target, g.get(actor, 'obRoutine'))
				g.run(4)
				assert all(g.get(a, 'code') != g.s['Caterkiller'] or g.get(a, 'obRoutine') in (10, 12) for a in parts)
			f.finish(f'complete-frame-{actor}-hits-{target}')


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--core', type=Path, required=True)
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--pal', action='store_true')
	p.add_argument('--baseline', action='store_true')
	args = p.parse_args()
	f = Fixture(args)
	try:
		encoding_and_spacing(f)
		terrain(f)
		if not args.baseline:
			terrain(f, 1)
			terrain(f, 2)
			lifecycle(f)
			complete_frames(f)
		(args.output/'report.json').write_text(json.dumps(dict(
			rom_sha256=hashlib.sha256(args.rom.read_bytes()).hexdigest(),
			region='PAL' if args.pal else 'NTSC', baseline=args.baseline,
			cases=f.report), indent=2) + '\n')
	finally:
		f.g.close()
	print('Caterkiller checks passed', flush=True)


if __name__ == '__main__':
	main()
