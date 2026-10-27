#!/usr/bin/env python3
"""Run ordinary platform fixtures and real placements in Genesis Plus GX.

Uses the normal object executor, player collision and renderer. RAM writes only
establish fixture positions, selected settings and a held switch. No ROM code
or collision service is replaced.
"""
import argparse
import json
from pathlib import Path

from check_object_course import boot_level
from genesis_test_core import Genesis
from object_layout import decode

p = argparse.ArgumentParser(description=__doc__)
for name in ('rom', 'listing', 'core', 'output'):
    p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--system-directory', type=Path)
p.add_argument('--pal', action='store_true')
p.add_argument('--player', type=int, choices=(0, 2), default=0)
p.add_argument('--zone', type=int, default=0)
p.add_argument('--act', type=int, default=3)
p.add_argument('--placements', type=Path, help='Sweep this act layout instead of the movement fixtures')
args = p.parse_args()
g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
            system_directory=args.system_directory)
boot_level(g, zone=args.zone, act=args.act, player=args.player)
pool = list(range(g.s['v_lvlobjspace'] & 65535, g.s['v_lvlobjend'] & 65535, g.s['object_size']))
actors = ['v_player', 'v_player2'] if args.player == 0 else ['v_player']
base = g.save()
checks = []


def run(frames):
    for i in range(frames):
        g.run()
        assert not g.read('v_errortype'), ('CPU exception', g.frame)


def position(x, y):
    for actor, dx in zip(actors, (-4, 4)):
        for field, value, size in (
                ('obX', x + dx, 2), ('obY', y, 2), ('obVelX', 0, 2),
                ('obVelY', 0x100, 2), ('obInertia', 0, 2), ('obControl', 1, 1),
                ('obStatus', 2, 1), ('obRoutine', 2, 1), ('obAnim', 0, 1),
                ('jumping', 0, 1), ('standonobject', 0, 1),
                ('obStatusSecondary', 2, 1), ('invtime', 6000, 2), ('flashtime', 0, 2)):
            g.put(actor, field, value, size)
        g.put(actor, 'obHeight', g.get(actor, 'default_y_radius'))
        g.put(actor, 'obWidth', g.get(actor, 'default_x_radius'))
    g.write('Tails_CPU_idle_timer', 600, 2)
    g.write('Camera_X_pos', max(0, x - 160), 2)
    g.write('Camera_Y_pos', max(0, y - 100), 2)


if args.placements:
    for index, (x, y, oid, era, subtype) in enumerate(decode(args.placements.read_bytes())):
        if oid != 0x18:
            continue
        g.restore(base)
        position(x, (y & 0xFFF) - 64)
        run(40)
        handle = g.placement_handle(index)
        owners = [a for a in pool if g.get(a, 'code') and g.get(a, 'respawn_addr', 2) == handle]
        assert len(owners) == 1, ('placement owner', index, x, y, owners)
        platform = owners[0]
        assert g.get(platform, 'obSubtype') == subtype
        assert g.get(platform, 'code') in (g.s['Plat_Top'], g.s['Plat_Full'], g.s['Plat_FallingIntangible'])
        assert g.get(platform, 'obFrame') < 2
        if len(checks) < 2:
            g.video.save(args.output / f'placement-{index}.png')
        checks.append({'placement': index, 'subtype': subtype})
else:
    cases = list(range(16)) + [0x100, 0x1100, 0x200C, 0x1000, 0x1001, 0x1004, 0x1005, 0x1008, 0x100C, 0x100F, 0x20, 0x30, 0x40, 0x120, 0x130, 0x140]
    for settings in cases:
        g.restore(base)
        # Clear dynamic objects so this fixture owns its interaction surface.
        for a in pool:
            g.write(a, 0, g.s['object_size'])
        platform = pool[0]
        mode = settings & 15
        subtype = settings | (0x80 if mode % 2 == 0 or mode == 7 else 0) | (0x4000 if mode == 14 else 0x6000 if mode == 15 else 0)
        falling=bool(subtype&0x1000)
        for field, value, size in (('code', g.s['Obj18'], 4), ('obX', 0x180, 2),
                                    ('obY', 0x2C0, 2), ('obSubtype', subtype, 2)):
            g.put(platform, field, value, size)
        position(0x180, 0x280)
        # Keep the actors away while construction selects the movement.
        for actor in actors:
            g.put(actor, 'obX', 0x40, 2)
        run(1)
        x, y = g.get(platform, 'obX', 2), g.get(platform, 'obY', 2)
        radius = g.get(platform,'obHeight')
        position(x, y - radius - g.get('v_player', 'obHeight'))
        for actor in actors:
            g.put(actor, 'obY', y - radius - g.get(actor, 'obHeight'), 2)
        g.put(platform, 'obRender', g.get(platform, 'obRender') | 0x80)
        run(2)
        mask = 0x18 if len(actors) == 2 else 8
        assert g.get(platform, 'obStatus') & mask == mask, ('boarding', hex(subtype), [(a, g.get(a, 'obY', 2), g.get(a, 'obStatus')) for a in actors])
        if mode >= 14:
            g.write(g.s['f_switch'] + (10 if mode==14 else 3), 1)
        offsets = {a: g.get(a, 'obX', 2) - g.get(platform, 'obX', 2) for a in actors}
        trace = []
        detached = False
        duration = 900 if falling and mode else 96 if mode == 7 else 400 if mode>=14 else 320 if mode==12 else 180
        for tick in range(duration):
            run(1)
            code = g.get(platform, 'code')
            if not code and falling:
                assert detached
                break  # normal deletion below the level, after detaching riders
            assert code, ('platform unexpectedly unloaded', hex(subtype), tick)
            detached |= code == g.s['Plat_FallingIntangible']
            if mode != 7 and code != g.s['Plat_FallingIntangible']:
                for actor in actors:
                    assert g.get(actor, 'obStatus') & 8, ('lost rider', hex(subtype), actor, tick)
                    assert g.get(actor, 'obX', 2) - g.get(platform, 'obX', 2) == offsets[actor]
            if tick in (0, 30, 90, duration - 1):
                trace.append([tick, g.get(platform, 'obX', 2), g.get(platform, 'obY', 2), code])
        if falling:
            assert g.get(platform, 'code') in (0, g.s['Plat_FallingIntangible'])
            assert not g.get(platform, 'obStatus') & 0x18
        if mode >= 14 and not falling:
            assert g.get(platform, 'Plat_rawY', 2) == 0xC0
            assert g.get(platform, 'Plat_movement', 4) == g.s['Plat_Stationary']
        if mode == 7:
            assert not g.get(platform, 'Plat_flags') & 1
            assert g.get(platform, 'Plat_rawY', 2) < 0x2C0
        g.video.save(args.output / f'mode-{subtype:04X}.png')
        checks.append({'subtype': subtype, 'trace': trace})
        print(f'PASS platform ${subtype:04X}', flush=True)

report = {'pal': args.pal, 'player': args.player, 'zone': args.zone, 'act': args.act, 'checks': checks}
(args.output / 'game.json').write_text(json.dumps(report, indent=2))
g.close()
print(f'Passed {len(checks)} platform cases.')
