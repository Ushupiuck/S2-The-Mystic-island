#!/usr/bin/env python3
"""Check GHZ deployment, continuous flight, hits, breakup and boss explosions.

Native fixtures execute the built 68000 routines with drawing/audio boundaries
stubbed. --core additionally enters GHZ3 and lands eight real collision hits,
then observes the rendered breakup, explosions, escape and capsule. Player
positioning is a fixture; this is not a controller-only playthrough.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def signed(value, bits=16):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


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
            label = {s['Obj3D']: 'Obj3D', s['Obj48']: 'Obj48'}.get(m.get(a, 'code'))
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
    m.put(pool[-1], 'code', 0)
    m.act('Obj48', root)
    assert len(parts('Obj48')) == 6 and m.get(root, 'obRoutine') == 2
    results.append('full/fragmented pools retry without partial ship or chain')

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
    while not m.get(body, 'BGHZ_WeaponReady'):
        for a in previous:
            distance = m.get(a, 'GBall_Distance', 2)
            assert distance - previous[a] in (0, 2)
            assert m.get(a, 'obX', 2) == m.get(body, 'obX', 2)
            assert m.get(a, 'obY', 2) - m.get(body, 'obY', 2) == distance
            previous[a] = distance
        frame()
    assert [m.get(a, 'GBall_Distance', 2) for a in children] == [16, 32, 48, 64, 96]
    assert m.get(root, 'obY', 2) - m.get(body, 'obY', 2) == 32
    assert m.get(children[-1], 'obY', 2) - m.get(body, 'obY', 2) == 128
    frame()  # enter patrol; flight starts on the following tick
    turns = 0
    previous_x = m.get(body, 'obX', 2)
    previous_step = -1
    for _ in range(512):
        frame()
        x = m.get(body, 'obX', 2)
        delta = x - previous_x
        assert abs(delta) == 1, ('Flight paused', x, previous_x)
        assert s['BGHZ_LeftTurn'] <= x <= s['BGHZ_RightTurn']
        turns += delta != previous_step
        previous_x, previous_step = x, delta
        assert m.get(root, 'obX', 2) == x
        assert m.get(root, 'obY', 2) == m.get(body, 'obY', 2) + 32
    assert turns >= 7
    results.append('staged two-pixel drop and eight continuous patrol sweeps')

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
        assert m.get(a, 'obRoutine') == s['GBall_DebrisRoutine']
        assert not m.get(a, 'obColType')
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
    previous_x = g.get(body, 'obX', 2)
    xs = []
    for _ in range(256):
        g.run()
        valid()
        x = g.get(body, 'obX', 2)
        assert abs(x - previous_x) == 1
        previous_x = x
        xs.append(x)
    assert min(xs) == s['BGHZ_LeftTurn'] and max(xs) == s['BGHZ_RightTurn']
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
    assert all(g.get(a, 'obRoutine') == s['GBall_DebrisRoutine'] and
               not g.get(a, 'obColType') for a in weapon)
    burst_count = 0
    for tick in range(600):
        g.run()
        valid()
        burst_count = max(burst_count, len([a for a in objects(g) if g.get(a, 'code') == s['BossExplosion']]))
        if tick in (5, 13, 25, 50, 300):
            g.video.save(args.output / f'defeat-{tick:03}.png')
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
                boss_deleted=True, harmless_debris=True, capsule_open=True,
                ordinary_explosion_art_restored=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT / 'main.lst')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--core', type=Path)
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--player', type=int, choices=(0, 2), default=0)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results, decoded = native_checks(args)
    report = dict(native=results)
    for result in report['native']:
        print(result + ': passed', flush=True)
    if args.core:
        report['runtime'] = live_checks(args, decoded)
        print('GHZ3: eight real hits, breakup, bursts, escape and capsule passed', flush=True)
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
