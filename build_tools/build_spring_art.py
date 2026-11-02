#!/usr/bin/env python3
"""Pack the editable shared spring atlas; caps select red/yellow per piece.

The straight caps use Sonic CD's drawing; the mechanisms and diagonal shape
retain S3&K's geometry. All caps use the same three red/yellow shades and white.
Springs.unc contains vertical (12), horizontal (12), diagonal (18), then
Sonic CD's static back support (4). The support is a separate VDP sprite,
referenced by every diagonal pose rather than baked into the moving art.
"""
from pathlib import Path
import argparse
from import_scrap_madness import nemesis_compress

ROOT = Path(__file__).resolve().parents[1]


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--check', action='store_true')
	args = p.parse_args()
	raw = (ROOT / 'art/uncompressed/Springs.unc').read_bytes()
	assert len(raw) == 46 * 32
	for name, first, count in (('Vertical', 0, 12), ('Horizontal', 12, 12), ('Diagonal', 24, 18)):
		bank = raw[first * 32:(first + count) * 32]
		colors = {v for b in bank for v in (b >> 4, b & 15)}
		assert colors <= {0, 1, 6, 7, 8, 9, 13, 14, 15}, (name, colors)
		cap_tiles = 10 if name == 'Diagonal' else 4
		cap_colors = {v for b in bank[:cap_tiles * 32] for v in (b >> 4, b & 15)}
		assert {13, 14, 15} <= cap_colors <= {0, 1, 6, 13, 14, 15}, (name, 'cap shades', cap_colors)
	assert {v for b in raw[42 * 32:] for v in (b >> 4, b & 15)} <= {0, 1, 6, 8, 9}
	target = ROOT / 'art/nemesis/Springs.nem'
	packed = nemesis_compress(raw)
	if args.check:
		assert target.read_bytes() == packed, target
	else:
		target.write_bytes(packed)
	print('Springs: 46 contiguous tiles (12 vertical, 12 horizontal, 18 diagonal, 4 shared support).')


if __name__ == '__main__':
	main()
