#!/usr/bin/env python3
"""Adapt the original lives portrait to the shared player palette.

The source already uses the shared slot order. Merge its legacy extra
blue (now $F) into blue $A; lit shoes use red $D, shadow corners red $E.
"""
from pathlib import Path
from import_scrap_madness import nemesis_inline

ROOT = Path(__file__).resolve().parents[1]

def build():
    raw = bytearray((ROOT/'art/uncompressed/Sonic Lives Source.unc').read_bytes())
    assert len(raw) == 12*32
    for i, value in enumerate(raw[:4*32]):
        hi, lo = value >> 4, value & 15
        raw[i] = (10 if hi == 15 else hi) << 4 | (10 if lo == 15 else lo)
    for x, y in ((7, 13), (12, 13), (8, 14), (9, 14), (10, 14)):
        offset = ((x//8)*2+y//8)*32+(y%8)*4+(x%8)//2
        shift = 0 if x & 1 else 4
        assert raw[offset] >> shift & 15 == 14
        raw[offset] = raw[offset] & ~(15 << shift) | 13 << shift
    (ROOT/'art/nemesis/Sonic lives counter.nem').write_bytes(nemesis_inline(raw))

if __name__ == '__main__':
    build()
