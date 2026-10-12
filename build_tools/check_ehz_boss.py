#!/usr/bin/env python3
"""Check the built EHZ boss mappings, simultaneous art banks and capsule data.

With --s2disasm, compare every converted piece against an independently built
Sonic 2 final ROM and listing. No emulator or additional packages are required.
"""
from argparse import ArgumentParser
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
MAPS = (
    ('Map_EHZBoss_Vehicle', 'Nem_EggPod', 'Obj56_MapUnc_2FAF8'),
    ('Map_EHZBoss_Ground', 'Nem_EHZ_Boss', 'Obj56_MapUnc_2FA58'),
    ('Map_EHZBoss_Propeller', 'Nem_EggChopper', 'Obj56_MapUnc_2F970'),
    ('Map_BossExplosion', 'Nem_BossExplosion', 'Obj58_MapUnc_2D50A'),
)


def symbols(path):
    return {name: int(value, 16) for name, value in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', path.read_text())}


def pieces(rom, base, count, stride=6):
    result = []
    for frame in range(count):
        position = base + struct.unpack_from('>h', rom, base + frame * 2)[0]
        length = struct.unpack_from('>H', rom, position)[0]
        assert length <= 80
        row = []
        for i in range(length):
            position_i = position + 2 + i * stride
            y, size, tile = struct.unpack_from('>bBH', rom, position_i)
            x = struct.unpack_from('>h', rom, position_i + stride - 2)[0]
            assert size < 16
            row.append((y, size, tile, x))
        result.append(row)
    return result


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('--s2disasm', type=Path)
    args = parser.parse_args()
    rom = (ROOT / 's2built.bin').read_bytes()
    sym = symbols(ROOT / 'main.lst')
    art_tiles = lambda name: struct.unpack_from('>H', rom, sym[name])[0] & 0x7FFF
    cues = []
    for label in ('PLC_Boss', 'PLC_Capsule'):
        base = sym[label]
        count = struct.unpack_from('>H', rom, base)[0] + 1
        for i in range(count):
            source, dest = struct.unpack_from('>IH', rom, base + 2 + i * 6)
            length = (struct.unpack_from('>H', rom, source)[0] & 0x7FFF) * 32
            cues.append((label, dest, dest + length))

    # Both shield allocations exist in this engine. The EHZ-specific one is
    # still used during the fight, as are stars and the monitor/signpost bank.
    protected = [(sym['vram_fg'], 0x10000)]
    for tile, art in (
        ('ArtTile_Shield', 'Nem_Shield'),
        ('ArtTile_EHZ_Shield', 'Nem_Shield'),
        ('ArtTile_Invincibility', 'Nem_Stars'),
        ('ArtTile_Monitor', 'Nem_Monitors'),
    ):
        low = sym[tile] * 32
        protected.append((low, low + art_tiles(art) * 32))
    for label, low, high in cues:
        assert low % 32 == 0 and low < high <= 0x10000
        assert all(high <= a or low >= b for a, b in protected), (
            'Shared VRAM overwritten', label, hex(low), hex(high))
    for i, (_, low, high) in enumerate(cues):
        assert all(high <= a or low >= b for _, a, b in cues[:i]), (
            'Boss/capsule art overlap', hex(low), hex(high))

    total = 0
    stock = (args.s2disasm / 's2built.bin').read_bytes() if args.s2disasm else None
    stock_sym = symbols(args.s2disasm / 's2.lst') if stock else None
    for label, art, original in MAPS:
        frames = pieces(rom, sym[label], sym[label + '_frames'])
        for frame, row in enumerate(frames):
            for y, size, tile, x in row:
                width, height = ((size >> 2) + 1) * 8, ((size & 3) + 1) * 8
                assert (tile & 0x7FF) + width * height // 64 <= art_tiles(art), (label, frame)
                assert max(abs(x), abs(x + width)) <= sym[label + '_width']
                assert max(abs(y), abs(y + height)) <= sym[label + '_height']
        if stock:
            assert frames == pieces(stock, stock_sym[original], len(frames), 8), label
        total += len(frames)

    # This manager consumes six-byte records; preserve the sorted list and its
    # sentinel. The S1 capsule needs a separate button above its body.
    placements = (ROOT / 'level/objects/EHZ_2.bin').read_bytes()
    assert len(placements) % 6 == 0 and placements[-6:] == bytes.fromhex('FFFF00000000')
    records = list(struct.iter_unpack('>HHBB', placements[:-6]))
    assert [x for x, *_ in records] == sorted(x for x, *_ in records)
    capsule = [r for r in records if r[2] == sym['id_Obj3E'] and r[0] == 0x2B50]
    assert capsule == [(0x2B50, 0x422, sym['id_Obj3E'], 0),
                       (0x2B50, 0x3FA, sym['id_Obj3E'], 1)], capsule
    print(f'{total} boss/explosion mapping frames, {len(cues)} disjoint art banks '
          'and the capsule placements pass.')
    if stock:
        print('Every converted piece matches Sonic 2 final geometry and tile indices.')


if __name__ == '__main__':
    main()
