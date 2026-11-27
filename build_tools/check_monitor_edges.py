#!/usr/bin/env python3
"""Exercise angled attacks, held-charge landings and harmful monitor rewards.

Fixtures place a monitor and position a player above it. The real movement,
collision and reward routines run afterward; no collision result is injected.
"""
from pathlib import Path
import argparse
import json
from itertools import product

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import isolate, place, spawn
from check_signpost_game import park_fixture_camera


def check_attack_angles(g, args):
	initial = g.save()
	s = g.s
	roles = ('v_player', 'v_player2') if args.player == 0 else ('v_player',)
	cases = (('right-up', -36, 0, 0x600, -0x400),
		('left-up', 36, 0, -0x600, -0x400),
		('right-down', -36, -16, 0x400, 0x200),
		('left-down', 36, -16, -0x400, 0x200),
		('up', 0, 40, 0, -0x600), ('down', 0, -40, 0, 0x200),
		('right-level', -36, 0, 0x600, 0), ('left-level', 36, 0, -0x600, 0),
		('stack-right-up', 36, 0, -0x600, -0x400),
		('stack-left-up', -36, 0, 0x600, -0x400))
	rows = []
	for who, miniature in product(roles, (False, True)):
		g.restore(initial)
		isolate(g)
		park_fixture_camera(g)
		if who == 'v_player':
			g.put('v_player2', 'code', 0)
		else:
			place(g, 'v_player', 40, 1452, False)
			g.put('v_player', 'obControl', 1)  # keep the real lead player outside the fixture
		place(g, who, 80, 1452, False)
		g.write('Tails_CPU_routine', 6, 2)
		g.write('Tails_CPU_idle_timer', 6000, 2)
		g.buttons2 = {4}
		if miniature:
			spawn(g, 'MMZ_Laser', 80, 1280, 0)
			for _ in range(100):
				g.run()
				assert not g.read('v_errortype')
				if g.get(who, 'default_y_radius') == s['Player_MiniHeight']:
					break
			else:
				raise AssertionError((who, 'shrink beam did not resize the actor'))
			g.run(3)
			isolate(g)  # retain the real resized character; retire the setup laser
			place(g, who, 80, 1461, False)
		form = g.save()
		for name, dx, dy, vx, vy in cases:
			g.restore(form)
			g.write('Tails_CPU_idle_timer', 6000, 2)
			g.buttons2 = {4}  # manual controller 2, without horizontal steering or flight
			mx, my = (176 if name == 'stack-left-up' else 240), 1360
			if name.startswith('stack-'):
				stack = [spawn(g, 'Monitor', x, my, s['MonitorType_Rings']) for x in (176, 208, 240)]
				spawn(g, 'Monitor', 208, my-32, s['MonitorType_Rings'])
				mon = stack[0 if name == 'stack-left-up' else 2]
			else:
				mon = spawn(g, 'Monitor', mx, my, s['MonitorType_Rings'])
			g.run(3)
			place(g, who, mx+dx, my+dy)
			tails = g.get(who, 'character_id') == s['CharacterID_Tails']
			height = s['Player_MiniRollHeight'] if miniature else s['tails_roll_height' if tails else 'sonic_roll_height']
			width = s['Player_MiniWidth'] if miniature else s['tails_roll_width' if tails else 'sonic_roll_width']
			for field, value, size in (('obStatus', 6, 1), ('obAnim', s['AniIDSonAni_Roll'], 1),
				('obHeight', height, 1), ('obWidth', width, 1),
				('obVelX', vx & 65535, 2), ('obVelY', vy & 65535, 2), ('obInertia', vx & 65535, 2)):
				g.put(who, field, value, size)
			g.put(who, 'obAngle', 0)
			trace = []
			broken = False
			for tick in range(30):
				g.run()
				assert not g.read('v_errortype'), (who, name, 'ROM exception')
				trace.append((g.get(who, 'obX', 2), g.get(who, 'obY', 2), g.get(mon, 'obRoutine')))
				if tick in (5, 15, 29):
					g.video.save(args.output / f'{who}-{"mini" if miniature else "full"}-{name}-{tick}.png')
				broken |= g.get(mon, 'obRoutine') >= 4
			if miniature:
				assert g.get(who, 'default_y_radius') == s['Player_MiniHeight']
				assert g.get(who, 'obMap', 4) == s['Map_MiniTails' if tails else 'Map_MiniSonic']
			row = {'actor': who, 'miniature': miniature, 'case': name, 'broken': broken,
				'collector': g.get(mon, 'obParent', 2), 'trace': trace}
			rows.append(row)
			print({key: value for key, value in row.items() if key != 'trace'}, flush=True)
			if not args.probe:
				assert broken and row['collector'] == s[who] & 65535, row
	g.restore(initial)
	return rows


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--player', type=int, choices=(0, 2), default=0)
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--probe', action='store_true', help='Report the old behavior without asserting fixes')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal, system_directory=args.system_directory)
    boot_level(g, item=0, player=args.player)
    angle_cases = check_attack_angles(g, args)
    g.put('v_player2', 'code', 0)
    baseline = g.save()
    x = g.get('v_player', 'obX', 2)
    y = g.get('v_player', 'obY', 2) - 64
    slots = range(g.s['v_lvlobjspace'] & 0xFFFF, g.s['v_lvlobjend'] & 0xFFFF, g.s['object_size'])
    report = {'region': 'PAL' if args.pal else 'NTSC', 'player': 'Tails' if args.player else 'Sonic', 'cases': {}, 'attack_angles': angle_cases}

    def setup(subtype, charge=False):
        g.restore(baseline)
        obj = next(a for a in slots if not g.get(a, 'code'))
        for field, value, size in [('code', g.s['Monitor'], 4), ('obX', x, 2),
                ('obY', y, 2), ('obSubtype', subtype, 1)]:
            g.put(obj, field, value, size)
        for field, value, size in [('obX', x, 2), ('obY', y - 110, 2),
                ('obVelX', 0, 2), ('obVelY', 0, 2), ('obInertia', 0, 2),
                ('obRoutine', 2, 1), ('obControl', 0, 1),
                ('obStatus', 2 if charge else 6, 1), ('obStatusSecondary', 0, 1),
                ('flashtime', 0, 2), ('invtime', 0, 2),
                ('obAnim', g.s['AniIDSonAni_Spindash'] if charge else g.s['AniIDSonAni_Roll'], 1),
                ('obPrevAni', 0xFF, 1), ('spindash_flag', int(charge), 1),
                ('spindash_counter', 0x600 if charge else 0, 2)]:
            g.put('v_player', field, value, size)
        if not charge:
            g.put('v_player', 'obHeight', g.s['tails_roll_height'] if args.player else g.s['sonic_roll_height'])
            g.put('v_player', 'obWidth', g.s['tails_roll_width'] if args.player else g.s['sonic_roll_width'])
        g.write('v_rings', 40, 2)
        g.buttons = {5} if charge else set()
        return obj

    obj = setup(2, charge=True)
    landed = False
    dust_visible = False
    dust = g.get('v_player', 'player_dust_ptr', 2)
    for tick in range(90):
        g.run()
        standing = bool(g.get('v_player', 'obStatus') & (1 << g.s['status.player.on_object']))
        landed |= standing
        if standing:
            dust_visible |= bool(g.get(dust, 'obAnim'))
    row = {'landed': landed, 'dust_resumed': dust_visible,
           'monitor_unbroken': g.get(obj, 'obRoutine') == 2,
           'charge_held': g.get('v_player', 'spindash_flag') == 1,
           'player_y': g.get('v_player', 'obY', 2), 'monitor_y': g.get(obj, 'obY', 2)}
    report['cases']['held_charge_landing'] = row
    g.video.save(args.output / 'held-charge.png')
    if not args.probe:
        assert all(row[k] for k in ('landed', 'dust_resumed', 'monitor_unbroken', 'charge_held')), row

    for name, subtype, rings, shield, invincible, flashing in (
            ('blank', 0, 40, False, False, False),
            ('eggman', 0, 40, False, False, False),
            ('blank_zero_rings', 0, 0, False, False, False),
            ('blank_shield', 0, 0, True, False, False),
            ('blank_invincible', 0, 40, False, True, False),
            ('blank_flashing', 0, 40, False, False, True)):
        obj = setup(subtype)
        g.write('v_rings', rings, 2)
        g.put('v_player', 'obStatusSecondary', int(shield) | (int(invincible) << 1))
        g.put('v_player', 'invtime', 600 if invincible else 0, 2)
        g.put('v_player', 'flashtime', 180 if flashing else 0, 2)
        broke = False
        hurt = False
        died = False
        minimum_rings = rings
        icon_hurt = False
        icon_death = False
        for tick in range(120):
            g.run()
            broke |= g.get(obj, 'obRoutine') >= 4
            hurt |= g.get('v_player', 'obRoutine') == 4
            died |= g.get('v_player', 'obRoutine') == 6
            minimum_rings = min(minimum_rings, g.read('v_rings', 2))
            for a in slots:
                if g.get(a, 'code') == g.s['MonitorContents']:
                    icon_hurt |= g.get(a, 'obAnim') == g.s['AniIDSonAni_Hurt']
                    icon_death |= g.get(a, 'obRoutine') == 6
        row = {'broken': broke, 'collector_hurt': hurt, 'collector_died': died, 'icon_hurt': icon_hurt,
               'icon_died': icon_death, 'rings': g.read('v_rings', 2),
               'minimum_rings': minimum_rings,
               'icon_deleted': not any(g.get(a, 'code') == g.s['MonitorContents'] for a in slots)}
        report['cases'][name] = row
        g.video.save(args.output / (name + '.png'))
        if not args.probe:
            assert broke and not icon_hurt and not icon_death and row['icon_deleted'], row
            protected = invincible or flashing
            assert hurt == (not protected and (shield or rings > 0)), row
            assert died == (not protected and not shield and rings == 0), row
            assert minimum_rings == (rings if protected or shield else 0), row
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f"{len(angle_cases)} attack-angle cases and {len(report['cases'])} monitor behavior cases checked.", flush=True)
    g.close()


if __name__ == '__main__':
    main()
