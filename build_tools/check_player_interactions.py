#!/usr/bin/env python3
"""Regress character-specific tumble poses, sloped pushing and two-player walls.

Native checks cover all angles and animation-delay returns. Optional libretro
scenes stage the initial actors/objects, then use ordinary movement and controller
input. These are focused fixtures, not full playthroughs.
"""
from pathlib import Path
import argparse
import json

from native_test_core import Native

ROOT = Path(__file__).resolve().parents[1]


def animation_checks(args):
	n = Native(args.rom, args.listing)
	n.start()
	failures, push_samples, tumble_samples = [], 0, 0
	for character, base, push in (('Sonic', 0x5F, 0x48), ('Tails', 0x31, 0xA9)):
		for facing in (0, 1):
			for angle in range(256):
				for delay in (0, 6, 32):
					for field, value in (('obAnim', 0), ('obPrevAni', 0), ('obFrame', push),
						('obAniFrame', 0), ('obAngle', angle), ('flip_angle', 0),
						('flip_turned', 0), ('obStatus', 0x20 | facing),
						('obRender', 0x84), ('obTimeFrame', delay)):
						n.put('v_player', field, value)
					n.put('v_player', 'obInertia', 0, 2)
					n.act(character + '_Animate', 'v_player')
					push_samples += 1
					if n.get('v_player', 'obRender') != 0x84 | facing:
						failures.append((character, 'pushing', facing, angle, delay))
			for turned in (0, 1):
				for angle in range(1, 256):
					for field, value in (('obAnim', 0), ('obPrevAni', 0), ('obStatus', facing),
						('obRender', 0x87), ('flip_angle', angle), ('flip_turned', turned)):
						n.put('v_player', field, value)
					n.act(character + '_Animate', 'v_player')
					phase = (angle + 11) & 255
					flags = facing
					if facing and not turned:
						phase, flags = (-angle + 0x8F) & 255, 3
					tumble_samples += 1
					actual = (n.get('v_player', 'obFrame'), n.get('v_player', 'obRender'))
					if actual != (base + phase // 22, 0x84 | flags):
						failures.append((character, 'tumble', facing, turned, angle, actual))
	return dict(push_samples=push_samples, tumble_samples=tumble_samples,
		failures=len(failures), examples=failures[:12])


def wall_checks(args):
	n = Native(args.rom, args.listing)
	results = []
	for actor in ('v_player', 'v_player2'):
		for direction in (1, -1):
			for speed, animation in ((0x47F, 2), (0x480, 2), (0x700, 2), (0x700, 0)):
				n.start()
				n.write('Current_Zone', n.s['id_EHZ'])
				n.write('Camera_X_pos_coarse_back', 0x100, 2)
				for other in ('v_player', 'v_player2'):
					for field, value, size in (('obX', 0x300, 2), ('obY', 0x400, 2),
						('obVelX', 0x900, 2), ('obAnim', 2, 1)):
						n.put(other, field, value, size)
				for field, value, size in (('obX', 0x180 - direction * 25, 2),
					('obY', 0x400, 2), ('obVelX', direction * speed, 2),
					('obInertia', direction * speed, 2), ('obAnim', animation, 1),
					('obStatus', 4 if animation == 2 else 0, 1)):
					n.put(actor, field, value, size)
				wall = n.s['v_lvlobjspace']
				for field, value, size in (('code', n.s['Obj3C'], 4), ('obX', 0x180, 2), ('obY', 0x400, 2)):
					n.put(wall, field, value, size)
				n.act('Obj3C', wall)
				n.put(wall, 'obRender', 0x84)
				n.act('Obj3C', wall)
				parts = [a for a in range(wall, n.s['v_lvlobjend'], n.s['object_size'])
					if n.get(a, 'code') == n.s['Obj3C'] and n.get(a, 'obRoutine') == 4]
				expected = animation == 2 and speed >= 0x480
				passed = (len(parts) == 8 if expected else not parts)
				if expected:
					passed &= n.get(actor, 'obVelX', 2) == direction * speed & 65535
				results.append(dict(actor=actor, direction=direction, speed=speed,
					animation=animation, fragments=len(parts), passed=bool(passed)))
	for breaker, rider, standing_bit in (('v_player2', 'v_player', 3), ('v_player', 'v_player2', 4)):
		for owned in (True, False):
			n.start()
			n.write('Current_Zone', n.s['id_EHZ'])
			n.write('Camera_X_pos_coarse_back', 0x100, 2)
			wall = n.s['v_lvlobjspace']
			for actor in (breaker, rider):
				n.put(actor, 'obX', 0x300, 2)
				n.put(actor, 'obY', 0x400, 2)
			for field, value, size in (('code', n.s['Obj3C'], 4), ('obX', 0x180, 2), ('obY', 0x400, 2)):
				n.put(wall, field, value, size)
			n.act('Obj3C', wall)
			n.put(wall, 'obRender', 0x84)
			n.put(wall, 'obStatus', 1 << standing_bit)
			for field, value, size in (('obX', 0x180, 2), ('obY', 0x400-32-19-1, 2),
				('obStatus', 8, 1), ('standonobject', (wall-n.s['v_objspace'])//n.s['object_size']+int(not owned), 1)):
				n.put(rider, field, value, size)
			for field, value, size in (('obX', 0x180-25, 2), ('obY', 0x400, 2),
				('obVelX', 0x700, 2), ('obInertia', 0x700, 2), ('obAnim', 2, 1), ('obStatus', 4, 1)):
				n.put(breaker, field, value, size)
			n.act('Obj3C', wall)
			status = n.get(rider, 'obStatus')
			passed = n.get(wall, 'obRoutine') == 4 and bool(status & 2) == owned and bool(status & 8) != owned
			results.append(dict(case='rider_release', actor=breaker, rider=rider, owned=owned, passed=passed))
	return results


def floor_scene(g, rom):
	from check_ehz_terrain import clear_scene
	clear_scene(g)
	indices = g.read('v_colladdr1', 4)
	count = len((ROOT / 'mappings/16x16/EHZ.unc').read_bytes()) // 8
	profiles = [rom[g.s['ColArray1'] + rom[indices + 2 * i] * 16:
		g.s['ColArray1'] + (rom[indices + 2 * i] + 1) * 16] for i in range(count)]
	full = profiles.index(bytes([16]) * 16)
	for col in (4, 5):
		g.layout_cell(5, col, 255)
	for cell in range(64):
		g.write(g.terrain_address('chunks') + 255 * 128 + cell * 2, full | 0xF000, 2)
	g.write('Screen_redraw_flag', 1)
	g.run(8)
	return full, profiles


def spindash_wall(g, rom, act, mode, actor, direction, output):
	from check_companion_followup import place, spawn
	from check_object_course import objects
	floor_scene(g, rom)
	wall = spawn(g, 'Obj3C', 640, 608)
	other = 'v_player2' if actor == 'v_player' else 'v_player'
	place(g, other, 640 + direction * 96, 620, False)
	g.put(other, 'obControl', 0x81)
	place(g, actor, 640 - direction * 80, 620, True)
	g.put(actor, 'obStatus', 2 | (direction < 0))
	g.put(actor, 'obAngle', 0)
	g.put(actor, 'flip_angle', 0)
	g.put(actor, 'obStatusSecondary', 0)
	if actor == 'v_player2':
		g.buttons2 = {5}
	else:
		g.buttons = {5}
	g.run(20)
	assert not g.get(actor, 'obStatus') & 2, 'Spindash fixture did not land'
	pictures = []
	for _ in range(4):
		if actor == 'v_player2':
			g.buttons2 = {5, 0}
		else:
			g.buttons = {5, 0}
		g.run(2)
		pictures.append(g.video.copy())
		if actor == 'v_player2':
			g.buttons2 = {5}
		else:
			g.buttons = {5}
		g.run(4)
	assert g.get(actor, 'spindash_flag'), 'Controller did not charge a spindash'
	if actor == 'v_player2':
		g.buttons2 = {7 if direction > 0 else 6}
	else:
		g.buttons = {7 if direction > 0 else 6}
	peak_speed, parts = 0, []
	for tick in range(40):
		g.run()
		velocity = g.get(actor, 'obVelX', 2)
		peak_speed = max(peak_speed, abs(velocity if velocity < 32768 else velocity - 65536))
		if tick % 2 == 0:
			pictures.append(g.video.copy())
		parts = [a for a in objects(g, 0x3C) if g.get(a, 'obRoutine') == 4]
		if parts:
			break
	assert len(parts) == 8, ('Controller spindash did not break wall', act, mode, actor, direction, peak_speed)
	for _ in range(10):
		g.run(2)
		pictures.append(g.video.copy())
	stem = f'act{act+1}-mode{mode}-{actor}-dash-{direction}'
	pictures[0].save(output / (stem + '.gif'), save_all=True, append_images=pictures[1:], duration=34, loop=0)
	assert not g.read('v_errortype')
	return dict(act=act+1, mode=mode, actor=actor, direction=direction, fragments=8, peak_speed=peak_speed)


def sloped_push(g, rom, act, mode, direction, output):
	from check_companion_followup import place, spawn
	full, profiles = floor_scene(g, rom)
	indices = g.read('v_colladdr1', 4)
	slope = next(i for i, heights in enumerate(profiles)
		if rom[g.s['AngleMap'] + rom[indices + 2*i]] == 0xE8
		and min(heights) > 0 and max(heights) == 16)
	for row in range(8):
		for col in range(8):
			word = 0 if row < 3 else (slope if row == 3 else full) | 0xF000
			if direction > 0:
				word |= 0x400
			g.write(g.terrain_address('chunks') + 254 * 128 + (row * 8 + col) * 2, word, 2)
	for col in (4, 5):
		g.layout_cell(4, col, 254)
	g.write('Screen_redraw_flag', 1)
	wall = spawn(g, 'Obj3C', 600, 544)
	place(g, 'v_player2', 740, 620, False)
	g.put('v_player2', 'obControl', 0x81)
	place(g, 'v_player', 600-direction*48, 525, True)
	g.put('v_player', 'obStatus', 2 | int(direction < 0))
	g.put('v_player', 'obAngle', 0)
	g.put('v_player', 'flip_angle', 0)
	g.put('v_player', 'obStatusSecondary', 0)
	g.buttons = {7 if direction > 0 else 6}
	pictures, samples = [], []
	for tick in range(140):
		g.run()
		if g.get('v_player', 'obStatus') & 0x20:
			frame = g.get('v_player', 'obFrame')
			low, high = (0x48, 0x4B) if mode == 0 else (0xA9, 0xAC)
			if low <= frame <= high:
				samples.append((g.get('v_player', 'obAngle'), g.get('v_player', 'obRender') & 3))
				assert samples[-1][1] == int(direction < 0), ('Sloped push flipped body', act, mode, direction, samples[-1])
			if tick % 2 == 0:
				pictures.append(g.video.copy())
	assert len(samples) >= 60, ('Pushing fixture missed wall', act, mode, direction, samples)
	assert any(angle == (0x18 if direction > 0 else 0xE8) for angle, _ in samples)
	stem = f'act{act+1}-mode{mode}-push-{direction}'
	pictures[len(pictures)//2].save(output / (stem + '.png'))
	pictures[0].save(output / (stem + '.gif'), save_all=True, append_images=pictures[1:], duration=34, loop=0)
	assert g.get(wall, 'obRoutine') == 2, 'Walking push broke wall'
	assert not g.read('v_errortype')
	return dict(act=act+1, mode=mode, direction=direction, upright_push_frames=len(samples))


def spiral(g, act, mode, direction, output):
	from check_companion_followup import place
	from check_object_course import objects
	# Traverse the complete Act-2 chain; the joins have no ordinary floor.
	x, y = (4800 if act == 0 else (7232 if direction > 0 else 8000)), 1408
	exit_x = x + direction * (250 + (768 if act else 0))
	place(g, 'v_player', x-direction*216, y+32, False)
	g.put('v_player', 'obControl', 0x81)
	g.put('v_player2', 'obControl', 0x81)
	for name, value in (('Camera_X_pos', x-320), ('Camera_Y_pos', y-112),
		('Camera_Min_X_pos', 0), ('Camera_Max_X_pos', 0x2B00),
		('Camera_Max_X_pos_target', 0x2B00), ('Camera_Max_Y_pos', 0x720),
		('Camera_Max_Y_pos_target', 0x720)):
		g.write(name, value, 2)
	g.write('Screen_redraw_flag', 1)
	g.run(30)
	assert any(g.get(a, 'obX', 2) == x for a in objects(g, 6)), 'Authored spiral did not load'
	place(g, 'v_player', x-direction*216, y+32, False)
	for field, value, size in (('obStatus', int(direction < 0), 1), ('obAngle', 0, 1),
		('flip_angle', 0, 1), ('obVelX', direction*0x900 & 65535, 2),
		('obInertia', direction*0x900 & 65535, 2), ('obStatusSecondary', 2, 1), ('invtime', 6000, 2)):
		g.put('v_player', field, value, size)
	g.buttons = {7 if direction > 0 else 6}
	pictures, poses, trace, visited = [], set(), [], set()
	base = 0x5F if mode == 0 else 0x31
	for tick in range(190):
		phase = g.get('v_player', 'flip_angle')
		g.run()
		if phase and g.get('v_player', 'obAnim') == 0:
			frame = g.get('v_player', 'obFrame')
			assert base <= frame < base+12, ('Wrong character tumble frames', act, mode, direction, phase, frame)
			poses.add(frame)
		trace.append([g.get('v_player', f, size) for f, size in
			(('obX', 2), ('obY', 2), ('obFrame', 1), ('flip_angle', 1), ('obStatus', 1))])
		if tick % 2 == 0:
			pictures.append(g.video.copy())
		visited.update(g.get(a, 'obX', 2) for a in objects(g, 6) if g.get(a, 'obStatus') & 8)
		if direction * (g.get('v_player', 'obX', 2)-exit_x) > 0:
			break
	assert len(poses) >= 10, ('Spiral was not traversed', act, mode, direction, trace)
	assert direction * (trace[-1][0]-exit_x) > 0 and not trace[-1][3], ('Spiral exit', act, mode, direction, trace[-8:])
	assert ({7232, 7616, 8000} if act else {4800}) <= visited, ('Skipped a spiral', act, mode, direction, visited)
	stem = f'act{act+1}-mode{mode}-spiral-{direction}'
	pictures[0].save(output / (stem + '.gif'), save_all=True, append_images=pictures[1:], duration=34, loop=0)
	(output / (stem + '.json')).write_text(json.dumps(trace) + '\n')
	assert not g.read('v_errortype')
	return dict(act=act+1, mode=mode, direction=direction, tumble_poses=sorted(poses), spiral_centers=sorted(visited), frames=len(trace))


def live_checks(args):
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	g = Genesis(args.core, args.rom, args.listing, args.output, args.pal, system_directory=args.system_directory)
	rom = args.rom.read_bytes()
	report = dict(spirals=[], pushing=[], spindashes=[])
	for act in (0, 1):
		for mode in (0, 2):
			g.core.retro_reset()
			boot_level(g, zone=3, act=act, player=mode)
			state = g.save()
			for direction in (1, -1):
				g.restore(state)
				report['spirals'].append(spiral(g, act, mode, direction, args.output))
				g.restore(state)
				report['pushing'].append(sloped_push(g, rom, act, mode, direction, args.output))
				for actor in (('v_player', 'v_player2') if mode == 0 else ('v_player',)):
					g.restore(state)
					report['spindashes'].append(spindash_wall(g, rom, act, mode, actor, direction, args.output))
			print(f'Act {act+1}, mode {mode}: corkscrews, slopes and controller spindashes pass.', flush=True)
	g.close()
	return report


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
	p.add_argument('--core', type=Path)
	p.add_argument('--system-directory', type=Path)
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--pal', action='store_true')
	p.add_argument('--probe', action='store_true', help='Record older failures without accepting them as a pass')
	args = p.parse_args()
	args.output.mkdir(parents=True, exist_ok=True)
	report = dict(animations=animation_checks(args), walls=wall_checks(args))
	if args.core:
		report['live'] = live_checks(args)
	(args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
	print(json.dumps(report, indent=2))
	if not args.probe:
		assert report['animations']['failures'] == 0
		assert all(row['passed'] for row in report['walls'])


if __name__ == '__main__':
	main()
