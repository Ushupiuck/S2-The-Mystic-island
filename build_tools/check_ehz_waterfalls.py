#!/usr/bin/env python3
"""Check baked PP poses, real palette writes and waterfall SAT pressure.

The native scene uses the authored four-column Act-2 group, separated players,
an approaching snail and 32 rings. Optional before-ROM arguments demonstrate
the former SAT starvation with the same inputs. --core also checks live DMA.
"""
from pathlib import Path
import argparse
import json
import struct
from native_test_core import Native
from build_ehz_reflection_art import reflection_runs, reflection_source

ROOT = Path(__file__).resolve().parents[1]


def sprite_pieces(n):
	count = n.read('v_spritecount')
	raw = n.cpu.mem_read(n.s['Sprite_Table'] & 0xFFFFFF, count * 8)
	return [struct.unpack_from('>4H', raw, i * 8) for i in range(count)]


def pressure_scene(rom, listing):
	n = Native(rom, listing)
	n.start()
	s = n.s
	for suffix in ('', '_copy'):
		n.write('Camera_X_pos' + suffix, 0x1DC0, 2)
		n.write('Camera_Y_pos' + suffix, 0x720, 2)
	n.write('Camera_X_pos_coarse_back', 0x1D00, 2)
	n.write('Level_started_flag', 1)
	n.put('v_player', 'obX', 0x1EE0, 2)
	n.put('v_player2', 'obX', 0x1DE0, 2)
	for i in range(32):
		x, y = 0x1DC0 + 64 + (i % 8) * 24, 0x720 + 32 + (i // 8) * 32
		n.cpu.mem_write((s['Ring_Positions'] & 0xFFFFFF) + i * 6,
						struct.pack('>3H', 0, x, y))
	n.write('Ring_start_addr', s['Ring_Positions'] & 65535, 2)
	n.write('Ring_end_addr', (s['Ring_Positions'] + 32 * 6) & 65535, 2)
	for i, (x, y, subtype) in enumerate(((0x1D60,0x780,0),
			(0x1DE0,0x780,0), (0x1E60,0x780,0),
			(0x1EE0,0x720,0), (0x1EE0,0x7E0,4))):
		a = s['v_lvlobjspace'] + i * s['object_size']
		for field, value, size in (('layout_id',0x49,1), ('obX',x,2),
								('obY',y,2), ('obSubtype',subtype,2)):
			n.put(a, field, value, size)
		n.act('Obj49', a)
	a = s['v_lvlobjspace'] + 5 * s['object_size']
	for field, value, size in (('layout_id',0x54,1), ('obX',0x1EF0,2),
			('obY',0x7B0,2), ('obRender',4,1), ('obPriority',0x200,2),
			('obMap',s['Map_Snailbot'],4), ('obGfx',s['ArtTile_Snail'],2),
			('width_pixels',s['Map_Snailbot_width'],1),
			('height_pixels',s['Map_Snailbot_height'],1)):
		n.put(a, field, value, size)
	n.act('DisplaySprite', a)
	n.act('Render_Sprites')
	pieces = sprite_pieces(n)
	snail = [p for p in pieces if s['ArtTile_Snail'] <= p[2] & 2047 < s['ArtTile_Masher']]
	waterfalls = [p for p in pieces if s['ArtTile_Waterfall'] <= p[2] & 2047 < s['ArtTile_EHZ_Bridge']]
	rings = [p for p in pieces if s['ArtTile_Ring'] <= p[2] & 2047 < s['ArtTile_HUD']]
	assert len(rings) == 32 and waterfalls, (len(rings), len(waterfalls))
	return {'sat_entries': len(pieces), 'snail_pieces': len(snail), 'waterfall_pieces':len(waterfalls)}


def native_animation(rom, listing):
	n = Native(rom, listing)
	n.start()
	n.write('Current_ZoneAndAct', 0x301, 2)
	base = n.s['v_palette'] & 0xFFFFFF
	pal = (ROOT / 'palette/SonicAndTails.bin').read_bytes() + (ROOT / 'palette/EHZ2 PP.bin').read_bytes()
	n.cpu.mem_write(base, pal)
	before = bytes(n.cpu.mem_read(base, 128))
	cycle, poses, changes = set(), set(), []
	foreground, foreground_changes = set(), []
	previous = before
	for tick in range(60):
		n.act('PalCycle_Load')
		n.act('Animate_Tiles')
		current = bytes(n.cpu.mem_read(base, 128))
		for i in range(64):
			if i not in (18,19,20,21,49,51,54):
				assert current[i*2:i*2+2] == before[i*2:i*2+2], ('Static color changed', i)
		cycle.add(tuple(struct.unpack_from('>H', current, i*2)[0] for i in (49,51,54)))
		if any(current[i*2:i*2+2] != previous[i*2:i*2+2] for i in (49,51,54)):
			changes.append(tick)
		foreground.add(tuple(struct.unpack_from('>H',current,i*2)[0] for i in (18,19,20,21)))
		if current[36:44] != previous[36:44]:foreground_changes.append(tick)
		previous = current
		for source, dest, length in n.uploads:
			if dest & 65535 == n.s['ArtTile_EHZ2_BGWaterfall'] * 32:
				assert length == 11 * 16
				poses.add((source - n.s['Art_EHZ2BGWaterfall']) // (11 * 32))
		n.uploads.clear()
	assert len(cycle) == 3 and poses == {0,1,2}, (cycle, poses)
	assert all(b-a == 9 for a,b in zip(changes,changes[1:])), changes
	assert len(foreground)==4 and all(b-a==8 for a,b in zip(foreground_changes,foreground_changes[1:])),foreground_changes
	return {'palette_phases':len(cycle), 'tile_poses':sorted(poses), 'palette_updates':changes,'foreground_phases':len(foreground),'foreground_updates':foreground_changes}


def clipping_comparison(rom, listing, before_rom, before_listing):
	old, new = Native(before_rom,before_listing), Native(rom,listing)
	def visible(n,x,y,flip):
		n.start()
		for name in ('Camera_X_pos_copy','Camera_Y_pos_copy'):
			n.write(name,0x200,2)
		a = n.s['v_lvlobjspace']
		for field,value,size in (('layout_id',0x49,1),('obX',0x200+x,2),
				('obY',0x200+y,2),('obRender',0x14|flip,1),('obFrame',1,1),
				('obMap',n.s['Map_Waterfall1'],4),('obGfx',n.s['ArtTile_Waterfall']|0x2000,2),
				('width_pixels',32,1),('height_pixels',128,1)):
			n.put(a,field,value,size)
		n.act('DisplaySprite',a)
		n.act('Render_Sprites')
		result = []
		for py,sl,tile,px in sprite_pieces(n):
			x,y,size = (px&511)-128,(py&511)-128,sl>>8
			if x < 320 and x+((size>>2)+1)*8 > 0 and y < 224 and y+((size&3)+1)*8 > 0:
				result.append((py&511,size,tile,px&511))
		return result
	count = 0
	for flip in range(4):
		for x in (-32,0,160,320):
			for y in (-128,0,112,224,350):
				assert visible(old,x,y,flip) == visible(new,x,y,flip), (x,y,flip)
				count += 1
	return count


def source_colors():
	from import_ehz2_pp_background import tile_pixels
	source = (ROOT / 'art/uncompressed/EHZ2 Background Waterfall Source.unc').read_bytes()
	frames = (ROOT / 'art/uncompressed/EHZ2 Background Waterfall.unc').read_bytes()
	assert len(source) == 11*32 and len(frames) == 3*len(source)
	pp = (0xA00,0xEEE,0xEEA,0xCC6,0xE64,0x0EE,0x08E,0x06A,
			0x024,0x000,0xEEC,0xEC8,0xE86,0x042,0x0A6,0x064)
	pal = struct.unpack('>48H', (ROOT / 'palette/EHZ2 PP.bin').read_bytes())[16:32]
	for phase, colors in enumerate(((0xEEE,0xEEA,0xCC6),
			(0xCC6,0xEEE,0xEEA),(0xEEA,0xCC6,0xEEE))):
		original = list(pp)
		original[1:4] = colors
		pose = frames[phase*len(source):(phase+1)*len(source)]
		for a,b in zip(tile_pixels(source),tile_pixels(pose)):
			assert (original[a] if a else None) == (pal[b] if b else None), (phase,a,b)
	return 11*64*3


def fixed_reflections(rom,listing):
	from import_ehz2_pp_background import tile_pixels
	n=Native(rom,listing)
	n.start()
	n.write('Current_ZoneAndAct',0x300,2)
	palette=(ROOT/'palette/SonicAndTails.bin').read_bytes()+(ROOT/'palette/EHZ.bin').read_bytes()
	base=n.s['v_palette']&0xFFFFFF
	n.cpu.mem_write(base,palette)
	original=struct.unpack('>64H',palette)
	assert original[18:22]==(0xA86,0xE86,0xEA8,0xECA)
	source=reflection_source()
	expected=[original[16+i] if i else None for i in tile_pixels(source)]
	runs={}
	offset=0
	for dest,count in reflection_runs():
		runs[dest*32]=(offset,count*32)
		offset+=count*32
	poses=set()
	for tick in range(64):
		n.act('PalCycle_Load')
		current=struct.unpack('>64H',n.cpu.mem_read(base,128))
		assert all(current[i]==original[i] for i in range(64) if i not in (18,19,20,21))
		assert not n.uploads or {dest&65535 for _,dest,_ in n.uploads}==runs.keys()
		for address,dest,length in n.uploads:
			offset,size=runs[dest&65535]
			assert length&65535==size//2
			pose=(address-n.s['Art_EHZReflection']-offset)//len(source)
			actual=tile_pixels(n.cpu.mem_read(address,size))
			assert [current[16+i] if i else None for i in actual]==expected[offset*2:(offset+size)*2], ('Reflection pulses',pose)
			poses.add(pose)
		n.uploads.clear()
	assert poses=={0,1,2,3}
	# Palette and both tile spans must wait together when the queue is full.
	before=bytes(n.cpu.mem_read(base,128))
	phase=n.read('v_pcyc_num',2)
	for free in range(3):
		n.write('VDP_Command_Buffer_Slot',(n.s['VDP_Command_Buffer_Slot']-free*n.s['DMAEntry.len'])&65535,2)
		n.write('v_pcyc_time',0,2)
		n.act('PalCycle_Load')
		assert not n.uploads and n.read('v_pcyc_num',2)==phase
		assert bytes(n.cpu.mem_read(base,128))==before
	n.write('VDP_Command_Buffer_Slot',(n.s['VDP_Command_Buffer_Slot']-3*n.s['DMAEntry.len'])&65535,2)
	n.act('PalCycle_Load')
	assert len(n.uploads)==2 and n.read('v_pcyc_num',2)==phase+1
	return {'poses':sorted(poses),'fixed_rgb_pixels':len(source)*2*4,'deferred_queue_cases':3}


def cloud_tiles():
	"""Return actual cloud tile/palette references from the editable PP panel."""
	from level_layout import load
	_, bg = load(ROOT/'level/layout/EHZ_2.kosp')
	chunks = (ROOT/'mappings/128x128/EHZ2.unc').read_bytes()
	blocks = (ROOT/'mappings/16x16/EHZ2.unc').read_bytes()
	refs = set()
	for y in range(0,192,8):
		for x in range(0,512,8):
			cid = bg[y//128][x//128]
			cell = struct.unpack_from('>H',chunks,cid*128+(y//16%8*8+x//16%8)*2)[0]
			bx, by = (x//8%2)^bool(cell&0x400), (y//8%2)^bool(cell&0x800)
			word = struct.unpack_from('>H',blocks,(cell&1023)*8+(by*2+bx)*2)[0]
			refs.add((word&2047,word>>13&3))
	return sorted(refs)


def live(args):
	import ctypes as C
	from import_ehz2_pp_background import tile_pixels
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	g = Genesis(args.core, args.rom, args.listing, args.output / 'live',
				system_directory=args.system_directory)
	boot_level(g, zone=3, act=args.act, player=0)
	name='EHZ2 Background Waterfall.unc' if args.act==1 else 'EHZ Reflections.unc'
	size=352 if args.act==1 else 544
	bank = (ROOT / 'art/uncompressed' / name).read_bytes()
	poses = [bank[i:i+size] for i in range(0,len(bank),size)]
	cram=(C.c_uint16*64).in_dll(g.core,'cram')
	clouds = cloud_tiles() if args.act==1 else []
	cloud_colors = None
	cloud_samples = 0
	if args.act==0:
		original=struct.unpack('>48H',(ROOT/'palette/EHZ.bin').read_bytes())[:16]
		source=reflection_source()
		fixed=[original[i] if i else None for i in tile_pixels(source)]
	seen, phases, pictures = set(), set(), []
	foreground=set()
	for tick in range(90):
		g.run()
		assert not g.read('v_errortype')
		runs=[(g.s['ArtTile_EHZ2_BGWaterfall'],11)] if args.act==1 else reflection_runs()
		actual=b''.join(bytes(g.vram[(base*32+i)^1] for i in range(count*32)) for base,count in runs)
		assert actual in poses, ('Incomplete live waterfall pose', tick)
		if args.act==0:
			colors=[((v&7)<<1)|((v&0x38)<<2)|((v&0x1C0)<<3) for v in cram[16:32]]
			assert [colors[i] if i else None for i in tile_pixels(actual)]==fixed, ('Visible reflection pulses',tick)
		seen.add(poses.index(actual))
		phases.add(tuple(g.read(g.s['v_palette']+i*2,2) for i in ((49,51,54) if args.act==1 else (18,19,20,21))))
		foreground.add(tuple(cram[18:22]))
		if clouds:
			colors = []
			for tile,line in clouds:
				pixels = bytes(g.vram[(tile*32+i)^1] for i in range(32))
				colors.extend(cram[line*16+p] for p in tile_pixels(pixels) if p)
			if cloud_colors is None:
				cloud_colors = colors
			assert colors == cloud_colors, ('Visible PP clouds change color with waterfall cycle',tick)
			cloud_samples += len(colors)
		pictures.append(g.video.copy())
	assert seen == set(range(len(poses))) and len(phases) == len(poses)
	assert len(foreground)==4,('Foreground waterfall is frozen',args.act,foreground)
	pictures[0].save(args.output / f'EHZ{args.act+1}-waterfalls.webp', save_all=True,
					append_images=pictures[1:],duration=17,loop=0,lossless=True)
	g.close()
	return {'frames':90,'tile_poses':sorted(seen),'palette_phases':len(phases),
		'foreground_phases':len(foreground),'fixed_cloud_color_samples':cloud_samples}


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
	p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--before-rom',type=Path)
	p.add_argument('--before-listing',type=Path)
	p.add_argument('--core',type=Path)
	p.add_argument('--system-directory',type=Path)
	p.add_argument('--act',type=int,choices=(0,1),default=1)
	p.add_argument('--output',type=Path,required=True)
	args = p.parse_args()
	args.output.mkdir(parents=True,exist_ok=True)
	report = {'exact_baked_pixels':source_colors(),
			'fixed_reflections':fixed_reflections(args.rom,args.listing),
			'animation':native_animation(args.rom,args.listing),
			'pressure':pressure_scene(args.rom,args.listing)}
	assert report['pressure']['snail_pieces'] == 3, report
	if args.before_rom:
		assert args.before_listing
		report['before_pressure'] = pressure_scene(args.before_rom,args.before_listing)
		assert report['before_pressure']['snail_pieces'] < 3, report
		report['unchanged_visible_mapping_cases'] = clipping_comparison(
				args.rom,args.listing,args.before_rom,args.before_listing)
	if args.core:
		report['live'] = live(args)
	(args.output/'report.json').write_bytes((json.dumps(report,indent=2)+'\n').replace('\n','\r\n').encode())
	print(json.dumps(report,indent=2))


if __name__ == '__main__':
	main()
