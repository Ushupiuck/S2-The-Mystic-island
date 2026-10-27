#!/usr/bin/env python3
"""Extract the existing primary-palette SMZ switch for optional act PLCs.

The atlas/mappings remain the editable sources. Only referenced unique tiles
are copied; SMZ continues using its resident atlas without an extra upload.
"""
from pathlib import Path
import struct
from import_scrap_madness import nemesis_compress

ROOT = Path(__file__).resolve().parents[1]


def main():
    art = (ROOT / 'art/uncompressed/SMZ Sprite Atlas.unc').read_bytes()
    mappings = bytearray((ROOT / 'mappings/sprite/SMZ But.bin').read_bytes())
    count = int.from_bytes(mappings[:2], 'big') // 2
    tiles, indices = [], {}
    for frame in range(count):
        offset = struct.unpack_from('>H', mappings, frame * 2)[0]
        pieces = struct.unpack_from('>H', mappings, offset)[0]
        for piece in range(pieces):
            pos = offset + 2 + piece * 6
            size, tile = struct.unpack_from('>BH', mappings, pos + 1)
            length = ((size >> 2) + 1) * ((size & 3) + 1)
            source = tile & 0x7FF
            key = art[source * 32:(source + length) * 32]
            assert len(key) == length * 32
            if key not in indices:
                indices[key] = len(tiles) // 32
                tiles.extend(key)
            struct.pack_into('>H', mappings, pos + 2, (tile & 0xF800) | indices[key])
    raw = bytes(tiles)
    (ROOT / 'art/uncompressed/Platform button.unc').write_bytes(raw)
    (ROOT / 'art/nemesis/Platform button.nem').write_bytes(nemesis_compress(raw))
    (ROOT / 'mappings/sprite/Platform button.bin').write_bytes(mappings)
    print('Portable button:', len(raw) // 32, 'tiles; existing primary palette')


if __name__ == '__main__':
    main()
