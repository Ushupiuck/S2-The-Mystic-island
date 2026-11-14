#!/usr/bin/env python3
"""Check shared S1 pilot/exhaust pixels, expressions and live EHZ attachment.

Optional reference ROM/listing compare against the former unsplit S1 mappings.
The emulator scenes use normal constructors, PLCs and updates with staged
players; they are visual/lifecycle fixtures, not controller-only playthroughs.
"""
from pathlib import Path
import argparse
import json
import struct

from check_ehz_boss import symbols
from check_sprite_assets import frames
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]


def unpack(rom, address):
	count = struct.unpack_from('>H', rom, address)[0]
	out, address = bytearray(), address+2
	while len(out) < count:
		block, address = kosinski_plus_decode(rom, address)
		out += block
	assert len(out) == count
	return bytes(out)


def raster(row, banks, origin=0):
	"""Compare visible hardware pixels, including mapping flips/priority order."""
	pixels = {}
	for y, size, word, x in reversed(row):
		w, h = (size >> 2)+1, (size & 3)+1
		for tx in range(w):
			for ty in range(h):
				tile = origin+(word & 2047)+tx*h+ty
				base, raw = next((a,b) for a,b in banks if a <= tile < a+len(b)//32)
				for p, n in enumerate(c for b in raw[(tile-base)*32:(tile-base+1)*32] for c in (b >> 4,b & 15)):
					if not n:
						continue
					px, py = tx*8+p%8, ty*8+p//8
					if word & 0x800:
						px = w*8-1-px
					if word & 0x1000:
						py = h*8-1-py
					pixels[x+px,y+py] = ((word >> 13) & 3,n)
	return pixels


def head_frame(rom, s, pose):
	"""Expand the compiled DPLC independently of the art generator."""
	source = unpack(rom,s['Kospm_EggmanFace' if pose<7 else 'Kospm_EggRoboHead'])
	root = s['DPLC_BossHeads']
	cue = root+struct.unpack_from('>h',rom,root+pose*2)[0]
	count = struct.unpack_from('>H',rom,cue)[0]
	cache = bytearray()
	for i in range(count):
		word = struct.unpack_from('>H',rom,cue+2+i*2)[0]
		first, length = (word&0xFFF)*32, ((word>>12)+1)*32
		assert first+length<=len(source),('DPLC outside source',pose,i)
		cache += source[first:first+length]
	assert 0<len(cache)<=s['BossFace_VRAMTiles']*32,(pose,len(cache))
	return bytes(cache)


def face_banks(rom, s, pose):
	head = head_frame(rom,s,pose) if 'DPLC_BossHeads' in s else unpack(rom,s['Kospm_EggmanFace'])
	return [(s['ArtTile_Eggman'],unpack(rom,s['Kospm_OldEggPod'])),(s['ArtTile_EggmanFace'],head)]


def display_color(g,word):
	if 'ClownMDEmu' in g.emulator:word |= (word&0x888)>>3
	r,green,b = (word>>shift&15 for shift in (0,4,8))
	return (((r<<1)|(r>>3))*255//31,((green<<2)|(green>>2))*255//63,((b<<1)|(b>>3))*255//31)


def queue_fixture(g,fixture,bank,dest):
	program = struct.pack('>HIHHHHHI',0x223C,fixture+32,0x343C,dest,0x363C,len(bank)//2,0x4EF9,g.s['QueueDMATransfer'])
	for offset,value in enumerate(program+bytes(32-len(program))+bank):g.write(fixture+offset,value)



def reference_checks(a, rom, s):
	if not a.reference_rom:
		return []
	old, before = a.reference_rom.read_bytes(), symbols(a.reference_listing)
	legacy = len(unpack(old,before['Kospm_OldEggPod']))==108*32
	if legacy:
		oldbanks = [(before[tile],unpack(old,before[label])) for tile,label in (
			('ArtTile_Eggman','Kospm_OldEggPod'),('ArtTile_Eggman_Exhaust','Kospm_Exhaust'))]
		oldrows = frames(old,before['Map_Eggman'],13)[1:8]
	else:
		oldrows = frames(old,before['Map_GHZBoss_Cockpit'],7)
	from build_boss_shared_art import seat_color,head_color
	for index,(row,previous) in enumerate(zip(frames(rom,s['Map_GHZBoss_Cockpit'],7),oldrows)):
		original = raster(previous,oldbanks if legacy else face_banks(old,before,index),before['ArtTile_Eggman'])
		expected = {(x,y):(line,head_color(index,x,y,seat_color(x,y,color))) for (x,y),(line,color) in original.items()} if legacy else original
		actual = raster(row,face_banks(rom,s,index),s['ArtTile_Eggman'])
		# The windshield now has transparent glass and sits in front of the
		# pilot. All other human/cockpit pixels retain the source appearance.
		outside = lambda pixels:{p:c for p,c in pixels.items() if not(-20<=p[0]<-4 and -20<=p[1]<-4)}
		assert outside(actual)==outside(expected),('Pilot pixels changed outside the windshield',index)
	newfire = frames(rom,s['Map_BossExhaust'],5)
	firebank = [(s['ArtTile_Eggman_Exhaust'],unpack(rom,s['Kospm_Exhaust']))]
	oldfire = [frames(old,before['Map_Eggman'],13)[i] for i in (8,9,11,12,10)] if legacy else frames(old,before['Map_BossExhaust'],5)
	oldfirebank = oldbanks if legacy else [(before['ArtTile_Eggman_Exhaust'],unpack(old,before['Kospm_Exhaust']))]
	for index,(row,previous) in enumerate(zip(newfire,oldfire)):
		actual = raster(row,firebank,s['ArtTile_Eggman_Exhaust'])
		if legacy:
			actual = {(x+34,y):c for (x,y),c in actual.items()}
		assert actual==raster(previous,oldfirebank,before['ArtTile_Eggman' if legacy else 'ArtTile_Eggman_Exhaust']),('S1 flame changed',index)
	oldhull = raster(frames(old,before['Map_Eggman'],1)[0],oldbanks if legacy else face_banks(old,before,0),before['ArtTile_Eggman'])
	expectedhull = {(x,y):(line,seat_color(x,y,color) if line==0 else color) for (x,y),(line,color) in oldhull.items()} if legacy else oldhull
	assert raster(frames(rom,s['Map_Eggman'],1)[0],face_banks(rom,s,0),s['ArtTile_Eggman'])==expectedhull
	return ['all seven Eggman expressions outside the new glass overlay, the hull and exhaust remain pixel-exact against the reference']


def native_checks(a):
	from native_test_core import Native, UC_M68K_REG_A1
	class BossMachine(Native):
		def hook(self,cpu,address,size,unused):
			if address==self.s['DisplaySprite']:
				from native_test_core import UC_M68K_REG_A0
				self.drawn.append(self.get(cpu.reg_read(UC_M68K_REG_A0),'obFrame'))
			super().hook(cpu,address,size,unused)
	m = BossMachine(a.rom,a.listing)
	m.drawn = []
	s = m.s
	m.cpu.mem_write(s['DisplaySprite'],bytes.fromhex('4E75'))
	pool = list(range(s['v_lvlobjspace'],s['v_lvlobjend'],s['object_size']))
	rom = a.rom.read_bytes()
	import configparser
	ini = configparser.ConfigParser()
	ini.read(ROOT/'SonLVL INI Files/objGHZ.ini')
	assert int(ini['3D']['headtileoffset'])==s['ArtTile_EggmanFace']-s['ArtTile_Eggman']
	result = reference_checks(a,rom,s)
	assert len(unpack(rom,s['Kospm_EggmanFace']))==s['Art_EggmanFace_End']-s['Art_EggmanFace']
	assert len(unpack(rom,s['Kospm_EggRoboHead']))==s['Art_EggRoboHead_End']-s['Art_EggRoboHead']
	for label,name in (('Kospm_OldEggPod','Old Eggpod'),('Kospm_EggmanFace','Eggman face'),('Kospm_EggRoboHead','Egg Robo head')):
		assert unpack(rom,s[label])==(ROOT/f'art/uncompressed/{name}.unc').read_bytes(),('Packed bank differs from editable art',name)
	assert s['ArtTile_EggmanFace']==s['ArtTile_Eggman']+60
	assert max(len(head_frame(rom,s,i)) for i in range(s['BossFace_FrameCount']))==8*32
	if a.skdisasm:
		from import_scrap_madness import classic_kosinski
		from sprite_palette import PLAYER_FROM_SK
		packed=(a.skdisasm/'General/Sprites/Egg Robo/Egg Robo Head.kosm').read_bytes()
		raw=classic_kosinski(packed[2:])
		expected=bytes((PLAYER_FROM_SK[b>>4]<<4)|PLAYER_FROM_SK[b&15] for b in raw)
		for i,row in enumerate(frames(rom,s['Map_GHZBoss_Cockpit'],s['BossFace_FrameCount'])[7:]):
			head=[piece for piece in row if (piece[2]&2047)>=60]
			assert head==[(-28,0x0D,60,-6)],('EggRobo collar anchor',i,head)
			original=raster([(-28,0x0D,0,-6)],[(0,expected[i*256:(i+1)*256])])
			actual=raster(head,face_banks(rom,s,i+7),s['ArtTile_Eggman'])
			assert {p:c for p,c in actual.items() if p[1]<-16}=={p:c for p,c in original.items() if p[1]<-16}
			assert actual[-3,-13]==(0,4),('Yellow head triangle does not meet the shared collar',i)
			neck = {p:c for p,c in actual.items() if p[1]>=-16}
			assert all(-6<=x<12 and -16<=y<=-13 for x,y in neck),'Chest strip covers glass or the backrest'
			if i:assert neck==previous_neck,'Collar seam moves with the head animation'
			previous_neck=neck
		result.append('four EggRobo source helmets/faces and palette roles are exact; only the lower chest strip is adapted to a stable aligned collar')
	rows = frames(rom,s['Map_GHZBoss_Cockpit'],s['BossFace_FrameCount'])
	glass = rows[0][0]
	assert glass==(-20,5,35,-20)
	assert all(row[0]==glass for row in rows),'Glass must precede every pilot head'
	glass_pixels = raster([glass],face_banks(rom,s,0),s['ArtTile_Eggman'])
	assert len(glass_pixels)<256 and {6,7,8,9,10}<={color for _,color in glass_pixels.values()}
	assert any((x,y) not in glass_pixels for x in range(-17,-10) for y in range(-17,-12)),'The window has no transparent opening'
	if a.reference_rom:
		before,old = symbols(a.reference_listing),a.reference_rom.read_bytes()
		if 'Map_GHZBoss_Cockpit' in before:
			first = frames(old,before['Map_GHZBoss_Cockpit'],7)[0]
			static = [p for p in first if (p[2]&2047)<before['ArtTile_EggmanFace']-before['ArtTile_Eggman']]
			previous = raster(static,face_banks(old,before,0),before['ArtTile_Eggman'])
		else:
			from build_boss_shared_art import head_mask
			previous = raster(frames(old,before['Map_Eggman'],13)[1],[(before['ArtTile_Eggman'],unpack(old,before['Kospm_OldEggPod']))],before['ArtTile_Eggman'])
			previous = {p:c for p,c in previous.items() if not head_mask(0,*p,c[1])}
		expected = {p:c for p,c in previous.items() if -20<=p[0]<-4 and -20<=p[1]<-4}
		assert glass_pixels==expected,'Windshield frame/reflection pixels changed'
	result.append('one shared transparent glass piece precedes every pilot; four resident tiles and the original reflection/frame pixels are retained')

	from check_ehz_s1_pod import check_art
	check_art(rom,s)
	for kind,character in ((k,c) for k in ('Obj3D','EHZBoss') for c in (0,1)):
		m.start()
		body = pool[0]
		m.put(body,'code',s[kind])
		m.put(body,'obSubtype',character,2)
		m.put(body,'obX',s['EHZBoss_LandingX'] if kind=='EHZBoss' else 1000,2)
		m.put(body,'obY',s['EHZBoss_LandingY']+8 if kind=='EHZBoss' else 1000,2)
		m.act(kind,body)
		face = next(p for p in pool[1:] if m.get(p,'code')==s[kind] and m.get(p,'obRoutine')==(4 if kind=='Obj3D' else 14))
		assert m.get(face,'obMap',4)==s['Map_GHZBoss_Cockpit' if kind=='Obj3D' else 'Map_EHZBoss_Cockpit']
		assert m.get(face,'obGfx',2)==s['ArtTile_Eggman']+(0x8000 if kind=='EHZBoss' else 0)
		assert m.get(face,'obSubtype',2)==character
		art = s['Art_EggmanFace' if character==0 else 'Art_EggRoboHead']
		expected_source = unpack(rom,s['Kospm_EggmanFace' if character==0 else 'Kospm_EggRoboHead'])
		assert m.get(face,'BossFace_Source',4)&0xFFFFFF==art&0xFFFFFF
		assert bytes(m.cpu.mem_read(art&0xFFFFFF,len(expected_source)))==expected_source
		assert m.read('BossFace_ArtReady')&(1<<character)

		m.put(body,'obX',1000,2)
		m.put(body,'obY',1000,2)
		# Only source expression selectors vary; the real animation runs each tick.
		for flip in (0,1):
			for name,phase,flash,hurt,expected in (
				('normal',6 if kind=='Obj3D' else 4,0,False,{0,1}),
				('laugh',6 if kind=='Obj3D' else 4,0,True,{2,3}),
				('hurt',6 if kind=='Obj3D' else 4,32,False,{0,4}),
				('exploding',8 if kind=='Obj3D' else 6,0,False,{0,4} if kind=='Obj3D' else {6}),
				('recover',10 if kind=='Obj3D' else 8,0,False,{6}),
				('escape',12 if kind=='Obj3D' else 10,0,False,{0,5})):
				if character:expected = {9} if name=='hurt' else ({10} if name in ('exploding','recover','escape') else {7,8})
				m.put(body,'obStatus',flip)
				m.put(body,'ob2ndRout',phase)
				if kind=='EHZBoss' and name=='escape':
					m.put(body,'objoff_30',4)	# powered escape
				m.put(body,'BGHZ_FlashTimer' if kind=='Obj3D' else 'objoff_42',flash)
				m.put('v_player','obRoutine',4 if hurt else 2)
				m.put(face,'obPrevAni',255)
				palette = bytes(range(128))
				m.cpu.mem_write(s['v_palette'] & 0xFFFFFF,palette)
				seen = set()
				for _ in range(70):
					m.act(kind,face)
					seen.add(m.get(face,'obFrame'))
					assert m.get(face,'obX',2)==1000
					assert m.get(face,'obY',2)==1000
					assert m.get(face,'obRender') & 1==flip
				assert seen==expected,(kind,name,flip,seen,expected)
				assert bytes(m.cpu.mem_read(s['v_palette'] & 0xFFFFFF,128))==palette
		# One persistent rear flame serves approach and escape; no rotor slot.
		if kind=='EHZBoss':
			rotor = next(p for p in pool[1:] if m.get(p,'code')==s[kind] and m.get(p,'obRoutine')==16)
			count = sum(bool(m.get(p,'code')) for p in pool)
			assert count==8
			m.put(body,'ob2ndRout',10)
			m.put(body,'objoff_30',4)
			m.act(kind,rotor)
			assert m.get(rotor,'obMap',4)==s['Map_BossExhaust']
			assert sum(bool(m.get(p,'code')) for p in pool)==count
		else:
			rotor = next(p for p in pool[1:] if m.get(p,'code')==s[kind] and m.get(p,'obRoutine')==6)
			m.put(body,'ob2ndRout',s['BGHZ_Escape'])
		for flip in (0,1):
			m.put(body,'obStatus',flip)
			m.put(rotor,'obPrevAni',255)
			seen = set()
			for _ in range(80):
				m.act(kind,rotor)
				seen.add(m.get(rotor,'obFrame'))
				dx = 34
				assert m.get(rotor,'obX',2)==1000+(-dx if flip else dx)
			assert seen=={0,1,2,3}
		# A recycled same-code child must not become a new parent.
		m.put(body,'obRoutine',14 if kind=='EHZBoss' else 4)
		before = bytes(m.cpu.mem_read(body & 0xFFFFFF,s['object_size']))
		m.act(kind,face)
		m.act(kind,rotor)
		assert not m.get(face,'code') and not m.get(rotor,'code')
		assert bytes(m.cpu.mem_read(body & 0xFFFFFF,s['object_size']))==before
		result.append(f'{kind} pilot {character}: five expressions, both facings, decoded source, independent anchors, unchanged palette and recycled-parent cleanup')
	for bodymap,cockpitmap in (('Map_Eggman','Map_GHZBoss_Cockpit'),('Map_EHZBoss_Vehicle','Map_EHZBoss_Cockpit')):
		base = frames(rom,s[bodymap],1)[0]
		for row in frames(rom,s[cockpitmap],s['BossFace_FrameCount']):
			peak = max(sum(y<=scan<y+((size&3)+1)*8 for y,size,_,_ in row+base) for scan in range(-48,40))
			assert peak<=12, ('Boss exceeds the reserved scanline budget',bodymap,peak)
	for character in (0,1):
		m.start();body,face=pool[:2]
		m.put(body,'obSubtype',character,2)
		m.act('BossFace_Init',body,{UC_M68K_REG_A1:face})
		first = 7 if character else 0
		m.put(face,'obFrame',first)
		m.act('BossFace_Draw',face)
		assert m.get(face,'BossFace_LoadedFrame')==first
		m.uploads.clear();m.drawn.clear()
		m.put(face,'obFrame',first+1)
		m.write('VDP_Command_Buffer_Slot',(s['VDP_Command_Buffer_Slot']-1)&65535,2)
		m.act('BossFace_Draw',face)
		assert not m.uploads and m.drawn==[first]
		assert m.get(face,'obFrame')==first and m.get(face,'BossFace_LoadedFrame')==first
		assert m.get(face,'BossFace_DesiredFrame')==first+1
		m.put(face,'BossFace_LoadedFrame',255);m.drawn.clear()
		m.put(face,'obTimeFrame',127)
		m.act('BossFace_Display',face,{UC_M68K_REG_A1:body})
		assert not m.drawn and not m.uploads
		m.write('VDP_Command_Buffer_Slot',s['VDP_Command_Buffer']&65535,2)
		m.act('BossFace_Display',face,{UC_M68K_REG_A1:body})
		assert m.get(face,'BossFace_LoadedFrame')==first+1 and m.uploads
		m.uploads.clear();m.act('BossFace_Draw',face)
		assert not m.uploads, 'An unchanged expression re-uploaded its art'
		# DisplaySprite queues the SST, not a snapshot. Consume the real queue
		# after the fallback returns and compare the resulting hardware pieces.
		m.cpu.mem_write(s['DisplaySprite'],rom[s['DisplaySprite']:s['DisplaySprite']+32])
		m.cpu.ctl_remove_cache(s['DisplaySprite'],s['DisplaySprite']+32)
		m.put(face,'code',s['BossFace_Draw'])
		m.put(face,'obX',160,2);m.put(face,'obY',120,2)
		m.put(face,'obMap',s['Map_GHZBoss_Cockpit'],4)
		m.put(face,'obGfx',s['ArtTile_Eggman'],2)
		m.put(face,'obRender',4);m.put(face,'obPriority',0x180,2)
		m.put(face,'width_pixels',s['Map_GHZBoss_Cockpit_width'])
		m.put(face,'height_pixels',s['Map_GHZBoss_Cockpit_height'])
		m.put(face,'BossFace_LoadedFrame',first)
		m.put(face,'obFrame',first+1)
		m.write('VDP_Command_Buffer_Slot',(s['VDP_Command_Buffer_Slot']-1)&65535,2)
		m.act('BossFace_Draw',face)
		assert bytes(m.cpu.mem_read((s['v_spritequeue']+0x180)&0xFFFFFF,2))==b'\0\2', 'Deferred face was not queued'
		m.act('Init_SpriteTable');m.act('Render_Sprites')
		row=frames(rom,s['Map_GHZBoss_Cockpit'],s['BossFace_FrameCount'])[first]
		for i,(y,size,tile,x) in enumerate(row):
			actual=bytes(m.cpu.mem_read((s['Sprite_Table']+i*8)&0xFFFFFF,8))
			assert struct.unpack('>HBBHH',actual)[::2]==(248+y, i+1,288+x), (character,i,actual.hex(),(y,size,tile,x))
			assert actual[2]==size and int.from_bytes(actual[4:6],'big')==s['ArtTile_Eggman']+tile
		m.cpu.mem_write(s['DisplaySprite'],bytes.fromhex('4E75'))
		m.cpu.ctl_remove_cache(s['DisplaySprite'],s['DisplaySprite']+32)
	result.append('both pilots: queue exhaustion retains the complete previous pose, retries initial uploads, preserves desired animation and skips cached frames')
	# The shared escape sequence retains S1's one startup flare and small loop.
	m.start()
	obj = pool[0]
	m.put(obj,'obAnim',s['BossExhaust_Escape'])
	m.put(obj,'obPrevAni',255)
	seen = []
	for _ in range(120):
		m.act('AnimateSprite',obj,{UC_M68K_REG_A1:s['Ani_BossExhaust']})
		seen.append(m.get(obj,'obFrame'))
	assert all(f in (0,1) for f in seen[24:]) and set(seen[:24])=={0,1,2,3}
	result.append('S1 flame startup plays once; EHZ retains one exhaust child for approach and escape')
	return result


def live_gallery(g, a, act):
	"""Check actual VDP pixels for every expression/facing, including glass order."""
	from check_companion_followup import isolate,place,spawn
	saved = g.save()
	s = g.s
	camx,camy = g.read('Camera_X_pos',2),g.read('Camera_Y_pos',2)
	isolate(g)
	g.put('v_player2','code',0)
	place(g,'v_player',camx+160,camy+210,False)
	g.put('v_player','obControl',0x81)
	for name,value in (('Camera_Min_X_pos',camx),('Camera_Max_X_pos',camx),('Camera_Max_X_pos_target',camx),
		('Camera_Min_Y_pos',camy),('Camera_Max_Y_pos',camy),('Camera_Max_Y_pos_target',camy)):
		g.write(name,value,2)
	# Decode the missing character through the real constructor. Restore the
	# original fight after the gallery, including its immutable source buffers.
	if g.read('BossFace_ArtReady')!=3:
		missing = 1 if not g.read('BossFace_ArtReady')&2 else 0
		spawn(g,'EHZBoss',camx+160,camy+150,missing)
		g.run(4);assert not g.read('v_errortype')
		assert g.read('BossFace_ArtReady')==3
		isolate(g)
	x,y = camx+160,camy+150
	hull=spawn(g,'DisplaySprite',x,y)
	face=spawn(g,'BossFace_Draw',x,y)
	g.put(face,'BossFace_Source',s['Art_EggmanFace'],4)
	g.put(face,'BossFace_LoadedFrame',255)
	for obj,mapping,line in ((hull,'Map_EHZBoss_Vehicle',0),(face,'Map_EHZBoss_Cockpit',0)):
		for field,value,size in (('obMap',s[mapping],4),('obGfx',s['ArtTile_Eggman']+(line<<13)|0x8000,2),
			('obRender',4,1),('obPriority',0x200,2),('width_pixels',s[mapping+'_width'],1),
			('height_pixels',s[mapping+'_height'],1)):
			g.put(obj,field,value,size)
	rom = a.rom.read_bytes()
	rows = frames(rom,s['Map_EHZBoss_Cockpit'],s['BossFace_FrameCount'])
	# Let the copied camera and the displayed SAT settle before pixel sampling.
	g.run(30)
	for flip in (0,1):
		for pose,row in enumerate(rows):
			for obj in (hull,face):
				g.put(obj,'obRender',4|flip)
				g.put(obj,'obStatus',flip)
			g.put(face,'BossFace_Source',s['Art_EggmanFace' if pose<7 else 'Art_EggRoboHead'],4)
			g.put(face,'obFrame',pose)
			g.run(4)
			assert not g.read('v_errortype')
			pixels = raster(row,face_banks(rom,s,pose),s['ArtTile_Eggman'])
			def screen(p):
				px,py = p
				return x-g.read('Camera_X_pos_copy',2)+(-px-1 if flip else px),y-g.read('Camera_Y_pos_copy',2)+py
			# Inspect the lens itself, without borrowing the producer's color mask.
			blues = [p for p,(_,n) in pixels.items() if -6<=p[0]<=3 and -28<=p[1]<=-16 and n in (10,11,12)]
			if pose<7:assert blues, ('No blue lens pixels',act,pose,flip)
			for point in blues:
				r,gc,b = g.video.getpixel(screen(point))
				assert b>r+50 and b>gc+40, ('Lens lost its blue in the VDP output',act,pose,flip,point,(r,gc,b))
			composite = frames(rom,s['Map_EHZBoss_Vehicle'],1)[0]+row
			for point,(line,index) in raster(composite,face_banks(rom,s,pose),s['ArtTile_Eggman']).items():
				word = g.read(s['v_palette']+(line*16+index)*2,2)
				assert g.video.getpixel(screen(point))==display_color(g,word),('EHZ pilot/glass pixel',act,pose,flip,point)

			g.video.save(a.output/f'ehz{act+1}-pose{pose}-flip{flip}.png')
	g.restore(saved)
	return 22


def glass_priority_check(g,face):
	"""An opaque test rider behind the real glass must show through its holes."""
	from check_companion_followup import spawn
	from check_object_course import objects
	saved = g.save()
	s,rom = g.s,bytes(g.rom.raw[:-1])
	try:
		glass = frames(rom,g.get(face,'obMap',4),s['BossFace_FrameCount'])[0][0]
		gy,size,tile,gx = glass
		assert size==5
		front = raster([glass],face_banks(rom,s,0),s['ArtTile_Eggman'])
		for obj in objects(g):
			if obj!=face:g.put(obj,'code',0,4)
		fixture = s['Free_RAM_Start']&0xFFFFFF
		probe = fixture+0x100
		rider = (gy,size,s['ArtTile_EggmanFace']-s['ArtTile_Eggman'],gx)
		g.put(face,'code',s['DisplaySprite'],4);g.put(face,'obMap',probe,4);g.put(face,'obFrame',0)
		queue_fixture(g,fixture,bytes([0xDD])*(4*32),s['ArtTile_EggmanFace']*32)
		uploader=spawn(g,'DisplaySprite',0,0);g.put(uploader,'code',fixture,4)
		red = display_color(g,g.read(s['v_palette']+13*2,2))
		checked = 0
		for flip in (0,1):
			g.put(face,'obStatus',flip);g.put(face,'obRender',4|flip)
			for reverse in (False,True):
				pieces = (rider,glass) if reverse else (glass,rider)
				mapping = struct.pack('>HH',2,2)+b''.join(struct.pack('>bBHh',*p) for p in pieces)
				for i,value in enumerate(mapping):g.write(probe+i,value)
				g.run(3);assert not g.read('v_errortype')
				for y in range(gy,gy+16):
					for x in range(gx,gx+16):
						point = (g.get(face,'obX',2)-g.read('Camera_X_pos_copy',2)+(-x-1 if flip else x),g.get(face,'obY',2)-g.read('Camera_Y_pos_copy',2)+y)
						expected = red
						if not reverse and (x,y) in front:
							line,index = front[x,y]
							expected = display_color(g,g.read(s['v_palette']+(line*16+index)*2,2))
						actual=g.video.getpixel(point)
						if actual!=expected:g.video.save(g.output/'glass-control-failure.png')
						assert actual==expected,('Glass/rider control',flip,reverse,(x,y),actual,expected)
						checked+=1
		return f'front glass: both facings, transparent holes reveal the opaque test rider, reversed-order control; {checked} VDP pixels'
	finally:
		g.restore(saved)


def live_checks(a):
	from check_ehz_s1_pod import live
	# The S1-pod runner performs real rolling hits and the full hop/escape/capsule.
	a.player = 0
	return [str(live(a,act)) for act in (0,1)]



def waterfall_burst_checks(g,body):
	"""Real GHZ bursts go behind the foreground plane but in front of Eggman."""
	from check_object_course import objects
	s,rom = g.s,bytes(g.rom.raw[:-1])
	before = g.save()
	try:
		g.put(body,'ob2ndRout',s['BGHZ_Explode']);g.put(body,'BGHZ_Timer',0x400,2)
		g.put(body,'BossBurst_Started',0);g.put(body,'obColType',0)
		for _ in range(120):
			g.run();assert not g.read('v_errortype')
			bursts = [o for o in objects(g) if g.get(o,'code')==s['BossExplosion'] and g.get(o,'obRoutine')]
			if bursts:break
		else:raise AssertionError('GHZ did not emit a burst')
		burst = bursts[0]
		assert not g.get(burst,'obGfx',2)&0x8000,'GHZ burst overrides the foreground-plane waterfall'
		assert g.get(burst,'obPriority',2)<g.get(body,'obPriority',2),'GHZ burst is behind Eggman'
		face = next(o for o in objects(g) if g.get(o,'obMap',4)==s['Map_GHZBoss_Cockpit'])
		for o in objects(g):
			if o not in (body,face,burst):g.put(o,'code',0,4)
		for player in ('v_player','v_player2'):g.put(player,'code',0,4)
		camx,camy = g.read('Camera_X_pos',2),g.read('Camera_Y_pos',2)
		for name,value in (('Camera_Min_X_pos',camx),('Camera_Max_X_pos',camx),('Camera_Max_X_pos_target',camx),
			('Camera_Min_Y_pos',camy),('Camera_Max_Y_pos',camy),('Camera_Max_Y_pos_target',camy)):g.write(name,value,2)
		g.write('f_timecount',0);g.write('v_pcyc_time',0x7FFF,2)
		g.put(body,'code',s['DisplaySprite'],4);g.put(face,'code',s['BossFace_Draw'],4)
		for obj in (body,face):
			g.put(obj,'obX',camx+160,2);g.put(obj,'obY',camy+120,2)
			g.put(obj,'obRender',4);g.put(obj,'obStatus',0)
		g.put(face,'obFrame',0);g.put(face,'BossFace_LoadedFrame',255)
		g.put(burst,'obX',camx+160,2);g.put(burst,'obY',camy+96,2)
		g.put(burst,'obTimeFrame',127)
		g.run(3)
		assert not g.read('v_errortype')
		def rgb(line,color):
			word = g.read(s['v_palette']+(line*16+color)*2,2)
			if 'ClownMDEmu' in g.emulator:word |= (word&0x888)>>3
			r,green,b = (word>>shift&15 for shift in (0,4,8))
			return (((r<<1)|(r>>3))*255//31,((green<<2)|(green>>2))*255//63,((b<<1)|(b>>3))*255//31)
		def sprite_pixels(obj):
			bank = bytes(g.vram[i^1] for i in range(65536))
			mapping,frame,gfx = g.get(obj,'obMap',4),g.get(obj,'obFrame'),g.get(obj,'obGfx',2)
			name = 'Map_GHZBoss_Cockpit' if obj==face else 'Map_BossExplosion'
			count = s[name+'_frames']
			row = frames(rom,mapping,count)[frame]
			flip = g.get(obj,'obRender')&3
			result = {}
			for (x,y),(line,color) in raster(row,[(0,bank)],gfx&2047).items():
				point = (g.get(obj,'obX',2)-g.read('Camera_X_pos_copy',2)+(-x-1 if flip&1 else x),
					g.get(obj,'obY',2)-g.read('Camera_Y_pos_copy',2)+(-y-1 if flip&2 else y))
				if not(0<=point[0]<320 and 0<=point[1]<224):continue
				result[point] = rgb(((gfx>>13)+line)&3,color)
			return result
		def foreground_pixel(point):
			"""Decode the real foreground name table, scrolling and opaque tile pixel."""
			x,y = point
			bank = g.vram
			def word(address):return (bank[address^1]<<8)|bank[(address+1)^1]
			x = (x-word(s['vram_hscroll']+y*4))&511
			y = (y+g.read('v_scrposy_vdp',2))&255
			entry = word(s['vram_fg']+((y//8)*64+x//8)*2)
			if not entry&0x8000:return None
			x,y = x&7,y&7
			if entry&0x800:x=7-x
			if entry&0x1000:y=7-y
			packed = bank[((entry&2047)*32+y*4+x//2)^1]
			color = (packed>>(0 if x&1 else 4))&15
			return rgb((entry>>13)&3,color) if color else None
		staged = g.save()
		checked,controls,over_head = 0,0,0
		for phase in range(s['Map_BossExplosion_frames']):
			g.restore(staged);g.put(burst,'obFrame',phase);g.put(burst,'obTimeFrame',127)
			seed = g.save()
			g.put(burst,'code',0,4);g.run(3);baseline=g.video.copy()
			assert not g.read('v_errortype')
			g.restore(seed)
			g.run(3)
			assert not g.read('v_errortype')
			fire,head = sprite_pixels(burst),sprite_pixels(face)
			witnesses = {p:foreground_pixel(p) for p in fire}
			witnesses = {p:c for p,c in witnesses.items() if c is not None and c!=fire[p]}
			assert witnesses,('No opaque foreground overlap',phase)
			assert all(baseline.getpixel(p)==c for p,c in witnesses.items()),('Foreground pixel decoder disagrees with VDP',phase)
			assert all(g.video.getpixel(p)==c for p,c in witnesses.items()),('Explosion covers foreground waterfall',phase)
			checked+=len(witnesses)
			visible = [p for p in fire.keys()&head.keys() if baseline.getpixel(p)==head[p] and fire[p]!=head[p]]
			if not visible:
				baseline.save(g.output/f'burst{phase}-baseline.png')
				g.video.save(g.output/f'burst{phase}-overlap.png')
			assert visible,('No visible head/burst overlap',phase)
			assert all(g.video.getpixel(p)==fire[p] for p in visible),('Explosion is behind Eggman',phase)
			over_head+=len(visible)
			if phase==3:g.video.save(g.output/'waterfall-over-burst.png')
			g.restore(seed);g.put(burst,'obGfx',g.get(burst,'obGfx',2)|0x8000,2);g.run(3)
			assert not g.read('v_errortype')
			assert all(g.video.getpixel(p)==fire[p] for p in witnesses),('High-priority control did not reveal the burst',phase)
			controls+=len(witnesses)
			if phase==3:g.video.save(g.output/'burst-front-control.png')
		return f'foreground waterfall: all seven burst frames, {checked} covered pixels, {controls} high-priority control pixels; {over_head} pixels over Eggman'
	finally:
		g.restore(before)


def ghz_face_checks(a):
	"""Normal arena/music handoff, then every streamed pose without the waterfall."""
	from genesis_test_core import Genesis
	from check_object_course import boot_level,objects
	from check_companion_followup import isolate,place,spawn
	g=Genesis(a.core,a.rom,a.listing,a.output,a.pal,system_directory=a.system_directory)
	s,rom=g.s,a.rom.read_bytes()
	def vram(address,length):return bytes(g.vram[(address+i)^1] for i in range(length))
	def source_bytes(name,length):return bytes(g.ram[((s[name]+i)&65535)^1] for i in range(length))
	boot_level(g,zone=0,act=2)
	g.put('v_player2','code',0)
	for field,value,size in (('obX',s['BGHZ_CenterX'],2),('obY',s['boss_ghz_y']+0xB0,2),
			('obVelX',0,2),('obVelY',0,2),('obInertia',0,2),('obControl',1,1),
			('obRoutine',2,1),('flashtime',6000,2)):g.put('v_player',field,value,size)
	g.write('v_rings',99,2)
	for tick in range(1500):
		g.run();assert not g.read('v_errortype'),('GHZ exception',tick)
		ships=[o for o in objects(g,0x3D) if g.get(o,'obRoutine')==2]
		if ships and g.get(ships[0],'ob2ndRout')==s['BGHZ_Patrol']:break
	else:raise AssertionError('GHZ boss did not deploy')
	eggman=unpack(rom,s['Kospm_EggmanFace'])
	assert source_bytes('Art_EggmanFace',len(eggman))==eggman
	g.video.save(a.output/'ghz-deployed.png')
	plc=s['PLC_GHZBoss'];count=struct.unpack_from('>H',rom,plc)[0]+1
	for i in range(count):
		source,dest=struct.unpack_from('>IH',rom,plc+2+i*6);raw=unpack(rom,source)
		assert vram(dest,len(raw))==raw,('GHZ boss PLC bank mismatch',hex(dest))
	waterfall_report = waterfall_burst_checks(g,ships[0])
	# Construct the other pilot through the actual boss path. Separate immutable
	# buffers keep any previously queued Eggman DMA source intact.
	camx,camy=g.read('Camera_X_pos',2),g.read('Camera_Y_pos',2)
	isolate(g);place(g,'v_player',camx+40,camy+200,False);g.put('v_player','obControl',0x81)
	robo=spawn(g,'Obj3D',camx+160,camy+120);g.put(robo,'obSubtype',1,2)
	g.run(4);assert not g.read('v_errortype')
	assert g.read('BossFace_ArtReady')==3
	eggrobo=unpack(rom,s['Kospm_EggRoboHead'])
	assert source_bytes('Art_EggRoboHead',len(eggrobo))==eggrobo
	assert source_bytes('Art_EggmanFace',len(eggman))==eggman
	isolate(g);place(g,'v_player',camx+40,camy+200,False);g.put('v_player','obControl',0x81)
	for name,value in (('Camera_Min_X_pos',camx),('Camera_Max_X_pos',camx),('Camera_Max_X_pos_target',camx),
			('Camera_Min_Y_pos',camy),('Camera_Max_Y_pos',camy),('Camera_Max_Y_pos_target',camy)):g.write(name,value,2)
	x,y=camx+160,camy+120
	hull=spawn(g,'DisplaySprite',x,y);face=spawn(g,'BossFace_Draw',x,y)
	for obj,mapping in ((hull,'Map_Eggman'),(face,'Map_GHZBoss_Cockpit')):
		for field,value,size in (('obMap',s[mapping],4),('obGfx',s['ArtTile_Eggman']|0x8000,2),
				('obRender',4,1),('obPriority',0x180,2),('width_pixels',s[mapping+'_width'],1),
				('height_pixels',s[mapping+'_height'],1)):g.put(obj,field,value,size)
	g.put(face,'BossFace_LoadedFrame',255);g.put(face,'BossFace_Source',s['Art_EggmanFace'],4)
	g.run(30)
	for base in (s['vram_fg'],s['vram_bg']):
		for i in range(0x1000):g.vram[(base+i)^1]=0
	checked=0
	for flip in (0,1):
		for pose,row in enumerate(frames(rom,s['Map_GHZBoss_Cockpit'],s['BossFace_FrameCount'])):
			for obj in (hull,face):g.put(obj,'obRender',4|flip);g.put(obj,'obStatus',flip)
			g.put(face,'BossFace_Source',s['Art_EggmanFace' if pose<7 else 'Art_EggRoboHead'],4)
			g.put(face,'obFrame',pose);g.run(4)
			assert not g.read('v_errortype')
			cache=head_frame(rom,s,pose)
			assert vram(s['ArtTile_EggmanFace']*32,len(cache))==cache,('Head DMA mismatch',pose,flip)
			assert source_bytes('Art_EggmanFace',len(eggman))==eggman
			assert source_bytes('Art_EggRoboHead',len(eggrobo))==eggrobo
			# The earlier hull pieces occlude the same lower cockpit pixels as
			# the real sprite queue. Check every visible pod/head pixel.
			composite=frames(rom,s['Map_Eggman'],1)[0]+row
			for (px,py),(line,index) in raster(composite,face_banks(rom,s,pose),s['ArtTile_Eggman']).items():
				color=g.read(s['v_palette']+(line*16+index)*2,2)
				rgb=display_color(g,color)
				point=(x-g.read('Camera_X_pos_copy',2)+(-px-1 if flip else px),y-g.read('Camera_Y_pos_copy',2)+py)
				assert g.video.getpixel(point)==rgb,('Pilot pixel',pose,flip,point)
				checked+=1
			g.video.save(a.output/f'ghz-pose{pose}-flip{flip}.png')
	glass_report = glass_priority_check(g,face)
	g.close()
	return [waterfall_report,f'GHZ arena/music handoff: stable per-character sources, {count} resident banks; 22 streamed poses/facings, {checked} rendered pod/head pixels',glass_report]


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
	p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--reference-rom',type=Path)
	p.add_argument('--reference-listing',type=Path)
	p.add_argument('--output',type=Path,required=True)
	p.add_argument('--core',type=Path)
	p.add_argument('--system-directory',type=Path)
	p.add_argument('--pal',action='store_true')
	p.add_argument('--skdisasm',type=Path,help='Compare all four EggRobo source poses and palette conversion')
	p.add_argument('--ghz-faces-only',action='store_true',help='Only check GHZ arena/music loading and all pilot expressions')
	a = p.parse_args()
	assert bool(a.reference_rom)==bool(a.reference_listing)
	a.output.mkdir(parents=True,exist_ok=True)
	if a.ghz_faces_only:
		if not a.core or not a.system_directory:p.error('--ghz-faces-only requires --core and --system-directory')
		result = ghz_face_checks(a)
	else:
		result = native_checks(a)
		if a.core:
			result += live_checks(a)
	(a.output/'report.json').write_text(json.dumps(result,indent=2)+'\n')
	for row in result:
		print(row+': passed')


if __name__=='__main__':
	main()
