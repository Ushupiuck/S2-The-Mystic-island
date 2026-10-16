#!/usr/bin/env python3
"""Ride the real SBZ2 discs using Genesis Plus GX and normal player physics.

Debug positions each solo character above a real placement, then switches off.
Damage flashing isolates the wheel from nearby hazards. These focused scenes
are separate from the paused controller-only Tails AI route samples.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import subprocess
import sys
import tempfile

from genesis_test_core import Genesis
from check_object_course import boot_level, objects

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--core', type=Path, required=True)
p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
p.add_argument('--listing', type=Path, default=ROOT/'main.lst')
p.add_argument('--output', type=Path)
p.add_argument('--wheel', type=int, help='Check only this zero-based placement')
p.add_argument('--player', type=int, choices=(1, 2), help=argparse.SUPPRESS)
args = p.parse_args()
rows = [(x, y & 0xFFF) for x, y, oid, sub in struct.iter_unpack(
    '>HHBB', (ROOT/'level/objects/SMZ_2.bin').read_bytes()[:-6]) if oid == 0xA1]
checks = []


def finish(checks):
    report = {'passed': len(checks), 'rom_sha256': hashlib.sha256(args.rom.read_bytes()).hexdigest(),
              'checks': checks}
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'checks'}), flush=True)


if args.player is None:
    # Keep each libretro initialization/deinitialization in its own process.
    with tempfile.TemporaryDirectory(prefix='sbz-disc-reports-') as directory:
        for player in (1, 2):
            output = Path(directory)/f'{player}.json'
            command = [sys.executable, str(Path(__file__).resolve()), '--core', str(args.core),
                       '--rom', str(args.rom), '--listing', str(args.listing),
                       '--player', str(player), '--output', str(output)]
            if args.wheel is not None:
                command += ['--wheel', str(args.wheel)]
            subprocess.run(command, check=True)
            checks.extend(json.loads(output.read_text())['checks'])
    finish(checks)
    raise SystemExit


def ride(g, disc, frames, minimum_laps=2):
    attached = False
    count = winding = 0
    previous = None
    for _ in range(frames):
        g.run()
        current = bool(g.get(disc, 'SMZ_disc_sonic_attached'))
        if not attached and not current:
            continue
        attached = True
        state = [g.get('v_player', f, z) for f, z in
                 [('obX', 2), ('obY', 2), ('obStatus', 1), ('obAngle', 1)]]
        assert current and g.get('v_player', 'stick_to_convex'), ('Lost disc', state)
        assert not state[2] & 2, ('Became airborne', state)
        assert g.get('v_player', 'obRoutine') == 2, ('Hurt/dead on disc', state)
        if previous is not None:
            winding += (state[3] - previous + 128) % 256 - 128
        previous = state[3]
        count += 1
    assert count >= frames - 60, ('Did not land on disc', count)
    assert winding >= minimum_laps * 256, ('Incomplete laps', winding, count)
    return {'riding_frames': count, 'net_laps': winding / 256}


with tempfile.TemporaryDirectory(prefix='sbz-discs-') as directory:
    for player, name in ((1, 'Sonic'), (2, 'Tails')):
        if player != args.player:
            continue
        g = Genesis(args.core, args.rom, args.listing, Path(directory)/name)
        try:
            boot_level(g, zone=8, act=1, player=player)
            initial = g.save()
            for index, (x, y) in enumerate(rows):
                if args.wheel is not None and index != args.wheel:
                    continue
                g.restore(initial)
                g.write('Debug_mode_flag', 1)
                g.buttons = {0}; g.run(); g.buttons = set(); g.run(2)
                assert g.read('Debug_placement_mode', 2)
                g.put('v_player', 'obX', x, 2)
                # Stay below the ledge between the vertically stacked wheels.
                g.put('v_player', 'obY', y - 96, 2)
                g.run(240)
                g.buttons = {0}; g.run(); g.buttons = set(); g.run()
                assert not g.read('Debug_placement_mode', 2)
                g.put('v_player', 'flashtime', 1800, 2)
                disc = next(a for a in objects(g, 0xA1) if
                            g.get(a, 'SMZ_disc_origX', 2) == x and
                            g.get(a, 'SMZ_disc_origY', 2) == y)
                detail = ride(g, disc, 360)
                checks.append({'player': name, 'wheel': index, 'check': 'running laps', **detail})

                # Jump from the upper arc so nearby terrain cannot block it.
                for _ in range(120):
                    if ((g.get('v_player', 'obAngle') + 24) & 255) < 48:
                        break
                    g.run()
                else:
                    raise AssertionError('Never returned to upper arc')
                before_jump = g.save()
                g.buttons = {8}; g.run(3); g.buttons = set()
                assert g.get('v_player', 'obStatus') & 2, 'Jump failed'
                assert not g.get('v_player', 'stick_to_convex'), 'Jump kept sticking flag'
                assert not g.get(disc, 'SMZ_disc_sonic_attached'), 'Jump kept disc attachment'
                checks.append({'player': name, 'wheel': index, 'check': 'jump release'})

                if index == 0:
                    g.restore(before_jump)
                    g.buttons = {5}; g.run(2); g.buttons = set()
                    assert g.get('v_player', 'obStatus') & 4, 'Did not roll'
                    # Check a full rolling lap. Sonic 1 can also lose the wheel
                    # after prolonged rolling accelerates him to high speed.
                    detail = ride(g, disc, 70, minimum_laps=1)
                    checks.append({'player': name, 'wheel': index, 'check': 'rolling lap', **detail})
                print(name, 'wheel', index, 'PASS', flush=True)
        finally:
            g.close()

finish(checks)
