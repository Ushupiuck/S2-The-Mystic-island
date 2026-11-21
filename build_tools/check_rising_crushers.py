#!/usr/bin/env python3
"""Test terrain clearance over authored Metallic and Scrap Madness crushers."""
import argparse
from pathlib import Path

from check_companion_followup import place
from check_object_course import boot_level
from genesis_test_core import Genesis
from object_layout import decode

ACTORS = ('v_player', 'v_player2')
DOWN, ACTION, RIGHT, LEFT = 5, 0, 7, 6
RISE_FRAMES = 128
SNUG = (1, 0x1120, 0x032E)
TIGHT = (2, 0x1D61, 0x02AD)
OPEN = (1, 0x1721, 0x067F)


def seek(g, x, y):
	for actor in ACTORS:
		place(g, actor, x, y-56)
		g.put(actor, 'obControl', 0x81)
	g.write('Camera_X_pos', x-152, 2)
	g.write('Camera_Y_pos', y-132, 2)
	g.write('Screen_redraw_flag', 1)
	g.run(32)


def find_support(g, code, origin, x, y):
	s = g.s
	slots = range(s['v_lvlobjspace'] & 0xFFFF, s['v_lvlobjend'] & 0xFFFF, s['object_size'])
	return next(slot for slot in slots if g.get(slot, 'code') == s[code]
		and g.get(slot, origin[0], 2) == x and g.get(slot, origin[1], 2) == y)


def stage(g, initial, scene, era, player):
	act, x, y = scene
	g.restore(initial)
	g.buttons, g.buttons2 = set(), set()
	boot_level(g, player=player, zone=15, act=act-1, timezone=era)
	seek(g, x, y)
	piston = find_support(g, 'Stomper_Run', ('stomper_origin_x', 'stomper_origin_y'), x, y)
	return piston, g.save()


def set_rider(g, actor, support, x, foot, path):
	s = g.s
	player_index = ACTORS.index(actor)
	tails = player_index == 1 or g.read('Player_mode', 2) == s['PlayerMode_Tails']
	assert g.get(actor, 'character_id') == (s['CharacterID_Tails'] if tails else 0)
	radius = s['tails_height' if tails else 'sonic_height']
	assert g.get(actor, 'default_y_radius') == radius
	place(g, actor, x, foot-radius, False)
	for field, value, size in (
			('obStatus', 8, 1), ('obStatusSecondary', 2, 1), ('invtime', 6000, 2),
			('standonobject', (support-(s['v_objspace'] & 0xFFFF))//s['object_size'], 1),
			('player_support_x', x, 2), ('obTopSolidBit', 12+path*2, 1),
			('obLRBSolidBit', 13+path*2, 1)):
		g.put(actor, field, value, size)
	flags = g.get(support, 'obStatus') & ~0x18
	g.put(support, 'obStatus', flags | (1 << (3+player_index)))
	g.put(support, 'obRender', g.get(support, 'obRender') | 0x80)


def board(g, actor, piston, path):
	height_table = g.get(piston, 'MMZ_crush_heights', 4)
	y = g.get(piston, 'stomper_origin_y', 2) + g.rom[height_table+64:height_table+65][0]
	x = g.get(piston, 'stomper_origin_x', 2)
	foot = y-g.get(piston, 'obHeight')-1
	set_rider(g, actor, piston, x, foot, path)
	for field, value, size in (
			('obY', y, 2), ('MMZ_crush_phase', 0x100, 2), ('obVelY', 0, 2)):
		g.put(piston, field, value, size)


def hold(g, actor, *buttons):
	if actor == 'v_player':
		g.buttons, g.buttons2 = set(buttons), set()
	else:
		# Controller 2 input keeps manual control.
		g.buttons, g.buttons2 = set(), set(buttons) | {4}


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
	# The equivalent standing rider dies on this update. The carry pass
	# must keep the rider compact if standing fits only before the rise.
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


def scrap_madness(g, initial, era, player, actors, output):
	root = Path(__file__).resolve().parents[1]
	for act in (1, 2):
		rows = decode((root / f'level/objects/SMZ_{act}.bin').read_bytes())
		crushers = [(x, y & 0xFFF, oid) for x, y, oid, _, subtype in rows
			if oid == 0xAA or (oid == 0xA5 and subtype in (0x24, 0x34))]
		assert len(crushers) == (20 if act == 1 else 1)
		g.restore(initial)
		g.buttons, g.buttons2 = set(), set()
		boot_level(g, player=player, zone=8, act=act-1, timezone=era)
		level = g.save()
		for x, y, oid in crushers:
			g.restore(level)
			g.buttons, g.buttons2 = set(), set()
			seek(g, x, y)
			if oid == 0xAA:
				support = find_support(g, 'SMZ_Girder', ('SMZ_gird_origX', 'SMZ_gird_origY'), x, y)
				# Start at the down/right corner, facing the real diagonal return leg.
				fields = (
					('obX', (x+96)<<16, 4), ('obY', (y+48)<<16, 4),
					('obVelX', 0xFF00, 2), ('obVelY', 0xFFC0, 2),
					('SMZ_gird_time', 96, 2), ('SMZ_gird_set', 0x18, 1),
					('SMZ_gird_delay', 0, 2))
				rider_x = x+24
			else:
				support = find_support(g, 'Stomper_Run', ('stomper_origin_x', 'stomper_origin_y'), x, y)
				offset = g.get(support, 'SMZ_sto_offset_max', 2)
				fields = (('obY', (y+offset)<<16, 4), ('SMZ_sto_active', 0, 1),
					('SMZ_sto_offset_now', offset, 2))
				rider_x = x
			for field, value, size in fields:
				g.put(support, field, value, size)
			foot = g.get(support, 'obY', 2)-g.get(support, 'obHeight')-1
			base = g.save()
			for actor in actors:
				for path in (0, 1):
					g.restore(base)
					g.buttons, g.buttons2 = set(), set()
					set_rider(g, actor, support, rider_x, foot, path)
					hold(g, actor)
					for frame in range(RISE_FRAMES):
						previous_y = g.get(support, 'obY', 2)
						if not step(g, actor, support, on_board=True):
							assert 0 < frame and g.get(support, 'obY', 2) < previous_y
							assert not g.get(actor, 'obStatus') & 8
							assert not g.get(support, 'obStatus') & 0x18
							break
					else:
						raise AssertionError((act, hex(x), hex(y), era, actor, path))
					if era == path == 0 and actor == ACTORS[0] and x in (0x06A0, 0x09A0, 0x11E0):
						g.video.save(output / f'smz{act}-{x:04x}-{y:04x}-crush.png')
		print(f'Scrap Madness {act}, era {era}: terrain crush verified at {len(crushers)} placements.', flush=True)


def metallic_madness(g, initial, era, player, actors, output):
	for scene in (SNUG, TIGHT, OPEN):
		piston, base = stage(g, initial, scene, era, player)
		if era == 0 and scene == SNUG:
			roof_solidity(g, base, piston)
		for actor in actors:
			for path in (0, 1):
				standing_death = ride(g, base, actor, piston, path)
				duck_death = ride(g, base, actor, piston, path, duck=True)
				identity = scene, era, player, actor, path
				assert (standing_death is None) == (scene == OPEN), identity
				assert (duck_death is None) == (scene != TIGHT), identity
				if scene == SNUG:
					shots = output if era == path == 0 else None
					release_and_dash(g, base, actor, piston, path, standing_death, shots)
	print(f'Metallic Madness, era {era}: snug, tight and open piston checks passed on both paths.', flush=True)


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
	for player, actors, name in (
			(g.s['PlayerMode_Tails'], ACTORS[:1], 'solo Tails'),
			(g.s['PlayerMode_SonicAndTails'], ACTORS, 'Sonic and controller-2 Tails')):
		output = args.output / ('solo-tails' if player == g.s['PlayerMode_Tails'] else 'sonic-and-tails')
		output.mkdir(parents=True, exist_ok=True)
		print(f'Testing {name}.', flush=True)
		for era in range(4):
			metallic_madness(g, initial, era, player, actors, output)
			scrap_madness(g, initial, era, player, actors, output)
	g.close()


if __name__ == '__main__':
	main()
