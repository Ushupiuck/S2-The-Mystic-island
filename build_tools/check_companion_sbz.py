#!/usr/bin/env python3
"""Check Scrap Madness companion failures with actual Genesis Plus GX code.

The conveyor scene initializes riders on a real eight-platform group, then
runs normal game frames. The flight scene feeds captured Sonic/camera samples
to the actual AI and sprite renderer. These are focused fixtures, not route
playthroughs. --probe records an older ROM's failures for comparison.
"""
from pathlib import Path
import argparse
import ctypes as C
import hashlib
import json
import subprocess
import sys

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import isolate, spawn, place, reset_cpu

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--core', type=Path, required=True)
p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
p.add_argument('--output', type=Path, required=True)
p.add_argument('--probe', action='store_true')
p.add_argument('--scene', choices=('conveyor', 'flight'), help=argparse.SUPPRESS)
args = p.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
checks = []


def finish():
    report = {'kind': 'focused AI fixtures; no new route playthrough',
              'rom_sha256': hashlib.sha256(args.rom.read_bytes()).hexdigest(),
              'passed': sum(c['passed'] for c in checks),
              'failed': sum(not c['passed'] for c in checks), 'checks': checks}
    (args.output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'checks'}), flush=True)
    if not args.probe:
        assert not report['failed'], [c for c in checks if not c['passed']]


if args.scene is None:
    # Keep each core initialization in its own process. The direct CPU fixture
    # also has an independent cycle clock from the full-frame conveyor scene.
    for scene in ('conveyor', 'flight'):
        out = args.output/scene
        command = [sys.executable, str(Path(__file__).resolve()), '--scene', scene,
                   '--core', str(args.core), '--rom', str(args.rom),
                   '--listing', str(args.listing), '--output', str(out)]
        if args.probe:
            command.append('--probe')
        subprocess.run(command, check=True)
        checks.extend(json.loads((out/'report.json').read_text())['checks'])
    finish()
    raise SystemExit


class CPU:
    """Call assembled routines with interrupts masked; return to a RAM loop."""
    def __init__(self, g):
        self.g = g
        self.cycles = 10_000_000
        g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
        g.core.m68k_run.argtypes = [C.c_uint]

    def act(self, routine, actor='v_player2'):
        g = self.g
        g.write(0xFF8000, 0x60FE, 2)
        g.write(0xFF8FF0, 0xFF8000, 4)
        for register, value in ((17, 0x2700), (15, 0xFF8FF0),
                                (8, g.s[actor]), (9, g.s['v_player']),
                                (16, g.s[routine])):
            g.core.m68k_set_reg(register, value)
        self.cycles += 100_000
        g.core.m68k_run(self.cycles)
        assert g.core.m68k_get_reg(16) == 0xFF8000, (routine, 'did not return')


g = Genesis(args.core, args.rom, args.listing, args.output)
try:
    if args.scene == 'conveyor':
        boot_level(g, zone=8, act=0)
        isolate(g)
        g.write('Camera_X_pos', 3800, 2)
        g.write('Camera_Y_pos', 1200, 2)
        for actor in ('v_player', 'v_player2'):
            place(g, actor, 3900, 1250)
            g.put(actor, 'obControl', 0x81)
        spawn(g, 'SMZ_SpinConvey', 3968, 1280, 0x83)
        g.run(3)
        carriers = [a for a in range(g.s['v_lvlobjspace'] & 65535,
                                    g.s['v_lvlobjend'] & 65535, g.s['object_size'])
                    if g.get(a, 'code') == g.s['SMZ_SpinConvey'] and
                    g.get(a, 'SMZ_spinc_baseX', 2) == 3968 and
                    g.get(a, 'obY', 2) > 1200 and g.get(a, 'obAnim') == 1]
        carriers.sort(key=lambda a: g.get(a, 'obX', 2))
        assert len(carriers) == 3, carriers
        bottom, top = carriers[:2]

        def rider(actor, obj, radius):
            place(g, actor, g.get(obj, 'obX', 2), g.get(obj, 'obY', 2)-radius, False)
            g.put(actor, 'obStatus', 8)
            g.put(actor, 'standonobject',
                  (obj-(g.s['v_objspace'] & 65535))//g.s['object_size'])
            bit = 8 if actor == 'v_player' else 16
            g.put(obj, 'obStatus', g.get(obj, 'obStatus') | bit)

        rider('v_player', top, 26)
        rider('v_player2', bottom, 22)
        reset_cpu(g)
        # A resting lead supplies no delayed jump to accidentally help Tails.
        for index in range(0, 256, 4):
            g.write(g.s['Sonic_Pos_Record_Buf']+index, g.get('v_player', 'obX', 2), 2)
            g.write(g.s['Sonic_Pos_Record_Buf']+index+2, g.get('v_player', 'obY', 2), 2)
            g.write(g.s['Sonic_Stat_Record_Buf']+index, 0, 4)
        initial = g.save()
        for phase in range(64):
            g.restore(initial)
            g.write('Timer_frames', phase, 2)
            landed = jumped = None
            invalid = False
            trace = []
            for tick in range(120):
                g.run()
                cpu = g.read('Tails_CPU_routine', 2)
                invalid |= cpu != 6 or g.get('v_player2', 'obRoutine') >= 6
                if g.get('v_player2', 'jumping') and jumped is None:
                    jumped = tick
                if phase == 0:
                    trace.append({'tick': tick, 'x': g.get('v_player2', 'obX', 2),
                                  'y': g.get('v_player2', 'obY', 2), 'cpu': cpu,
                                  'jumping': g.get('v_player2', 'jumping')})
                assert not g.read('v_errortype'), ('ROM exception', phase, tick)
                if g.get(top, 'obStatus') & 16:
                    landed = tick
                    break
            checks.append({'case': 'rising-conveyor-transfer', 'phase': phase,
                           'passed': landed is not None and not invalid,
                           'jump_frame': jumped, 'landing_frame': landed})
            if phase == 0:
                g.video.save(args.output/'transfer.png')
                (args.output/'transfer-trace.json').write_text(json.dumps(trace)+'\n')

        # Sharing the lead's carrier is a ride, not a reason to keep hopping.
        g.restore(initial)
        g.put(bottom, 'obStatus', g.get(bottom, 'obStatus') & ~16)
        rider('v_player2', top, 22)
        reset_cpu(g)
        good = True
        for tick in range(90):
            g.run()
            good &= (bool(g.get(top, 'obStatus') & 16) and
                     not g.get('v_player2', 'jumping') and
                     g.read('Tails_CPU_routine', 2) == 6)
            assert not g.read('v_errortype')
        checks.append({'case': 'shared-conveyor-no-unnecessary-jumps', 'passed': good})

    else:
        captured = json.loads((ROOT/'build_tools/fixtures/smz1-normal-catchup.json').read_text())
        samples = [dict(zip(captured['columns'], row)) for row in captured['samples']]
        offset = captured['flight_start_frame']-captured['first_frame']+1
        assert offset == 64  # one full position-history buffer precedes the flight
        C.memset(g.ram, 0, 65536)
        cpu = CPU(g)
        for actor, code, height in (('v_player', 'Obj01', 19), ('v_player2', 'Obj02', 15)):
            for field, value, size in (('code', g.s[code], 4), ('obRoutine', 2, 1),
                                       ('obHeight', height, 1), ('obWidth', 9, 1),
                                       ('default_y_radius', height, 1), ('default_x_radius', 9, 1)):
                g.put(actor, field, value, size)
        cpu.act('Init_SpriteTable')
        for field, value, size in (('obMap', g.s['Map_Tails'], 4),
                                   ('height_pixels', g.s['Map_Tails_height'], 1),
                                   ('width_pixels', 24, 1), ('obPriority', 0x100, 2),
                                   ('obRender', 4, 1), ('obControl', 0x81, 1), ('obStatus', 2, 1),
                                   ('obX', captured['tails_start'][0], 2),
                                   ('obY', captured['tails_start'][1], 2)):
            g.put('v_player2', field, value, size)
        g.write('Tails_CPU_routine', 4, 2)
        for index, r in enumerate(samples[:offset]):
            g.write(g.s['Sonic_Pos_Record_Buf']+4*index, r['sx'], 2)
            g.write(g.s['Sonic_Pos_Record_Buf']+4*index+2, r['sy'], 2)
            g.write(g.s['Sonic_Stat_Record_Buf']+4*index+2, r['sstatus'])
        trace, max_step = [], 0
        for index, r in enumerate(samples[offset:], offset):
            for field, key, size in (('obX', 'sx', 2), ('obY', 'sy', 2),
                                     ('obVelX', 'svx', 2), ('obVelY', 'svy', 2),
                                     ('obStatus', 'sstatus', 1), ('obRoutine', 'sroutine', 1),
                                     ('jumping', 'sjump', 1)):
                g.put('v_player', field, r[key], size)
            g.write('Camera_X_pos_copy', r['camera_x'], 2)
            g.write('Camera_Y_pos_copy', r['camera_y'], 2)
            cpu.act('Sonic_RecordPos', 'v_player')
            before_y = g.get('v_player2', 'obY', 2)
            cpu.act('Tails_FlySwim_Unknown')
            cpu.act('DisplaySprite')
            cpu.act('Render_Sprites')
            state = {'frame': captured['first_frame']+index,
                     'x': g.get('v_player2', 'obX', 2), 'y': g.get('v_player2', 'obY', 2),
                     'cpu': g.read('Tails_CPU_routine', 2),
                     'render': g.get('v_player2', 'obRender'),
                     'timer': g.read('Tails_CPU_flight_timer', 2)}
            trace.append(state)
            if state['cpu'] != 2:
                max_step = max(max_step, abs(state['y']-before_y))
            if state['cpu'] != 4:
                break
        last = trace[-1]
        checks.append({'case': 'recorded-normal-route-flight',
                       'passed': last['cpu'] == 6 and max_step <= 6,
                       'recorded_timeout_frame': captured['recorded_timeout_frame'],
                       'max_vertical_step': max_step, 'final': last})
        (args.output/'flight-trace.json').write_text(json.dumps(trace, indent=2)+'\n')
finally:
    g.close()
finish()
