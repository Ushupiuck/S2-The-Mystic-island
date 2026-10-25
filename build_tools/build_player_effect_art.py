#!/usr/bin/env python3
"""Pack Mode 1's shield, invincibility and ring RAM sources as Nemesis art.

The uncompressed files remain the editable sources, including SonLVL's rings.
Run after editing those files; --check verifies the committed packed copies.
The legacy Shield.nem is unrelated and is deliberately left alone.
"""
from argparse import ArgumentParser
from pathlib import Path

from import_scrap_madness import nemesis_compress

ROOT = Path(__file__).resolve().parents[1]
ASSETS = (
    ('Shield.unc', 'Shield Dynamic.nem'),
    ('Invincibility.unc', 'Invincibility.nem'),
    ('Ring.bin', 'Ring.nem'),
)


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    raw_total = packed_total = 0
    for source, target in ASSETS:
        raw = (ROOT / 'art/uncompressed' / source).read_bytes()
        packed = nemesis_compress(raw)
        path = ROOT / 'art/nemesis' / target
        if args.check:
            assert path.read_bytes() == packed, f'Repack {source} with {Path(__file__).name}'
        else:
            path.write_bytes(packed)
        raw_total += len(raw)
        packed_total += len(packed)
        print(f'{source}: ${len(raw):X} -> ${len(packed):X} bytes')
    print(f'Total: ${raw_total:X} -> ${packed_total:X} bytes')


if __name__ == '__main__':
    main()
