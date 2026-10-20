#!/usr/bin/env python3
"""Exercise swing solidity/hurt families and the retained gray/blue switches.

Real 68000 object and touch routines verify both actors. Full-frame switch
fixtures use the real terrain, movement and momentary switch code.
"""
from pathlib import Path
import argparse
import ctypes as C
import json

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import spawn, place, isolate
from check_caterkiller import CpuPrefix

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--core', type=Path, required=True)
    p.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT / 'main.lst')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--pal', action='store_true')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
                system_directory=args.system_directory)
    boot_level(g, zone=8, player=0)
    atlas = (ROOT / 'art/uncompressed/SMZ Sprite Atlas.unc').read_bytes()
    first = g.s['ArtTile_SMZ_Atlas'] * 32
    assert bytes(g.vram[(first + i) ^ 1] for i in range(len(atlas))) == atlas, 'Atlas upload differs from source pixels'
    base = g.save()
    cpu = CpuPrefix.in_dll(g.core, 'm68k')
    g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
    g.core.m68k_run.argtypes = [C.c_uint]
    rows = []

    def act(label, obj):
        g.core.m68k_set_reg(17, 0x2700)
        g.core.m68k_set_reg(8, 0xFF0000 | (obj & 65535))
        g.write(0x7E00, 0xFF7F00, 4)
        g.write(0x7F00, 0x60FE, 2)
        g.core.m68k_set_reg(15, 0xFF7E00)
        g.core.m68k_set_reg(16, g.s[label])
        for _ in range(200000):
            if g.core.m68k_get_reg(16) == 0xFF7F00:
                return
            g.core.m68k_run(cpu.cycles + 1)
        raise AssertionError((label, hex(g.core.m68k_get_reg(16))))

    def record(case, passed, **details):
        row = dict(case=case, passed=bool(passed), **details)
        rows.append(row)
        assert passed, row

    for zone, family in ((8, 0x76), (8, 0x77), (0, 0x76), (8, 0x56),
                         (0, 0x46), (0, 0x56), (3, 0x06), (0, 0x06)):
        g.restore(base)
        isolate(g)
        g.write('Current_Zone', zone)
        obj = spawn(g, 'SwingingPtfm', 250, 950, family)
        g.write(g.s['v_oscillate'] + 0x1A, 0x40)
        act('SwingingPtfm', obj)
        act('SwingingPtfm', obj)
        node = g.save()
        hazard = family >> 4 == 7
        for who in ('v_player', 'v_player2'):
            g.restore(node)
            other = 'v_player2' if who == 'v_player' else 'v_player'
            g.put(other, 'code', 0)
            x, y = g.get(obj, 'obX', 2), g.get(obj, 'obY', 2)
            radius = g.get(who, 'default_y_radius')
            place(g, who, x, y - g.get(obj, 'obHeight') - 1 - radius + 4)
            g.put(who, 'obVelY', 0x300, 2)
            g.write('v_rings', 40, 2)
            act('SwingingPtfm', obj)
            standing = bool(g.get(who, 'obStatus') & 8)
            record(f'top-{zone}-{family:02X}-{who}', standing != hazard,
                   standing=standing)
            act('TouchResponse', g.s[who])
            record(f'top-clearance-{zone}-{family:02X}-{who}',
                   g.get(who, 'obRoutine') == 2)
            contacts = (('top', 0, -20), ('bottom', 0, 20),
                        ('left', -16, 0), ('right', 16, 0)) if hazard else (
                            ('bottom', 0, 16),)
            for side, dx, dy in contacts:
                g.restore(node)
                g.put(other, 'code', 0)
                place(g, who, x + dx, y + dy)
                g.write('v_rings', 40, 2)
                act('TouchResponse', g.s[who])
                expected_hurt = bool(g.get(obj, 'obColType'))
                record(f'hurt-{zone}-{family:02X}-{who}-{side}',
                       (g.get(who, 'obRoutine') == 4) == expected_hurt)

    for who in ('v_player', 'v_player2'):
        g.restore(base)  # resume whole frames only from the original boundary
        isolate(g)
        other = 'v_player2' if who == 'v_player' else 'v_player'
        g.put(other, 'code', 0)
        obj = spawn(g, 'SMZ_Button', 250, 1152)
        place(g, who, 250, 1070)
        g.buttons2 = {4}  # keep companion control manual
        g.write('Tails_CPU_idle_timer', 600, 2)
        g.put(who, 'obVelY', 0x100, 2)
        g.write('Camera_X_pos', 0, 2)
        g.write('Camera_Y_pos', 1040, 2)
        pressed = False
        for _ in range(60):
            g.run()
            pressed |= g.get(obj, 'obFrame') == 1 and bool(g.read('f_switch') & 1)
        record('switch-press-' + who, pressed)
        g.video.save(args.output / ('switch-' + who + '.png'))
        place(g, who, 320, 1070)
        g.put(who, 'obControl', 1)
        g.run(5)
        record('switch-release-' + who,
               g.get(obj, 'obFrame') == 0 and not g.read('f_switch') & 1)
    g.close()
    report = dict(region='PAL' if args.pal else 'NTSC', rows=rows)
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'{len(rows)} swing/switch contact checks passed ({report["region"]}).')


if __name__ == '__main__':
    main()
