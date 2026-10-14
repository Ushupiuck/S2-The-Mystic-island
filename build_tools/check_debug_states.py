#!/usr/bin/env python3
"""Enter Debug during real monitor-inflicted recoil/death in Genesis Plus GX.

Fixtures only place the hazard and position the player. The collision,
damage, button handling, Debug entry and restoration use the real ROM code.
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
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
    boot_level(g, item=0, player=args.player)
    g.put('v_player2', 'code', 0)
    baseline = g.save()
    slots = range(g.s['v_lvlobjspace'] & 0xFFFF,
                  g.s['v_lvlobjend'] & 0xFFFF, g.s['object_size'])
    report = {'region': 'PAL' if args.pal else 'NTSC',
              'player': 'Tails' if args.player else 'Sonic', 'cases': []}
    for routine, rings, label in ((4, 40, 'hurt'), (6, 0, 'dying')):
        for frame_cycle in (False, True):
            g.restore(baseline)
            g.write('Debug_mode_flag', 0)  # zero-ring Debug immunity is intentional
            g.write('v_rings', rings, 2)
            x = g.get('v_player', 'obX', 2)
            y = g.get('v_player', 'obY', 2) - 64
            obj = next(a for a in slots if not g.get(a, 'code'))
            for field, value, size in [('code', g.s['Obj26'], 4),
                    ('obX', x, 2), ('obY', y, 2), ('obSubtype', 0, 1)]:
                g.put(obj, field, value, size)
            for field, value, size in [('obY', y - 110, 2), ('obStatus', 6, 1),
                    ('obAnim', g.s['AniIDSonAni_Roll'], 1),
                    ('obPrevAni', 0xFF, 1), ('obStatusSecondary', 0, 1),
                    ('flashtime', 0, 2), ('obVelX', 0, 2), ('obVelY', 0, 2),
                    ('obHeight', g.s['tails_roll_height' if args.player else 'sonic_roll_height'], 1),
                    ('obWidth', g.s['tails_roll_width' if args.player else 'sonic_roll_width'], 1)]:
                g.put('v_player', field, value, size)
            for tick in range(180):
                g.run()
                if g.get('v_player', 'obRoutine') == routine:
                    break
            else:
                raise AssertionError(('Monitor did not produce the real state', label))
            code = g.get('v_player', 'code')
            mapping = g.get('v_player', 'obMap', 4)
            g.write('Debug_mode_flag', 1)
            g.buttons = {0, 8} if frame_cycle else {0}  # Genesis B / C+B
            g.run()
            expected = 2 if frame_cycle else 1
            assert g.read('Debug_placement_type') == expected, (label, frame_cycle)
            g.buttons = set()
            g.run(3)
            assert g.get('v_player', 'code') == code
            if frame_cycle:
                before = g.get('v_player', 'obFrame')
                g.run(2)
                assert g.get('v_player', 'obFrame') != before
            else:
                assert g.get('v_player', 'obMap', 4) != mapping
            g.video.save(args.output / f'{label}-{expected}-debug.png')
            g.buttons = {0}
            g.run()
            assert not g.read('Debug_placement_mode', 2)
            assert g.get('v_player', 'code') == code
            assert g.get('v_player', 'obMap', 4) == mapping
            if not frame_cycle:
                assert g.get('v_player', 'obRoutine') == 2
                assert g.get('v_player', 'obHeight') == g.get('v_player', 'default_y_radius')
                assert g.get('v_player', 'obWidth') == g.get('v_player', 'default_x_radius')
                assert not g.get('v_player', 'obVelX', 2)
                assert not g.get('v_player', 'obVelY', 2)
                g.buttons = set()
                g.run(45)
                assert g.get('v_player', 'obRoutine') == 2
            assert not g.read('v_errortype')
            row = {'state': label, 'debug_type': expected, 'entered': True,
                   'code_preserved': True, 'mappings_restored': True,
                   'exit_routine': g.get('v_player', 'obRoutine')}
            report['cases'].append(row)
            g.video.save(args.output / f'{label}-{expected}-exit.png')
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(report)
    g.close()


if __name__ == '__main__':
    main()
