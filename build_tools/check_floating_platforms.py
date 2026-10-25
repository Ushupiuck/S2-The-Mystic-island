#!/usr/bin/env python3
"""Exercise assembled ordinary-platform motion, settings, riders and lifetimes.

Optional --s3-source assembles the pinned upstream movement routines unchanged
into an isolated ROM region and compares trajectories instruction by instruction.
The source and generated probe remain outside the checked-in project assets.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

import native_test_core as c
from object_layout import decode


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom', type=Path)
    p.add_argument('--listing', type=Path)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--s3-source', type=Path)
    p.add_argument('--before-ref')
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    m = c.Manager(args.rom, args.listing)
    obj = next(iter(m.pool()))
    checks = []

    def fixture(subtype, status=0, x=0x1800, y=0x600, zone=0):
        m.start()
        m.write('Current_Zone', zone)
        m.write('Camera_X_pos_coarse_back', x - 0x100, 2)
        m.write('Camera_Max_Y_pos', 0x1000, 2)
        m.act('OscillateNumInit')
        for field, value, size in (('code', m.s['Obj18'], 4), ('obX', x, 2),
                                   ('obY', y, 2), ('obSubtype', subtype, 2),
                                   ('obStatus', status, 1)):
            m.put(obj, field, value, size)
        m.act('Obj18', obj)
        return obj

    def tick():
        code = m.get(obj, 'code')
        label = next(n for n in ('Plat_Top', 'Plat_Full', 'Plat_FallingIntangible') if m.s[n] == code)
        m.act(label, obj)

    # Word flags, configuration bounds, direct update pointers and no global RAM
    # growth. Invalid mapping frames must never escape into the renderer.
    for shape in range(8):
        for flags in (0, 0x80, 0x100, 0x180, 0xF700, 0xF780):
            fixture((shape << 4) | flags)
            assert m.get(obj, 'obSubtype') == (shape << 4) | flags
            assert m.get(obj, 'obFrame') == (shape if shape < 2 else 0)
            assert m.get(obj, 'obActWid') == 32
            assert m.get(obj, 'code') == m.s['Plat_Full' if flags & 0x80 else 'Plat_Top']
            assert m.get(obj, 'Plat_flags') == bool(flags & 0x100)
    assert m.s['object_size'] == 0x4E and m.s['obSubtype'] == 0x2C
    checks.append('48 constructors: independent word settings, bounded frames, direct code pointers')
    debug_count = 0
    for label, zone in (('Debug_GHZ', 0), ('Debug_EHZ', 3), ('Debug_HTZ', 5)):
        cursor = m.s[label]
        count = int.from_bytes(m.cpu.mem_read(cursor, 2), 'big')
        for i in range(count):
            code, mapping, subtype, frame, pad, art = struct.unpack('>IIHBBH', bytes(m.cpu.mem_read(cursor + 2 + i * 14, 14)))
            if code == m.s['Obj18']:
                fixture(subtype, zone=zone)
                assert m.get(obj, 'obFrame') == frame, (label, subtype, frame)
                assert m.get(obj, 'obMap', 4) == mapping, (label, subtype, mapping)
                debug_count += 1
    checks.append(f'{debug_count} Debug platform entries: preview matches constructed shape')

    # Every repeating path can independently sag. Compare its unsagged position
    # to the rendered Y throughout press/release instead of assuming a flat path.
    for mode in list(range(7)) + list(range(8, 16)):
        for sag in (False, True):
            fixture(mode | (0x100 if sag else 0))
            m.put(obj, 'obStatus', 0x10)
            for i in range(16):
                m.act('OscillateNumDo')
                m.act('Plat_Move', obj)
                assert 0 <= m.get(obj, 'obY', 2) - m.get(obj, 'Plat_rawY', 2) <= 4
            assert m.get(obj, 'obY', 2) - m.get(obj, 'Plat_rawY', 2) == (4 if sag else 0)
            m.put(obj, 'obStatus', 0)
            for i in range(16):
                m.act('Plat_Move', obj)
            assert m.get(obj, 'obY', 2) == m.get(obj, 'Plat_rawY', 2)
    fixture(0x107)
    assert not m.get(obj, 'Plat_flags') & 1
    checks.append('sag press/release across 15 movement modes; trap ignores sag')

    # The full body actually blocks a player's upward movement; a one-way
    # platform lets them through. Also board and carry both players together.
    for solid in (0, 0x80):
        fixture(solid | 0x100)
        x, y = m.get(obj, 'obX', 2), m.get(obj, 'obY', 2)
        radius = 48 if solid else 8
        for player, dx in (('v_player', -4), ('v_player2', 4)):
            m.put(player, 'obX', x + dx, 2)
            m.put(player, 'obY', y - radius - 19, 2)
            m.put(player, 'obVelY', 0x100, 2)
            m.put(player, 'obStatus', 2)
        m.put(obj, 'obRender', 0x94)
        tick()
        assert m.get(obj, 'obStatus') & 0x18 == 0x18
        for i in range(20):
            tick()
        for player in ('v_player', 'v_player2'):
            assert m.get(player, 'obStatus') & 8
            assert m.get(player, 'obY', 2) == m.get(obj, 'obY', 2) - radius - 19 - bool(solid)
        fixture(solid)
        for player, dx in (('v_player', -4), ('v_player2', 4)):
            m.put(player, 'obX', 0x1800 + dx, 2)
            m.put(player, 'obY', 0x600 + radius + 14, 2)
            m.put(player, 'obVelY', -0x100, 2)
            m.put(player, 'obStatus', 2)
        m.put(obj, 'obRender', 0x94)
        tick()
        for player in ('v_player', 'v_player2'):
            assert m.get(player, 'obVelY', 2) == (0 if solid else 0xFF00), (solid, player)
    checks.append('top/full solidity: both riders board/carry; undersides differ')

    # Either rider triggers the fall, with exact 30+32 timing. Switch 0 stays
    # pressed to reproduce the former missing-RTS fall-through regression.
    for standing in (8, 0x10, 0x18):
        fixture(0x10E)
        m.put(obj, 'obStatus', standing)
        m.write('f_switch', 1)
        m.act('Plat_Move', obj)
        assert m.get(obj, 'Plat_timer', 2) == 30
        for i in range(29):
            m.act('Plat_Move', obj)
            assert m.get(obj, 'Plat_movement', 4) == m.s['Plat_FallingDelayed']
        m.act('Plat_Move', obj)
        assert m.get(obj, 'Plat_timer', 2) == 32
        assert m.get(obj, 'Plat_movement', 4) == m.s['Plat_Falling']
        for player, bit in (('v_player', 8), ('v_player2', 0x10)):
            m.put(player, 'obStatus', 8 if standing & bit else 0)
        for i in range(31):
            m.act('Plat_Move', obj)
            assert not m.get(obj, 'Plat_flags') & 2
        velocity = m.get(obj, 'obVelY', 2)
        m.act('Plat_Move', obj)
        assert m.get(obj, 'Plat_timer', 2) == 0
        assert m.get(obj, 'obStatus') & 0x18 == 0
        assert m.get(obj, 'code') == m.s['Plat_FallingIntangible']
        for player, bit in (('v_player', 8), ('v_player2', 0x10)):
            if standing & bit:
                assert m.get(player, 'obStatus') & 0xA == 2
                assert m.get(player, 'obVelY', 2) == velocity
        assert m.get(obj, 'Plat_movement', 4) == m.s['Plat_FallStep']
        for i in range(16):
            tick()
            assert m.get(obj, 'Plat_sag') == max(0, 0x3C - (i + 1) * 4)
            assert 0 <= m.get(obj, 'obY', 2) - m.get(obj, 'Plat_rawY', 2) <= 4
        assert m.get(obj, 'Plat_timer', 2) == 0
    checks.append('primary/companion/both fall: 30+32, inherited velocity, smooth sag release, no switch fall-through')

    # Switch selectors span the entire high nibble and coexist with sag/shape/
    # full solidity. A different channel cannot start movement.
    for channel in range(16):
        subtype = (channel << 12) | 0x19F
        fixture(subtype)
        m.cpu.mem_write((m.s['f_switch'] + ((channel + 1) & 15)) & 0xFFFFFF, b'\1')
        m.act('Plat_Move', obj)
        assert m.get(obj, 'Plat_timer', 2) == 0
        m.cpu.mem_write((m.s['f_switch'] + channel) & 0xFFFFFF, b'\1')
        m.act('Plat_Move', obj)
        assert m.get(obj, 'Plat_timer', 2) == 60
        for i in range(60):
            m.act('Plat_Move', obj)
        assert m.get(obj, 'Plat_movement', 4) == m.s['Plat_SwitchRise']
        for i in range(256):
            m.act('Plat_Move', obj)
        assert m.get(obj, 'Plat_rawY', 2) == 0x400
        assert m.get(obj, 'Plat_movement', 4) == m.s['Plat_Stationary']
        assert m.get(obj, 'obSubtype') == subtype
        assert m.get(obj, 'code') == m.s['Plat_Full']
    checks.append('all 16 switch channels: independent selection, 60-frame delay, 512-pixel stop')

    # The rising trap latches from either rider, accelerates only through its
    # first 128 pixels and then cruises. No sag may leak into the trajectory.
    for standing in (8, 0x10):
        fixture(0x107)
        m.put(obj, 'obStatus', standing)
        m.act('Plat_Move', obj)
        assert m.get(obj, 'Plat_state') == 1
        m.put(obj, 'obStatus', 0)
        cruise = []
        for i in range(180):
            m.act('Plat_Move', obj)
            if m.get(obj, 'Plat_rawY', 2) <= 0x580:
                cruise.append(m.get(obj, 'obVelY', 2))
            assert m.get(obj, 'obY', 2) == m.get(obj, 'Plat_rawY', 2)
        assert len(cruise) > 20 and len(set(cruise)) == 1

    from convert_s1_ss_background import kosinski_plus_decode
    def ghz4_terrain():
        chunks = kosinski_plus_decode((c.ROOT / 'mappings/128x128/GHZ.kosp').read_bytes())[0]
        layout = kosinski_plus_decode((c.ROOT / 'level/layout/GHZ_4.kosp').read_bytes())[0]
        m.cpu.mem_write(m.s['Chunk_Table'] & 0xFFFFFF, chunks)
        m.cpu.mem_write(m.s['v_lvllayout'] & 0xFFFFFF, layout)
        for label, value in (('v_colladdr1', m.s['Col_GHZ4']), ('v_colladdr2', m.s['Col_GHZ4'] + 1), ('Collision_addr', m.s['Col_GHZ4'])):
            m.write(label, value, 4)

    # Real arch terrain exercises the actual MD/CD distance executor, including
    # correction at the platform's ceiling and each selected rider's entrapment.
    fixture(7, x=0x1080, y=0x380)
    ghz4_terrain()
    m.put(obj, 'Plat_state', 1)
    m.put(obj, 'obVelY', -0x400, 2)
    stopped = False
    for i in range(60):
        m.act('Plat_Move', obj)
        if not m.get(obj, 'obVelY', 2):
            stopped = True
            break
    assert stopped and 0x318 <= m.get(obj, 'Plat_rawY', 2) <= 0x324
    for standing in (8, 0x10, 0x18):
        fixture(7, x=0x1080, y=0x380)
        ghz4_terrain()
        m.put(obj, 'Plat_state', 1)
        m.put(obj, 'obStatus', standing)
        for player in ('v_player', 'v_player2'):
            m.put(player, 'obX', 0x1080, 2)
            m.put(player, 'obY', 0x308, 2)
        m.act('Plat_Move', obj)
        assert m.get('v_player', 'obRoutine') == (6 if standing & 8 else 2)
        assert m.get('v_player2', 'obRoutine') == (6 if standing & 0x10 else 2)
    checks.append('rising trap: either-rider latch, acceleration cap, real GHZ4 ceiling stop and both crush checks')

    # Long paths stay alive at their distant endpoint and release actual
    # placement ownership on unload, allowing a clean subsequent reload.
    for phase in (0, 0x200):
        rows = [(0x1800, 0x8600, 0x18, 0xC | phase)]
        m.fixture(rows)
        m.cam(0x1700, 0x600)
        m.act('ObjectsManager')
        current = next(iter(m.live().values()))
        assert current == obj
        m.act('Obj18', obj)
        handle = m.get(obj, 'respawn_addr', 2)
        right = 0x1880 if phase else 0x1900
        m.write('Camera_X_pos_coarse_back', right, 2)
        tick()
        assert m.get(obj, 'code')
        m.write('Camera_X_pos_coarse_back', right + 0x80, 2)
        tick()
        assert not m.get(obj, 'code') and not m.placement_read(handle - m.respawn_base)
        m.cam(0x2100, 0x600)
        m.act('ObjectsManager')
        m.cam(0x1700, 0x600)
        m.act('ObjectsManager')
        assert len(m.live()) == 1
    checks.append('both long-path phases: extended lifetime, respawn release and reload')

    if args.before_ref:
        migrated = 0
        mapping = {0: 0, 1: 2, 2: 4, 3: 14, 5: 2, 6: 4, 9: 0, 10: 3, 11: 3, 12: 13, 13: 13}
        for path in (c.ROOT / 'level/objects').glob('*.bin'):
            old = decode(subprocess.check_output(['git', 'show', args.before_ref + ':level/objects/' + path.name], cwd=c.ROOT))
            expected = []
            for x, y, oid, era, subtype in old:
                if oid == 0x18:
                    mode = subtype & 15
                    phase = int(mode in (5, 6, 11, 13)) ^ ((y >> 13) & 3)
                    subtype = (subtype & 0xF0) | 0x100 | (phase << 9) | mapping[mode]
                    if mode in (1, 5): x -= 64
                    migrated += 1
                expected.append((x, y, oid, era, subtype))
            actual = decode(path.read_bytes())
            if path.name == 'GHZ_4.bin':
                # This task also restores the matching Act-3 loop swappers.
                actual = [row for row in actual if row[2] != 3]
            assert actual == sorted(expected, key=lambda r: r[0]), path
        checks.append(f'{migrated} migrated platforms: original travel areas, phases, settings and era flags')

    if args.s3_source:
        checks.extend(compare_upstream(m, obj, fixture, args))
    result = {'mode1': bool(m.s['MegaCDMode1']), 'checks': checks}
    (args.output / 'native.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))


def compare_upstream(m, obj, fixture, args):
    raw = args.s3_source.read_bytes()
    blob = hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()
    assert blob == '0f10a373ff0e3d5c0033ed7d13c678bcb927c7b0', 'Use pinned skdisasm 73de97c6'
    source = raw.decode()
    def block(first, last):
        return source[source.index('\n' + first + ':') + 1:source.index('\n' + last + ':')]
    origin, reference = 0x3C0000, 0xFF7000
    assert (args.rom or c.ROOT / 's2built.bin').stat().st_size <= origin, 'Reference probe overlaps the game ROM'
    # An unused results-card SST supplies absolute-short-addressable scratch.
    oscillators = (m.s['v_objspace'] + m.s['object_size'] * 16) & 0xFFFFFF
    header = f'''\tcpu 68000
\torg ${origin:X}
bytesToWcnt function n,(n/2)-1
bytesToLcnt function n,(n/4)-1
Oscillating_table equ -${0x1000000 - oscillators:X}
Oscillating_table_end equ Oscillating_table+66
Competition_mode equ -$1000
Player_1 equ -${0x1000000 - (m.s['v_player'] & 0xFFFFFF):X}
routine equ $24
x_pos equ $10
y_pos equ $14
status equ $2A
'''
    selected = '\n'.join((block('Platform_Horizontal64', 'Platform_DiagonalLift'),
                           block('Platform_Horizontal256', 'Platform_FallingDelayed'),
                           block('Platform_Square32', 'Map_LBZMovingPlatform'),
                           block('OscillateNumInit', 'ChangeRingFrame')))
    path = args.output / 's3-reference.asm'
    path.write_text(header + selected)
    asl = c.ROOT / 'build_tools/Linux-x86_64/asl'
    converter = c.ROOT / 'build_tools/Linux-x86_64/p2bin'
    subprocess.run([str(asl), '-xx', '-n', '-q', '-A', '-L', '-U', '-E', '-i', '.', str(path)], check=True)
    subprocess.run([str(converter), str(path.with_suffix('.p')), str(path.with_suffix('.bin'))], check=True)
    listing = path.with_suffix('.lst').read_text()
    symbols = {n: int(v, 16) for n, v in re.findall(r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', listing)}
    m.s.update({'Ref_' + n: v for n, v in symbols.items()})
    m.cpu.mem_write(origin, path.with_suffix('.bin').read_bytes()[origin:])
    pairs = [(1, 'Horizontal64'), (2, 'Horizontal128'), (3, 'Vertical64'),
             (4, 'Vertical128'), (5, 'DiagonalUp'), (6, 'DiagonalDown'),
             (8, 'Square32'), (9, 'Square96'), (10, 'Square160'),
             (11, 'Square224'), (12, 'Horizontal256')]
    samples = 0
    for mode, name in pairs:
        for phase in range(4):
            fixture(mode | (phase << 9))
            m.cpu.mem_write(reference, bytes(0x50))
            m.cpu.mem_write(reference + 0x30, struct.pack('>H', 0x1800))
            m.cpu.mem_write(reference + 0x34, struct.pack('>H', 0x600))
            m.cpu.mem_write(reference + 0x2A, bytes((phase,)))
            m.cpu.mem_write(reference + 0x2E, bytes((m.get(obj, 'Plat_phase'),)))
            m.cpu.mem_write(reference + 0x36, struct.pack('>H', m.get(obj, 'Plat_position', 2)))
            m.cpu.mem_write(reference + 0x40, struct.pack('>H', m.get(obj, 'Plat_speed', 2)))
            m.cpu.mem_write(reference + 0x3C, bytes((m.get(obj, 'Plat_state'),)))
            m.act('Ref_OscillateNumInit')
            for tick in range(1024):
                # S3&K's used oscillator profiles are identical to these rows
                # of the shared engine table. Unrelated rows are intentionally
                # not changed by the object port.
                m.act('OscillateNumDo')
                m.act('Ref_OscillateNumDo')
                own = bytes(m.cpu.mem_read(m.s['v_oscillate'] & 0xFFFFFF, 66))
                ref = bytes(m.cpu.mem_read(oscillators & 0xFFFFFF, 66))
                for row in (2, 3, 7, 10, 11, 12, 13):
                    off = 2 + row * 4
                    assert own[off:off+4] == ref[off:off+4], (row, tick)
                m.act('Plat_Move', obj)
                m.act('Ref_Platform_' + name, reference)
                rx = int.from_bytes(m.cpu.mem_read(reference + 0x10, 2), 'big')
                ry = int.from_bytes(m.cpu.mem_read(reference + 0x14, 2), 'big')
                if name.startswith('Horizontal'):
                    ry = 0x600
                elif name.startswith('Vertical'):
                    # S1 centred/downward convention, same S3 oscillator.
                    half = 32 if mode == 3 else 64
                    ry = (2 * 0x600 - ry - half) & 65535
                    rx = 0x1800
                assert (m.get(obj, 'obX', 2), m.get(obj, 'Plat_rawY', 2)) == (rx, ry), (name, phase, tick)
                samples += 1
    return [f'{samples} motion samples against unchanged assembled S3&K source; seven oscillator profiles match']


if __name__ == '__main__':
    main()
