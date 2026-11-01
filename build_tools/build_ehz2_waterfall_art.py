#!/usr/bin/env python3
"""Bake PP Present's palette-driven waterfalls into fixed-palette tile frames.

Source pixels and cycle: sonicretro/scddisasm
f8cf3f0af7bf419d18182ba98554f09307ad3cc6, upright panel at Y $600.
The editable source bank keeps original PP indices. No image quantization is used.
"""
from pathlib import Path
import argparse
import struct
from sprite_palette import remap_pixels

ROOT = Path(__file__).resolve().parents[1]
# Original PP colors 1/2/3, in their original three palette phases.
PP_CYCLE = ((0xEEE, 0xEEA, 0xCC6),
			(0xCC6, 0xEEE, 0xEEA),
			(0xEEA, 0xCC6, 0xEEE))
PP_TO_P2 = {0: 0, 1: 2, 2: 10, 3: 11, 5: 7, 6: 6,
			7: 5, 8: 3, 9: 1, 13: 9, 14: 8, 15: 13}
CYAN_SLOTS = {0xEEE: 2, 0xEEA: 10, 0xCC6: 11}


def bake(source):
	assert source and len(source) % 32 == 0
	colors = {v for b in source for v in (b >> 4, b & 15)}
	assert colors <= PP_TO_P2.keys(), colors
	frames = []
	for phase in PP_CYCLE:
		lookup = [PP_TO_P2.get(i, 0) for i in range(16)]
		for i, color in enumerate(phase, 1):
			lookup[i] = CYAN_SLOTS[color]
		frames.append(remap_pixels(source, lookup))
	return b''.join(frames)


def outputs(source):
	# CD advances before displaying its first phase. Store its 1/2/0 order
	# for the palette script; the tile script selects the same frame order.
	cycle = b''.join(struct.pack('>3H', phase[1], phase[2], phase[0])
					for phase in (PP_CYCLE[1], PP_CYCLE[2], PP_CYCLE[0]))
	return {'art/uncompressed/EHZ2 Background Waterfall.unc': bake(source),
			'palette/EHZ2 PP Water.bin': cycle}


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--check', action='store_true')
	args = p.parse_args()
	source = (ROOT / 'art/uncompressed/EHZ2 Background Waterfall Source.unc').read_bytes()
	assert len(source) == 11 * 32
	for name, raw in outputs(source).items():
		path = ROOT / name
		if args.check:
			assert path.read_bytes() == raw, path
		else:
			path.write_bytes(raw)
	print('PP waterfalls: 11 tiles, 3 exact indexed poses, 352 bytes per update.')


if __name__ == '__main__':
	main()
