#!/usr/bin/env python3
"""Run real LZ air expiry, drowning input locks and level restart in the core."""
from pathlib import Path
import argparse
import json

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import isolate, place


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--player', type=int, choices=(0, 2), default=0)
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
    boot_level(g, item=6, player=args.player)
    isolate(g)
    water = g.read('v_waterpos1', 2)
    x = 0xE00
    place(g, 'v_player', x, water + 64)
    g.put('v_player', 'obControl', 1)
    g.write('Camera_X_pos', x - 160, 2)
    g.write('Camera_Y_pos', water - 100, 2)
    g.write('Debug_mode_flag', 1)
    g.run(8)
    assert g.get('v_player', 'obStatus') & 64
    assert g.get('v_sonicbubbles', 'code') == g.s['Obj0A']
    underwater = g.save()
    rows = []

    # Low air itself is not the exception: B still enters before expiry.
    g.write('v_air', 5, 2)
    g.buttons = {0}
    g.run()
    assert g.read('Debug_placement_mode', 2)
    rows.append({'case': 'low-air-debug', 'allowed': True})

    g.restore(underwater)
    g.write('v_lives', 3)
    g.write('v_air', 0, 2)
    g.put('v_sonicbubbles', 'objoff_3C', 0, 2)
    g.run()
    assert g.get('v_player', 'obAnim') == g.s['AniIDSonAni_Drown']
    assert g.get('v_player', 'obRoutine') == 2
    assert g.read('f_lockctrl') == g.s['PlayerInputLock_Drowning']
    for tick in range(120):
        g.buttons = {0, 7} if tick % 2 else {0, 8, 5}
        g.buttons2 = {0, 6, 8}
        g.run()
        assert not g.read('Debug_placement_mode', 2)
        assert not g.read('v_jpadholdlogical', 2)
        assert not g.read('v_jpadholdlogical2', 2)
        assert g.read('f_lockctrl') == g.s['PlayerInputLock_Drowning']
    assert g.get('v_player', 'obRoutine') == 6
    g.video.save(args.output / 'drowning-debug-blocked.png')
    rows.append({'case': 'primary-drowning', 'animation_debug_blocked': True,
                 'both_logical_inputs_neutral': True, 'real_death_routine': True})

    g.buttons = g.buttons2 = set()
    for tick in range(720):
        g.run()
        if (g.get('v_player', 'obRoutine') == 2 and g.read('f_timecount') and
                not g.read('f_lockctrl') and not g.read('f_playerctrl')):
            break
    else:
        raise AssertionError('Drowning did not restart with unlocked input')
    assert g.read('v_lives') == 2
    g.run(90)  # wait for the normal level loop after the restart's fade-in
    # Level initialization clears the temporary test cheat; re-enable it to
    # test the released lock rather than requiring a different cheat policy.
    g.write('Debug_mode_flag', 1)
    g.buttons = {0}
    g.run()
    assert g.read('Debug_placement_mode', 2), {
        f: g.read(f, n) for f, n in [('f_lockctrl', 1), ('Debug_mode_flag', 1),
                                    ('v_gamemode', 2), ('v_jpadpress1', 1)]}
    rows.append({'case': 'drowning-restart', 'input_and_debug_unlocked': True})

    if args.player == 0:
        g.restore(underwater)
        place(g, 'v_player', x, water - 64)
        place(g, 'v_player2', x - 32, water + 64)
        g.put('v_player', 'obControl', 1)
        g.put('v_player2', 'obControl', 1)
        g.write('Tails_CPU_idle_timer', 600, 2)
        g.run(8)
        assert g.get('v_tailsbubbles', 'code') == g.s['Obj0A']
        g.put('v_player2', 'air_left', 0)
        g.put('v_tailsbubbles', 'objoff_3C', 0, 2)
        g.run()
        assert g.get('v_player2', 'obAnim') == g.s['AniIDSonAni_Drown']
        assert not g.read('f_lockctrl')
        g.buttons = {0}
        g.run()
        assert g.read('Debug_placement_mode', 2)
        rows.append({'case': 'companion-drowning', 'primary_debug_allowed': True})
    assert not g.read('v_errortype')
    report = {'player': 'Tails' if args.player else 'Sonic',
              'region': 'PAL' if args.pal else 'NTSC', 'cases': rows}
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(report, flush=True)
    g.close()


if __name__ == '__main__':
    main()
