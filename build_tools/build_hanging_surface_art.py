#!/usr/bin/env python3
"""Pack editable FBZ handhold/chain art and their clipped display mappings.

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
    chain = (ROOT / 'art/uncompressed/Hanging chain.unc').read_bytes()
    assert len(chain) == 2 * 32, 'The repeated chain link is 8 by 16 pixels'
    rows = []
    for count in range(1, VISIBLE_MAX + 1):
        pieces = [(y, size, tile, 16 - count * 16 + grip * 32 - 8)
                  for grip in range(count)
                  for y, size, tile in ((-20, 5, 0), (-4, 6, 4))]
        rows.append(struct.pack('>H', len(pieces)) + b''.join(
            struct.pack('>bBHh', *piece) for piece in pieces))
    def mapping(rows):
        offset = len(rows) * 2
        pointers = []
        for row in rows:
            pointers.append(offset)
            offset += len(row)
        return struct.pack('>' + 'H' * len(rows), *pointers) + b''.join(rows)

    chain_rows = []
    # 0..14: visible links ending in the grip. 15..29: links only, while the
    # grip is below the viewport. A biased centre keeps all piece Ys signed.
    for grip, counts in ((True, range(15)), (False, range(1, 16))):
        for count in counts:
            bias = min(count * 8 + 20, 128) if grip else count * 8
            pieces = [(i * 16 - bias, 1, 10, -4) for i in range(count)]
            if grip:
                pieces += [(count * 16 - bias, 5, 0, -8),
                           (count * 16 + 16 - bias, 6, 4, -8)]
            chain_rows.append(struct.pack('>H', len(pieces)) + b''.join(
                struct.pack('>bBHh', *piece) for piece in pieces))
    return {
        ROOT / 'art/nemesis/Hanging surface.nem': nemesis_compress(raw + chain),
        ROOT / 'mappings/sprite/Hanging surface.bin': mapping(rows),
        ROOT / 'mappings/sprite/Pull chain.bin': mapping(chain_rows),
        ROOT / 'art/uncompressed/Pull chain.unc': raw + chain,  # editor atlas; edit the two sources above
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
