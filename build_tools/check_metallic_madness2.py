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
		result.append(dict(era=era,visible_tile_samples=samples,terrain_tiles=(ROOT/f'art/kosinski/level/8x8 - MMZ2 {title}.unc').stat().st_size//32))
	g.close();return result


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin');p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst');p.add_argument('--source',type=Path,required=True)
	p.add_argument('--output',type=Path,required=True);p.add_argument('--core',type=Path);p.add_argument('--system-directory',type=Path);p.add_argument('--pal',action='store_true');a=p.parse_args()
	a.output.mkdir(parents=True,exist_ok=True)
	report={'native':native(a),'source_geometry':source_geometry(a),'animations':animation_checks(a,2)}
	if a.core:report['game']=game(a)
	(a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))


if __name__=='__main__':main()
