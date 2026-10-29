#!/usr/bin/env python3
"""Rebuild underwater character colors from the live shared palette.

HPZ retains its violet cast; LZ4 retains its pink cast. Their lower two authored
level rows stay editable. GHZ4's separate generator tints all four GHZ rows.
"""
from pathlib import Path
import struct
import argparse

ROOT = Path(__file__).resolve().parents[1]


def tint(raw, cast):
    result = []
    for word, in struct.iter_unpack('>H', raw):
        # Work in the VDP's 0..7 channels, blend 25%, round once.
        channels = [(word >> shift) & 7 for shift in (1, 5, 9)]
        result.append(sum(((3*c+t+2)//4) << shift
                          for c, t, shift in zip(channels, cast, (1, 5, 9))))
    result[0] = 0  # Sprite transparency; the scene owns its backdrop.
    return struct.pack('>16H', *result)


def lz_palette():
    """Transfer S1 LZ's authored color changes to current FG and TT scenery."""
    def words(path):
        raw = (ROOT / path).read_bytes()
        return list(struct.unpack('>'+str(len(raw)//2)+'H', raw))
    normal = words('palette/sources/S1 Sonic.bin') + words('palette/sources/S1 LZ.bin')
    water = words('palette/sources/S1 LZ Underwater.bin')
    current = words('palette/SonicAndTails.bin') + words('palette/LZ.bin')
    def rgb(w):
        return tuple(w >> sh & 7 for sh in (1,5,9))
    result = []
    for line in range(4):
        old = normal[line*16:(line+1)*16]
        below = water[line*16:(line+1)*16]
        for slot, value in enumerate(current[line*16:(line+1)*16]):
            color = rgb(value)
            nearest = min(range(1,16), key=lambda i: sum((a-b)**2 for a,b in zip(color,rgb(old[i]))))
            adapted = [min(7,max(0,c+b-a)) for c,a,b in zip(color,rgb(old[nearest]),rgb(below[nearest]))]
            result.append(sum(c << sh for c,sh in zip(adapted,(1,5,9))))
    # These are semantic shared ramps, independent of nearest-color ties.
    for slot in (1,6,7,8,9):
        result[16+slot] = result[slot]
    for slot in (13,14,15):
        source_slot = slot-1
        result[16+slot] = water[16+source_slot]
    result[0] = water[0]
    return struct.pack('>64H',*result)


def outputs():
    source = (ROOT / 'palette/SonicAndTails.bin').read_bytes()
    for main, legacy, cast in (
            ('HPZ Underwater.bin', 'HPZ Sonic Underwater.bin', (2, 0, 7)),
            ('LZ4 Underwater.bin', 'LZ4 Sonic Underwater.bin', (6, 0, 6))):
        colors = tint(source, cast)
        old = (ROOT / 'palette' / main).read_bytes()
        act = 'HPZ' if main.startswith('HPZ') else 'LZ4'
        secondary = tint((ROOT / f'palette/{act}.bin').read_bytes()[:32], cast)
        secondary = old[32:34] + secondary[2:]
        yield ROOT / 'palette' / main, colors + secondary + old[64:]
        yield ROOT / 'palette' / legacy, colors
    labyrinth = lz_palette()
    yield ROOT / 'palette/LZ Underwater.bin', labyrinth
    yield ROOT / 'palette/LZ Sonic Underwater.bin', labyrinth[:32]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check', action='store_true')
    args = p.parse_args()
    for path, data in outputs():
        if args.check:
            assert path.read_bytes() == data, path
        else:
            path.write_bytes(data)
    print('Underwater character rows regenerated from the live player palette.')


if __name__ == '__main__':
    main()
