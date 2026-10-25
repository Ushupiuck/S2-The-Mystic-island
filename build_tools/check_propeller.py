#!/usr/bin/env python3
"""Exercise Metallic Madness's propeller in the actual Genesis Plus GX core.

Checks the original CD nine-state timing with an independent interpreter,
both players' contacts, Debug placement, resident art and allocation/lifetime
failures. Direct 68000 calls isolate pool-pressure cases; normal frames handle
movement, damage, animation and loading. No ROM instructions are replaced.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct

from check_caterkiller import Fixture, ROOT
from check_companion_followup import isolate, place, spawn
from check_object_course import boot_level
from check_sprite_assets import frames


class CDPhase:
	"""Original 2/4/6/8/A/C/E/10 routine flow, before table optimization."""
	def __init__(self, upper):
		self.routine = 0xA if upper else 2
		self.timer = 0
		self.frame = 6
		self.active = False
		self.age = -1

	def step(self):
		while True:
			if self.routine in (2, 6, 0xA, 0xE):
				self.frame = 7 if self.routine == 6 else 6
				self.timer = 73 if self.routine in (6, 0xE) else 5
				if self.routine == 2: self.active = False
				if self.routine == 0xE:
					self.active = True
					self.age = -1
				self.routine += 2
			self.timer -= 1
			if self.timer:
				if self.active:
					self.age += 1
					self.frame = self.age//3 % 6
				return self.frame, self.active
			self.routine = 2 if self.routine == 0x10 else self.routine+2


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--core', type=Path, required=True)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--pal', action='store_true')
	args = p.parse_args()
	args.baseline = False
	f = Fixture(args)
	g = f.g
	report = []

	def finish(case, **detail):
		assert not g.read('v_errortype'), (case, 'ROM exception')
		report.append(dict(case=case, passed=True, **detail))
		print(report[-1], flush=True)

	def blades(a):
		return [g.get(a, name, 2) for name in ('prop_upper', 'prop_lower')]

	def group(a):
		return [a]+blades(a)

	def alive(a):
		assert g.get(a, 'code') == g.s['MM_Propeller']
		assert all(g.get(b, 'code') == g.s['MM_PropellerBlade'] for b in blades(a))

	try:
		g.core.retro_reset()
		boot_level(g, zone=0xA)
		stage = g.save()
		for filename, bank in [('MM Propeller', 'ArtTile_Propeller'), ('Wheel carrier', 'ArtTile_Wheel')]+[
			('PP '+name, 'ArtTile_PP_'+name.replace('-', '')) for name in ('Anton', 'Mosqui', 'Pata-Bata', 'Taga-Taga', 'Tamabboh')]:
			raw = (ROOT/f'art/uncompressed/{filename}.unc').read_bytes()
			base = g.s[bank]*32
			assert raw == bytes(g.vram[(base+i)^1] for i in range(len(raw))), filename
		assert len((ROOT/'art/uncompressed/MM Propeller.unc').read_bytes()) == 49*32
		assert g.s['ArtTile_Propeller_End'] <= g.s['ArtTile_Wheel']
		assert all(len(row) == 4 for row in frames((ROOT/'mappings/sprite/MM Propeller base.bin').read_bytes()))
		for filename in ('base', 'blade'):
			for row in frames((ROOT/f'mappings/sprite/MM Propeller {filename}.bin').read_bytes()):
				assert all((tile & 0x7FF)+((size >> 2)+1)*((size & 3)+1) <= 49 for _, size, tile, _ in row)
		finish('resident-art-and-mapping-bounds', tiles=49, mast_sprites=4)

		isolate(g)
		length = g.placement_capacity()
		g.placement_write(0, int.from_bytes(b'\x80'*length, 'big'), length)
		for actor in ('v_player', 'v_player2'):
			place(g, actor, 560, 312)
			g.put(actor, 'obControl', 0x81)
		g.write('Camera_X_pos', 400, 2)
		g.write('Camera_X_pos_coarse_back', 256, 2)
		g.write('Camera_Y_pos', 208, 2)
		g.write('Collision_addr', g.read('v_colladdr1', 4), 4)
		unit = g.save()

		# Over six full cycles, every frame and collision toggle must agree
		# with the unoptimized CD routine flow, not just the cycle length.
		phase_states = {}
		for facing in (0, 1):
			g.restore(unit)
			a = spawn(g, 'MM_Propeller', 480, 338)
			g.put(a, 'obStatus', facing)
			models = [CDPhase(True), CDPhase(False)]
			xs = []
			for tick in range(1000):
				g.run()
				alive(a)
				assert g.get(a, 'obY', 2) == 337
				xs.append(g.get(a, 'obX', 2))
				for i, b in enumerate(blades(a)):
					frame, active = models[i].step()
					assert g.get(b, 'obFrame') == frame, (tick, i, frame, g.get(b, 'obFrame'))
					assert bool(g.get(b, 'obColType')) == active, (tick, i, active)
					assert g.get(b, 'obX', 2) == xs[-1]
					assert g.get(b, 'obY', 2) == 337+(-44 if i == 0 else 20)
					assert bool(g.get(b, 'obRender') & 2) == bool(i)
					key = (i, 'spinning' if active else 'folded' if frame == 7 else 'transition')
					if facing == 0 and key not in phase_states and (not active or frame == 1):
						phase_states[key] = (g.save(), a, b)
				xdelta = -1 if facing else 1
				steps = tick % 256
				expected = 480+xdelta*(steps if steps <= 128 else 256-steps)
				assert xs[-1] == expected, (tick, facing, xs[-1], expected)
			finish(f'cd-cycle-and-patrol-facing-{facing}', frames=1000, x_range=[min(xs), max(xs)])
			g.video.save(args.output/f'propeller-facing-{facing}.png')

		for earlier in (1, 2):
			g.restore(unit)
			free = [slot for slot in f.pool() if not g.get(slot, 'code')]
			for slot in free[:2]: g.put(slot, 'code', g.s['ObjectMove'])
			a = spawn(g, 'MM_Propeller', 480, 338)
			for slot in free[:earlier]: g.put(slot, 'code', 0)
			models = [CDPhase(True), CDPhase(False)]
			for tick in range(400):
				g.run()
				alive(a)
				for b, model in zip(blades(a), models):
					frame, active = model.step()
					assert g.get(b, 'obFrame') == frame and bool(g.get(b, 'obColType')) == active, (earlier, tick)
					assert g.get(b, 'obY', 2) == g.get(a, 'obY', 2)+(-44 if b == blades(a)[0] else 20)
			finish(f'synchronized-with-{earlier}-earlier-blade-slots')

		for (which, phase), (state, a, b) in phase_states.items():
			for actor in ('v_player', 'v_player2'):
				for rolling in (False, True):
					g.restore(state)
					x, y = g.get(b, 'obX', 2), g.get(b, 'obY', 2)
					place(g, actor, x+24, y)
					g.put(actor, 'obStatusSecondary', 0)
					if rolling:
						for key, val in [('obAnim', 2), ('obStatus', 6), ('obHeight', 9), ('obWidth', 7), ('jumping', 1)]:
							g.put(actor, key, val)
					g.buttons2 = {4}
					g.run()
					assert (g.get(actor, 'obRoutine') == 4) == (phase == 'spinning'), (which, phase, actor, rolling)
					alive(a)
					finish(f'{actor}-blade-{which}-{phase}-'+('rolling' if rolling else 'standing'))

		for actor in ('v_player', 'v_player2'):
			state, a, b = phase_states[0, 'spinning']
			for contact in ('invincible-blade', 'mast'):
				g.restore(state)
				place(g, actor, g.get(a, 'obX', 2), g.get(b, 'obY', 2) if contact.startswith('invincible') else 322)
				g.put(actor, 'obStatusSecondary', 2 if contact.startswith('invincible') else 0)
				g.put(actor, 'invtime', 100, 2)
				g.buttons2 = {4}
				g.run()
				assert g.get(actor, 'obRoutine') == 2
				alive(a)
				finish(f'{actor}-{contact}-harmless')

		# Pool pressure and private state limits, using real 68000 calls.
		# Occupied fixture SSTs are not dispatched by these isolated calls.
		for available in (0, 1, 2):
			g.restore(unit)
			a = spawn(g, 'MM_Propeller', 480, 338)
			others = [slot for slot in f.pool() if slot != a]
			for slot in others:
				g.put(slot, 'code', 0x123456, 4)
			for slot in others[:available]: g.put(slot, 'code', 0)
			f.act('MM_Propeller', a)
			if available < 2:
				assert not g.get(a, 'prop_upper', 2) and not g.get(a, 'prop_lower', 2)
				assert not any(g.get(slot, 'code') == g.s['MM_PropellerBlade'] for slot in others)
				for slot in others[:2]: g.put(slot, 'code', 0)
				f.act('MM_Propeller', a)
			alive(a)
			for slot in group(a):
				g.write(slot+0x40, int.from_bytes(f.canary, 'big'), len(f.canary))
			for _ in range(300):
				for slot, routine in [(a, 'MM_Propeller')]+[(b, 'MM_PropellerBlade') for b in blades(a)]:
					f.act(routine, slot)
					assert g.read(slot+0x40, len(f.canary)) == int.from_bytes(f.canary, 'big')
			finish(f'pool-{available}-free-and-private-state')

		for replacement in ('foreign-parent', 'same-code-parent', 'foreign-blade'):
			g.restore(unit)
			a = spawn(g, 'MM_Propeller', 480, 338)
			g.run(12)
			parts = group(a)
			if replacement == 'foreign-blade':
				victim = parts[1]
				g.write(victim, int.from_bytes(bytes([0x5A])*g.s['object_size'], 'big'), g.s['object_size'])
				g.put(victim, 'code', g.s['ObjectMove'])
				before = g.read(victim, g.s['object_size'])
				f.act('MM_Propeller_Unload', a)
				assert g.read(victim, g.s['object_size']) == before
				assert not g.get(parts[2], 'code')
			else:
				g.write(a, 0, g.s['object_size'])
				g.put(a, 'code', g.s['MM_Propeller'] if replacement.startswith('same') else g.s['ObjectMove'])
				before = g.read(a, g.s['object_size'])
				for b in parts[1:]: f.act('MM_PropellerBlade', b)
				assert not any(g.get(b, 'code') for b in parts[1:])
				assert g.read(a, g.s['object_size']) == before
			finish('recycled-'+replacement)

		g.restore(unit)
		a = spawn(g, 'MM_Propeller', 480, 338)
		g.run(12)
		parts = group(a)
		g.write('Camera_X_pos_coarse_back', 0x1000, 2)
		f.act('MM_Propeller', a)
		assert not any(g.get(slot, 'code') for slot in parts)
		finish('dynamic-unload-removes-all-three')

		# Actual loader placement, departure and revisit (one respawn owner).
		g.restore(stage)
		for visit in range(2):
			for x in ((1600,) if visit == 0 else (400, 1600)):
				place(g, 'v_player', x, 240)
				g.put('v_player', 'obControl', 0x81)
				g.put('v_player2', 'obControl', 0x81)
				g.write('Camera_X_pos', x-160, 2)
				g.write('Camera_X_pos_coarse_back', (x-288) & 0xFF80, 2)
				g.write('Camera_Y_pos', 160, 2)
				g.run(10)
			owners = [a for a in f.pool() if g.get(a, 'code') == g.s['MM_Propeller']]
			assert len(owners) == 1, (visit, owners)
			alive(owners[0])
			assert g.get(owners[0], 'respawn_addr', 2)
			finish(f'layout-placement-visit-{visit+1}')

		# Select B7 through the real Debug menu and place it with C.
		g.restore(unit)
		base = g.s['Debug_PP']
		rom = args.rom.read_bytes()
		count = struct.unpack_from('>H', rom, base)[0]
		records = list(struct.iter_unpack('>IIBBH', rom[base+2:base+2+count*12]))
		index = next(i for i, row in enumerate(records) if row[0] == g.s['MM_Propeller'])
		g.put('v_player2', 'code', 0)
		place(g, 'v_player', 480, 338)
		g.write('Debug_mode_flag', 1)
		g.buttons = {0}; g.run(); g.buttons = set(); g.run(2)
		assert g.read('Debug_placement_type') == 1
		g.write('Debug_object', (index-1) % count)
		g.buttons = {1}; g.run(); g.buttons = set(); g.run()
		assert g.read('Debug_object') == index
		g.buttons = {8}; g.run(); g.buttons = set(); g.run(12)
		owners = [a for a in f.pool() if g.get(a, 'code') == g.s['MM_Propeller']]
		assert len(owners) == 1
		alive(owners[0])
		g.video.save(args.output/'debug-propeller.png')
		finish('real-debug-selection-and-spawn')

		# GHZ's real bumps, slopes and curves; the floor probe must remain
		# exactly on the collision surface once the mast has landed.
		for label, x, y, facing in (
			('bumps-right', 0x100, 920, 0), ('bumps-left', 0x200, 920, 1),
			('slope-right', 0x620, 840, 0), ('slope-left', 0x6F0, 910, 1),
			('curve-right', 0x700, 880, 0), ('curve-left', 0x780, 840, 1)):
			g.restore(f.initial)
			g.write('Camera_X_pos_coarse_back', max(0, x-288) & 0xFF80, 2)
			a = spawn(g, 'MM_Propeller', x, y-40)
			g.put(a, 'obStatus', facing)
			landed = 0
			for tick in range(300):
				f.act('MM_Propeller', a)
				for b in blades(a): f.act('MM_PropellerBlade', b)
				alive(a)
				if g.get(a, 'obRoutine') == 4:
					f.act('ObjHitFloor', a)
					assert not g.core.m68k_get_reg(1) & 65535, (label, tick)
					landed += 1
			assert landed > 200
			finish('native-terrain-'+label, grounded_frames=landed)

		(args.output/'report.json').write_text(json.dumps(dict(
			rom_sha256=hashlib.sha256(args.rom.read_bytes()).hexdigest(),
			region='PAL' if args.pal else 'NTSC', checks=report), indent=2)+'\n')
	finally:
		g.close()
	print(f'{len(report)} propeller checks passed', flush=True)


if __name__ == '__main__':
	main()
