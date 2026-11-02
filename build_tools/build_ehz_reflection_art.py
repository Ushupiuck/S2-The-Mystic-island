#!/usr/bin/env python3
"""Keep EHZ's reflected clouds fixed while P1's waterfall colors cycle.

Source pixels keep the grouped P1 indices. Inverse index rotations cancel
the four palette phases exactly; the existing background deformation remains.
"""
from pathlib import Path
import argparse
import re
from sprite_palette import remap_pixels
from convert_s1_ss_background import kosinski_plus

ROOT = Path(__file__).resolve().parents[1]


def outputs():
	constants = (ROOT / '_definitions/s2.constants.asm').read_text()
	def allocation(name):
		return int(re.search(r'^'+name+r':\s*equ\s+\$([0-9A-Fa-f]+)',constants,re.M)[1],16)
	base = allocation('ArtTile_EHZ_Reflection')
	count = allocation('ArtTile_EHZ_Reflection_Count')
	source = (ROOT / 'art/uncompressed/EHZ Reflections Source.unc').read_bytes()
	assert len(source) == count * 32 and base + count <= 0x394
	poses = []
	for phase in range(4):
		lookup = list(range(16))
		for i in range(2,6):
			lookup[i] = 2 + (i - 2 + phase) % 4
		poses.append(remap_pixels(source,lookup))
	terrain = bytearray((ROOT / 'art/kosinski/level/8x8 - EHZ.unc').read_bytes())
	if len(terrain) < (base + count) * 32:
		terrain.extend(bytes((base + count) * 32 - len(terrain)))
	terrain[base*32:(base+count)*32] = source
	return {'art/uncompressed/EHZ Reflections.unc': b''.join(poses),
			'art/kosinski/level/8x8 - EHZ.unc': bytes(terrain),
			'art/kosinski/level/8x8 - EHZ.kosp': kosinski_plus(terrain)}


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--check',action='store_true')
	args = p.parse_args()
	for name,raw in outputs().items():
		path = ROOT / name
		if args.check:
			assert path.read_bytes() == raw,path
		else:
			path.write_bytes(raw)
	print('EHZ reflections: 17 tiles, four inverse poses; no additional palette colors.')


if __name__ == '__main__':
	main()
