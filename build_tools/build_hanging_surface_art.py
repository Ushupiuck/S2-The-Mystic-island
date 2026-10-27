#!/usr/bin/env python3
"""Pack the editable FBZ handhold and generate the 1..11 visible-row mappings.

The controller clips its full 1..63 grip span to the viewport before choosing
a mapping. Every grip reuses the same ten resident tiles / two VDP sprites.
The raw source retains FBZ's tile order, remapped to the shared gray palette.
"""
from argparse import ArgumentParser
from pathlib import Path
import struct
from import_scrap_madness import nemesis_compress

ROOT = Path(__file__).resolve().parents[1]
VISIBLE_MAX = 11


def generate():
    raw = (ROOT / 'art/uncompressed/Hanging surface.unc').read_bytes()
    assert len(raw) == 10 * 32, 'Keep the two-piece FBZ handhold tile order'
    rows = []
    for count in range(1, VISIBLE_MAX + 1):
        pieces = [(y, size, tile, 16 - count * 16 + grip * 32 - 8)
                  for grip in range(count)
                  for y, size, tile in ((-20, 5, 0), (-4, 6, 4))]
        rows.append(struct.pack('>H', len(pieces)) + b''.join(
            struct.pack('>bBHh', *piece) for piece in pieces))
    offset = len(rows) * 2
    pointers = []
    for row in rows:
        pointers.append(offset)
        offset += len(row)
    mapping = struct.pack('>' + 'H' * len(rows), *pointers) + b''.join(rows)
    return {
        ROOT / 'art/nemesis/Hanging surface.nem': nemesis_compress(raw),
        ROOT / 'mappings/sprite/Hanging surface.bin': mapping,
    }


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for path, data in generate().items():
        if args.check:
            assert path.read_bytes() == data, 'Regenerate ' + str(path.relative_to(ROOT))
        else:
            path.write_bytes(data)
        print(path.relative_to(ROOT))


if __name__ == '__main__':
    main()
