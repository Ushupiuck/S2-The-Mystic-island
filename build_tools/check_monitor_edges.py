#!/usr/bin/env python3
"""Exercise held-charge monitor landings and harmful monitor rewards in Genesis Plus GX.

Fixtures place a monitor and position a player above it. The real movement,
collision and reward routines run afterward; no collision result is injected.
"""
from pathlib import Path
import argparse
import json

from genesis_test_core import Genesis
from check_object_course import boot_level


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--player', type=int, choices=(0, 2), default=0)
    p.add_argument('--probe', action='store_true', help='Report the old behavior without asserting fixes')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
    boot_level(g, item=0, player=args.player)
    g.put('v_player2', 'code', 0)
    baseline = g.save()
    x = g.get('v_player', 'obX', 2)
    y = g.get('v_player', 'obY', 2) - 64
    slots = range(g.s['v_lvlobjspace'] & 0xFFFF, g.s['v_lvlobjend'] & 0xFFFF, g.s['object_size'])
    report = {'region': 'PAL' if args.pal else 'NTSC', 'player': 'Tails' if args.player else 'Sonic', 'cases': {}}

    def setup(subtype, charge=False):
        g.restore(baseline)
        obj = next(a for a in slots if not g.get(a, 'code'))
        for field, value, size in [('code', g.s['Obj26'], 4), ('obX', x, 2),
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

    obj = setup(6, charge=True)
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
            ('eggman', 3, 40, False, False, False),
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
                if g.get(a, 'code') == g.s['Obj29']:
                    icon_hurt |= g.get(a, 'obAnim') == g.s['AniIDSonAni_Hurt']
                    icon_death |= g.get(a, 'obRoutine') == 6
        row = {'broken': broke, 'collector_hurt': hurt, 'collector_died': died, 'icon_hurt': icon_hurt,
               'icon_died': icon_death, 'rings': g.read('v_rings', 2),
               'minimum_rings': minimum_rings,
               'icon_deleted': not any(g.get(a, 'code') == g.s['Obj29'] for a in slots)}
        report['cases'][name] = row
        g.video.save(args.output / (name + '.png'))
        if not args.probe:
            assert broke and not icon_hurt and not icon_death and row['icon_deleted'], row
            protected = invincible or flashing
            assert hurt == (not protected and (shield or rings > 0)), row
            assert died == (not protected and not shield and rings == 0), row
            assert minimum_rings == (rings if protected or shield else 0), row
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(report, flush=True)
    g.close()


if __name__ == '__main__':
    main()
