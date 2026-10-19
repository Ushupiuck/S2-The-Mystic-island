#!/usr/bin/env python3
"""Check monitor ownership, Tails jump radii and the shared rolling camera.

Native 68000 fixtures establish a landing, then model an interrupted rider
handoff. Full-frame checks exercise rolling on real terrain and revisiting
SMZ1's left pit monitor. --probe records an older ROM's failures.
"""
from pathlib import Path
import argparse
import ctypes as C
import hashlib
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
    p.add_argument('--player', type=int, choices=(0, 2), default=2)
    p.add_argument('--probe', action='store_true')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
                system_directory=args.system_directory)
    boot_level(g, zone=8, player=args.player)
    base = g.save()  # genuine frame boundary, before native-routine fixtures
    cpu = CpuPrefix.in_dll(g.core, 'm68k')
    g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
    g.core.m68k_run.argtypes = [C.c_uint]
    rows = []

    def act(label, obj, regs=None):
        g.core.m68k_set_reg(17, 0x2700)
        g.core.m68k_set_reg(8, 0xFF0000 | (obj & 65535))
        for reg, value in (regs or {}).items():
            g.core.m68k_set_reg(reg, value & 0xFFFFFFFF)
        # Tails_Jump discards its caller on success, so provide two returns.
        for address in (0x7E00, 0x7E04):
            g.write(address, 0xFF7F00, 4)
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
        print(row, flush=True)
        if not args.probe:
            assert passed, row

    who = 'v_player' if args.player == 2 else 'v_player2'
    bit = 3 if args.player == 2 else 4
    other_bit = 4 if bit == 3 else 3
    isolate(g)
    g.write('Camera_X_pos', 4520, 2)
    g.write('Camera_X_pos_coarse_back', 0x1100, 2)
    mon = spawn(g, 'Obj26', 4624, 1521, 4)
    act('Obj26', mon)
    place(g, who, 4624, 1490)
    g.put(who, 'obVelY', 0x100, 2)
    act('Monitor_Solid', mon)
    assert g.get(mon, 'obStatus') & (1 << bit), 'Fixture did not land'
    attached = g.save()
    for mismatch in ('no-standing', 'another-parent'):
        g.restore(attached)
        place(g, who, 4636, 1570)
        g.put(who, 'obControl', 1)
        if mismatch == 'another-parent':
            parent = spawn(g, 'SMZ_MovingBlock', 4636, 1600)
            g.put(who, 'obStatus', 8)
            g.put(who, 'standonobject',
                  (parent - (g.s['v_objspace'] & 65535)) // g.s['object_size'])
        before = (g.get(who, 'obX', 2), g.get(who, 'obY', 2))
        g.put(mon, 'obStatus', g.get(mon, 'obStatus') | (1 << other_bit))
        act('Monitor_SolidCharacter', mon,
            {9: g.s[who], 1: 0x1A, 2: 15, 3: 16, 4: 4624, 6: bit})
        after = (g.get(who, 'obX', 2), g.get(who, 'obY', 2))
        status = g.get(mon, 'obStatus')
        record('stale-' + mismatch,
               after == before and not status & (1 << bit) and status & (1 << other_bit),
               before=before, after=after)

    g.restore(attached)
    feet = g.get(who, 'obY', 2) + g.get(who, 'obHeight')
    g.write('v_jpadpresslogical2', g.s['btnC'])
    g.write('v_jpadholdlogical2', g.s['btnC'])
    act('Tails_Jump', g.s[who])
    new_feet = g.get(who, 'obY', 2) + g.get(who, 'obHeight')
    record('jump-preserves-feet', feet == new_feet, old_feet=feet, new_feet=new_feet)

    # Complete camera routine, with Sonic as the original five-pixel control.
    for character, height, rolled in (('Sonic', 19, 14), ('Tails', 15, 14)):
        g.restore(base)
        bias = g.s['Camera_LookCenter']
        place(g, 'v_player', 4520, 900 + bias, airborne=False)
        g.put('v_player', 'default_y_radius', height)
        g.put('v_player', 'obInertia', 0x400, 2)
        g.write('Camera_Y_pos', 900 << 16, 4)
        g.write('Camera_Y_pos_bias', bias, 2)
        g.write('Camera_Min_Y_pos', 0, 2)
        g.write('Camera_Max_Y_pos', 2000, 2)
        g.write('Camera_Max_Y_Pos_Changing', 0)
        cameras = []
        for state in ('standing', 'rolling', 'uncurled'):
            rolling = state == 'rolling'
            g.put('v_player', 'obStatus', 4 if rolling else 0)
            g.put('v_player', 'obHeight', rolled if rolling else height)
            g.put('v_player', 'obY', 900 + bias + (height - rolled if rolling else 0), 2)
            act('ScrollVertical', g.s['v_player'],
                {9: g.s['Camera_Y_pos'], 10: g.s['Verti_block_crossed_flag'],
                 11: g.s['Scroll_flags'], 12: g.s['Camera_Y_pos_diff']})
            cameras.append(g.read('Camera_Y_pos', 2))
        record(character + '-camera-roll-uncurl', cameras == [900] * 3, camera_y=cameras)

    if args.player == 2:
        # Real controller input and terrain resolve the entire roll/uncurl cycle.
        g.restore(base)
        place(g, 'v_player', 230, 1200, airborne=False)
        g.put('v_player', 'obVelX', 0x180, 2)
        g.put('v_player', 'obInertia', 0x180, 2)
        g.write('Camera_Y_pos', 1104 << 16, 4)
        trace = []
        for tick in range(100):
            g.buttons = {5} if tick < 3 else set()
            g.run()
            trace.append(dict(tick=tick, y=g.get('v_player', 'obY', 2),
                              height=g.get('v_player', 'obHeight'),
                              status=g.get('v_player', 'obStatus'),
                              camera=g.read('Camera_Y_pos', 2)))
            if tick in (2, 99):
                g.video.save(args.output / f'camera-{tick}.png')
        record('live-camera-roll-uncurl',
               any(row['status'] & 4 for row in trace) and not trace[-1]['status'] & 4
               and {row['camera'] for row in trace} == {1104}
               and {row['y'] + row['height'] for row in trace} == {1215},
               camera_y=sorted({row['camera'] for row in trace}))
        (args.output / 'camera-trace.json').write_text(json.dumps(trace, indent=2) + '\n')

        g.restore(base)
        slots = range(g.s['v_lvlobjspace'] & 65535, g.s['v_lvlobjend'] & 65535,
                      g.s['object_size'])

        def left_monitor():
            return next((obj for obj in slots if g.get(obj, 'code') == g.s['Obj26']
                         and g.get(obj, 'obX', 2) == 4624), None)

        for visit in range(2):
            place(g, 'v_player', 4636, 1480)
            g.put('v_player', 'obVelY', 0x200, 2)
            g.put('v_player', 'invtime', 1800, 2)
            g.write('Camera_X_pos', 4512, 2)
            g.write('Camera_Y_pos', 1408, 2)
            landed = broken = False
            for tick in range(150):
                g.buttons = ({6} if tick < 60 else set()) | (
                    {8} if visit and 20 <= tick < 32 else set())
                g.run()
                obj = left_monitor()
                if obj:
                    landed |= bool(g.get(obj, 'obStatus') & 8)
                    broken |= g.get(obj, 'obRoutine') >= 4
            record('pit-monitor-visit-' + str(visit), landed and broken == bool(visit),
                   landed=landed, broken=broken)
            g.video.save(args.output / f'pit-visit-{visit}.png')
            if not visit:
                # Move the fixture beyond the loading window; real unloading
                # and respawn tracking must make the unbroken monitor return.
                place(g, 'v_player', 5600, 1400)
                g.put('v_player', 'obControl', 1)
                g.write('Camera_X_pos', 5440, 2)
                g.write('Camera_Y_pos', 1300, 2)
                g.buttons = set()
                g.run(100)
                record('pit-monitor-unloads', left_monitor() is None)
    g.close()
    report = dict(region='PAL' if args.pal else 'NTSC', player=args.player, rows=rows,
                  rom_sha256=hashlib.sha256(args.rom.read_bytes()).hexdigest())
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
