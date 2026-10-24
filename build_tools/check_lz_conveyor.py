#!/usr/bin/env python3
"""Run assembled LZ/S3&K conveyors: construction, paths, reversal and ownership."""
import argparse
import json
from pathlib import Path
import struct

import native_test_core as c

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--rom', type=Path)
p.add_argument('--listing', type=Path)
p.add_argument('--output', type=Path)
args = p.parse_args()
m = c.Manager(args.rom, args.listing)
pool = list(m.pool())
checks = []
expected_counts = (8, 8, 8, 8, 12, 9, 4, 8)
sheet = c.ROOT / 'art/moduled kosinski/LZ conveyor.kospm'
tiles = int.from_bytes(sheet.read_bytes()[:2], 'big') // 32
assert m.s['ArtTile_LZ_Conveyor_Belt'] + tiles == m.s['ArtTile_LZ_Conveyor_Belt_End'] <= m.s['ArtTile_Ball_HogV']


def members():
    return [a for a in pool if m.get(a, 'code') == m.s['LabyrinthConvey']]


def group_fixture(group, x=0x1800, y=0x400, facing=0, reversed=False):
    m.fixture([(x, y | 0x8000 | (facing << 13), 0x1F, 0x80 + group)])
    m.cam(x - 256, y)
    m.act('ObjectsManager')
    parent = next(iter(m.live().values()))
    handle = m.get(parent, 'respawn_addr', 2)
    m.write('f_conveyrev', int(reversed))
    return parent, handle


def points(obj):
    address = m.get(obj, 'LCon_targetdata', 4)
    count = m.get(obj, 'LCon_count') // 4
    x, y = (m.get(obj, name, 2) for name in ('LCon_originX', 'LCon_originY'))
    return [((dx + x) & 65535, (dy + y) & 65535) for dx, dy in
            struct.iter_unpack('>hh', m.cpu.mem_read(address, count * 4))]


# Original S1 counts/spacing, complete relative translation, and whole loops.
for group, count in enumerate(expected_counts):
    parent, handle = group_fixture(group)
    m.act('LabyrinthConvey', parent, {c.UC_M68K_REG_D7: 0x12345678})
    assert m.cpu.reg_read(c.UC_M68K_REG_D7) == 0x12345678
    objects = members()
    assert len(objects) == count, (group, len(objects))
    assert [a for a in objects if m.get(a, 'respawn_addr', 2)] == [parent]
    original = [(m.get(a, 'obX', 2), m.get(a, 'obY', 2), m.get(a, 'obSubtype')) for a in objects]
    parent2, _ = group_fixture(group, x=0x2200, y=0x600)
    m.act('LabyrinthConvey', parent2)
    translated = [(m.get(a, 'obX', 2), m.get(a, 'obY', 2), m.get(a, 'obSubtype')) for a in members()]
    assert translated == [(x + 0xA00, y + 0x200, sub) for x, y, sub in original]
    parent, handle = group_fixture(group)
    m.act('LabyrinthConvey', parent)
    objects = members()
    for obj in objects:
        m.act('LabyrinthConvey', obj)
    path = points(parent)
    seen = set()
    changes = 0
    previous = m.get(parent, 'LCon_posindex')
    # Enough time for two circuits of the longest retained S1 shape.
    for tick in range(4000):
        m.act('LabyrinthConvey', parent)
        target = (m.get(parent, 'LCon_nextX', 2), m.get(parent, 'LCon_nextY', 2))
        assert target in path
        index = m.get(parent, 'LCon_posindex')
        if index != previous:
            changes += 1
            previous = index
            seen.add(index // 4)
        if changes >= 2 * len(path):
            break
    else:
        raise AssertionError(('stalled path', group, changes, m.get(parent, 'obX', 2), m.get(parent, 'obY', 2), target))
    assert seen == set(range(len(path)))
    # A vertical camera excursion cannot duplicate a wide/any-Y group.
    m.cam(0x1700, 0x780)
    m.act('ObjectsManager')
    assert len(members()) == count
    # The entire horizontal route must leave the retained interval before unload.
    m.cam(0x2800, 0x400)
    m.act('ObjectsManager')
    for obj in objects:
        m.act('LabyrinthConvey', obj)
    assert not members() and m.placement_read(handle - m.respawn_base) == 0
    m.cam(0x1700, 0x400)
    m.act('ObjectsManager')
    parent = next(iter(m.live().values()))
    m.act('LabyrinthConvey', parent)
    assert len(members()) == count
    checks.append(['group', group, count, 'relative spacing, two circuits, vertical travel, unload/reload'])

# The largest group must be atomic for fragmented pools, independent of parent slot.
for parent_index in (0, len(pool) // 2, len(pool) - 1):
    for free_count in range(11):
        original, handle = group_fixture(4)
        data = bytes(m.cpu.mem_read(original & 0xFFFFFF, m.s['object_size']))
        for obj in pool:
            m.cpu.mem_write(obj & 0xFFFFFF, bytes(m.s['object_size']))
            m.put(obj, 'code', m.s['ObjNull'])
        parent = pool[parent_index]
        m.cpu.mem_write(parent & 0xFFFFFF, data)
        helpers = [a for a in pool if a != parent][:11]
        for obj in helpers[:free_count]:
            m.cpu.mem_write(obj & 0xFFFFFF, bytes(m.s['object_size']))
        m.act('LabyrinthConvey', parent)
        assert members() == [parent] and m.get(parent, 'obSubtype') == 0x84
        assert m.get(parent, 'obRoutine') == 0 and m.get(parent, 'respawn_addr', 2) == handle
        for obj in helpers:
            m.cpu.mem_write(obj & 0xFFFFFF, bytes(m.s['object_size']))
        m.act('LabyrinthConvey', parent)
        assert len(members()) == 12
        checks.append(['pool retry', parent_index, free_count])

# Facing and persistent S1 reversal compose; held/released switch E must not
# repeatedly reverse members, and freshly loaded groups inherit the latch.
for facing in (0, 1):
    for reversed in (False, True):
        parent, _ = group_fixture(6, facing=facing, reversed=reversed)
        m.act('LabyrinthConvey', parent)
        objects = members()
        for obj in objects:
            m.act('LabyrinthConvey', obj)
        expected = 0xFC if bool(facing) ^ reversed else 4
        assert {m.get(obj, 'LCon_increment') for obj in objects} == {expected}
        m.cpu.mem_write((m.s['f_switch'] + 14) & 0xFFFFFF, b'\1')
        for tick in range(60):
            for obj in objects:
                m.act('LabyrinthConvey', obj)
        final = 4 if facing else 0xFC
        assert {m.get(obj, 'LCon_increment') for obj in objects} == {final}
        assert m.read('f_conveyrev') == 1
        m.cpu.mem_write((m.s['f_switch'] + 14) & 0xFFFFFF, b'\0')
        for obj in objects:
            m.act('LabyrinthConvey', obj)
        assert {m.get(obj, 'LCon_increment') for obj in objects} == {final}
        checks.append(['direction', facing, reversed, 'switch E held/released'])

# Both actual player SSTs can board and ride either dominant axis, and jumping
# detaches one rider without disturbing the other player's ownership.
for subtype in (0x20, 0x30):
    m.start()
    obj = pool[0]
    m.put(obj, 'code', m.s['LabyrinthConvey'])
    m.put(obj, 'obSubtype', subtype)
    m.put(obj, 'obX', 0x1800, 2)
    m.put(obj, 'obY', 0x400, 2)
    m.write('Camera_X_pos_coarse_back', 0x1700, 2)
    m.act('LabyrinthConvey', obj)
    x, y = m.get(obj, 'obX', 2), m.get(obj, 'obY', 2)
    for who, offset in (('v_player', -4), ('v_player2', 4)):
        m.put(who, 'obX', x + offset, 2)
        m.put(who, 'obY', y - 8 - 19, 2)
        m.put(who, 'obStatus', 2)
        m.put(who, 'obVelY', 0x100, 2)
    m.put(obj, 'obRender', 0x84)
    m.act('LabyrinthConvey', obj)
    assert m.get(obj, 'obStatus') & 0x18 == 0x18
    before = [(m.get(who, 'obX', 2), m.get(who, 'obY', 2)) for who in ('v_player', 'v_player2')]
    for tick in range(20):
        m.act('LabyrinthConvey', obj)
    for who, (old_x, old_y) in zip(('v_player', 'v_player2'), before):
        assert m.get(who, 'obStatus') & 8
        assert m.get(who, 'obX', 2) - old_x == (20 if subtype == 0x30 else 0)
        assert m.get(who, 'obY', 2) - old_y == (20 if subtype == 0x20 else 0)
    m.put('v_player', 'obStatus', 0xA)
    m.put('v_player', 'obVelY', -0x400, 2)
    m.act('LabyrinthConvey', obj)
    assert m.get(obj, 'obStatus') & 0x18 == 0x10
    assert not m.get('v_player', 'obStatus') & 8 and m.get('v_player2', 'obStatus') & 8
    checks.append(['both riders', subtype, 'board, carry 20 pixels, primary jumps away'])

# Spiked groups share every normal group's constructor and switch-E mover.
for group, count in enumerate(expected_counts):
    parent, _ = group_fixture(group)
    m.put(parent, 'obSubtype', 0xC0 + group)
    m.act('LabyrinthConvey', parent)
    objects = members()
    assert len(objects) == count and {m.get(a, 'LCon_settings') for a in objects} == {1}
    for obj in objects:
        m.act('LabyrinthConvey', obj)
    assert {m.get(a, 'obFrame') for a in objects} == {5}
    m.cpu.mem_write((m.s['f_switch'] + 14) & 0xFFFFFF, b'\1')
    for obj in objects:
        m.act('LabyrinthConvey', obj)
    assert {m.get(a, 'LCon_increment') for a in objects} == {0xFC}
    checks.append(['spiked group', group, count, 'switch reverses every member'])

# The upper recipe byte is a real extension field, independent of route/phase.
parent, _ = group_fixture(0)
table = m.s['LCon_Placements']
entry = table + int.from_bytes(m.cpu.mem_read(table, 2), 'big') + 6
m.cpu.mem_write(entry, b'\1')
m.act('LabyrinthConvey', parent)
assert sorted(m.get(a, 'LCon_settings') for a in members()) == [0] * 7 + [1]
m.cpu.mem_write(entry, b'\0')
checks.append(['recipe settings', 'one spiked member inside a normal group'])

for harmful in (0, 1):
    for contact in ('top', 'side', 'underside'):
        for protection in ('none', 'invincible', 'flashing-word'):
            m.start()
            obj = pool[0]
            m.put(obj, 'code', m.s['LabyrinthConvey'])
            m.put(obj, 'obSubtype', 0x30)
            m.put(obj, 'LCon_settings', harmful)
            m.put(obj, 'obX', 0x1800, 2)
            m.put(obj, 'obY', 0x400, 2)
            m.write('Camera_X_pos_coarse_back', 0x1700, 2)
            m.act('LabyrinthConvey', obj)
            m.put(obj, 'obRender', 0x84)
            m.write('v_rings', 20, 2)
            x, y = m.get(obj, 'obX', 2), m.get(obj, 'obY', 2)
            for who, dx in (('v_player', -4), ('v_player2', 4)):
                m.put(who, 'obX', x + (25 if contact == 'side' else dx), 2)
                m.put(who, 'obY', y + (21 if contact == 'underside' else -27 if contact == 'top' else -2), 2)
                m.put(who, 'obStatus', 2)
                m.put(who, 'obVelY', -0x100 if contact == 'underside' else 0x100, 2)
                if protection == 'invincible':
                    m.put(who, 'obStatusSecondary', 1 << m.s['obStatusSecondary_isInvincible'])
                if protection == 'flashing-word':
                    m.put(who, 'flashtime', 0x100, 2)
            m.act('LabyrinthConvey', obj)
            hurt = harmful and contact == 'underside' and protection == 'none'
            assert {m.get(who, 'obRoutine') for who in ('v_player', 'v_player2')} == {4 if hurt else 2}
            checks.append(['contact', harmful, contact, protection, bool(hurt)])

# The diagonal calculation must retain the division remainder on the correct
# subpixel axis; the old LZ port accidentally wrote d0 into Y's subpixel word.
m.start()
obj = pool[0]
for name, value in (('obX', 0x1000), ('obY', 0x500), ('LCon_nextX', 0x108B), ('LCon_nextY', 0x521)):
    m.put(obj, name, value, 2)
m.act('LCon_ChangeDir', obj)
assert m.get(obj, 'obVelX', 2) == 0x100
assert m.get(obj, 'obYSub', 2) == (-33 * 256 % -139) & 65535
checks.append(['fractional diagonal', 'Y receives signed DIVS remainder'])

# Unsupported group IDs unload safely. The wheel keeps ordinary placement
# ownership and uses frame 0-3 rather than the platform's frame 4.
for subtype in (0x88, 0xFF):
    parent, handle = group_fixture(0)
    m.put(parent, 'obSubtype', subtype)
    m.act('LabyrinthConvey', parent)
    assert not members() and m.placement_read(handle - m.respawn_base) == 0
m.start()
m.put(obj, 'code', m.s['LabyrinthConvey'])
m.put(obj, 'obX', 0x1000, 2)
m.put(obj, 'obY', 0x400, 2)
m.put(obj, 'obSubtype', 0x7F)
m.write('Camera_X_pos_coarse_back', 0xF00, 2)
m.act('LCon_ResetWheels')
m.act('LabyrinthConvey', obj)
assert m.get(obj, 'obRoutine') == 4 and m.get(obj, 'obFrame') == 0
assert m.read('v_lcon_wheel_frame') == 1
m.write('f_conveyrev', 1)
m.write('v_framecount', 4, 2)
m.act('LabyrinthConvey', obj)
assert m.read('v_lcon_wheel_frame') == 0
checks.append(['invalid groups and decorative wheel'])

if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'checks': checks}, indent=2) + '\n')
print(f'{len(checks)} conveyor construction/path/direction/lifetime checks passed.')
