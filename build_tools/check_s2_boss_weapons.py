#!/usr/bin/env python3
"""Check prepared S2 weapon pixels, compiled mappings and independent MCZ DPLCs.

--core renders an asset gallery through the normal VDP. Positions, phases and
palette are fixtures; these are not implemented boss fights.
"""
from pathlib import Path
import argparse
import json
import struct

from PIL import Image,ImageDraw
from check_boss_shared_art import raster,unpack
from check_ehz_boss import symbols
from check_sprite_assets import frames
from convert_s1_ss_background import kosinski_plus_decode
from import_s2_boss_weapons import BOSSES,MCZ_DRILL_FRAMES,source_boss,extras,scanlines

ROOT = Path(__file__).resolve().parents[1]


def reference_row(pieces):
	bank,row = bytearray(),[]
	for x,y,w,h,raw,xf,yf,pal,pri in pieces:
		row.append((y,((w-1)<<2)|(h-1),len(bank)//32|(xf<<11)|(yf<<12)|(pal<<13)|(pri<<15),x))
		bank.extend(raw)
	return row,bytes(bank)


def drill_cache(rom,s,phase):
	raw = kosinski_plus_decode(rom[s['Kos_MCZBossDrills']:])[0]
	base = s['DPLC_MCZBoss_Drills']
	pointer = base+struct.unpack_from('>h',rom,base+phase*2)[0]
	count = struct.unpack_from('>H',rom,pointer)[0]
	result = bytearray()
	for i in range(count):
		word = struct.unpack_from('>H',rom,pointer+2+i*2)[0]
		start,length = (word&4095)*32,((word>>12)+1)*32
		assert start+length<=len(raw)
		result.extend(raw[start:start+length])
	assert 0<len(result)<=s['MCZBoss_DrillSlotTiles']*32
	return bytes(result)


def weapon_bank(rom,s,zone,frame):
	bank = unpack(rom,s[f'Kospm_{zone}BossWeapons'])
	if zone=='MCZ':
		width = s['MCZBoss_DrillSlotTiles']*32
		slots = [bytes(width),bytes(width)]
		if frame in MCZ_DRILL_FRAMES:
			cache = drill_cache(rom,s,MCZ_DRILL_FRAMES.index(frame))
			slots[0] = cache+bytes(width-len(cache))
		elif 21<=frame<28:
			cache = drill_cache(rom,s,frame-21)
			slots[1] = cache+bytes(width-len(cache))
		bank += b''.join(slots)
	return bank


def asset_cases(a,rom,s):
	result = []
	for zone in BOSSES:
		original,families = source_boss(a.source,zone)
		for family,rows in families.items():
			if zone=='MCZ' and family=='Weapons':
				rows += [rows[i] for i in MCZ_DRILL_FRAMES]
			label = f'Map_{zone}Boss_{family}'
			adapted = frames(rom,s[label])
			assert len(adapted)==len(rows),(label,len(adapted),len(rows))
			for i,(old,new) in enumerate(zip(rows,adapted)):
				previous,source = reference_row(old)
				bank = weapon_bank(rom,s,zone,i)
				assert raster(new,[(0,bank)])==raster(previous,[(0,source)]),(zone,family,i,'pixels changed')
				assert len(new)<=len(previous)+2
				oldc,oldw = scanlines(previous)
				newc,neww = scanlines(new)
				assert all(n<=o+1 and nw<=ow for n,o,nw,ow in zip(newc,oldc,neww,oldw)),(label,i,'sprite budget')
				assert all((word&2047)+((size>>2)+1)*((size&3)+1)<=len(bank)//32 for y,size,word,x in new)
				result.append((zone,family,i,label,new,bank,1 if zone=='CPZ' else 0))
		extra = extras(a.source,zone)
		if extra:
			name,family,raw,rows = extra
			label = f'Map_{zone}Boss_{family}'
			assert unpack(rom,s[f'Kospm_{zone}Boss{family}'])==raw
			adapted = frames(rom,s[label])
			assert adapted==rows
			result += [(zone,family,i,label,row,raw,1 if zone=='CPZ' else 0) for i,row in enumerate(rows)]
		count = s[f'{zone}Boss_WeaponTiles']
		assert s['ArtTile_BossWeapons']==0x434 and 0<count<=s['ArtTile_Prison_Capsule']-0x434
		if zone!='MCZ':
			assert len(unpack(rom,s[f'Kospm_{zone}BossWeapons']))==count*32
		else:
			assert count==s['MCZBoss_StaticTiles']+2*s['MCZBoss_DrillSlotTiles']
			assert len(unpack(rom,s['Kospm_MCZBossWeapons']))==s['MCZBoss_StaticTiles']*32
			assert list(rom[s['MCZBoss_DrillFramesA']:s['MCZBoss_DrillFramesA']+7])==list(MCZ_DRILL_FRAMES)
			assert list(rom[s['MCZBoss_DrillFramesB']:s['MCZBoss_DrillFramesB']+7])==list(range(21,28))
	assert not any('BossWeapons' in line or 'MCZBossDrills' in line for line in (ROOT/'_inc/Pattern Load Cues.asm').read_text().splitlines())
	return result


def native_drills(a,rom,s):
	from native_test_core import Native,UC_M68K_REG_D0,UC_M68K_REG_D4,UC_M68K_REG_D6,UC_M68K_REG_A0,UC_M68K_REG_A1,UC_M68K_REG_A2,UC_M68K_REG_A3
	m = Native(a.rom,a.listing);m.start()
	source = s['Free_RAM_Start']&0xFFFFFF
	m.act('KosPlusDec',regs={UC_M68K_REG_A0:s['Kos_MCZBossDrills'],UC_M68K_REG_A1:source})
	raw = (ROOT/'art/uncompressed/MCZ boss drills.unc').read_bytes()
	assert bytes(m.cpu.mem_read(source,len(raw)))==raw
	width = s['MCZBoss_DrillSlotTiles']*32
	objects = [s['v_lvlobjspace'],s['v_lvlobjspace']+s['object_size']]
	for obj in objects:
		m.put(obj,'objoff_2E',255)
	bank = bytearray(width*2)
	for left in range(7):
		for right in range(7):
			for obj in objects:m.put(obj,'objoff_2E',255)
			m.write('VDP_Command_Buffer_Slot',s['VDP_Command_Buffer']&65535,2)
			for slot,phase in enumerate((left,right)):
				m.uploads.clear()
				base = (s['ArtTile_BossWeapons']+s['MCZBoss_StaticTiles'])*32+slot*width
				m.act('Load_DynamicPLC',regs={UC_M68K_REG_D0:phase,UC_M68K_REG_A2:s['DPLC_MCZBoss_Drills'],
					UC_M68K_REG_A3:objects[slot]+s['objoff_2E'],UC_M68K_REG_D4:base,UC_M68K_REG_D6:source})
				assert m.get(objects[slot],'objoff_2E')==phase
				for start,dest,words in m.uploads:
					dest,words = dest&65535,words&65535
					offset = dest-base+slot*width
					bank[offset:offset+words*2] = m.cpu.mem_read(start&0xFFFFFF,words*2)
				# The native DMA boundary is stubbed; retain actual queue use
				# between the two loads so both six-run phases must fit together.
				m.write('VDP_Command_Buffer_Slot',(m.read('VDP_Command_Buffer_Slot',2)+len(m.uploads)*s['DMAEntry.len'])&65535,2)
				assert bank[slot*width:slot*width+len(drill_cache(rom,s,phase))]==drill_cache(rom,s,phase)
				m.uploads.clear()
				m.act('Load_DynamicPLC',regs={UC_M68K_REG_D0:phase,UC_M68K_REG_A2:s['DPLC_MCZBoss_Drills'],
					UC_M68K_REG_A3:objects[slot]+s['objoff_2E'],UC_M68K_REG_D4:base,UC_M68K_REG_D6:source})
				assert not m.uploads,'An unchanged drill phase queued art'
			assert bytes(m.cpu.mem_read(source,len(raw)))==raw
	for slot,phase in enumerate((0,6)):
		m.put(objects[slot],'objoff_2E',255);m.uploads.clear()
		m.write('VDP_Command_Buffer_Slot',s['VDP_Command_Buffer_Slot']&65535,2)
		m.act('Load_DynamicPLC',regs={UC_M68K_REG_D0:phase,UC_M68K_REG_A2:s['DPLC_MCZBoss_Drills'],
			UC_M68K_REG_A3:objects[slot]+s['objoff_2E'],UC_M68K_REG_D4:0x8680,UC_M68K_REG_D6:source})
		assert not m.uploads and m.get(objects[slot],'objoff_2E')==255,'Full queue accepted a partial drill phase'
	return 'actual CD codec and generic DPLC loader: all 49 independent drill-phase pairs, immutable source, cached phases and full-queue rejection'


def gallery(a,rom,s,cases):
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_companion_followup import isolate,spawn
	g = Genesis(a.core,a.rom,a.listing,a.output,a.pal,system_directory=a.system_directory)
	boot_level(g,zone=0,act=0)
	isolate(g)
	for player in ('v_player','v_player2'):
		g.put(player,'code',0)
	camx,camy = g.read('Camera_X_pos',2),g.read('Camera_Y_pos',2)
	for name,value in (('Camera_Min_X_pos',camx),('Camera_Max_X_pos',camx),('Camera_Max_X_pos_target',camx),
		('Camera_Min_Y_pos',camy),('Camera_Max_Y_pos',camy),('Camera_Max_Y_pos_target',camy)):
		g.write(name,value,2)
	g.write('Dynamic_Resize_Routine',0);g.write('f_timecount',0)
	g.run(4)
	for base in (s['vram_fg'],s['vram_bg']):
		for i in range(0x1000):g.vram[(base+i)^1]=0
	actor = spawn(g,'DisplaySprite',camx+160,camy+112)
	# A fixture actor queues the raw cache through the real DMA path. Writing
	# emulator VRAM directly would bypass VDP pattern-cache invalidation.
	fixture = s['Free_RAM_Start']&0xFFFFFF
	uploader = spawn(g,'DisplaySprite',0,0)
	g.put(uploader,'code',fixture,4)
	for name,value,size in (('obPriority',0x180,2),('width_pixels',128,1),('height_pixels',112,1)):
		g.put(actor,name,value,size)
	images = [];checked = 0
	for zone,family,index,label,row,bank,palette_base in cases:
		palette = (ROOT/'palette/SonicAndTails.bin').read_bytes()+(ROOT/f'palette/{zone} Boss Weapons.bin').read_bytes()
		for offset,value in enumerate(palette):g.write(s['v_palette']+offset,value)
		# Test setup installs the independently checked cache image. These are
		# mapping/color fixtures; the live boss controllers are deliberately absent.
		program = struct.pack('>HIHHHHHI',0x223C,fixture+32,0x343C,0x8680,0x363C,len(bank)//2,0x4EF9,s['QueueDMATransfer'])
		for offset,value in enumerate(program+bytes(32-len(program))+bank):g.write(fixture+offset,value)
		g.put(actor,'obMap',s[label],4);g.put(actor,'obFrame',index)
		g.put(actor,'obGfx',s['ArtTile_BossWeapons']|(palette_base<<13),2)
		for flip in range(4):
			g.put(actor,'obRender',4|flip);g.put(actor,'obStatus',flip)
			# Disable normal level palette cycling for this isolated asset scene.
			g.write('Current_Zone',s['id_LZ'])
			g.run(3)
			assert not g.read('v_errortype')
			for (x,y),(line,color) in raster(row,[(0,bank)]).items():
				word = int.from_bytes(palette[((line+palette_base)&3)*32+color*2:((line+palette_base)&3)*32+color*2+2],'big')
				if 'ClownMDEmu' in g.emulator:word |= (word&0x888)>>3
				r,green,b = (word>>shift&15 for shift in (0,4,8))
				rgb = (((r<<1)|(r>>3))*255//31,((green<<2)|(green>>2))*255//63,((b<<1)|(b>>3))*255//31)
				point = (160+(-x-1 if flip&1 else x),112+(-y-1 if flip&2 else y))
				assert g.video.getpixel(point)==rgb,(zone,family,index,flip,point,g.video.getpixel(point),rgb)
				checked+=1
			if flip==0 and row:
				images.append((f'{zone} {family} {index}',g.video.copy()))
			if index==0 and flip in (0,1):g.video.save(a.output/f'{zone}-{family}-flip{flip}.png')
	g.close()
	columns = 5;cellw,cellh = 160,132
	sheet = Image.new('RGB',(columns*cellw,((len(images)+columns-1)//columns)*cellh),(28,32,40))
	draw = ImageDraw.Draw(sheet)
	for i,(caption,im) in enumerate(images):
		x,y = i%columns*cellw,i//columns*cellh
		sheet.paste(im.resize((160,112),Image.Resampling.NEAREST),(x,y+20))
		draw.text((x+4,y+4),caption,fill='white')
	sheet.save(a.output/'contact.png')
	return f'{len(cases)*4} frame/facing cases and {checked} exact VDP pixel samples'


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--source',type=Path,required=True)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
	p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--output',type=Path,required=True)
	p.add_argument('--core',type=Path)
	p.add_argument('--system-directory',type=Path)
	p.add_argument('--pal',action='store_true')
	a = p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
	rom,s = a.rom.read_bytes(),symbols(a.listing)
	cases = asset_cases(a,rom,s)
	report = [f'{len(cases)} source/compiled mapping frames: exact indexed pixels, valid banks, bounded piece/scanline costs',native_drills(a,rom,s)]
	if a.core:
		report.append(gallery(a,rom,s,cases))
	(a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
	for row in report:print(row+': passed',flush=True)


if __name__=='__main__':
	main()
