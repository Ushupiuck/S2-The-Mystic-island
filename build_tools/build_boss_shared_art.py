#!/usr/bin/env python3
"""Extract S1 heads while retaining each Eggmobile's original cockpit/body.

This explicit migration reads a pre-split ROM/listing. The resulting .unc and
ASM files are editable sources; build_end_art.py packs them without re-importing.
"""
from pathlib import Path
import argparse
import json
import re
import struct

from check_sprite_assets import frames
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]
# Clear the old upper face; retain S2's rounded lower jaw, collar and jacket.
# The primary palette's warm colors serve both skin and clothing: color alone
# cannot identify which pixels belong to the face.
S2_FACE_SPANS = {
	-24:(-6,-2), -23:(-9,1), -22:(-10,2), -21:(-11,2),
	-20:(-12,3), -19:(-14,8), -18:(-12,8), -17:(-12,8),
	-16:(-10,6), -15:(-9,6), -14:(-8,6),
}
# Rightmost original windshield pixel on each occupied scanline.
S2_GLASS_RIGHT = {-19:-15,-18:-13,-17:-12,-16:-11,-15:-10,-14:-10,
	-13:-9,-12:-9,-11:-9,-10:-7,-9:-7}
S2_HEAD_X = -4
S2_HEAD_Y = 0
S1_SEAT_COLORS = {10:4,11:3,12:2}
# Lower contours follow the drawing, including the whole jaw and its outline.
# Profile poses stop above the gold collar; no S1 shirt pixels are shared.
S1_HEAD_LOWER_SPANS = (
	{-16:(-6,12), -15:(-5,12), -14:(-4,11), -13:(-2,7)},
	{-16:(-6,12), -15:(-5,12), -14:(-4,7), -13:(-2,4)},
	{-16:(-6,18), -15:(-5,16), -14:(-4,13), -13:(-3,11)},
	{-16:(-6,16), -15:(-5,15), -14:(-4,10)},
	{-16:(-6,20), -15:(-5,20), -14:(-4,18), -13:(-3,5), -12:(-3,5)},
	{-16:(-6,12), -15:(-5,12), -14:(-4,7), -13:(-2,4)},
	{-16:(-6,20), -15:(-5,20), -14:(-5,18), -13:(-5,5), -12:(-3,5)},
)


def seat_color(x, y, color):
	"""Only S1's exposed padding takes the existing S2 orange ramp."""
	return S1_SEAT_COLORS.get(color,color) if x>=10 and -20<=y<-4 else color


def head_color(pose, x, y, color):
	"""Keep profile lenses visibly blue, with the frontal poses' blue ramp."""
	if pose in (0,1,5) and -6<=x<=3 and -24<=y<=-14:
		return {12:11,11:10}.get(color,color)
	return color


def glass_foreground(head, original):
	"""Original windshield shades/outline occlude the new face in SAT order."""
	return {p:original[p] for p in head if p in original
		and p[1] in S2_GLASS_RIGHT and p[0]<=S2_GLASS_RIGHT[p[1]]}


def head_mask(pose, x, y, color):
	"""Authored face contour; leave each cockpit, collar and shirt private."""
	if pose in (4,6) and -20<=y<=-13 and -20<=x<-5 and color==1:
		return True
	if y>=-16:
		# The front whisker's curled tip passes across S1's glass. Keep the
		# facial pixels, while leaving the fixed red instrument needle private.
		if pose in (2,3,4,6) and -16<=y<=-13 and -16<=x<-8:
			if color in (13,14,15):
				return True
			if pose in (4,6) and (x,y) in ((-13,-14),(-14,-13)) and color==1:
				return True
		left,right = S1_HEAD_LOWER_SPANS[pose].get(y,(0,0))
		return left<=x<right and not (x>=10 and color in S1_SEAT_COLORS)
	if x>=10 and -20<=y<-4 and color in S1_SEAT_COLORS:
		return False
	if -21<=y<=-17 and -20<=x<-5 and color in (13,14,15):
		return True
	if pose in (0,1,5):
		if pose==5 and 4<=x<16 and -30<=y<-20:
			return True
		if -24<=y<=-20:
			left,right = -8,8
		elif -19<=y<=-17:
			left,right = -7,12
		else:
			return False
	else:
		if -30<=y<=-21:
			left,right = (-12,16) if pose in (4,6) else (-10,10)
		elif -20<=y<=-17:
			left,right = -14,20
		else:
			return False
	if not left<=x<right:
		return False
	if x<-4 and 6<=color<=10:
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
	# This panel is vehicle art. Its edge and gauge do not acquire the old
	# pilot's burnt hair or facial shading in the recovery expression.
	for y,right in S2_GLASS_RIGHT.items():
		for x in range(-32,right+1):
			if (x,y) in rows[0]:
				pixels[x,y] = rows[0][x,y]
	# Hurt/recovery whiskers and burnt hair project beyond the normal skull.
	# Their exposed part is sky; the arch to their right remains untouched.
	for y in range(-25,-19):
		for x in range(-17,0):
			pixels.pop((x,y),None)
		for x in range(0,17):
			if pixels.get((x,y)) in (13,14,15):
				pixels[x,y] = 1
	for y,(left,right) in S2_FACE_SPANS.items():
		for x in range(left,right):
			color = pixels.get((x,y),0)
			if not color or (y in S2_GLASS_RIGHT and x<=S2_GLASS_RIGHT[y]):
				continue
			if x>=0 and color in (3,4):
				continue	# original orange backrest
			# Above the windshield, the old head projects into open air.
			# Below it, expose the cabin's dark interior. Never stretch a
			# shirt row through the jaw or erase S2's lower chin/collar.
			if y<-19 and x<0:
				pixels.pop((x,y),None)
			else:
				pixels[x,y] = 1
	return pixels


def tile_bytes(pixels, x, y):
	out = bytearray()
	for py in range(y,y+8):
		for px in range(x,x+8,2):
			out.append(pixels.get((px,py),0)<<4 | pixels.get((px+1,py),0))
	return bytes(out)


def pack_pixels_aligned(pixels, bank, offset):
	"""Pack one candidate grid without changing any visible pixel."""
	ox,oy = offset
	pixels = {(x-ox,y-oy):c for (x,y),c in pixels.items()}
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
	return [(y+oy,size,tile,x+ox) for y,size,tile,x in pieces]


def pack_pixels(pixels, bank):
	"""Choose a grid phase that reuses the most tiles from earlier poses.

	A one-pixel expression bob must not force an entirely new 8x8 grid.
	Only the mapping origin changes; indexed pixels and SAT order stay exact.
	"""
	best = None
	for oy in range(8):
		for ox in range(8):
			candidate = bytearray(bank)
			pieces = pack_pixels_aligned(pixels,candidate,(ox,oy))
			key = (len(candidate),len(pieces),oy,ox)
			if best is None or key<best[0]:
				best = key,candidate,pieces
	bank[:] = best[1]
	return best[2]


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
	heads = [{p:head_color(i,*p,c) for p,c in row.items() if head_mask(i,*p,c)} for i,row in enumerate(pilots)]
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
	fronts = [glass_foreground({(x+S2_HEAD_X,y+S2_HEAD_Y):c for (x,y),c in head.items()},s2pilots[0])
		for i,head in enumerate(heads)]
	frontmaps = [pack_pixels(row,banks['Boss Ship']) if row else [] for row in fronts]

	# Preserve the full S1 figure after separating its ownership into two banks.
	for i,row in enumerate(pilots):
		assert {**backgrounds[i],**heads[i]}=={p:head_color(i,*p,seat_color(*p,c)) for p,c in row.items()}
	return banks,headmaps,ghz,ehz,frontmaps,oldmaps[0],newmaps[0]


def mapping(label, rows, headmaps=None, private_base=0, dx=0, dy=0, foregrounds=None, draw_y=0):
	lines = [label+':']+[f'\tdc.w {label}_Frame{i}-{label}' for i in range(len(rows))]
	for i,row in enumerate(rows):
		head = headmaps[i] if headmaps else []
		front = foregrounds[i] if foregrounds else []
		pieces = front+[(y+dy,size,private_base+tile,x+dx) for y,size,tile,x in head]+row
		lines.append(f'{label}_Frame{i}:\tdc.w {len(pieces)}')
		for y,size,tile,x in pieces:
			lines += [f'\tdc.b {y+draw_y},${size:02X}',f'\tdc.w ${tile:04X},{x}']
	return '\n'.join(lines)+'\n\teven\n'


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,required=True)
	p.add_argument('--listing',type=Path,required=True)
	p.add_argument('--write',action='store_true')
	a = p.parse_args()
	constants = (ROOT/'_definitions/s2.constants.asm').read_text()
	allocations = {name:int(value,16) for name,value in re.findall(r'^(ArtTile_\w+):\s+equ \$([0-9A-Fa-f]+)',constants,re.M)}
	object_source = (ROOT/'objects/55 EHZ Boss.asm').read_text()
	draw_y = int(re.search(r'^EHZBoss_PodDrawY\s*=\s*(-?\d+)',object_source,re.M).group(1))
	banks,heads,ghz,ehz,fronts,oldhull,newhull = extract(a.rom,a.listing)
	report = {name:len(raw)//32 for name,raw in banks.items()}
	report['private_end'] = hex(0x3F0+max(len(banks['Old Eggpod']),len(banks['Boss Ship']))//32)
	report['shared_base'] = hex(allocations['ArtTile_EggmanFace'])
	report['shared_end'] = hex(int(report['shared_base'],16)+len(banks['Eggman face'])//32)
	report['pieces'] = {'head':[len(r) for r in heads],'GHZ':[len(r) for r in ghz],'EHZ':[len(r) for r in ghz]}
	print(json.dumps(report,indent=2))
	if not a.write:
		return
	headbase,headend = int(report['shared_base'],16),int(report['shared_end'],16)
	assert headbase>=int(report['private_end'],16)
	assert headend<=min(allocations['ArtTile_Eggman_Weapons'],allocations['ArtTile_ArtNem_EHZBoss'])
	weaponbase = allocations['ArtTile_ArtNem_EHZBoss']
	expected = {'ArtTile_Eggman':0x3F0,'ArtTile_ArtNem_Eggpod_1':0x3F0,
		'ArtTile_EggmanFace':headbase,'ArtTile_Eggman_Weapons':weaponbase,
		'ArtTile_ArtNem_EHZBoss':weaponbase,'ArtTile_ArtNem_EggChoppers':weaponbase+128,
		'ArtTile_Prison_Capsule':weaponbase+128+12,'ArtTile_Eggman_Exhaust':weaponbase+128+12+85}
	for name,value in expected.items():
		assert allocations[name]==value, (name,hex(allocations[name]),'needs',hex(value))
	assert expected['ArtTile_Eggman_Exhaust']+25<=allocations['ArtTile_Shield_2']
	for name,raw in banks.items():
		(ROOT/f'art/uncompressed/{name}.unc').write_bytes(raw)
	outputs = {
		'GHZ Boss Cockpit.asm':mapping('Map_GHZBoss_Cockpit',ghz,heads,int(report['shared_base'],16)-0x3F0),
		'EHZ Boss Cockpit.asm':mapping('Map_EHZBoss_Cockpit',ghz,heads,int(report['shared_base'],16)-0x3F0,draw_y=draw_y),
		'EHZ Boss Vehicle.asm':mapping('Map_EHZBoss_Vehicle',[[(y,size,(tile&0xF800)|((tile&0x7FF)-10),x) for y,size,tile,x in oldhull]],draw_y=draw_y),
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
		comment = ('; Archived Sonic 2 propeller mappings; not assembled by the S1-pod preview.\n'
			if name=='EHZ Boss Propeller.asm' else '; Shared S1 pod/cockpit; EHZ maps draw the complete pod four pixels higher.\n')
		(ROOT/f'mappings/sprite/{name}').write_bytes((comment+text).replace('\n','\r\n').encode())


if __name__=='__main__':
	main()
