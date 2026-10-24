#!/usr/bin/env python3
"""Pack the editable 80-tile conveyor sheet, including its spiked platform."""
from pathlib import Path
import struct
from convert_s1_ss_background import kosinski_plus, kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]


def build():
    path = ROOT / 'art/moduled kosinski/LZ conveyor.unc'
    raw = path.read_bytes()
    assert len(raw) == 80 * 32, 'Four wheels, normal platform and spiked platform'
    packed = struct.pack('>H', len(raw)) + bytes(kosinski_plus(raw))
    packed += bytes(len(packed) & 1)
    assert kosinski_plus_decode(packed, 2)[0] == raw
    path.with_suffix('.kospm').write_bytes(packed)


if __name__ == '__main__':
    build()
