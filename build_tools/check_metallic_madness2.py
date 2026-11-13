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
		if era==3:expected.append((n.s['Kospm_MMZ2_TerrainSpill'],n.s['ArtTile_MMZ2_TerrainSpill']*32))
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
		# Check the priority bit separately for both actors and both paths.
		raw=(a.source/f'src/maps/r8/foreground_2{"abcd"[era]}.bin').read_bytes();width=raw[0]+1
		for who in ('v_player','v_player2'):
			for i,c in enumerate(raw[2:]):
				for path in (12,14):
					n.put(who,'obX',(i%width)*256+16,2);n.put(who,'obY',(i//width)*256+16,2)
					n.put(who,'obTopSolidBit',path);n.put(who,'obGfx',0xB456,2);n.act('MMZ2_UpdatePriority')
					assert n.get(who,'obGfx',2)==(0x3456|(0x8000 if c&128 and path==12 else 0)),(era,who,i,path)
					cases+=1
	# Verify the reciprocal shortcut's complete authored camera domain against
	# the original unsigned DIVU quantization, including its far-right edge.
	for x in range(0x1E98):
		delta=x-x*3//16
		assert ((delta*0xAAAB)&0xFFFFE000)>>3==((delta*64)//12)<<10
	return dict(eras=4,header_parallax_priority_cases=cases,reciprocal_domain=7832,max_initial_plcs=15)


def source_geometry(a):
	maps=a.source/'src/maps/r8';cd=read_bank(a.source/'src/maps',('collision_columns.bin','collision_rows.bin','collision_angles.bin'))
	bank=read_bank(ROOT/'collision');bank[0x69]=(bank[0x69][0],bank[0x69][1],0xC8)
	profiles=visuals=0
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
		art=(ROOT/f'art/kosinski/level/8x8 - MMZ2 {title}.unc').read_bytes();spill=(ROOT/'art/uncompressed/MMZ2 Bad Future Spill.unc').read_bytes()
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
						data=spill[(tile-0x553)*32:(tile-0x553+1)*32] if 0x553<=tile<0x560 else art[tile*32:(tile+1)*32]
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
						p=reflect(cd[srcindices[sw&2047]],(sw>>11)&3);q=reflect(bank[indices[(dw&1023)*2+path]],(dw>>10)&3)
						assert profile_equal(p,q),(era,i,by,bx,path,'collision profile/angle')
						profiles+=1
	return dict(authored_block_pixels=visuals,path_profiles=profiles,original_chunks_preserved=True,exact_cd_angles=True)


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
		assert g.read(0x420000+g.s['MCD_TerrainAngles_Sub']+0x69)==0xC8
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
			if era==3:
				spill=(ROOT/'art/uncompressed/MMZ2 Bad Future Spill.unc').read_bytes()
				assert bytes(g.vram[(0x553*32+i)^1] for i in range(len(spill)))==spill
			g.video.save(g.output/f'era{era}-pose{index}.png')
		result.append(dict(era=era,visible_tile_samples=samples,spill_intact=era==3))
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
