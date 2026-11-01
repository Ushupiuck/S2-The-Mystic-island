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
	previous = before
	for tick in range(60):
		n.act('PalCycle_Load')
		n.act('Animate_Tiles')
		current = bytes(n.cpu.mem_read(base, 128))
		for i in range(64):
			if i not in (49,51,54):
				assert current[i*2:i*2+2] == before[i*2:i*2+2], ('Static color changed', i)
		cycle.add(tuple(struct.unpack_from('>H', current, i*2)[0] for i in (49,51,54)))
		if current != previous:
			changes.append(tick)
		previous = current
		for source, dest, length in n.uploads:
			if dest & 65535 == n.s['ArtTile_EHZ2_BGWaterfall'] * 32:
				assert length == 11 * 16
				poses.add((source - n.s['Art_EHZ2BGWaterfall']) // (11 * 32))
		n.uploads.clear()
	assert len(cycle) == 3 and poses == {0,1,2}, (cycle, poses)
	assert all(b-a == 9 for a,b in zip(changes,changes[1:])), changes
	return {'palette_phases':len(cycle), 'tile_poses':sorted(poses), 'palette_updates':changes}


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


def live(args):
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	g = Genesis(args.core, args.rom, args.listing, args.output / 'live',
				system_directory=args.system_directory)
	boot_level(g, zone=3, act=1, player=0)
	bank = (ROOT / 'art/uncompressed/EHZ2 Background Waterfall.unc').read_bytes()
	poses = [bank[i:i+352] for i in range(0,len(bank),352)]
	seen, phases, pictures = set(), set(), []
	for tick in range(90):
		g.run()
		assert not g.read('v_errortype')
		base = g.s['ArtTile_EHZ2_BGWaterfall'] * 32
		actual = bytes(g.vram[(base+i)^1] for i in range(352))
		assert actual in poses, ('Incomplete live waterfall pose', tick)
		seen.add(poses.index(actual))
		phases.add(tuple(g.read(g.s['v_palette']+i*2,2) for i in (49,51,54)))
		pictures.append(g.video.copy())
	assert seen == {0,1,2} and len(phases) == 3
	pictures[0].save(args.output / 'EHZ2-waterfalls.webp', save_all=True,
					append_images=pictures[1:],duration=17,loop=0,lossless=True)
	g.close()
	return {'frames':90,'tile_poses':sorted(seen),'palette_phases':len(phases)}


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
	p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--before-rom',type=Path)
	p.add_argument('--before-listing',type=Path)
	p.add_argument('--core',type=Path)
	p.add_argument('--system-directory',type=Path)
	p.add_argument('--output',type=Path,required=True)
	args = p.parse_args()
	args.output.mkdir(parents=True,exist_ok=True)
	report = {'exact_baked_pixels':source_colors(),
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
