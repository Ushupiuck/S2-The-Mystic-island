#!/usr/bin/env python3
"""Pack the supplied miniature player sheets into the existing DPLC format."""

import argparse
from pathlib import Path
import struct

from PIL import Image

from sprite_art import find_tiles, pack_rectangles


ROOT = Path(__file__).resolve().parents[1]
# Palette roles follow SonicAndTails.bin. Fold Mania's extra highlight shades
# into the four shared blues and the four fur slots.
SONIC_COLORS = {
	(0, 0, 0): 1,
	(64, 0, 0): 15, (144, 0, 0): 14, (224, 0, 0): 13,
	(24, 88, 104): 9, (96, 160, 176): 8, (160, 224, 224): 7, (240, 240, 240): 6,
	(192, 104, 48): 2, (224, 144, 96): 3, (240, 176, 144): 4, (240, 208, 192): 5,
	(0, 0, 128): 12, (0, 56, 192): 11, (0, 104, 240): 10,
	(24, 136, 240): 10, (48, 160, 240): 10, (104, 208, 240): 10,
}
TAILS_COLORS = {
	(0, 0, 0): 1,
	(64, 0, 0): 15, (224, 0, 0): 13,
	(72, 72, 104): 9, (88, 112, 144): 9, (128, 160, 176): 8,
	(152, 192, 200): 8, (176, 208, 208): 7, (240, 240, 240): 6,
	(127, 3, 0): 2, (172, 26, 0): 2, (205, 79, 0): 3, (220, 120, 0): 4,
	(228, 142, 0): 4, (236, 166, 0): 5,
}


def pose(sheet, palette, row_y, column, center_y, angle):
	"""Remove the cell background and keep the foot/rotation origin fixed."""
	x = column * 49 + 1
	cell = sheet.crop((x, row_y + 4, x + 47, row_y + 44))
	background = cell.getpixel((0, 0))
	channels = cell.tobytes()
	raw = bytes(0 if rgb == background else palette[rgb]
		for rgb in zip(channels[::3], channels[1::3], channels[2::3]))
	pixels = Image.new('L', (80, 80))
	pixels.paste(Image.frombytes('L', cell.size, raw), (17, 44 - center_y))
	if angle:
		pixels = pixels.rotate(angle, resample=Image.Resampling.NEAREST, center=(40, 40))
	left, top, right, bottom = pixels.getbbox()
	width = (right - left + 7) // 8
	height = (bottom - top + 7) // 8
	assert 0 < width <= 4 and 0 < height <= 4
	tiles = []
	for tile_x in range(left, left + width * 8, 8):
		for tile_y in range(top, top + height * 8, 8):
			indices = pixels.crop((tile_x, tile_y, tile_x+8, tile_y+8)).tobytes()
			tiles.append(bytes(a << 4 | b for a, b in zip(indices[::2], indices[1::2])))
	return tuple(tiles), struct.pack('>bBHh', top-40, (width-1)<<2 | (height-1), 0, left-40)


def repeats(rows, start, size, row, column, angles=1, available=None, center=None):
	"""Map ordinary frame runs, including their existing slope groups."""
	available = available or size
	for direction in range(angles):
		for offset in range(size):
			rows[start + direction*size + offset] = (row, column + offset % available, center, direction*45)


def sonic_rows():
	rows = [(0, 0, None, 0)] * 251
	rows[0] = None
	repeats(rows, 2, 8, 0, 1, available=7)
	repeats(rows, 0xB, 2, 0, 8)
	repeats(rows, 0xD, 8, 1, 0, angles=4)
	repeats(rows, 0x2D, 4, 1, 14, angles=4)
	repeats(rows, 0x3D, 5, 2, 0, center=28)
	repeats(rows, 0x42, 6, 2, 15, available=4)
	repeats(rows, 0x48, 4, 3, 0)
	rows[0x4C:0x4E] = [(0, 15, None, 0), (0, 16, None, 0)]
	repeats(rows, 0x4E, 2, 3, 6, available=1)
	repeats(rows, 0x54, 6, 2, 8, available=5)
	repeats(rows, 0x5C, 2, 3, 7, available=1)
	for index in range(12):
		rows[0x5F+index] = (2, 8+index%5, 30, index*30)
	repeats(rows, 0xC8, 4, 3, 12)
	repeats(rows, 0xCC, 3, 3, 8)
	repeats(rows, 0xCF, 2, 3, 8)
	repeats(rows, 0xD1, 4, 2, 13, available=2)
	repeats(rows, 0xDA, 5, 2, 8)
	repeats(rows, 0xE2, 4, 1, 18, available=2)
	return rows


def tails_rows():
	rows = [(0, 0, None, 0)] * 251
	rows[0] = None
	repeats(rows, 1, 8, 1, 0, angles=4)
	repeats(rows, 0x21, 4, 1, 14, angles=4)
	repeats(rows, 0x86, 3, 2, 19)
	repeats(rows, 0x89, 2, 3, 6, available=1)
	repeats(rows, 0x8B, 2, 2, 12)
	repeats(rows, 0x96, 3, 1, 20, center=32)
	rows[0x99] = (0, 22, None, 0)
	repeats(rows, 0x9A, 2, 3, 8)
	rows[0x9C] = (3, 7, None, 0)
	repeats(rows, 0xA9, 4, 3, 0)
	repeats(rows, 0xAD, 3, 0, 0)
	rows[0xB0] = (0, 14, None, 0)
	repeats(rows, 0xB1, 4, 0, 4)
	repeats(rows, 0xB5, 8, 2, 12, available=5)
	repeats(rows, 0xBD, 5, 2, 0, available=2)
	rows[0xC2] = (2, 2, None, 0)
	repeats(rows, 0xC3, 2, 1, 18, angles=4)
	repeats(rows, 0xCB, 2, 2, 17)
	repeats(rows, 0xCD, 2, 2, 3)
	repeats(rows, 0xCF, 2, 2, 0)
	for index in range(12):
		rows[0xE0+index] = (2, 12+index%5, 34, index*30)
	repeats(rows, 0xEB, 3, 2, 12)
	return rows


def tail_rows():
	rows = [None] * 45
	repeats(rows, 1, 4, 4, 6, center=35)
	repeats(rows, 5, 4, 4, 0, angles=4, center=31)
	repeats(rows, 0x1A, 4, 4, 12, center=35)
	repeats(rows, 0x1E, 4, 4, 12, center=35)
	repeats(rows, 0x22, 5, 3, 16, center=34)
	repeats(rows, 0x29, 4, 4, 18, center=35)
	# The supplied miniature flight body frames already include the rotor.
	return rows


def offset_table(rows):
	result = bytearray(len(rows)*2)
	offsets = {}
	for index, row in enumerate(rows):
		if row not in offsets:
			offsets[row] = len(result)
			result.extend(row)
		struct.pack_into('>H', result, index*2, offsets[row])
	return bytes(result)


def build():
	sonic = Image.open(ROOT/'art/sources/Mania Mini Sonic.png').convert('RGB')
	tails = Image.open(ROOT/'art/sources/Mania Mini Tails.png').convert('RGB')
	banks = (
		('Mini Sonic', sonic, SONIC_COLORS, (21, 81, 141, 199), 30, sonic_rows()),
		('Mini Tails', tails, TAILS_COLORS, (20, 80, 140, 198, 256), 34, tails_rows()),
		('Mini Tails tails', tails, TAILS_COLORS, (20, 80, 140, 198, 256), 34, tail_rows()),
	)
	outputs = {}
	for name, sheet, colors, row_positions, center, rows in banks:
		poses = {key: pose(sheet, colors, row_positions[key[0]], key[1],
			center if key[2] is None else key[2], key[3]) for key in set(rows) if key is not None}
		bank = pack_rectangles(pattern for pattern, _ in poses.values())
		assert len(bank) <= 0x1000
		mappings, cues = [], []
		for key in rows:
			if key is None:
				mappings.append(b'\0\0')
				cues.append(b'\0\0')
				continue
			pattern, piece = poses[key]
			offset = find_tiles(bank, pattern)
			assert offset is not None and len(pattern) <= (9 if name.endswith('tails') else 16)
			mappings.append(b'\0\1' + piece)
			cues.append(struct.pack('>HH', 1, (len(pattern)-1)<<12 | offset))
		outputs[f'art/uncompressed/{name}.unc'] = b''.join(bank)
		outputs[f'mappings/sprite/{name}.bin'] = offset_table(mappings)
		outputs[f'mappings/spriteDPLC/{name}.bin'] = offset_table(cues)
		print(f'{name}: {len(poses)} poses using {len(bank)} tiles')
	return outputs


if __name__ == '__main__':
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument('--check', action='store_true')
	args = parser.parse_args()
	for name, data in build().items():
		path = ROOT/name
		if args.check:
			assert path.read_bytes() == data, name
		else:
			path.write_bytes(data)
