#!/usr/bin/env python3
"""Check S1 REV01 parallax and visible SMZ background tiles in real emulation.

Uses the imported editable geometry as the tilemap oracle. Camera sweeps freeze
the lead actor at successive targets; the game still scrolls, streams, animates,
and hands Word RAM between CPUs normally. These are not full playthroughs.
"""
from pathlib import Path
from functools import lru_cache
import argparse
import ctypes as C
import json
import struct

from genesis_test_core import Genesis
from check_object_course import boot_level
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
for name in ('rom', 'listing', 'core', 'output'):
    p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--system-directory', type=Path)
p.add_argument('--pal', action='store_true')
p.add_argument('--player', type=int, choices=(0, 2), default=0)
args = p.parse_args()
g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
            system_directory=args.system_directory)
vsram = (C.c_uint8 * 128).in_dll(g.core, 'vsram')
chunks = (ROOT / 'mappings/128x128/SMZ.unc').read_bytes()
blocks = (ROOT / 'mappings/16x16/SMZ.unc').read_bytes()
rom = args.rom.read_bytes()
report = []
tile_samples = scroll_samples = 0


def word(memory, address):
    return (memory[address ^ 1] << 8) | memory[(address + 1) ^ 1]


def camera():
    return (-word(g.vram, g.s['vram_hscroll'])) & 0xFFFF, word(vsram, 0) & 0x7FF


for act in (0, 1):
    boot_level(g, zone=g.s['id_SMZ'], act=act, player=args.player)
    start_x, start_y = struct.unpack_from('>HH', rom,
        g.s['StartLocArray'] + g.s['id_SMZ'] * 16 + act * 4)
    assert start_x <= 160, 'Reference X origin assumes the original left-edge start'
    initial_y = max(0, min(0x720, start_y - 96))
    initial_bg_y = ((initial_y & 0x7F8) >> 3) + 1
    layout = kosinski_plus_decode((ROOT / f'level/layout/SMZ_{act + 1}.kosp').read_bytes())[0]

    @lru_cache(maxsize=None)
    def tile(tx, ty):
        chunk = layout[(ty // 16 & 15) * 256 + 128 + (tx // 16 & 127)]
        entry = struct.unpack_from('>H', chunks, chunk * 128 +
            ((ty // 2 & 7) * 8 + (tx // 2 & 7)) * 2)[0]
        x, y = (tx & 1) ^ bool(entry & 0x400), (ty & 1) ^ bool(entry & 0x800)
        value = struct.unpack_from('>H', blocks, (entry & 0x3FF) * 8 + (y * 2 + x) * 2)[0]
        return value ^ (0x800 if entry & 0x400 else 0) ^ (0x1000 if entry & 0x800 else 0)

    def check(full=False):
        global tile_samples, scroll_samples
        assert not g.read('v_errortype'), ('CPU exception', act, g.frame)
        fg_x, fg_y = camera()
        bg_y = word(vsram, 2) & 0x7FF
        expected_y = (initial_bg_y + (fg_y - initial_y) // 8) & 0x7FF
        assert bg_y == expected_y, ('BG vertical parallax', act + 1, g.frame,
                                   (fg_x, fg_y), bg_y, expected_y)
        for sy in (*range(0, 224, 8), 223):
            wy = (bg_y + sy) & 0x7FF
            row = (wy & 0x1FF) // 16
            if act:
                expected_scroll = -(fg_x // 4)
            elif row < 4:
                near = (-fg_x) >> 2
                step = ((near >> 1) - near) << 13
                expected_scroll = near + (row * step >> 16)
            else:
                numerator = 2 if row < 14 else 3 if row < 21 else 4
                expected_scroll = -(fg_x * numerator // 8)
            scroll = word(g.vram, g.s['vram_hscroll'] + sy * 4 + 2)
            assert scroll == expected_scroll & 0xFFFF, (
                'BG horizontal parallax', act + 1, g.frame, sy, fg_x, bg_y,
                scroll, expected_scroll & 0xFFFF)
            scroll_samples += 1
            if not full and g.frame % 4:
                continue
            signed_scroll = scroll if scroll < 0x8000 else scroll - 0x10000
            for sx in (*range(0, 320, 8), 319):
                wx = (sx - signed_scroll) & 0xFFFF
                # Cloud rows are drawn across the full fixed 512-pixel plane.
                source_x = wx & 0x1FF if act == 0 and row < 4 else wx
                expected = tile(source_x // 8, wy // 8)
                address = g.s['vram_bg'] + ((wy & 0xFF) // 8) * 128 + ((wx & 0x1FF) // 8) * 2
                actual = word(g.vram, address)
                assert actual == expected, ('Stale/wrong background tile', act + 1,
                    g.frame, (fg_x, fg_y), (sx, sy), (source_x, wy),
                    hex(actual), hex(expected))
                tile_samples += 1

    g.video.save(args.output / f'act-{act + 1}-start.png')
    check(True)
    # Ordinary controller input before the diagnostic camera excursion.
    for buttons, frames in (({7}, 32), ({6}, 32), (set(), 24)):
        g.buttons = buttons
        for _ in range(frames):
            g.run()
            check()
    g.buttons = set()
    targets = []
    for index, (tx, ty) in enumerate(((0, 0), (0xC00, 0), (0xC00, 0x720),
                                      (0, 0x720), (0, 0))):
        stable = 0
        previous = None
        for frames in range(800):
            for field, value, size in (
                    ('obX', tx + 160, 2), ('obY', ty + g.s['Camera_LookCenter'], 2),
                    ('obVelX', 0, 2), ('obVelY', 0, 2), ('obInertia', 0, 2),
                    ('obControl', 0x81, 1), ('obRoutine', 2, 1), ('obStatus', 0, 1),
                    ('invtime', 6000, 2)):
                g.put('v_player', field, value, size)
            g.write('Camera_Min_Y_pos', 0, 2)
            g.write('Camera_Max_Y_pos', 0x720, 2)
            g.write('Camera_Max_Y_pos_target', 0x720, 2)
            g.run()
            check()
            current = camera()
            stable = stable + 1 if current == previous else 0
            previous = current
            if abs(current[0] - tx) <= 16 and abs(current[1] - ty) <= 16 and stable >= 5:
                break
        else:
            raise AssertionError(('Camera sweep did not settle', act + 1, tx, ty, camera()))
        check(True)
        g.video.save(args.output / f'act-{act + 1}-sweep-{index}.png')
        targets.append({'target': [tx, ty], 'camera': list(camera()), 'frames': frames + 1})
    g.buttons = {3}; g.run(); g.buttons = set(); g.run(5)
    assert g.read('f_pause', 2), 'Pause did not engage'
    for _ in range(20):
        g.run()
        check()
    g.buttons = {3}; g.run(); g.buttons = set(); g.run(5)
    assert not g.read('f_pause', 2), 'Pause did not release'
    check(True)
    report.append({'act': act + 1, 'targets': targets})
    print(f'SMZ {act + 1}: parallax, visible tiles, both scroll directions, vertical bands and pause pass.', flush=True)
    if not act:
        g.write('v_gamemode', g.s['SegaScreen'], 2)
        g.run()

result = {'pal': args.pal, 'player': args.player, 'scroll_samples': scroll_samples,
          'tile_samples': tile_samples, 'checks': report}
(args.output / 'report.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k != 'checks'}), flush=True)
g.close()
