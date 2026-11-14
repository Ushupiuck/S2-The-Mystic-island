#!/usr/bin/env python3
"""Prepare single-player S2 boss art and S3&K weapon mappings, without boss code.

Explicit imports optimize the atlas. Normal builds repack the editable .unc
files without overwriting them. Shared Eggpod pieces are deliberately omitted;
the later controllers must use Mystic Island's existing pod/head children.
Source: sonicretro/s2disasm, revision 4c5dc02b3eea186c3f80a020447b206343f30c0a.
MTZ eggs: sonicretro/skdisasm, revision 73de97c6b55055bcb8089c1d55d006b02136f163.
"""
from pathlib import Path
from functools import lru_cache
import argparse
import json
import re
import struct

from build_end_art import pack_moduled
from import_ehz2_pp_background import nemesis
from convert_s1_ss_background import kosinski_plus, kosinski_plus_decode
from import_scrap_madness import classic_kosinski

ROOT = Path(__file__).resolve().parents[1]
# Sonic 2's four blues become the project's three-blue ramp. Other roles match
# the existing EHZ import: black/gray, skin, reds and the yellow/orange pair.
PLAYER_FROM_S2 = (0,1,12,11,10,10,6,7,8,9,5,2,13,14,4,3)
# Shared row-two contract: black 1, white 6, grays 7/8/9 and optional C,
# yellows D/E/F. Displaced source E/F colors move to A/5, including CNZ cycles.
SECONDARY_FROM_S2 = (0,1,2,3,4,15,6,7,8,9,12,11,13,14,10,5)
# S&K's four intermediate grays, white and near-black use the same EHZ ramp.
# Its yellow/teal deformation colors follow the prepared secondary row too.
MTZ_EGGS_FROM_SK = {0:0,1:6,3:7,4:12,5:13,6:14,7:9,12:1,13:8,15:15}
CPZ_CHEMICAL_FRAMES = tuple(range(4,10))+tuple(range(16,28))
BOSSES = {
	'CPZ': (0x500, [('Weapons','obj5D_a')]),
	'ARZ': (0x3E0, [('Weapons','obj89_b'),('Pillars','obj89_a')]),
	'CNZ': (0x3A7, [('Weapons','obj51')]),
	'MCZ': (0x3C0, [('Weapons','obj57')]),
	'MTZ': (0x37C, [('Weapons','obj54')]),
}
SOURCE_COUNTS = {'CPZ':111,'ARZ':166,'CNZ':133,'MCZ':204,'MTZ':124}
MCZ_DRILL_FRAMES = (2,3,4,8,9,10,11)
CNZ_TOPPER_FRAME = 21
CNZ_TOPPER_X = -16
CNZ_COLLAR_Y = 8


def number(text):
	return int(text.strip().replace('$','0x'),0)


def read_mappings(path):
	text = path.read_text()
	rows, current = {}, None
	for line in text.splitlines():
		header = re.match(r'^(\w+):\s*spriteHeader',line)
		if header:
			current = rows[header[1]] = []
		piece = re.match(r'\s*spritePiece\s+([^;]+)',line)
		if piece:
			values = tuple(map(number,piece[1].split(',')))
			assert len(values)==9 and current is not None,path
			current.append(values)
	# CNZ's unused frame zero points at its pointer table. Normalize it to empty.
	return [rows.get(label,[]) for label in re.findall(r'mappingsTableEntry\.w\s+(\w+)',text)]


def mtz_eggs(source):
	path = source/'Levels/SSZ/KosinskiM Art/MTZ Orbs.kosm'
	packed = path.read_bytes()
	raw = classic_kosinski(packed[2:])
	assert len(raw)==int.from_bytes(packed[:2],'big')==117*32
	text = (source/'Levels/SSZ/Misc Object Data/Map - MTZ Orbs.asm').read_text()
	labels = re.findall(r'dc.w\s+(\w+)-Map_SSZMTZOrbs_',text)[:6]
	rows,current = {},None
	for line in text.splitlines():
		header = re.match(r'^(\w+):\s*dc.w\s+(\d+)',line)
		if header:
			current = [] if header[1] in labels else None
			if current is not None:rows[header[1]] = current
		piece = re.match(r'\s*dc.b\s+([^;]+)',line)
		if piece and current is not None:
			y,size,word,x = struct.unpack('>bBHh',bytes(map(number,piece[1].split(','))))
			w,h = (size>>2)+1,(size&3)+1
			first = word&2047
			assert first+w*h<=37,'Only the egg/orb tiles may be imported'
			data = raw[first*32:(first+w*h)*32]
			assert word&0x6000==0x2000
			data = bytes(MTZ_EGGS_FROM_SK[b>>4]<<4|MTZ_EGGS_FROM_SK[b&15] for b in data)
			current.append((x,y,w,h,data,word>>11&1,word>>12&1,1,word>>15))
	assert len(labels)==6 and all(len(rows[label])==1 for label in labels)
	return [rows[label] for label in labels]


def pod_coverage():
	"""Opaque pixels of the editable universal hull, in its normal coordinates."""
	text = (ROOT/'md-main.asm').read_text().split('Map_Eggman_Frame0:',1)[1]
	count = int(re.match(r'\s*dc.w\s+(\d+)',text)[1])
	pieces = re.findall(r'dc.b\s+([^\n]+)\n\s*dc.w\s+([^\n]+)',text)[:count]
	assert len(pieces)==count
	raw = (ROOT/'art/uncompressed/Old Eggpod.unc').read_bytes()
	covered = set()
	for first,second in pieces:
		y,size = map(number,first.split(','));word,x = map(number,second.split(','))
		w,h = (size>>2)+1,(size&3)+1
		for px in range(w*8):
			for py in range(h*8):
				tile = (word&2047)+(px//8)*h+py//8
				byte = raw[tile*32+py%8*4+px%8//2]
				if (byte>>(0 if px&1 else 4))&15:
					covered.add((x+(w*8-1-px if word&0x800 else px),y+(h*8-1-py if word&0x1000 else py)))
	return covered


def cnz_mounts(rows):
	"""Show the S1 hull through the collar; keep the topper behind the pilot."""
	assert len(rows)==CNZ_TOPPER_FRAME
	covered = pod_coverage()
	body,topper = [],[]
	for x,y,w,h,raw,xf,yf,pal,pri in rows[1]:
		if y<0:
			topper.append((x+CNZ_TOPPER_X,y,w,h,raw,xf,yf,pal,pri))
			continue
		data = bytearray(raw)
		for px in range(w*8):
			for py in range(h*8):
				point = x+(w*8-1-px if xf else px),y+(h*8-1-py if yf else py)
				if 0<=point[1]<CNZ_COLLAR_Y and point in covered:
					offset = ((px//8)*h+py//8)*32+py%8*4+px%8//2
					data[offset] &= 0xF0 if px&1 else 0x0F
		body.append((x,y,w,h,bytes(data),xf,yf,pal,pri))
	rows[1] = body
	rows.append(topper)


def source_boss(source, zone, skdisasm):
	base, tables = BOSSES[zone]
	raw = nemesis((source/f'art/nemesis/{zone} boss.nem').read_bytes())
	assert len(raw)==SOURCE_COUNTS[zone]*32
	first = 96 if zone=='CNZ' else 0
	secondary = secondary_lookup(source,zone)
	families = {}
	for family,name in tables:
		frames = []
		for index,row in enumerate(read_mappings(source/f'mappings/sprite/{name}.asm')):
			private = []
			for x,y,w,h,tile,xf,yf,pal,pri in row:
				if zone=='MCZ' and index in (13,20):
					continue	# these frames use the separate falling-rock bank
				if not first<=tile<first+len(raw)//32:
					assert 0x500<=base+tile<0x568,(zone,index,hex(base+tile))
					continue	# existing shared Eggpod, never duplicate its pixels
				start = tile-first
				assert start+w*h<=len(raw)//32
				art = raw[start*32:(start+w*h)*32]
				if zone!='CPZ' and pal==0:
					art = bytes(PLAYER_FROM_S2[b>>4]<<4|PLAYER_FROM_S2[b&15] for b in art)
				elif zone=='CPZ' or pal==1:
					art = bytes(secondary[b>>4]<<4|secondary[b&15] for b in art)
				private.append((x,y,w,h,art,xf,yf,pal,pri))
			frames.append(private)
		families[family] = frames
	if zone=='MTZ':
		# S2 IDs 3-8 and S&K IDs 0-5 have the same animation roles: two
		# orbit poses, distant pose and three transitions into the balloon.
		families['Weapons'][3:9] = mtz_eggs(skdisasm)
	elif zone=='CNZ':
		cnz_mounts(families['Weapons'])
	return raw, families


def trim(part):
	x,y,w,h,raw = part
	filled = [(a,b) for a in range(w) for b in range(h) if any(raw[(a*h+b)*32:(a*h+b+1)*32])]
	if not filled:
		return None
	left,right = min(a for a,b in filled),max(a for a,b in filled)+1
	top,bottom = min(b for a,b in filled),max(b for a,b in filled)+1
	data = b''.join(raw[(a*h+b)*32:(a*h+b+1)*32] for a in range(left,right) for b in range(top,bottom))
	return x+left,y+top,right-left,bottom-top,data


def split(part, axis, cut):
	x,y,w,h,raw = part
	regions = [(0,0,cut,h),(cut,0,w-cut,h)] if axis==0 else [(0,0,w,cut),(0,cut,w,h-cut)]
	result = []
	for a,b,ww,hh in regions:
		data = b''.join(raw[(cx*h+cy)*32:(cx*h+cy+1)*32] for cx in range(a,a+ww) for cy in range(b,b+hh))
		cropped = trim((x+a,y+b,ww,hh,data))
		if cropped:
			result.append(cropped)
	return tuple(result)


@lru_cache(maxsize=None)
def partitions(raw, w, h):
	first = trim((0,0,w,h,raw))
	if first is None:
		return ((),)
	choices = {(first,)}
	# Up to two extra pieces, with a per-frame/scanline budget below. Transparent
	# corners can disappear without turning every occupied tile into a sprite.
	frontier = {(first,)}
	for depth in range(2):
		next_choices = set()
		for parts in frontier:
			for i,part in enumerate(parts):
				for axis,size in enumerate(part[2:4]):
					for cut in range(1,size):
						candidate = parts[:i]+split(part,axis,cut)+parts[i+1:]
						if len(candidate)<=3:
							next_choices.add(candidate)
		choices.update(next_choices)
		frontier = next_choices
	# Deterministic output, independent of Python's randomized hash seed.
	return tuple(sorted(choices,key=lambda parts:(len(parts),sum(w*h for x,y,w,h,data in parts),parts)))


@lru_cache(maxsize=None)
def flip_block(raw, w, h, xf, yf):
	result = bytearray()
	for x in range(w):
		for y in range(h):
			cx,cy = w-1-x if xf else x,h-1-y if yf else y
			tile = raw[(cx*h+cy)*32:(cx*h+cy+1)*32]
			rows = [tile[i:i+4] for i in range(0,32,4)]
			if yf:
				rows.reverse()
			for row in rows:
				result.extend(bytes((b&15)<<4|b>>4 for b in reversed(row)) if xf else row)
	return bytes(result)


def pack_block(bank, raw, w, h):
	best = None
	for xf,yf in ((0,0),(1,0),(0,1),(1,1)):
		data = flip_block(raw,w,h,xf,yf)
		position = bank.find(data)
		while position>=0 and position%32:
			position = bank.find(data,position+1)
		if position>=0:
			return bank,position//32,xf,yf
		overlap = min(len(bank),len(data))-32
		while overlap>0 and bank[-overlap:]!=data[:overlap]:
			overlap-=32
		overlap = max(0,overlap)
		key = (len(data)-overlap,xf+yf,xf,yf)
		if best is None or key<best[0]:
			best = key,data,overlap,xf,yf
	_,data,overlap,xf,yf = best
	return bank+data[overlap:],(len(bank)-overlap)//32,xf,yf


def scanlines(row):
	counts,widths = [0]*256,[0]*256
	for y,size,tile,x in row:
		for scan in range(max(-128,y),min(128,y+((size&3)+1)*8)):
			counts[scan+128]+=1
			widths[scan+128]+=((size>>2)+1)*8
	return counts,widths


def pack_frame(bank, source, penalty):
	original = [(y,((w-1)<<2)|(h-1),0,x) for x,y,w,h,*rest in source]
	counts,widths = scanlines(original)
	states = [(bank,[])]
	for x,y,w,h,raw,xf,yf,pal,pri in source:
		next_states = []
		for previous,row in states:
			for parts in partitions(raw,w,h):
				if len(row)+len(parts)>len(source)+2:
					continue
				candidate = previous
				mapped = list(row)
				for px,py,ww,hh,data in parts:
					candidate,tile,fx,fy = pack_block(candidate,data,ww,hh)
					left = x+(w-px-ww if xf else px)*8
					top = y+(h-py-hh if yf else py)*8
					word = tile|((xf^fx)<<11)|((yf^fy)<<12)|(pal<<13)|(pri<<15)
					mapped.append((top,((ww-1)<<2)|(hh-1),word,left))
				cc,ww = scanlines(mapped)
				if any(c>old+1 or width>oldwidth for c,old,width,oldwidth in zip(cc,counts,ww,widths)):
					continue
				next_states.append((candidate,mapped))
		assert next_states, 'No representation fits the original sprite-width budget'
		states = sorted(next_states,key=lambda state:(len(state[0])+len(state[1])*penalty,len(state[1]),state[1],state[0]))[:12]
	return min(states,key=lambda state:(len(state[0])+len(state[1])*penalty,len(state[1]),state[1],state[0]))


def optimize(families):
	items = [(name,i,row) for name,rows in families.items() for i,row in enumerate(rows)]
	best = None
	for penalty in (32,64):
		for ordered in (items,sorted(items,key=lambda item:-sum(w*h for x,y,w,h,*rest in item[2]))):
			bank,mappings = b'',{name:[None]*len(rows) for name,rows in families.items()}
			for name,index,row in ordered:
				bank,mappings[name][index] = pack_frame(bank,row,penalty)
			pieces = sum(len(row) for rows in mappings.values() for row in rows)
			key = len(bank),pieces
			if best is None or key<best[0]:
				best = key,bank,mappings
	return best[1:]


def mapping_text(zone, families, tiles):
	lines = [f'; Prepared {zone} weapon art; six-byte S3&K mappings, original frame IDs.',
		'; Empty pilot frames use the existing shared pod/head children when code is ported.',
		f'{zone}Boss_WeaponTiles = {tiles}']
	if zone=='CNZ':
		lines += ['; Future cycle destinations, byte offsets from v_palette.',
			f'CNZBoss_Cycle2PaletteOffset = ${0x20+SECONDARY_FROM_S2[14]*2:02X}',
			f'CNZBoss_Cycle3PaletteOffset = ${0x20+SECONDARY_FROM_S2[15]*2:02X}',
			'; Body frame 1 draws before the shared pod; topper draws behind it.',
			f'CNZBoss_TopperFrame = {CNZ_TOPPER_FRAME}']
	for family,rows in families.items():
		label = f'Map_{zone}Boss_{family}'
		lines += ['',label+':']+[f'\tdc.w {label}_Frame{i}-{label}' for i in range(len(rows))]
		written = {}
		for i,row in enumerate(rows):
			key = tuple(row)
			if key in written:
				lines.append(f'{label}_Frame{i} equ {label}_Frame{written[key]}')
				continue
			written[key] = i
			lines.append(f'{label}_Frame{i}:\tdc.w {len(row)}')
			for y,size,word,x in row:
				lines += [f'\tdc.b {y},${size:02X}',f'\tdc.w ${word:04X},{x}']
	lines += ['\teven','']
	return '\n'.join(lines).replace('\n','\r\n').encode()


def mcz_drills(families):
	"""Two independently cached drill slots; source frame IDs select slot A.

	Append seven slot-B mappings to the same family for the existing composite
	renderer. Controllers can select the two byte lookup tables by DPLC phase.
	"""
	source = {name:list(rows) for name,rows in families.items()}
	poses = [source['Weapons'][i] for i in MCZ_DRILL_FRAMES]
	for i in MCZ_DRILL_FRAMES:
		source['Weapons'][i] = []
	static,maps = optimize(source)
	static_tiles = len(static)//32
	caches,rows = [],[]
	for pose in poses:
		cache,row = min((pack_frame(b'',pose,p) for p in (32,64)),key=lambda pair:(len(pair[0]),len(pair[1])))
		caches.append(cache)
		rows.append(row)
	slot_tiles = max(len(cache)//32 for cache in caches)
	bank,lookup,cues = bytearray(),{},[]
	for cache in caches:
		cue = []
		for start in range(0,len(cache),32):
			tile = cache[start:start+32]
			if tile not in lookup:
				lookup[tile] = len(bank)//32
				bank.extend(tile)
			cue.append(lookup[tile])
		cues.append(cue)
	def shifted(row,offset):
		return [(y,size,(word&0xF800)|((word&2047)+offset),x) for y,size,word,x in row]
	for i,row in zip(MCZ_DRILL_FRAMES,rows):
		maps['Weapons'][i] = shifted(row,static_tiles)
	first_b = len(maps['Weapons'])
	maps['Weapons'] += [shifted(row,static_tiles+slot_tiles) for row in rows]
	metadata = [f'MCZBoss_StaticTiles = {static_tiles}',f'MCZBoss_DrillSlotTiles = {slot_tiles}',
		f'MCZBoss_DrillSourceTiles = {len(bank)//32}',
		'MCZBoss_DrillFramesA:\tdc.b '+','.join(map(str,MCZ_DRILL_FRAMES)),
		'MCZBoss_DrillFramesB:\tdc.b '+','.join(str(first_b+i) for i in range(len(rows))), '\teven','']
	return static,maps,bytes(bank),cues,static_tiles+slot_tiles*2,'\n'.join(metadata).replace('\n','\r\n').encode()


def drill_dplc(cues):
	label = 'DPLC_MCZBoss_Drills'
	lines = ['; One cue family shared by both independently cached drill slots.',label+':']
	lines += [f'\tdc.w .pose{i}-{label}' for i in range(len(cues))]
	for i,tiles in enumerate(cues):
		runs = []
		for tile in tiles:
			if runs and runs[-1][0]+runs[-1][1]==tile and runs[-1][1]<16:
				runs[-1][1]+=1
			else:
				runs.append([tile,1])
		lines.append(f'.pose{i}:\tdc.w {len(runs)}')
		lines += [f'\tdc.w ${((count-1)<<12)|first:04X}' for first,count in runs]
	return ('\n'.join(lines)+'\n\teven\n').replace('\n','\r\n').encode()


def source_palette(source, zone):
	palette = bytearray((source/f'art/palettes/{zone}.bin').read_bytes())
	if zone in ('MCZ','CNZ'):
		palette[:32] = (source/f'art/palettes/{zone} Boss.bin').read_bytes()
	return palette


def secondary_lookup(source, zone):
	lookup = list(SECONDARY_FROM_S2)
	for index,color in enumerate(struct.unpack('>16H',source_palette(source,zone)[:32])):
		if index and color in (0,0x222):lookup[index] = 1
	return tuple(lookup)


def prepared_palette(source, zone):
	palette = source_palette(source,zone)
	# Only row two changes; all bosses follow the shared black/metal/yellow ramp.
	# CPZ's chemical frames use only 0/8, so its row-four cycle stays untouched.
	old = bytes(palette[:32])
	for before,after in enumerate(SECONDARY_FROM_S2):
		palette[after*2:after*2+2] = old[before*2:before*2+2]
	common = (ROOT/'palette/SonicAndTails.bin').read_bytes()
	for slot in (1,6,7,8,9):
		palette[slot*2:slot*2+2] = common[slot*2:slot*2+2]
	palette[24:26] = struct.pack('>H',0xA88)
	return bytes(palette)


def extras(source, zone):
	if zone=='CPZ':
		raw = nemesis((source/'art/nemesis/Smoke trail from CPZ and HTZ bosses.nem').read_bytes())
		lookup = secondary_lookup(source,zone)
		raw = bytes(lookup[b>>4]<<4|lookup[b&15] for b in raw)
		rows = read_mappings(source/'mappings/sprite/obj5D_d.asm')
		name,family = 'CPZ boss smoke','Smoke'
	elif zone=='MCZ':
		raw = (source/'art/uncompressed/Falling rocks and stalactites from MCZ.bin').read_bytes()
		allrows = read_mappings(source/'mappings/sprite/obj57.asm')
		rows = [allrows[13],allrows[20]]
		name,family = 'MCZ boss debris','Debris'
	else:
		return None
	converted = [[(y,((w-1)<<2)|(h-1),tile|(xf<<11)|(yf<<12)|(pal<<13)|(pri<<15),x)
		for x,y,w,h,tile,xf,yf,pal,pri in row] for row in rows]
	return name,family,raw,converted


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--source',type=Path,required=True)
	p.add_argument('--skdisasm',type=Path,required=True,help='S&K source for the six MTZ egg/orb poses')
	p.add_argument('--write',action='store_true')
	p.add_argument('--check',action='store_true')
	p.add_argument('--report',type=Path)
	a = p.parse_args()
	assert not (a.write and a.check)
	report = []
	for zone in BOSSES:
		original,source = source_boss(a.source,zone,a.skdisasm)
		dynamic = None
		if zone=='MCZ':
			art,mappings,drills,cues,resident,metadata = mcz_drills(source)
			dynamic = bytes(kosinski_plus(drills))
			assert kosinski_plus_decode(dynamic)[0]==drills
		else:
			art,mappings = optimize(source)
			resident,metadata = len(art)//32,b''
		assert 0<resident<=0x501-0x434
		outputs = {ROOT/f'art/uncompressed/{zone} boss weapons.unc':art,
			ROOT/f'art/moduled kosinski/{zone} boss weapons.kospm':pack_moduled(art),
			ROOT/f'palette/{zone} Boss Weapons.bin':prepared_palette(a.source,zone)}
		if dynamic:
			outputs[ROOT/'art/uncompressed/MCZ boss drills.unc'] = drills
			outputs[ROOT/'art/kosinski/MCZ boss drills.kosp'] = dynamic
			outputs[ROOT/'mappings/spriteDPLC/MCZ boss drills.asm'] = drill_dplc(cues)
		if zone=='CNZ':
			for i in range(1,4):
				outputs[ROOT/f'palette/CNZ Boss Weapons Cycle {i}.bin'] = (a.source/f'art/palettes/CNZ Boss Cycle {i}.bin').read_bytes()
		extra = extras(a.source,zone)
		if extra:
			name,family,raw,rows = extra
			outputs[ROOT/f'art/uncompressed/{name}.unc'] = raw
			outputs[ROOT/f'art/moduled kosinski/{name}.kospm'] = pack_moduled(raw)
			mappings[family] = rows
		outputs[ROOT/f'mappings/sprite/{zone} Boss.asm'] = mapping_text(zone,mappings,resident)+metadata
		for path,data in outputs.items():
			if a.write:
				path.write_bytes(data)
			elif a.check:
				assert path.read_bytes()==data, f'Regenerate {path}'
		row = dict(zone=zone,original_tiles=len(original)//32,tiles=resident,static_tiles=len(art)//32,
			last_tile=f'{0x434+resident-1:04X}',last_tile_vram=f'{(0x434+resident-1)*32:04X}',
			gap_tiles=0x501-0x434-resident,
			pieces_before=sum(len(row) for rows in source.values() for row in rows),
			pieces_after=sum(len(row) for family,rows in mappings.items() if family in source for row in rows[:len(source[family])]))
		if dynamic:
			row.update(drill_source_tiles=len(drills)//32,drill_slot_tiles=(resident-len(art)//32)//2,drill_slots=2)
		report.append(row)
		print(json.dumps(row),flush=True)
	if a.report:
		a.report.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':
	main()
