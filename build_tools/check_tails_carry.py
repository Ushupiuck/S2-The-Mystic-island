#!/usr/bin/env python3
"""Exercise Tails carry transitions through real SMZ game frames.

Fixtures position actors and an electrocuter; pickup, zap timing, damage,
recoil, release, gravity, landings and graphics execute in the built ROM.
--probe records older-ROM failures without treating them as passes.
"""
from pathlib import Path
import argparse
import json

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import isolate, place, reset_cpu, spawn


def main():
	p = argparse.ArgumentParser(description=__doc__)
	for name in ('core', 'rom', 'listing', 'output'):
		p.add_argument('--' + name, type=Path, required=True)
	p.add_argument('--system-directory', type=Path)
	p.add_argument('--pal', action='store_true')
	p.add_argument('--probe', action='store_true')
	args = p.parse_args()
	g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
		system_directory=args.system_directory)
	boot_level(g, zone=8)
	isolate(g)
	place(g, 'v_player', 160, 600)
	place(g, 'v_player2', 160, 564)
	reset_cpu(g)
	g.write('Camera_X_pos', 0, 2)
	g.write('Camera_Y_pos', 470, 2)
	g.put('v_player2', 'tails_flight_flag', 1)
	g.put('v_player2', 'tails_flight_energy', g.s['Tails_FlightBudget'])
	g.write('Tails_CPU_idle_timer', 600, 2)
	g.run()
	assert g.read('Flying_carrying_Sonic_flag') == 1, 'Fixture never picked up Sonic'
	picked = g.save()
	rows = []

	def sample():
		fields = (('obX', 2), ('obY', 2), ('obVelY', 2), ('obRoutine', 1),
			('obControl', 1), ('obStatus', 1), ('obAnim', 1), ('tails_flight_flag', 1))
		return {'carry': g.read('Flying_carrying_Sonic_flag'), **{
			actor: {field: g.get(actor, field, size) for field, size in fields}
			for actor in ('v_player', 'v_player2')}}

	def finish(label, ok, **detail):
		rows.append({'case': label, 'passed': bool(ok), **detail})
		print(rows[-1], flush=True)
		assert not g.read('v_errortype'), (label, 'ROM exception')
		if not args.probe:
			assert ok, rows[-1]

	attached = True
	for _ in range(48):
		g.run()
		attached &= (g.read('Flying_carrying_Sonic_flag') == 1 and
			g.get('v_player', 'obControl') == 3 and
			g.get('v_player', 'obY', 2) - g.get('v_player2', 'obY', 2) == g.s['Tails_CarriedYOffset'])
	finish('ordinary carry remains attached', attached)

	for label, victim, rings in (('carrier hurt', 'v_player2', 99),
			('carrier killed', 'v_player2', 0), ('passenger hurt', 'v_player', 99)):
		g.restore(picked)
		g.write('v_rings', rings, 2)
		spawn(g, 'SMZ_Electro', g.get(victim, 'obX', 2),
			g.get(victim, 'obY', 2) - (12 if victim == 'v_player2' else -8), 1)
		trace = []
		for tick in range(40):
			g.run()
			trace.append(sample())
			if g.get(victim, 'obRoutine') >= 4:
				break
		else:
			(args.output / 'missed-shock.json').write_text(json.dumps(trace))
			raise AssertionError((label, 'Electrocuter never hit the intended actor', sample()))
		expected = 6 if not rings else 4
		assert g.get(victim, 'obRoutine') == expected, (label, sample())
		g.video.save(args.output / (label.replace(' ', '-') + '-hit.png'))
		g.run()  # the next player update must detach before Tails's recoil moves
		after = sample()
		ok = after['carry'] == 0 and after['v_player']['obControl'] == 0
		if victim == 'v_player2':
			ok &= after['v_player']['obRoutine'] == 2 and bool(after['v_player']['obStatus'] & 2)
			start_y = g.get('v_player', 'obY', 2)
			g.run(12)
			ok &= g.get('v_player', 'obY', 2) > start_y
			g.video.save(args.output / (label.replace(' ', '-') + '-fall.png'))
			g.run(150)
			ok &= g.get('v_player', 'obRoutine') == 2 and not g.get('v_player', 'obStatus') & 2
		else:
			ok &= after['v_player']['obRoutine'] == 4 and after['v_player']['obAnim'] == g.s['AniIDSonAni_Hurt']
		(args.output / (label.replace(' ', '-') + '-trace.json')).write_text(json.dumps(trace))
		finish(label, ok, hit_tick=tick, after=after)

	g.restore(picked)
	g.buttons = {0}
	g.run(2)
	finish('passenger jumps off', not g.read('Flying_carrying_Sonic_flag') and
		not g.get('v_player', 'obControl') and g.get('v_player', 'jumping') == 1 and
		g.get('v_player', 'obAnim') == g.s['AniIDSonAni_Roll'] and
		g.get('v_player', 'obVelY', 2) == 0xFC80, after=sample())
	g.buttons = set()

	g.restore(picked)
	spawn(g, 'Obj18', 160, 670)
	for tick in range(120):
		g.run()
		if not g.read('Flying_carrying_Sonic_flag'):
			break
	finish('passenger reaches a platform', tick < 119 and
		not g.get('v_player', 'obControl') and g.get('v_player', 'obRoutine') == 2)

	for control in (1, 3, 0x81):
		g.restore(picked)
		g.put('v_player2', 'obControl', control)
		g.run(2)
		locked = sample()
		ok = not g.get('v_player2', 'tails_flight_flag') and not g.read('Flying_carrying_Sonic_flag')
		ok &= not g.get('v_player', 'obControl') and g.get('v_player2', 'obControl') == control
		g.put('v_player2', 'obControl', 0)
		velocity = g.get('v_player2', 'obVelY', 2)
		# A video frame can end before this actor's next movement update.
		for _ in range(4):
			g.run()
			if g.get('v_player2', 'obVelY', 2) != velocity:
				break
		ok &= g.get('v_player2', 'obVelY', 2) == (velocity + 0x38) & 0xFFFF
		finish(f'carrier object lock ${control:02X}', ok, velocity=velocity, locked=locked, after=sample())

	# A normal hurt companion has no passenger; the early return preserves Sonic.
	g.restore(picked)
	g.write('Flying_carrying_Sonic_flag', 0, 2)
	g.put('v_player', 'obControl', 0x81)
	g.put('v_player2', 'obRoutine', 4)
	g.put('v_player2', 'obAnim', g.s['AniIDSonAni_Hurt'])
	g.run(2)
	finish('unrelated hurt preserves Sonic lock', g.get('v_player', 'obControl') == 0x81)

	(args.output / 'report.json').write_text(json.dumps({'passed': all(row['passed'] for row in rows),
		'region': 'PAL' if args.pal else 'NTSC', 'checks': rows}, indent=2) + '\n')
	g.close()


if __name__ == '__main__':
	main()
