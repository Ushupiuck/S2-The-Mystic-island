#!/usr/bin/env python3
"""Exercise companion ledge jumps, catch-up bridge landings and exit inputs.

RAM writes place the initial actors and real objects; every jump, landing,
pickup and signpost update then runs through the normal ROM and emulator.
--probe records an older ROM's failures without treating them as a pass.
"""
from pathlib import Path
import argparse
import json

from genesis_test_core import Genesis
from check_object_course import boot_level


def isolate(g):
    for a in range(g.s['v_lvlobjspace'] & 65535,
                   g.s['v_lvlobjend'] & 65535, g.s['object_size']):
        if g.get(a, 'code') != g.s['SpindashDust']:
            g.write(a, 0, g.s['object_size'])
    g.buttons = g.buttons2 = set()
    g.write('v_rings', 99, 2)


def spawn(g, code, x, y, subtype=0):
    a = next(a for a in range(g.s['v_lvlobjspace'] & 65535,
                             g.s['v_lvlobjend'] & 65535, g.s['object_size'])
             if not g.get(a, 'code'))
    g.write(a, 0, g.s['object_size'])
    for f, v, n in [('code', g.s[code], 4), ('obX', x, 2), ('obY', y, 2),
                    ('obSubtype', subtype, 1)]:
        g.put(a, f, v, n)
    return a


def place(g, actor, x, y, airborne=True):
    for f, v, n in [('obX', x << 16, 4), ('obY', y << 16, 4),
                    ('obVelX', 0, 2), ('obVelY', 0, 2), ('obInertia', 0, 2),
                    ('obStatus', 2 if airborne else 0, 1), ('obControl', 0, 1),
                    ('obRoutine', 2, 1), ('obAnim', 0, 1), ('obPrevAni', 255, 1),
                    ('spindash_flag', 0, 1), ('jumping', 0, 1), ('move_lock', 0, 2),
                    ('tails_flight_flag', 0, 1), ('flashtime', 0, 2)]:
        g.put(actor, f, v, n)
    g.put(actor, 'obHeight', g.get(actor, 'default_y_radius'))
    g.put(actor, 'obWidth', g.get(actor, 'default_x_radius'))


def reset_cpu(g):
    g.write('Tails_CPU_routine', 6, 2)
    for f in ('Tails_CPU_idle_timer', 'Tails_CPU_flight_timer',
              'Tails_CPU_reach_timer'):
        if f in g.s:
            g.write(f, 0, 2)
    g.write('Tails_CPU_auto_jump_flag', 0)


def state(g):
    return {f: g.get('v_player2', f, n) for f, n in
            [('obX', 2), ('obY', 2), ('obVelX', 2), ('obVelY', 2),
             ('obStatus', 1), ('obControl', 1), ('obRoutine', 1)]} | {
        'cpu': g.read('Tails_CPU_routine', 2),
        'input': g.read('v_jpadholdlogical2', 2)}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--probe', action='store_true')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
    boot_level(g, item=0)
    level = g.save()  # retain GHZ1's actual paired ledges and surrounding terrain
    isolate(g)
    baseline = g.save()
    rows = []

    def finish(label, ok, **detail):
        rows.append({'case': label, 'passed': bool(ok), **detail})
        g.video.save(args.output / (label + '.png'))
        print(rows[-1], flush=True)
        if not args.probe:
            assert ok, rows[-1]
        assert not g.read('v_errortype'), (label, 'ROM exception')

    for label, height, px, sx, tx, subtype in (
            ('ledge-right', 48, 184, 168, 136, 0),
            ('ledge-left', 48, 116, 132, 164, 0),
            ('ledge-moving', 48, 184, 168, 136, 5),
            ('ledge-flight', 132, 184, 168, 136, 0)):
        g.restore(baseline)
        platform = spawn(g, 'Obj18', px, 960 - height, subtype & 0xF0)
        place(g, 'v_player', sx, 760)
        g.put('v_player2', 'obControl', 1)
        g.run(90)
        assert g.get('v_player', 'obStatus') & 8, ('Lead did not land on fixture', label,
            {f:g.get('v_player',f,n) for f,n in [('obX',2),('obY',2),('obStatus',1)]},
            {f:g.get(platform,f,n) for f,n in [('obX',2),('obY',2),('obActWid',1),('obSubtype',1),('obRoutine',1),('obStatus',1)]})
        if subtype:
            g.put(platform, 'obSubtype', subtype & 15)
            g.run(1)  # start the actual moving subtype after establishing its rider
            tx = g.get('v_player', 'obX', 2) - 32
        place(g, 'v_player2', tx, 948)
        reset_cpu(g)
        trace, flew, landed = [], False, False
        for tick in range(480):
            g.run()
            sample = state(g)
            flew |= sample['cpu'] == 4
            if tick % 8 == 0:
                trace.append({'tick': tick, **sample})
            if g.get(platform, 'obStatus') & 16 and not sample['obStatus'] & 2:
                landed = True
                break
        (args.output / (label + '-trace.json')).write_text(json.dumps(trace))
        finish(label, landed and (height > 100 or not flew),
               landed=landed, flew=flew, frames=tick + 1, final=state(g))

    g.restore(baseline)
    spawn(g, 'Obj18', 184, 828)
    place(g, 'v_player', 168, 760)
    g.put('v_player2', 'obControl', 1)
    g.run(90)
    place(g, 'v_player2', 136, 948)
    reset_cpu(g)
    g.buttons2 = {6}
    g.run(120)
    finish('manual-control-no-ai-takeoff', g.read('Tails_CPU_routine', 2) == 6 and
           g.read('Tails_CPU_idle_timer', 2) > 0, final=state(g))

    g.restore(baseline)
    place(g, 'v_player', 168, 800)
    place(g, 'v_player2', 136, 800)
    reset_cpu(g)
    flew = False
    for tick in range(240):
        g.run()
        flew |= g.read('Tails_CPU_routine', 2) == 4
    finish('flat-ground-no-ai-takeoff', not flew, final=state(g))

    for action in ('run', 'jump', 'fall'):
        g.restore(baseline)
        ledge = spawn(g, 'Obj1A', 184, 900)
        place(g, 'v_player', 168, 760)
        g.put('v_player2', 'obControl', 1)
        for tick in range(90):
            g.run()
            if g.get('v_player', 'obStatus') & 8 and g.get(ledge, 'ledge_collapse_flag'):
                break
        else:
            raise AssertionError('Lead did not trigger the real collapsing ledge')
        place(g, 'v_player2', 136, 944, airborne=False)
        reset_cpu(g)
        if action != 'fall':
            g.buttons = {7, 8} if action == 'jump' else {7}
            g.put('v_player', 'obVelX', 0x100, 2)
            g.put('v_player', 'obInertia', 0x100, 2)
        g.write('Timer_frames', 63, 2)  # provoke the normal CPU jump, not a forced flight
        jumped = flew = descending_jump_flight = falling_release = False
        trace = []
        for tick in range(90):
            before = (g.get('v_player2', 'obX', 2), g.get('v_player2', 'obY', 2))
            was_flying = g.read('Tails_CPU_routine', 2) == 4
            g.run()
            lead_air = bool(g.get('v_player', 'obStatus') & 2)
            lead_jump = bool(g.get('v_player', 'jumping'))
            flying = g.read('Tails_CPU_routine', 2) == 4
            jumped |= bool(g.get('v_player2', 'jumping'))
            if flying and not was_flying:
                assert jumped, 'Flight replaced the initial rolling jump'
                assert g.get(ledge, 'obRoutine') == g.s['ledge_fragment_routine'], 'Countdown triggered flight'
                assert before == (g.get('v_player2', 'obX', 2), g.get('v_player2', 'obY', 2)), 'Take-off teleported Tails'
                assert g.read('Tails_CPU_reach_timer', 2) == 65535
            flew |= flying
            descending_jump_flight |= (flying and lead_air and lead_jump and
                                       g.get('v_player', 'obVelY', 2) < 0x8000)
            if lead_air and not lead_jump:
                # NPCs update after the players; allow the next AI update to
                # observe the ledge releasing its rider, then require falling.
                g.run()
                falling_release = (g.read('Tails_CPU_routine', 2) == 6 and
                                   not g.get('v_player2', 'obControl'))
                if action != 'jump':
                    break
            trace.append({'tick': tick, 'ledge_routine': g.get(ledge, 'obRoutine'),
                          'lead_air': lead_air, 'lead_jump': lead_jump,
                          'lead_vy': g.get('v_player', 'obVelY', 2), **state(g)})
        (args.output / ('collapsed-ledge-' + action + '-trace.json')).write_text(json.dumps(trace))
        ok = jumped and (not flew and falling_release if action == 'fall' else flew)
        if action == 'jump':
            ok &= descending_jump_flight
        else:
            ok &= falling_release
        finish('collapsed-ledge-' + action, ok, jumped=jumped, flew=flew,
               descending_jump_flight=descending_jump_flight,
               ordinary_fall=falling_release, final=state(g))

    for initial_y in (780, 948):
        g.restore(baseline)
        bridge = spawn(g, 'Bridge', 176, 900, 12)
        place(g, 'v_player', 176, 760)
        g.put('v_player2', 'obControl', 1)
        g.run(100)
        assert g.get('v_player', 'obStatus') & 8, 'Lead did not land on bridge'
        place(g, 'v_player2', 144, initial_y)
        reset_cpu(g)
        g.write('Tails_CPU_routine', 4, 2)
        g.put('v_player2', 'obControl', 0x81)
        illegal_contact, landed = False, False
        for tick in range(480):
            g.run()
            flying = g.get('v_player2', 'obControl') & 0x80
            illegal_contact |= bool(flying and g.get(bridge, 'obStatus') & 16)
            if g.get(bridge, 'obStatus') & 16 and not flying:
                landed = True
                break
        finish(f'bridge-flight-{initial_y}', landed and not illegal_contact,
               landed=landed, flying_rider=illegal_contact, frames=tick + 1,
               final=state(g))

    g.restore(baseline)
    bonus = spawn(g, 'Obj7D', 160, 900, 3)
    place(g, 'v_player', 48, 820)
    place(g, 'v_player2', 160, 900)
    reset_cpu(g)
    before = g.read('v_score', 4)
    g.run(1)
    awarded = g.read('v_score', 4) - before
    g.run(10)
    finish('companion-hidden-bonus', awarded == 10 and
           g.read('v_score', 4) - before == 10,
           score_added=awarded, routine=g.get(bonus, 'obRoutine'))

    g.restore(baseline)
    sign = spawn(g, 'Signpost', 100, 940)
    place(g, 'v_player', 110, 800)
    place(g, 'v_player2', 80, 800)
    reset_cpu(g)
    g.write('Camera_Max_X_pos', 0, 2)  # keep this near-start arena in the loaded window
    for tick in range(300):
        g.run()
        if g.read('f_lockctrl'):
            break
    assert g.read('f_lockctrl'), ('Signpost did not lock input', g.get(sign, 'obRoutine'))
    g.buttons2 = {6, 8}  # left + jump; real controller 2 must lose precedence
    good = True
    for tick in range(20):
        g.run()
        good &= g.read('v_jpadholdlogical2', 2) == g.read('v_jpadholdlogical', 2)
    finish('signpost-controller2-lock', good and
           g.read('v_jpadholdlogical2') == g.s['btnR'], final=state(g))

    # The real double ledge before checkpoint 1: continuous running must not
    # provoke a rescue flight. The rock approach also catches a stale ledge
    # reference interrupting a later jump after Sonic has left the segment.
    for entry, sx, tx, y, settle in (
            ('riding', 0x1040, 0x1020, 632, 2),
            ('approach', 0xFC0, 0xFA0, 560, 90)):
        g.restore(level)
        place(g, 'v_player', sx, y)
        place(g, 'v_player2', tx, y)
        g.write('Camera_X_pos', 0xF20, 2)
        g.write('Camera_Y_pos', 480, 2)
        for actor in ('v_player', 'v_player2'):
            g.put(actor, 'obStatusSecondary', 2)
            g.put(actor, 'invtime', 1200, 2)
        g.write('Tails_CPU_idle_timer', 120, 2)
        g.run(settle)
        if entry == 'riding':
            assert all(g.get(a, 'obStatus') & 8 for a in ('v_player', 'v_player2'))
        start = g.save()
        cases = []
        for speed in (0, 0x100, 0x300, 0x600):
            for phase in (*range(0, 64, 8), 63):
                g.restore(start)
                reset_cpu(g)
                g.write('Timer_frames', phase, 2)
                for actor in ('v_player', 'v_player2'):
                    g.put(actor, 'obVelX', speed, 2)
                    g.put(actor, 'obInertia', speed, 2)
                g.buttons = {7}
                broken, trace = set(), []
                flew = jumped = crumble_flight = crossed = False
                for tick in range(200):
                    g.run()
                    for obj in range(g.s['v_lvlobjspace'] & 65535,
                                     g.s['v_lvlobjend'] & 65535, g.s['object_size']):
                        if (g.get(obj, 'code') == g.s['Obj1A'] and
                                g.get(obj, 'obX', 2) in (0x1030, 0x10A0) and
                                g.get(obj, 'obRoutine') == g.s['ledge_fragment_routine']):
                            broken.add(g.get(obj, 'obX', 2))
                    sample = state(g)
                    flew |= sample['cpu'] == 4
                    jumped |= bool(g.get('v_player2', 'jumping'))
                    crumble_flight |= (sample['cpu'] == 4 and
                                       g.read('Tails_CPU_reach_timer', 2) == 65535)
                    if tick % 8 == 0:
                        trace.append({'tick': tick, **sample})
                    if sample['obX'] > 0x10D0 and not sample['obStatus'] & 2:
                        crossed = True
                        break
                # If Tails misses the rock and falls offscreen, the existing
                # respawn flight remains valid. It must not be tagged as a
                # collapse rescue. Riding cases need neither jump nor flight.
                ok = crossed and bool(broken) and not crumble_flight
                if entry == 'riding':
                    ok &= not flew and not jumped and len(broken) == 2
                label = f'ghz1-double-ledge-{entry}-{speed:X}-{phase}'
                detail = {'case': label, 'passed': bool(ok), 'flew': flew,
                          'jumped': jumped, 'crumble_flight': crumble_flight,
                          'crossed': crossed, 'broken': sorted(broken)}
                cases.append(detail)
                (args.output / (label + '-trace.json')).write_text(json.dumps(trace))
                if not args.probe:
                    assert ok, detail
                assert not g.read('v_errortype'), detail
        (args.output / (f'ghz1-double-ledge-{entry}-cases.json')).write_text(
            json.dumps(cases, indent=2) + '\n')
        finish(f'ghz1-double-ledge-{entry}', all(c['passed'] for c in cases),
               runs=len(cases), collapse_flights=sum(c['crumble_flight'] for c in cases),
               ordinary_respawns=sum(c['flew'] for c in cases))
    (args.output / 'report.json').write_text(json.dumps(rows, indent=2) + '\n')
    g.close()


if __name__ == '__main__':
    main()
