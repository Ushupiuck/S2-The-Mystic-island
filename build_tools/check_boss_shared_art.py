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


def reference_checks(a, rom, s):
	if not a.reference_rom:
		return []
	old, before = a.reference_rom.read_bytes(), symbols(a.reference_listing)
	oldbanks = [(before[tile],unpack(old,before[label])) for tile,label in (
		('ArtTile_Eggman','Kospm_OldEggPod'),('ArtTile_Eggman_Exhaust','Kospm_Exhaust'))]
	oldrows = frames(old,before['Map_Eggman'],13)
	from build_boss_shared_art import seat_color,head_color
	newbanks = [(s[tile],unpack(rom,s[label])) for tile,label in (
		('ArtTile_Eggman','Kospm_OldEggPod'),('ArtTile_EggmanFace','Kospm_EggmanFace'))]
	for row,index in zip(frames(rom,s['Map_GHZBoss_Cockpit'],7),range(1,8)):
		original = raster(oldrows[index],oldbanks,before['ArtTile_Eggman'])
		expected = {(x,y):(line,head_color(index-1,x,y,seat_color(x,y,color))) for (x,y),(line,color) in original.items()}
		assert raster(row,newbanks,s['ArtTile_Eggman'])==expected, ('S1 changed beyond seat colors',index)
	newfire = frames(rom,s['Map_BossExhaust'],5)
	firebank = [(s['ArtTile_Eggman_Exhaust'],unpack(rom,s['Kospm_Exhaust']))]
	for row,index in zip(newfire,(8,9,11,12,10)):
		actual = {(x+34,y):c for (x,y),c in raster(row,firebank,s['ArtTile_Eggman_Exhaust']).items()}
		assert actual==raster(oldrows[index],oldbanks,before['ArtTile_Eggman']), ('S1 flame changed',index)
	oldhull = raster(oldrows[0],oldbanks,before['ArtTile_Eggman'])
	expectedhull = {(x,y):(line,seat_color(x,y,color) if line==0 else color) for (x,y),(line,color) in oldhull.items()}
	assert raster(frames(rom,s['Map_Eggman'],1)[0],newbanks,s['ArtTile_Eggman'])==expectedhull
	return ['S1 complete pod, seven poses and original exhaust remain pixel-exact apart from the selected seat/lens colors']


def native_checks(a):
	from native_test_core import Native, UC_M68K_REG_A1
	m = Native(a.rom,a.listing)
	s = m.s
	m.cpu.mem_write(s['DisplaySprite'],bytes.fromhex('4E75'))
	pool = list(range(s['v_lvlobjspace'],s['v_lvlobjend'],s['object_size']))
	rom = a.rom.read_bytes()
	import configparser
	ini = configparser.ConfigParser()
	ini.read(ROOT/'SonLVL INI Files/objGHZ.ini')
	assert int(ini['3D']['headtileoffset'])==s['ArtTile_EggmanFace']-s['ArtTile_Eggman']
	result = reference_checks(a,rom,s)
	from check_ehz_s1_pod import check_art
	check_art(rom,s)
	for kind in ('Obj3D','EHZBoss'):
		m.start()
		body = pool[0]
		m.put(body,'code',s[kind])
		m.put(body,'obX',s['EHZBoss_LandingX'] if kind=='EHZBoss' else 1000,2)
		m.put(body,'obY',s['EHZBoss_LandingY']+8 if kind=='EHZBoss' else 1000,2)
		m.act(kind,body)
		face = next(p for p in pool[1:] if m.get(p,'code')==s[kind] and m.get(p,'obRoutine')==(4 if kind=='Obj3D' else 14))
		assert m.get(face,'obMap',4)==s['Map_GHZBoss_Cockpit' if kind=='Obj3D' else 'Map_EHZBoss_Cockpit']
		assert m.get(face,'obGfx',2)==s['ArtTile_Eggman' if kind=='Obj3D' else 'ArtTile_ArtNem_Eggpod_1']
		m.put(body,'obX',1000,2)
		m.put(body,'obY',1000,2)
		# Only source expression selectors vary; the real animation runs each tick.
		for flip in (0,1):
			for name,phase,flash,hurt,expected in (
				('normal',6 if kind=='Obj3D' else 4,0,False,{0,1}),
				('laugh',6 if kind=='Obj3D' else 4,0,True,{2,3}),
				('hurt',6 if kind=='Obj3D' else 4,32,False,{0,4}),
				('defeated',8 if kind=='Obj3D' else 6,0,False,{0,5}),
				('recover',10 if kind=='Obj3D' else 8,0,False,{6})):
				m.put(body,'obStatus',flip)
				m.put(body,'ob2ndRout',phase)
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
		result.append(f'{kind}: five expressions, both facings, independent anchors, unchanged palette and recycled-parent cleanup')
	for bodymap,cockpitmap in (('Map_Eggman','Map_GHZBoss_Cockpit'),('Map_EHZBoss_Vehicle','Map_EHZBoss_Cockpit')):
		base = frames(rom,s[bodymap],1)[0]
		for row in frames(rom,s[cockpitmap],7):
			peak = max(sum(y<=scan<y+((size&3)+1)*8 for y,size,_,_ in row+base) for scan in range(-48,40))
			assert peak<=12, ('Boss exceeds the reserved scanline budget',bodymap,peak)
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
	x,y = camx+160,camy+150
	hull,face = [spawn(g,'DisplaySprite',x,y) for _ in range(2)]
	for obj,mapping,line in ((hull,'Map_EHZBoss_Vehicle',0),(face,'Map_EHZBoss_Cockpit',0)):
		for field,value,size in (('obMap',s[mapping],4),('obGfx',s['ArtTile_ArtNem_Eggpod_1']+(line<<13),2),
			('obRender',4,1),('obPriority',0x200,2),('width_pixels',s[mapping+'_width'],1),
			('height_pixels',s[mapping+'_height'],1)):
			g.put(obj,field,value,size)
	rom = a.rom.read_bytes()
	banks = [(s[tile],unpack(rom,s[label])) for tile,label in (
		('ArtTile_Eggman','Kospm_OldEggPod'),('ArtTile_EggmanFace','Kospm_EggmanFace'))]
	rows = frames(rom,s['Map_EHZBoss_Cockpit'],7)
	# Let the copied camera and the displayed SAT settle before pixel sampling.
	g.run(30)
	for flip in (0,1):
		for pose,row in enumerate(rows):
			for obj in (hull,face):
				g.put(obj,'obRender',4|flip)
				g.put(obj,'obStatus',flip)
			g.put(face,'obFrame',pose)
			g.run(4)
			assert not g.read('v_errortype')
			pixels = raster(row,banks,s['ArtTile_ArtNem_Eggpod_1'])
			def screen(p):
				px,py = p
				return x-g.read('Camera_X_pos_copy',2)+(-px-1 if flip else px),y-g.read('Camera_Y_pos_copy',2)+py
			# Inspect the lens itself, without borrowing the producer's color mask.
			blues = [p for p,(_,n) in pixels.items() if -6<=p[0]<=3 and -28<=p[1]<=-16 and n in (10,11,12)]
			assert blues, ('No blue lens pixels',act,pose,flip)
			for point in blues:
				r,gc,b = g.video.getpixel(screen(point))
				assert b>r+50 and b>gc+40, ('Lens lost its blue in the VDP output',act,pose,flip,point,(r,gc,b))

			g.video.save(a.output/f'ehz{act+1}-pose{pose}-flip{flip}.png')
	g.restore(saved)


def live_checks(a):
	from check_ehz_s1_pod import live
	# The S1-pod runner performs real rolling hits and the full hop/escape/capsule.
	a.player = 0
	return [str(live(a,act)) for act in (0,1)]


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
	a = p.parse_args()
	assert bool(a.reference_rom)==bool(a.reference_listing)
	a.output.mkdir(parents=True,exist_ok=True)
	result = native_checks(a)
	if a.core:
		result += live_checks(a)
	(a.output/'report.json').write_text(json.dumps(result,indent=2)+'\n')
	for row in result:
		print(row+': passed')


if __name__=='__main__':
	main()
