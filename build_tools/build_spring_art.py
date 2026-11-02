#!/usr/bin/env python3
"""Pack editable spring banks; red/yellow caps share pixels and select a line.

The straight caps use Sonic CD's drawing; the mechanisms and diagonal shape
retain S3&K's geometry. All caps use the same three red/yellow shades and white.
The historic * S3.unc filenames remain editable sources.
"""
from pathlib import Path
import argparse
from import_scrap_madness import nemesis_compress

ROOT = Path(__file__).resolve().parents[1]


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--check', action='store_true')
	args = p.parse_args()
	for name, count in (('Vertical', 12), ('Horizontal', 12), ('Diagonal', 18)):
		raw = (ROOT / f'art/uncompressed/{name} spring S3.unc').read_bytes()
		assert len(raw) == count * 32
		colors = {v for b in raw for v in (b >> 4, b & 15)}
		assert colors <= {0, 1, 6, 7, 8, 9, 13, 14, 15}, (name, colors)
		cap_tiles = 10 if name == 'Diagonal' else 4
		cap_colors = {v for b in raw[:cap_tiles * 32] for v in (b >> 4, b & 15)}
		assert {13, 14, 15} <= cap_colors <= {0, 1, 6, 13, 14, 15}, (name, 'cap shades', cap_colors)
		target = ROOT / f'art/nemesis/{name} spring.nem'
		packed = nemesis_compress(raw)
		if args.check:
			assert target.read_bytes() == packed, target
		else:
			target.write_bytes(packed)
	print('Springs: 42 resident tiles; cap art shared by both colors (formerly 60).')


if __name__ == '__main__':
	main()
