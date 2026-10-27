#!/usr/bin/env python3
"""Execute platform payload placement, ownership, riding and persistence tests."""
import argparse
import json
from pathlib import Path

import native_test_core as c
from object_layout import decode, encode, with_mount, mount_settings


def signed16(value):
    return value - 65536 if value & 0x8000 else value


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom', type=Path, required=True)
    p.add_argument('--listing', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    m = c.Manager(args.rom, args.listing)
    checks = []
    guard = 0x3579006F

    def act(label, obj=None):
        m.act(label, obj, {c.UC_M68K_REG_D7: guard})
        assert m.cpu.reg_read(c.UC_M68K_REG_D7) == guard, (label, 'object loop counter')

    def fixture(setting=0, word=0x20, label='Obj18'):
        m.start()
        m.write('Camera_X_pos_coarse_back', 0x700, 2)
        m.write('Camera_Max_Y_pos', 0x1000, 2)
        m.act('OscillateNumInit')
        obj = next(iter(m.pool()))
        for f, v, n in [('code', m.s[label], 4), ('obX', 0x800, 2), ('obY', 0x400, 2),
                        ('obSubtype', word, 2), ('PlatformMount_settings', setting, 1)]:
            m.put(obj, f, v, n)
        act(label, obj)
        body = obj if label == 'Obj18' else m.get(obj, 'swing_body', 2) | 0xFF0000
        if label != 'Obj18': act('SwingingPtfm_Interact', obj)
        return obj, body

    def children(body):
        result = []
        ptr = m.get(body, 'PlatformMount_head', 2)
        while ptr:
            child = ptr | 0xFF0000
            assert child not in result and len(result) < 2
            assert m.get(child, 'Mount_parent', 2) == body & 65535
            result.append(child)
            ptr = m.get(child, 'Mount_next', 2)
        return result

    # Every selection is independent of raw settings, era and old Y flags.
    cases = 0
    for oid in (0x17, 0x18, 0xDB, 0xDC, 0xDD, 0xDE):
        for setting in range(64):
            for eras in range(8):
                row = with_mount((0x800, 0xE400, oid, eras << 5, 0xA5F3), setting)
                assert mount_settings(row) == setting
                assert decode(encode([row])) == [row]
                assert row[1] & 0xEFFF == 0xE400 and row[3] & 0xE0 == eras << 5 and row[4] == 0xA5F3
                cases += 1
    checks.append(f'{cases} complete record round trips: six payload bits, eras, flips, any-Y and full word')

    # Test both actual loaders, not a fixture-only decoding path.
    for oid in (0x17, 0x18, 0xDB, 0xDC, 0xDD, 0xDE):
        for setting in range(64):
            row = with_mount((0x800, 0xE400, oid, 0xE0, 0xA5F3), setting)
            m.fixture([row]);m.cam(0x700, 0x300);m.act('ObjectsManager')
            obj = next(iter(m.live().values()))
            assert m.get(obj, 'PlatformMount_settings') == setting, (oid, setting)
            assert m.get(obj, 'obSubtype') == 0xA5F3 and m.get(obj, 'obStatus') & 3 == 3
            assert m.get(obj, 'obY', 2) == 0x400
    checks.append('384 live loader cases: all platform art IDs and reserved payload codes, no render/status flag leakage')

    for label, shape in [('SwingingPtfm', 2), ('SwingingPtfm_ArtTerrain0', 0),
                         ('SwingingPtfm_ArtTerrain1', 1), ('SwingingPtfm_ArtRail', 3), ('SwingingPtfm_ArtBall', 4)]:
        for profile in range(16):
            for setting in range(34):
                obj, body = fixture(setting, (profile << 8) | 0x26, label)
                assert m.get(body, 'obSubtype') == ((profile if profile < 12 else 0) << 8) | shape << 4
                assert m.get(body, 'PlatformMount_settings') == setting
                group = children(body)
                assert len(group) == (0 if setting == 0 else 2 if 17 <= setting <= 20 else 1), (label, profile, setting)
                for child in group:
                    assert not m.get(child, 'respawn_addr', 2)
                    assert m.get(child, 'obX', 2) == m.get(body, 'obX', 2) + signed16(m.get(child, 'Mount_x', 2))
                    before = (m.get(child, 'obX', 4), m.get(child, 'obY', 4), m.get(child, 'obRoutine'))
                    act('PlatformMount_Child', child)
                    assert before == (m.get(child, 'obX', 4), m.get(child, 'obY', 4), m.get(child, 'obRoutine'))
    checks.append('2720 independent swing art/interaction/payload constructors; exact child count and no double update')

    for setting in range(1, 34):
        obj, body = fixture(setting)
        group = children(body)
        if setting <= 16: assert m.get(group[0], 'obSubtype') == setting - 1
        elif setting <= 20:
            by_x = sorted(group, key=lambda a: m.get(a, 'obX', 2))
            assert [m.get(a, 'obSubtype') for a in by_x] == [((setting - 17) >> 1) * 2, ((setting - 17) & 1) * 2]
        elif setting == 21:
            assert m.get(group[0], 'obFrame') == 8 and m.get(group[0], 'obSubtype') == 0
        else: assert m.get(group[0], 'obAnim') == setting - 22
        before = {a: (m.get(a, 'obX', 2), m.get(a, 'obY', 2)) for a in group}
        m.put(body, 'obX', 0x830, 2);m.put(body, 'obY', 0x412, 2)
        act('PlatformMount_Update', body)
        for child in group:
            assert (m.get(child, 'obX', 2), m.get(child, 'obY', 2)) == (before[child][0] + 48, before[child][1] + 18)
            if setting == 21:
                assert m.get(child, 'spikes_base_x_pos', 2) == m.get(child, 'obX', 2)
                assert m.get(child, 'spikes_base_y_pos', 2) == m.get(child, 'obY', 2)
        act('Plat_Unload', body)
        assert all(not m.get(a, 'code') for a in group)
    checks.append('all payload subtypes, independent spring colors, moving spike origins and group cleanup')

    # Either character can stand on a mounted monitor; carry and body sag/fall
    # must use that relationship rather than pretending they stand on the base.
    for who in ('v_player', 'v_player2'):
        obj, body = fixture(26, 0x10A0)
        child = children(body)[0]
        other = 'v_player2' if who == 'v_player' else 'v_player'
        m.put(other, 'code', 0)
        stand = (child - (m.s['v_objspace'] & 0xFFFFFF)) // m.s['object_size']
        m.put(child, 'obRender', 0x94)
        for f, v, n in [('obX', m.get(child, 'obX', 2), 2), ('obY', m.get(child, 'obY', 2) - 35, 2),
                        ('obStatus', 8, 1), ('standonobject', stand, 1)]:m.put(who, f, v, n)
        m.put(child, 'obStatus', 8 if who == 'v_player' else 16)
        x, y = m.get(who, 'obX', 2), m.get(who, 'obY', 2)
        m.put(body, 'obX', m.get(body, 'obX', 2) + 12, 2)
        m.put(body, 'obY', m.get(body, 'obY', 2) + 6, 2)
        act('PlatformMount_Update', body)
        assert m.get(who, 'obX', 2) == x + 12 and m.get(who, 'obY', 2) == y + 6, (who, hex(child), x, y, m.get(who, 'obX', 2), m.get(who, 'obY', 2), m.get(who, 'obStatus'), m.get(child, 'obStatus'))
        assert m.get(who, 'standonobject') == stand
        assert m.get(body, 'PlatformMount_standing') & (8 if who == 'v_player' else 16)
        act('Plat_Move', body)
        assert m.get(body, 'Plat_flags') & 8 and m.get(body, 'Plat_sag') == 4
    checks.append('both monitor riders translate once, retain standing indices, depress and arm the base platform')

    for setting in (1, 18, 21, 26):
        obj, body = fixture(setting, 0x1026, 'SwingingPtfm')
        group = children(body)
        for a in m.pool():
            if not m.get(a, 'code'):m.put(a, 'code', m.s['ObjNull'])
        m.put(obj, 'obStatus', 8);m.put(obj, 'swing_mode_timer', 30, 2)
        act('SwingingPtfm_DetachCheck', obj)
        assert m.get(body, 'obRoutine') == 10 and children(body) == group
        act('SwingingPtfm_DelAll', obj)
        assert all(not m.get(a, 'code') for a in [obj, body] + group)
    checks.append('full-pool detachment retains all four payload families without new allocations')

    # Partial allocation must retry without duplicating the first spring. A
    # reused child slot belongs to its new owner, even if old metadata remains.
    obj, body = fixture(18)
    act('PlatformMount_Delete', body)
    for a in m.pool():
        if not m.get(a, 'code'):m.put(a, 'code', m.s['ObjNull'])
    act('PlatformMount_Update', body);assert not children(body)
    spare=[a for a in m.pool() if a != body][:2]
    for n,a in enumerate(spare,1):
        m.cpu.mem_write(a & 0xFFFFFF, bytes(m.s['object_size']))
        act('PlatformMount_Update',body)
        assert len(children(body))==n
    group=children(body);foreign=group[0];survivor=group[1]
    m.put(foreign,'code',m.s['ObjNull'])
    act('PlatformMount_Update',body)
    assert not children(body) and m.get(foreign,'code')==m.s['ObjNull']
    act('PlatformMount_Child',survivor);assert not m.get(survivor,'code')
    act('PlatformMount_Update',body);assert len(children(body))==1
    checks.append('full/partial pools retry; reused child survives and its orphan sibling retires')

    for orphan in (False, True):
        obj, body=fixture(16);child=children(body)[0]
        m.write('f_switch',0) # channel F, not channel zero
        m.cpu.mem_write((m.s['f_switch']+15)&0xFFFFFF,b'\x81')
        if orphan:
            m.put(body,'code',m.s['ObjNull']);act('PlatformMount_Child',child)
        else:act('PlatformMount_Delete',body)
        assert not m.get(child,'code')
        assert bytes(m.cpu.mem_read((m.s['f_switch']+15)&0xFFFFFF,1))==b'\x80'
    checks.append('explicit and orphan button cleanup releases only its momentary channel bit')

    for who in ('v_player','v_player2'):
        for setting,strength in ((17,0xF000),(20,0xF600)):
            obj,body=fixture(setting);child=min(children(body),key=lambda a:m.get(a,'obX',2))
            m.put('v_player2' if who=='v_player' else 'v_player','code',0)
            for f,v,n in [('obX',m.get(child,'obX',2),2),('obY',m.get(child,'obY',2)-25,2),
                          ('obStatus',2,1),('obVelY',0x100,2)]:m.put(who,f,v,n)
            act('PlatformMount_Update',body)
            assert m.get(who,'obVelY',2)==strength, (who,setting,'spring launch')
            assert not m.get(who,'obStatus')&8
    checks.append('both actors launch from red/yellow mounted springs at the ordinary strengths')

    # Body metadata does not turn a broken monitor into a consumed platform.
    for oid in (0x18,0x17,0xDB,0xDC,0xDD,0xDE):
        row = with_mount((0x800, 0x400, oid, 0xE0, 0x20), 26)
        m.fixture([row]);m.cam(0x700, 0x300);m.act('ObjectsManager')
        root = next(iter(m.live().values()))
        entry = 'Obj18' if oid==0x18 else {0x17:'SwingingPtfm',0xDB:'SwingingPtfm_ArtTerrain0',0xDC:'SwingingPtfm_ArtTerrain1',0xDD:'SwingingPtfm_ArtRail',0xDE:'SwingingPtfm_ArtBall'}[oid]
        act(entry,root)
        body=root if oid==0x18 else m.get(root,'swing_body',2)|0xFF0000
        if oid!=0x18:act('SwingingPtfm_Interact',root)
        child = children(body)[0]
        m.put(child, 'obRoutine', 4);act('PlatformMount_Update', body)
        assert m.placement_read() == 0x82 and m.get(body,'code') in (m.s['Plat_Top'],m.s['Platform_SuspendedBody'])
        if oid==0x18:act('Plat_Unload',body)
        else:act('SwingingPtfm_DelAll',root)
        assert m.placement_read() == 2
        m.cam(0x1800,0x300);m.act('ObjectsManager');m.cam(0x700,0x300);m.act('ObjectsManager')
        root=next(a for a in m.pool() if m.get(a,'code')==m.s[entry])
        act(entry,root)
        body=root if oid==0x18 else m.get(root,'swing_body',2)|0xFF0000
        if oid!=0x18:act('SwingingPtfm_Interact',root)
        child=children(body)[0]
        assert m.get(child,'obRoutine')==8 and m.get(child,'obFrame')==11 and not m.get(child,'obColType'), (oid,m.placement_read(),m.get(body,'PlatformMount_flags'))
    checks.append('all six placement owners retain consumed-monitor state on backtracking, restoring their body with a broken box')
    assert m.s['object_size'] == 0x4E
    (args.output / 'native.json').write_text(json.dumps(checks, indent=2) + '\n')
    print('\n'.join('PASS ' + check for check in checks))


if __name__ == '__main__':
    main()
