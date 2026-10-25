#!/usr/bin/env python3
"""Import Kemusi's four original frames and adapt its QQ colors to SMZ.

Source: sonicretro/scddisasm test, 791253ba1922d7c4142a40975860d1b3bb37b9f7.
Requires the optional Unicorn dependency used by pack_scrap_sprites.py; the
assembled game's Nemesis decoder supplies the original indexed art.
"""
from pathlib import Path
import argparse
import re
import struct

from import_scrap_madness import nemesis_inline, palette_lookup, remap_pixels

ROOT = Path(__file__).resolve().parents[1]


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--source', type=Path, required=True)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	args = p.parse_args()
	import native_test_core as m68k
	m = m68k.Native(args.rom, args.listing)
	packed = (args.source/'src/gfx/r5/kemusi.nem').read_bytes()
	assert int.from_bytes(packed[:2], 'big') & 0x7FFF == 22
	m.cpu.mem_write(0x300000, packed)
	m.act('NemDecToRAM', limit=2000000, regs={
		m68k.UC_M68K_REG_A0: 0x300000, m68k.UC_M68K_REG_A4: 0xFF0000})
	raw = bytes(m.cpu.mem_read(0xFF0000, 22*32))
	source = struct.unpack('>16H', (args.source/'src/palettes/r5/inside_a.pal').read_bytes()[:32])
	target = struct.unpack('>16H', (ROOT/'palette/SMZ2.bin').read_bytes()[:32])
	lookup = palette_lookup(source, target)
	# Keep the three magenta shades distinct, and retain the S3 gray ramp.
	lookup[5], lookup[10], lookup[11] = 2, 4, 5
	raw = remap_pixels(raw, lookup)
	(ROOT/'art/uncompressed/Enemy Kemusi.unc').write_bytes(raw)
	(ROOT/'art/nemesis/Enemy Kemusi.nem').write_bytes(nemesis_inline(raw))

	source = (args.source/'src/sprites/r5/kemusi.asm').read_text()
	rows = re.findall(r'\.Sprite\d+:\s*dc.b\s*1\s*dc.b\s*([^\n]+)', source)
	assert len(rows) == 4
	data = bytearray(8)
	for frame, row in enumerate(rows):
		v = [int(n.strip()[1:], 16) if n.strip().startswith('$') else int(n.strip()) for n in row.split(',')]
		y, size, hi, lo, x = v
		assert hi == 0 and size in (5, 6)
		struct.pack_into('>H', data, frame*2, len(data))
		data += struct.pack('>HbBHh', 1, y-256 if y >= 128 else y, size, hi*256+lo, x-256 if x >= 128 else x)
	(ROOT/'mappings/sprite/Kemusi.bin').write_bytes(data)
	print('Imported 22 tiles and four original sprite rectangles; palette lookup:', lookup)


if __name__ == '__main__':
	main()
