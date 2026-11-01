#!/usr/bin/env python3
"""Pack the editable EHZ waterfall object bank without changing its VRAM span."""
from pathlib import Path
import argparse
from import_scrap_madness import nemesis_compress

ROOT = Path(__file__).resolve().parents[1]


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--check', action='store_true')
	args = p.parse_args()
	raw = (ROOT / 'art/uncompressed/EHZ Waterfall.unc').read_bytes()
	assert len(raw) == 24 * 32
	colors = {v for b in raw for v in (b >> 4, b & 15)}
	assert colors == {0, 2, 3, 6, 10, 11}, colors
	packed = nemesis_compress(raw)
	target = ROOT / 'art/nemesis/Waterfall tiles.nem'
	if args.check:
		assert target.read_bytes() == packed, target
	else:
		target.write_bytes(packed)
	print('EHZ waterfall: 24 tiles; P1 cyan indices 2/3/A/B and white 6.')


if __name__ == '__main__':
	main()
