#!/usr/bin/env python3
"""Pack the shared full-height Sonic 1 seesaw and its complete spikeball.

Optional import source: sonicretro/s1disasm 2c51d46a0b0682133834db2093292d41da872ecf.
The editable atlas is 44 plank tiles followed by 18 ball tiles. Plank blue
indices 2-5 intentionally select the shared orange/skin ramp. Ball skin/red
indices are translated to the corresponding shared slots.
"""
from pathlib import Path
import argparse
import struct

from import_ehz2_pp_background import nemesis
from import_scrap_madness import mapping, nemesis_compress
from check_sprite_assets import frames
from sprite_palette import remap_pixels

ROOT = Path(__file__).resolve().parents[1]


def encode(rows):
	result = bytearray(len(rows)*2)
	seen = {}
	for i,row in enumerate(rows):
		data = struct.pack('>H',len(row))+b''.join(struct.pack('>bBHh',*p) for p in row)
		if data not in seen:
			seen[data] = len(result)
			result.extend(data)
		struct.pack_into('>H',result,i*2,seen[data])
	return bytes(result)


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--source',type=Path)
	p.add_argument('--check',action='store_true')
	args = p.parse_args()
	outputs = {}
	if args.source:
		source = args.source
		plank = nemesis((source/'artnem/SLZ Seesaw.nem').read_bytes())
		ball = nemesis((source/'artnem/SLZ Little Spikeball.nem').read_bytes())
		assert len(plank)==44*32 and len(ball)==18*32
		lookup = list(range(16))
		for old,new in ((10,5),(12,13),(13,14),(14,15)):
			lookup[old] = new
		outputs['art/uncompressed/Seesaw.unc'] = plank+remap_pixels(ball,lookup)
		for name,dy,dt in (('Seesaw',16,0),('Seesaw Ball',0,44)):
			rows = frames(mapping((source/f'_maps/{name}.asm').read_text()))
			rows = [[(y+dy,size,tile+dt,x) for y,size,tile,x in row] for row in rows]
			outputs['mappings/sprite/obj5E_'+('a' if name=='Seesaw' else 'b')+'.bin'] = encode(rows)
	raw = outputs.get('art/uncompressed/Seesaw.unc')
	if raw is None:
		raw = (ROOT/'art/uncompressed/Seesaw.unc').read_bytes()
	assert len(raw)==62*32
	assert {n for b in raw for n in (b>>4,b&15)} <= set(range(10))|{13,14,15}
	outputs['art/nemesis/Seesaw.nem'] = nemesis_compress(raw)
	for path,data in outputs.items():
		if args.check:
			assert (ROOT/path).read_bytes()==data, path
		else:
			(ROOT/path).write_bytes(data)
	for name,start,end in (('a',0,44),('b',44,62)):
		for row in frames((ROOT/f'mappings/sprite/obj5E_{name}.bin').read_bytes()):
			for _,size,tile,_ in row:
				assert not tile&0xE000
				assert start<=tile&2047<end
				assert (tile&2047)+((size>>2)+1)*((size&3)+1)<=end
	print('Seesaw: 44 full-height plank tiles + 18 complete spikeball tiles; no interleaved 2P art.')


if __name__=='__main__':
	main()
