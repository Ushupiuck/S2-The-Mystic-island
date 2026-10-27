#!/usr/bin/env python3
"""Tint GHZ4's four underwater palette lines and its waterfall animation.

Editable sources remain SonicAndTails.bin, GHZ.bin and GHZ Water.bin.
Blend 25% teal (RGB 0/6/7 in the MD's 0-7 channel range), then quantize.
"""
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def tint(data):
    result = []
    for word, in struct.iter_unpack('>H', data):
        r, g, b = ((word >> shift) & 7 for shift in (1, 5, 9))
        rgb = ((3*r+2)//4, (3*g+6+2)//4, (3*b+7+2)//4)
        result.append(sum(value << shift for value, shift in zip(rgb, (1, 5, 9))))
    return struct.pack('>' + 'H'*len(result), *result)


def main():
    normal = (ROOT/'palette/SonicAndTails.bin').read_bytes()[:32] + (ROOT/'palette/GHZ.bin').read_bytes()
    assert len(normal) == 128
    for source, dest in ((normal, 'GHZ4 Underwater.bin'), ((ROOT/'palette/GHZ Water.bin').read_bytes(), 'GHZ4 Underwater Cycle.bin')):
        (ROOT/'palette'/dest).write_bytes(tint(source))
    print('GHZ4 underwater: 64 colors plus four matching waterfall phases')


if __name__ == '__main__':main()
