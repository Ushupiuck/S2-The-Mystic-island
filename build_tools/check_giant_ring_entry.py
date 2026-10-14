#!/usr/bin/env python3
"""Follow actual giant-ring contacts through the last flash frame in Genesis Plus GX."""
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
    p.add_argument('--probe', action='store_true')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
    boot_level(g, item=0, player=args.player)
    g.put('v_player2', 'code', 0)
    baseline = g.save()
    x = g.get('v_player', 'obX', 2) + 96
    y = g.get('v_player', 'obY', 2) - 160
    slots = range(g.s['v_lvlobjspace'] & 0xFFFF, g.s['v_lvlobjend'] & 0xFFFF, g.s['object_size'])
    report = {'region': 'PAL' if args.pal else 'NTSC', 'player': 'Tails' if args.player else 'Sonic', 'cases': []}
    for count, velocity in ((1, 0x600), (3, 0xA00), (3, 0xF600)):
        g.restore(baseline)
        g.write('v_rings', 99, 2)
        g.write('v_emeralds', 0)
        for i in range(count):
            a = next(a for a in slots if not g.get(a, 'code'))
            for field, value, size in [('code', g.s['GiantRing'], 4), ('obX', x, 2), ('obY', y + i * 40, 2)]:
                g.put(a, field, value, size)
        g.run(3)
        start_y = y + (count - 1) * 40 + 72 if velocity & 0x8000 else y - 72
        for field, value, size in [('obX', x, 2), ('obY', start_y, 2),
                ('obVelX', 0, 2), ('obVelY', velocity, 2), ('obInertia', 0, 2),
                ('obStatus', 2, 1), ('obControl', 0, 1), ('obRoutine', 2, 1),
                ('obStatusSecondary', 0, 1), ('flashtime', 0, 2)]:
            g.put('v_player', field, value, size)
        seen_flash = False
        vanished = False
        max_flashes = 0
        error = 0
        start_vint = g.read('Vint_runcount', 4)
        for tick in range(100):
            g.run()
            flashes = sum(g.get(a, 'code') == g.s['GiantRingFlash'] for a in slots)
            max_flashes = max(max_flashes, flashes)
            seen_flash |= flashes > 0
            vanished |= not g.get('v_player', 'code')
            error = g.read('v_errortype')
            if error:
                break
        row = {'rings': count, 'velocity': hex(velocity), 'flash_started': seen_flash,
               'max_flashes': max_flashes, 'primary_vanished': vanished,
               'entry_queued': bool(g.read('f_bigring')), 'art_clock_stopped': not g.read('v_gfxbigring'),
               'exception': error, 'pc': hex(g.core.m68k_get_reg(16)),
               'saved_sp': hex(g.read('v_spbuffer', 4)),
               'vint_progress': g.read('Vint_runcount', 4) - start_vint}
        report['cases'].append(row)
        g.video.save(args.output / f'{count}-{velocity:04X}.png')
        print(row, flush=True)
        if not args.probe:
            assert seen_flash and vanished and row['entry_queued'] and row['art_clock_stopped'], row
            assert not error and row['vint_progress'] >= 99, row
            if count == 1:
                # Place a signpost in this fixture's screen and lock its arena
                # there. Its real spin/results code must consume queued entry.
                camera = g.read('Camera_X_pos', 2)
                g.write('Camera_Max_X_pos', camera, 2)
                g.write('Camera_Min_X_pos', camera, 2)
                sign = next(a for a in slots if not g.get(a, 'code'))
                for field, value, size in [('code', g.s['Signpost'], 4),
                        ('obX', g.get('v_player', 'obX', 2), 2), ('obY', y + 160, 2)]:
                    g.put(sign, field, value, size)
                for step in range(3000):
                    g.run()
                    assert not g.read('v_errortype'), ('exception during stage route', step)
                    if (g.read('v_gamemode', 2) & 0x7FFF == g.s['BonusStage'] and
                            g.read('v_vbla_routine', 2) == g.s['Vint_S1SS']):
                        g.run(120)
                        assert not g.read('v_errortype')
                        row['results_to_special_stage'] = True
                        row['stage_route_frames'] = step + 1
                        g.video.save(args.output / 'special-stage.png')
                        break
                else:
                    raise AssertionError(('Queued giant-ring entry never reached the special stage',
                        g.read('v_gamemode', 2), g.get(sign, 'obRoutine'), g.get('v_endcard', 'code')))
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    g.close()


if __name__ == '__main__':
    main()
