#!/usr/bin/env python3
"""Keep EHZ's reflected clouds fixed while P1's waterfall colors cycle.

The corrected animation uses the original terrain slots. Inverse index
rotations cancel the four palette phases; background deformation remains.
"""
from pathlib import Path
import argparse
import re
from sprite_palette import remap_pixels
from convert_s1_ss_background import kosinski_plus

ROOT = Path(__file__).resolve().parents[1]


def reflection_runs():
	constants = (ROOT / '_definitions/s2.constants.asm').read_text()
	def allocation(name):
		return int(re.search(r'^'+name+r':\s*equ\s+\$([0-9A-Fa-f]+)',constants,re.M)[1],16)
	return [(allocation(base), allocation(count)) for base, count in (
		('ArtTile_EHZ_Reflection1', 'ArtTile_EHZ_Reflection1_Count'),
		('ArtTile_EHZ_Reflection2', 'ArtTile_EHZ_Reflection2_Count'))]


def reflection_source():
	terrain = (ROOT / 'art/kosinski/level/8x8 - EHZ.unc').read_bytes()
	runs = reflection_runs()
	assert all((base + count) * 32 <= len(terrain) for base, count in runs)
	return b''.join(terrain[base*32:(base+count)*32] for base, count in runs)


def outputs():
	source = reflection_source()
	poses = []
	for phase in range(4):
		lookup = list(range(16))
		for i in range(2,6):
			lookup[i] = 2 + (i - 2 + phase) % 4
		poses.append(remap_pixels(source,lookup))
	terrain = (ROOT / 'art/kosinski/level/8x8 - EHZ.unc').read_bytes()
	return {'art/uncompressed/EHZ Reflections.unc': b''.join(poses),
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
	print('EHZ reflections: four inverse poses in the original 17 terrain slots.')


if __name__ == '__main__':
	main()
