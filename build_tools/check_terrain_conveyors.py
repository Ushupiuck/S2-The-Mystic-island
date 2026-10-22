#!/usr/bin/env python3
"""Exercise terrain conveyors through the real ROM and Genesis Plus GX.

The matrix freezes initialized players to isolate rectangle/force semantics.
Traversal scenes retain GHZ1's actual terrain and normal player physics, and
place real conveyor actors over the complete tested route. A cloned RAM chunk
supplies isolated left/right walls for collision-path tests. No ROM code is
patched. These focused fixtures are separate from companion AI playthroughs.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import subprocess
import sys

from genesis_test_core import Genesis
from check_object_course import boot_level, objects
from check_companion_followup import isolate, place, spawn

ROOT = Path(__file__).resolve().parents[1]
ACTORS = ('v_player', 'v_player2')


def subtype(width, height, speed):
    assert width in range(16, 257, 16) and height in (48, 112)
    assert 0 <= abs(speed) <= 7
    return (width // 16 - 1) | (abs(speed) << 4) | (128 if height == 112 else 0)


def belt(g, x, y, width, height, speed):
    obj = spawn(g, 'Conveyor', x, y, subtype(width, height, speed))
    g.put(obj, 'obStatus', int(speed < 0))
    return obj


def sample(g, actor):
    return {field: g.get(actor, field, size) for field, size in (
        ('obX', 2), ('obY', 2), ('obStatus', 1), ('obAngle', 1),
        ('obRoutine', 1), ('obVelX', 2), ('obVelY', 2), ('obInertia', 2),
        ('spindash_flag', 1), ('conveyor_applied', 1))}


def covers(area, row):
    x, y, width, height = area
    return x - width // 2 <= row['obX'] < x + width // 2 and y - height <= row['obY'] < y


def step(g):
    g.run()
    assert not g.read('v_errortype'), ('ROM exception', g.frame)


def check_layouts(reference):
    """Compare the previous handler's format with the migrated raw records."""
    before = subprocess.check_output([
        'git', 'show', reference + ':level/objects/SMZ_2.bin'], cwd=ROOT)
    after = (ROOT / 'level/objects/SMZ_2.bin').read_bytes()
    assert len(before) == len(after)
    migrated = []
    for offset in range(0, len(before), 6):
        old = struct.unpack_from('>HHBB', before, offset)
        new = struct.unpack_from('>HHBB', after, offset)
        if old[2] != 0xA2:
            assert old == new, ('Unrelated placement changed', offset)
            continue
        x, y, _, old_subtype = old
        expected_width = 112 if old_subtype & 15 else 256
        expected_speed = (old_subtype >> 4) - (16 if old_subtype & 128 else 0)
        actual_speed = (new[3] >> 4) & 7
        if new[1] & 0x2000:
            actual_speed = -actual_speed
        assert new[:1] == old[:1] and new[2] == old[2]
        assert (new[1] & ~0x2000) == (y & ~0x2000)
        assert actual_speed == expected_speed
        assert ((new[3] & 15) + 1) * 16 == expected_width
        assert not new[3] & 128, 'Existing belt changed height'
        migrated.append({'x': x, 'y': y & 0xFFF, 'width': expected_width,
                         'speed': expected_speed, 'subtype': new[3]})
    assert len(migrated) == 20
    return migrated


def matrix(g, initial):
    checks = []
    g.restore(initial)
    isolate(g)
    for actor in ACTORS:
        place(g, actor, 0x180, 0x180, False)
        g.put(actor, 'obControl', 1)
        g.put(actor, 'obXSub', 0x1234, 2)
    g.write('Camera_X_pos', 0x100, 2)
    g.write('Camera_Y_pos', 0x100, 2)
    base = g.save()

    def reset():
        g.restore(base)
        g.buttons2 = {4}  # manual lookup suppresses companion follow inputs

    # All widths, speeds, heights and placement flips, for both player slots.
    for sub in range(256):
        for flip in range(4):
            reset()
            obj = spawn(g, 'Conveyor', 0x180, 0x190, sub)
            g.put(obj, 'obStatus', flip)
            step(g)
            speed = ((sub >> 4) & 7) * (-1 if flip & 1 else 1)
            assert g.get(obj, 'conv_width', 2) == ((sub & 15) + 1) * 8
            assert g.get(obj, 'conv_height', 2) == (112 if sub & 128 else 48)
            assert g.get(obj, 'conv_speed', 2) == speed & 65535
            for actor in ACTORS:
                assert g.get(actor, 'obX', 2) == 0x180 + speed, (sub, flip, actor, sample(g, actor))
                assert g.get(actor, 'obXSub', 2) == 0x1234
    checks.append({'case': 'all-subtypes-and-flips', 'configurations': 1024,
                   'player_slots': 2})

    count = 0
    for width in (16, 112, 256):
        for height in (48, 112):
            for speed in (-7, 7):
                for dx, dy, inside in (
                    (-width // 2, -1, True), (width // 2 - 1, -1, True),
                    (-width // 2 - 1, -1, False), (width // 2, -1, False),
                    (0, -height, True), (0, -height - 1, False), (0, 0, False)):
                    reset()
                    for actor in ACTORS:
                        g.put(actor, 'obX', 0x180 + dx, 2)
                        g.put(actor, 'obY', 0x190 + dy, 2)
                    belt(g, 0x180, 0x190, width, height, speed)
                    step(g)
                    for actor in ACTORS:
                        assert g.get(actor, 'obX', 2) == 0x180 + dx + (speed if inside else 0)
                    count += 1
    checks.append({'case': 'rectangle-boundaries', 'configurations': count})

    for state in ('airborne', 'hurt', 'dead', 'inactive'):
        reset()
        for actor in ACTORS:
            if state == 'airborne':
                g.put(actor, 'obStatus', 2)
            elif state == 'inactive':
                g.put(actor, 'code', 0)
            else:
                g.put(actor, 'obRoutine', 4 if state == 'hurt' else 6)
                g.put(actor, 'obStatus', 2)
        belt(g, 0x180, 0x190, 256, 48, 7)
        step(g)
        for actor in ACTORS:
            assert not g.get(actor, 'conveyor_applied'), (state, actor, sample(g, actor))
        checks.append({'case': 'ignore-' + state})

    for speed in (-7, -2, 2, 7):
        for overlap in (False, True):
            for reverse in (False, True):
                reset()
                x = 0x180 if overlap else (0x17F if speed > 0 else 0x180)
                for actor in ACTORS:
                    g.put(actor, 'obX', x, 2)
                centers = [0x180, 0x180] if overlap else [0x100, 0x200]
                if reverse:
                    centers.reverse()
                live = [belt(g, center, 0x190, 256, 48, speed) for center in centers]
                for frame in range(1, 4):
                    step(g)
                    assert all(g.get(obj, 'code') == g.s['Conveyor'] for obj in live), 'Join fixture left the loading window'
                    for actor in ACTORS:
                        assert g.get(actor, 'obX', 2) == x + frame * speed, (speed, overlap, reverse, frame, actor)
    checks.append({'case': 'adjacent-overlapping-areas-once-per-frame',
                   'configurations': 16, 'frames_each': 3})

    # Clone one unused GHZ chunk in RAM and insert a 32x32 full collision wall.
    # Vary only its solidity bits to exercise both actual collision paths.
    layout = g.terrain_address('layout')
    chunks = g.terrain_address('chunks')

    def wall_chunk(solidity):
        ids = {g.read(layout + i) for i in range(g.s['Level_Layout_End'] - g.s['Level_Layout'])}
        unused = next(i for i in range(255, 0, -1) if i not in ids)
        cell = 3 * 256 + 2  # world $100-$17F, $180-$1FF
        source = g.read(layout + cell)
        g.write(chunks + unused * 128, g.read(chunks + source * 128, 128), 128)
        g.write(layout + cell, unused)
        # Take a real full block below GHZ1's initial ground surface.
        ground_chunk = g.read(layout + 7 * 256 + 2)
        word = g.read(chunks + ground_chunk * 128 + 7 * 16, 2)
        rom = bytes(g.rom)
        shape = rom[g.read('v_colladdr1', 4) + (word & 0x3FF) * 2]
        assert set(rom[g.s['ColArray2'] + shape * 16:g.s['ColArray2'] + shape * 16 + 16]) == {16}
        for row in (0, 1):
            for column in (4, 5):
                g.write(chunks + unused * 128 + row * 16 + column * 2,
                        (word & 0xFFF) | solidity, 2)

    for speed in (-7, -2, 2, 7):
        for path in (0, 1):
            for wall_path in (0, 1):
                reset()
                wall_chunk(0x3000 if wall_path == 0 else 0xC000)
                x = 0x12A if speed > 0 else 0x176
                for actor in ACTORS:
                    g.put(actor, 'obX', x, 2)
                    g.put(actor, 'obY', 0x190, 2)
                    g.put(actor, 'obTopSolidBit', 12 + path * 2)
                    g.put(actor, 'obLRBSolidBit', 13 + path * 2)
                assert 0xE0 <= min(x, x + 20 * speed) and max(x, x + 20 * speed) < 0x1E0
                belt(g, 0x160, 0x1A0, 256, 48, speed)
                for _ in range(20):
                    step(g)
                for actor in ACTORS:
                    actual = g.get(actor, 'obX', 2)
                    if path == wall_path:
                        assert actual == (0x135 if speed > 0 else 0x16A), (speed, path, actor, hex(actual))
                    else:
                        assert actual == x + 20 * speed, (speed, path, wall_path, actor, hex(actual))
                    assert not g.get(actor, 'obVelX', 2) and not g.get(actor, 'obInertia', 2)
    checks.append({'case': 'left-right-walls-and-both-collision-paths', 'configurations': 16})
    return checks


def traversal(g, initial, role, output):
    checks = []
    actors = ACTORS if role == 'both' else ACTORS[:1]

    def prepare(sx, sy, speed=2):
        g.restore(initial)
        isolate(g)
        if role != 'both':
            g.put('v_player2', 'code', 0)
        for i, actor in enumerate(actors):
            place(g, actor, sx + (8 if speed > 0 else -8) * i, sy)
            g.put(actor, 'flashtime', 6000, 2)
        g.buttons2 = {4} if role == 'both' else set()
        g.write('Camera_X_pos', max(0, sx - 160), 2)
        g.write('Camera_Y_pos', max(0, sy - 100), 2)
        for _ in range(60):
            step(g)

    # Each rectangle covers the complete tested path, including the character's
    # changing center height and the post-push position at rectangle joins.
    scenes = [
        ('bumps-right', 0x108, 0x3B0, 0x1E0, 2, [(0x180, 0x3D0, 256, 48)]),
        ('bumps-left', 0x1F0, 0x3B0, 0x118, -2, [(0x180, 0x3D0, 256, 48)]),
        ('stepped-rectangles-up', 0x354, 0x3A0, 0x3C0, 2,
         [(0x368, 0x3C0, 80, 112), (0x3B0, 0x3A0, 64, 112)]),
        ('stepped-rectangles-down', 0x3C8, 0x360, 0x360, -2,
         [(0x368, 0x3C0, 80, 112), (0x3B0, 0x3A0, 64, 112)]),
        ('tall-area-downhill', 0x638, 0x350, 0x6D8, 2, [(0x690, 0x3D0, 192, 112)]),
        ('tall-area-uphill', 0x6E8, 0x390, 0x648, -2, [(0x690, 0x3D0, 192, 112)]),
        ('curve-up-to-45-degrees', 0x718, 0x390, 0x754, 2, [(0x750, 0x3D0, 128, 112)]),
    ]
    for name, sx, sy, goal, speed, areas in scenes:
        prepare(sx, sy, speed)
        for actor in actors:
            assert abs(g.get(actor, 'obX', 2) - sx) <= 12 and not g.get(actor, 'obStatus') & 2
        belts = [belt(g, x, y, width, height, speed) for x, y, width, height in areas]
        trace = []
        for frame in range(240):
            # A paired control frame measures the belt's actual contribution
            # separately from player acceleration and slope gravity.
            before = g.save()
            step(g)
            actual = {actor: sample(g, actor) for actor in actors}
            video = g.video.copy()
            after = g.save()
            g.restore(before)
            g.buttons2 = {4} if role == 'both' else set()
            for obj in belts:
                g.put(obj, 'obRoutine', 2)
                g.put(obj, 'conv_speed', 0, 2)
            step(g)
            controls = {actor: sample(g, actor) for actor in actors}
            g.restore(after)
            g.video = video
            g.buttons2 = {4} if role == 'both' else set()
            for actor, row in actual.items():
                row['belt_dx'] = row['obX'] - controls[actor]['obX']
                assert row['obRoutine'] == 2 and not row['obStatus'] & 2, (name, actor, row)
                assert any(covers(area, row) for area in areas), (name, 'uncovered', actor, row)
                assert row['belt_dx'] == speed, (name, 'incorrect push', actor, row)
            trace.append(actual)
            x = actual['v_player']['obX']
            if (speed > 0 and x >= goal) or (speed < 0 and x <= goal):
                break
        else:
            raise AssertionError((name, 'did not complete route', trace[-1]))
        angles = sorted({row[actor]['obAngle'] for row in trace for actor in actors})
        assert len(angles) >= 2, (name, 'did not traverse irregular terrain')
        (output / (name + '-trace.json')).write_text(json.dumps(trace) + '\n')
        g.video.save(output / (name + '.png'))
        checks.append({'case': name, 'role': role, 'frames': len(trace),
                       'rectangles': areas, 'angles': angles, 'uncovered_frames': 0,
                       'incorrect_pushes': 0, 'final': trace[-1]})
        print(role, name, 'PASS', flush=True)

    # A real GHZ wall, using ordinary movement and both standing/charging sizes.
    for charging in (False, True):
        prepare(0x850, 0x350)
        belt(g, 0x880, 0x3A0, 256, 112, 4)
        if charging:
            g.buttons = {5}
            g.buttons2 = {5} if role == 'both' else set()
            g.run(2)  # enter the crouch before pressing a spin-dash button
            g.buttons = {5, 8}
            g.buttons2 = {5, 8} if role == 'both' else set()
        for _ in range(60):
            step(g)
        for actor in actors:
            row = sample(g, actor)
            assert row['obX'] == 0x880 - g.get(actor, 'obWidth') - 2, (role, charging, actor, row)
            assert not row['obStatus'] & 2 and row['obRoutine'] == 2
            assert bool(row['spindash_flag']) == charging, (role, charging, actor, row)
        checks.append({'case': 'real-wall-while-' + ('charging' if charging else 'standing'),
                       'role': role, 'final': {a: sample(g, a) for a in actors}})

    prepare(0x180, 0x3B0)
    area = (0x180, 0x3D0, 256, 112)
    belt(g, *area, 2)
    g.run(8)
    g.buttons = {8}
    g.buttons2 = {8} if role == 'both' else set()
    for _ in range(3):
        step(g)
        for actor in actors:
            row = sample(g, actor)
            assert row['obStatus'] & 2 and not row['conveyor_applied'], (role, 'jump', actor, row)
            assert covers(area, row), ('Jump fixture left area before its air check', row)
    g.buttons = set()
    g.buttons2 = {4} if role == 'both' else set()
    landed = set()
    for _ in range(120):
        step(g)
        for actor in actors:
            row = sample(g, actor)
            if not row['obStatus'] & 2:
                assert row['conveyor_applied'], (role, 'landing did not resume belt', actor, row)
                landed.add(actor)
        if len(landed) == len(actors):
            break
    assert len(landed) == len(actors), (role, 'did not land back on belt')
    checks.append({'case': 'jump-ignores-belt-and-landing-resumes', 'role': role})
    return checks


def placed_belts(g, initial):
    checks = []
    rows = [(x, y, sub) for x, y, oid, sub in struct.iter_unpack(
        '>HHBB', (ROOT / 'level/objects/SMZ_2.bin').read_bytes()[:-6]) if oid == 0xA2]
    for x, y, sub in rows:
        g.restore(initial)
        g.put('v_player2', 'code', 0)
        g.write('Debug_mode_flag', 1)
        g.buttons = {0}
        step(g)
        g.buttons = set()
        step(g)
        assert g.read('Debug_placement_mode', 2)
        g.put('v_player', 'obX', x, 2)
        g.put('v_player', 'obY', (y & 0xFFF) - 24, 2)
        g.put('v_player', 'obStatus', 2)
        for _ in range(480):
            step(g)
            matches = [a for a in objects(g, 0xA2) if g.get(a, 'obX', 2) == x and g.get(a, 'obY', 2) == y & 0xFFF]
            if len(matches) == 1 and g.get(matches[0], 'obRoutine') == 2:
                break
        assert len(matches) == 1, ('Missing/duplicate actual placement', hex(x), hex(y), matches,
                                   g.read('Camera_X_pos', 2), g.read('Camera_Y_pos', 2))
        obj = matches[0]
        speed = ((sub >> 4) & 7) * (-1 if y & 0x2000 else 1)
        assert g.get(obj, 'conv_speed', 2) == speed & 65535
        assert g.get(obj, 'conv_width', 2) * 2 == ((sub & 15) + 1) * 16
        assert g.get(obj, 'conv_height', 2) == 48
        checks.append({'case': 'actual-SMZ2-placement', 'x': x, 'y': y & 0xFFF,
                       'speed': speed, 'width': g.get(obj, 'conv_width', 2) * 2})
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core', type=Path, required=True)
    parser.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    parser.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--before-ref', help='Compare migrated layouts with this previous git commit')
    parser.add_argument('--part', choices=('matrix', 'sonic', 'tails', 'both', 'smz'), help=argparse.SUPPRESS)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.part is None:
        checks = []
        migration = check_layouts(args.before_ref) if args.before_ref else None
        for part in ('matrix', 'sonic', 'tails', 'both', 'smz'):
            directory = args.output / part
            subprocess.run([sys.executable, str(Path(__file__).resolve()),
                            '--core', str(args.core), '--rom', str(args.rom),
                            '--listing', str(args.listing), '--output', str(directory),
                            '--part', part], check=True)
            checks.extend(json.loads((directory / 'report.json').read_text())['checks'])
        report = {'passed': True, 'rom_sha256': hashlib.sha256(args.rom.read_bytes()).hexdigest(),
                  'companion_ai_playthrough': False, 'migration': migration, 'checks': checks}
        (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print('Terrain conveyor checks pass:', len(checks), flush=True)
        return
    mode = {'matrix': 0, 'sonic': 1, 'tails': 2, 'both': 0, 'smz': 0}[args.part]
    g = Genesis(args.core, args.rom, args.listing, args.output)
    try:
        boot_level(g, zone=8 if args.part == 'smz' else 0,
                   act=1 if args.part == 'smz' else 0, player=mode)
        initial = g.save()
        if args.part == 'matrix':
            checks = matrix(g, initial)
        elif args.part == 'smz':
            checks = placed_belts(g, initial)
        else:
            checks = traversal(g, initial, args.part, args.output)
        (args.output / 'report.json').write_text(json.dumps({'passed': True, 'checks': checks}, indent=2) + '\n')
        print(args.part, 'PASS', flush=True)
    finally:
        g.close()


if __name__ == '__main__':
    main()
