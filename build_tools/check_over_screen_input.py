#!/usr/bin/env python3
"""Real zero-ring monitor deaths: lock Debug during Over cards, then unlock.

Physical buttons must still advance the cards. Hurt/death Debug entry before
the cards is covered independently by check_debug_states.py.
"""
from pathlib import Path
import argparse
import json

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import isolate, spawn, place


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--player', type=int, choices=(0, 2), default=0)
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
    boot_level(g, item=0, player=args.player)
    isolate(g)
    g.put('v_player2', 'code', 0)
    baseline = g.save()
    rows = []
    for time_over in (False, True):
        g.restore(baseline)
        g.write('Debug_mode_flag', 0)
        g.write('v_rings', 0, 2)
        g.write('v_lives', 3 if time_over else 1)
        g.write('v_continues', 0)
        g.write('f_timeover', int(time_over))
        spawn(g, 'Obj26', 80, 860, 0)
        place(g, 'v_player', 80, 730)
        for f, v, n in [('obStatus', 6, 1), ('obAnim', g.s['AniIDSonAni_Roll'], 1),
                        ('obStatusSecondary', 0, 1),
                        ('obHeight', g.s['tails_roll_height' if args.player else 'sonic_roll_height'], 1),
                        ('obWidth', g.s['tails_roll_width' if args.player else 'sonic_roll_width'], 1)]:
            g.put('v_player', f, v, n)
        died = False
        for tick in range(360):
            g.run()
            died |= g.get('v_player', 'obRoutine') == 6
            if g.read('f_lockctrl') == g.s['PlayerInputLock_Over']:
                break
        assert died and g.read('f_lockctrl') == g.s['PlayerInputLock_Over']
        assert not g.read('v_jpadholdlogical', 2)
        g.write('Debug_mode_flag', 1)
        g.buttons = {0}  # B while words are still entering
        g.run(1)
        assert not g.read('Debug_placement_mode', 2)
        assert not g.read('v_jpadholdlogical', 2)
        g.buttons = set()
        for tick in range(120):
            g.run()
            if g.get('v_gameovertext1', 'obRoutine') == 4:
                break
        assert g.get('v_gameovertext1', 'obRoutine') == 4
        g.video.save(args.output / ('time-over.png' if time_over else 'game-over.png'))
        g.buttons2 = {8}  # physical controller 2 C still advances the card
        g.run(1)
        g.buttons2 = set()
        assert not g.read('Debug_placement_mode', 2)
        if time_over:
            for tick in range(600):
                g.run()
                if (g.read('v_vbla_routine', 2) == g.s['Vint_Level'] and
                        g.get('v_player', 'obRoutine') == 2 and
                        g.read('f_timecount') and not g.read('f_lockctrl')):
                    break
            else:
                raise AssertionError('Time Over did not restart with unlocked input')
        else:
            assert g.read('v_gamemode', 2) == g.s['SegaScreen']
            assert not g.read('f_lockctrl')
            g.run(3)
            assert not g.read('f_lockctrl')
        assert not g.read('v_errortype')
        rows.append({'card': 'time-over' if time_over else 'game-over',
                     'debug_blocked': True, 'raw_controller2_advance': True,
                     'input_unlocked_after_exit': True})
    (args.output / 'report.json').write_text(json.dumps(rows, indent=2) + '\n')
    print({'player': args.player, 'pal': args.pal, 'cases': rows})
    g.close()


if __name__ == '__main__':
    main()
