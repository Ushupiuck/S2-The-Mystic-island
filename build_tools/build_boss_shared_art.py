#!/usr/bin/env python3
"""Extract S1 heads while retaining each Eggmobile's original cockpit/body.

This explicit migration reads a pre-split ROM/listing. The resulting .unc and
ASM files are editable sources; ordinary builds only pack those sources.
"""
from pathlib import Path
import argparse
import json
import re
import struct

from check_sprite_assets import frames
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]
# Original S2 facial silhouette, excluding the windshield and rear seat rim.
S2_FACE_SPANS = {
	-23:(-9,-4), -22:(-10,-1), -21:(-11,0), -20:(-12,1),
	-19:(-12,2), -18:(-12,7), -17:(-12,7), -16:(-10,5),
	-15:(-9,5), -14:(-8,5), -13:(-7,-1), -12:(-6,-1),
}
S2_HEAD_X = -4
S2_HEAD_Y = -2
S1_SEAT_COLORS = {10:4,11:3,12:2}


def seat_color(x, y, color):
	"""Only S1's exposed padding takes the existing S2 orange ramp."""
	return S1_SEAT_COLORS.get(color,color) if x>=10 and -20<=y<-4 else color


def head_mask(pose, x, y, color):
	"""Authored head contour; never extract the S1 glass, console or torso."""
	if x>=10 and -20<=y<-4 and color in S1_SEAT_COLORS:
		return False
	# The short glass-side whisker extends left of the skull contour.
	if -21<=y<=-17 and -16<=x<-5 and color in (13,14,15):
		return True
	if pose in (0,1,5):
		if pose==5 and 4<=x<16 and -30<=y<-20:
			return True
		if -24<=y<=-20:
			left,right = -8,8
		elif -19<=y<=-17:
			left,right = -7,12
		elif -16<=y<=-14:
			left,right = -6,12
		elif y==-13:
			left,right = -4,8
		elif -12<=y<=-11:
			left,right = -4,3
		else:
			return False
	else:
		if -30<=y<=-21:
			left,right = (-12,16) if pose in (4,6) else (-10,10)
		elif -20<=y<=-17:
			left,right = -14,20
		elif -16<=y<=-15:
			left,right = -6,16
		elif y==-14:
			left,right = -4,12
		elif y==-13:
			left,right = -2,8
		else:
			return False
	if not left<=x<right:
		return False
	if x<-4 and y>-20 and 6<=color<=10:
		return False
	if x<-7 and y>=-20 and color not in (13,14,15):
		return False
	return True


def raster(row, raw):
	pixels = {}
	for y,size,word,x in reversed(row):
		w,h = (size>>2)+1,(size&3)+1
		for tx in range(w):
			for ty in range(h):
				first = ((word&2047)+tx*h+ty)*32
				for p,color in enumerate(n for b in raw[first:first+32] for n in (b>>4,b&15)):
					if not color:
						continue
					px,py = tx*8+p%8,ty*8+p//8
					if word&0x800:
						px = w*8-1-px
					if word&0x1000:
						py = h*8-1-py
					assert not word&0x6000, 'Pilot sources must use the primary palette'
					pixels[x+px,y+py] = color
	return pixels


def s2_background(pose, rows):
	pixels = rows[pose].copy()
	for y,(left,right) in S2_FACE_SPANS.items():
		for x in range(left,right):
			color = pixels.get((x,y),0)
			if not color or (color in (6,7,8,9,10) and x<-10):
				continue
			if x>=0 and color in (3,4):
				continue	# source seat rim, retained behind the new moustache
			pixels[x,y] = 1 if y<-14 else rows[0].get((x,-10),13)
	return pixels


def tile_bytes(pixels, x, y):
	out = bytearray()
	for py in range(y,y+8):
		for px in range(x,x+8,2):
			out.append(pixels.get((px,py),0)<<4 | pixels.get((px+1,py),0))
	return bytes(out)


def pack_pixels(pixels, bank):
	"""Deduplicate 8x8 cells, then join runs with valid hardware tile order."""
	cells = {(x//8,y//8) for x,y in pixels if pixels[x,y]}
	lookup = {bytes(bank[i:i+32]):i//32 for i in range(0,len(bank),32)}
	indices = {}
	for x,y in sorted(cells):
		raw = tile_bytes(pixels,x*8,y*8)
		if raw not in lookup:
			lookup[raw] = len(bank)//32
			bank += raw
		indices[x,y] = lookup[raw]
	pieces = []
	while cells:
		x,y = min(cells,key=lambda p:(p[1],p[0]))
		first = indices[x,y]
		choices = []
		for w in range(1,5):
			for h in range(1,5):
				covered = {(a,b) for a in range(x,x+w) for b in range(y,y+h)}
				if not covered<=cells:
					continue
				if all(indices[a,b]==first+(a-x)*h+(b-y) for a,b in covered):
					choices.append((w*h,w,h,covered))
		_,w,h,covered = max(choices,key=lambda r:r[:3])
		pieces.append((y*8,((w-1)<<2)|(h-1),first,x*8))
		cells -= covered
	return pieces


def unpack_bank(rom, address):
	count = struct.unpack_from('>H',rom,address)[0]
	out,address = bytearray(),address+2
	while len(out)<count:
		block,address = kosinski_plus_decode(rom,address)
		out += block
	assert len(out)==count
	return bytes(out)


def extract(rom_path, listing_path):
	rom = rom_path.read_bytes()
	s = {name:int(value,16) for name,value in re.findall(r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',listing_path.read_text())}
	def unpack(label):
		return unpack_bank(rom,s[label])
	old,new = unpack('Kospm_OldEggPod'),unpack('Kospm_EggPod')
	assert len(old)==108*32 and len(new)==96*32, 'Use the pre-split source build'
	oldmaps,newmaps = frames(rom,s['Map_Eggman'],13),frames(rom,s['Map_EHZBoss_Vehicle'],7)
	pilots = [raster(row,old) for row in oldmaps[1:8]]
	s2pilots = [raster(row,new) for row in newmaps[1:7]]
	heads = [{p:c for p,c in row.items() if head_mask(i,*p,c)} for i,row in enumerate(pilots)]
	backgrounds = [{p:seat_color(*p,c) for p,c in row.items() if p not in heads[i]} for i,row in enumerate(pilots)]
	ghz_hull = bytearray(old[10*32:0x2D*32])
	# The outer backrest is in the hull's second piece, not the pilot bank.
	for i in range(2*32,6*32):
		byte = ghz_hull[i]
		ghz_hull[i] = S1_SEAT_COLORS.get(byte>>4,byte>>4)<<4 | S1_SEAT_COLORS.get(byte&15,byte&15)
	banks = {'Eggman face':bytearray(),'Old Eggpod':ghz_hull,'Boss Ship':bytearray(new[:32*32])}
	headmaps = [pack_pixels(row,banks['Eggman face']) for row in heads]
	ghz = [pack_pixels(row,banks['Old Eggpod']) for row in backgrounds]
	ehz = [pack_pixels(s2_background(min(i,5),s2pilots),banks['Boss Ship']) for i in range(7)]
	# Preserve the full S1 figure after separating its ownership into two banks.
	for i,row in enumerate(pilots):
		assert {**backgrounds[i],**heads[i]}=={p:seat_color(*p,c) for p,c in row.items()}
	return banks,headmaps,ghz,ehz,oldmaps[0],newmaps[0]


def mapping(label, rows, headmaps=None, private_base=0, dx=0, dy=0):
	lines = [label+':']+[f'\tdc.w {label}_Frame{i}-{label}' for i in range(len(rows))]
	for i,row in enumerate(rows):
		head = headmaps[i] if headmaps else []
		lines.append(f'{label}_Frame{i}:\tdc.w {len(head)+len(row)}')
		for y,size,tile,x in head:
			lines += [f'\tdc.b {y+dy},${size:02X}',f'\tdc.w ${private_base+tile:04X},{x+dx}']
		for y,size,tile,x in row:
			lines += [f'\tdc.b {y},${size:02X}',f'\tdc.w ${tile:04X},{x}']
	return '\n'.join(lines)+'\n\teven\n'


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,required=True)
	p.add_argument('--listing',type=Path,required=True)
	p.add_argument('--write',action='store_true')
	a = p.parse_args()
	banks,heads,ghz,ehz,oldhull,newhull = extract(a.rom,a.listing)
	report = {name:len(raw)//32 for name,raw in banks.items()}
	report['shared_base'] = hex(0x3F0+max(len(banks['Old Eggpod']),len(banks['Boss Ship']))//32)
	report['shared_end'] = hex(int(report['shared_base'],16)+len(banks['Eggman face'])//32)
	report['pieces'] = {'head':[len(r) for r in heads],'GHZ':[len(r) for r in ghz],'EHZ':[len(r) for r in ehz]}
	print(json.dumps(report,indent=2))
	if not a.write:
		return
	constants = (ROOT/'_definitions/s2.constants.asm').read_text()
	allocations = {name:int(value,16) for name,value in re.findall(r'^(ArtTile_\w+):\s+equ \$([0-9A-Fa-f]+)',constants,re.M)}
	headbase,headend = int(report['shared_base'],16),int(report['shared_end'],16)
	expected = {'ArtTile_Eggman':0x3F0,'ArtTile_ArtNem_Eggpod_1':0x3F0,
		'ArtTile_EggmanFace':headbase,'ArtTile_Eggman_Weapons':headend,
		'ArtTile_ArtNem_EHZBoss':headend,'ArtTile_ArtNem_EggChoppers':headend+128,
		'ArtTile_Prison_Capsule':headend+128+12,'ArtTile_Eggman_Exhaust':headend+128+12+85}
	for name,value in expected.items():
		assert allocations[name]==value, (name,hex(allocations[name]),'needs',hex(value))
	assert expected['ArtTile_Eggman_Exhaust']+25<=allocations['ArtTile_Shield_2']
	for name,raw in banks.items():
		(ROOT/f'art/uncompressed/{name}.unc').write_bytes(raw)
	outputs = {
		'GHZ Boss Cockpit.asm':mapping('Map_GHZBoss_Cockpit',ghz,heads,int(report['shared_base'],16)-0x3F0),
		'EHZ Boss Cockpit.asm':mapping('Map_EHZBoss_Cockpit',ehz,heads,int(report['shared_base'],16)-0x3F0,S2_HEAD_X,S2_HEAD_Y),
	}
	rom = a.rom.read_bytes()
	s = {name:int(value,16) for name,value in re.findall(r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',a.listing.read_text())}
	prop = unpack_bank(rom,s['Kospm_EggChopper'])
	assert len(prop)==20*32
	assert all(prop[i*32:(i+1)*32]==bytes(32) for i in range(8,20,2))
	assert all(prop[i*32:(i+1)*32]==prop[9*32:10*32] for i in range(9,20,2))
	(ROOT/'art/uncompressed/Chopper blades for EHZ boss.unc').write_bytes(prop[:8*32]+prop[9*32:10*32]*4)
	propmaps = frames(rom,s['Map_EHZBoss_Propeller'],7)
	propmaps = [[(y+8,(size&12),8,x) if tile>=8 else (y,size,tile,x) for y,size,tile,x in row] for row in propmaps]
	outputs['EHZ Boss Propeller.asm'] = mapping('Map_EHZBoss_Propeller',propmaps)
	for name,text in outputs.items():
		(ROOT/f'mappings/sprite/{name}').write_bytes(('; Original vehicle cockpit/torso with a shared S1 head layer.\n'+text).replace('\n','\r\n').encode())


if __name__=='__main__':
	main()
