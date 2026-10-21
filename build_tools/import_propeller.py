#!/usr/bin/env python3
"""Import Metallic Madness's propeller obstacle from scddisasm test.

Source: sonicretro/scddisasm, 791253ba1922d7c4142a40975860d1b3bb37b9f7.
Preserves the source pixels and flips. Three repeated shaft tiles let the
mast use four hardware sprites instead of nine. Palette 0 is adapted to the
common player palette; no runtime palette swap is needed.
Requires the optional Unicorn dependency used by the other CD importers.
"""
from pathlib import Path
import argparse
import struct

from import_palmtree_enemies import mapping
from import_scrap_madness import nemesis_inline, palette_lookup, remap_pixels

ROOT = Path(__file__).resolve().parents[1]


def pixels(art, pieces):
	"""Independent pixel oracle for the original and combined rectangles."""
	out = {}
	for y, size, tile, x in pieces:
		w, h = (size >> 2)+1, (size & 3)+1
		for px in range(w*8):
			for py in range(h*8):
				tx = w*8-1-px if tile & 0x800 else px
				ty = h*8-1-py if tile & 0x1000 else py
				offset = ((tile & 0x7FF)+(tx//8)*h+ty//8)*32+(ty%8)*4+tx%8//2
				color = (art[offset] >> (0 if tx & 1 else 4)) & 15
				if color: out[x+px, y+py] = color
	return out


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--source', type=Path, required=True)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'main.lst')
	args = p.parse_args()
	import native_test_core as m68k
	m = m68k.Native(args.rom, args.listing)
	packed = (args.source/'src/gfx/r8/propeller.nem').read_bytes()
	assert int.from_bytes(packed[:2], 'big') & 0x7FFF == 46
	m.cpu.mem_write(0x300000, packed)
	m.act('NemDecToRAM', limit=2000000, regs={
		m68k.UC_M68K_REG_A0: 0x300000, m68k.UC_M68K_REG_A4: 0xFF0000})
	raw = bytes(m.cpu.mem_read(0xFF0000, 46*32))
	source = struct.unpack('>16H', (args.source/'src/palettes/player.pal').read_bytes())
	target = struct.unpack('>16H', (ROOT/'palette/SonicAndTails.bin').read_bytes()[:32])
	lookup = palette_lookup(source, target)
	raw = remap_pixels(raw, lookup)
	optimized = raw+raw[-32:]*3
	(ROOT/'art/uncompressed/MM Propeller.unc').write_bytes(optimized)
	(ROOT/'art/nemesis/MM Propeller.nem').write_bytes(nemesis_inline(optimized))
	for part in ('base', 'blade'):
		data = mapping((args.source/f'src/sprites/r8/propeller_{part}.asm').read_text(), '.Sprites')
		if part == 'base':
			from check_sprite_assets import frames
			original = frames(data)
			result = bytearray(4)
			for i, pieces in enumerate(original):
				assert pieces[:7] == [(y, 0, 45, -4) for y in range(-40, 16, 8)]
				combined = [(-40, 3, 45, -4), (-8, 2, 45, -4)]+pieces[7:]
				assert pixels(raw, pieces) == pixels(optimized, combined)
				struct.pack_into('>H', result, i*2, len(result))
				result += struct.pack('>H', len(combined))
				result += b''.join(struct.pack('>bBHh', *piece) for piece in combined)
			data = result
		(ROOT/f'mappings/sprite/MM Propeller {part}.bin').write_bytes(data)
	print('Imported 49 propeller tiles; mast 9 -> 4 sprites, pixel-identical; palette:', lookup)


if __name__ == '__main__':
	main()
