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
	# The affected silhouette is the only permitted difference to the S2 cockpit.
	from build_boss_shared_art import S2_FACE_SPANS,head_mask,S2_HEAD_X,S2_HEAD_Y
	old2banks = [(0,unpack(old,before['Kospm_EggPod']))]
	new2banks = [(s[tile],unpack(rom,s[label])) for tile,label in (
		('ArtTile_ArtNem_Eggpod_1','Kospm_EggPod'),('ArtTile_EggmanFace','Kospm_EggmanFace'))]
	for pose,row in enumerate(frames(rom,s['Map_EHZBoss_Cockpit'],7)):
		actual = raster(row,new2banks,s['ArtTile_ArtNem_Eggpod_1'])
		original = raster(frames(old,before['Map_EHZBoss_Vehicle'],7)[min(pose,5)+1],old2banks)
		source = raster(oldrows[pose+1],oldbanks,before['ArtTile_Eggman'])
		head = {(x+S2_HEAD_X,y+S2_HEAD_Y):(line,head_color(pose,x,y,color)) for (x,y),(line,color) in source.items() if head_mask(pose,x,y,color)}
		front = {p:original[p] for p in head if p in original and p[0]<=-15 and p[1]>=-20 and original[p][1] in (6,7,8,9,10)}
		region = set(head) | {(x,y) for y,(lo,hi) in S2_FACE_SPANS.items() for x in range(lo,hi)}
		assert {p:c for p,c in actual.items() if p not in region}=={p:c for p,c in original.items() if p not in region}, ('S2 cockpit/torso altered outside facial area',pose)
		assert all(actual.get(p)==front.get(p,c) for p,c in head.items()), ('S1 head detail or windshield overlap lost',pose)
		for (x,y),c in source.items():
			if -21<=y<=-17 and -16<=x<-5 and c[1] in (13,14,15):
				p = (x+S2_HEAD_X,y+S2_HEAD_Y)
				assert actual.get(p)==front.get(p,c), ('Glass-side whisker lost',pose,x,y)
		# Named fault locations, independent of the producer's extraction rules.
		for p in ((-17,-19),(-16,-19),(-15,-19)):
			if p in front:
				assert actual[p]==original[p], ('Whisker painted over glass',pose,p)
		for (x,y),(_,color) in source.items():
			if -6<=x<=3 and -24<=y<=-14 and color in (10,11,12):
				assert actual[(x+S2_HEAD_X,y+S2_HEAD_Y)][1] in (10,11,12), ('Non-blue lens',pose,x,y)
		if pose in (2,3):
			assert all(actual[(x,y)][1]==1 for x in (-4,-3) for y in range(-14,-11)), ('Two-tone red neck strays',pose)
	oldprop = [(0,unpack(old,before['Kospm_EggChopper']))]
	newprop = [(0,unpack(rom,s['Kospm_EggChopper']))]
	for oldrow,newrow in zip(frames(old,before['Map_EHZBoss_Propeller'],7),frames(rom,s['Map_EHZBoss_Propeller'],7)):
		assert raster(oldrow,oldprop)==raster(newrow,newprop), 'Propeller pixels changed'
	oldrow = frames(old,before['Map_EHZBoss_Vehicle'],1)[0]
	newrow = frames(rom,s['Map_EHZBoss_Vehicle'],1)[0]
	assert raster(oldrow,[(0,unpack(old,before['Kospm_EggPod']))]) == raster(newrow,[(0,unpack(rom,s['Kospm_EggPod']))])
	return ['S1 seat/lens changes are scoped; S2 neck is clean, windshield occludes whiskers, and all seven poses keep blue lenses']


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
		# Reuse the post-fight rotor slot for thrust; allocation count cannot grow.
		if kind=='EHZBoss':
			rotor = next(p for p in pool[1:] if m.get(p,'code')==s[kind] and m.get(p,'obRoutine')==4)
			count = sum(bool(m.get(p,'code')) for p in pool)
			m.put(body,'ob2ndRout',10)
			m.put(body,'objoff_30',4)
			m.put(body,'objoff_2E',0,2)
			m.act(kind,rotor)
			assert m.get(rotor,'obMap',4)==s['Map_EHZBoss_Propeller']
			m.put(body,'objoff_2E',65535,2)
			m.act(kind,rotor)
			assert m.get(rotor,'obMap',4)==s['Map_BossExhaust']
			assert m.get(rotor,'obRoutine')==16
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
				dx = 28 if kind=='EHZBoss' else 34
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
	result.append('S1 flame startup plays once; EHZ reuses its rotor slot without allocating another SST')
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
	for obj,mapping,line in ((hull,'Map_EHZBoss_Vehicle',1),(face,'Map_EHZBoss_Cockpit',0)):
		for field,value,size in (('obMap',s[mapping],4),('obGfx',s['ArtTile_ArtNem_Eggpod_1']+(line<<13),2),
			('obRender',4,1),('obPriority',0x200,2),('width_pixels',s[mapping+'_width'],1),
			('height_pixels',s[mapping+'_height'],1)):
			g.put(obj,field,value,size)
	rom = a.rom.read_bytes()
	banks = [(s[tile],unpack(rom,s[label])) for tile,label in (
		('ArtTile_ArtNem_Eggpod_1','Kospm_EggPod'),('ArtTile_EggmanFace','Kospm_EggmanFace'))]
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
			blues = [p for p,(_,n) in pixels.items() if -10<=p[0]<=-1 and -26<=p[1]<=-16 and n in (10,11,12)]
			assert blues, ('No blue lens pixels',act,pose,flip)
			for point in blues:
				r,gc,b = g.video.getpixel(screen(point))
				assert b>r+50 and b>gc+40, ('Lens lost its blue in the VDP output',act,pose,flip,point,(r,gc,b))
			if pose in (2,3,4,6):
				r,gc,b = g.video.getpixel(screen((-16,-19)))
				assert max(r,gc,b)-min(r,gc,b)<80 and min(r,gc,b)>100, ('Whisker covers glass in VDP output',act,pose,flip,(r,gc,b))
			if pose in (2,3):
				for px in (-4,-3):
					for py in range(-14,-11):
						rgb = g.video.getpixel(screen((px,py)))
						assert max(rgb)<80 and max(rgb)-min(rgb)<20, ('Red neck strays in VDP output',act,pose,flip,px,py,rgb)
			g.video.save(a.output/f'ehz{act+1}-pose{pose}-flip{flip}.png')
	g.restore(saved)


def live_checks(a):
	from genesis_test_core import Genesis
	from check_object_course import boot_level,objects
	from check_companion_followup import isolate,place,spawn
	g = Genesis(a.core,a.rom,a.listing,a.output,a.pal,system_directory=a.system_directory)
	s,rom = g.s,a.rom.read_bytes()
	result = []
	for act in (0,1):
		if act:
			g.core.retro_reset()
		boot_level(g,zone=s['id_EHZ'],act=act,player=0)
		isolate(g)
		g.put('v_player2','code',0)
		# This explicit arena fixture tests both act palettes and real CD plane loads.
		for name,value in (('Camera_X_pos',s['EHZBoss_CameraLeft']),('Camera_Y_pos',s['EHZBoss_CameraY']),
			('Camera_Min_X_pos',s['EHZBoss_CameraLeft']),('Camera_Max_X_pos',s['EHZBoss_CameraFightRight']),
			('Camera_Min_Y_pos',s['EHZBoss_CameraY']),('Camera_Max_Y_pos',s['EHZBoss_CameraY']),
			('Camera_Max_Y_pos_target',s['EHZBoss_CameraY'])):
			g.write(name,value,2)
		g.write('Screen_redraw_flag',1)
		g.write('Dynamic_Resize_Routine',6 if act else 0)
		place(g,'v_player',s['EHZBoss_LandingX']-64,s['EHZBoss_LandingY']-30,False)
		g.put('v_player','obControl',1)
		g.put('v_player','invtime',6000,2)
		for _ in range(120):
			g.run()
		assert not g.read('v_errortype')
		# Queue the exact compiled boss list through the ordinary module loader.
		assert not g.read('v_plc_buffer',4)
		plc = s['PLC_Boss']
		count = struct.unpack_from('>h',rom,plc)[0]+1
		entries = bytearray(rom[plc+2:plc+2+count*6]+bytes(6))
		for i in range(count):
			entries[i*6] |= 0x80
		for i,value in enumerate(entries):
			g.write(s['v_plc_buffer']+i,value)
		for _ in range(600):
			g.run()
			if not g.read('v_plc_buffer',4) and not g.read('v_plc_patternsleft',2):
				break
		else:
			raise AssertionError('Boss module queue did not finish')
		for label,base in (('Kospm_EggPod','ArtTile_ArtNem_Eggpod_1'),('Kospm_EggmanFace','ArtTile_EggmanFace'),('Kospm_EggChopper','ArtTile_ArtNem_EggChoppers'),('Kospm_Exhaust','ArtTile_Eggman_Exhaust')):
			raw = unpack(rom,s[label])
			assert bytes(g.vram[(s[base]*32+i)^1] for i in range(len(raw)))==raw, ('Resident boss pixels',act,label)
		body = spawn(g,'EHZBoss',s['EHZBoss_LandingX'],s['EHZBoss_LandingY']+8)
		for _ in range(500):
			g.run()
			assert not g.read('v_errortype')
			if g.get(body,'obRoutine')==2 and g.get(body,'ob2ndRout')==4:
				break
		else:
			raise AssertionError('Boss did not land/activate')
		face = next(p for p in objects(g,0x55) if g.get(p,'obRoutine')==14)
		assert g.get(face,'obMap',4)==s['Map_EHZBoss_Cockpit']
		g.video.save(a.output/f'ehz{act+1}-normal.png')
		live_gallery(g,a,act)
		# Invoke the actual hit/defeat handler; the native/GHZ checks cover collisions.
		g.put(body,'obColType',0)
		frames_out,hit_frames = [],[]
		for _ in range(40):
			g.run()
			assert not g.read('v_errortype')
			frames_out.append(g.video.copy())
			hit_frames.append(g.get(face,'obFrame'))
		assert 4 in hit_frames, ('Hurt face did not render',act,hit_frames)
		frames_out[4].save(a.output/f'ehz{act+1}-hit.png')
		g.put(body,'obStatus',g.get(body,'obStatus')|0x80)
		pictures,seen = [],set()
		for tick in range(800):
			g.run()
			assert not g.read('v_errortype')
			assert g.read('v_gamemode',2)==s['Level'], ('Escape interrupted by game-mode change',act,tick)
			for p in objects(g,0x55):
				if g.get(p,'obRoutine')==16:
					assert g.get(p,'obMap',4)==s['Map_BossExhaust']
					seen.add(g.get(p,'obFrame'))
					if tick%2==0:
						pictures.append(g.video.copy())
			if not g.get(body,'code'):
				break
		assert {0,1,2,3}<=seen, ('Incomplete live escape flame',act,seen)
		assert not g.get(face,'code'), 'Pilot survived deleted parent'
		pictures[0].save(a.output/f'ehz{act+1}-escape.webp',save_all=True,append_images=pictures[1:],duration=34,loop=0,lossless=True)
		pictures[min(4,len(pictures)-1)].save(a.output/f'ehz{act+1}-escape.png')
		if act==1:
			place(g,'v_player',0x2B50,0x6D0,False)
			g.put('v_player','obControl',1)
			for _ in range(90):
				g.run()
				assert not g.read('v_errortype') and g.read('v_gamemode',2)==s['Level']
			buttons = [p for p in objects(g,0x3E) if g.get(p,'obSubtype')==1]
			assert len(buttons)==1, ('Capsule switch not loaded',buttons)
			button = buttons[0]
			for name,value,size in (('obControl',0,1),('obX',g.get(button,'obX',2),2),
				('obY',g.get(button,'obY',2)-40,2),('obVelX',0,2),('obVelY',0x100,2),
				('obStatus',2,1),('obAnim',0,1)):
				g.put('v_player',name,value,size)
			for _ in range(180):
				g.run()
				assert not g.read('v_errortype')
				if g.read('Boss_defeated_flag')==2:
					break
			else:
				raise AssertionError('EHZ capsule did not open')
			g.run(4)
			assert any(g.get(p,'code')==s['Flicky'] for p in objects(g))
			g.video.save(a.output/'ehz2-capsule-open.png')
		result.append(f'EHZ{act+1}: all seven VDP-rendered poses in both facings, blue lenses, foreground glass, clean neck, escape and cleanup')
	return result


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
