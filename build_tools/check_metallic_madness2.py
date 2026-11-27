#!/usr/bin/env python3
"""Check MMZ2's source pixels/collision paths, real headers, parallax and VRAM.

Source comparisons retain every authored chunk. Core visits use ordinary level
entry, PLCs, callbacks and rendering with positioned players, not a full run.
"""
from pathlib import Path
import argparse
import ctypes as C
import json
import struct
from native_test_core import Native,UC_M68K_REG_A2,UC_M68K_REG_D4,UC_M68K_REG_D5,UC_M68K_REG_D7
from terrain_collision import read_bank,reflect
from sprite_palette import PLAYER_FROM_S1,remap_pixels
from import_metallic_madness import ENEMY_FROM_MMZ,animations
from import_ehz2_pp_background import nemesis
from check_metallic_madness import ERAS,animation_checks
from level_layout import load

ROOT=Path(__file__).resolve().parents[1]


def rows(past):
	if past:
		# Original CD reverse-fill repetitions, then its forward-fill gradient.
		first=sum(([g]*(n+1) for g,n in reversed(list(enumerate((1,1,1,3,3,1,1,1,1,1,1,1))))),[])
		second=sum(([(12+g)]*(n+1) for g,n in enumerate((0,0,0,0,0,0,1,1))),[])
		return first+[20]*4+second+[22]*10+[21]*12
	first=sum(([g]*(n+1) for g,n in enumerate((1,1,1,0,0,0,0))),[])
	second=sum(([g]*(n+1) for g,n in reversed(list(enumerate((1,9,1,0,0,0,0))))),[])
	return [9]*6+first+[10]*18+second+[9]*12


def values(x,past):
	far,near,base=x//4,x//2,x*3//16
	if past:
		step=((x-base)*64//12)*1024
		first=[-((base*65536+i*step)//65536) for i in range(12)]
		step=((far-base)*64//8)*1024
		return first+[-((base*65536+i*step)//65536) for i in range(8)]+[-base,-near,-far]
	step=((near-far)*128//5)*512
	return [-((far*65536+i*step)//65536) for i in range(9)]+[-base,-near]


def native(a):
	n=Native(a.rom,a.listing);rom=a.rom.read_bytes();cases=0
	for era,(key,title,folder) in enumerate(ERAS):
		n.start();n.write('Current_ZoneAndAct',0xF01,2);n.write('Current_Timezone',era)
		n.act('GetLevelArtHeader');at=n.cpu.reg_read(UC_M68K_REG_A2)&0xffffff
		parts=struct.unpack_from('>3I',rom,at)
		assert [v&0xffffff for v in parts]==[n.s[p+key] for p in ('Kosp_MMZ2_','Map16_MMZ2_','Map128_MMZ2_')]
		assert parts[2]>>24==n.s['palid_MMZ2_'+key]
		base=n.s['ArtLoadCues'];entry=struct.unpack_from('>H',rom,base+(parts[0]>>24)*2)[0]
		assert entry&n.s['PLCKos_IndexFlag'];plc=base+(entry&~n.s['PLCKos_IndexFlag'])
		count=struct.unpack_from('>h',rom,plc)[0]+1
		expected=[(n.s[label],(n.s['ArtTile_MMZ_Atlas']+offset)*32) for label,offset in (
			('Kospm_MMZ2_EmittersDoors',0),('Kospm_MMZ_CrusherFloor',38),('Kospm_MMZ2_BombCrushers',110),
			('Kospm_MMZ_MechaBu',270),('Kospm_MMZ2_DangoDoors',318),('Kospm_MMZ_TimePostHeads',432),
			('Kospm_MMZ_GeneratorPast' if era==1 else 'Kospm_MMZ_Generator',454))]
		assert [struct.unpack_from('>IH',rom,plc+2+i*6) for i in range(count)]==expected
		assert count+n.s['ActPLC_Main_Reserve']<=16
		n.act('LoadCollisionIndexes');assert n.read('v_colladdr1',4)==n.s['Col_MMZ2_'+key]
		selectors=rows(era==1);assert len(selectors)==64
		for x in (0,1,15,16,127,128,1023,4095,5121,6000,7831):
			for y in (0,1,7,8,63,64,127,511,1023,1407,1808):
				n.write('Camera_X_pos',x,2);n.write('Camera_Y_pos',y,2);n.act('Deform_MMZ2')
				actual=struct.unpack('>448h',n.cpu.mem_read(n.s['v_hscrolltablebuffer']&0xffffff,224*4))
				v=values(x,era==1);expected=tuple(k for line in range(224) for k in (-x,v[selectors[(y//8+line)//8]]))
				assert actual==expected,(era,x,y,'MD hscroll')
				assert n.read('Camera_BG_Y_pos',2)==y//8
				cases+=1
		for label,val in (('MCD_TerrainBG_Sub',333),('MCD_TerrainBG2_Sub',888),('MCD_TerrainBG3_Sub',777)):
			n.sub.mem_write(n.s[label],struct.pack('>H',val))
		n.sub.mem_write(n.s['MCD_TerrainTimeZone_Sub'],bytes((era,)))
		for y in range(-16,769,8):
			n.sub.reg_write(UC_M68K_REG_D4,y&65535);n.sub_call('Plane_SourceMMZ2')
			idx=selectors[(y%512)//8]
			cams={20:333,21:888,22:777} if era==1 else {9:333,10:888}
			expected=(cams[idx],0) if idx in cams else (0,1)
			assert (n.sub.reg_read(UC_M68K_REG_D5)&65535,n.sub.reg_read(UC_M68K_REG_D7)&65535)==expected
			cases+=1
	# Verify the reciprocal shortcut's complete authored camera domain against
	# the original unsigned DIVU quantization, including its far-right edge.
	for x in range(0x1E98):
		delta=x-x*3//16
		assert ((delta*0xAAAB)&0xFFFFE000)>>3==((delta*64)//12)<<10
	revolving_doors(n)
	return dict(eras=4,header_parallax_cases=cases,reciprocal_domain=7832,max_initial_plcs=14,door_axes=2,
		vertical_doors=vertical_doors(n))


def vertical_doors(n):
	"""Run both panels through the same controller with each resident art bank."""
	s = n.s
	slots = list(range(s['v_lvlobjspace'] & 0xFFFFFF, s['v_lvlobjend'] & 0xFFFFFF, s['object_size']))
	root = slots[5]
	actors = ('v_player', 'v_player2')
	def init(zone, subtype, flip):
		n.start()
		n.write('Current_Zone', zone)
		n.write('Camera_X_pos_coarse_back', 256, 2)
		for field, value, size in (('code', s['Obj30'], 4), ('obX', 600, 2), ('obY', 600, 2),
			('obSubtype', subtype, 2), ('obRender', 0x84 | flip, 1), ('obStatus', flip, 1)):
			n.put(root, field, value, size)
	def update():
		n.act('Obj30', root, regs={UC_M68K_REG_D7: 0x3579006F})
		assert n.cpu.reg_read(UC_M68K_REG_D7) == 0x3579006F
		return n.get(root, 'door_travel', 2)
	def place(actor, x, y, vx=0):
		for field, value, size in (('code', 1, 4), ('obRoutine', 2, 1), ('obRender', 0x84, 1),
			('obX', x, 2), ('obY', y, 2), ('obVelX', vx & 0xFFFF, 2), ('obWidth', 9, 1),
			('obHeight', 19, 1), ('obStatus', 2, 1)):
			n.put(actor, field, value, size)

	banks = ((0, 0, 'Map_Obj30'), (8, 0, 'Map_SMZ_Door'),
		(15, 0x80, 'Map_MMZ_Door1'), (15, 0x81, 'Map_MMZ_Door2'), (15, 0x82, 'Map_MMZ_Door3'))
	for zone, subtype, mapping in banks:
		for flip in (0, 1):
			init(zone, subtype, flip)
			assert update() == 0
			child = 0xFF0000 | n.get(root, 'door_partner', 2)
			assert n.get(child, 'code') == s['ADoor_Upper']
			assert n.get(child, 'door_parent', 2) == root & 0xFFFF
			assert n.get(root, 'obMap', 4) == n.get(child, 'obMap', 4) == s[mapping]
			side = 1 if (subtype == 0x81) ^ bool(flip) else -1
			place(actors[0], 600 - side * 40, 600)
			assert update() == 0
			place(actors[0], 600 + side * 40, 649)
			assert update() == 0
			place(actors[1], 600 + side * 40, 600)
			assert update() == 2 and update() == 4

			# Each player hits a different panel while the panels are sliding.
			place(actors[0], 588, 568, 0x200)
			place(actors[1], 612, 632, -0x200)
			assert update() == 6
			assert [n.get(actor, 'obX', 2) for actor in actors] == [583, 617]
			assert all(n.get(actor, 'obVelX', 2) == 0 for actor in actors)

			# The opening completes even if the first player leaves the sensor early.
			for actor in actors:
				place(actor, 400, 400)
			for gap in (*range(8, 33, 2), 33):
				assert update() == gap
				assert n.get(root, 'obY', 2) == 616 + gap
				assert n.get(child, 'obY', 2) == 584 - gap
				assert n.get(root, 'obFrame') == n.get(child, 'obFrame')
			place(actors[0], 600 - side * 22, 600)
			assert update() == 33
			place(actors[0], 400, 400)
			assert update() == 31 and update() == 29
			place(actors[1], 600 - side * 22, 600)
			assert update() == 31 and update() == 33
			place(actors[1], 400, 400)
			for gap in (*range(31, 0, -2), 0):
				assert update() == gap
			n.write('Camera_X_pos_coarse_back', 1536, 2)
			update()
			assert not n.get(root, 'code') and not n.get(child, 'code')

	init(8, 0, 0)
	for a in slots:
		n.put(a, 'code', s['Obj30'])
	before = bytes(n.cpu.mem_read(root, s['object_size']))
	update()
	assert bytes(n.cpu.mem_read(root, s['object_size'])) == before
	n.put(slots[0], 'code', 0)
	update()
	assert n.get(root, 'door_partner', 2) == slots[0] & 0xFFFF
	n.put(root, 'code', 0)
	n.act('ADoor_Upper', slots[0])
	assert not n.get(slots[0], 'code')
	return dict(profiles=len(banks)*2, both_panels_solid_during_travel=True,
		both_players_open_and_hold=True, full_pool_retry=True, paired_unload=True)


def revolving_doors(n):
	actors = ('v_player', 'v_player2')
	door = n.s['v_lvlobjspace']
	x, y = 512, 512
	for axis in (0, 4):
		n.start()
		n.write('Camera_X_pos_coarse_back', 256, 2)
		n.put(door, 'layout_id', 0x0A)
		n.put(door, 'obX', x, 2)
		n.put(door, 'obY', y, 2)
		n.put(door, 'obSubtype', n.s['PathSwitch_Door'] | 0x28 | axis)

		def update(offsets):
			for actor, offset in zip(actors, offsets):
				n.put(actor, 'obX', x + (0 if axis else offset), 2)
				n.put(actor, 'obY', y + (offset if axis else 0), 2)
			n.act(n.get(door, 'code'), door)

		update((-20, 20))
		assert n.get(door, 'obMap', 4) == n.s['Map_MMZ_RevolveDoor']
		assert n.get(door, 'obGfx', 2) == n.s['ArtTile_MMZ_Atlas']
		update((-1, 1))
		assert n.get(door, 'switch_inside') == 0xC0
		assert n.get(door, 'obFrame') == (1 if axis else 2)
		assert n.get(door, 'obRender') & 1 == (0 if axis else 1)
		update((20, 1))
		assert n.get(door, 'switch_inside') == 0x40
		assert [n.get(actor, 'obTopSolidBit', 2) for actor in actors] == [0x0E0F, 0x0C0D]
		update((20, -20))
		assert n.get(door, 'switch_inside') == 0
		assert [n.get(actor, 'obGfx', 2) >> 15 for actor in actors] == [1, 0]

		update((0, 0))
		n.put(door, 'obSubtype', n.get(door, 'obSubtype') | 0x80)
		n.put(actors[0], 'obStatus', 2)
		n.put(actors[1], 'code', 0)
		update((-20, 20))
		assert n.get(door, 'switch_inside') == 0
		assert [n.get(actor, 'obTopSolidBit', 2) for actor in actors] == [0x0E0F, 0x0C0D]
		for _ in range(16):
			update((-20, 20))
		assert n.get(door, 'obFrame') == (0 if axis else 2)
		assert not n.get(door, 'obRender') & 1


def source_geometry(a):
	maps=a.source/'src/maps/r8';cd=read_bank(a.source/'src/maps',('collision_columns.bin','collision_rows.bin','collision_angles.bin'))
	bank=read_bank(ROOT/'collision')
	profiles=visuals=shared_ramps=0
	def profile_equal(p,q):
		return p[:2]==q[:2] and (not any(p[0]+p[1]) or (bool(p[2]&1) and bool(q[2]&1) if p[2]&1 else p[2]==q[2]))
	def flip_tile(data,f):
		pixels=[[((data[y*4+x//2]>>(4 if not x%2 else 0))&15) for x in range(8)] for y in range(8)]
		if f&1:pixels=[r[::-1] for r in pixels]
		if f&2:pixels=pixels[::-1]
		return bytes(r[x]<<4|r[x+1] for r in pixels for x in range(0,8,2))
	for era,(key,title,folder) in enumerate(ERAS):
		letter='abcd'[era];raw=(maps/f'foreground_2{letter}.bin').read_bytes();width=raw[0]+1
		original=(maps/f'chunks_2{letter}.bin').read_bytes();srcblocks=nemesis((maps/f'blocks_2{letter}.nem').read_bytes())
		srcindices=(maps/f'collision_2{letter}.bin').read_bytes();srcart=nemesis((maps/f'gfx_2{letter}.nem').read_bytes())
		chunks=(ROOT/f'mappings/128x128/MMZ2 {title}.unc').read_bytes();blocks=(ROOT/f'mappings/16x16/MMZ2 {title}.unc').read_bytes()
		indices=(ROOT/f'collision/{("present","past","good Future","bad future")[era]}/LV0F2.bin').read_bytes()
		fg,bg=load(ROOT/f'level/layout/{folder}LV0F_2.kosp');assert (len(fg[0]),len(fg))==(66,16)
		art=(ROOT/f'art/kosinski/level/8x8 - MMZ2 {title}.unc').read_bytes()
		cache={}
		def visual(words,f,source):
			cachekey=words,f,source
			if cachekey in cache:return cache[cachekey]
			out=[]
			for ty in range(2):
				for tx in range(2):
					w=words[((ty^bool(f&2))*2)+(tx^bool(f&1))];tile=w&2047;pal=w>>13&3
					if source:
						data=srcart[tile*32:(tile+1)*32]
						lookup=PLAYER_FROM_S1 if pal==0 else ENEMY_FROM_MMZ if pal==1 else tuple(range(16))
						data=remap_pixels(data,lookup)
					else:
						data=art[tile*32:(tile+1)*32]
					assert len(data)==32
					out.append((pal,w&0x8000,flip_tile(data,((w>>11)&3)^f)))
			cache[cachekey]=tuple(out);return tuple(out)
		# Every authored base chunk survives, including unplaced/alternate art.
		for c in range(len(original)//512):
			for by in range(16):
				for bx in range(16):
					sw=struct.unpack_from('>H',original,c*512+by*32+bx*2)[0]
					cid=1+c*4+(by//8)*2+bx//8
					dw=struct.unpack_from('>H',chunks,cid*128+(by&7)*16+(bx&7)*2)[0]
					sb=struct.unpack_from('>4H',srcblocks,(sw&2047)*8);db=struct.unpack_from('>4H',blocks,(dw&1023)*8)
					assert visual(sb,(sw>>11)&3,True)==visual(db,(dw>>10)&3,False),(era,c,by,bx,'terrain pixels')
					visuals+=1
		# Independently follow CD's flagged-chunk substitutions for each path.
		alternate={0x46:0x6A,0x48:0x6B,0x4A:0x6C,0x10:0x6D,0x63:0x6E,0x43:0x6F}
		for i,c in enumerate(raw[2:]):
			if not c:continue
			for by in range(16):
				for bx in range(16):
					cid=fg[(i//width)*2+by//8][(i%width)*2+bx//8]
					dw=struct.unpack_from('>H',chunks,cid*128+(by&7)*16+(bx&7)*2)[0]
					for path in (0,1):
						sc=alternate.get(c&127,c&127) if path and c&128 else c&127
						sw=struct.unpack_from('>H',original,(sc-1)*512+by*32+bx*2)[0]
						assert (sw>>13&3)==(dw>>(12+path*2)&3),(era,i,by,bx,path,'solidity')
						source = srcindices[sw&2047]
						dest = indices[(dw&1023)*2+path]
						p = reflect(cd[source], (sw>>11)&3)
						q = reflect(bank[dest], (dw>>10)&3)
						if (source, dest) == (0x6E, 0x69):
							assert p[:2] == q[:2] and abs((q[2]-p[2]+128)%256-128) == 8
							shared_ramps += 1
						else:
							assert profile_equal(p,q),(era,i,by,bx,path,'collision profile/angle')
						profiles+=1
	assert shared_ramps
	return dict(authored_block_pixels=visuals,path_profiles=profiles,original_chunks_preserved=True,
		shared_ramp_cells=shared_ramps,max_angle_difference=8)


def past_panel_frames(g, source):
	"""Check the original sequence on the visible panel at $0730,$0050."""
	from check_companion_followup import place
	from import_metallic_madness import table_values
	import re

	stage = source/'src/r8'
	pointers = table_values((stage/'stage_gfx_animate_2b.asm').read_text(), 'unk_20FBD8', 'l')
	files = dict(re.findall(r'^(\w+):\s*\n\s*incbin\s+"([^"]+)"', (stage/'data_2b.asm').read_text(), re.M))
	expected = [(source/files[label]).read_bytes()[:128] for label in pointers]
	assert len(set(expected)) == len(expected) == 6

	for actor in ('v_player', 'v_player2'):
		place(g, actor, 0x730, 132)
		g.put(actor, 'obControl', 0x81)
	g.write('Camera_X_pos', 0x690, 2)
	g.write('Camera_Y_pos', 0, 2)
	g.write('Screen_redraw_flag', 1)
	g.run(32)

	first = g.s['ArtTile_MMZ2_Past_Anim1']
	plane = g.s['vram_fg']+(0x50//8&31)*128+(0x730//8&63)*2
	word = (g.vram[plane^1]<<8) | g.vram[(plane+1)^1]
	assert first <= word & 0x7FF < first+4
	previous = None
	crops = {}
	for _ in range(90):
		raw = bytes(g.vram[(first*32+i)^1] for i in range(128))
		assert raw in expected, 'Past panel retained its numbered placeholder'
		frame = expected.index(raw)
		if previous is not None and frame != previous:
			assert frame == (previous+1)%6
		x = 0x730-g.read('Camera_X_pos', 2)
		y = 0x50-g.read('Camera_Y_pos', 2)
		assert 0 <= x <= 304 and 0 <= y <= 208
		crops[frame] = g.video.crop((x,y,x+16,y+16)).tobytes()
		previous = frame
		g.run()
	assert len(crops) == len(set(crops.values())) == 6
	g.video.save(g.output/'past-animated-panel.png')
	return len(crops)


def game(a):
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_companion_followup import place,spawn,isolate
	g=Genesis(a.core,a.rom,a.listing,a.output/'game',a.pal,system_directory=a.system_directory)
	initial=g.save();vsram=(C.c_uint8*128).in_dll(g.core,'vsram');result=[]
	def word(mem,at):return mem[at^1]*256+mem[(at+1)^1]
	for era,(key,title,folder) in enumerate(ERAS):
		g.restore(initial);boot_level(g,zone=15,act=1,timezone=era);isolate(g)
		assert not g.read('v_errortype') and g.read('Current_ZoneAndAct',2)==0xF01
		angles = (ROOT/'collision/Curve and resistance mapping.bin').read_bytes()
		assert bytes(g.read(0x420000+g.s['MCD_TerrainAngles_Sub']+i) for i in range(256)) == angles
		fg,bg=load(ROOT/f'level/layout/{folder}LV0F_2.kosp');chunks=(ROOT/f'mappings/128x128/MMZ2 {title}.unc').read_bytes();blocks=(ROOT/f'mappings/16x16/MMZ2 {title}.unc').read_bytes()
		def tile(plane,x,y):
			cid=(fg[y//128][x//128] if y//128<len(fg) and x//128<len(fg[0]) else 0) if not plane else bg[y//128%len(bg)][x//128%len(bg[0])]
			entry=struct.unpack_from('>H',chunks,cid*128+(y//16&7)*16+(x//16&7)*2)[0]
			bx=(x//8&1)^bool(entry&0x400);by=(y//8&1)^bool(entry&0x800)
			return struct.unpack_from('>H',blocks,(entry&1023)*8+(by*2+bx)*2)[0]^(0x800 if entry&0x400 else 0)^(0x1000 if entry&0x800 else 0)
		selectors=rows(era==1);samples=0
		for index,(x,y) in enumerate(((0,1068),(128,1408),(1800,0),(4800,448),(6000,896),(7831,1808))):
			for actor in ('v_player','v_player2'):
				place(g,actor,x+160,y+96);g.put(actor,'obControl',0x81)
			g.write('Camera_X_pos',x,2);g.write('Camera_Y_pos',y,2);g.write('Screen_redraw_flag',1);g.run(30)
			assert not g.read('v_errortype')
			for plane in (0,1):
				py=word(vsram,plane*2)&2047
				for sy in range(0,224,8):
					wy=py+sy;scroll=word(g.vram,g.s['vram_hscroll']+sy*4+plane*2);scroll=scroll-65536 if scroll&32768 else scroll
					fixed=plane and selectors[(wy//8)%64]<(20 if era==1 else 9)
					for sx in range(0,320,8):
						wx=(sx-scroll)&65535;actual=word(g.vram,(0xE000 if plane else 0xC000)+(wy//8&31)*128+(wx//8&63)*2)
						assert actual==tile(plane,wx%512 if fixed else wx,wy),(era,index,plane,sx,sy,'visible tilemap')
						samples+=1
			g.video.save(g.output/f'era{era}-pose{index}.png')
		row = dict(era=era,visible_tile_samples=samples,
			terrain_tiles=(ROOT/f'art/kosinski/level/8x8 - MMZ2 {title}.unc').stat().st_size//32)
		if era == 1:
			row['animated_panel_frames'] = past_panel_frames(g, a.source)
		result.append(row)
	g.close();return result


def twin_allocation(a):
	from check_sprite_assets import frames
	from native_test_core import UC_M68K_REG_A0, UC_M68K_REG_SR
	from convert_s1_ss_background import kosinski_plus_decode

	n = Native(a.rom, a.listing)
	n.start()
	s = n.s
	slots = list(range(s['v_lvlobjspace'] & 0xFFFFFF, s['v_lvlobjend'] & 0xFFFFFF, s['object_size']))
	foot, mate, links = slots[-3:]
	for slot in slots:
		if slot != mate:
			n.put(slot, 'code', s['DisplaySprite'])
	n.put(foot, 'code', s['MMZ_TwinWalker'])
	n.put(foot, 'obX', 600, 2)
	n.put(foot, 'obY', 500, 2)
	n.write('Camera_X_pos_coarse_back', 384, 2)
	length = s['object_size']
	before = [bytes(n.cpu.mem_read(slot, length)) for slot in (foot, mate)]
	n.act('MMZ_TwinWalker', foot)
	assert [bytes(n.cpu.mem_read(slot, length)) for slot in (foot, mate)] == before
	n.put(links, 'code', 0)
	n.act('MMZ_TwinWalker', foot)
	assert n.get(foot, 'code') == s['MMZ_TwinWalker_Run']
	assert n.get(foot, 'twin_mate', 2) == mate & 0xFFFF and n.get(foot, 'twin_links', 2) == links & 0xFFFF
	assert n.get(mate, 'obX', 2) == 664 and n.get(links, 'mainspr_childsprites') == 6
	assert [n.get(links, f'sub{i}_x_pos', 2) for i in range(2, 8)] == list(range(656, 608, -8))
	assert n.get(links, 'obX', 2) == 608
	n.act('MMZ_TwinWalker_Run', foot, regs={UC_M68K_REG_D7: 0x13572468})
	assert n.cpu.reg_read(UC_M68K_REG_D7) == 0x13572468
	assert n.cpu.reg_read(UC_M68K_REG_A0) & 0xFFFFFF == foot

	raw = (ROOT/'art/uncompressed/MMZ2 Twin Walker.unc').read_bytes()
	rom = a.rom.read_bytes()
	assert len(raw) == s['TwinWalker_ArtTiles']*32
	archive = s['Kospm_MMZ_TwinWalker']
	assert struct.unpack_from('>H', rom, archive)[0] == len(raw)
	assert kosinski_plus_decode(rom, archive+2)[0] == raw
	assert struct.unpack_from('>H', rom, s['Kospm_MMZ2_BombCrushers'])[0] == 121*32
	mapping = (ROOT/'mappings/sprite/MMZ TwinWalker.bin').read_bytes()
	assert all((word & 0x6000) == 0 and (word & 0x7FF) < s['TwinWalker_ArtTiles']
		for row in frames(mapping) for _, _, word, _ in row)

	n.uploads.clear()
	n.write('TwinWalker_ArtFrame', 0xFE)
	queue_end = s['VDP_Command_Buffer_Slot'] & 0xFFFF
	n.write('VDP_Command_Buffer_Slot', queue_end-s['DMAEntry.len']*2, 2)
	n.act('MMZ_TwinWalker_LoadArt', foot)
	assert n.cpu.reg_read(UC_M68K_REG_SR) & 1
	assert not n.uploads and n.read('TwinWalker_ArtFrame') == 0xFE
	n.write('VDP_Command_Buffer_Slot', s['VDP_Command_Buffer'] & 0xFFFF, 2)
	source, destination = s['Art_TwinWalker'] & 0xFFFFFFFF, s['ArtTile_MMZ2_TwinWalker']*32
	n.act('MMZ_TwinWalker_LoadArt', foot)
	assert not n.cpu.reg_read(UC_M68K_REG_SR) & 1
	assert [(addr, dest & 0xFFFF, words & 0xFFFF) for addr, dest, words in n.uploads] == [
		(source, destination, 256), (source+512, destination+512, 16)]
	n.uploads.clear()
	n.act('MMZ_TwinWalker_LoadArt', mate)
	assert not n.uploads and n.read('TwinWalker_ArtFrame') == 0

	n.put(mate, 'code', s['DisplaySprite'])
	n.act('MMZ_TwinWalker_Run', foot)
	assert n.get(mate, 'code') == s['DisplaySprite']
	assert not n.get(foot, 'code') and not n.get(links, 'code')
	return dict(pool_retry=True, packed_links=7, recycled_slot_preserved=True,
		object_loop_preserved=True, packed_art_tiles=17, dma_queue_retry=True)


def spike_crusher_native(args):
	"""Verify the five groups' timing, placement and atomic allocation."""
	n = Native(args.rom, args.listing)
	n.start()
	s = n.s
	slots = list(range(s['v_lvlobjspace'] & 0xFFFFFF, s['v_lvlobjend'] & 0xFFFFFF, s['object_size']))
	root = slots[5]
	x, y = 600, 500
	n.write('Camera_X_pos_coarse_back', 384, 2)
	n.put(root, 'code', s['MMZ_SpikeCrusher'])
	n.put(root, 'obX', x, 2)
	n.put(root, 'obY', y, 2)
	for slot in slots:
		if slot != root and slot not in slots[-3:]:
			n.put(slot, 'code', s['DisplaySprite'])
	original = bytes(n.cpu.mem_read(root, s['object_size']))
	n.act('MMZ_SpikeCrusher', root)
	assert bytes(n.cpu.mem_read(root, s['object_size'])) == original
	for slot in slots:
		if slot != root:
			n.put(slot, 'code', 0)
	n.act('MMZ_SpikeCrusher', root)
	assert n.get(root, 'platgroup_count') == 4
	children = tuple(n.get(root+offset, 'platgroup_members', 2) | 0xFF0000 for offset in (0, 2, 4, 6))
	assert [n.get(part, 'obX', 2) for part in (root, *children)] == [x-52, x, x+52, x-52, x+52]
	assert [n.get(part, 'obColType') for part in children] == [0, 0, 0x9C, 0x9C]

	# Use Tails with Sonic far outside the activation band. Let the clock
	# run while the already-landed root is stationary.
	n.put(root, 'spikecrusher_landed', 0xFF)
	n.put('v_player', 'obX', x+256, 2)
	n.put('v_player2', 'obX', x, 2)
	n.put('v_player2', 'obY', y+256, 2)
	launches = {}
	for tick in range(1, 1082):
		n.act('MMZ_SpikeCrusher_Controller', root, regs={UC_M68K_REG_D7: 0x13572468})
		assert n.cpu.reg_read(UC_M68K_REG_D7) == 0x13572468
		for slot in slots:
			if n.get(slot, 'code') != s['MMZ_SpikeCrusher']:
				continue
			wave = n.get(slot, 'obSubtype')
			assert wave not in launches and n.get(slot, 'obX', 2) == x
			assert n.get(slot, 'obY', 2) == y-16*wave
			launches[wave] = tick
			n.act('MMZ_SpikeCrusher', slot)
			assert n.get(slot, 'spikecrusher_wave') == wave
			assert n.get(slot, 'spikecrusher_depth', 2) == wave*24
	assert launches == {1: 300, 2: 600, 3: 840, 4: 1080}, launches
	n.act('MMZ_SpikeCrusher_Touch', children[2])
	assert not n.get(children[2], 'code') and not n.get(root+4, 'platgroup_members', 2)
	n.act('PlatformGroup_Unload', root)
	n.act('MMZ_SpikeCrusher_Touch', children[3])
	assert all(not n.get(part, 'code') for part in (root, *children))
	return dict(launch_updates=list(launches.values()), atomic_group=True, landed_hitbox_removed=True)


def spike_crusher_game(g, era, output):
	from check_companion_followup import place, reset_cpu
	from check_rising_crushers import ACTORS, seek

	x, y = 0x1A80, 0x010C
	s = g.s
	seek(g, x, y)
	slots = range(s['v_lvlobjspace'] & 0xFFFF, s['v_lvlobjend'] & 0xFFFF, s['object_size'])
	root = next(slot for slot in slots if g.get(slot, 'platgroup_state', 4) == s['MMZ_SpikeCrusher_Controller']
		and (g.get(slot, 'platgroup_x', 2), g.get(slot, 'platgroup_y', 2)) == (x, y))
	panels = (root, *(g.get(root+offset, 'platgroup_members', 2) for offset in (0, 2)))
	touch = tuple(g.get(root+offset, 'platgroup_members', 2) for offset in (4, 6))
	scene = g.save()
	for actor, teeth in zip(ACTORS, touch):
		g.restore(scene)
		reset_cpu(g)
		g.buttons2 = {4}
		g.write('v_rings', 10, 2)
		place(g, actor, g.get(teeth, 'obX', 2), y+12+g.get(actor, 'default_y_radius')-5)
		g.put(actor, 'obControl', 1)
		g.put(actor, 'obRender', 0x84)
		for _ in range(10):
			g.run()
			if g.get(actor, 'obRoutine') == 4:
				break
		assert g.get(actor, 'obRoutine') == 4, (era, actor, 'crusher underside')
		g.restore(scene)
		reset_cpu(g)
		g.buttons2 = {4}
		place(g, actor, x, y+270)
		g.put(actor, 'obControl', 1)
		g.put(actor, 'obRender', 0x84)
		for _ in range(12):
			g.run()
			if all(g.get(panel, 'obY', 4) > y << 16 for panel in panels):
				break
		assert g.get(root, 'obRoutine') == 2 and all(g.get(panel, 'obY', 4) > y << 16 for panel in panels), (era, actor)
		g.video.save(output/f'spike-crusher-era{era}.png')
		for _ in range(440):
			g.run()
			if all(g.get(panel, 'spikecrusher_landed') for panel in panels):
				break
		assert all(g.get(panel, 'spikecrusher_landed') for panel in panels), (era, actor, 'terrain stops')
		assert not g.read('v_errortype')


def ride_twin_walker(g, era, output):
	from check_companion_followup import place
	from check_rising_crushers import ACTORS, seek

	x, y = 0x16B2, 0x0658
	s = g.s
	assert g.read('TwinWalker_ArtFrame') == 0xFF
	seek(g, x-80, y)
	check_twin_art_upload(g)
	slots = range(s['v_lvlobjspace'] & 0xFFFF, s['v_lvlobjend'] & 0xFFFF, s['object_size'])
	walker = next(slot for slot in slots if g.get(slot, 'code') == s['MMZ_TwinWalker_Run'])
	mate = g.get(walker, 'twin_mate', 2)
	assert g.get(walker, 'twin_steps') == 12 and g.get(mate, 'obX', 2) == x+64
	scene = g.save()
	for riders in (((ACTORS[0], walker),), ((ACTORS[1], walker),), tuple(zip(ACTORS, (walker, mate)))):
		g.restore(scene)
		g.buttons, g.buttons2 = set(), {4}
		for actor, foot in riders:
			radius = g.get(actor, 'default_y_radius')
			place(g, actor, g.get(foot, 'obX', 2), y-s['twin_foot_height']-radius-3)
			g.put(actor, 'obVelY', 0x300, 2)
		max_updates = len(riders)*(0x10000//s['twin_stride']) + 8
		for tick in range(max_updates):
			# Sample after both the sub-CPU floor result and the rider carry.
			for _ in range(12):
				g.run()
				if g.read('v_vbla_counter') == 1:
					break
			else:
				raise AssertionError('Twin Walker update did not complete')
			assert not g.read('v_errortype')
			if g.get(walker, 'twin_steps') == 12:
				continue
			for actor, foot in riders:
				case = era, tick, riders, actor
				assert g.get(actor, 'obRoutine') == 2 and g.get(actor, 'obStatus') & 8, case
				slot = ((foot-(s['v_objspace'] & 0xFFFF))//s['object_size'])
				assert g.get(actor, 'standonobject') == slot, case
				actor_foot = g.get(actor, 'obY', 2)+g.get(actor, 'obHeight')
				surface = g.get(foot, 'obY', 2)-s['twin_foot_height']
				assert actor_foot == surface, (case, actor_foot, surface)
			swinging = g.get(walker, 'obRoutine') == 4
			landed = 12-g.get(walker, 'twin_steps')-int(swinging)
			if landed >= len(riders):
				assert g.get(walker, 'twin_pivot') == landed & 1, (era, riders, landed)
				break
		else:
			raise AssertionError((era, riders, 'walker did not land'))
		if len(riders) == 2:
			g.video.save(output/f'twin-walker-era{era}.png')


def check_twin_art_upload(g):
	raw = (ROOT/'art/uncompressed/MMZ2 Twin Walker.unc').read_bytes()
	base = g.s['ArtTile_MMZ2_TwinWalker']*32
	for _ in range(24):
		assert not g.read('v_errortype')
		uploaded = bytes(g.vram[(base+i)^1] for i in range(len(raw)))
		if g.read('TwinWalker_ArtFrame') == 0 and uploaded == raw:
			return
		g.run()
	raise AssertionError('Twin Walker art did not reach VRAM')


def mmz2_debug_entry(g, code):
	base = g.s['Debug_MMZ2']
	count = struct.unpack_from('>H', g.rom, base)[0]
	size = g.s['DebugEntry_size']
	index = next(i for i in range(count) if struct.unpack_from('>I', g.rom, base+2+i*size)[0] == code)
	return index, count


def twin_debug_preview(g):
	s = g.s
	assert g.read('TwinWalker_ArtFrame') == 0xFF
	g.write('Debug_mode_flag', 1)
	g.buttons = {0}
	g.run(2)
	g.buttons = set()
	g.run(3)
	assert g.read('Debug_placement_type') == s['DebugType_Placement']
	index, count = mmz2_debug_entry(g, s['MMZ_TwinWalker'])
	g.write('Debug_object', (index-1) % count)
	g.buttons = {1}
	g.run(2)
	g.buttons = set()
	check_twin_art_upload(g)
	assert g.read('Debug_object') == index
	assert g.get('v_player', 'obMap', 4) == s['Map_MMZ_TwinWalker']
	assert g.get('v_player', 'obFrame') == 2
	assert g.get('v_player', 'obGfx', 2) & 0x67FF == s['ArtTile_MMZ2_TwinWalker']


def switch_debug_placement(g):
	from check_companion_followup import place
	from check_debug_states import press_debug
	from check_object_course import objects
	from check_rising_crushers import seek
	x, y = 0x0710, 0x05DB  # Flat floor beside the authored switch at $0740.
	seek(g, x, y)
	place(g, 'v_player', x, y, False)
	g.write('Debug_mode_flag', 1)
	index, _ = mmz2_debug_entry(g, g.s['SMZ_Button'])
	g.write('Debug_object', index)
	press_debug(g, g.s['DebugType_Placement'])
	g.run(4)
	assert g.get('v_player', 'obMap', 4) == g.s['Map_PlatformButton']
	assert (g.get('v_player', 'obX', 2), g.get('v_player', 'obY', 2)) == (x, y)
	g.buttons = {8}  # C places the selected switch.
	g.run(2)
	g.buttons = set()
	g.run(3)
	switch = next(slot for slot in objects(g, 0xAF) if g.get(slot, 'obX', 2) == x)
	assert g.get(switch, 'obRoutine') == 2 and not g.get(switch, 'respawn_addr', 2)
	assert g.get(switch, 'obY', 2) == y, 'Placed switch moved off its Debug preview'


def transport_game(args):
	from check_companion_followup import place
	from check_object_course import boot_level
	from check_rising_crushers import ACTORS, seek
	from genesis_test_core import Genesis
	from object_layout import decode
	g = Genesis(args.core, args.rom, args.listing, args.output/'transport', args.pal,
		system_directory=args.system_directory)
	initial = g.save()
	s = g.s
	slots = range(s['v_lvlobjspace'] & 0xFFFF, s['v_lvlobjend'] & 0xFFFF, s['object_size'])
	placements = decode((ROOT/'level/objects/LV0F_2.bin').read_bytes())
	routes = (ROOT/'level/objects/MMZ2 Tunnel Paths.bin').read_bytes()[2:]
	report = []

	def visit(x, y, label):
		g.restore(level)
		g.buttons, g.buttons2 = set(), set()
		seek(g, x, max(y, 132))
		slot = next(slot for slot in slots if g.get(slot, 'code') == s[label]
			and g.get(slot, 'obX', 2) == x and g.get(slot, 'obY', 2) == y)
		return slot, g.save()

	def packet(actor, pipe):
		return pipe + s['objoff_30'] + ACTORS.index(actor)*s['smz_pipe_packet']

	def ride(pipe, actor, route, x, y, case):
		if route:
			entry = struct.unpack_from('>H', routes, route*2)[0]
			length = struct.unpack_from('>H', routes, entry)[0]
			waypoints = ((x, y), *struct.iter_unpack('>hh', routes[entry+2:entry+2+length]))
			exit_x, exit_y = waypoints[-1]
			ticks = sum(1+max(abs(bx-ax),abs(by-ay))//16
				for (ax,ay),(bx,by) in zip(waypoints,waypoints[1:]))
		else:
			ticks = 4
			assert g.read(packet(actor, pipe)) == 3, case
			exit_x, exit_y = x+(16 if actor == ACTORS[0] else -16), y
			g.buttons, g.buttons2 = ({7}, {0}) if actor == ACTORS[0] else (set(), {6})
		for _ in range(ticks*3+16):
			assert g.get(actor, 'obRoutine') == 2 and g.get(actor, 'obControl') == 0x81, case
			g.run()
			if not g.read(packet(actor, pipe)):
				break
		else:
			raise AssertionError(('no pipe exit', case))
		assert g.get(actor, 'obRoutine') == 2, case
		control = g.get(actor, 'obControl')
		current = g.get(actor, 'obX', 2), g.get(actor, 'obY', 2)
		if control:
			# A later slot can catch the rider on the same frame.
			next_pipe = next((slot for slot in slots if slot != pipe
				and g.get(slot, 'code') == s['SMZ_Teleport_Main'] and g.read(packet(actor, slot))), None)
			assert control == 0x81 and next_pipe, (case, control, current)
			assert current == (g.get(next_pipe, 'obX', 2), g.get(next_pipe, 'obY', 2)), case
			assert abs(current[0]-exit_x) <= 16 and abs(current[1]-(exit_y & 0x7FF)) <= 16, case
		else:
			assert current == (exit_x, exit_y & 0x7FF), (case, current)

	def enter(pipe, scene, actor, route, x, y, hurt):
		g.restore(scene)
		g.buttons, g.buttons2 = set(), {0}
		place(g, actor, x, y)
		if hurt:
			g.put(actor, 'obRoutine', 4)
			g.put(actor, 'obAnim', s['AniIDSonAni_Hurt'])
			g.put(actor, 'obVelX', 0x200, 2)
			g.put(actor, 'obVelY', -0x400, 2)
		case = title, hex(x), hex(y), actor, 'hurt' if hurt else 'normal'
		for _ in range(12):
			g.run()
			if g.read(packet(actor, pipe)):
				break
		else:
			raise AssertionError(('no pipe entry', case))
		if hurt:
			assert g.get(actor, 'flashtime', 2) == s['Player_HurtFlashTime'], case
		ride(pipe, actor, route, x, y, case)

	def fly_to_pipe(x, y, pipe, scene, jump_off):
		sonic, tails = ACTORS
		case = title, 'jump off' if jump_off else 'carrier enters', hex(x), hex(y)
		g.restore(scene)
		g.buttons, g.buttons2 = set(), set()
		cover = next(slot for slot in slots if g.get(slot, 'code') == s['TubeCover_Update']
			and g.get(slot, 'obX', 2) == x and 0 < y-g.get(slot, 'obY', 2) < 32)
		g.write(s['f_switch']+(g.get(cover, 'obSubtype', 2)&15), 1)
		g.run(8)
		assert g.get(cover, 'obFrame') == s['TubeCover_Open'], case
		place(g, sonic, x, y-24)
		place(g, tails, x, y-60)
		g.put(tails, 'tails_flight_flag', 1)
		g.put(tails, 'tails_flight_energy', s['Tails_FlightBudget'])
		g.put(tails, 'obVelY', 0x100, 2)
		g.buttons, g.buttons2 = set(), {4}
		carried_into_range = carrier_entered = False
		for _ in range(64):
			g.run()
			if g.read('Flying_carrying_Sonic_flag'):
				in_range = -16 <= g.get(sonic, 'obY', 2)-y < 16
				carried_into_range |= in_range
				carrier_entered |= bool(g.read(packet(tails, pipe)))
				assert not g.read(packet(sonic, pipe)) and g.get(sonic, 'obControl') == 3, case
				if jump_off and in_range:
					g.buttons = {0}
			if g.read(packet(sonic, pipe)):
				break
		else:
			raise AssertionError(('no carry handoff', case))
		assert carried_into_range and carrier_entered != jump_off, case
		assert not g.read('Flying_carrying_Sonic_flag'), case
		g.buttons = set()
		route = g.get(pipe, 'obSubtype', 2) & 63
		ride(pipe, sonic, route, x, y, case)
		for _ in range(64):
			if not g.read(packet(tails, pipe)):
				break
			g.run()
		assert not g.read(packet(tails, pipe)) and g.get(tails, 'obControl') == 0, case

	for era, (_, title, _) in enumerate(ERAS):
		g.restore(initial)
		g.buttons, g.buttons2 = set(), set()
		boot_level(g, zone=15, act=1, timezone=era)
		level = g.save()
		mask = (0x40, 0x20, 0x80, 0x80)[era]
		doors = pipes = junctions = switches = 0
		for x, y, oid, presence, subtype in placements:
			if not presence & mask:
				continue
			if oid == 0x0A and subtype == 0x300:
				door, scene = visit(x, y, 'CollisionSwitcher_Run')
				for actor in ACTORS:
					for path in (0, 1):
						g.restore(scene)
						g.buttons, g.buttons2 = set(), {4}
						place(g, actor, x-2, y+78-g.get(actor, 'default_y_radius'))
						g.put(actor, 'obVelY', 0x100, 2)
						g.put(actor, 'obTopSolidBit', 0xC0D+path*0x202, 2)
						for _ in range(12):
							g.run()
							if g.get(actor, 'obTopSolidBit') == 0xE-2*path:
								break
						else:
							raise AssertionError((title, 'door', x, y, actor, path))
						assert g.get(door, 'switch_turn') and g.get(actor, 'obGfx', 2) >> 15 == path
				doors += 1
			elif oid == 0xAB:
				pipe, scene = visit(x, y, 'SMZ_Teleport_Main')
				route = subtype & 63
				for actor in ACTORS:
					for hurt in (False, True):
						enter(pipe, scene, actor, route, x, y, hurt)
				pipes += int(bool(route))
				junctions += int(not route)
			elif oid == 0xAF:
				switch, _ = visit(x, y, 'SMZ_Button')
				assert g.get(switch, 'obSubtype', 2) == subtype
				switches += 1
		x, y, _, _, subtype = next(row for row in placements if row[2] == 0x30 and row[4] & 0x100
			and row[3] & mask)
		cover, scene = visit(x, y, 'TubeCover_Update')
		assert g.get(cover, 'obFrame') == s['TubeCover_Closed']
		g.write(s['f_switch']+(subtype & 15), 1)
		g.run(8)
		assert g.get(cover, 'obFrame') == s['TubeCover_Open']
		g.restore(scene)
		place(g, ACTORS[0], x, y+32)
		g.put(ACTORS[0], 'obControl', 1)
		g.put(ACTORS[0], 'obVelY', 0xFC00, 2)
		g.run(8)
		assert g.get(cover, 'obFrame') == s['TubeCover_Open']
		assert not g.read('v_errortype')
		hatch = [x, y]
		x, y = 0x1880, 0x02D0
		pipe, scene = visit(x, y, 'SMZ_Teleport_Main')
		for jump_off in (True, False):
			fly_to_pipe(x, y, pipe, scene, jump_off)

		g.restore(level)
		g.buttons, g.buttons2 = set(), set()
		ride_twin_walker(g, era, args.output/'transport')
		g.restore(level)
		g.buttons, g.buttons2 = set(), set()
		spike_crusher_game(g, era, args.output/'transport')
		if era == 0:
			g.restore(level)
			g.buttons, g.buttons2 = set(), set()
			twin_debug_preview(g)
			g.restore(level)
			switch_debug_placement(g)
		g.restore(initial)
		g.buttons, g.buttons2 = set(), set()
		boot_level(g, player=s['PlayerMode_Tails'], zone=15, act=1, timezone=era)
		level = g.save()
		pipe, scene = visit(x, y, 'SMZ_Teleport_Main')
		assert g.get(ACTORS[0], 'character_id') == s['CharacterID_Tails']
		enter(pipe, scene, ACTORS[0], g.get(pipe, 'obSubtype', 2) & 63, x, y, True)
		assert not g.read('v_errortype')
		print(f'MMZ2 {title}: normal and hurt riders, solo Tails, carry handoffs, doors, covers and switches passed.', flush=True)
		report.append(dict(era=title, doors=doors, pipes=pipes, junctions=junctions, switches=switches,
			hatch=hatch, hurt_entries=(pipes+junctions)*2+1, carry_handoffs=2, twin_walker=True, spike_crusher=True))
	g.close()
	return report


def size_laser_native(args):
	from native_test_core import UC_M68K_REG_D0
	from level_layout import encode
	n = Native(args.rom, args.listing)
	s = n.s
	n.start()
	n.resident_terrain = True
	roof = 0x180
	layout = encode([[int(y == 2)]*8 for y in range(8)], [[0]])
	n.sub.mem_write(s['MCD_TerrainLayout_Sub'], layout)
	n.sub.mem_write(s['MCD_ChunkTable_SubStart']+128, (0xF001).to_bytes(2, 'big')*64)
	n.cpu.mem_write(0x3E0000, bytes([255])*(s['MCD_TerrainIndexCapacity']+1))
	n.write('v_colladdr1', 0x3E0000, 4)
	n.write('v_colladdr2', 0x3E0001, 4)
	dma = s['VDP_Command_Buffer'] & 0xFFFF
	full = s['VDP_Command_Buffer_Slot'] & 0xFFFF
	for actor, name in (('v_player', 'Sonic'), ('v_player2', 'Tails')):
		tails = name == 'Tails'
		stand = s['tails_height' if tails else 'sonic_height']
		for field, value, size in (
				('character_id', int(tails), 1), ('obMap', s['Map_'+name], 4),
				('obFrame', 1, 1), ('obHeight', stand, 1), ('default_y_radius', stand, 1),
				('obX', 600, 2), ('obY', roof+48-stand, 2)):
			n.put(actor, field, value, size)
		n.write('VDP_Command_Buffer_Slot', full, 2)
		n.act('Player_ChangeSize', actor, regs={UC_M68K_REG_D0: 1})
		assert n.get(actor, 'obHeight') == stand and n.get(actor, 'obMap', 4) == s['Map_'+name]
		n.write('VDP_Command_Buffer_Slot', dma, 2)
		n.act('Player_ChangeSize', actor, regs={UC_M68K_REG_D0: 1})
		assert n.get(actor, 'obHeight', 2) == 0x0A05 and n.get(actor, 'obMap', 4) == s['Map_Mini'+name]
		assert n.get(actor, 'obY', 2) + n.get(actor, 'obHeight') == roof+48
		n.act('Player_EnterRoll', actor)
		assert n.get(actor, 'obHeight', 2) == 0x0805
		assert n.get(actor, 'obY', 2) + n.get(actor, 'obHeight') == roof+48
		for path in range(2):
			n.put(actor,'obTopSolidBit',0xC0D+path*0x202,2)
			n.put(actor,'obY',roof+24-8,2)
			n.write('VDP_Command_Buffer_Slot', dma, 2)
			n.act('Player_ChangeSize', actor, regs={UC_M68K_REG_D0: 0})
			assert n.get(actor, 'default_y_radius') == 10, (actor,path,'grew into the roof')
		n.put(actor,'obY',roof+48-8,2)
		n.act('Player_ChangeSize', actor, regs={UC_M68K_REG_D0: 0})
		assert n.get(actor, 'obHeight') == stand and n.get(actor, 'obY', 2)+stand == roof+48

	# Save a mixed-size pair through the actual checkpoint and time-warp writers.
	n.write('VDP_Command_Buffer_Slot', dma, 2)
	n.act('Player_ChangeSize', 'v_player2', regs={UC_M68K_REG_D0: 1})
	n.put(s['v_lvlobjspace'],'obSubtype',1)
	n.act('Lamppost_StoreInfo', s['v_lvlobjspace'])
	assert n.read('v_lamp_size_flags') == 2
	n.put('v_player2','default_y_radius',s['tails_height'])
	n.act('Player_RestoreSize','v_player2')
	assert n.get('v_player2','default_y_radius') == 10
	n.write('f_timecount',1)
	n.write('TimeWarp_Direction',1)
	n.write('TimeWarp_Frames',s['TimeWarp_CommitFrames']-1)
	n.put('v_player','obInertia',0x700,2)
	n.act('TimeWarp_Tick')
	assert n.read('TimeWarp_Target') == 4 and n.read('TimeWarp_SizeFlags') == 2
	n.put('v_player2', 'default_y_radius', s['tails_height'])
	n.put('v_player2', 'obMap', s['Map_Tails'], 4)
	n.act('Player_RestoreSize', 'v_player2')
	assert n.get('v_player2','default_y_radius') == 10 and n.get('v_player','default_y_radius') == 19
	return dict(queue_retry=True, two_player_sizes=True, roof_both_paths=True, checkpoint_and_warp=True)


def size_laser_game(args):
	from genesis_test_core import Genesis
	from check_companion_followup import place
	from check_object_course import boot_level
	from check_rising_crushers import hold, seek
	from object_layout import decode
	g = Genesis(args.core,args.rom,args.listing,args.output/'size-lasers',args.pal,
		system_directory=args.system_directory)
	s = g.s
	pool = range(s['v_lvlobjspace']&0xFFFF,s['v_lvlobjend']&0xFFFF,s['object_size'])
	layout = decode((ROOT/'level/objects/LV0F_2.bin').read_bytes())
	emitters = [(x,y,flags,kind) for x,y,oid,flags,kind in layout if oid == 0xBF]
	floors = {0x1830:0x2E0, 0x19A8:0x3E0, 0x19B8:0x0E0, 0x1B79:0x5C0, 0x1D48:0x500}
	initial = g.save()
	placed = 0
	for era, mask in enumerate((0x40,0x20,0x80,0x80)):
		g.restore(initial)
		boot_level(g,zone=15,act=1,timezone=era)
		level = g.save()
		for x,y,flags,kind in emitters:
			if not flags & mask:
				continue
			g.restore(level)
			seek(g,x,max(y,132))
			root = next(a for a in pool if g.get(a,'code') == s['MMZ_Laser'] and g.get(a,'obX',2) == x)
			assert g.get(root,'obSubtype',2) == kind and g.get(root,'obFrame') == kind+1
			states, impact, sparks = set(), set(), set()
			gap_seen = False
			for _ in range(90):
				g.run()
				travelling = []
				for a in pool:
					if g.get(a,'obX',2) != x:
						continue
					code = g.get(a,'code')
					tip = g.get(a,'obY',2)+4
					if code == s['MMZ_LaserSpark']:
						sparks.add(tip)
						assert g.get(a,'obPriority',2) > g.get(root,'obPriority',2)
					if code != s['MMZ_LaserPulse']:
						continue
					assert g.get(a,'obPriority',2) > g.get(root,'obPriority',2)
					state = g.get(a,'obRoutine')
					states.add(state)
					if state == 2:
						impact.add(g.get(a,'laser_impact_y',2)+4)
						assert tip <= floors[x]
					elif g.get(a,'obFrame') >= 5:
						travelling.append((tip-(g.get(a,'obAnim')+1)*16,tip))
				travelling.sort()
				for upper, lower in zip(travelling, travelling[1:]):
					# A new slot can get its first update on this frame or the next.
					assert lower[0]-upper[1] >= 4, (era,x,travelling)
					gap_seen = True
			assert states == {0,2}, (era,x,y,states)
			assert impact == sparks == {floors[x]}, (era,x,impact,sparks)
			if x == 0x19B8:
				assert gap_seen, (era,x,'no separated travelling pulses')
			placed += 1
	assert placed == 18 and len(emitters) == 5

	for player, actor in ((0,'v_player'),(0,'v_player2'),(2,'v_player')):
		g.restore(initial)
		g.buttons, g.buttons2 = set(), set()
		boot_level(g,zone=15,act=1,player=player)
		other = 'v_player2' if actor == 'v_player' else 'v_player'
		height = g.get(actor,'default_y_radius')
		other_height = g.get(other,'default_y_radius')
		for x,y,shrink in ((0x1B79,0x587,True),(0x1830,0x288,False)):
			seek(g,x,y)
			stage = g.save()
			place(g,actor,x,(y&~15)+22)
			hold(g,actor)
			g.put(actor,'obStatusSecondary',2)
			g.put(actor,'invtime',600,2)
			g.write('v_rings',42,2)
			expected = 10 if shrink else height
			for _ in range(45):
				g.run()
				assert not g.read('v_errortype')
				if g.get(actor,'default_y_radius') == expected:
					break
			else:
				raise AssertionError((player,actor,x,y,'no transformation'))
			assert g.get(actor,'obRoutine') == 4 and g.read('v_rings',2) == 42
			assert g.get(other,'default_y_radius') == other_height
			name = 'Tails' if player == 2 or actor == 'v_player2' else 'Sonic'
			prefix = 'Mini' if shrink else ''
			assert g.get(actor,'obMap',4) == s['Map_'+prefix+name]
			if shrink:
				g.run(5)
				g.video.save(args.output/'size-lasers'/f'{player}-{actor}-mini.png')
				frame = g.read(name+'_LastLoadedDPLC')
				address = s['Mini'+name+'DynPLC']
				cue = address + struct.unpack_from('>H',g.rom,address+frame*2)[0]
				count, run = struct.unpack_from('>HH',g.rom,cue)
				assert count == 1
				start = s['Art_Mini'+name]+(run&0xFFF)*32
				bank = s['ArtTile_'+name]*32
				length = ((run>>12)+1)*32
				assert bytes(g.vram[(bank+i)^1] for i in range(length)) == g.rom[start:start+length]
				mini = g.save()
				# Approach the authored 24-pixel tunnel on its real terrain.
				for state, small in ((stage,False),(mini,True)):
					g.restore(state)
					place(g,actor,0x1BA8,0x57F-g.get(actor,'default_y_radius'),False)
					g.put(actor,'obVelX',0x300,2)
					g.put(actor,'obInertia',0x300,2)
					hold(g,actor,7)
					g.run(40)
					x = g.get(actor,'obX',2)
					assert (x >= 0x1C20 if small else x < 0x1BC0), (player,actor,small,x)
				# Charge inside the same low passage in either direction. Every
				# frame uses normal input and must retain the compact hitbox.
				for direction in (-1, 1):
					g.restore(mini)
					x = 0x1C08 if direction < 0 else 0x1BC8
					place(g,actor,x,0x57F-g.get(actor,'default_y_radius'),False)
					g.put(actor,'obAngle',0)
					g.put(actor,'obStatus',int(direction < 0))
					hold(g,actor,5)
					g.run(4)
					hold(g,actor,5,0)
					g.run(2)
					hold(g,actor,5)
					g.run(4)
					assert g.get(actor,'spindash_flag') == 1, (player,actor,direction,'no charge')
					hold(g,actor)
					for _ in range(10):
						g.run()
						assert not g.read('v_errortype') and g.get(actor,'obRoutine') == 2
						assert g.get(actor,'obHeight',2) == 0x0805
					assert (g.get(actor,'obX',2)-x)*direction > 48, (player,actor,direction,'stalled spindash')
					g.video.save(args.output/'size-lasers'/f'{player}-{actor}-spindash-{direction}.png')
				g.restore(mini)
	g.close()
	print('Size lasers: five authored emitters and independent Sonic/Tails forms passed.',flush=True)
	return dict(placements=placed,sonic=True,solo_tails=True,companion_tails=True,mini_art=True,low_tunnel=True,two_way_mini_spindash=True)


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin');p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst');p.add_argument('--source',type=Path,required=True)
	p.add_argument('--output',type=Path,required=True);p.add_argument('--core',type=Path);p.add_argument('--system-directory',type=Path);p.add_argument('--pal',action='store_true');a=p.parse_args()
	a.output.mkdir(parents=True,exist_ok=True)
	report={'native':native(a),'twin_walker':twin_allocation(a),'spike_crusher':spike_crusher_native(a),'source_geometry':source_geometry(a),'animations':animation_checks(a,2)}
	report['size_laser']=size_laser_native(a)
	if a.core:
		report['game']=game(a)
		report['transport']=transport_game(a)
		report['size_laser_game']=size_laser_game(a)
	(a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))


if __name__=='__main__':main()
