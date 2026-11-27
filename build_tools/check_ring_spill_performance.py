#!/usr/bin/env python3
"""Measure real 50-ring pickups/hurt and a 32-ring spill on authored SMZ terrain.

Only initial positions, pickup objects and the hurt fixture are staged. The
matching control deletes the scattered objects from the identical hurt state.
Full game updates, Tails AI, terrain, sound, sprite output and VBlank remain live.
"""
import argparse
import json
from pathlib import Path

from check_companion_followup import place, spawn
from check_object_course import boot_level
from check_rising_crushers import seek
from check_terrain_momentum import floor_surface
from genesis_test_core import Genesis

ROOT = Path(__file__).resolve().parents[1]


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--core', type=Path, required=True)
	p.add_argument('--system-directory', type=Path, required=True)
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--act', type=int, choices=(1, 2), default=1)
	p.add_argument('--scene', choices=('start', 'girders', 'stompers'), default='start')
	p.add_argument('--player', type=int, choices=(0, 2), default=0)
	p.add_argument('--pal', action='store_true')
	p.add_argument('--probe', action='store_true', help='Record an older ROM without requiring zero missed updates')
	args = p.parse_args()
	if args.act == 2 and args.scene != 'start':
		p.error('the girder/stomper fixtures use SMZ act 1')
	g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
		system_directory=args.system_directory)
	boot_level(g, zone=8, act=args.act-1, player=args.player)
	pool = list(range(g.s['v_lvlobjspace']&65535, g.s['v_lvlobjend']&65535, g.s['object_size']))
	g.buttons = g.buttons2 = set()
	g.put('v_player2', 'obControl', 0x81)
	if args.scene != 'start':
		x, first_y = (0x600, 0x5C0) if args.scene == 'girders' else (0x940, 0x600)
		seek(g, x+0xA0, first_y+0xC0)
		found = None
		for candidate in (x, x+0x20, x+0x40, x+0x160, x+0x180):
			for y in range(first_y, first_y+0x1A1):
				try:
					_, angle = floor_surface(g, candidate, y, y+1)
				except AssertionError:
					continue
				try:
					floor_surface(g, candidate, y-42, y)
				except AssertionError:
					found = (candidate, y, angle)
					break
			if found:
				break
		assert found, 'no clear authored floor near the requested mechanisms'
		x, y, angle = found
		place(g, 'v_player', x, y-g.get('v_player', 'default_y_radius')-1, False)
		g.put('v_player', 'obAngle', angle)
	for _ in range(120):
		g.run()
		if not g.get('v_player', 'obStatus')&2:
			break
	assert g.read('v_rings', 2) == 0
	while g.read('v_rings', 2) < 50:
		before = g.read('v_rings', 2)
		for _ in range(min(10, 50-before)):
			spawn(g, 'Ring', g.get('v_player', 'obX', 2), g.get('v_player', 'obY', 2))
		for _ in range(12):
			g.run()
			assert not g.read('v_errortype')
			if g.read('v_rings', 2) >= min(50, before+10):
				break
		assert g.read('v_rings', 2) > before, ('pickup failed', before)
	assert g.read('v_rings', 2) == 50
	g.run(40)
	g.video.save(args.output/'fifty-rings.png')
	if g.get('v_player2', 'code'):
		place(g, 'v_player2', g.get('v_player', 'obX', 2)-40, g.get('v_player', 'obY', 2)+4, False)
		g.put('v_player2', 'obControl', 0)
		g.write('Tails_CPU_idle_timer', 0, 2)
		g.write('Tails_CPU_routine', 6, 2)
	origin = (g.get('v_player', 'obX', 2), g.get('v_player', 'obY', 2))
	spawn(g, 'Spikes', origin[0], origin[1]+g.get('v_player', 'obHeight')+16)

	def step():
		timer, vint = g.read('Timer_frames', 2), g.read('Vint_runcount', 4)
		g.run()
		assert not g.read('v_errortype')
		return dict(updates=(g.read('Timer_frames', 2)-timer)&65535,
			vints=(g.read('Vint_runcount', 4)-vint)&0xFFFFFFFF,
			timer=g.read('Timer_frames', 2), lag=g.read('Lag_frame_count', 2),
			x=g.get('v_player', 'obX', 2), y=g.get('v_player', 'obY', 2),
			routine=g.get('v_player', 'obRoutine'))

	hit_trace = []
	for _ in range(120):
		hit_trace.append(step())
		if g.get('v_player', 'obRoutine') == 4 and not g.read('v_rings', 2):
			break
	else:
		raise AssertionError('the real spike contact did not spill the inventory')
	hit = g.save()
	rows = []
	for keep in (False, True):
		g.restore(hit)
		if not keep:
			for slot in pool:
				if g.get(slot, 'code') in (g.s['LostRings'], g.s['LostRing_Move']):
					g.write(slot, 0, g.s['object_size'])
		trace = []
		for video in range(330):
			g.buttons = {7} if video%120 < 40 else ({6} if video%120 < 80 else set())
			row = step()
			row['video'] = video
			row['rings'] = sum(g.get(slot, 'code') == g.s['LostRing_Move'] for slot in pool)
			row['recovered'] = g.read('v_rings', 2)
			trace.append(row)
			if video in (1, 15, 24, 40, 100):
				g.video.save(args.output/f'{"spill" if keep else "control"}-{video}.png')
			if row['routine'] >= 6 or g.read('v_gamemode', 2) != g.s['Level']:
				break
		rows.append(dict(spill=keep, frames=len(trace),
			missed_updates=sum(row['updates'] == 0 for row in trace),
			peak=max(row['rings'] for row in trace), trace=trace))
		print({key:value for key,value in rows[-1].items() if key != 'trace'}, flush=True)
	g.close()
	report = dict(act=args.act, scene=args.scene, player=args.player, pal=args.pal,
		origin=origin, collected=50, hit=hit_trace, runs=rows)
	(args.output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
	assert rows[1]['peak'] == 32, 'fixture did not exercise the full spill'
	if not args.probe:
		assert not any(row['updates'] == 0 for row in hit_trace), 'missed update during hurt/allocation'
		assert not rows[1]['missed_updates'], 'missed active gameplay update during the spill'


if __name__ == '__main__':
	main()
