#!/usr/bin/env python3
"""Run the placed Chemical Plant crossings and their shared two-player trigger."""
import argparse
import json
from itertools import product
from pathlib import Path

from check_companion_followup import place
from check_object_course import boot_level
from check_terrain_momentum import sample, shrink, signed
from genesis_test_core import Genesis
from native_test_core import Native

ROOT = Path(__file__).resolve().parents[1]

# Start X, floor Y, finish X, expected finish floor, initial path, full turns.
# A few reverse climbs use speed from the preceding descent. A speed of zero
# starts from rest and charges a real spindash using only controller input.
ROUTES = (
	('top loop',             0x0D60, 0x140, 0x1050, 0x296, 12, 1, 0x900),
	('top loop reverse',     0x0FD0, 0x280, 0x0DF0, 0x140, 14, 1, 0xD00),
	('west stacked loops',   0x0DE0, 0x580, 0x1000, 0x640, 12, 2, 0x900),
	('west lower loop',      0x0DE0, 0x680, 0x1000, 0x640, 12, 1, 0x900),
	('west lower reverse',   0x1040, 0x640, 0x0E20, 0x680, 14, 1, 0xD00),
	('east stacked loops',   0x15D0, 0x380, 0x1800, 0x580, 12, 2, 0x900),
	('east lower loop',      0x1630, 0x480, 0x1800, 0x580, 12, 1, 0x900),
	('east lower reverse',   0x18A0, 0x580, 0x1600, 0x480, 14, 1, 0xD00),
	('last loop',            0x1810, 0x580, 0x19C0, 0x534, 12, 1, 0x900),
	('last loop reverse',    0x1A70, 0x500, 0x1800, 0x580, 14, 1, 0x900),
	('east braid high',      0x15A0, 0x180, 0x1860, 0x1A0, 14, 0, 0x900),
	('east braid low',       0x1500, 0x244, 0x1860, 0x27C, 12, 0, 0x900),
	('east high reverse',    0x19D0, 0x200, 0x15D0, 0x180, 14, 0, 0x900),
	('east low reverse',     0x1920, 0x280, 0x15D0, 0x204, 12, 0, 0x900),
	('lower braid low',      0x0AC0, 0x440, 0x0DC0, 0x480, 12, 0, 0x900),
	('lower braid high',     0x0A90, 0x380, 0x0DC0, 0x400, 14, 0, 0x900),
	('central braid high',   0x0FC0, 0x280, 0x1210, 0x280, 14, 0, 0x900),
	('central braid low',    0x0F60, 0x300, 0x1520, 0x3DC, 12, 0, 0x900),
	('west braid high',      0x03B0, 0x200, 0x0850, 0x200, 14, 0, 0x900),
	('west braid low',       0x0350, 0x24C, 0x0900, 0x2BD, 12, 0, 0x900),
	('west descent',         0x07B0, 0x600, 0x0960, 0x680, 12, 0, 0x900),
	('west ascent',          0x09B0, 0x680, 0x07A0, 0x600, 14, 0, 0x900),
	('central underpass',    0x10E0, 0x500, 0x1250, 0x580, 12, 0, 0x900),
	('central under reverse',0x1270, 0x580, 0x10D0, 0x500, 12, 0, 0x900),
	('east ascent',          0x1A70, 0x600, 0x1C00, 0x580, 12, 0, 0x900),
	('east descent',         0x1C50, 0x580, 0x1A60, 0x600, 12, 0, 0x900),
	('last fork slope',      0x1C70, 0x380, 0x1E90, 0x280, 14, 0, 0x900),
	('last fork high',       0x1CA0, 0x280, 0x1E90, 0x280, 12, 0, 0x900),
	('last fork low return', 0x1ED8, 0x380, 0x1CB0, 0x380, 12, 0, 0x900),
	('last fork high return',0x1F00, 0x280, 0x1CB0, 0x280, 14, 0, 0x900),
	('charged west descent', 0x07B0, 0x600, 0x0960, 0x680, 12, 0, 0),
	('charged east return',  0x1920, 0x280, 0x15D0, 0x204, 12, 0, 0),
)


def switch_lines(rom, listing):
	n = Native(rom, listing)
	gate = n.s['v_lvlobjspace']
	players = ('v_player', 'v_player2')
	cases = 0
	for axis, length, ground_only in product(range(2), range(4), (False, True)):
		n.start()
		n.write('Camera_X_pos', 0x180, 2)
		n.put(gate, 'obX', 0x200, 2)
		n.put(gate, 'obY', 0x200, 2)
		n.put(gate, 'obSubtype', 0x48 | axis << 2 | length | int(ground_only) << 7)
		along, across = ('obX', 'obY') if axis == 0 else ('obY', 'obX')
		span = 0x20 << length
		def position(who, side, offset):
			n.put(who, along, 0x200+side, 2)
			n.put(who, across, 0x200+offset, 2)
		def state(who):
			return n.get(who, 'obTopSolidBit', 2), n.get(who, 'obGfx', 2)
		def step():
			n.act(n.get(gate, 'code'), gate)
		for who, side in zip(players, (-32, 32)):
			n.put(who, 'obGfx', 0x2345, 2)
			position(who, side, 0)
		n.act('CollisionSwitcher', gate)
		assert all(state(who) == (0x0C0D, 0x2345) for who in players)
		# Equality is right/down. Both actors skip the old narrow band.
		position(players[0], 0, -span)
		position(players[1], -32, span-1)
		step()
		assert state(players[0]) == (0x0E0F, 0x2345)
		assert state(players[1]) == (0x0C0D, 0xA345)
		# Exiting past the exclusive endpoint must not fire on re-entry
		# from that same side. Only the next actual crossing can fire.
		position(players[0], -32, span)
		step()
		position(players[0], -32, 0)
		step()
		assert state(players[0]) == (0x0E0F, 0x2345)
		position(players[1], 32, -span-1)
		step()
		position(players[1], 32, 0)
		step()
		assert state(players[1]) == (0x0C0D, 0xA345)
		n.put(players[1], 'obStatus', 2)
		position(players[1], -32, 0)
		step()
		position(players[1], 32, 0)
		step()
		assert state(players[1]) == ((0x0C0D, 0xA345) if ground_only else (0x0E0F, 0x2345))
		# A debug teleport or a newly occupied partner slot needs a fresh side.
		n.write('Debug_placement_mode', 1, 2)
		step()
		position(players[0], 32, 0)
		n.put(players[0], 'obTopSolidBit', 0x0C0D, 2)
		n.write('Debug_placement_mode', 0, 2)
		step()
		assert state(players[0]) == (0x0C0D, 0x2345)
		n.put(players[1], 'code', 0)
		step()
		n.put(players[1], 'layout_id', 2)
		n.put(players[1], 'obStatus', 0)
		n.put(players[1], 'obGfx', 0x2345, 2)
		position(players[1], -32, 0)
		step()
		assert n.get(players[1], 'obGfx', 2) == 0x2345
		cases += 1
	return cases


def traverse(g, route):
	name, x, floor, end, exit_floor, path, crowns, speed = route
	who = 'v_player'
	direction = 1 if end > x else -1
	key = 7 if direction > 0 else 6
	height = g.get(who, 'default_y_radius')
	y = floor-height-1
	g.buttons = set()
	place(g, who, x, y, False)
	g.put(who, 'obControl', 0x81)
	g.put(who, 'obTopSolidBit', path << 8 | (path+1), 2)
	g.write('Camera_X_pos', x-160, 2)
	g.write('Camera_X_pos_coarse_back', (x-288)&0xFF80, 2)
	g.write('Camera_Y_pos', floor-112, 2)
	g.write('Screen_redraw_flag', 1)
	g.run(12)
	place(g, who, x, y, False)
	g.put(who, 'obAngle', 0)
	g.put(who, 'obStatus', int(direction < 0))
	if speed:
		g.put(who, 'obInertia', direction*speed, 2)
		g.put(who, 'obVelX', direction*speed, 2)
	else:
		g.buttons = {5}
		g.run(4)
		for _ in range(12):
			g.buttons = {5, 0}
			g.run(2)
			g.buttons = {5}
			g.run(2)
		assert g.get(who, 'spindash_flag') == 1, (name, 'failed to charge')
	g.buttons = {key}
	turns = airborne = pushes = 0
	upside_down = False
	crossings = []
	for tick in range(360):
		g.run()
		row = sample(g, tick)
		assert not g.read('v_errortype') and row['obRoutine'] == 2, (name, tick, row)
		current = g.get(who, 'obTopSolidBit')
		if current != path:
			crossings.append((row['obX'], row['obY'], current))
			path = current
		airborne += bool(row['obStatus'] & 2)
		pushes += bool(row['obStatus'] & 32)
		ceiling = 0x60 <= row['obAngle'] <= 0xA0 and not row['obStatus'] & 2
		turns += ceiling and not upside_down
		upside_down = ceiling
		if (row['obX']-end)*direction >= 0:
			break
	feet = row['obY'] + g.get(who, 'obHeight') + 1
	passed = ((row['obX']-end)*direction >= 0 and abs(feet-exit_floor) <= 18
		and signed(row['obInertia'])*direction >= 0x200 and turns == crowns
		and not airborne and not pushes)
	return dict(route=name, passed=passed, frames=tick+1, exit_feet=feet,
		exit_x=row['obX'], inertia=signed(row['obInertia']), upside_down_passes=turns,
		airborne_frames=airborne, push_frames=pushes, path_changes=crossings)


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--core', type=Path)
	p.add_argument('--system-directory', type=Path)
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--act', type=int, choices=range(1, 5), default=1)
	p.add_argument('--timezone', type=int, choices=range(4), default=0)
	p.add_argument('--pal', action='store_true')
	args = p.parse_args()
	args.output.mkdir(exist_ok=True, parents=True)
	report = dict(line_configurations=switch_lines(args.rom, args.listing), routes=[])
	if args.core:
		g = Genesis(args.core, args.rom, args.listing, args.output, args.pal, system_directory=args.system_directory)
		title = g.save()
		for player in (0, 2):
			g.restore(title)
			boot_level(g, zone=2, act=args.act-1, player=player, timezone=args.timezone)
			stage = g.save()
			for miniature in (False, True):
				g.restore(stage)
				if miniature:
					# Some act starts are in midair. Place the setup beam on the
					# same flat, loaded approach for every act and timezone.
					place(g, 'v_player', 0x7B0, 0x600-g.get('v_player', 'default_y_radius')-1, False)
					g.put('v_player', 'obTopSolidBit', 0x0C0D, 2)
					g.write('Camera_X_pos', 0x710, 2)
					g.write('Camera_X_pos_coarse_back', 0x680, 2)
					g.write('Camera_Y_pos', 0x590, 2)
					g.write('Screen_redraw_flag', 1)
					g.run(12)
					shrink(g)
				form = g.save()
				for route in ROUTES:
					g.restore(form)
					result = traverse(g, route)
					report['routes'].append(dict(player=player, miniature=miniature, **result))
					if not result['passed']:
						print(report['routes'][-1], flush=True)
		g.close()
	(args.output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
	assert all(r['passed'] for r in report['routes']), 'See failing routes above'
	print(report['line_configurations'], 'two-player switch configurations;', len(report['routes']), 'route traversals passed.')


if __name__ == '__main__':
	main()
