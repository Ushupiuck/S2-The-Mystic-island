#!/usr/bin/env python3
"""Adapt Sonic 2 final's EHZ chassis to its fixed sprite/palette-row-two roles.

Source: sonicretro/s2disasm 4ef457c18fc4902396c43ab06fabc119ac6ecb64.
The raw art outputs remain editable; normal builds only repack art.
Mappings remain the authoritative, directly editable geometry.
"""
from pathlib import Path
import argparse
import re
import struct

from build_end_art import pack_moduled
from import_ehz2_pp_background import nemesis

ROOT = Path(__file__).resolve().parents[1]
# The car body uses the primary sprite palette; drill/wheels use row two.
# The complete S1 pod, shared pilot and exhaust are deliberately not imported.
BANKS = (
	('EHZ boss', 'EHZ boss', 'EHZ Boss Ground', (0, 1, 1, 1, 1, 1, 1, 1)),
)
# Source RGB roles, never Mystic Island's old index permutation. Row-two C
# supplies S2's extra $666 metal shade; animated slots 2-5 remain unavailable.
TARGET_SLOTS = (
	{0: 1, 0xEEE: 6, 0xAAA: 7, 0x888: 8, 0x666: 8, 0x444: 9,
		0x8AE: 5, 0x46A: 2, 0x0AE: 4, 0x08E: 3, 0x00E: 13, 0x008: 14},
	{0: 1, 0xEEE: 6, 0xAAA: 7, 0x888: 8, 0x666: 12, 0x444: 9,
		0x0EE: 13, 0x088: 14, 0x044: 15},
)


def number(value):
	return int(value.strip().replace('$', '0x'), 0)


def mapping_tiles(name):
	text = (ROOT / f'mappings/sprite/{name}.asm').read_text()
	parts = re.split(r'(?m)^Map_\w+_Frame\d+:\s*dc.w\s+(\d+)\s*$', text)
	frames = []
	for count, body in zip(parts[1::2], parts[2::2]):
		pieces = re.findall(r'dc.b\s+([^\n]+)\n\s*dc.w\s+([^\n]+)', body)
		assert len(pieces) == int(count), name
		row = []
		for first, second in pieces:
			_, size = map(number, first.split(','))
			tile, _ = map(number, second.split(','))
			assert not tile & 0x6000, (name, tile)
			row.append((tile & 2047, ((size >> 2) + 1) * ((size & 3) + 1)))
		frames.append(row)
	return frames


def convert(raw, frames, roles, palettes):
	assert len(frames) == len(roles)
	owners = {}
	for row, role in zip(frames, roles):
		for first, count in row:
			assert (first + count) * 32 <= len(raw)
			for tile in range(first, first + count):
				owners.setdefault(tile, set()).add(role)
	result = bytearray()
	for tile in range(len(raw) // 32):
		source = raw[tile * 32:(tile + 1) * 32]
		variants = set()
		for role in owners.get(tile, {roles[0]}):
			def pixel(index):
				return TARGET_SLOTS[role][palettes[role][index]] if index else 0
			variants.add(bytes(pixel(b >> 4) << 4 | pixel(b & 15) for b in source))
		assert len(variants) == 1, ('A shared tile needs conflicting palette colors', tile)
		result.extend(variants.pop())
	return bytes(result)


def outputs(source):
	constants = (ROOT / '_definitions/s2.constants.asm').read_text()
	assert re.search(r'ArtTile_ArtNem_EHZBoss:\s*equ \$434\b', constants)
	palettes = [struct.unpack('>16H', (source / 'art/palettes/SonicAndTails.bin').read_bytes()),
		struct.unpack('>48H', (source / 'art/palettes/EHZ.bin').read_bytes())[:16]]
	files = {}
	for original, local, mapping, roles in BANKS:
		raw = nemesis((source / f'art/nemesis/{original}.nem').read_bytes())
		assert len(raw) == 128 * 32
		converted = convert(raw, mapping_tiles(mapping), roles, palettes)
		files[ROOT / f'art/uncompressed/{local}.unc'] = converted
		files[ROOT / f'art/moduled kosinski/{local}.kospm'] = pack_moduled(converted)
	return files


def main():
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument('--source', type=Path, required=True)
	parser.add_argument('--check', action='store_true', help='Verify the editable/packed outputs without writing')
	args = parser.parse_args()
	files = outputs(args.source)
	for path, data in files.items():
		if args.check:
			assert path.read_bytes() == data, path
		else:
			path.write_bytes(data)
	print('128 EHZ chassis tiles use fixed metal colors; row-two C holds the extra shade.')


if __name__ == '__main__':
	main()
