#!/usr/bin/env python3
"""Check GHZ deployment, original timed flight, hits, breakup and explosions.

Native fixtures execute the built 68000 routines with drawing/audio boundaries
stubbed. --core additionally enters GHZ3 and lands eight real collision hits,
then observes the rendered breakup, explosions, escape and capsule. Player
positioning is a fixture; this is not a controller-only playthrough.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import platform
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def signed(value, bits=16):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def s1_patrol_steps():
    # Upstream decrements before moving: $7F gives 127 quarter-pixel steps,
    # $3F gives 63 full-pixel steps. The turn plus wait occupy 65 still frames.
    steps = [-0x4000] * 127
    for direction in (1, -1) * 4:
        steps += [0] * 65 + [direction * 0x10000] * 63
    return steps


def s1_reference_motion(args):
    """Execute upstream movement instructions, with only allocation/hits omitted.

    The reference keeps its own BossMove, CalcSine/table and pendulum positioning.
    Field aliases adapt its scratch layout; none of its movement instructions or
    timers are rewritten. Deployment intentionally differs, so compare the chain
    only once our faster staged drop has finished.
    """
    from native_test_core import Manager, UC_M68K_REG_D0
    original = args.s1disasm / '_incObj'
    ship = (original / '3D, 48 Boss - GHZ Main and Wrecking Ball.asm').read_text()
    swing = (original / '15 Swinging Platforms.asm').read_text()
    move = (original / 'sub BossDefeated & BossMove.asm').read_text()
    sine = (original / 'sub CalcSine.asm').read_text()
    actual, reference = (Manager(args.rom, args.listing) for _ in range(2))
    s = actual.s
    aliases = {name: s[name] for name in (
        'obX', 'obY', 'obVelX', 'obVelY', 'obStatus', 'ob2ndRout', 'obAngle',
        'boss_ghz_x', 'boss_ghz_y')}
    aliases.update(obBossX=s['BGHZ_BaseX'], obBossY=s['BGHZ_BaseY'],
                   BGHZ_BossGenericTimer=s['BGHZ_Timer'],
                   BGHZ_SineCounter=s['BGHZ_BobAngle'], BGHZ_ParentObj=0x38,
                   obID=0, id_BossBall=0x48, status_xflip_bit=0,
                   swing_children=0x2E, swing_origX=0x38, swing_origY=0x3A,
                   swing_radius=0x3C, GBall_Swing_Direction=0x40,
                   GBall_Swing_Speed=0x42, object_size_bits=6, v_objspace=0xFF0200)
    begin = ship.index('\nBGHZ_ShipStart:')
    end = ship.index('\t\tcmpi.b\t#8,ob2ndRout(a0)', begin)
    bob = ship[begin:end] + '\t\trts\n'
    flight = ship[ship.index('\nBGHZ_MakeBall:'):ship.index('\nBGHZ_Explode:')]
    # _move is upstream's optional instruction-encoding macro, not game logic.
    flight = flight.replace('_move.b', 'move.b')
    pendulum = swing[swing.index('\nGBall_Move:'):swing.index('\nSwing_ChkDel:')]
    source = ['\tCPU 68000', f'\tinclude "{(ROOT / "_definitions/s2.macrosetup.asm").as_posix()}"',
              '\t!org 0', '\tphase $300000']
    source += [f'{name} equ ${value:X}' for name, value in aliases.items()]
    source += ['Ref_Step:', '\tmoveq #0,d0', '\tmove.b ob2ndRout(a0),d0',
               '\tmove.w Ref_Index(pc,d0.w),d1', '\tjsr Ref_Index(pc,d1.w)', '\trts',
               'Ref_Index:', '\tdc.w BGHZ_ShipStart-Ref_Index,BGHZ_MakeBall-Ref_Index',
               '\tdc.w BGHZ_ShipMove-Ref_Index,BGHZ_ChgDir-Ref_Index',
               bob, flight, move[move.index('\nBossMove:'):], pendulum, sine,
               'FindNextFreeObj:', '\tmovea.l #$FF0180,a1', '\tmoveq #0,d0',
               '\trts', '\tdephase']
    asm = args.output.resolve() / 's1-motion-reference.asm'
    asm.write_text('\n'.join(source) + '\n')
    win = platform.system() == 'Windows'
    tools = ROOT / 'build_tools' / ('Windows-x86' if win else 'Linux-' + platform.machine())
    for command in (
            [str(tools / ('asw.exe' if win else 'asl')), '-xx', '-n', '-q', '-A', '-L', '-U', str(asm)],
            [str(tools / ('p2bin.exe' if win else 'p2bin')), '-p=FF', str(asm.with_suffix('.p')),
             str(asm.with_suffix('.bin'))]):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr
    labels = {name: int(value, 16) for name, value in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', asm.with_suffix('.lst').read_text())}
    reference.s.update(labels)
    reference.cpu.mem_write(0x300000, asm.with_suffix('.bin').read_bytes())
    for machine in (actual, reference):
        machine.cpu.mem_write(s['DisplaySprite'], bytes.fromhex('4E75'))
        machine.start()
    pool = list(actual.pool())
    body, ref_body, ref_root = pool[0], 0xFF0100, 0xFF0200
    actual.put(body, 'code', s['Obj3D'])
    for machine, obj in ((actual, body), (reference, ref_body)):
        machine.put(obj, 'obX', s['boss_ghz_x'] + 0x100, 2)
        machine.put(obj, 'obY', s['boss_ghz_y'] - 0x80, 2)
    reference.put(ref_body, 'BGHZ_BaseX', (s['boss_ghz_x'] + 0x100) << 16, 4)
    reference.put(ref_body, 'BGHZ_BaseY', (s['boss_ghz_y'] - 0x80) << 16, 4)
    reference.put(ref_root, 'obAngle', 0x4080, 2)
    reference.put(ref_root, 'GBall_SwingVelocity', -0x200, 2)
    reference.cpu.mem_write(ref_root + 0x2E, bytes((5, 0, 1, 2, 3, 4, 5)))
    for index, radius in enumerate((0, 16, 32, 48, 64, 96)):
        reference.cpu.mem_write(ref_root + index * 64 + 0x3C, bytes((radius,)))
    fields = (('BGHZ_BaseX', 4), ('BGHZ_BaseY', 4), ('obX', 2), ('obY', 2),
              ('obVelX', 2), ('obVelY', 2), ('BGHZ_Timer', 2), ('ob2ndRout', 1),
              ('obStatus', 1), ('BGHZ_BobAngle', 1))
    started, trace = False, []
    for tick in range(2400):
        for obj in pool:
            code = actual.get(obj, 'code')
            if code in (s['Obj3D'], s['Obj48']):
                actual.act('Obj3D' if code == s['Obj3D'] else 'Obj48', obj)
        reference.act('Ref_Step', ref_body)
        expected = {field: reference.get(ref_body, field, size) for field, size in fields}
        observed = {field: actual.get(body, field, size) for field, size in fields}
        assert observed == expected, ('S1 flight differs', tick, observed, expected)
        reference.cpu.mem_write(ref_root + 0x38, struct.pack('>HH',
            expected['obX'], expected['obY'] + 32))
        if started:
            reference.act('GBall_Move', ref_root)
        else:
            reference.act('Swing_UpdateSwingPosition', ref_root,
                          {UC_M68K_REG_D0: reference.get(ref_root, 'obAngle', 2) >> 8})
            started = expected['ob2ndRout'] == 6
        roots = [a for a in pool if actual.get(a, 'code') == s['Obj48']]
        if roots and actual.get(body, 'BGHZ_WeaponReady'):
            root = roots[0]
            for field, size in (('obAngle', 2), ('GBall_SwingVelocity', 2),
                                ('GBall_SwingDirection', 1)):
                assert actual.get(root, field, size) == reference.get(ref_root, field, size), (
                    'S1 pendulum differs', tick, field)
            for index, piece in enumerate(roots):
                for field in ('obX', 'obY'):
                    assert actual.get(piece, field, 2) == reference.get(ref_root + index * 64, field, 2), (
                        'S1 chain position differs', tick, index, field)
        trace.append(expected)
    (args.output / 's1-motion-trace.json').write_text(json.dumps(trace) + '\n')
    return '2400 frames match assembled S1 flight/bob/pendulum instructions and every fully deployed chain piece'


def wall_checks(m, pool, rom):
    from native_test_core import UC_M68K_REG_D0
    from check_sprite_assets import frames
    s = m.s
    m.start()
    m.act('LoadPLC', regs={UC_M68K_REG_D0: s['plcid_ExplosionWall']})
    plc = s['PLC_ExplosionWall']
    count = struct.unpack_from('>h', rom, plc)[0] + 1
    assert count == 2
    assert bytes(m.cpu.mem_read(s['v_plc_buffer'] & 0xFFFFFF, count * 6)) == rom[plc + 2:plc + 2 + count * 6]
    banks = []
    for i, mapping in enumerate(('Map_BossExplosion', 'Map_Explosion')):
        source, low = struct.unpack_from('>IH', rom, plc + 2 + i * 6)
        tiles = struct.unpack_from('>H', rom, source)[0] & 0x7FFF
        high = low + tiles * 32
        assert all(high <= a or low >= b for a, b in banks)
        assert high <= s['ArtTile_Shield_2'] * 32 or low >= s['ArtTile_Shield_2_End'] * 32
        assert high <= s['vram_fg']
        for frame in frames(rom, s[mapping]):
            for _, size, tile, _ in frame:
                first = tile & 0x7FF
                assert first + ((size >> 2) + 1) * ((size & 3) + 1) <= tiles
        banks.append((low, high))
    assert banks[1][0] == s['ArtTile_ExplosionWall_Small'] * 32

    # A parent at the final SST can reserve four earlier fragmented slots.
    m.start()
    wall = pool[-1]
    for a in pool:
        m.put(a, 'code', 0x123456)
    m.put(wall, 'code', s['BossExplosion_Wall'])
    for a in pool[:6:2]:
        m.put(a, 'code', 0)
    before = bytes(m.cpu.mem_read(pool[0] & 0xFFFFFF, s['v_lvlobjend'] - pool[0]))
    m.act('BossExplosion_Wall', wall)
    assert bytes(m.cpu.mem_read(pool[0] & 0xFFFFFF, len(before))) == before
    m.put(pool[7], 'code', 0)
    m.cam(0, 200)  # also exercise a negative starting X near the level origin
    m.act('BossExplosion_Wall', wall)
    assert m.get(wall, 'obRoutine') == 2
    assert signed(m.get(wall, 'obX', 2)) == -128
    assert m.get(wall, 'obY', 2) == 328
    kinds = ('BossExplosion_Controller', 'BossExplosion_NormalController')
    emitters = {a: next((k for k in kinds if m.get(a, 'code') == s[k]), None) for a in pool}
    emitters = {a: k for a, k in emitters.items() if k}
    assert Counter(emitters.values()) == dict.fromkeys(kinds, 2)
    for a in pool:
        if a != wall and a not in emitters:
            m.put(a, 'code', 0)
    emitted = Counter()
    for tick in range(390):
        m.cam(tick * 2, 200)
        m.act('BossExplosion_Wall', wall)
        assert signed(m.get(wall, 'obX', 2) - tick * 2) == -126
        for control, kind in emitters.items():
            if not m.get(control, 'code'):
                continue
            m.act(kind, control)
            visual = 'BossExplosion' if kind == kinds[0] else 'BossExplosion_Small'
            for a in pool:
                if m.get(a, 'code') != s[visual]:
                    continue
                assert tick % 3 == 0
                assert -128 <= signed(m.get(a, 'obX', 2) - m.get(wall, 'obX', 2)) < 128
                assert -128 <= signed(m.get(a, 'obY', 2) - m.get(wall, 'obY', 2)) < 128
                emitted[control] += 1
                m.act('DeleteObject', a)
    assert all(emitted[a] == (130 if k == kinds[0] else 127) for a, k in emitters.items())
    for _ in range(129):
        m.act('BossExplosion_Wall', wall)
        if not m.get(wall, 'code'):
            break
    assert not m.get(wall, 'code')
    for a, kind in emitters.items():
        if m.get(a, 'code'):
            m.act(kind, a)
        assert not m.get(a, 'code')

    m.start()
    m.put(wall, 'code', s['BossExplosion_Wall'])
    m.act('BossExplosion_Wall', wall)
    m.put(wall, 'code', s['Obj26'])
    before = bytes(m.cpu.mem_read(wall & 0xFFFFFF, s['object_size']))
    for a in pool[:-1]:
        if m.get(a, 'code') in (s[kinds[0]], s[kinds[1]]):
            m.act(next(k for k in kinds if m.get(a, 'code') == s[k]), a)
            assert not m.get(a, 'code')
    assert bytes(m.cpu.mem_read(wall & 0xFFFFFF, s['object_size'])) == before
    small = pool[0]
    m.put(small, 'code', s['BossExplosion_Small'])
    seen = []
    for _ in range(40):
        m.act('BossExplosion_Small', small)
        if not m.get(small, 'code'):
            break
        seen.append(m.get(small, 'obFrame'))
    assert Counter(seen) == dict(enumerate((3, 8, 8, 8, 8)))
    return 'callable mixed wall: PLC banks, full-pool retry, moving camera/origin, 4 emitters, cadence, finite/continuous counts and cleanup'


def native_checks(args):
    from native_test_core import (Manager, UC_M68K_REG_A0, UC_M68K_REG_A1,
                                  UC_M68K_REG_A4, UC_M68K_REG_A7,
                                  UC_M68K_REG_D0, UC_M68K_REG_PC, UC_M68K_REG_SR)
    from unicorn import UC_HOOK_CODE
    m = Manager(args.rom, args.listing)
    s = m.s
    # Rendering is exercised by the optional full-core pass below.
    m.cpu.mem_write(s['DisplaySprite'], bytes.fromhex('4E75'))
    pool = list(m.pool())
    body = pool[0]
    results = []
    if args.s1disasm:
        results.append(s1_reference_motion(args))

    def palette(value=None):
        address = (s['v_palette'] + 0x22) & 0xFFFFFF
        if value is not None:
            m.cpu.mem_write(address, value.to_bytes(2, 'big'))
        return int.from_bytes(m.cpu.mem_read(address, 2), 'big')

    def start():
        m.start()
        m.cam(s['boss_ghz_x'], s['boss_ghz_y'])
        m.put(body, 'code', s['Obj3D'])
        m.put(body, 'obX', s['boss_ghz_x'] + 0x100, 2)
        m.put(body, 'obY', s['boss_ghz_y'] - 0x80, 2)

    def parts(code):
        return [a for a in pool if m.get(a, 'code') == s[code]]

    def frame():
        for a in pool:
            label = {s[name]: name for name in (
                'Obj3D', 'Obj48', 'BossExplosion_Controller', 'BossExplosion')}.get(m.get(a, 'code'))
            if label:
                m.act(label, a)

    def fill(first=1):
        for a in pool[first:]:
            m.put(a, 'code', 0x123456)

    # The wall deliberately borrows surface tiles in dry acts. Exercise the
    # actual level-entry selection so later water changes cannot silently alias.
    start()
    wall = s['ArtTile_GHZ_SLZ_Smashable_Wall']
    surface = s['ArtTile_Water_Surface']
    for act in range(s['ActsPerZone']):
        m.write('Current_ZoneAndAct', s['id_GHZ'] * 256 + act, 2)
        m.cpu.emu_start(s['Level_WaterFlagInit'], s['Level_WaterFlagInit_End'], count=10000)
        assert m.cpu.reg_read(UC_M68K_REG_PC) == s['Level_WaterFlagInit_End']
        assert not m.read('Water_flag') or wall + 12 <= surface or wall >= surface + 16
    results.append('dry-act wall borrowing agrees with actual water selection in all GHZ acts')

    # Pool exhaustion must preserve initialization and retry at the same anchor.
    start()
    fill()
    m.put(pool[1], 'code', 0)
    m.act('Obj3D', body)
    assert m.get(body, 'obRoutine') == 0 and parts('Obj3D') == [body]
    m.put(pool[3], 'code', 0)
    m.act('Obj3D', body)
    assert len(parts('Obj3D')) == 3
    m.put(body, 'ob2ndRout', s['BGHZ_Approach'])
    m.put(body, 'BGHZ_BaseX', s['BGHZ_CenterX'] << 16, 4)
    for _ in range(5):
        m.act('Obj3D', body)
        assert m.get(body, 'ob2ndRout') == s['BGHZ_Approach']
        assert m.get(body, 'BGHZ_BaseX', 2) == s['BGHZ_CenterX']
    m.put(pool[4], 'code', 0)
    m.act('Obj3D', body)
    root = parts('Obj48')[0]
    for a in pool[5:9]:
        m.put(a, 'code', 0)
    m.act('Obj48', root)
    assert m.get(root, 'obRoutine') == 0 and parts('Obj48') == [root]
    for _ in range(180):
        m.act('Obj3D', body)
        m.act('Obj48', root)
        assert m.get(body, 'ob2ndRout') == s['BGHZ_Deploy']
        assert m.get(body, 'BGHZ_BaseX', 2) == s['BGHZ_CenterX']
        assert not m.get(body, 'obVelX', 2)
    assert m.get(body, 'BGHZ_Timer', 2) == 0  # no signed-timer wrap while allocation retries
    m.put(pool[-1], 'code', 0)
    m.act('Obj48', root)
    assert len(parts('Obj48')) == 6 and m.get(root, 'obRoutine') == 2
    for _ in range(65):
        frame()
        if m.get(body, 'ob2ndRout') == s['BGHZ_Patrol']:
            break
    else:
        raise AssertionError('Ship did not resume after delayed chain allocation')
    assert m.get(root, 'obAngle', 2) == 0x4080
    assert m.get(body, 'BGHZ_Timer', 2) == 127
    results.append('full/fragmented pools retry without partial ship/chain, timer wrap or an early pass')

    # End-of-pool parents must not read/write beyond the dynamic SST allocation.
    start()
    last = pool[-1]
    m.put(last, 'code', s['Obj3D'])
    m.act('Obj3D', last)
    assert m.get(last, 'obRoutine') == 0
    results.append('initialization at final SST remains pending')

    start()
    for tick in range(500):
        frame()
        if m.get(body, 'ob2ndRout') == s['BGHZ_Deploy']:
            break
    else:
        raise AssertionError('Weapon never spawned')
    root, *children = parts('Obj48')
    previous = {a: 0 for a in (root, *children)}
    opening_wait = 0
    while not m.get(body, 'BGHZ_WeaponReady'):
        for a in previous:
            distance = m.get(a, 'GBall_Distance', 2)
            assert distance - previous[a] in (0, 2)
            assert m.get(a, 'obX', 2) == m.get(body, 'obX', 2)
            assert m.get(a, 'obY', 2) - m.get(body, 'obY', 2) == distance
            previous[a] = distance
        frame()
        opening_wait += 1
        assert opening_wait <= 120, 'Weapon deployment stalled'
    assert [m.get(a, 'GBall_Distance', 2) for a in children] == [16, 32, 48, 64, 96]
    assert m.get(root, 'obY', 2) - m.get(body, 'obY', 2) == 32
    assert m.get(children[-1], 'obY', 2) - m.get(body, 'obY', 2) == 128
    while m.get(body, 'ob2ndRout') != s['BGHZ_Patrol']:
        assert m.get(root, 'obAngle', 2) == 0x4080, 'Pendulum started before the first pass'
        frame()
        opening_wait += 1
        assert opening_wait <= 120, 'Opening pause stalled'
    assert opening_wait == 120 and m.get(body, 'BGHZ_Timer', 2) == 127
    assert m.get(root, 'obAngle', 2) == 0x4080
    previous_x = m.get(body, 'BGHZ_BaseX', 4)
    for step in s1_patrol_steps():
        frame()
        fixed_x = m.get(body, 'BGHZ_BaseX', 4)
        assert fixed_x - previous_x == step, ('S1 timed pass differs', fixed_x, previous_x, step)
        previous_x = fixed_x
        x = m.get(body, 'obX', 2)
        assert s['BGHZ_CenterX'] - 32 <= x <= s['BGHZ_CenterX'] + 31
        assert m.get(root, 'obX', 2) == x
        assert m.get(root, 'obY', 2) == m.get(body, 'obY', 2) + 32
    results.append('staged drop, original 120-frame opening, quarter-speed first pass and eight timed return sweeps')

    # A recycled child slot is never repositioned by its old root.
    reused = children[1]
    m.put(reused, 'code', s['Obj26'])
    before = bytes(m.cpu.mem_read(reused & 0xFFFFFF, s['object_size']))
    m.act('Obj48', root)
    assert bytes(m.cpu.mem_read(reused & 0xFFFFFF, s['object_size'])) == before
    m.put(reused, 'code', s['Obj48'])
    results.append('chain positioning ignores a recycled SST')

    # Actual damage response, exact palette restoration, and one defeat award.
    for color in (0x222, 0x444, 0x866):
        palette(color)
        m.put(body, 'obColProp', 8)
        m.put('v_player', 'obAnim', s['AniIDSonAni_Roll'])
        m.act('Touch_Enemy', 'v_player', {UC_M68K_REG_A1: body})
        assert m.get(body, 'obColProp') == 7 and not m.get(body, 'obColType')
        observed = set()
        for _ in range(32):
            m.act('Obj3D', body)
            observed.add(palette())
        assert observed == {color, s['cWhite']}
        assert palette() == color
        assert m.get(body, 'obColType') == 0xF
    m.put(body, 'obColProp', 1)
    m.act('Touch_Enemy', 'v_player', {UC_M68K_REG_A1: body})
    score = m.read('v_score', 4)
    frame()
    assert m.get(body, 'ob2ndRout') == s['BGHZ_Explode']
    assert m.read('v_score', 4) == score + 100
    debris = parts('Obj48')
    assert len(debris) == 6
    for a in debris:
        assert m.get(a, 'obRoutine') != s['GBall_DebrisRoutine']
        assert not m.get(a, 'obColType')
    assert not parts('BossExplosion')
    first_burst = None
    for tick in range(1, 70):
        frame()
        if parts('BossExplosion') and first_burst is None:
            first_burst = tick
        detached = [m.get(a, 'obRoutine') == s['GBall_DebrisRoutine'] for a in debris]
        assert len(set(detached)) == 1, 'Chain pieces must release together'
        assert all(not m.get(a, 'obColType') for a in debris)
        if all(detached):
            assert first_burst is not None and tick - first_burst == 64
            assert m.get(body, 'BGHZ_BreakTimer') == 64
            break
        assert m.get(debris[0], 'obX', 2) == m.get(body, 'obX', 2)
        assert m.get(debris[0], 'obY', 2) == m.get(body, 'obY', 2) + 32
    else:
        raise AssertionError('Chain did not break after its explosion delay')
    # Deleting the ship cannot stop already detached debris. Test each visible
    # and invisible frame against its previous velocity, including fractions.
    m.put(body, 'code', 0)
    for _ in range(12):
        for a in debris:
            x, y = m.get(a, 'obX', 4), m.get(a, 'obY', 4)
            vx, vy = signed(m.get(a, 'obVelX', 2)), signed(m.get(a, 'obVelY', 2))
            m.act('Obj48', a)
            assert m.get(a, 'code') == s['Obj48']
            assert m.get(a, 'obX', 4) == (x + vx * 256) & 0xFFFFFFFF
            assert m.get(a, 'obY', 4) == (y + vy * 256) & 0xFFFFFFFF
            assert signed(m.get(a, 'obVelY', 2)) == vy + 0x38
    for _ in range(160):
        for a in debris:
            if m.get(a, 'code') == s['Obj48']:
                m.act('Obj48', a)
    assert all(not m.get(a, 'code') for a in debris)
    for a in parts('Obj3D'):
        m.act('Obj3D', a)
        assert not m.get(a, 'code')
    results.append('hit restoration, one score award, independent full-speed debris and cleanup')

    # A controller with no free visual slot must not start the breakup clock.
    start()
    for _ in range(500):
        frame()
        if m.get(body, 'ob2ndRout') == s['BGHZ_Patrol']:
            break
    else:
        raise AssertionError('Weapon never became ready')
    weapon = parts('Obj48')
    for a in pool:
        if not m.get(a, 'code'):
            m.put(a, 'code', 0x123456)
    m.put(body, 'obColProp', 1)
    m.put('v_player', 'obAnim', s['AniIDSonAni_Roll'])
    m.act('Touch_Enemy', 'v_player', {UC_M68K_REG_A1: body})
    for _ in range(10):
        frame()
    assert not m.get(body, 'BossBurst_Started')
    m.put(pool[-1], 'code', 0)
    for _ in range(20):
        frame()
    assert m.get(body, 'BossBurst_Started') == 1
    assert not m.get(body, 'BGHZ_BreakTimer')
    assert all(not m.get(a, 'obColType') and
               m.get(a, 'obRoutine') != s['GBall_DebrisRoutine'] for a in weapon)
    m.put(pool[-2], 'code', 0)
    for _ in range(3):  # wait for the controller's next scheduled burst attempt
        frame()
        if m.get(body, 'BossBurst_Started') & 0x80:
            break
    assert m.get(body, 'BossBurst_Started') & 0x80
    for _ in range(64):
        frame()
    assert all(m.get(a, 'obRoutine') == s['GBall_DebrisRoutine'] for a in weapon)
    results.append('harmless attached chain waits for an actual burst under a full pool, then releases after 64 boss updates')

    # Recovery clears the old defeated bit; pending pieces must still retire.
    start()
    m.act('Obj3D', body)
    m.put(body, 'ob2ndRout', s['BGHZ_Approach'])
    m.put(body, 'BGHZ_BaseX', s['BGHZ_CenterX'] << 16, 4)
    m.act('Obj3D', body)
    root = parts('Obj48')[0]
    m.act('Obj48', root)
    weapon = parts('Obj48')
    assert len(weapon) == 6
    m.put(body, 'ob2ndRout', s['BGHZ_Recover'])
    assert not m.get(body, 'BossBurst_Started')
    for a in weapon:
        m.act('Obj48', a)
        assert m.get(a, 'obRoutine') == s['GBall_DebrisRoutine']
        assert not m.get(a, 'obColType')
    results.append('recovery releases pending parts even without a burst or the defeated bit')

    # Both boss profiles use the imported three-frame burst scheduler.
    for profile, parent_code, phase in (('GHZ', 'Obj3D', s['BGHZ_Explode']),
                                         ('EHZ', 'EHZBoss', 6)):
        start()
        m.put(body, 'code', s[parent_code])
        m.put(body, 'obRoutine', 2)
        m.put(body, 'ob2ndRout', phase)
        fill()
        m.act('BossExplosion_Start', body, {UC_M68K_REG_D0: s['BossExplosion_' + profile]})
        assert not m.get(body, 'BossBurst_Started')
        m.put(pool[-1], 'code', 0)
        m.act('BossExplosion_Start', body, {UC_M68K_REG_D0: s['BossExplosion_' + profile]})
        control = parts('BossExplosion_Controller')[0]
        for a in pool[1:-1]:
            m.put(a, 'code', 0)
        for _ in range(4):
            m.act('BossExplosion_Start', body, {UC_M68K_REG_D0: s['BossExplosion_' + profile]})
        assert parts('BossExplosion_Controller') == [control]
        offsets, ticks = [], []
        for tick in range(180):
            m.put(body, 'obX', 600 + tick, 2)
            m.put(body, 'obY', 200, 2)
            m.act('BossExplosion_Controller', control)
            for a in parts('BossExplosion'):
                offsets.append((signed(m.get(a, 'obX', 2) - 600 - tick),
                                signed(m.get(a, 'obY', 2) - 200)))
                ticks.append(tick)
                m.act('DeleteObject', a)
        assert ticks == list(range(0, 180, 3))
        assert all(-32 <= x < 32 and -32 <= y < 32 for x, y in offsets)
        assert all(any(p[axis] < 0 for p in offsets) and
                   any(p[axis] >= 0 for p in offsets) for axis in (0, 1))
        m.put(body, 'ob2ndRout', phase + 2)
        m.act('BossExplosion_Controller', control)
        assert not m.get(control, 'code')
    results.append('both burst profiles: full-pool retry, one controller, 3-frame cadence and centered RNG')

    results.append(wall_checks(m, pool, args.rom.read_bytes()))

    start()
    visual = pool[1]
    m.put(visual, 'code', s['BossExplosion'])
    frames = []
    for _ in range(30):
        m.act('BossExplosion', visual)
        if not m.get(visual, 'code'):
            break
        frames.append(m.get(visual, 'obFrame'))
    assert Counter(frames) == dict(enumerate((2, 2, 3, 3, 3, 4, 4)))
    assert len(frames) == 21 and not m.get(visual, 'code')
    assert s['Map_BossExplosion_frames'] == 7
    art = (ROOT / 'art/uncompressed/Large explosion.unc').read_bytes()
    assert len(art) == 100 * 32
    m.put(visual, 'code', s['FieryExplosion'])
    for _ in range(22):
        m.act('FieryExplosion', visual)
    assert m.get(visual, 'code') == s['FieryExplosion']
    results.append('seven S2 fiery frames last 21 ticks; ordinary bomb timing stays separate')

    start()
    m.act('Obj3D', body)
    m.put(body, 'ob2ndRout', s['BGHZ_Recover'])
    m.put(body, 'BGHZ_Timer', 0x2F, 2)
    m.write('Current_ZoneAndAct', 2, 2)
    m.write('f_lockscreen', 1)
    # Give GHZ3 a deliberately different valid song in this native ROM only.
    m.cpu.mem_write(s['MusicList'] + 2, bytes((s['bgm_LZ'],)))
    played = []
    m.cpu.hook_add(UC_HOOK_CODE, lambda c, a, z, u: played.append(c.reg_read(UC_M68K_REG_D0) & 65535),
                   begin=s['PlayMusic'], end=s['PlayMusic'])
    m.act('Obj3D', body)
    assert played == [s['bgm_LZ']] and not m.read('f_lockscreen')
    results.append('escape restores the act-selected song')

    # Decode through the actual owning CPU, independently of the PLC upload.
    # The initial title-card bank is not a valid ordinary-explosion oracle.
    rom = args.rom.read_bytes()
    decoded = {}
    for label in ('Nem_Explosion', 'Nem_BossExplosion', 'Nem_Bunny', 'Nem_Flicky'):
        count = (struct.unpack_from('>H', rom, s[label])[0] & 0x7FFF) * 32
        if hasattr(m, 'sub'):
            cpu = m.sub
            source, output = s['MCD_DecompInput_Sub'], s['MCD_DecompOutput_Sub']
            cpu.mem_write(source, rom[s[label]:s[label] + 0x2000])
            stop, stack = 0x7FBF0, s['MCD_SubStack_Top'] - 4
            cpu.mem_write(stack, struct.pack('>I', stop))
            for register, value in ((UC_M68K_REG_SR, 0x2700), (UC_M68K_REG_A7, stack),
                                    (UC_M68K_REG_A0, source), (UC_M68K_REG_A4, output)):
                cpu.reg_write(register, value)
            cpu.emu_start(s['MCD_SubNemDecToRAM'], stop, count=2000000)
            assert cpu.reg_read(UC_M68K_REG_PC) == stop
        else:
            cpu, output = m.cpu, 0xFF0000
            m.act('NemDecToRAM', regs={UC_M68K_REG_A0: s[label], UC_M68K_REG_A4: output}, limit=2000000)
        decoded[label] = bytes(cpu.mem_read(output, count))
    assert decoded['Nem_BossExplosion'] == art
    results.append('owning CPU decodes boss art exactly to its editable pixel source')
    return results, decoded


def live_checks(args, decoded):
    from genesis_test_core import Genesis
    from check_object_course import boot_level, objects
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
                system_directory=args.system_directory)
    s = g.s
    boot_level(g, zone=0, act=2, player=args.player)
    g.put('v_player2', 'code', 0)
    assert not g.read('Water_flag')

    def park():
        for field, value, size in (
                ('obX', s['BGHZ_CenterX'], 2), ('obY', s['boss_ghz_y'] + 0xB0, 2),
                ('obVelX', 0, 2), ('obVelY', 0, 2), ('obInertia', 0, 2),
                ('obControl', 1, 1), ('obRoutine', 2, 1), ('flashtime', 6000, 2)):
            g.put('v_player', field, value, size)

    def valid():
        assert not g.read('v_errortype'), ('Error handler', hex(g.core.m68k_get_reg(16)))
        assert g.get('v_player', 'obRoutine') < 6, 'Player died during fixture'
        assert g.read('v_gamemode', 2) == s['Level']

    park()
    g.write('v_rings', 99, 2)
    # Let the real camera and column/row streaming catch up to the fixture.
    # A direct camera teleport leaves stale name-table columns in the arena.
    for _ in range(1500):
        g.run()
        valid()
        ships = [a for a in objects(g, 0x3D) if g.get(a, 'obRoutine') == 2]
        if ships and g.get(ships[0], 'ob2ndRout') == s['BGHZ_Patrol']:
            break
    else:
        raise AssertionError('GHZ boss did not deploy')
    body = ships[0]
    weapon = objects(g, 0x48)
    assert len(weapon) == 6
    g.video.save(args.output / 'deployed.png')
    assert g.get(body, 'BGHZ_Timer', 2) == 127
    assert g.get(body, 'BGHZ_BaseX', 4) == s['BGHZ_CenterX'] << 16
    previous_x = g.get(body, 'BGHZ_BaseX', 4)
    xs = []
    motion = []
    for tick, step in enumerate(s1_patrol_steps()):
        g.run()
        valid()
        fixed_x = g.get(body, 'BGHZ_BaseX', 4)
        assert fixed_x - previous_x == step, ('Live S1 timed pass differs', tick, fixed_x, previous_x, step)
        previous_x = fixed_x
        x = g.get(body, 'obX', 2)
        xs.append(x)
        motion.append([fixed_x, g.get(body, 'obY', 2), g.get(body, 'ob2ndRout'),
                       g.get(body, 'BGHZ_Timer', 2), g.get(body, 'obStatus')])
        if tick in (0, 126, 160, 254, 288, 382):
            g.video.save(args.output / f'flight-{tick:03}.png')
    assert min(xs) == s['BGHZ_CenterX'] - 32 and max(xs) == s['BGHZ_CenterX'] + 31
    (args.output / 'live-flight-trace.json').write_text(json.dumps(motion) + '\n')
    g.video.save(args.output / 'swing.png')
    art = (ROOT / 'art/uncompressed/Large explosion.unc').read_bytes()
    bank = s['ArtTile_BossExplosion'] * 32
    assert bytes(g.vram[(bank + i) ^ 1] for i in range(len(art))) == art

    normal = g.read(s['v_palette'] + 0x22, 2)
    score = g.read('v_score', 4)
    hits = []
    for hit in range(8):
        hp = g.get(body, 'obColProp')
        for field, value, size in (
                ('obControl', 0, 1), ('obX', g.get(body, 'obX', 2), 2),
                ('obY', g.get(body, 'obY', 2) - 24, 2), ('obVelX', 0, 2),
                ('obVelY', 0x300, 2), ('obInertia', 0, 2), ('obStatus', 6, 1),
                ('obHeight', 14, 1), ('obWidth', 7, 1),
                ('obAnim', s['AniIDSonAni_Roll'], 1), ('flashtime', 6000, 2)):
            g.put('v_player', field, value, size)
        for _ in range(8):
            g.run()
            valid()
            if g.get(body, 'obColProp') == hp - 1:
                break
        else:
            raise AssertionError(('Rolling collision missed boss', hit, hp))
        hits.append(g.get(body, 'obColProp'))
        if hit == 3:
            g.video.save(args.output / 'hit.png')
        park()
        if hit < 7:
            g.run(34)
            assert g.read(s['v_palette'] + 0x22, 2) == normal
            assert g.get(body, 'obColType') == 0xF
    assert hits == list(range(7, -1, -1))
    assert g.read('v_score', 4) == score + 100
    assert all(g.get(a, 'obRoutine') != s['GBall_DebrisRoutine'] and
               not g.get(a, 'obColType') for a in weapon)
    burst_count = 0
    first_burst = breakup = None
    for tick in range(600):
        g.run()
        valid()
        visible_bursts = [a for a in objects(g) if g.get(a, 'code') == s['BossExplosion']]
        burst_count = max(burst_count, len(visible_bursts))
        if visible_bursts and first_burst is None:
            first_burst = tick
        if breakup is None:
            detached = [g.get(a, 'obRoutine') == s['GBall_DebrisRoutine'] for a in weapon]
            assert len(set(detached)) == 1, 'Chain pieces did not release together'
            assert all(not g.get(a, 'obColType') for a in weapon)
            if all(detached):
                breakup = tick
                assert first_burst is not None and 63 <= breakup - first_burst <= 64
                assert g.get(body, 'BGHZ_BreakTimer') == 64
                g.video.save(args.output / 'chain-breakup.png')
            else:
                assert g.get(weapon[0], 'obX', 2) == g.get(body, 'obX', 2)
                assert g.get(weapon[0], 'obY', 2) == g.get(body, 'obY', 2) + 32
        if tick in (5, 13, 25, 50, 63, 65, 300):
            g.video.save(args.output / f'defeat-{tick:03}.png')
    assert first_burst is not None and breakup is not None
    assert burst_count >= 6
    assert not objects(g, 0x3D) and not objects(g, 0x48)
    assert not [a for a in objects(g) if g.get(a, 'code') in (s['BossExplosion'], s['BossExplosion_Controller'])]
    assert g.read('Boss_defeated_flag') == 1
    assert g.read('v_limitright2', 2) >= s['boss_ghz_end']
    for label, tile in (('Nem_Explosion', 'ArtTile_Explosion'),
                        ('Nem_Bunny', 'ArtTile_Animal_1'), ('Nem_Flicky', 'ArtTile_Animal_2')):
        bank = s[tile] * 32
        assert bytes(g.vram[(bank + i) ^ 1] for i in range(len(decoded[label]))) == decoded[label], label
    buttons = [a for a in objects(g, 0x3E) if g.get(a, 'obSubtype') == 1]
    assert len(buttons) == 1
    button = buttons[0]
    for field, value, size in (
            ('obControl', 0, 1), ('obX', g.get(button, 'obX', 2), 2),
            ('obY', g.get(button, 'obY', 2) - 40, 2), ('obVelX', 0, 2),
            ('obVelY', 0x100, 2), ('obInertia', 0, 2), ('obStatus', 2, 1),
            ('obHeight', g.get('v_player', 'default_y_radius'), 1),
            ('obWidth', g.get('v_player', 'default_x_radius'), 1), ('obAnim', 0, 1)):
        g.put('v_player', field, value, size)
    for _ in range(180):
        g.run()
        valid()
        if g.read('Boss_defeated_flag') == 2:
            break
    else:
        raise AssertionError('Capsule switch failed to open the prison')
    g.run(4)
    valid()
    assert any(g.get(a, 'obFrame') == 2 for a in objects(g, 0x3E)
               if g.get(a, 'obSubtype') == 0)
    assert any(g.get(a, 'code') == s['Flicky'] for a in objects(g))
    g.video.save(args.output / 'capsule-open.png')
    g.close()
    return dict(player='Tails' if args.player == 2 else 'Sonic',
                region='PAL' if args.pal else 'NTSC', hits=hits,
                patrol_frames=len(xs), maximum_simultaneous_bursts=burst_count,
                first_burst_tick=first_burst, chain_breakup_tick=breakup,
                boss_deleted=True, harmless_debris=True, capsule_open=True,
                ordinary_explosion_art_restored=True)


def live_wall_checks(args, decoded):
    from genesis_test_core import Genesis
    from check_object_course import boot_level, objects
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
                system_directory=args.system_directory)
    s = g.s
    boot_level(g, zone=s['id_EHZ'], act=0, player=args.player)
    g.put('v_player', 'obControl', 1)
    g.put('v_player2', 'code', 0)
    for _ in range(600):
        g.run()
        if not g.read('v_plc_buffer', 4) and not g.read('v_plc_patternsleft', 2):
            break
    else:
        raise AssertionError('Initial level PLCs did not finish')
    pool = range(s['v_lvlobjspace'] & 65535, s['v_lvlobjend'] & 65535, s['object_size'])
    for address in range(pool.start, pool.stop):
        g.write(address, 0)
    # Simulate a level trigger queuing the compiled PLC and creating the wall.
    # Native checks above also execute LoadPLC and verify this exact queue data.
    rom = args.rom.read_bytes()
    plc = s['PLC_ExplosionWall']
    count = struct.unpack_from('>h', rom, plc)[0] + 1
    assert not g.read('v_plc_buffer', 4)
    for i, value in enumerate(rom[plc + 2:plc + 2 + count * 6] + bytes(6)):
        g.write(s['v_plc_buffer'] + i, value)
    for _ in range(300):
        g.run()
        if not g.read('v_plc_buffer', 4) and not g.read('v_plc_patternsleft', 2):
            break
    else:
        raise AssertionError('Wall PLC did not finish')
    banks = (('Nem_BossExplosion', 'ArtTile_BossExplosion'),
             ('Nem_Explosion', 'ArtTile_ExplosionWall_Small'))

    def check_art():
        for label, tile in banks:
            bank = s[tile] * 32
            assert bytes(g.vram[(bank + i) ^ 1] for i in range(len(decoded[label]))) == decoded[label], label

    check_art()
    wall = pool[0]
    g.put(wall, 'code', s['BossExplosion_Wall'])
    maximum = dict(large=0, small=0)
    for tick in range(200):
        g.run()
        assert not g.read('v_errortype'), hex(g.core.m68k_get_reg(16))
        assert g.read('v_gamemode', 2) == s['Level']
        if tick == 2:
            assert g.get(wall, 'obRoutine') == 2
            for label in ('BossExplosion_Controller', 'BossExplosion_NormalController'):
                assert sum(g.get(a, 'code') == s[label] for a in objects(g)) == 2
        for kind, code in (('large', 'BossExplosion'), ('small', 'BossExplosion_Small')):
            bursts = [a for a in objects(g) if g.get(a, 'code') == s[code]]
            maximum[kind] = max(maximum[kind], len(bursts))
        if tick in (32, 64, 100, 128):
            check_art()
            g.video.save(args.output / f'wall-{tick:03}.png')
    assert maximum['large'] >= 10 and maximum['small'] >= 18, maximum
    codes = {s[label] for label in ('BossExplosion_Wall', 'BossExplosion_Controller',
                                   'BossExplosion_NormalController', 'BossExplosion',
                                   'BossExplosion_Small', 'Flicky')}
    assert not [a for a in objects(g) if g.get(a, 'code') in codes]
    check_art()
    g.close()
    return dict(player='Tails' if args.player == 2 else 'Sonic',
                region='PAL' if args.pal else 'NTSC', maximum_bursts=maximum,
                both_art_banks_match=True, wall_and_emitters_deleted=True,
                all_visuals_finished=True, no_animals=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--core', type=Path)
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--player', type=int, choices=(0, 2), default=0)
    p.add_argument('--s1disasm', type=Path,
                   help='Compare motion against assembled upstream S1 boss, swing, BossMove and CalcSine sources')
    p.add_argument('--explosion-wall', action='store_true',
                   help='Run the currently unplaced wall in an EHZ1 trigger fixture instead of the GHZ fight')
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results, decoded = native_checks(args)
    report = dict(native=results)
    for result in report['native']:
        print(result + ': passed', flush=True)
    if args.core:
        if args.explosion_wall:
            report['runtime'] = live_wall_checks(args, decoded)
            print('Mixed explosion wall: both sizes, live PLC loading and complete cleanup passed', flush=True)
        else:
            report['runtime'] = live_checks(args, decoded)
            print('GHZ3: eight real hits, breakup, bursts, escape and capsule passed', flush=True)
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
