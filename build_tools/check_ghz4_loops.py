#!/usr/bin/env python3
"""Check GHZ4's Act-3 loop pathswappers and controller-driven traversal."""
import argparse
import json
from pathlib import Path

from convert_s1_ss_background import kosinski_plus_decode
from object_layout import decode
from genesis_test_core import Genesis
from check_object_course import boot_level

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
for name in ('rom', 'listing', 'core', 'output'):
    p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--system-directory', type=Path)
p.add_argument('--pal', action='store_true')
p.add_argument('--player', type=int, choices=(0, 2), default=0)
args = p.parse_args()
layouts = [kosinski_plus_decode((ROOT / f'level/layout/GHZ_{act}.kosp').read_bytes())[0] for act in (3, 4)]
loops = []
for y in range(15):
    for x in range(127):
        offset = y * 256 + x
        if layouts[1][offset:offset+2] == bytes.fromhex('C0C1') and layouts[1][offset+256:offset+258] == bytes.fromhex('C2C3'):
            assert layouts[0][offset:offset+2] == bytes.fromhex('C0C1')
            assert layouts[0][offset+256:offset+258] == bytes.fromhex('C2C3')
            loops.append((x * 128, y * 128))
assert loops, 'No GHZ4 loop terrain'
swappers = [[r for r in decode((ROOT / f'level/objects/GHZ_{act}.bin').read_bytes()) if r[2] == 3] for act in (3, 4)]
assert swappers[0] == swappers[1]
assert [r[4] for r in swappers[1]] == [0x91, 0x11, 0x10]
assert all(r[3] == 0xE0 for r in swappers[1])
g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
            system_directory=args.system_directory)
boot_level(g, zone=0, act=3, player=args.player)
base = g.save()
checks = []
for ox, oy in loops:
    g.restore(base)
    x, floor = ox - 96, oy + 192
    for field, value, size in (
            ('obX', x, 2), ('obY', floor - g.get('v_player', 'obHeight') - 1, 2),
            ('obVelX', 0xB00, 2), ('obVelY', 0, 2), ('obInertia', 0xB00, 2),
            ('obAngle', 0, 1), ('obStatus', 0, 1), ('obAnim', 0, 1),
            ('obRoutine', 2, 1), ('obControl', 0, 1), ('obTopSolidBit', 12, 1),
            ('obLRBSolidBit', 13, 1), ('obStatusSecondary', 2, 1), ('invtime', 6000, 2)):
        g.put('v_player', field, value, size)
    g.write('Camera_X_pos', x - 160, 2)
    g.write('Camera_Y_pos', floor - 112, 2)
    g.write('Screen_redraw_flag', 1)
    quadrants, paths, trace = set(), set(), []
    for frame in range(100):
        g.buttons = {7}
        g.run()
        assert not g.read('v_errortype')
        assert g.get('v_player', 'obRoutine') < 6
        angle = g.get('v_player', 'obAngle') & 0xC0
        quadrants.add(angle)
        paths.add(g.get('v_player', 'obTopSolidBit'))
        if angle == 0x80:
            g.video.save(args.output / 'loop-ceiling.png')
        if frame % 4 == 0:
            trace.append([frame, g.get('v_player', 'obX', 2), g.get('v_player', 'obY', 2), angle, g.get('v_player', 'obTopSolidBit')])
    assert quadrants == {0, 0x40, 0x80, 0xC0}, quadrants
    assert paths == {12, 14}, paths
    assert g.get('v_player', 'obX', 2) > ox + 256
    assert not g.get('v_player', 'obStatus') & 2
    g.video.save(args.output / 'loop-exit.png')
    checks.append({'origin': [ox, oy], 'quadrants': sorted(quadrants), 'paths': sorted(paths), 'trace': trace})
(args.output / 'loops.json').write_text(json.dumps({'pal': args.pal, 'player': args.player, 'checks': checks}, indent=2))
g.close()
print('GHZ4 loop: all quadrants, both collision paths, grounded exit.')
