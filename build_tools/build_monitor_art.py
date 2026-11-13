#!/usr/bin/env python3
"""Build resident monitor bodies/life art, four cached-icon mappings and DPLCs.

Editable master: art/nemesis/Monitor and contents.unc. Tiles 0-15 are the intact
box; 16-23 are its broken base. Then four tiles each: Eggman, rings, regular
shield, water, fire, electric, shoes, invincibility, Tails. Sonic's double-life
icon already lives in the permanent life-counter bank. No separate static icon.
"""
from pathlib import Path
import argparse
import re
import struct
from import_scrap_madness import nemesis_inline
from build_end_art import pack_moduled

ROOT=Path(__file__).resolve().parents[1]


def mappings(rows):
	data=bytearray(len(rows)*2)
	for i,row in enumerate(rows):
		struct.pack_into('>H',data,i*2,len(data))
		data+=struct.pack('>H',len(row))
		data+=b''.join(struct.pack('>bBHh',*piece) for piece in row)
	return bytes(data)


def generate():
	raw=(ROOT/'art/nemesis/Monitor and contents.unc').read_bytes()
	assert len(raw)==60*32,'Monitor master must retain its 24 body + 36 icon tiles'
	text=(ROOT/'_definitions/s2.constants.asm').read_text()
	base=int(re.search(r'^ArtTile_Monitor:\s*equ\s+\$([\dA-Fa-f]+)',text,re.M)[1],16)
	life=int(re.search(r'^ArtTile_Lives_Counter:\s*equ\s+\$([\dA-Fa-f]+)',text,re.M)[1],16)
	body=(-17,15,0,-16);broken=(-1,13,16,-16)
	outputs={
		'art/nemesis/Monitor and contents.nem':nemesis_inline(raw),
		'art/nemesis/Monitor and contents.kospm':pack_moduled(raw),
		'art/nemesis/Monitor bodies.nem':nemesis_inline(raw[:24*32]),
		'art/nemesis/Monitor Tails life.nem':nemesis_inline(raw[56*32:]),
		'art/uncompressed/Monitor icons.unc':raw[24*32:56*32],
	}
	for slot in range(5):
		# Slot 4 is the editor view of the full master, never a runtime buffer.
		rows=[[body]]
		for kind in range(10):
			tile=24+kind*4 if slot==4 else 24+slot*4
			if kind==8:tile=(life-base)&2047
			elif kind==9:tile=56
			if kind==1:tile|=0x2000
			rows.append([(-11,5,tile,-8),body])
		rows.append([broken])
		name='Monitor' if slot==4 else f'Monitor DPLC {slot}'
		outputs[f'mappings/sprite/{name}.bin']=mappings(rows)
	data=bytearray(16)
	for kind in range(8):
		struct.pack_into('>H',data,kind*2,len(data));data+=struct.pack('>HH',1,0x3000+kind*4)
	outputs['mappings/spriteDPLC/Monitor.bin']=bytes(data)
	return outputs


def main():
	p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args()
	for name,data in generate().items():
		path=ROOT/name
		if args.check:assert path.read_bytes()==data,('Regenerate monitor art',name)
		else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
	print('Monitor art: 24 body + 16 cached content + 4 permanent Tails tiles; 16 tiles reclaimed. Both life icons stay resident.')


if __name__=='__main__':main()
