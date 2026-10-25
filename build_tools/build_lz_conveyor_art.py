#!/usr/bin/env python3
"""Build the compact resident conveyor bank and shared wheel DPLC source."""
from pathlib import Path
import struct
from convert_s1_ss_background import kosinski_plus, kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]


def build():
    path = ROOT / 'art/moduled kosinski/LZ conveyor.unc'
    raw = path.read_bytes()
    assert len(raw) == 80 * 32, 'Four wheels, normal platform and spiked platform'
    # One wheel plus both platforms in VRAM; all four wheel frames stream from ROM.
    resident = raw[:16 * 32] + raw[64 * 32:]
    packed = struct.pack('>H', len(resident)) + bytes(kosinski_plus(resident))
    packed += bytes(len(packed) & 1)
    assert kosinski_plus_decode(packed, 2)[0] == resident
    path.with_suffix('.kospm').write_bytes(packed)
    (ROOT / 'art/uncompressed/LZ conveyor wheels.unc').write_bytes(raw[:64 * 32])


if __name__ == '__main__':
    build()
