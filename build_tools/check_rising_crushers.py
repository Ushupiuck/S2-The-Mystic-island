#!/usr/bin/env python3
"""Test terrain clearance over the authored Metallic Madness crushers."""
import argparse
from pathlib import Path

from check_companion_followup import place
from check_object_course import boot_level
from genesis_test_core import Genesis

ACTORS = ('v_player', 'v_player2')
DOWN, ACTION, RIGHT, LEFT = 5, 0, 7, 6
RISE_FRAMES = 128
SNUG = (1, 0x1120, 0x032E)
TIGHT = (2, 0x1D61, 0x02AD)
OPEN = (1, 0x1721, 0x067F)


def stage(g, initial, scene, era):
	act, x, y = scene
	g.restore(initial)
	g.buttons, g.buttons2 = set(), set()
	boot_level(g, zone=15, act=act-1, timezone=era)
	for actor in ACTORS:
		place(g, actor, x, y-56)
		g.put(actor, 'obControl', 0x81)
	g.write('Camera_X_pos', x-152, 2)
	g.write('Camera_Y_pos', y-132, 2)
	g.write('Screen_redraw_flag', 1)
	g.run(32)
	s = g.s
	slots = range(s['v_lvlobjspace'] & 0xFFFF, s['v_lvlobjend'] & 0xFFFF, s['object_size'])
	piston = next(slot for slot in slots if g.get(slot, 'code') == s['Stomper_Run']
		and g.get(slot, 'stomper_origin_x', 2) == x and g.get(slot, 'stomper_origin_y', 2) == y)
	return piston, g.save()


def board(g, actor, piston, path):
	s = g.s
	height_table = g.get(piston, 'MMZ_crush_heights', 4)
	y = g.get(piston, 'stomper_origin_y', 2) + g.rom[height_table+64:height_table+65][0]
	x = g.get(piston, 'stomper_origin_x', 2)
	foot = y-g.get(piston, 'obHeight')-1
	player_index = ACTORS.index(actor)
	place(g, actor, x, foot-g.get(actor, 'default_y_radius'), False)
	for field, value, size in (
			('obStatus', 8, 1), ('obStatusSecondary', 2, 1), ('invtime', 6000, 2),
			('standonobject', (piston-(s['v_objspace'] & 0xFFFF))//s['object_size'], 1),
			('obTopSolidBit', 12+path*2, 1), ('obLRBSolidBit', 13+path*2, 1)):
		g.put(actor, field, value, size)
	for field, value, size in (
			('obY', y, 2), ('MMZ_crush_phase', 0x100, 2), ('obVelY', 0, 2),
			('obRender', 0x84, 1), ('obStatus', 1 << (3+player_index), 1)):
		g.put(piston, field, value, size)


def hold(g, actor, *buttons):
	if actor == 'v_player':
		g.buttons = set(buttons)
	else:
		g.buttons2 = set(buttons) | {4}  # Controller 2 input keeps manual control


def step(g, actor, piston, on_board=False):
	before = g.get(piston, 'obY', 2)
	g.run()
	assert not g.read('v_errortype'), 'ROM exception'
	alive = g.get(actor, 'obRoutine') < 6
	if on_board and alive:
		assert g.get(actor, 'obStatus') & 8, 'Foot left the piston'
		foot = g.get(actor, 'obY', 2) + g.get(actor, 'obHeight')
		offset = g.get(piston, 'obHeight') + 1
		assert foot in (before-offset, g.get(piston, 'obY', 2)-offset), 'Pose moved the foot'
	return alive


def ride(g, base, actor, piston, path, duck=False):
	g.restore(base)
	board(g, actor, piston, path)
	hold(g, actor, *((DOWN,) if duck else ()))
	for frame in range(RISE_FRAMES+1):
		if not step(g, actor, piston, on_board=True):
			return frame
	return None


def roof_solidity(g, base, piston):
	# The last solid row above the snug crusher. Retain its geometry
	# and change only its solidity on both paths in disposable CD RAM.
	for solidity in (1, 2):
		g.restore(base)
		y = 0x02BF
		for x in (0x1120-9, 0x1120, 0x1120+9):
			chunk = g.layout_cell(y//128, x//128)
			cell = g.terrain_address('chunks') + chunk*128 + (y//16 & 7)*16 + (x//16 & 7)*2
			word = g.read(cell, 2)
			g.write(cell, (word & 0x0FFF) | (solidity << 12) | (solidity << 14), 2)
		fixture = g.save()
		for path in (0, 1):
			result = ride(g, fixture, 'v_player', piston, path)
			assert (result is not None) == (solidity == 2), (solidity, path, result)


def release_and_dash(g, base, actor, piston, path, release, output):
	g.restore(base)
	board(g, actor, piston, path)
	hold(g, actor, DOWN)
	for _ in range(release):
		assert step(g, actor, piston, on_board=True)
	# The equivalent standing rider dies on this update. The player loop
	# must test the height the piston will carry the rider to later this frame.
	hold(g, actor)
	duck = g.s['AniIDSonAni_Duck']
	for _ in range(3):
		assert step(g, actor, piston, on_board=True)
		assert g.get(actor, 'obAnim') == duck
	assert g.get(actor, 'obHeight') == g.get(actor, 'default_y_radius')
	if output:
		g.video.save(output / f'{actor}-retained-duck.png')
	tucked = g.save()
	for _ in range(90):
		assert step(g, actor, piston, on_board=True)
		if g.get(actor, 'obAnim') != duck:
			break
	else:
		raise AssertionError('Player stayed tucked after the gap reopened')
	g.restore(tucked)
	face = LEFT if actor == 'v_player2' else RIGHT
	hold(g, actor, face)
	assert step(g, actor, piston, on_board=True)
	for _ in range(3):
		hold(g, actor, DOWN, ACTION)
		assert step(g, actor, piston, on_board=True)
		assert g.get(actor, 'obAnim') == g.s['AniIDSonAni_Spindash']
		assert g.get(actor, 'spindash_flag') == 1
		hold(g, actor, DOWN)
		assert step(g, actor, piston, on_board=True)
	assert g.get(actor, 'spindash_counter', 2) >= 0x200
	x = g.get(actor, 'obX', 2)
	hold(g, actor)
	assert step(g, actor, piston, on_board=True)
	assert g.get(actor, 'obStatus') & 4
	assert g.get(actor, 'obHeight') == 14 and g.get(actor, 'spindash_flag') == 0
	if output:
		g.video.save(output / f'{actor}-release-roll.png')
	for _ in range(5):
		assert step(g, actor, piston)
	direction = 1 if face == RIGHT else -1
	assert (g.get(actor, 'obX', 2)-x)*direction >= 16


def main():
	p = argparse.ArgumentParser(description=__doc__)
	for flag in ('rom', 'listing', 'core', 'output'):
		p.add_argument('--'+flag, type=Path, required=True)
	p.add_argument('--system-directory', type=Path)
	p.add_argument('--pal', action='store_true')
	args = p.parse_args()
	g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
		system_directory=args.system_directory)
	initial = g.save()
	for era in range(4):
		for scene in (SNUG, TIGHT, OPEN):
			piston, base = stage(g, initial, scene, era)
			if era == 0 and scene == SNUG:
				roof_solidity(g, base, piston)
			for actor in ACTORS:
				for path in (0, 1):
					standing_death = ride(g, base, actor, piston, path)
					duck_death = ride(g, base, actor, piston, path, duck=True)
					identity = scene, era, actor, path
					assert (standing_death is None) == (scene == OPEN), identity
					assert (duck_death is None) == (scene != TIGHT), identity
					if scene == SNUG:
						shots = args.output if era == path == 0 else None
						release_and_dash(g, base, actor, piston, path, standing_death, shots)
		print(f'Era {era}: both riders and both paths pass the snug, tight and open piston checks.', flush=True)
	g.close()


if __name__ == '__main__':
	main()
