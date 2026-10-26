#!/usr/bin/env python3
"""Check assembled half-swing coordination and continuous rotation.

Optional before-ROM/listing compares both halves with the former $1n/$3n
handlers. Optional core runs the paired logs and rotators through whole frames.
"""
import argparse
import json
from pathlib import Path
import struct

import native_test_core as c


def fixture(m, subtype, flip=0, full=False):
    m.start()
    pool = list(m.pool())
    if full:
        for obj in pool:
            m.put(obj, 'code', m.s['ObjNull'])
    obj = pool[0]
    m.write('Camera_X_pos_coarse_back', 0x1700, 2)
    for field, value, size in (('code', m.s['SwingingPtfm'], 4),
                               ('obX', 0x1800, 2), ('obY', 0x400, 2),
                               ('obSubtype', subtype, 2), ('obStatus', flip, 1)):
        m.put(obj, field, value, size)
    m.act('SwingingPtfm', obj)
    return obj


def pose(m, obj, links):
    helper = m.get(obj, 'swing_helper_ptr', 4) & 0xFFFFFF
    records = bytes(m.cpu.mem_read(helper + m.s['subspr_data'], links * 6))
    return (m.get(obj, 'obX', 2), m.get(obj, 'obY', 2),
            m.get(helper, 'obX', 2), m.get(helper, 'obY', 2),
            tuple(struct.unpack_from('>HH', records, n * 6) for n in range(links)))


def native(args):
    m = c.Manager(args.rom, args.listing)
    old = c.Manager(args.before_rom, args.before_listing) if args.before_rom else None
    comparisons = 0
    if old:
        angles = [0] * 3 + list(range(129)) + [128] * 3 + list(range(128, -1, -1)) + [0] * 3
        for links in range(9):
            for flip in (0, 1):
                obj = fixture(m, 0x10 | links, flip)
                ref = fixture(old, (0x30 if flip else 0x10) | links)
                old.put(ref, 'swing_last_angle', 0xFF)
                for angle in angles:
                    for machine in (m, old):
                        machine.cpu.mem_write((machine.s['v_oscillate'] + 0x1A) & 0xFFFFFF, bytes((angle,)))
                    m.act('SwingingPtfm_UpdateMotion', obj)
                    old.act('SwingingPtfm_UpdateMotion', ref)
                    assert pose(m, obj, links) == pose(old, ref, links), (links, flip, angle)
                    comparisons += 1

    rotations = 0
    for links in range(9):
        for flip in (0, 1):
            for phase in (0, 1, 63, 64, 127, 128, 191, 192, 254, 255):
                obj = fixture(m, (phase << 8) | 0x30 | links, flip)
                first = (m.get(obj, 'obX', 2), m.get(obj, 'obY', 2))
                for tick in range(257):
                    if tick:
                        m.act('SwingingPtfm_UpdateMotion', obj)
                    angle = (phase + tick) & 255
                    if flip:
                        angle = (128 - angle) & 255
                    data = bytes(m.cpu.mem_read(m.s['Sine_Data'] + angle * 2, 130))
                    sine, cosine = struct.unpack_from('>h', data)[0], struct.unpack_from('>h', data, 128)[0]
                    radius = links * 16 + 8
                    expected = (0x1800 + ((cosine * radius) >> 8), 0x400 + ((sine * radius) >> 8))
                    assert (m.get(obj, 'obX', 2), m.get(obj, 'obY', 2)) == expected, (links, flip, phase, tick)
                    rotations += 1
                assert (m.get(obj, 'obX', 2), m.get(obj, 'obY', 2)) == first

    # The helper is optional under pool pressure; a null pointer must not write
    # through ROM or delete an unrelated slot, including during construction.
    for subtype in (0x16, 0x36, 0xFF36):
        obj = fixture(m, subtype, full=True)
        assert m.get(obj, 'swing_helper_ptr', 4) == 0
        m.act('SwingingPtfm_UpdateMotion', obj)
        m.act('SwingingPtfm_DelAll', obj)
        assert m.get(obj, 'code') == 0
    obj = fixture(m, 0x31)
    helper = m.get(obj, 'swing_helper_ptr', 4) & 0xFFFFFF
    assert m.get(helper, 'mainspr_mapframe') == 2
    assert m.get(helper, 'sub2_mapframe') == 1

    obj = fixture(m, 0x45)
    m.put('v_player', 'obX', 0x1800, 2)
    for _ in range(188):
        m.act('SwingingPtfm_UpdateMotion', obj)
    assert m.get(obj, 'swing_mode_timer', 2) == 60
    assert m.get(obj, 'swing_last_angle') == 0x80
    assert (m.get(obj, 'obX', 2), m.get(obj, 'obY', 2)) == (0x1800 - 88, 0x400)
    assert m.s['object_size'] == 0x4E and m.s['obSubtype'] == 0x2C
    return dict(before_half_swing_comparisons=comparisons, rotation_samples=rotations,
                boundary_checks='null-helper motion/deletion, one-link anchor, trap endpoint, SST ABI')


def game(args):
    from genesis_test_core import Genesis
    from check_object_course import boot_level
    from check_companion_followup import place, isolate
    g = Genesis(args.core, args.rom, args.listing, args.output / 'game', args.pal,
                system_directory=args.system_directory)
    boot_level(g, zone=0, act=3, player=0)
    base = g.save()
    pool = list(range(g.s['v_lvlobjspace'] & 65535, g.s['v_lvlobjend'] & 65535, g.s['object_size']))
    rows = []
    for subtype, flips in ((0x16, (0, 1)), (0x36, (0,)), (0x4036, (1,))):
        g.restore(base)
        isolate(g)
        for a in pool:
            g.write(a, 0, g.s['object_size'])
        for actor in ('v_player', 'v_player2'):
            place(g, actor, 400, 540)
            g.put(actor, 'obControl', 1)
        g.write('Camera_X_pos', 250, 2)
        g.write('Camera_Y_pos', 480, 2)
        objects = pool[:len(flips)]
        for obj, flip in zip(objects, flips):
            for field, value, size in (('code', g.s['SwingingPtfm'], 4),
                                       ('obX', 400, 2), ('obY', 600, 2),
                                       ('obSubtype', subtype, 2), ('obStatus', flip, 1)):
                g.put(obj, field, value, size)
        g.buttons2 = {4}
        g.write('Tails_CPU_idle_timer', 6000, 2)
        positions = [set() for _ in objects]
        for frame in range(540):
            g.run()
            assert not g.read('v_errortype')
            for n, obj in enumerate(objects):
                assert g.get(obj, 'code') == g.s['SwingingPtfm']
                positions[n].add((g.get(obj, 'obX', 2), g.get(obj, 'obY', 2)))
            if len(objects) == 1 and frame == 2:
                obj = objects[0]
                x, y = g.get(obj, 'obX', 2), g.get(obj, 'obY', 2)
                for actor, dx in (('v_player', -4), ('v_player2', 4)):
                    place(g, actor, x + dx, y - 8 - g.get(actor, 'obHeight') + 3)
                    g.put(actor, 'obVelY', 0x300, 2)
                    g.put(actor, 'obControl', 1)
                g.put(obj, 'obRender', g.get(obj, 'obRender') | 0x80)
            if len(objects) == 1 and frame > 6:
                assert g.get(objects[0], 'obStatus') & 0x18 == 0x18, ('rider lost', subtype, frame)
            if len(objects) == 2 and frame > 2:
                assert any(g.get(obj, 'obY', 2) == 704 for obj in objects), 'Both logs left the waiting position'
            if frame in (30, 90, 180, 270):
                g.video.save(args.output / 'game' / f'motion-{subtype:04X}-{frame}.png')
        assert all(len(points) > 30 for points in positions)
        rows.append(dict(subtype=subtype, flips=flips, distinct_positions=[len(p) for p in positions]))
    g.close()
    return rows


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom', type=Path, default=c.ROOT / 's2built.bin')
    p.add_argument('--listing', type=Path, default=c.ROOT / 'md-main.lst')
    p.add_argument('--before-rom', type=Path)
    p.add_argument('--before-listing', type=Path)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--core', type=Path)
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--pal', action='store_true')
    args = p.parse_args()
    assert bool(args.before_rom) == bool(args.before_listing)
    args.output.mkdir(parents=True, exist_ok=True)
    report = native(args)
    if args.core:
        report['game'] = game(args)
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
