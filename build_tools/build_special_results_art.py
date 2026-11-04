#!/usr/bin/env python3
"""Build the results screen's own palette, emeralds and continue sprites.

The rotating stage keeps its own editable emerald sheet and palette. Results
use a dark blue backdrop, the shared player row, aligned gold/gray UI colors and two rows
of independent emerald ramps. The original results emerald sheet is the pixel
source; each color now owns four tiles instead of sharing incompatible slots.
"""
from pathlib import Path
import struct
from import_ehz2_pp_background import nemesis
from import_scrap_madness import nemesis_compress
from build_end_art import pack_moduled
from build_signpost_art import mapping_file
from build_hud_art import lettering
from convert_s1_ss_background import kosinski_plus_decode
from sprite_palette import PLAYER_FROM_S1, remap_pixels

ROOT = Path(__file__).resolve().parents[1]


def main():
	player = list(struct.unpack('>16H', (ROOT/'palette/SonicAndTails.bin').read_bytes()))
	player[0] = 0x200
	ui = player.copy()
	ui[13:16] = [0x0EE, 0x088, 0x044]
	# P2 keeps the existing blue shades at 2/3/4. Blue no longer needs 5;
	# previously unused 1/7 and released 5 supply cyan's intermediate shades.
	# Both gems share the dark-blue outline at 2 and white highlight at 6.
	gems = [
		[0x200,0xA60,0x822,0xC42,0xE66,0xEC4,0xEEE,0xEEA,
		 0x044,0x088,0x0CC,0x4EE,0x404,0x808,0xC4C,0xEAE],
		[0x200,0x222,0x040,0x080,0x0C6,0x8EA,0xEEE,0xECC,
		 0x004,0x008,0x00E,0x88E,0x444,0x888,0xAAA,0xECC],
	]
	# Source tile and its dark-to-light indices, destination row and indices.
	# Cyan duplicates blue's four source tiles, with its own palette indices.
	colors = (
		(4, (2,3,4,5,6), 0, (2,2,3,4,6)),
		(0, (10,11,12,13,14), 0, (8,9,10,11,6)),
		(4, (2,3,4,5,6), 0, (12,13,14,15,6)),
		(4, (2,3,4,5,6), 1, (2,3,4,5,6)),
		(8, (14,13,12,11,6), 1, (8,9,10,11,6)),
		(12, (9,8,7,6), 1, (12,13,14,6)),
		(4, (2,3,4,5,6), 0, (2,1,5,7,6)),
	)
	original = nemesis((ROOT/'art/Bonus & Special Stage/Bonus Stage Result Emeralds.nem').read_bytes())
	raw, rows = bytearray(), []
	for i, (tile, indices, line, destinations) in enumerate(colors):
		lookup = [0]*16
		for old, new in zip(indices, destinations):
			lookup[old] = new
		raw += remap_pixels(original[tile*32:(tile+4)*32], lookup)
		rows.append([(-8, 5, ((line+2)<<13) | i*4, -8)])
	(ROOT/'palette/Special Stage Results.bin').write_bytes(struct.pack('>64H',*(player+ui+gems[0]+gems[1])))
	(ROOT/'art/uncompressed/Results emeralds.unc').write_bytes(raw)
	(ROOT/'art/nemesis/Results emeralds.nem').write_bytes(nemesis_compress(raw))
	(ROOT/'mappings/sprite/SSR Emeralds.bin').write_bytes(mapping_file(rows))
	# Sonic is the unchanged S1 Continue Screen Stuff sheet; Tails is S2 art.
	# S1 E is dark red, while S2 E/F are orange. Keep their conversions distinct.
	continue_from_s2 = (0,1,12,11,10,10,6,7,8,9,5,2,13,14,4,3)
	def poses(filename, lookup, skip=0):
		packed = (ROOT/f'art/moduled kosinski/{filename}.kospm').read_bytes()
		raw = kosinski_plus_decode(packed[2:])[0][skip*32:]
		assert len(raw) == 12*32
		return remap_pixels(raw,lookup)
	sonic = poses('Mini Sonic Continue',PLAYER_FROM_S1,18)
	tails = poses('Mini Tails continue',continue_from_s2)
	text = lettering('CONTINUE',ink=13,width=72)
	for name, data in (('Sonic',text+sonic),('Tails',tails)):
		(ROOT/f'art/uncompressed/Results continue {name}.unc').write_bytes(data)
		(ROOT/f'art/moduled kosinski/Results continue {name}.kospm').write_bytes(pack_moduled(data))
	print('Independent results: navy/white/gold UI, seven four-tile emeralds, original animated continue sprites.')


if __name__ == '__main__':
	main()
