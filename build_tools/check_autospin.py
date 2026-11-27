#!/usr/bin/env python3
"""Check AutoSpin crossings and both ways through the first GHZ1 S-tunnel."""
import argparse
from pathlib import Path

from check_companion_followup import place
from check_object_course import boot_level
from genesis_test_core import Genesis
from native_test_core import Native
from check_terrain_momentum import shrink, floor_surface

ACTORS = ('v_player', 'v_player2')
UPPER = (0x17F0, 0x0480)
LOWER = (0x1910, 0x0580)


def crossing(n, vertical, leftward, case):
	n.start()
	gate = n.s['v_lvlobjspace']
	x, y = 600, 700
	direction = -1 if leftward else 1
	along, across = ('obY', 'obX') if vertical else ('obX', 'obY')
	start, end = (-direction*10, direction*10)
	will_roll = case in ('normal', 'air-enabled')
	if case == 'outward':
		start, end = end, start
	for actor, constructor, radius in zip(ACTORS, ('Obj01', 'Obj02'), (19, 15)):
		for field, value, size in (
				('code', n.s[constructor], 4), ('obX', x, 2), ('obY', y, 2),
				('obHeight', radius, 1), ('obVelX', direction*0x580, 2),
				('obVelY', 0x140, 2), ('obInertia', direction*0x590, 2)):
			n.put(actor, field, value, size)
		n.put(actor, along, n.get(actor, along, 2)+start, 2)
		if case == 'out-of-span':
			n.put(actor, across, n.get(actor, across, 2)+40, 2)
		if case in ('ground-only', 'air-enabled'):
			n.put(actor, 'obStatus', 2)
		if case == 'charging':
			n.put(actor, 'spindash_flag', 1)
		if case == 'flight':
			n.put(actor, 'tails_flight_flag', 1)
		if case == 'locked':
			n.put(actor, 'obControl', 0x81)
		if case == 'death':
			n.put(actor, 'obRoutine', 6)
	if case == 'debug':
		n.write('Debug_placement_mode', 1, 2)
	for field, value, size in (
			('obX', x, 2), ('obY', y, 2), ('obStatus', int(leftward), 1),
			('obSubtype', (4 if vertical else 0) | (0 if case == 'air-enabled' else 0x20), 2)):
		n.put(gate, field, value, size)
	n.write('Camera_X_pos_coarse_back', x-128, 2)
	n.act('AutoSpin', gate)
	assert all(not n.get(actor, 'obStatus') & 4 for actor in ACTORS)
	for actor in ACTORS:
		n.put(actor, along, n.get(actor, along, 2)+end-start, 2)
		foot = n.get(actor, 'obY', 2)+n.get(actor, 'obHeight')
		n.act('AutoSpin_Run', gate)
		assert bool(n.get(actor, 'obStatus') & 4) == will_roll, (vertical, leftward, case, actor)
		assert n.get(actor, 'spindash_flag') == int(case == 'charging')
		assert n.get(actor, 'obY', 2)+n.get(actor, 'obHeight') == foot
		assert n.get(actor, 'obVelX', 2) == direction*0x580 & 0xFFFF
		assert n.get(actor, 'obVelY', 2) == 0x140
		assert n.get(actor, 'obInertia', 2) == direction*0x590 & 0xFFFF


def traverse(g, base, returning):
	g.restore(base)
	g.buttons = set()
	mouth, exit_mouth = (LOWER, UPPER) if returning else (UPPER, LOWER)
	direction = -1 if returning else 1
	x, floor = mouth[0]-direction*24, mouth[1]
	actor = 'v_player'
	place(g, actor, x, floor-g.get(actor, 'default_y_radius'), False)
	for field, value, size in (('obStatus', int(returning), 1), ('obControl', 0x81, 1),
			('obStatusSecondary', 2, 1), ('invtime', 6000, 2)):
		g.put(actor, field, value, size)
	g.write('Camera_X_pos', x-152, 2)
	g.write('Camera_Y_pos', floor-125, 2)
	g.write('Screen_redraw_flag', 1)
	g.run(20)
	g.put(actor, 'obControl', 0)
	if returning:
		g.buttons = {5}
		g.run(4)
		for _ in range(12):
			g.buttons = {5, 0}
			g.run()
			g.buttons = {5}
			g.run()
		assert g.get(actor, 'spindash_flag') == 1
		g.buttons = set()
	else:
		g.put(actor, 'obInertia', 0x580, 2)
		g.put(actor, 'obVelX', 0x580, 2)
		g.buttons = {7}
	entered_in_a_ball = False
	for _ in range(180):
		g.run()
		assert not g.read('v_errortype')
		assert g.get(actor, 'obRoutine') < 6
		x = g.get(actor, 'obX', 2)
		y = g.get(actor, 'obY', 2)
		if (x-mouth[0])*direction >= 0 and not entered_in_a_ball:
			assert g.get(actor, 'obStatus') & 4
			assert g.get(actor, 'obHeight') == 14
			assert g.get(actor, 'spindash_flag') == 0
			entered_in_a_ball = True
		if (x-exit_mouth[0])*direction >= -12 and abs(y-exit_mouth[1]) < 32:
			assert entered_in_a_ball
			g.video.save(g.output / f'player{g.read("Player_mode", 2)}-return{int(returning)}.png')
			return
	raise AssertionError(('Tunnel exit not reached', returning, x, y))


def hpz_mouths(g, base, miniature, spindash):
	"""Enter the real lower HPZ1 mouth from the right, then climb its bend."""
	g.restore(base)
	if miniature:
		shrink(g)
	x = 0x540
	floor, angle = floor_surface(g, x, 0x570, 0x5C0)
	height = g.get('v_player', 'default_y_radius')
	place(g, 'v_player', x, floor-height-1, False)
	g.put('v_player', 'obAngle', angle)
	g.put('v_player', 'obStatus', 1)
	g.put('v_player', 'obControl', 0x81)
	for field, value in (('Camera_X_pos', 0x480), ('Camera_X_pos_coarse_back', 0x400),
		('Camera_Y_pos', 0x500), ('Screen_redraw_flag', 1)):
		g.write(field, value, 1 if field == 'Screen_redraw_flag' else 2)
	g.run(12)
	g.put('v_player', 'obControl', 0)
	if spindash:
		g.buttons = {5}
		g.run(4)
		for _ in range(12):
			g.buttons = {5, 0}
			g.run(2)
			g.buttons = {5}
			g.run(2)
		assert g.get('v_player', 'spindash_flag') == 1
		g.buttons = set()
	else:
		g.put('v_player', 'obInertia', -0x580, 2)
		g.put('v_player', 'obVelX', -0x580, 2)
		g.buttons = {6}
	entered = False
	for tick in range(150):
		g.run()
		assert not g.read('v_errortype')
		assert g.get('v_player', 'obRoutine') == 2
		x, y = g.get('v_player', 'obX', 2), g.get('v_player', 'obY', 2)
		if x <= 0x510 and not entered:
			assert g.get('v_player', 'obStatus') & 4, ('HPZ lower mouth did not curl', miniature, spindash, x, y)
			assert g.get('v_player', 'obHeight') == (8 if miniature else 14)
			assert g.get('v_player', 'obInertia', 2) & 0x8000, 'Enforcer reversed the incoming roll'
			entered = True
		if entered and y < 0x550:
			g.video.save(g.output/f'hpz-player{g.read("Player_mode", 2)}-mini{int(miniature)}-dash{int(spindash)}.png')
			return
	raise AssertionError(('HPZ lower bend not climbed', miniature, spindash, x, y, entered))


def main():
	p = argparse.ArgumentParser(description=__doc__)
	for flag in ('rom', 'listing'):
		p.add_argument('--'+flag, type=Path, required=True)
	for flag in ('core', 'output', 'system-directory'):
		p.add_argument('--'+flag, type=Path)
	p.add_argument('--pal', action='store_true')
	args = p.parse_args()
	n = Native(args.rom, args.listing)
	for vertical in (False, True):
		for leftward in (False, True):
			for case in ('normal', 'outward', 'out-of-span', 'ground-only', 'air-enabled',
					'charging', 'flight', 'locked', 'death', 'debug'):
				crossing(n, vertical, leftward, case)
	print('40 AutoSpin gate cases pass for both actor slots.', flush=True)
	if args.core:
		assert args.output, '--core needs --output'
		g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
			system_directory=args.system_directory)
		initial = g.save()
		for player in (1, 2):
			g.restore(initial)
			g.buttons = set()
			boot_level(g, zone=0, act=0, player=player)
			base = g.save()
			for returning in (False, True):
				traverse(g, base, returning)
		for player in (1, 2):
			g.restore(initial)
			boot_level(g, zone=4, act=0, player=player)
			base = g.save()
			for miniature in (False, True):
				for spindash in (False, True):
					hpz_mouths(g, base, miniature, spindash)
		g.close()
		print('Sonic and Tails cross the authored GHZ1 tunnel in both directions.', flush=True)
		print('Both sizes enter HPZ1\'s authored lower mouth by running or spindashing and climb its return bend.', flush=True)


if __name__ == '__main__':
	main()
