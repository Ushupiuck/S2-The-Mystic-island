#!/usr/bin/env python3
"""Import Metallic Madness 1's four terrain eras and resident sprite atlas from scddisasm test.

Read-only source: sonicretro/scddisasm 791253ba1922d7c4142a40975860d1b3bb37b9f7.
Every 256px source chunk retains all four 128px quadrants, including unplaced
and duplicate pieces. Seven exact CD collision profiles fill unused shared
slots; existing terrain profiles and their angles remain unchanged.
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
from terrain_collision import BANK_FILES,read_bank,remap_geometry

ROOT=Path(__file__).resolve().parents[1]
SOURCE_REVISION='791253ba1922d7c4142a40975860d1b3bb37b9f7'
ERAS=(('a','Present','present',''),('b','Past','past','past/'),
	('c','Good Future','good Future','good future/'),
	('d','Bad Future','bad future','bad future/'))
# CD MMZ uses gray slots 5/7/8 and green slots 9/A. It does not have the
# legacy S2 slot arrangement: blindly replacing slots 7-9 loses dark green.
ENEMY_FROM_MMZ=(0,1,12,11,10,7,6,8,9,2,5,4,13,14,15,3)
CD_PROFILES={0x40:0xCC,0x7A:0xCD,0x7B:0xCE,0x7D:0xCF,
	0x7F:0xD0,0x80:0xD8,0xB5:0xD9}
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


def expand_layout(raw,source_chunks):
	width,height=raw[0]+1,raw[1]+1
	assert len(raw)==width*height+2
	rows=[]
	for y in range(height*2):
		row=[]
		for x in range(width*2):
			chunk=raw[2+(y//2)*width+x//2]
			assert chunk<128,'MMZ2 layer-changing chunks require a separate path conversion'
			assert chunk<=source_chunks,(chunk,source_chunks)
			row.append(1+(chunk-1)*4+(y&1)*2+(x&1) if chunk else 0)
		rows.append(row)
	return rows


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


def animations(source,constants):
	"""Retain CD timing while sharing equal raw frame payloads across eras."""
	atlas=bytearray();unique={};text=['; Imported MMZ1 palette/terrain animation data; see import_metallic_madness.py.',
		'; Pixel art is editable in art/uncompressed/MMZ1 Animated.unc.','']
	specs={
		'a':('Present',(('byte_20EB0C',0x1FD,8),('byte_20EB1E',0x205,8),
			('byte_20EB30',0x20D,16),('byte_20EA96',0x1ED,16),('byte_20EB42',0x21D,4))),
		'd':('BadFuture',(('unk_20EC56',0x228,8),('unk_20EC68',0x230,8),
			('unk_20EC7A',0x238,16),('unk_20EC8C',0x248,4))),
		'c':('GoodFuture',(('unk_20EADA',0x216,8),('unk_20EAEC',0x21E,8),
			('unk_20EAFE',0x226,16)))}
	report=[]
	for era,(title,entries) in specs.items():
		data=(source/f'src/r8/data_1{era}.asm').read_text()
		files=dict(re.findall(r'^(\w+):\s*\n\s*incbin\s+"([^"]+)"',data,re.M))
		anim=(source/f'src/r8/stage_gfx_animate_1{era}.asm').read_text()
		text.append(f'AnimCue_MMZ1_{title}:\tzoneanimstart')
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
			dest=f'ArtTile_MMZ1_{title}_Anim{i}'
			decl=re.search(r'^'+dest+r':\s*equ\s+\$([\da-fA-F]+)\b',constants,re.M)
			assert decl and int(decl[1],16)==target+WATER_TILES,('Animation allocation',dest)
			# CD starts with step 1; Dynamic_Normal starts at 0. Rotate the
			# declarative script, preserving frame order and all hold durations.
			steps=steps[1:]+steps[:1]
			text.append(f'\t\tzoneanimdecl -1,Art_MMZ1Animated+{base}*32,{dest},{len(steps)},{count}')
			for duration,frame in steps:
				assert 0<=duration<128 and frame<len(offsets)
				text.append(f'\t\tdc.b {offsets[frame]-base},{duration}')
			text.append('\t\teven')
			report.append(dict(era=title,slot=i,tile=target+WATER_TILES,count=count,
				steps=[dict(duration=d,frame=f) for d,f in steps],source=pointers,offsets=offsets))
		text.extend(('\t\tzoneanimend',''))
	text.extend(('AnimCue_MMZ1_Past:\tdc.w -1',''))
	for era,title,_,_ in ERAS:
		key=title.replace(' ','')
		pal=(source/f'src/r8/palette_cycle_{era}.asm').read_text()
		initial=pal.split('\nCycleColor:',1)[0]
		pairs=re.findall(r'lea\s+(\w+),a1\s*\n\s*lea\s+(\w+),a2',initial)
		pairs=pairs[:{'a':6,'b':5,'c':4,'d':6}[era]]
		text.append(f'MMZ1_Pal{key}:')
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
	outputs={'art/uncompressed/MMZ1 Animated.unc':bytes(atlas),
		'_inc/Metallic Madness Animation Data.asm':('\r\n'.join(text).rstrip()+'\r\n').encode()}
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
		('TimePost','../monitor_time',[('../monitor_time','.Sprites',slice(8,None),0)]),
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
		for era,index in (('Past',1),('Good Future',2)):
			if payloads[index]!=payloads[0]:
				filename=f'MMZ1 {family} {era}'
				outputs[f'art/uncompressed/{filename}.unc']=payloads[index]
				outputs[f'art/moduled kosinski/{filename}.kospm']=pack_moduled(payloads[index])
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
	outputs['art/moduled kosinski/MMZ1 Sprite Atlas.kospm']=pack_moduled(atlas)
	return outputs,dict(tiles=len(atlas)//32,base=base,end=base+len(atlas)//32,
		families=report,overlays=[dict(family=f,era=e,offset=o,tiles=n) for (f,e),(o,n) in overlays.items()])


def build(source):
	constants=(ROOT/'_definitions/s2.constants.asm').read_text()
	limit=re.search(r'^ArtTile_MMZ_Atlas:\s*equ\s+\$([0-9A-Fa-f]+)\b',constants,re.M)
	assert limit,'Review the shared terrain/sprite allocation before importing'
	static_limit=int(limit[1],16)
	cd,shared,outputs=collision_bank(source)
	grays=(ROOT/'palette/SonicAndTails.bin').read_bytes()[14:20]
	report=[]
	for key,title,col_folder,layout_folder in ERAS:
		name='MMZ1 '+title
		maps=source/'src/maps/r8'
		art=nemesis((maps/f'gfx_1{key}.nem').read_bytes())
		blocks=nemesis((maps/f'blocks_1{key}.nem').read_bytes())
		original_blocks=blocks
		assert not any(art[:32]),'Terrain tile zero must remain transparent'
		chunks=expand_chunks((maps/f'chunks_1{key}.bin').read_bytes())
		count=max(len(blocks)//8,1+max(w&1023 for w, in struct.iter_unpack('>H',chunks)))
		assert count<=768
		blocks+=bytes(count*8-len(blocks))
		indices=(maps/f'collision_1{key}.bin').read_bytes()
		assert len(indices)>=count
		indices=b''.join(bytes((v,v)) for v in indices[:count])
		art,blocks=remap_tile_bank(art,blocks,{0:PLAYER_FROM_S1,1:ENEMY_FROM_MMZ})
		# Reserve the same transparent/water prefix as every other terrain bank.
		art=art[:32]+bytes(WATER_TILES*32)+art[32:]
		words=list(struct.unpack('>'+str(len(blocks)//2)+'H',blocks))
		words=[(w&0xF800)|((w&2047)+WATER_TILES if w&2047 else 0) for w in words]
		assert max(w&2047 for w in words)<static_limit,'Terrain overlaps the resident sprite atlas'
		assert len(art)//32<=static_limit
		blocks=struct.pack('>'+str(len(words))+'H',*words)
		blocks,chunks,(indices,),flips=remap_geometry(blocks,chunks,[indices],cd,shared)
		source_count=(len(chunks)-128)//512
		fg=expand_layout((maps/f'foreground_1{key}.bin').read_bytes(),source_count)
		bg=expand_layout((maps/f'background_1{key}.bin').read_bytes(),source_count)
		palette=bytearray((source/f'src/palettes/r8/stage_1{key}.pal').read_bytes())
		assert len(palette)==96
		assert tuple(struct.unpack('>16H',palette[:32])[i] for i in (5,7,8))==(0xAAA,0x888,0x444)
		palette[:32]=struct.pack('>16H',*remap_line(struct.unpack('>16H',palette[:32]),ENEMY_FROM_MMZ))
		palette[14:20]=grays
		for prefix,data in ((f'art/kosinski/level/8x8 - {name}',art),
			(f'mappings/16x16/{name}',blocks),(f'mappings/128x128/{name}',chunks)):
			outputs[prefix+'.unc']=data
			outputs[prefix+'.kosp']=pack(data)
		outputs[f'palette/{name}.bin']=bytes(palette)
		outputs[f'collision/{col_folder}/LV0F1.bin']=indices
		outputs[f'level/layout/{layout_folder}LV0F_1.kosp']=pack(encode_layout(fg,bg))
		start=(maps/f'spawn_1{key}.bin').read_bytes()
		assert len(start)==4
		if key=='a':outputs['startpos/LV0F_1.bin']=start
		else:assert start==outputs['startpos/LV0F_1.bin'],'Era-specific starts need explicit runtime selection'
		report.append(dict(era=title,tiles=len(art)//32,source_blocks=len(original_blocks)//8,
			blocks=len(blocks)//8,chunks=len(chunks)//128,fg=[len(fg[0]),len(fg)],
			bg=[len(bg[0]),len(bg)],start=list(struct.unpack('>HH',start)),
			compensated_blocks=sum(bool(f) for f in flips.values())))
	animated,animation_report=animations(source,constants)
	outputs.update(animated)
	sprite_outputs,sprite_report=sprites(source,constants)
	outputs.update(sprite_outputs)
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
