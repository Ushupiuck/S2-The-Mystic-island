#!/usr/bin/env python3
"""Build the shared Sonic 1 checkpoint/time-pole body and its head variants.

Editable art: Checkpoint.unc (pole 6, blue 2, red 2, yellow 2) and
the MMZ atlas/mappings (CD PAST 8, FUTURE 8, thin 4, edge 2). S1 source revision
2c51d46a0b0682133834db2093292d41da872ecf; CD revision is pinned in the MMZ
importer. The post origin retains its old foot at +24; S1 geometry shifts +4.
"""
from pathlib import Path
import argparse
import re
from build_seesaw_art import encode
from check_sprite_assets import frames
from import_scrap_madness import nemesis_compress

ROOT=Path(__file__).resolve().parents[1]


def generate():
	raw=(ROOT/'art/uncompressed/Checkpoint.unc').read_bytes()
	assert len(raw)==12*32
	constants=(ROOT/'_definitions/s2.constants.asm').read_text()
	post=int(re.search(r'^ArtTile_Lamppost:\s*equ \$([0-9A-F]+)',constants,re.M)[1],16)
	atlas=int(re.search(r'^ArtTile_MMZ_Atlas:\s*equ \$([0-9A-F]+)',constants,re.M)[1],16)
	offset=int(re.search(r'^ArtTile_TimePostHeads:\s*equ ArtTile_MMZ_Atlas\+(\d+)',constants,re.M)[1])
	sign=atlas+offset
	heads=(ROOT/'art/uncompressed/MMZ1 Sprite Atlas.unc').read_bytes()[offset*32:(offset+22)*32]
	time_rows=frames((ROOT/'mappings/sprite/MMZ TimePost.bin').read_bytes())
	assert len(heads)==22*32 and len(time_rows)==6 and all(len(r)==1 for r in time_rows)
	# Absolute runtime tile words make all object flips safe across banks.
	pole=[(-24,1,0,-8),(-24,1,0x800,0),(-8,3,0x2002,-8),(-8,3,0x2802,0)]
	outputs={'art/nemesis/Lamppost.nem':nemesis_compress(raw),
		'art/nemesis/Checkpoint editor.nem':nemesis_compress(raw+heads)}
	for editor in (False,True):
		base=0 if editor else post
		yellow_word=0x2000|(base+10)
		def ball(word,y=-40):return [(y,1,word,-8),(y,1,(word+0x800)&65535,0)]
		body=[(y,z,w+base,x) for y,z,w,x in pole]
		rows=[body+ball(base+6),body+ball(base+8),body+ball(yellow_word),body,
			ball(base+8,-8),ball(yellow_word,-8)]
		for row in time_rows:
			y,size,tile,x=row[0]
			word=((12-offset+tile) if editor else (atlas+tile))&65535
			rows.append([(y,size,word,x)]+body)
		for tile in (0,8):
			word=(12+tile) if editor else (sign+tile)&65535
			rows.append([(-8,13,word,-16)])
		outputs['mappings/sprite/Checkpoint'+(' editor' if editor else '')+'.bin']=encode(rows)
	return outputs


def main():
	p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args()
	for name,data in generate().items():
		path=ROOT/name
		if args.check:assert path.read_bytes()==data,('Regenerate checkpoint art',name)
		else:path.write_bytes(data)
	print('Shared poles: 12 contiguous resident tiles and 22 per-act sign tiles.')


if __name__=='__main__':main()
