#!/usr/bin/env python3
"""Exercise companion AI on the real Hidden Palace Act 1 terrain.

The main routes use controller input from the level start. The platform route
only positions the initial actors beside the actual placed ledges; it retains
the level, objects, collision, camera, enemies and normal movement code.
"""
from pathlib import Path
import argparse
import json
from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import place, reset_cpu


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--probe', action='store_true')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
    boot_level(g, item=6)
    assert g.read('Current_ZoneAndAct', 2) == g.s['id_HPZ'] << 8
    assert not g.read('Player_mode', 2)
    baseline = g.save()
    reach = 'Tails_CPU_reach_state' if 'Tails_CPU_reach_state' in g.s else 'Tails_CPU_reach_timer'
    rows = []

    def sample():
        r = {'frame': g.frame, 'cpu': g.read('Tails_CPU_routine', 2),
             'reach': g.read(reach, 2), 'input2': g.read('v_jpadholdlogical2', 2)}
        for prefix, actor in (('s', 'v_player'), ('t', 'v_player2')):
            for key, field, size in (
                    ('x', 'obX', 2), ('y', 'obY', 2), ('status', 'obStatus', 1),
                    ('routine', 'obRoutine', 1), ('render', 'obRender', 1),
                    ('angle', 'obAngle', 1), ('vx', 'obVelX', 2),
                    ('inertia', 'obInertia', 2), ('spin', 'spindash_flag', 1),
                    ('jump', 'jumping', 1), ('lock', 'move_lock', 2)):
                r[prefix + key] = g.get(actor, field, size)
            if r[prefix + 'status'] & 8:
                index = g.get(actor, 'standonobject')
                parent = (g.s['v_objspace'] & 65535) + index * g.s['object_size']
                r[prefix + 'parent_code'] = g.get(parent, 'code')
                r[prefix + 'parent_x'] = g.get(parent, 'obX', 2)
        return r

    def run_route(label, commands, require_spin=False, require_platforms=False):
        trace, bad_flights = [], []
        spin_seen = spin_released = False
        for phase, buttons, frames in commands:
            g.buttons = set(buttons)
            for _ in range(frames):
                before = sample()
                g.run()
                after = sample()
                after['phase'] = phase
                trace.append(after)
                spin_seen |= bool(after['tspin'])
                spin_released |= bool(before['tspin'] and not after['tspin'] and
                                      after['tinertia'] and after['troutine'] == 2 and
                                      after['tstatus'] & 4)
                if after['cpu'] == 4 and before['cpu'] in (6, 8) and after['sroutine'] < 6:
                    # Ordinary offscreen respawn enters through state 2.
                    # A direct takeoff must prove the actual collapsed parent.
                    index = g.get('v_player', 'standonobject')
                    parent = (g.s['v_objspace'] & 65535) + index * g.s['object_size']
                    valid = (after['reach'] == 65535 and
                             g.get(parent, 'code') in (g.s['Obj1A'], g.s['Obj1B']) and
                             g.get(parent, 'obRoutine') == g.s['ledge_fragment_routine'])
                    if not valid:
                        bad_flights.append(after)
                if before['cpu'] == after['cpu'] == 4 and after['reach'] == 65535:
                    if abs(after['tx'] - before['tx']) > 6 or abs(after['ty'] - before['ty']) > 1:
                        bad_flights.append(after)
                assert not g.read('v_errortype'), after
        ok = not bad_flights and all(r['sroutine'] < 6 for r in trace)
        if require_spin:
            ok &= spin_seen and spin_released
        platforms = sorted({r['sparent_x'] for r in trace
                            if r.get('sparent_code') == g.s['Obj1A']})
        lead_jumps = sum(r['sjump'] and (i == 0 or not trace[i-1]['sjump'])
                         for i, r in enumerate(trace))
        if require_platforms:
            ok &= 0xA10 in platforms and 0xA90 in platforms and lead_jumps >= 2
        row = {'case': label, 'passed': bool(ok), 'frames': len(trace),
               'unjustified_flights': len(bad_flights), 'spindash': spin_seen,
               'spindash_release': spin_released,
               'ground_slope_frames': sum(bool(r['tangle']) and not r['tstatus'] & 2 for r in trace),
               'jump_frames': sum(bool(r['tjump']) for r in trace),
               'platforms_ridden': platforms,
               'lead_jumps': lead_jumps,
               'cpu_states': sorted({r['cpu'] for r in trace}), 'final': sample()}
        rows.append(row)
        (args.output / (label + '-trace.json')).write_text(json.dumps(trace))
        (args.output / (label + '-invalid-flights.json')).write_text(json.dumps(bad_flights))
        g.video.save(args.output / (label + '.png'))
        print(row, flush=True)
        if not args.probe:
            assert ok, row

    # Start, accelerate, stop fully, then make ordinary jumps onto the raised
    # walkway. This route includes slow motion and sustained running.
    approach = [('start-run', (7,), 64), ('full-stop', (), 80),
                ('start-again', (7,), 75), ('first-jump', (7, 8), 25),
                ('first-landing', (7,), 45), ('walkway-jump', (7, 8), 25),
                ('walkway-stop', (), 140)]
    for label, frames in (('ramp-from-rest', 64), ('ramp-with-momentum', 96)):
        g.restore(baseline)
        run_route(label, approach + [('climb-ramp', (7,), frames),
                                    ('wait-for-companion', (), 500)], require_spin=True)

    # The two actual HPZ1 collapsing ledges at $A10/$A90. Do not replace the
    # layout or spawn stand-in objects. Start on their real collision surface.
    g.restore(baseline)
    place(g, 'v_player', 0xA00, 1132)
    place(g, 'v_player2', 0x9E0, 1136)
    g.write('Camera_X_pos', 0x940, 2)
    g.write('Camera_Y_pos', 1024, 2)
    g.write('Tails_CPU_idle_timer', 120, 2)
    g.run(2)
    reset_cpu(g)
    run_route('consecutive-platform-jumps', [
        ('first-platform', (7,), 20), ('first-hop', (7, 8), 12),
        ('first-release', (7,), 30), ('brake-for-landing', (6,), 18),
        ('land-on-next-platform', (), 8),
        ('second-hop', (7, 8), 12), ('second-release', (7,), 40),
        ('wait-on-next-platform', (), 160)], require_platforms=True)
    (args.output / 'report.json').write_text(json.dumps(rows, indent=2) + '\n')
    g.close()


if __name__ == '__main__':
    main()
