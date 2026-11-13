#!/usr/bin/env python3
"""Import both Metallic Madness acts' four terrain eras and resident art banks.

Read-only source: sonicretro/scddisasm 791253ba1922d7c4142a40975860d1b3bb37b9f7.
Every 256px source chunk retains all four 128px quadrants, including unplaced
and duplicate pieces. Sixteen exact CD collision profiles fill unused shared
slots; Act 2 scopes its alternate angle to the terrain-loader staging copy.
"""
from pathlib import Path
import argparse
import json
import re
import struct

from convert_s1_ss_background import kosinski_plus,kosinski_plus_decode
from import_ehz2_pp_background import nemesis
from level_layout import encode as encode_layout
from sprite_palette import PLAYER_FROM_S1,remap_line,remap_tile_bank
from terrain_collision import BANK_FILES,read_bank,remap_geometry,reflect

ROOT=Path(__file__).resolve().parents[1]
SOURCE_REVISION='791253ba1922d7c4142a40975860d1b3bb37b9f7'
ERAS=(('a','Present','present',''),('b','Past','past','past/'),
	('c','Good Future','good Future','good future/'),
	('d','Bad Future','bad future','bad future/'))
# CD MMZ uses gray slots 5/7/8 and green slots 9/A. It does not have the
# legacy S2 slot arrangement: blindly replacing slots 7-9 loses dark green.
ENEMY_FROM_MMZ=(0,1,12,11,10,7,6,8,9,2,5,4,13,14,15,3)
CD_PROFILES={0x40:0xCC,0x7A:0xCD,0x7B:0xCE,0x7D:0xCF,
	0x7F:0xD0,0x80:0xD8,0xB5:0xD9,0x4C:0xDA,0x6F:0xDB,
	0x70:0xDC,0xA1:0xF5,0xC4:0xF6,0xD1:0xF7,0xD2:0xF8,0xD3:0xF9,0xD4:0xFA}
CD_BANK=('collision_columns.bin','collision_rows.bin','collision_angles.bin')
WATER_TILES=16


def pack(raw):
	encoded=bytes(kosinski_plus(raw))
	assert kosinski_plus_decode(encoded)[0]==raw
	return encoded


def expand_chunks(raw):
	assert len(raw)%512==0
	chunks=[bytes(128)]
	for base in range(0,len(raw),512):
		for qy in range(2):
			for qx in range(2):
				words=[]
				for by in range(8):
					for bx in range(8):
						w=struct.unpack_from('>H',raw,base+(qy*8+by)*32+(qx*8+bx)*2)[0]
						assert w&0x7FF<1024,'CD block ID exceeds the resident block format'
						words.append((w&0x3FF)|(w&0x1800)>>1|(w&0x6000)>>1|(w&0x6000)<<1)
				chunks.append(struct.pack('>64H',*words))
	assert len(chunks)<=1024
	return b''.join(chunks)


def expand_layout(raw,source_chunks,layer_chunks=None):
	width,height=raw[0]+1,raw[1]+1
	assert len(raw)==width*height+2
	rows=[]
	for y in range(height*2):
		row=[]
		for x in range(width*2):
			chunk=raw[2+(y//2)*width+x//2]
			flag=chunk&128;chunk&=127
			if flag and layer_chunks is None:raise ValueError('Layered foreground needs paired collision paths')
			assert chunk<=source_chunks,(chunk,source_chunks)
			quarter=(y&1)*2+(x&1)
			row.append(layer_chunks[chunk][quarter] if flag else 1+(chunk-1)*4+quarter if chunk else 0)
		rows.append(row)
	return rows


# CD's alternate collision chunks. Ordinary foreground art stays unchanged;
# each layer-marked placement selects paired primary/secondary block profiles.
MMZ2_LAYER_CHUNKS={0x46:0x6A,0x48:0x6B,0x4A:0x6C,0x10:0x6D,0x63:0x6E,0x43:0x6F}


def paired_layers(raw,blocks,chunks,indices,bank):
	width,height=raw[0]+1,raw[1]+1
	assert width<=64 and height<=8
	flags=bytearray(64)
	for i,chunk in enumerate(raw[2:]):
		if chunk&128:flags[(i//width)*8+(i%width)//8]|=1<<((i%width)&7)
	blocks=bytearray(blocks);indices=bytearray(indices)
	parts=[chunks[i:i+128] for i in range(0,len(chunks),128)]
	original_count=len(parts)
	chunk_lookup={data:i for i,data in enumerate(parts)}
	block_lookup={(bytes(blocks[i*8:i*8+8]),bytes(indices[i*2:i*2+2])):i for i in range(len(blocks)//8)}
	layers={};created=0
	for normal in sorted({c&127 for c in raw[2:] if c&128}):
		alternate=MMZ2_LAYER_CHUNKS.get(normal,normal)
		if alternate==normal:
			layers[normal]=tuple(1+(normal-1)*4+q for q in range(4));continue
		assert 1+(alternate-1)*4+3<original_count,('Missing authored alternate chunk',normal,alternate)
		converted=[]
		for q in range(4):
			front=struct.unpack('>64H',parts[1+(normal-1)*4+q])
			back=struct.unpack('>64H',parts[1+(alternate-1)*4+q]);row=[]
			for w,v in zip(front,back):
				b=w&1023;c=indices[(v&1023)*2]
				if c:
					profile=reflect(bank[c],((w^v)>>10)&3)
					matches=[i for i,p in enumerate(bank) if reflect(p,0)[:2]==profile[:2] and (bool(p[2]&1) if profile[2]&1 else p[2])==(True if profile[2]&1 else profile[2])]
					assert matches,('A layer needs an exact reflected collision profile',normal,b,c,profile)
					c=matches[0]
				pair=bytes((indices[b*2],c));pixels=bytes(blocks[b*8:b*8+8]);key=pixels,pair
				if key not in block_lookup:
					block_lookup[key]=len(blocks)//8;blocks+=pixels;indices+=pair;created+=1
				row.append((w&0x3C00)|((v&0x3000)<<2)|block_lookup[key])
			payload=struct.pack('>64H',*row)
			if payload not in chunk_lookup:chunk_lookup[payload]=len(parts);parts.append(payload)
			converted.append(chunk_lookup[payload])
		layers[normal]=tuple(converted)
	assert len(blocks)//8<=768 and len(parts)<=1024,(len(blocks)//8,len(parts))
	return bytes(blocks),b''.join(parts),bytes(indices),layers,bytes(flags),dict(paired_blocks=created,paired_chunks=len(parts)-original_count)


def spill_terrain(art,blocks,constants):
	"""Swap 13 static tiles out; move the complete 40-tile animation tail down.

	The 18 reclaimed monitor tiles after the yellow ball hold this static spill.
	No terrain pixels or authored chunks are discarded, and no animation DMA is
	split. The former tail ends exactly before the existing $260 sprite bank.
	"""
	assert len(art)==621*32
	monitor=int(re.search(r'^ArtTile_Monitor:\s*equ\s+\$([0-9A-F]+)',constants,re.M)[1],16)
	spill=monitor+42
	assert 'ArtTile_MMZ2_TerrainSpill:\tequ ArtTile_Monitor_Reclaimed' in constants
	assert spill+13<=monitor+60
	remap={t:spill+t-568 for t in range(568,581)}
	remap.update((t,t-13) for t in range(581,621))
	words=[(w&0xF800)|remap.get(w&2047,w&2047) for w, in struct.iter_unpack('>H',blocks)]
	return art[:568*32]+art[581*32:],struct.pack('>'+str(len(words))+'H',*words),art[568*32:581*32]


def collision_bank(source):
	original=read_bank(ROOT/'collision')
	bank=list(original)
	cd=read_bank(source/'src/maps',CD_BANK)
	for old,new in CD_PROFILES.items():
		if bank[new]!=cd[old]:
			assert not any(bank[new][0]+bank[new][1]),f'Collision slot ${new:X} is occupied'
			for path in (ROOT/'collision').glob('*/*.bin'):
				assert new not in path.read_bytes(),f'Collision slot ${new:X} is referenced by {path}'
			bank[new]=cd[old]
	for i in range(256):
		if i not in CD_PROFILES.values():assert bank[i]==original[i]
	arrays=(b''.join(bytes(v&255 for v in p[0]) for p in bank),
		b''.join(bytes(v&255 for v in p[1]) for p in bank),bytes(p[2] for p in bank))
	return cd,bank,dict(zip(('collision/'+name for name in BANK_FILES),arrays))


def table_values(text,label,kind):
	body=re.split(r'^\S[^\n]*:',text.split(label+':',1)[1],maxsplit=1,flags=re.M)[0]
	values=[]
	for line in body.splitlines():
		line=line.split(';',1)[0]
		m=re.search(r'\bdc\.'+kind+r'\s+(.+)',line)
		if m:values.extend(v.strip() for v in m[1].split(','))
	return values


def number(value):return int(value.replace('$','0x'),0)


def animations(source,constants,act=1):
	"""Retain CD timing while sharing equal raw frame payloads across eras."""
	atlas=bytearray();unique={};text=[f'; Imported MMZ{act} palette/terrain animation data; see import_metallic_madness.py.',
		f'; Pixel art is editable in art/uncompressed/MMZ{act} Animated.unc.','']
	specs={
		'a':('Present',(('byte_20EB0C',0x1FD,8),('byte_20EB1E',0x205,8),
			('byte_20EB30',0x20D,16),('byte_20EA96',0x1ED,16),('byte_20EB42',0x21D,4))),
		'd':('BadFuture',(('unk_20EC56',0x228,8),('unk_20EC68',0x230,8),
			('unk_20EC7A',0x238,16),('unk_20EC8C',0x248,4))),
		'c':('GoodFuture',(('unk_20EADA',0x216,8),('unk_20EAEC',0x21E,8),
			('unk_20EAFE',0x226,16)))}
	if act==2:
		specs={
			'a':('Present',(('byte_20FA18',0x222,8),('byte_20FA2A',0x22A,8),('byte_20FA3C',0x232,16),('byte_20FA4E',0x242,4),('byte_20FA6C',0x246,4))),
			'c':('GoodFuture',(('unk_20FD3A',0x21E,8),('unk_20FD4C',0x226,8),('unk_20FD5E',0x22E,16),('unk_20FD70',0x242,4))),
			'd':('BadFuture',(('unk_20FC40',0x235,8),('unk_20FC52',0x23D,8),('unk_20FC64',0x245,16),('unk_20FC76',0x255,4),('unk_20FC94',0x259,4)))}
	report=[]
	for era,(title,entries) in specs.items():
		data=(source/f'src/r8/data_{act}{era}.asm').read_text()
		files=dict(re.findall(r'^(\w+):\s*\n\s*incbin\s+"([^"]+)"',data,re.M))
		anim=(source/f'src/r8/stage_gfx_animate_{act}{era}.asm').read_text()
		text.append(f'AnimCue_MMZ{act}_{title}:\tzoneanimstart')
		for i,(label,target,count) in enumerate(entries,1):
			values=[number(v) for v in table_values(anim,label,'b')]
			pointers=table_values(anim,label,'l')
			if len(values)>2:
				assert len(values)==2+values[0]*2
				steps=list(zip(values[2::2],values[3::2]))
			else:
				assert values[1]==len(pointers)
				steps=[(values[0],i) for i in range(len(pointers))]
			offsets=[]
			for pointer in pointers:
				frame=(source/files[pointer]).read_bytes()
				assert len(frame)>=count*32,(pointer,len(frame),count)
				frame=frame[:count*32]
				if frame not in unique:
					unique[frame]=len(atlas)//32
					atlas.extend(frame)
				offsets.append(unique[frame])
			base=min(offsets)
			assert max(offsets)-base<=255,'Animation byte offset requires a local frame bank'
			target+=WATER_TILES
			if act==2 and era=='d':target-=13
			dest=f'ArtTile_MMZ{act}_{title}_Anim{i}'
			decl=re.search(r'^'+dest+r':\s*equ\s+\$([\da-fA-F]+)\b',constants,re.M)
			assert decl and int(decl[1],16)==target,('Animation allocation',dest)
			# CD starts with step 1; Dynamic_Normal starts at 0. Rotate the
			# declarative script, preserving frame order and all hold durations.
			steps=steps[1:]+steps[:1]
			text.append(f'\t\tzoneanimdecl -1,Art_MMZ{act}Animated+{base}*32,{dest},{len(steps)},{count}')
			for duration,frame in steps:
				assert 0<=duration<128 and frame<len(offsets)
				text.append(f'\t\tdc.b {offsets[frame]-base},{duration}')
			text.append('\t\teven')
			report.append(dict(era=title,slot=i,tile=target,count=count,
				steps=[dict(duration=d,frame=f) for d,f in steps],source=pointers,offsets=offsets))
		text.extend(('\t\tzoneanimend',''))
	text.extend((f'AnimCue_MMZ{act}_Past:\tdc.w -1',''))
	for era,title,_,_ in ERAS:
		key=title.replace(' ','')
		pal=(source/f'src/r8/palette_cycle_{era}.asm').read_text()
		initial=pal.split('\nCycleColor:',1)[0]
		pairs=re.findall(r'lea\s+(\w+),a1\s*\n\s*lea\s+(\w+),a2',initial)
		pairs=pairs[:{'a':6,'b':5,'c':4,'d':6}[era]]
		text.append(f'MMZ{act}_Pal{key}:')
		text.append(f'\t\tdc.w {len(pairs)-1}')
		cycles=[]
		for j,(script,colors) in enumerate(pairs):
			steps=[number(v) for v in table_values(pal,script,'b')]
			values=[number(v) for v in table_values(pal,colors,'w')]
			slot,count=steps[:2];steps=list(zip(steps[2::2],steps[3::2]))
			assert len(steps)==count
			if era=='c' and slot==0x31:
				# The source pairs are displaced at the long holds, indexing
				# code as colors $16/$42. Restore the six in-range flash steps.
				assert steps==[(2,0),(2,1),(2,0x16),(0,2),(1,0x42),(2,0)]
				steps=[(2,0),(2,1),(0x16,0),(2,1),(0x42,2),(2,0)]
			assert all(0<=d<128 and 0<=c<len(values) for d,c in steps),(era,slot,steps)
			text.extend((f'\t\tdc.w v_palette+${slot:X}*2,{count-1}',f'\t\tdc.l .cycle{j}'))
			cycles.append((steps,values))
		for j,(steps,values) in enumerate(cycles):
			text.append(f'.cycle{j}:')
			for duration,color in steps:
				text.extend((f'\t\tdc.b {duration},0',f'\t\tdc.w ${values[color]:03X}'))
		text.append('')
	text.append('')
	outputs={f'art/uncompressed/MMZ{act} Animated.unc':bytes(atlas),
		f'_inc/Metallic Madness'+('' if act==1 else ' 2')+' Animation Data.asm':('\r\n'.join(text).rstrip()+'\r\n').encode()}
	return outputs,dict(tiles=len(atlas)//32,bytes=len(atlas),streams=report)


def sprites(source,constants):
	"""Keep one resident atlas and load only the art differing in Past/GF."""
	from import_palmtree_enemies import mapping as cd_mapping
	from check_sprite_assets import frames
	from build_seesaw_art import encode as encode_sprites
	from build_end_art import pack_moduled
	from sprite_art import pack_rectangles,find_tiles
	from sprite_palette import remap_pixels
	from check_boss_shared_art import raster
	base=int(re.search(r'^ArtTile_MMZ_Atlas:\s*equ\s+\$([\da-fA-F]+)',constants,re.M)[1],16)
	limit=int(re.search(r'^ArtTile_MMZ_Atlas_End:\s*equ\s+\$([\da-fA-F]+)',constants,re.M)[1],16)
	identity=tuple(range(16));palettes=(PLAYER_FROM_S1,ENEMY_FROM_MMZ,identity,identity)
	# Each tuple is mapping file, root, selected frames, palette by frame.
	specs=(('Vanish','vanish_platform',[('vanish_platform','.Sprites',None,0)]),
		('Spin','rotate_platform',[('spin_platform','.Sprites',None,0)]),
		('Crusher','crusher',[('crusher','.Sprites',None,0)]),
		('Floor','collapse_floor',[('collapse_floor','.Sprites',None,2)]),
		('Saw','buzzsaw_abd',[('buzzsaw_ab','.Sprites',None,2),('buzzsaw_handle','.Sprites',None,2)]),
		('Seesaw','seesaw_abd',[('seesaw','.Sprites',None,lambda f:2 if 5<=f<=7 else 0)]),
		('MechaBu','mecha_bu',[('mecha_bu','.Sprites',None,1),('mecha_bu_saw','.Sprites',None,1)]),
		('PohBee','poh_bee',[('poh_bee','.Sprites1',None,1),('poh_bee','.Sprites2',None,1)]),
		('Scarab','scarab',[('scarab','.Sprites',None,1)]),
		('TimePost','../monitor_time',[('../monitor_time','.Sprites',slice(10,16),0)]),
		('Generator','../robot_transport_b',[('../robot_transport','.Sprites',None,0)]))
	atlas=bytearray();overlays={};outputs={};report=[]
	for family,art,maps in specs:
		folder=source/'src'
		paths=[folder/f'gfx/r8/{art}.nem']*3
		if family in ('Saw','Seesaw'):paths[2]=folder/f'gfx/r8/{art.removesuffix("_abd")}_c.nem'
		if family=='Generator':paths=[folder/'gfx/robot_transport_a.nem',folder/'gfx/robot_transport_b.nem',folder/'gfx/robot_transport_a.nem']
		banks=[nemesis(p.read_bytes()) for p in paths]
		# Present/GF never select the Past-only generator frames. Their missing
		# tiles stay transparent at matching indices rather than reading neighbors.
		if family=='Generator':banks=[b+bytes(23*32-len(b)) for b in banks]
		patterns=[];families=[]
		for mi,(name,root,selection,palette) in enumerate(maps):
			text=(folder/f'sprites/r8/{name}.asm').read_text()
			rs=frames(cd_mapping(text,root))
			if selection is not None:rs=rs[selection]
			# Signs borrow the global S1 post; only the first CD head piece survives.
			if family=='TimePost':rs=[row[:1] for row in rs]
			if family=='Saw' and mi==0:
				gf=frames(cd_mapping((folder/'sprites/r8/buzzsaw_cd.asm').read_text(),'.Sprites'))
				assert rs==gf,'Era-specific saw geometry needs separate mappings'
			packed=[]
			for fi,row in enumerate(rs):
				pal=palette(fi) if callable(palette) else palette
				pieces=[]
				for y,size,word,x in row:
					first=word&2047;count=((size>>2)+1)*((size&3)+1)
					assert all((first+count)*32<=len(b) for b in banks),(family,fi,first,count)
					pattern=tuple(tuple(remap_pixels(b[t*32:(t+1)*32],palettes[pal]) for b in banks)
						for t in range(first,first+count))
					patterns.append(pattern);pieces.append((y,size,(word&0x1800)|(pal<<13),x,pattern))
				packed.append(pieces)
			families.append((mi,name,packed,rs,palette))
		tiles=pack_rectangles(patterns);offset=len(atlas)//32
		if family in ('Saw','Seesaw','Generator'):
			assert re.search(r'^ArtTile_MMZ_'+family+r':\s*equ ArtTile_MMZ_Atlas\+'+str(offset)+r'\b',constants,re.M),('Overlay destination',family,offset)
		payloads=[b''.join(t[e] for t in tiles) for e in range(3)]
		atlas.extend(payloads[0])
		if family=='TimePost':
			assert len(tiles)==22
			assert all(find_tiles(tiles,p)==t for p,t in zip(patterns,(0,0,8,8,16,20)))
		for era,index in (('Past',1),('Good Future',2)):
			if payloads[index]!=payloads[0]:
				filename=f'MMZ1 {family} {era}'
				outputs[f'art/uncompressed/{filename}.unc']=payloads[index]
				overlays[family,era]=(offset,len(tiles))
		for mi,name,packed,original,palette in families:
			rows=[]
			for row in packed:
				rows.append([(y,size,word|(offset+find_tiles(tiles,pattern)),x) for y,size,word,x,pattern in row])
			label=family if len(families)==1 else family+(' Saw' if family=='MechaBu' and mi else ' Handle' if family=='Saw' and mi else ' Alternate' if mi else '')
			outputs[f'mappings/sprite/MMZ {label}.bin']=encode_sprites(rows)
			# Compare visible indexed pixels in every era, independent of the
			# rectangle packer's storage order and complete mapping-piece overlap.
			for era in range(3):
				for fi,(before,after) in enumerate(zip(original,rows)):
					pal=palette(fi) if callable(palette) else palette
					expected=raster(before,[(0,banks[era])])
					expected={xy:(pal,palettes[pal][c]) for xy,(_,c) in expected.items()}
					actual=raster(after,[(offset,payloads[era])])
					assert actual==expected,(family,era,fi,'sprite pixels or attributes')
		report.append(dict(family=family,offset=offset,tiles=len(tiles)))
	assert base+len(atlas)//32<=limit,('MMZ sprite atlas overlaps common objects',len(atlas)//32,limit-base)
	outputs['art/uncompressed/MMZ1 Sprite Atlas.unc']=bytes(atlas)
	return outputs,dict(tiles=len(atlas)//32,base=base,end=base+len(atlas)//32,
		families=report,overlays=[dict(family=f,era=e,offset=o,tiles=n) for (f,e),(o,n) in overlays.items()])


def sprites2(source):
	"""Act 2's private art fills the three holes between shared Act 1 families.

	The 72 crusher/floor, 48 Mecha-Bu, 22 sign-head and 23 generator tiles retain
	their existing addresses. New mapping families share those same bank bases.
	Only the three private ranges are stored; the editor composite is generated.
	"""
	from import_palmtree_enemies import mapping as cd_mapping
	from check_sprite_assets import frames
	from build_seesaw_art import encode
	from sprite_art import pack_rectangles,find_tiles
	from sprite_palette import remap_pixels
	from check_boss_shared_art import raster
	identity=tuple(range(16));palettes=(PLAYER_FROM_S1,ENEMY_FROM_MMZ,identity,identity)
	# family, art, mapping file/root pairs, source base palette, fixed offset/capacity
	specs=(('Laser','laser',(('r8/laser','.Sprites1'),('r8/laser','.Sprites2')),0,0,16),
		('Door','door',(('r8/door_1','.Sprites'),('r8/door_2','.Sprites'),('r8/door_3','.Sprites')),0,16,10),
		('TubeDoor','tube_cover',(('r8/tube_door','.Sprites'),),0,26,4),
		('BigBom','bigbom',(('r8/bigbom','.Sprites'),('r8/bigbom_fuse','.Sprites'),('r8/bigbom_debris','.Sprites')),0,110,94),
		('TwinWalker','twin_walker',(('r8/twin_walker','.Sprites'),),0,204,17),
		('SpikeCrusher','spike_crusher',(('r8/spike_crusher','.Sprites'),),0,221,27),
		('Dango','dango',(('r7/dango','.Sprites1'),('r7/dango','.Sprites2')),1,318,78),
		('RevolveDoor','revolve_door',(('r8/revolve_door','.Sprites'),),0,396,24))
	outputs={};atlas=bytearray(477*32);report=[]
	for family,art,maps,basepal,offset,capacity in specs:
		raw=nemesis((source/f'src/gfx/r8/{art}.nem').read_bytes());patterns=[];families=[]
		for name,label in maps:
			rows=frames(cd_mapping((source/f'src/sprites/{name}.asm').read_text(),label,allow_palettes=True));packed=[]
			for row in rows:
				pieces=[]
				for y,size,word,x in row:
					first=word&2047;count=((size>>2)+1)*((size&3)+1);pal=(basepal+(word>>13&3))&3
					assert (first+count)*32<=len(raw),(family,first,count,len(raw)//32)
					pattern=tuple(remap_pixels(raw[t*32:(t+1)*32],palettes[pal]) for t in range(first,first+count))
					patterns.append(pattern);pieces.append((y,size,(word&0x1800)|(pal<<13),x,pattern))
				packed.append(pieces)
			families.append((name,label,rows,packed))
		tiles=pack_rectangles(patterns);assert len(tiles)<=capacity,(family,len(tiles),capacity)
		payload=b''.join(tiles);atlas[offset*32:(offset+len(tiles))*32]=payload
		for i,(name,label,original,packed) in enumerate(families):
			rows=[[(y,z,word|(offset+find_tiles(tiles,pattern)),x) for y,z,word,x,pattern in row] for row in packed]
			filename=family+(' '+str(i+1) if len(families)>1 else '')
			outputs[f'mappings/sprite/MMZ {filename}.bin']=encode(rows)
			for fi,(before,after) in enumerate(zip(original,rows)):
				expected={(x,y):((basepal+pal)&3,palettes[(basepal+pal)&3][c]) for (x,y),(pal,c) in raster(before,[(0,raw)]).items()}
				assert raster(after,[(offset,payload)])==expected,(family,i,fi,'visible pixels/attributes')
		report.append(dict(family=family,offset=offset,tiles=len(tiles),capacity=capacity))
	button=(ROOT/'art/uncompressed/Platform button.unc').read_bytes();assert len(button)==8*32
	atlas[30*32:38*32]=button
	for name,start,count in (('MMZ2 Emitters and doors',0,38),('MMZ2 Bomb and crushers',110,138),('MMZ2 Dango and doors',318,102)):
		outputs[f'art/uncompressed/{name}.unc']=bytes(atlas[start*32:(start+count)*32])
	return outputs,dict(families=report,private_tiles=278,shared_tiles=165)


def build(source):
	constants=(ROOT/'_definitions/s2.constants.asm').read_text()
	limit=re.search(r'^ArtTile_MMZ_Atlas:\s*equ\s+\$([0-9A-Fa-f]+)\b',constants,re.M)
	assert limit,'Review the shared terrain/sprite allocation before importing'
	static_limit=int(limit[1],16)
	cd,shared,outputs=collision_bank(source)
	grays=(ROOT/'palette/SonicAndTails.bin').read_bytes()[14:20]
	report=[]
	layer_flags=bytearray()
	for act in (1,2):
		for key,title,col_folder,layout_folder in ERAS:
			name=f'MMZ{act} '+title
			maps=source/'src/maps/r8'
			art=nemesis((maps/f'gfx_{act}{key}.nem').read_bytes())
			blocks=nemesis((maps/f'blocks_{act}{key}.nem').read_bytes())
			original_blocks=blocks
			assert not any(art[:32]),'Terrain tile zero must remain transparent'
			chunks=expand_chunks((maps/f'chunks_{act}{key}.bin').read_bytes())
			count=max(len(blocks)//8,1+max(w&1023 for w, in struct.iter_unpack('>H',chunks)))
			assert count<=768
			blocks+=bytes(count*8-len(blocks))
			indices=(maps/f'collision_{act}{key}.bin').read_bytes()
			assert len(indices)>=count
			indices=b''.join(bytes((v,v)) for v in indices[:count])
			art,blocks=remap_tile_bank(art,blocks,{0:PLAYER_FROM_S1,1:ENEMY_FROM_MMZ})
			# Reserve the same transparent/water prefix as every other terrain bank.
			art=art[:32]+bytes(WATER_TILES*32)+art[32:]
			words=list(struct.unpack('>'+str(len(blocks)//2)+'H',blocks))
			words=[(w&0xF800)|((w&2047)+WATER_TILES if w&2047 else 0) for w in words]
			blocks=struct.pack('>'+str(len(words))+'H',*words)
			if act==2 and key=='d':
				from build_end_art import pack_moduled
				art,blocks,spill=spill_terrain(art,blocks,constants)
				outputs['art/uncompressed/MMZ2 Bad Future Spill.unc']=spill
				outputs['art/moduled kosinski/MMZ2 Bad Future Spill.kospm']=pack_moduled(spill)
				outputs['art/kosinski/level/MMZ2 Bad Future Spill.kosp']=pack(spill)
			assert len(art)//32<=static_limit
			assert all((w&2047)<static_limit or act==2 and key=='d' and 0x553<=(w&2047)<0x560 for w, in struct.iter_unpack('>H',blocks))
			# One existing shape needs CD's $C8 angle only in Act 2. Override the
			# staged angle byte, preserving every other level and avoiding a second
			# height/width bank. The nine remaining missing profiles fit free slots.
			bank=shared
			if act==2:
				bank=list(shared);bank[0x69]=(bank[0x69][0],bank[0x69][1],0xC8)
				outputs['collision/MMZ2 angles.bin']=bytes(p[2] for p in bank)
			blocks,chunks,(indices,),flips=remap_geometry(blocks,chunks,[indices],cd,bank)
			source_count=(len(chunks)-128)//512
			foreground=(maps/f'foreground_{act}{key}.bin').read_bytes()
			layer_stats={};layers=None
			if act==2:
				blocks,chunks,indices,layers,flags,layer_stats=paired_layers(foreground,blocks,chunks,indices,bank)
				layer_flags+=flags
			fg=expand_layout(foreground,source_count,layers)
			bg=expand_layout((maps/f'background_{act}{key}.bin').read_bytes(),source_count)
			palette=bytearray((source/f'src/palettes/r8/stage_{act}{key}.pal').read_bytes())
			assert len(palette)==96
			assert tuple(struct.unpack('>16H',palette[:32])[i] for i in (5,7,8))==(0xAAA,0x888,0x444)
			palette[:32]=struct.pack('>16H',*remap_line(struct.unpack('>16H',palette[:32]),ENEMY_FROM_MMZ))
			palette[14:20]=grays
			for prefix,data in ((f'art/kosinski/level/8x8 - {name}',art),
				(f'mappings/16x16/{name}',blocks),(f'mappings/128x128/{name}',chunks)):
				outputs[prefix+'.unc']=data
				outputs[prefix+'.kosp']=pack(data)
			outputs[f'palette/{name}.bin']=bytes(palette)
			outputs[f'collision/{col_folder}/LV0F{act}.bin']=indices
			outputs[f'level/layout/{layout_folder}LV0F_{act}.kosp']=pack(encode_layout(fg,bg))
			start=(maps/f'spawn_{act}{key}.bin').read_bytes()
			assert len(start)==4
			if key=='a':outputs[f'startpos/LV0F_{act}.bin']=start
			else:assert start==outputs[f'startpos/LV0F_{act}.bin'],'Era-specific starts need explicit runtime selection'
			report.append(dict(act=act,era=title,**layer_stats,tiles=len(art)//32,source_blocks=len(original_blocks)//8,
				blocks=len(blocks)//8,chunks=len(chunks)//128,fg=[len(fg[0]),len(fg)],
				bg=[len(bg[0]),len(bg)],start=list(struct.unpack('>HH',start)),
				compensated_blocks=sum(bool(f) for f in flips.values())))
	outputs['mappings/128x128/MMZ2 Layer Flags.bin']=bytes(layer_flags)
	animated,animation_report=animations(source,constants)
	outputs.update(animated)
	animated2,animation2_report=animations(source,constants,2)
	outputs.update(animated2)
	animation_report['act2']=animation2_report
	sprite_outputs,sprite_report=sprites(source,constants)
	outputs.update(sprite_outputs)
	sprite2_outputs,sprite2_report=sprites2(source)
	outputs.update(sprite2_outputs)
	sprite_report['act2']=sprite2_report
	return outputs,report,animation_report,sprite_report


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--source',type=Path,required=True)
	p.add_argument('--report',type=Path)
	p.add_argument('--check',action='store_true',help='Verify committed outputs without writing them')
	args=p.parse_args()
	outputs,report,animation_report,sprite_report=build(args.source)
	for name,data in outputs.items():
		path=ROOT/name
		if args.check:
			assert path.read_bytes()==data,('Generated asset differs',name)
		else:
			path.parent.mkdir(parents=True,exist_ok=True)
			path.write_bytes(data)
	result=dict(source=SOURCE_REVISION,eras=report,exact_collision_profiles=CD_PROFILES,animations=animation_report,sprites=sprite_report)
	if args.report:
		args.report.parent.mkdir(parents=True,exist_ok=True)
		args.report.write_text(json.dumps(result,indent=2)+'\n')
	print(json.dumps(result))


if __name__=='__main__':main()
