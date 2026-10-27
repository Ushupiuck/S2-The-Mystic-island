#!/usr/bin/env python3
"""Compare real 68000 object costs and resulting state against a previous ROM.

Use matching cartridge ROM/listing pairs in separate processes. Direct main-CPU
stepping cannot service Mode 1 sub-CPU requests. Counts exclude video-frame work;
they are emulator CPU costs, not a physical-console benchmark.
"""
import argparse
import ctypes as C
import json
from pathlib import Path

from genesis_test_core import Genesis
from check_caterkiller import CpuPrefix
from check_companion_followup import isolate, place, spawn
from check_object_course import boot_level


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--compare', type=Path, help='Previous run\'s costs.json')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output)
    assert not g.s['MegaCDMode1'], 'Use the cartridge build for isolated CPU timing'
    boot_level(g, zone=0, act=3, player=0)
    stage = g.save()
    cpu = CpuPrefix.in_dll(g.core, 'm68k')
    g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
    g.core.m68k_run.argtypes = [C.c_uint]
    rows = []

    def act(label, obj, regs=None):
        g.core.m68k_set_reg(17, 0x2700)
        g.core.m68k_set_reg(8, 0xFF0000 | (obj & 65535))
        for reg, value in (regs or {}).items():
            g.core.m68k_set_reg(reg, value & 0xFFFFFFFF)
        g.core.m68k_set_reg(15, 0xFF7E00)
        g.write(0x7E00, 0xFF7F00, 4)
        g.write(0x7F00, 0x60FE, 2)
        g.core.m68k_set_reg(16, g.s[label])
        start = cpu.cycles
        for _ in range(100000):
            if g.core.m68k_get_reg(16) == 0xFF7F00:
                assert g.core.m68k_get_reg(15) == 0xFF7E04, label
                return cpu.cycles - start
            g.core.m68k_run(cpu.cycles + 1)
        raise AssertionError((label, hex(g.core.m68k_get_reg(16))))

    def fixture(subtype=0x26, code='SwingingPtfm', initialize=True):
        g.restore(stage)
        isolate(g)
        g.write('Camera_X_pos_coarse_back', 0x700, 2)
        g.write('Camera_Max_Y_pos', 0x1000, 2)
        for who in ('v_player', 'v_player2'):
            place(g, who, 0xA00, 0x100)
        obj = spawn(g, code, 0x800, 0x200)
        g.put(obj, 'obSubtype', subtype, 2)
        if initialize:
            act(code, obj)
        return obj

    def state():
        fields = [('obX', 4), ('obY', 4), ('obVelX', 2), ('obVelY', 2),
                  ('obHeight', 1), ('obActWid', 1), ('obFrame', 1),
                  ('obStatus', 1), ('obRoutine', 1), ('obSubtype', 2)]
        objects = []
        for obj in range(g.s['v_lvlobjspace'] & 65535,
                         g.s['v_lvlobjend'] & 65535, g.s['object_size']):
            code = g.get(obj, 'code')
            if not code:
                continue
            row = dict(slot=obj, values=[g.get(obj, f, n) for f, n in fields])
            if code == g.s['SwingingPtfm']:
                row['angular'] = [g.get(obj, f, n) for f, n in
                                  [('obAngle', 2), ('swing_ang_vel', 2),
                                   ('swing_mode_timer', 2), ('swing_mode_started', 1)]]
            if code == g.s['SwingingPtfm_HelperDisplay']:
                row['links'] = [g.read(obj + g.s['subspr_data'] + i, 2)
                                for i in range(0, 48, 2)]
            objects.append(row)
        players = [[g.get(who, f, n) for f, n in fields +
                    [('obControl', 1), ('standonobject', 1)]]
                   for who in ('v_player', 'v_player2')]
        return dict(objects=objects, players=players, rings=g.read('v_rings', 2))

    def record(name, label, obj, regs=None):
        elapsed = act(label, obj, regs)
        assert elapsed % 7 == 0, (name, elapsed)
        rows.append(dict(case=name, cycles=elapsed // 7, state=state()))

    for links in (0, 1, 4, 8):
        obj = fixture(0x20 | links, initialize=False)
        record('construct-' + str(links), 'SwingingPtfm', obj)
        obj = fixture(0x20 | links)
        record('angle-' + str(links), 'SwingingPtfm_ApplyAngle', obj, {0: 0x53})
    obj = fixture()
    record('cached-angle', 'SwingingPtfm_ApplyAngle', obj, {0: 0x40})
    for subtype in (0x26, 0x926, 0x56, 0x66):
        obj = fixture(subtype)
        record('attached-' + format(subtype, '04X'), 'SwingingPtfm_SetSolid', obj)
    obj = fixture(0x46)
    g.put(obj, 'swing_mode_started', 1)
    g.put(obj, 'obAngle', 0x1000, 2)
    g.put(obj, 'swing_ang_vel', 0x300, 2)
    record('momentum-active', 'SwingingPtfm_UpdateMotion', obj)
    for profile in range(16):
        obj = fixture((profile << 8) | 0x20, 'Obj18')
        place(g, 'v_player', g.get(obj, 'obX', 2),
              g.get(obj, 'obY', 2) - g.get(obj, 'obHeight') - 19 + 2)
        g.put('v_player', 'obVelY', 0x100, 2)
        g.put('v_player', 'flashtime', 0x100, 2)
        g.put(obj, 'obRender', 0x94)
        record('contact-' + format(profile, 'X'), 'Platform_Interact', obj,
               {4: g.get(obj, 'obX', 2)})
    obj = fixture(0xA0, 'Obj18')
    record('empty-sag', 'Plat_ApplyY', obj)
    obj = fixture()
    record('wall-right', 'Platform_BodyWall', g.get(obj, 'swing_body', 2), {0: 1})
    obj = fixture()
    record('wall-left', 'Platform_BodyWall', g.get(obj, 'swing_body', 2), {0: -1})
    for water in (0, 1):
        obj = fixture()
        body = g.get(obj, 'swing_body', 2)
        g.write('Water_flag', water)
        g.write('v_waterpos2', 0x300, 2)
        g.put(body, 'obRoutine', 12)
        g.put(body, 'Plat_flags', 0)
        record('floating-' + str(water), 'Platform_FloatingBody', body)
    obj = fixture()
    record('cull-retained', 'SwingingPtfm_ChkDel', obj)
    obj = fixture()
    g.write('Camera_X_pos_coarse_back', 0x2000, 2)
    record('cull-unload', 'SwingingPtfm_ChkDel', obj)
    g.close()
    if args.compare:
        before = json.loads(args.compare.read_text())['rows']
        assert [r['case'] for r in before] == [r['case'] for r in rows]
        for old, new in zip(before, rows):
            assert old['state'] == new['state'], (new['case'], 'state changed')
            new['saved_cycles'] = old['cycles'] - new['cycles']
            assert new['saved_cycles'] >= 0, (new['case'], new['saved_cycles'])
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'costs.json').write_text(json.dumps(dict(rows=rows), indent=2) + '\n')
    for row in rows:
        print(row['case'], row['cycles'], 'cycles',
              '(' + str(row['saved_cycles']) + ' saved)' if args.compare else '')


if __name__ == '__main__':
    main()
