#!/usr/bin/env python3
"""Compare actual MD/CD terrain calls and tilemaps with a reference ROM.

First run the previous ROM with --baseline, then pass its report as --reference.
CPU costs include the complete mailbox wait; full frames use the real scheduler.
Direct probes reset both clock origins between slices, as in the ring-job check.
"""
from pathlib import Path
import argparse
import ctypes as C
import hashlib
import json
import random
import struct

from genesis_test_core import Genesis
from check_caterkiller import CpuPrefix
from check_object_course import boot_level

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for n in ('core', 'output'):
        p.add_argument('--' + n, type=Path, required=True)
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
    p.add_argument('--baseline', action='store_true')
    p.add_argument('--reference', type=Path)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--zone', type=int, default=0)
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
                system_directory=args.system_directory)
    boot_level(g, zone=args.zone)
    stage = g.save()
    maincpu = CpuPrefix.in_dll(g.core, 'm68k')
    subcpu = CpuPrefix.in_dll(g.core, 's68k')
    g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
    g.core.s68k_set_reg.argtypes = [C.c_int, C.c_uint]
    g.core.m68k_run.argtypes = [C.c_uint]
    cd = bool(g.s['MegaCDMode1'])
    prg = g.memory_domains.get('PRGRAM')
    stop = g.s['Free_RAM_Start'] & 0xFFFFFF
    stack = (g.s['v_systemstack'] & 0xFFFFFF) - 4

    def act(name, regs=None):
        for cpu in (maincpu, subcpu):
            cpu.cycles = 0
            cpu.poll[0] = cpu.poll[1] = 0
        g.core.m68k_set_reg(17, 0x2700)
        for reg, value in (regs or {}).items():
            g.core.m68k_set_reg(reg, value & 0xFFFFFFFF)
        g.write(stack, stop, 4)
        g.write(stop, 0x60FE, 2)
        g.core.m68k_set_reg(15, stack)
        g.core.m68k_set_reg(16, g.s[name])
        start = maincpu.cycles
        for _ in range(300000):
            if g.core.m68k_get_reg(16) == stop:
                assert g.core.m68k_get_reg(15) == stack + 4, name
                return (maincpu.cycles - start) // 7
            g.core.m68k_run(maincpu.cycles + 1)
        gate = (C.c_uint8 * 512).from_address(C.addressof(prg) + 0x102000)
        g.core.s68k_get_reg.argtypes = [C.c_int]
        g.core.s68k_get_reg.restype = C.c_uint
        raise AssertionError((name, hex(g.core.m68k_get_reg(16)),
                              'Sub', [hex(g.core.s68k_get_reg(i)) for i in (0, 6, 7, 15, 16)],
                              'clocks', maincpu.cycles, subcpu.cycles,
                              'gate', bytes(gate[:0x30]).hex()))

    def subwrite(name, value, size):
        address = g.s[name]
        for i, b in enumerate(value.to_bytes(size, 'big')):
            prg[(address + i) ^ 1] = b

    # Calls use the level's genuine resident collision data on both CPUs.
    cases, costs, planes = {}, {}, {}
    methods = ('AnglePos', 'CalcRoomInFront', 'sub_13102', 'loc_13146',
               'Sonic_DontRunOnWalls', 'ChkFloorEdge', 'ChkFloorEdge_Part2',
               'ObjHitFloor', 'ObjHitFloor2', 'sub_132EE', 'Sonic_HitWall',
               'ObjHitWallRight', 'ObjHitWallLeft', 'ObjHitCeiling',
               'Sonic_DoLevelCollision', 'Tails_DoLevelCollision')
    rng = random.Random(0x68000)
    points = [(rng.randrange(32, 2048), rng.randrange(160, 1024)) for _ in range(40)]
    points += [(128 + x, 944 + y) for x in (0, 7, 15, 16, 127, 128)
               for y in (-16, -1, 0, 1, 15, 16)]
    actor = g.s['v_player']
    for label in methods:
        total = 0
        for i, (x, y) in enumerate(points):
            for field, value, size in (
                    ('obX', x, 2), ('obY', y, 2), ('obHeight', 19, 1),
                    ('obWidth', 9, 1), ('obStatus', 0, 1),
                    ('obAngle', (i % 4) * 64, 1), ('obPrevAni', 0, 1),
                    ('stick_to_convex', i % 2, 1), ('obTopSolidBit', 12, 1),
                    ('obLRBSolidBit', 13, 1), ('obVelX', 0x280 if i % 2 else 0xFD80, 2),
                    ('obVelY', 0x180 if i % 4 < 2 else 0xFE80, 2),
                    ('obInertia', 0x1234, 2), ('default_y_radius', 19, 1),
                    ('default_x_radius', 9, 1), ('spindash_flag', 0, 1)):
                g.put(actor, field, value, size)
            g.write('Collision_addr', g.read('v_colladdr1', 4), 4)
            g.write('Primary_Angle', 3)
            g.write('Secondary_Angle', 3)
            if args.baseline and cd:
                act('MCD_AcquireProgramRAM')
            elif cd:
                subwrite('MCD_TerrainPrimary_Sub', 0x0303, 2)
                subwrite('MCD_TerrainPath_Sub', g.s['MCD_TerrainIndex_Sub'], 4)
            # These internal-style entries inherit d5's solidity bit from the
            # surrounding contact pass. Set it on the executing CPU explicitly;
            # a standalone probe must not inherit the previous method's d5.
            if label in ('Sonic_DontRunOnWalls', 'sub_132EE', 'Sonic_HitWall') and cd:
                g.core.s68k_set_reg(5, 13)
            total += act(label, {0: (i % 4) * 64, 3: x, 5: 13, 7: 0x24681357, 8: actor})
            assert g.core.m68k_get_reg(7) == 0x24681357, label
            row = {f: g.get(actor, f, z) for f, z in (
                ('obX', 2), ('obY', 2), ('obAngle', 1), ('obStatus', 1), ('obPrevAni', 1),
                ('obVelX', 2), ('obVelY', 2), ('obInertia', 2), ('obHeight', 1), ('obWidth', 1))}
            if label not in ('AnglePos', 'Sonic_DoLevelCollision', 'Tails_DoLevelCollision'):
                row.update(distance=g.core.m68k_get_reg(1) & 65535,
                           angle=g.core.m68k_get_reg(3) & 255)
                if label in ('sub_13102', 'loc_13146', 'Sonic_DontRunOnWalls'):
                    row['other_distance'] = g.core.m68k_get_reg(0) & 65535
            cases[f'{label}/{i}'] = row
        costs[label] = total / len(points)
    (args.output / 'costs.json').write_text(json.dumps(costs, indent=2) + '\n')
    print(f'{len(cases)} complete actor/sensor operations executed.', flush=True)

    if args.reference:
        reference = json.loads(args.reference.read_text())
        assert reference['cases'] == cases, next(
            (k, reference['cases'].get(k), v) for k, v in cases.items()
            if reference['cases'].get(k) != v)

    # Full planes span multiple clock slices. Run them through retro_run so the
    # core normalizes its clocks; direct single-instruction probes can overflow
    # Genesis Plus GX's 32-bit clock-conversion multiplication on this long job.
    for x, y in ((0, 0), (112, 112), (128, 128), (496, 240), (512, 256), (1023, 1023)):
        g.restore(stage)
        for field, value in (('Camera_X_pos', x), ('Camera_Y_pos', y),
                             ('Camera_BG_X_pos', x // 2), ('Camera_BG_Y_pos', y // 2)):
            g.write(field, value, 2)
        g.write('Scroll_flags', 0, 4)
        g.write('Scroll_flags_BG2', 0, 4)
        g.write('Screen_redraw_flag', 0)
        code = b''
        if cd and 'MCD_FlushDecodeDMA' in g.s:
            # Frame snapshots can hold a prepared art DMA. Keep V-int enabled
            # until its real VBlank consumes Word RAM, then disable it for drawing.
            code += bytes.fromhex('33FC813400C000044EB9') + struct.pack('>I', g.s['MCD_FlushDecodeDMA'])
        code += bytes.fromhex('33FC811400C0000433FC8F0200C00004')
        if args.baseline and cd:
            code += bytes.fromhex('4EB9') + struct.pack('>I', g.s['MCD_RequireProgramRAM'])
        code += bytes.fromhex('4EB9') + struct.pack('>I', g.s['LoadTilesFromStart'])
        done = stop + len(code)
        code += bytes.fromhex('60FE')
        for i, value in enumerate(code):
            g.write(stop + i, value)
        for reg, value in ((17, 0x2700), (15, stack), (16, stop)):
            g.core.m68k_set_reg(reg, value)
        for frame in range(32):
            g.run()
            if g.core.m68k_get_reg(16) == done:
                break
        else:
            raise AssertionError(('Full terrain construction stalled', x, y,
                                  hex(g.core.m68k_get_reg(16))))
        planes[f'{x}/{y}'] = hashlib.sha256(bytes(g.vram[0xC000:0xD000]) + bytes(g.vram[0xE000:0xF000])).hexdigest()
    print('Full plane construction and VDP output executed at six wrap/boundary positions.', flush=True)

    if args.reference:
        reference = json.loads(args.reference.read_text())
        assert reference['cases'] == cases, next(
            (k, reference['cases'].get(k), v) for k, v in cases.items()
            if reference['cases'].get(k) != v)
        assert reference['planes'] == planes, (reference['planes'], planes)
        print('Distances, angles, attachment state and complete tilemaps match the reference.', flush=True)

    # Resume whole frames only from a genuine frame-boundary state.
    g.restore(stage)
    walking = []
    for frame in range(180):
        g.buttons = {7}
        g.run()
        walking.append([g.get('v_player', 'obX', 2), g.get('v_player', 'obY', 2),
                        hashlib.sha256(bytes(g.vram[0xC000:0xD000]) + bytes(g.vram[0xE000:0xF000])).hexdigest()])
    g.restore(stage)
    free = slice(g.s['Free_RAM_Start'] & 65535, (g.s['Free_RAM_End'] & 65535) or 0x10000)
    canary = bytes((i * 37 + 19) & 255 for i in range(free.stop - free.start))
    g.ram[free] = canary
    gameplay = []
    for frame in range(600):
        g.buttons = {7} | ({0} if frame % 120 < 20 else set())
        g.run()
        assert not g.read('v_errortype'), frame
        assert bytes(g.ram[free]) == canary, frame
        gameplay.append([g.get('v_player', 'obX', 2), g.get('v_player', 'obY', 2),
                         hashlib.sha256(bytes(g.vram[0xC000:0xD000]) + bytes(g.vram[0xE000:0xF000])).hexdigest()])
    g.video.save(args.output / 'gameplay.png')
    g.close()
    if args.reference:
        assert reference['walking'] == walking, next(
            (i, a, b) for i, (a, b) in enumerate(zip(reference['walking'], walking)) if a != b)
    report = dict(cases=cases, planes=planes, walking=walking, gameplay=gameplay, md_cpu_cycles=costs,
                  pal=args.pal, zone=args.zone, baseline=args.baseline,
                  rom_sha256=hashlib.sha256(args.rom.read_bytes()).hexdigest())
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('600 controller-driven frames preserve the complete free MD RAM block.', flush=True)


if __name__ == '__main__':
    main()
