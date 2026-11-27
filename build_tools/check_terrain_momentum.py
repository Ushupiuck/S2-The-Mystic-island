#!/usr/bin/env python3
"""Exercise momentum through HPZ1's first chute and MMZ1's time-post bowl.

Only the initial actor/camera state is staged at the authored terrain. Ten
chute alignments repeat with neutral input and held Down. The bowl repeats
both directions at three speeds and two subpixel phases. Both scenes retain
placed objects and run Sonic/Tails at full size and after the real shrink beam.
"""
from pathlib import Path
import argparse
import json

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import place, spawn

ROOT = Path(__file__).resolve().parents[1]
FIELDS = (('obX', 2), ('obY', 2), ('obVelX', 2), ('obVelY', 2),
	('obInertia', 2), ('obAngle', 1), ('obStatus', 1), ('obAnim', 1), ('obRoutine', 1))


def signed(value):
	return (value + 32768) % 65536 - 32768


def sample(g, tick):
	return dict(tick=tick, **{field: g.get('v_player', field, size) for field, size in FIELDS})


def shrink(g):
	"""Let the real size laser and queued player DPLC create the miniature form."""
	x, y = g.get('v_player', 'obX', 2), g.get('v_player', 'obY', 2)
	spawn(g, 'MMZ_Laser', x, y-128)
	for _ in range(100):
		g.run()
		assert not g.read('v_errortype')
		if g.get('v_player', 'default_y_radius') == g.s['Player_MiniHeight']:
			break
	else:
		raise AssertionError('Shrink beam did not resize the player')
	g.run(3)
	# Retire only the setup emitter and its pulses/sparks; keep placed objects.
	codes = {g.s[name] for name in ('MMZ_Laser', 'MMZ_LaserPulse', 'MMZ_LaserSpark')}
	for slot in range(g.s['v_lvlobjspace'] & 65535, g.s['v_lvlobjend'] & 65535, g.s['object_size']):
		if g.get(slot, 'code') in codes:
			g.write(slot, 0, g.s['object_size'])


def traverse(g, output, player, miniature, down, trial):
	height = g.get('v_player', 'default_y_radius')
	x, y = 0x6C0-5+trial, 383-height
	place(g, 'v_player', x, y)
	g.put('v_player', 'obX', (x << 16)+trial*6553, 4)
	g.put('v_player', 'obY', (y << 16)+trial*5561, 4)
	g.put('v_player', 'obAngle', 0)
	for field, value, size in (('Camera_X_pos', 0x600, 2),
		('Camera_X_pos_coarse_back', 0x580, 2), ('Camera_Y_pos', 0x100, 2), ('Screen_redraw_flag', 1, 1)):
		g.write(field, value, size)
	trace, resets, pushes = [], [], []
	passed = False
	stem = f'player-{player}-{"mini" if miniature else "full"}-down-{int(down)}-{trial+1:02}'
	entry = None
	for tick in range(600):
		g.buttons = {5} if down else set()
		g.run()
		assert not g.read('v_errortype'), (stem, tick, 'ROM exception')
		row = sample(g, tick)
		if entry is None and row['obY'] >= 0x1C0:
			entry = row.copy()
			# The authored mouth, rather than a test-spawned enforcer, must
			# curl either character before the first bend, even with no Down.
		if trace and abs(signed(trace[-1]['obInertia'])) >= 0x600 and abs(signed(row['obInertia'])) < 0x100:
			resets.append(tick)
		if (trace and row['obStatus'] & 32 and not row['obStatus'] & 8
			and abs(signed(trace[-1]['obInertia'])) >= 0x600 and not row['obInertia']):
			pushes.append(tick)
		trace.append(row)
		if tick in (40, 80, 120, 160):
			g.video.save(output/f'{stem}-{tick}.png')
		passed = (0x560 <= row['obY'] < 0x5C0 and 0x600 <= row['obX'] < 0x900
			and signed(row['obVelX']) >= 0x600 and row['obRoutine'] == 2)
		if passed or row['obRoutine'] >= 6:
			break
	g.video.save(output/f'{stem}-final.png')
	(output/f'{stem}.json').write_text(json.dumps(trace)+'\n')
	return dict(scene='chute', player=player, miniature=miniature, down=down, trial=trial+1,
		passed=passed, inertia_resets=resets, terrain_push_stops=pushes, entry=entry, final=row)


def floor_surface(g, x, first=0x670, last=0x720):
	"""Read the bowl's actual resident floor profile to stage the starting feet."""
	prg = 0x420000
	path = g.read(prg+g.s['MCD_TerrainPath1_Sub'], 4)
	for y in range(first, last):
		chunk = g.layout_cell(y//128, x//128)
		cell = g.read(g.terrain_address('chunks')+chunk*128+((y//16%8)*8+x//16%8)*2, 2)
		if not cell & 0x1000:
			continue
		shape = g.read(prg+path+(cell & 1023)*2)
		column = 15-x%16 if cell & 0x400 else x%16
		height = g.read(prg+g.s['MCD_TerrainHeights_Sub']+shape*16+column)
		height = (height+128) % 256-128
		pixel = 15-y%16 if cell & 0x800 else y%16
		if height and (pixel >= 16-height if height > 0 else pixel < -height):
			angle = g.read(prg+g.s['MCD_TerrainAngles_Sub']+shape)
			if cell & 0x400:
				angle = -angle & 255
			if cell & 0x800:
				angle = 128-angle & 255
			return y, angle
	raise AssertionError(('Bowl floor not found', x))


def bowl(g, output, player, miniature, direction, speed, subpixel):
	x = 0xF24 if direction > 0 else 0xFFC
	floor, angle = floor_surface(g, x)
	tails = player == 2
	height = g.s['Player_MiniRollHeight'] if miniature else g.s['tails_roll_height' if tails else 'sonic_roll_height']
	width = g.s['Player_MiniWidth'] if miniature else g.s['tails_roll_width' if tails else 'sonic_roll_width']
	place(g, 'v_player', x, floor-height-1, False)
	for field, value, size in (('obX', (x << 16)+subpixel, 4), ('obAngle', angle, 1),
		('obHeight', height, 1), ('obWidth', width, 1), ('obStatus', 4, 1),
		('obAnim', g.s['AniIDSonAni_Roll'], 1), ('obInertia', direction*speed, 2), ('obVelX', direction*speed, 2)):
		g.put('v_player', field, value, size)
	for field, value, size in (('Camera_X_pos', 0xF00, 2), ('Camera_X_pos_coarse_back', 0xE80, 2),
		('Camera_Y_pos', 0x650, 2), ('Screen_redraw_flag', 1, 1)):
		g.write(field, value, size)
	trace, pushes = [], []
	passed = False
	stem = f'bowl-player-{player}-{"mini" if miniature else "full"}-{direction}-{speed:X}-{subpixel}'
	for tick in range(240):
		g.buttons = {5}
		g.run()
		assert not g.read('v_errortype'), (stem, tick, 'ROM exception')
		row = sample(g, tick)
		if (trace and row['obStatus'] & 32 and not row['obStatus'] & 8
			and abs(signed(trace[-1]['obInertia'])) >= 0x100 and not row['obInertia']):
			pushes.append(tick)
		trace.append(row)
		passed = (row['obX'] >= 0x1000 if direction > 0 else row['obX'] <= 0xF20)
		if passed or row['obRoutine'] >= 6:
			break
	g.video.save(output/f'{stem}-final.png')
	(output/f'{stem}.json').write_text(json.dumps(trace)+'\n')
	return dict(scene='bowl', player=player, miniature=miniature, direction=direction,
		speed=speed, subpixel=subpixel, passed=passed and row['obRoutine'] == 2,
		terrain_push_stops=pushes, final=row)


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--core', type=Path, required=True)
	p.add_argument('--system-directory', type=Path, required=True)
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--player', type=int, choices=(0, 2))
	p.add_argument('--scene', choices=('chute', 'bowl', 'all'), default='all')
	p.add_argument('--full-only', action='store_true')
	p.add_argument('--pal', action='store_true')
	p.add_argument('--probe', action='store_true', help='Record failures in an older ROM')
	args = p.parse_args()
	g = Genesis(args.core, args.rom, args.listing, args.output, args.pal, system_directory=args.system_directory)
	initial = g.save()
	results = []
	for scene in (('chute', 'bowl') if args.scene == 'all' else (args.scene,)):
		for player in ((args.player,) if args.player is not None else (0, 2)):
			g.restore(initial)
			boot_level(g, zone=4 if scene == 'chute' else 15, act=0, player=player)
			level = g.save()
			for miniature in ((False,) if args.full_only else (False, True)):
				g.restore(level)
				if miniature:
					shrink(g)
				form = g.save()
				if scene == 'chute':
					cases = [(down, trial) for down in (False, True) for trial in range(10)]
				else:
					cases = [(direction, speed, subpixel) for direction in (-1, 1)
						for speed in (0x200, 0x400, 0x600) for subpixel in (0, 32768)]
				rows = []
				for case in cases:
					g.restore(form)
					run = traverse if scene == 'chute' else bowl
					row = run(g, args.output, player, miniature, *case)
					rows.append(row)
					results.append(row)
					print(row, flush=True)
					(args.output/'report.json').write_text(json.dumps(results, indent=2)+'\n')
				print(f'{scene=} {player=} {miniature=}: {sum(r["passed"] for r in rows)}/{len(rows)} cleared; '
					f'{sum(bool(r["terrain_push_stops"]) for r in rows)} terrain push stops.', flush=True)
	g.close()
	if not args.probe:
		for row in results:
			if row['scene'] == 'chute':
				assert row['entry'] and row['entry']['obStatus'] & 4, ('HPZ entrance did not auto-roll', row)
		assert all(r['passed'] and not r['terrain_push_stops'] for r in results), [
			r for r in results if not r['passed'] or r['terrain_push_stops']]


if __name__ == '__main__':
	main()
