#!/usr/bin/env python3
"""Exercise real 68000 unloading and complete Sonic 1 conveyor groups.

Build with build.lua first. These are isolated CPU fixtures, not Tails route
samples. The expected conveyor positions are the original S1 REV01 data.
"""
from pathlib import Path
import argparse
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
p.add_argument('--output', type=Path)
p.add_argument('--core', type=Path, help='Also check real in-game camera travel with Genesis Plus GX')
p.add_argument('--game-zone', type=int, choices=(0, 8), help=argparse.SUPPRESS)
args = p.parse_args()
checks = []
if args.game_zone is not None and not args.core:
    p.error('--game-zone requires --core')
if args.game_zone is None:
    import native_test_core as m68k
    m = m68k.Manager(args.rom, args.listing)
    pool = list(m.pool())


    def owners():
        return [a for a in pool if m.get(a, 'code') == m.s['SMZ_SpinConvey']]


    # A walking enemy can cross the right edge before the camera reaches it.
    # Its original placement is still inside the retained band, so it must live.
    for routine in ('MarkObjGone', 'MarkObjGone2', 'MarkObjGone3'):
        for x in (-128, 640, 2048):
            base = m.fixture([(611, 128, 0x21, 0x10)])
            m.cam(0, 0)
            m.act('ObjectsManager')
            obj = next(iter(m.live().values()))
            pointer = m.get(obj, 'respawn_addr', 2)
            m.put(obj, 'obX', x, 2)
            m.act(routine, obj, {m68k.UC_M68K_REG_D0: x & 65535})
            assert m.get(obj, 'code') == m.s['Ballhog'], (routine, x, 'premature unload')
            assert m.cpu.mem_read(0xFF0000+pointer, 1)[0] == 128
            # Once both the object and its spawn point are outside, release it.
            m.cam(4096, 0)
            m.act('ObjectsManager')
            m.act(routine, obj, {m68k.UC_M68K_REG_D0: x & 65535})
            assert not m.get(obj, 'code')
            assert m.cpu.mem_read(0xFF0000+pointer, 1)[0] == 0
            checks.append([routine, x, 'placement lifetime and real unload'])

    # Cursor arithmetic must work on both sides of a placement and beyond byte
    # index 255, including multiple entries at one X and backward camera travel.
    rows = [(i*16, 128, 0x21, 0x10) for i in range(768)]
    base = m.fixture(rows)
    for x in (8192, 4096, 256, 0):
        m.cam(x, 0)
        m.act('ObjectsManager')
        for obj in list(m.live().values()):
            pointer = m.get(obj, 'respawn_addr', 2)
            index = pointer-(m.s['Object_Respawn_Table'] & 65535)
            spawn_x = rows[index][0]
            m.put(obj, 'obX', 30000, 2)
            m.act('MarkObjGone2', obj)
            expected = ((spawn_x & 0xFF80) - ((x-128) & 0xFF80)) & 65535
            assert bool(m.get(obj, 'code')) == (expected <= 640), (x, index)
        checks.append(['cursor lookup', x])

    # Dynamic helpers retain their normal lifetime; explicit destruction still
    # consumes the placement rather than resurrecting a killed enemy.
    for routine in ('MarkObjGone', 'MarkObjGone2', 'MarkObjGone3'):
        m.start()
        obj = pool[0]
        m.put(obj, 'code', m.s['Ballhog'], 4)
        m.put(obj, 'obX', 2000, 2)
        m.act(routine, obj, {m68k.UC_M68K_REG_D0: 2000})
        assert not m.get(obj, 'code')
        checks.append([routine, 'dynamic object unload'])
    base = m.fixture([(611, 128, 0x21, 0x10)])
    m.cam(0, 0)
    m.act('ObjectsManager')
    obj = next(iter(m.live().values()))
    pointer = m.get(obj, 'respawn_addr', 2)
    m.act('DeleteObject', obj)
    assert m.cpu.mem_read(0xFF0000+pointer, 1)[0] == 128
    m.act('ObjectsManager')
    assert not m.live()
    checks.append(['destroyed enemy stays consumed'])

    # S1's six loops all contain eight platforms. Group 2 has its initial Y
    # positions shifted down 48 pixels relative to the usual diagonal pattern.
    bases = [(0xE80, 0x358), (0xF80, 0x2C8), (0x1080, 0x258),
             (0xF80, 0x558), (0x1B80, 0x658), (0x1C80, 0x5C8)]
    offsets = [(-108, 24, 0), (-38, -11, 1), (32, -46, 1),
               (103, -81, 1), (111, -24, 2), (41, 11, 3),
               (-29, 46, 3), (-100, 81, 3)]
    spawner_y = (0x380, 0x300, 0x280, 0x500, 0x600, 0x580)
    placements = [(x, y, sub) for x, y, oid, sub in m.rows('SMZ_1.bin') if oid == 0xA9]
    assert sorted(placements) == sorted((x, spawner_y[i] | 0x8000, 0x80+i)
                                       for i, (x, _) in enumerate(bases))
    checks.append(['real layout has all six S1 spawners with whole-loop Y loading'])


    def group_fixture(group):
        x, y = bases[group]
        base = m.fixture([(x, y | 0x8000, 0xA9, 0x80+group)])
        m.cam(x-384, y)
        m.act('ObjectsManager')
        parent = next(iter(m.live().values()))
        return parent, m.get(parent, 'respawn_addr', 2)


    for group, (x, y) in enumerate(bases):
        parent, pointer = group_fixture(group)
        m.act('SMZ_SpinConvey', parent, {m68k.UC_M68K_REG_D7: 0x12345678})
        assert m.cpu.reg_read(m68k.UC_M68K_REG_D7) == 0x12345678
        members = owners()
        actual = sorted((m.get(a, 'obX', 2), m.get(a, 'obY', 2),
                         m.get(a, 'obSubtype')) for a in members)
        expected = sorted((x+dx, y+dy, group*16+sub) for dx, dy, sub in offsets)
        assert len(members) == 8 and actual == expected, (group, actual, expected)
        assert [a for a in members if m.get(a, 'respawn_addr', 2)] == [parent]
        # Let every member initialize and complete more than one whole circuit.
        for tick in range(600):
            for obj in members:
                m.act('SMZ_SpinConvey', obj)
            assert len(owners()) == 8
        # A vertical drop and return must not create a second copy or restart
        # any member. Y changes alone never unload a loop.
        before = [(a, m.get(a, 'obX', 4), m.get(a, 'obY', 4)) for a in members]
        for camera_y in (1920, 0, y):
            m.cam(x-384, camera_y)
            m.act('ObjectsManager')
            assert [(a, m.get(a, 'obX', 4), m.get(a, 'obY', 4)) for a in owners()] == before
        # Leave in X, remove every member, and return to spawn exactly one loop.
        m.cam(x+1024, y)
        m.act('ObjectsManager')
        for obj in members:
            m.act('SMZ_SpinConvey', obj)
        assert not owners() and m.cpu.mem_read(0xFF0000+pointer, 1)[0] == 0
        m.cam(x-384, y)
        m.act('ObjectsManager')
        parent = next(iter(m.live().values()))
        m.act('SMZ_SpinConvey', parent)
        assert len(owners()) == 8
        checks.append(['S1 group', group, 'positions, circuit, vertical return, X reload'])

    # Place the parent first, halfway through and last in a nearly full pool.
    # Zero through six free helper slots must produce no partial group. Making
    # the seventh available must recover without clearing/reloading the parent.
    for parent_index in (0, 45, 89):
        for free_count in range(7):
            original, pointer = group_fixture(3)
            parent = pool[parent_index]
            data = bytes(m.cpu.mem_read(original & 0xFFFFFF, m.s['object_size']))
            for a in pool:
                # DeleteObject clears a free SST, including its ownership.
                m.cpu.mem_write(a & 0xFFFFFF, bytes(m.s['object_size']))
                m.put(a, 'code', m.s['ObjNull'], 4)
            m.cpu.mem_write(parent & 0xFFFFFF, data)
            helpers = [a for a in pool if a != parent][:7]
            for a in helpers[:free_count]:
                m.put(a, 'code', 0, 4)
            m.act('SMZ_SpinConvey', parent)
            assert owners() == [parent] and m.get(parent, 'obSubtype') == 0x83
            assert m.get(parent, 'obRoutine') == 0
            assert m.cpu.mem_read(0xFF0000+pointer, 1)[0] == 128
            assert sum(not m.get(a, 'code') for a in pool) == free_count
            for a in helpers:
                m.put(a, 'code', 0, 4)
            m.act('SMZ_SpinConvey', parent)
            assert len(owners()) == 8
            assert sum(bool(m.get(a, 'respawn_addr', 2)) for a in owners()) == 1, (parent_index, free_count)
            checks.append(['atomic group retry', parent_index, free_count])

    # A waiting group still releases its placement when the camera leaves.
    parent, pointer = group_fixture(3)
    for obj in pool[1:]:
        m.put(obj, 'code', m.s['ObjNull'], 4)
    m.act('SMZ_SpinConvey', parent)
    m.cam(6000, 1368)
    m.act('ObjectsManager')
    m.act('SMZ_SpinConvey', parent)
    assert not owners() and m.cpu.mem_read(0xFF0000+pointer, 1)[0] == 0
    checks.append(['pending group unloads without leaking helpers'])

if args.core:
    if args.game_zone is None:
        # Keep Unicorn and Genesis Plus GX in separate processes: their
        # native 68000 libraries cannot safely share this Python process.
        import subprocess
        for zone in (0, 8):
            result = subprocess.check_output([
                sys.executable, str(Path(__file__).resolve()),
                '--rom', str(args.rom), '--listing', str(args.listing),
                '--core', str(args.core), '--game-zone', str(zone)], text=True)
            checks.extend(json.loads(result)['checks'])
    else:
        import tempfile
        from genesis_test_core import Genesis
        from check_object_course import boot_level, objects

        with tempfile.TemporaryDirectory(prefix='object-lifetimes-') as directory:
            for zone in ((args.game_zone,) if args.game_zone is not None else (0, 8)):
                g = Genesis(args.core, args.rom, args.listing, Path(directory))
                boot_level(g, zone=zone, act=0)
                g.write('Debug_mode_flag', 1)
                g.buttons = {0}
                g.run(1)
                g.buttons = set()
                g.run(2)
                assert g.read('Debug_placement_mode', 2)

                def travel(x, y):
                    # Debug only moves the actor/camera; no placements, flags,
                    # dynamic slots or object routines are replaced here.
                    g.put('v_player', 'obX', x, 2)
                    g.put('v_player', 'obY', y, 2)
                    g.run(240)
                    assert not g.read('v_errortype')
                    assert g.read('v_gamemode', 2) == g.s['Level']

                if zone == 0:
                    # Wait at the start long enough for the old right-edge
                    # omission, then approach without killing any of the hogs.
                    g.run(120)
                    travel(600, 944)
                    table = g.s['Object_Respawn_Table'] & 65535
                    expected = {table+i for i in (0, 2, 3, 4)}
                    for x in (600, 2000, 600):
                        travel(x, 944)
                        if x == 600:
                            present = {g.get(a, 'respawn_addr', 2) for a in objects(g, 0x21)}
                            assert expected <= present, ('GHZ missing Ball Hog', expected-present)
                    checks.append(['in-game GHZ wait, approach and horizontal return'])
                else:
                    def loop_members():
                        return [a for a in objects(g, 0xA9)
                                if g.get(a, 'obSubtype') >> 4 == 3]

                    travel(3200, 1356)
                    g.buttons = {7}
                    g.run(158)
                    g.buttons = set()
                    g.run(2)
                    members = loop_members()
                    assert len(members) == 8
                    identity = [(a, g.get(a, 'respawn_addr', 2)) for a in members]
                    for y in (1900, 1356):
                        travel(4017, y)
                        assert [(a, g.get(a, 'respawn_addr', 2)) for a in loop_members()] == identity
                    travel(5500, 1356)
                    assert not loop_members()
                    travel(4017, 1356)
                    assert len(loop_members()) == 8
                    assert sum(bool(g.get(a, 'respawn_addr', 2)) for a in loop_members()) == 1
                    checks.append(['in-game SBZ whole loop, vertical return and horizontal reload'])
                g.close()

report = {'passed': len(checks), 'checks': checks}
if args.output:
    args.output.write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report))
