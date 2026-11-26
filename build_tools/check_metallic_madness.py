#!/usr/bin/env python3
"""Check Metallic Madness's actual era bindings, parallax and visible tilemaps.

Native cases run the assembled MD hscroll function and CD source provider.
Optional game cases enter zone $0F through level select and compare visible
VDP tiles against authored terrain, including chunk IDs above $FF. Staged
camera visits are rendering fixtures, not a controller-only level playthrough.
"""
from pathlib import Path
import argparse
from configparser import ConfigParser
import ctypes as C
import json
import struct

from convert_s1_ss_background import kosinski_plus_decode
from level_layout import load
from object_layout import legacy_saw_subtype
from native_test_core import Native,UC_M68K_REG_A2,UC_M68K_REG_D4,UC_M68K_REG_D5,UC_M68K_REG_D7

ROOT=Path(__file__).resolve().parents[1]
ERAS=(('Present','Present',''),('Past','Past','past/'),
	('GoodFuture','Good Future','good future/'),('BadFuture','Bad Future','bad future/'))


def rows(past=False):
	if past:
		first=[8]*4+[7]*4+[6]*2+[5]*6+[4]*2+[3]*2+[2]*2+[1]*2+[0]*2
		second=[6]*4+[5]*2+[4]*2+[3]*4+[2]*2+[1]*2+[0]*2
		return first+[9]*4+[10]*28+second+[9]*8+[10]*12
	gradient=[4]*4+[3]*5+[2]*3+[1,0]
	return gradient+[9]*16+[10]*28+gradient+[9]*12+[10]*12


def parallax(x):
	far,near=x//4,x//2
	step=((near-far)*128//5)*512
	return [-((far*65536+i*step)//65536) for i in range(9)]+[-(x*3//16),-near]


def native(args):
	n=Native(args.rom,args.listing);n.start()
	rom=args.rom.read_bytes();cases=0
	for era,(key,title,folder) in enumerate(ERAS):
		n.write('Current_ZoneAndAct',0xF00,2);n.write('Current_Timezone',era)
		n.act('GetLevelArtHeader')
		address=n.cpu.reg_read(UC_M68K_REG_A2)&0xFFFFFF
		parts=struct.unpack_from('>3I',rom,address)
		for part,label in zip(parts,('Kosp_MMZ1_','Map16_MMZ1_','Map128_MMZ1_')):
			assert part&0xFFFFFF==n.s[label+key],(era,label)
		chunks=kosinski_plus_decode(rom[parts[2]&0xFFFFFF:])[0]
		assert len(chunks)==445*128
		assert parts[2]>>24==n.s['palid_MMZ1_'+key]
		# Follow the live header's unsigned IDs and typed PLC index, including
		# the two era overlays; a nearby unused list is not sufficient evidence.
		base=n.s['ArtLoadCues'];flag=n.s['PLCKos_IndexFlag']
		entry=struct.unpack_from('>H',rom,base+(parts[0]>>24)*2)[0]
		assert entry&flag
		plc=base+(entry&~flag)
		expected=[(n.s[label],n.s[tile]*32) for label,tile in (
			('Kospm_MMZ1_Platforms','ArtTile_MMZ_Atlas'),('Kospm_MMZ_CrusherFloor','ArtTile_MMZ_CrusherFloor'),
			('Kospm_MMZ1_SawsSeesawGoodFuture' if era==2 else 'Kospm_MMZ1_SawsSeesaw','ArtTile_MMZ_Saw'),
			('Kospm_MMZ_MechaBu','ArtTile_MMZ_MechaBu'),('Kospm_MMZ1_Enemies','ArtTile_MMZ_Atlas'),
			('Kospm_MMZ_TimePostHeads','ArtTile_TimePostHeads'),
			('Kospm_MMZ_GeneratorPast' if era==1 else 'Kospm_MMZ_Generator','ArtTile_MMZ_Generator'))]
		expected[4]=(expected[4][0],(n.s['ArtTile_MMZ_Atlas']+318)*32)
		count=struct.unpack_from('>h',rom,plc)[0]+1
		assert [struct.unpack_from('>IH',rom,plc+2+i*6) for i in range(count)]==expected,(era,'primary PLC')
		assert parts[1]>>24==n.s['plcid_LVF1_Extra']
		n.act('LoadCollisionIndexes')
		assert n.read('v_colladdr1',4)==n.s['Col_MMZ1_'+key]
		assert n.read('v_colladdr2',4)==n.s['Col_MMZ1_'+key]+1
		selectors=rows(era==1)
		assert len(selectors)==96
		guard=bytes(range(64))
		out=n.s['v_hscrolltablebuffer']&0xFFFFFF
		for x in (0,1,15,16,17,127,128,129,1023,4095,5119,5120,5121,6000,7831):
			for y in (0,1,4,28,31,32,96,447,448,449,896,1023,1024,1471,1600,1808):
				n.write('Camera_X_pos',x,2);n.write('Camera_Y_pos',y,2)
				n.cpu.mem_write(out+0x3A0,guard)
				n.act('Deform_MMZ1')
				actual=list(struct.unpack('>448h',n.cpu.mem_read(out,224*4)))
				values=parallax(x)
				expected=[v for line in range(224) for v in (-x,values[selectors[(y//4+line)//8]])]
				assert actual==expected,(era,x,y,next((i,a,b) for i,(a,b) in enumerate(zip(actual,expected)) if a!=b))
				assert n.cpu.mem_read(out+0x3A0,64)==guard,'Hscroll exceeded its declared padding'
				assert n.read('Camera_BG_X_pos',2)==x*3//16
				assert n.read('Camera_BG_Y_pos',2)==y//4
				cases+=1
		# Execute the CD provider too; it must select flat cameras or fixed
		# pattern rows from the same era without truncating to a 256px period.
		for name,val in (('MCD_TerrainBG_Sub',333),('MCD_TerrainBG2_Sub',888)):
			n.sub.mem_write(n.s[name],struct.pack('>H',val))
		n.sub.mem_write(n.s['MCD_TerrainTimeZone_Sub'],bytes([era]))
		for y in range(-16,769,16):
			n.sub.reg_write(UC_M68K_REG_D4,y&65535)
			n.sub_call('Plane_SourceMMZ1')
			index=selectors[(y%768)//8]
			expected=(333,0) if index==9 else (888,0) if index==10 else (0,1)
			actual=(n.sub.reg_read(UC_M68K_REG_D5)&65535,n.sub.reg_read(UC_M68K_REG_D7)&65535)
			assert actual==expected,(era,y,actual,expected)
			cases+=1
	# Check the actual F1 Debug selection and each preview's resident tiles.
	base=n.s['DebugList'];debug=base+struct.unpack_from('>h',rom,base+60*2)[0]
	assert debug==n.s['Debug_MMZ1']
	count=struct.unpack_from('>H',rom,debug)[0];monitors=set()
	from import_ehz2_pp_background import nemesis
	resident=set()
	for label,tiles in [('ArtTile_MMZ_Atlas',477),('ArtTile_Bomb_MMZ',41),('ArtTile_Ring',32),('ArtTile_Monitor',24),('ArtTile_Monitor_Icons',16),('ArtTile_Lives_Counter',4),('ArtTile_Spikes',16),('ArtTile_Lamppost',12)]:
		resident.update(range(n.s[label],n.s[label]+tiles))
	for label,file in [('ArtTile_MMZ_HVPlatform','Morphing Orbs'),('ArtTile_MMZ_Propeller','MM Propeller'),('ArtTile_Wheel','Wheel carrier'),('ArtTile_Springs','Springs')]:
		raw=nemesis((ROOT/f'art/nemesis/{file}.nem').read_bytes())
		resident.update(range(n.s[label],n.s[label]+len(raw)//32))
	for i in range(count):
		code,mapping,sub,frame,_,gfx=struct.unpack_from('>IIHBBH',rom,debug+2+i*n.s['DebugEntry_size'])
		if code==n.s['Monitor']:monitors.add(sub)
		p=mapping+struct.unpack_from('>h',rom,mapping+frame*2)[0]
		for j in range(struct.unpack_from('>H',rom,p)[0]):
			_,size,tile,_=struct.unpack_from('>bBHh',rom,p+2+j*6)
			first=(tile+gfx)&2047
			assert set(range(first,first+((size>>2)+1)*((size&3)+1)))<=resident,(i,hex(first),'Debug tiles not resident')
	assert monitors>={1,2,6,7}
	return dict(eras=4,chunks_per_era=445,parallax_and_provider_cases=cases,debug_previews=count)


def animation_checks(args,act=1):
	"""Compare the assembled VM's writes and DMA requests with CD source steps."""
	from import_metallic_madness import animations,table_values,number
	import re
	n=Native(args.rom,args.listing);rom=args.rom.read_bytes()
	_,reference=animations(args.source,(ROOT/'_definitions/s2.constants.asm').read_text(),act)
	writes=updates=0
	for era,(key,title,_) in enumerate(ERAS):
		n.start();n.write('Current_ZoneAndAct',0xF00+act-1,2);n.write('Current_Timezone',era)
		initial=(ROOT/'palette/SonicAndTails.bin').read_bytes()+(ROOT/f'palette/MMZ{act} {title}.bin').read_bytes()
		palette=bytearray(initial);n.cpu.mem_write(n.s['v_palette']&0xFFFFFF,bytes(palette))
		letter=('a','b','c','d')[era]
		source=(args.source/f'src/r8/palette_cycle_{letter}.asm').read_text()
		pairs=re.findall(r'lea\s+(\w+),a1\s*\n\s*lea\s+(\w+),a2',source.split('\nCycleColor:',1)[0])[:(6,5,4,6)[era]]
		cycles=[]
		for script,colors in pairs:
			values=[number(v) for v in table_values(source,script,'b')]
			colors=[number(v) for v in table_values(source,colors,'w')]
			slot,count=values[:2];steps=list(zip(values[2::2],values[3::2]))
			if letter=='c' and slot==0x31:steps=[(2,0),(2,1),(22,0),(2,1),(66,2),(2,0)]
			cycles.append(dict(slot=slot,steps=steps,colors=colors,time=0,frame=0))
		data=(args.source/f'src/r8/data_{act}{letter}.asm').read_text()
		files=dict(re.findall(r'^(\w+):\s*\n\s*incbin\s+"([^"]+)"',data,re.M))
		streams=[dict(v,time=0,frame=0) for v in reference['streams'] if v['era']==key]
		for tick in range(1200):
			for cycle in cycles:
				cycle['time']-=1
				if cycle['time']<0:
					cycle['frame']=(cycle['frame']+1)%len(cycle['steps'])
					duration,color=cycle['steps'][cycle['frame']]
					cycle['time']=duration
					struct.pack_into('>H',palette,cycle['slot']*2,cycle['colors'][color]);writes+=1
			n.act('PalCycle_Load')
			assert n.cpu.mem_read(n.s['v_palette']&0xFFFFFF,128)==palette,(era,tick,'palette timeline')
			expected=[]
			for stream in streams:
				stream['time']-=1
				if stream['time']<0:
					step=stream['steps'][stream['frame']]
					stream['time']=step['duration']
					stream['frame']=(stream['frame']+1)%len(stream['steps'])
					raw=(args.source/files[stream['source'][step['frame']]]).read_bytes()[:stream['count']*32]
					expected.append((stream['tile']*32,raw))
			n.act('Animate_Tiles')
			actual=[(dest&65535,rom[address:address+(length&65535)*2]) for address,dest,length in n.uploads]
			assert actual==expected,(era,tick,'animation DMA',[(d,len(b)) for d,b in actual],[(d,len(b)) for d,b in expected])
			updates+=len(actual);n.uploads.clear()
		# Starter Acts 3/4 retain their existing callbacks.
		n.write('Current_Act',2);before=bytes(n.cpu.mem_read(n.s['v_palette']&0xFFFFFF,128))
		n.act('PalCycle_Load');n.act('Animate_Tiles')
		assert not n.uploads and n.cpu.mem_read(n.s['v_palette']&0xFFFFFF,128)==before
	return dict(eras=4,updates_per_era=1200,palette_changes=writes,dma_transfers=updates,
		shared_animated_tiles=reference['tiles'])


def morph_native(args):
	"""Exercise independent and simultaneous contacts across the complete morph."""
	n = Native(args.rom, args.listing)
	s = n.s
	root = (s['v_lvlobjspace'] & 0xFFFFFF)+5*s['object_size']
	index = (root-(s['v_objspace'] & 0xFFFFFF))//s['object_size']
	rom = args.rom.read_bytes()
	shapes = [(0,120,8,56),(1,4,8,40),(2,4,8,24),(3,32,8,8),
		(4,4,24,8),(5,4,40,8),(6,120,56,8),(5,4,40,8),
		(4,4,24,8),(3,32,8,8),(2,4,8,24),(1,4,8,40)]
	assert [struct.unpack_from('>4B', rom, s['HVPlat_StateTable']+i*4)
		for i in range(12)] == shapes
	actors = (('v_player',3),('v_player2',4))

	def setup(phase):
		n.start()
		n.write('Current_Zone', s['id_MMZ'])
		n.write('Camera_X_pos', 440, 2)
		for actor, bit in actors:
			n.put(actor, 'obX', 100, 2)
			n.put(actor, 'obY', 100, 2)
			n.put(actor, 'obHeight', s['sonic_height' if bit == 3 else 'tails_height'])
		for f, v, z in (('code', s['MorphingPlatform'], 4), ('obX', 600, 2), ('obY', 500, 2)):
			n.put(root, f, v, z)
		n.act('MorphingPlatform', root)
		assert n.get(root, 'obGfx', 2) == s['ArtTile_MMZ_HVPlatform']
		frame, duration, width, height = shapes[phase]
		for f, v, z in (('obFrame', frame, 1), ('obWidth', width, 1),
			('obActWid', width, 1), ('obHeight', height, 1), ('mplat_timer', 100, 1),
			('mplat_state', phase, 1), ('obRender', 0x84, 1), ('obStatus', 0, 1)):
			n.put(root, f, v, z)
		return width, height

	def attach(owner, bit, x=600):
		n.put(root, 'obStatus', n.get(root, 'obStatus') | (1 << bit))
		height = n.get(root, 'obHeight')
		for f, v, z in (('obX', x, 2), ('obY', 500-height-n.get(owner, 'obHeight'), 2),
			('obStatus', 8, 1), ('standonobject', index, 1)):
			n.put(owner, f, v, z)

	def run():
		n.act('MorphingPlatform_Run', root, regs={UC_M68K_REG_D7: 0x13572468})
		assert n.cpu.reg_read(UC_M68K_REG_D7) == 0x13572468

	cases = 0
	for phase, shape in enumerate(shapes):
		for owner, bit, other in (('v_player', 3, 'v_player2'), ('v_player2', 4, 'v_player')):
			for side in (-1, 1):
				for airborne in (0, 2):
					width, height = setup(phase)
					attach(owner, bit)
					n.put(other, 'obX', 600+side*(width+8), 2)
					n.put(other, 'obY', 500, 2)
					n.put(other, 'obVelX', (-side*0x100)&65535, 2)
					n.put(other, 'obStatus', airborne)
					run()
					assert n.get(other, 'obX', 2) == 600+side*(width+16), (phase, owner, side, airborne, 'approach missed')
					assert bool(n.get(other, 'obStatus') & 32) == (not airborne)
					assert n.get(other, 'obVelX', 2) == 0
					assert n.get(root, 'obStatus') & (1 << bit)
					assert n.get(owner, 'obStatus') & 8
					assert n.get(owner, 'obY', 2) == 500-height-n.get(owner, 'obHeight')
					cases += 1
				# Standing still uses the raw visible radius, despite the enlarged
				# approach bound. Check the last valid pixel and the first outside.
				for offset in (width, width+1):
					setup(phase)
					attach(owner, bit)
					n.put(owner, 'obX', 600+side*offset, 2)
					run()
					assert bool(n.get(owner, 'obStatus') & 8) == (offset == width), (shape, owner, side, offset)
					assert bool(n.get(root, 'obStatus') & (1 << bit)) == (offset == width)
					cases += 1
		# Both side corrections must survive the first character's register and
		# status writes. Swap sides and test sustained ground/air contacts.
		for sonic_side in (-1, 1):
			for airborne in (0, 2):
				width, height = setup(phase)
				for actor, bit in actors:
					n.put(actor, 'obY', 500, 2)
					n.put(actor, 'obStatus', airborne)
				for tick in range(16):
					for actor, bit in actors:
						side = sonic_side if bit == 3 else -sonic_side
						n.put(actor, 'obX', 600+side*(width+8), 2)
						n.put(actor, 'obVelX', (-side*0x100)&65535, 2)
						n.put(actor, 'obInertia', (-side*0x100)&65535, 2)
					run()
					assert n.get(root, 'obStatus') & 0x60 == (0 if airborne else 0x60), (phase, sonic_side, airborne, tick)
					for actor, bit in actors:
						side = sonic_side if bit == 3 else -sonic_side
						assert n.get(actor, 'obX', 2) == 600+side*(width+16)
						assert n.get(actor, 'obY', 2) == 500
						assert n.get(actor, 'obVelX', 2) == 0
						assert bool(n.get(actor, 'obStatus') & 32) == (not airborne)
				if not airborne:
					for actor, bit in actors:
						side = sonic_side if bit == 3 else -sonic_side
						n.put(actor, 'obX', 600+side*(width+17), 2)
						run()
						assert not n.get(root, 'obStatus') & (1 << (bit+2))
						assert not n.get(actor, 'obStatus') & 32
						assert n.get(root, 'obStatus') & (0x40 if bit==3 else 0x20)
						n.put(actor, 'obX', 600+side*(width+16), 2)
						run()
						assert n.get(root, 'obStatus') & 0x60 == 0x60
				cases += 1
	# Both riders follow all shrinking/expanding poses for two full cycles.
	setup(0)
	for actor, bit in actors:attach(actor, bit, 600+(-4 if bit==3 else 4))
	n.put(root, 'mplat_timer', shapes[0][1])
	phase, timer = 0, shapes[0][1]
	timeline = sum(shape[1] for shape in shapes)*2
	for tick in range(timeline):
		timer -= 1
		if not timer:
			phase = (phase+1)%len(shapes)
			timer = shapes[phase][1]
		run()
		assert (n.get(root, 'mplat_state'), n.get(root, 'mplat_timer')) == (phase, timer)
		assert tuple(n.get(root, f) for f in ('obFrame','obWidth','obHeight')) == (shapes[phase][0],*shapes[phase][2:])
		assert n.get(root, 'obStatus') & 0x18 == 0x18
		for actor, bit in actors:
			assert n.get(actor, 'obStatus') & 8
			assert n.get(actor, 'obX', 2) == 600+(-4 if bit==3 else 4)
			assert n.get(actor, 'obY', 2) == 500-shapes[phase][3]-n.get(actor, 'obHeight')
	if args.source:
		from import_palmtree_enemies import mapping
		from sprite_palette import PLAYER_FROM_S1, remap_pixels
		from check_sprite_assets import frames
		from import_ehz2_pp_background import nemesis
		assert frames((ROOT/'mappings/sprite/Morphing Platform.bin').read_bytes()) == frames(
			mapping((args.source/'src/sprites/r8/hv_platform.asm').read_text(), '.Sprites'))
		assert nemesis((ROOT/'art/nemesis/Morphing Orbs.nem').read_bytes()) == remap_pixels(
			nemesis((args.source/'src/gfx/r8/hv_platform.nem').read_bytes()), PLAYER_FROM_S1)
	return dict(contact_and_standing_cases=cases, seven_authored_shapes=True,
		phases=12, simultaneous_side_contacts=True, both_rider_timeline=timeline,
		independent_approach_width=True, raw_standing_edges=True, existing_cd_art=True)


def ring_layouts(args):
	"""The ROM and editor must expose the same independent ring lists."""
	n = Native(args.rom, args.listing)
	rom = args.rom.read_bytes()
	ini = ROOT / 'SonLVL INI Files/SonLVL.ini'
	settings = ConfigParser(interpolation=None)
	settings.read_string('[Project]\n' + ini.read_text())
	base = n.s['RingPos_Index']
	capacity = (n.s['Ring_Positions_Active_End'] - n.s['Ring_Positions']) // 6 - 1
	addresses = set()
	files = set()
	for act in (1, 2):
		for era, (_, title, _) in enumerate(ERAS):
			section = settings[f'Metallic Madness Zone Act {act} - {title}']
			path = (ini.parent / section['rings']).resolve()
			layout = path.read_bytes()
			assert len(layout) % 4 == 2 and layout[-2:] == b'\xff\xff', path
			rows = tuple(struct.iter_unpack('>HH', layout[:-2]))
			assert all(x < 0x8000 for x, _ in rows), path
			assert sum(1 + (y >> 12 & 7) for _, y in rows) <= capacity, path
			index = ((n.s['id_MMZ'] * 4 + act - 1) * 4 + era) * 2
			header = struct.unpack_from('>H', rom, base + index)[0]
			layer_flag = n.s['RingLayout_PathTable']
			assert bool(header & layer_flag) == (act == 2)
			address = base + (header & ~layer_flag)
			if act == 2:
				layers = path.with_name(path.stem + ' Paths.bin').read_bytes()
				assert layers[-4:] == b'\xff\xff\x00\x00'
				secondary = tuple(struct.iter_unpack('>HH', layers[:-4]))
				assert secondary == tuple(sorted(set(secondary)))
				assert set(secondary) <= set(rows)
				layer_address = address + len(layout)
				assert rom[layer_address:layer_address + len(layers)] == layers
			assert rom[address:address + len(layout)] == layout, (act, title, path)
			assert address not in addresses and path not in files, (act, title)
			addresses.add(address)
			files.add(path)
	return dict(independent_era_lists=len(files), editor_and_rom_match=True)


def placement_native(args):
	"""Exercise the real ROM placement tables and CD selection in every era."""
	from native_test_core import Manager
	from object_layout import decode
	m = Manager(args.rom, args.listing)
	windows = 0
	loaded = 0
	for act in (1, 2):
		rows = decode((ROOT/f'level/objects/LV0F_{act}.bin').read_bytes())
		cameras = {(max(0, x-160) & 0xFF80, max(0, (y & 0xFFF)-112) & 0xFF80)
			for x, y, oid, eras, sub in rows}
		for era, mask in enumerate((0x40, 0x20, 0x80, 0x80)):
			for x, y in sorted(cameras):
				m.start()
				m.write('Current_ZoneAndAct', 0xF00+act-1, 2)
				m.write('Current_Timezone', era)
				m.cam(x, y)
				m.act('ObjectsManager')
				live = m.verify(rows)
				actual = {(ptr-m.respawn_base) & 65535 for ptr in live}
				expected = {i for i, (px, py, oid, eras, sub) in enumerate(rows)
					if eras & mask and max(0, x-128) <= px < x+640
					and max(0, y-128) <= py & 0xFFF <= y+512}
				assert actual == expected, (act, era, x, y, actual ^ expected)
				assert all(m.get(obj, 'code') != m.s['ObjNull'] for obj in live.values())
				loaded += len(live)
				windows += 1
	return dict(windows=windows, created_roots=loaded, acts=2, eras=4,
		actual_rom_tables=True, exact_subtypes_and_flips=True)


def authored_game(args):
	"""Verify authored ring/path data, generator, time poles and finishes in-game."""
	from check_companion_followup import place
	from check_object_course import boot_level
	from check_rising_crushers import ACTORS, seek
	from genesis_test_core import Genesis
	from object_layout import decode
	g = Genesis(args.core, args.rom, args.listing, args.output/'authored', args.pal,
		system_directory=args.system_directory)
	initial = g.save()
	report = []
	s = g.s
	slots = range(s['v_lvlobjspace'] & 0xFFFF, s['v_lvlobjend'] & 0xFFFF, s['object_size'])
	burst_table = s['TimeGenerator_Bursts'] + 4
	burst_data = g.rom[burst_table:burst_table+21*3+1]
	bursts = {time: (dx, dy) for time, dx, dy in struct.iter_unpack('>Bbb', burst_data[:-1])}
	assert len(bursts) == 21 and burst_data[-1] == 0xFF

	def visit(x, y):
		g.restore(level)
		g.buttons, g.buttons2 = set(), set()
		seek(g, max(x, 152), max(y, 132))

	def actor_at(actor, x, y, path=0, control=1):
		place(g, actor, x, y)
		g.put(actor, 'obControl', control)
		g.put(actor, 'obTopSolidBit', 0xC0D+path*0x202, 2)
		g.put(actor, 'obRender', 0x84)
		g.buttons2 = {4}

	def find(x, y, code):
		return next(slot for slot in slots if g.get(slot, 'code') == s[code]
			and g.get(slot, 'obX', 2) == x and g.get(slot, 'obY', 2) == y)

	for act in (1, 2):
		placements = decode((ROOT/f'level/objects/LV0F_{act}.bin').read_bytes())
		sign_x, sign_y, _, _, _ = next(row for row in placements if row[2] == 0x7E)
		for era, (_, title, folder) in enumerate(ERAS):
			g.restore(initial)
			g.buttons, g.buttons2 = set(), set()
			boot_level(g, zone=15, act=act-1, timezone=era)
			level = g.save()
			path = ROOT/f'level/rings/{folder}LV0F_{act}.bin'
			layout = dict.fromkeys(struct.iter_unpack('>HH', path.read_bytes()[:-2]),
				s['RingPath_Primary'] if act == 2 else 0)
			if act == 2:
				for point in struct.iter_unpack('>HH', path.with_name(path.stem+' Paths.bin').read_bytes()[:-4]):
					layout[point] = s['RingPath_Secondary']
			base = s['Ring_Positions']+6
			records = {}
			for index in range(len(layout)):
				at = base+index*6
				x, y = g.read(at+2, 2), g.read(at+4, 2)
				records[x, y & 0x3FFF] = at
				assert layout[x, y & 0x3FFF] == y & 0xC000, (act, title, x, y)
			assert set(records) == set(layout) and g.read(base+len(layout)*6+2, 2) == 0xFFFF
			for ring_path in range(act):
				mask = (s['RingPath_Secondary'] if ring_path else s['RingPath_Primary']) if act == 2 else 0
				x, y = next(point for point, flag in layout.items()
					if flag == mask and point[0] >= 0x600 and 132 <= point[1] < 0x700)
				at = records[x, y]
				for actor in ACTORS:
					for player_path in range(act):
						visit(x, y)
						actor_at(actor, x, y, player_path)
						g.run(5)
						assert bool(g.read(at, 2)) == (player_path == ring_path), (act, title, x, y, actor, player_path)
			mask = (0x40, 0x20, 0x80, 0x80)[era]
			x, y, _, _, subtype = next(row for row in placements if row[2] == 0x79
				and row[3] & mask and row[4] & 0x300 and 0x400 < row[0] < 0x1A00 and 132 <= row[1] < 0x700)
			pole_path = int(bool(subtype & 0x800))
			visit(x, y)
			find(x, y, 'TimePole_Main')
			if act == 2:
				actor_at(ACTORS[0], x, y, pole_path ^ 1)
				g.run(5)
				assert not g.read('TimeWarp_Direction'), (act, era, x, y, 'wrong pole path')
			actor_at(ACTORS[0], x, y, pole_path)
			g.run(5)
			assert g.read('TimeWarp_Direction') == (255 if subtype & 0x100 else 1), (act, era, x, y)
			pole = x, y
			if era < 2:
				x, y, _, _, _ = next(row for row in placements if row[2] == 0xB9)
				visit(x, y)
				generator = find(x, y-16 if era == 1 else y,
					'TimeGenerator_Active' if era == 1 else 'TimeGenerator_Dormant')
				if era == 1:
					actor_at(ACTORS[0], x, y-16)
					g.put(ACTORS[0], 'obStatusSecondary', 2)
					g.put(ACTORS[0], 'invtime', 600, 2)
					seen = set()
					for _ in range(60):
						g.run()
						if g.get(generator, 'code') == s['TimeGenerator_Dormant']:
							break
						if g.get(generator, 'code') != s['TimeGenerator_Explode']:
							continue
						assert g.read('TimeWarp_GoodFuture')
						frame = (g.read('Timer_frames', 2) - g.get(generator, 'timegen_break_frame', 2)) & 0xFFFF
						if frame not in bursts:
							continue
						dx, dy = bursts[frame]
						if any(g.get(slot, 'code') == s['FieryExplosion']
								and g.get(slot, 'obX', 2) == x + dx
								and g.get(slot, 'obY', 2) == y - 16 + dy for slot in slots):
							seen.add(frame)
					assert seen == bursts.keys(), (act, 'generator burst frames', bursts.keys() - seen)
					assert g.get(generator, 'code') == s['TimeGenerator_Dormant'] and g.get(generator, 'obFrame') == 1
			visit(sign_x-32, sign_y)
			sign = find(sign_x, sign_y, 'Signpost')
			assert g.get(sign, 'obRoutine') == 2 and g.read('f_timecount')
			actor_at(ACTORS[0], sign_x+4, sign_y+160)
			g.run(5)
			assert g.get(sign, 'obRoutine') == 2 and g.read('f_timecount')
			actor_at(ACTORS[0], sign_x-12, sign_y)
			g.run(2)
			actor_at(ACTORS[0], sign_x+4, sign_y)
			g.run(5)
			assert g.get(sign, 'obRoutine') >= 4 and not g.read('f_timecount')
			assert not g.read('v_errortype')
			print(f'MMZ{act} {title}: {len(layout)} rings, path pickups, time pole and actual finish pass.', flush=True)
			report.append(dict(act=act, era=title, rings=len(layout), pole=pole, finish=[sign_x,sign_y]))
	g.close()
	return report


def game(args):
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	g=Genesis(args.core,args.rom,args.listing,args.output/'game',args.pal,
		system_directory=args.system_directory)
	initial=g.save();report=[]
	vsram=(C.c_uint8*128).in_dll(g.core,'vsram')
	def word(memory,address):return memory[address^1]*256+memory[(address+1)^1]
	for era,(_,title,folder) in enumerate(ERAS):
		g.restore(initial)
		boot_level(g,zone=15,act=0,timezone=era)
		assert g.read('Current_Timezone')==era
		assert g.read('Current_ZoneAndAct',2)==0xF00
		fg,bg=load(ROOT/f'level/layout/{folder}LV0F_1.kosp')
		chunks=(ROOT/f'mappings/128x128/MMZ1 {title}.unc').read_bytes()
		blocks=(ROOT/f'mappings/16x16/MMZ1 {title}.unc').read_bytes()
		def tile(plane,x,y):
			if plane==0:
				cid=fg[y//128][x//128] if y//128<len(fg) and x//128<len(fg[0]) else 0
			else:cid=bg[y//128%len(bg)][x//128%len(bg[0])]
			entry=struct.unpack_from('>H',chunks,cid*128+(y//16&7)*16+(x//16&7)*2)[0]
			bx=(x//8&1)^bool(entry&0x400);by=(y//8&1)^bool(entry&0x800)
			return struct.unpack_from('>H',blocks,(entry&1023)*8+(by*2+bx)*2)[0]^(0x800 if entry&0x400 else 0)^(0x1000 if entry&0x800 else 0)
		selectors=rows(era==1);samples=0;animated=[]
		if args.source:
			from import_metallic_madness import animations
			_,meta=animations(args.source,(ROOT/'_definitions/s2.constants.asm').read_text())
			import re
			letter=('a','b','c','d')[era]
			data=(args.source/f'src/r8/data_1{letter}.asm').read_text()
			files=dict(re.findall(r'^(\w+):\s*\n\s*incbin\s+"([^"]+)"',data,re.M))
			for stream in meta['streams']:
				if stream['era']==ERAS[era][0]:
					animated.append((stream['tile'],stream['count'],{
						(args.source/files[p]).read_bytes()[:stream['count']*32] for p in stream['source']}))
		poses=((0,1600),(128,1408),(1800,448),(4800,0),(6000,896),(7831,1808))
		for index,(x,y) in enumerate(poses):
			for actor in ('v_player','v_player2'):
				for f,v,z in (('obX',x+160,2),('obY',y+96,2),('obXSub',0,2),('obYSub',0,2),
					('obVelX',0,2),('obVelY',0,2),('obInertia',0,2),('obControl',0x81,1)):
					g.put(actor,f,v,z)
			g.write('Camera_X_pos',x,2);g.write('Camera_Y_pos',y,2)
			g.write('Screen_redraw_flag',1);g.run(30)
			assert not g.read('v_errortype')
			for plane in (0,1):
				py=word(vsram,plane*2)&2047
				for sy in range(0,224,8):
					wy=py+sy
					scroll=word(g.vram,g.s['vram_hscroll']+sy*4+plane*2)
					if scroll&0x8000:scroll-=65536
					fixed=plane==1 and selectors[wy//8]<9
					for sx in range(0,320,8):
						wx=(sx-scroll)&65535
						actual=word(g.vram,(0xE000 if plane else 0xC000)+(wy//8&31)*128+(wx//8&63)*2)
						expected=tile(plane,wx%512 if fixed else wx,wy)
						assert actual==expected,(era,index,plane,sx,sy,wx,wy,hex(actual),hex(expected))
						samples+=1
			for tile_base,count,permitted in animated:
				pixels=bytes(g.vram[(tile_base*32+i)^1] for i in range(count*32))
				assert pixels in permitted,(era,index,tile_base,'animated VRAM payload')
			g.video.save(args.output/f'game/era{era}-scene{index}.png')
		report.append(dict(era=title,scenes=len(poses),visible_tiles=samples))
	g.close()
	return report


def platform_native(args):
	"""Compare actual platform updates with CD frame lists and curve data."""
	import re
	S=args.source;n=Native(args.rom,args.listing);report={};checks=0
	slots=lambda:list(range(n.s['v_lvlobjspace']&0xffffff,n.s['v_lvlobjend']&0xffffff,n.s['object_size']))
	def construct(entry,sub,idx=5,x=600,y=300):
		root=slots()[idx];n.put(root,'code',n.s[entry]);n.put(root,'obX',x,2);n.put(root,'obY',y,2);n.put(root,'obSubtype',sub)
		for a in ('v_player','v_player2'):n.put(a,'obX',100,2);n.put(a,'obY',100,2)
		n.act(entry,root,regs={UC_M68K_REG_D7:0x3579006F})
		assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006F,'Constructor changed the object-loop counter'
		return root
	def init(entry,sub,idx=5):
		n.start();root=construct(entry,sub,idx)
		return root,[a for a in slots() if n.get(a,'code')==n.s['PlatformGroup_Run']]
	def update(a):
		n.act('PlatformGroup_Run',a,regs={UC_M68K_REG_D7:0x3579006F})
		assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006F,'Platform changed the object-loop counter'
	def anim(name):
		t=(S/f'src/anims/r8/{name}.asm').read_text();rows=[]
		for i in range(2 if name=='vanish_platform' else 1):
			v=[];body=t.split(f'.Anim{i}:')[1].split('.Anim',1)[0]
			for line in body.splitlines():
				m=re.search(r'dc.b\s+(.+)',line.split(';')[0])
				if m:v.extend(int(s.strip().replace('$','0x'),0) for s in m[1].split(','))
			rows.append(v)
		return rows
	ani=anim('vanish_platform')
	for variant,timers in enumerate(((60,),(60,60),(90,180,270))):
		n.start()
		members=[construct('SMZ_VanishPlatform',0x100|delay//30,5+i,600+32*i,300+(16*i if variant==2 else 0))
			for i,delay in enumerate(timers)]
		assert [a for a in slots() if n.get(a,'code')==n.s['PlatformGroup_Run']]==members
		assert all(not n.get(a,'platgroup_count') and not n.get(a,'platgroup_owner',2) for a in members)
		refs=[dict(state='delay',timer=tm,frame=6,idx=0,which=0) for tm in timers]
		for tick in range(1500):
			for a,ref in zip(members,refs):
				st=ref['state']
				if st=='delay':
					ref['timer']-=1
					if ref['timer']==0:ref.update(state='anim',idx=0,which=0)
				elif st=='anim':
					ref['frame']=ani[ref['which']][ref['idx']+1];ref['idx']+=1
					if ref['frame']==0:ref.update(state='stand',timer=120)
				else:
					ref['timer']-=1
					if ref['timer']==0:ref.update(state='anim',idx=0,which=1)
				update(a);actual=n.get(a,'obFrame')
				assert actual==ref['frame'],('vanish',variant,tick,hex(a),actual,ref)
				assert n.get(a,'platgroup_state',4)==n.s['Vanish_Cycle']
				if ref['state']=='stand' and ref['timer']<120:
					assert n.get(a,'vanish_contact',2)==0x101 and n.get(a,'platgroup_timer',2)==ref['timer']
				checks+=1
		for a in members:
			n.act('PlatformGroup_Unload',a,regs={UC_M68K_REG_D7:0x3579006F})
			assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006F and not n.get(a,'code')
	report['vanish_frames']=checks
	fixed=anim('spin_platform')[0];assert fixed[0]==1
	fixed=[f for v in fixed[1:] if v<255 for f in (v,v)]
	for sub,count in ((0x100,1),(0x102,2)):
		root,members=init('SMZ_SpinConvey',sub);assert len(members)==count
		frame=0;timer=120;spinning=False;at=0
		for tick in range(1500):
			if not spinning:
				timer-=1
				if timer==0:spinning=True;at=0
			else:
				frame=fixed[at];at+=1
				if frame==0:spinning=False;timer=120
			for a in members:
				update(a);assert n.get(a,'obFrame')==frame,('fixed',sub,tick,n.get(a,'obFrame'),frame)
				checks+=1
	root,members=init('SMZ_SpinConvey',0x101);assert len(members)==5
	members=[root]+[(int.from_bytes(n.cpu.mem_read(root+n.s['platgroup_members']+i*2,2),'big')|0xff0000) for i in range(4)]
	refs=[dict(phase=i*89,spin=False,timer=0,acc=0,frame=0) for i in range(5)]
	path=list(struct.iter_unpack('bb',(S/'src/data/r8/spin_platform_1.bin').read_bytes()))
	for a,ref in zip(members,refs):
		x,y=path[ref['phase']]
		assert (n.get(a,'obX',2),n.get(a,'obY',2),n.get(a,'obVelX',2))==(600+x,300+y,0),'Curve cohort must be distributed before its first draw'
	for tick in range(1800):
		for a,ref in zip(members,refs):
			x,y=path[ref['phase']];ref['phase']=(ref['phase']+1)%446
			if not ref['spin']:
				if ref['phase']==344:ref.update(spin=True,timer=216,acc=0)
			else:
				ref['timer']-=1
				if ref['timer']<0:ref.update(spin=False,frame=0)
				else:
					ref['acc']+=128
					if ref['acc']>0x500:ref['acc']=0
					ref['frame']=ref['acc']>>8
			update(a)
			assert (n.get(a,'obX',2),n.get(a,'obY',2),n.get(a,'obFrame'))==(600+x,300+y,ref['frame']),('curve',tick,a,ref)
			checks+=1
	# Allocation is all-or-nothing, including occupied earlier/later slots.
	for free in range(4):
		n.start();ss=slots();root=ss[6]
		for a in ss:n.put(a,'code',n.s['PlayMusic'])
		for a in ss[:free]:n.put(a,'code',0)
		n.put(root,'code',n.s['SMZ_SpinConvey']);n.put(root,'obX',600,2);n.put(root,'obY',300,2);n.put(root,'obSubtype',0x101)
		before=bytes(n.cpu.mem_read(ss[0],len(ss)*n.s['object_size']));n.act('SMZ_SpinConvey',root)
		assert bytes(n.cpu.mem_read(ss[0],len(before)))==before
	# A live same-family replacement at the same address cannot adopt a stale child.
	root,members=init('SMZ_SpinConvey',0x102);child=next(a for a in members if a!=root)
	n.cpu.mem_write(root+n.s['platgroup_members'],b'\0'*8);update(child);assert not n.get(child,'code')
	# An independent platform initializes even when every other slot is occupied.
	n.start();ss=slots()
	for a in ss:n.put(a,'code',n.s['PlayMusic'])
	a=construct('SMZ_VanishPlatform',0x109,6)
	assert n.get(a,'platgroup_state',4)==n.s['Vanish_Cycle'] and n.get(a,'platgroup_timer',2)==270
	assert all(n.get(q,'code')==n.s['PlayMusic'] for q in ss if q!=a)
	report['platform_updates']=checks;report['allocation_failure_and_stale_owner']=True
	return report

def floor_wheel_native(args):
	"""Progressive floor edges, stationary riders and bounded wheel patrols."""
	n=Native(args.rom,args.listing);checks=0
	ss=list(range(n.s['v_lvlobjspace']&0xffffff,n.s['v_lvlobjend']&0xffffff,n.s['object_size']))
	def run(a):
		n.put(a,'obRender',n.get(a,'obRender')|128)
		n.act(n.get(a,'code'),a,regs={UC_M68K_REG_D7:0x3579006F})
		assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006F
	def setup(entry,sub,flip=0):
		n.start();n.write('Camera_X_pos',440,2);root=ss[5]
		for actor in ('v_player','v_player2'):n.put(actor,'obX',100,2);n.put(actor,'obY',100,2)
		for f,v,z in [('code',n.s[entry],4),('obX',600,2),('obY',600,2),('obSubtype',sub,2),('obStatus',flip,1)]:n.put(root,f,v,z)
		n.act(entry,root,regs={UC_M68K_REG_D7:0x3579006F})
		assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006F
		return root
	def attach(a,actor,x,bit):
		n.put(actor,'obX',x,2);n.put(actor,'obY',564,2);n.put(actor,'obStatus',8)
		n.put(actor,'standonobject',(a-(n.s['v_objspace']&0xffffff))//n.s['object_size'])
		n.put(a,'obStatus',n.get(a,'obStatus')|(1<<bit))
	for columns in range(1,9):
		for direction in (-1,1):
			for trigger in ('v_player','v_player2'):
				a=setup('Obj1B',0x100|columns)
				assert (n.get(a,'obFrame'),n.get(a,'obWidth'))==(columns-1,columns*8)
				attach(a,trigger,600,3 if trigger=='v_player' else 4)
				n.put(trigger,'obVelX',(direction*256)&65535,2);run(a)
				assert n.get(a,'code')==n.s['Floor_Delay']
				assert n.get(a,'floor_step',2)==(direction*8)&65535
				for remaining in range(columns-1,-1,-1):
					while n.get(a,'code')==n.s['Floor_Delay']:run(a)
					assert n.get(a,'code')==n.s['Floor_BreakColumn'];run(a)
					if remaining:
						assert n.get(a,'obX',2)==600+(columns-remaining)*8*direction
						assert n.get(a,'obWidth')==remaining*8 and n.get(a,'obFrame')==remaining-1
					else:assert not n.get(a,'code') and not n.get(trigger,'obStatus')&8
				pieces=[p for p in ss if n.get(p,'code')==n.s['FloorPiece_Run']]
				assert len(pieces)==columns*2 and all(not n.get(p,'respawn_addr',2) for p in pieces)
				checks+=1
	# Shrinking the left edge must release its rider while the right-hand rider
	# keeps exactly the same world position and standing height.
	a=setup('Obj1B',0x104);attach(a,'v_player',580,3);attach(a,'v_player2',620,4);run(a)
	while n.get(a,'code')==n.s['Floor_Delay']:run(a)
	run(a)
	assert not n.get('v_player','obStatus')&8 and n.get('v_player2','obStatus')&8
	assert (n.get('v_player2','obX',2),n.get('v_player2','obY',2))==(620,564)
	for count in (0,9,127):
		a=setup('Obj1B',0x180|count);assert n.get(a,'code')==n.s['Floor_Static'] and n.get(a,'obWidth')==8
	# A full pool still consumes each slice without retry loops or corrupting
	# neighboring SSTs. Static blocks do not accidentally arm a collapse.
	a=setup('Obj1B',0x104)
	for p in ss:
		if p!=a:n.put(p,'code',n.s['PlayMusic'])
	n.put(a,'code',n.s['Floor_BreakColumn']);run(a);assert n.get(a,'floor_columns',2)==3
	# A progressive floor piece falls exactly like a classic fragment.
	a=setup('Obj1B',0x101);n.put(a,'floor_step',8,2);n.put(a,'code',n.s['Floor_BreakColumn']);run(a)
	piece=next(p for p in ss if n.get(p,'code')==n.s['FloorPiece_Run'])
	n.put(piece,'floor_piece_delay',0)
	y=n.get(piece,'obY',4)
	for tick in range(120):
		run(piece);y+=tick*0x3800
		assert n.get(piece,'obY',4)==y and n.get(piece,'obVelY',2)==(tick+1)*0x38
	# Isolate the native movement oracle from terrain probes: wall clearance is
	# eight pixels, the landed floor is flat. Real terrain/payload contacts run
	# separately in Genesis Plus GX.
	for label in ('ObjHitWallRight','ObjHitWallLeft'):n.cpu.mem_write(n.s[label],bytes.fromhex('72084E75'))
	for short in range(2):
		for yellow in range(2):
			for flip in range(2):
				a=setup('WheelCarrier',0x100|(short<<7)|yellow,flip)
				n.cpu.mem_write(n.s['ObjHitFloor'],bytes.fromhex('72FF4E75'))
				n.cpu.ctl_remove_cache(n.s['ObjHitFloor'],n.s['ObjHitFloor']+4);run(a)
				assert n.get(a,'code')==n.s['WheelCarrier'] and n.get(a,'obRoutine')==4 and n.get(a,'obY',2)==599
				n.cpu.mem_write(n.s['ObjHitFloor'],bytes.fromhex('72004E75'))
				n.cpu.ctl_remove_cache(n.s['ObjHitFloor'],n.s['ObjHitFloor']+4)
				center=n.get(a,'obX',2);limit=64 if short else 80
				child=n.get(a,'wheel_child',4)
				assert n.get(child,'obSubtype')==(2 if yellow else 0)
				reached=set()
				for _ in range(800):
					old_x=n.get(a,'obX',4);run(a)
					x=n.get(a,'obX',4);dx=abs(x-old_x)
					assert (center-limit)<<16 <= x <= (center+limit)<<16
					assert n.get(a,'obY',2)==599
					assert n.get(child,'obX',4)==x
					if x in ((center-limit)<<16,(center+limit)<<16):
						reached.add(x)
						assert 0<dx<=0x18000
						assert n.get(a,'obVelX',2)==(0x180 if x<old_x else 0xFE80)
					else:assert dx==0x18000
					checks+=1
				assert len(reached)==2
	return dict(floor_configurations=32,wheel_updates=6400,checks=checks,
		stationary_rider_and_removed_edge=True,piece_acceleration_cases=120,full_pool=True)


def floor_wheel_game(args):
	"""Real-frame floor support, moving-spring contact and removal in each era."""
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_companion_followup import isolate,spawn,place
	g=Genesis(args.core,args.rom,args.listing,args.output/'floors-wheels',args.pal,
		system_directory=args.system_directory)
	initial=g.save();report=[]
	def clear():
		isolate(g);g.placement_write(0,int.from_bytes(b'\x80'*g.placement_capacity(),'big'),g.placement_capacity())
		for actor in ('v_player','v_player2'):
			place(g,actor,600,400);g.put(actor,'obControl',0x81)
		g.write('Camera_X_pos',440,2);g.write('Camera_X_pos_coarse_back',256,2);g.write('Camera_Y_pos',480,2)
		for row in range(2,7):
			for col in range(2,7):g.layout_cell(row,col,0)
	for era in range(4):
		g.restore(initial);boot_level(g,zone=15,timezone=era);clear();stage=g.save()
		for trigger in ('v_player','v_player2'):
			g.restore(stage);a=spawn(g,'Obj1B',600,600,4);g.run(2)
			place(g,trigger,620,600-16-g.get(trigger,'default_y_radius'))
			g.put(trigger,'obControl',1);g.run(3)
			assert g.get(a,'obStatus')&(8 if trigger=='v_player' else 16),(era,trigger,'floor-landing')
			assert g.get(a,'code')==g.s['Floor_Delay']
			place(g,'v_player',580,600-16-g.get('v_player','default_y_radius'));g.put('v_player','obControl',1)
			place(g,'v_player2',620,600-16-g.get('v_player2','default_y_radius'));g.put('v_player2','obControl',1)
			g.run(2);before=(g.get('v_player2','obX',2),g.get('v_player2','obY',2))
			for _ in range(20):
				g.run()
				if g.get(a,'floor_columns',2)==3:break
			else:raise AssertionError((era,'floor-did-not-crumble'))
			assert not g.get('v_player','obStatus')&8 and g.get('v_player2','obStatus')&8
			assert (g.get('v_player2','obX',2),g.get('v_player2','obY',2))==before,(era,trigger,'floor-hop')
			g.video.save(args.output/'floors-wheels'/f'era{era}-{trigger}-crumbling.png')
			g.run(35);assert not g.get(a,'code') and not g.get('v_player2','obStatus')&8
			report.append(dict(era=era,trigger=trigger,stationary_rider=True,removed_edge_released=True))
		g.restore(stage);a=spawn(g,'Obj1B',600,600,0x184);g.run(2)
		for actor in ('v_player','v_player2'):
			place(g,actor,600,600-16-g.get(actor,'default_y_radius'));g.put(actor,'obControl',1)
		g.run(30);assert g.get(a,'code')==g.s['Floor_Static'] and g.get(a,'obStatus')&0x18==0x18
		g.video.save(args.output/'floors-wheels'/f'era{era}-static.png')
		# Build only a RAM terrain fixture using this era's own full-solid profile.
		g.restore(stage);rom=bytes(g.rom);indices=g.read('v_colladdr1',4)
		block=next(b for b in range(1,551) if set(rom[g.s['ColArray1']+rom[indices+b*2]*16:g.s['ColArray1']+(rom[indices+b*2]+1)*16])=={16})|0xF000
		chunks=g.terrain_address('chunks')
		for row in range(8):
			for col in range(8):g.write(chunks+1023*128+row*16+col*2,block if row>=4 else 0,2)
		for col in range(3,7):g.layout_cell(4,col,1023)
		course=g.save()
		for short in range(2):
			g.restore(course);a=spawn(g,'WheelCarrier',600,566,0x100|(short<<7)|short);g.run(20)
			assert g.get(a,'code')==g.s['WheelCarrier'] and g.get(a,'obRoutine')==4,(era,short,'wheel-did-not-land')
			center=g.get(a,'wheel_home',2)
			child=g.get(a,'wheel_child',4);assert g.get(child,'code')==g.s['Springs']
			assert g.get(child,'obSubtype')==(2 if short else 0)
			xs=[]
			for _ in range(350):
				for frame in range(12):
					g.run()
					if g.read('v_vbla_counter')==1:break
				else:raise AssertionError('Carrier update did not complete')
				xs.append(g.get(a,'obX',2))
				assert g.get(child,'obX',4)==g.get(a,'obX',4)
			assert (min(xs),max(xs))==(center-(64 if short else 80),center+(64 if short else 80)),(era,short,min(xs),max(xs))
			rest=g.save()
			for actor in ('v_player','v_player2'):
				g.restore(rest);place(g,actor,g.get(child,'obX',2),g.get(child,'obY',2)-8-g.get(actor,'default_y_radius'))
				g.put(actor,'obControl',1);g.run(2)
				assert g.get(actor,'obVelY',2)&0x8000,(era,short,actor,'no-spring-launch')
				g.video.save(args.output/'floors-wheels'/f'era{era}-spring{short}-{actor}.png')
			report.append(dict(era=era,short_patrol=bool(short),x_range=[min(xs),max(xs)],both_spring_contacts=True))
		assert not g.read('v_errortype')
	g.close()
	return report


def platform_game(args):
	"""Check era PLCs, both live riders and independent disappearance/flip release."""
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_companion_followup import isolate,spawn,place,reset_cpu
	from import_ehz2_pp_background import nemesis
	R=ROOT
	g=Genesis(args.core,args.rom,args.listing,args.output/'objects',args.pal,
		system_directory=args.system_directory)
	initial=g.save();report=[]
	def raw_vram(base,raw):assert bytes(g.vram[(base*32+i)^1] for i in range(len(raw)))==raw,('resident-bank',hex(base))
	def setup(code,sub):
		isolate(g);g.placement_write(0,int.from_bytes(b'\x80'*g.placement_capacity(),'big'),g.placement_capacity())
		for actor in ('v_player','v_player2'):place(g,actor,600,400);g.put(actor,'obControl',0x81)
		g.write('Camera_X_pos',440,2);g.write('Camera_X_pos_coarse_back',256,2);g.write('Camera_Y_pos',480,2)
		a=spawn(g,code,600,600,sub);g.run(2)
		if code=='SMZ_SpinConvey' and sub==0x101:
			for _ in range(30):
				if g.get(a,'platgroup_phase',2):break
				g.run()
			else:raise AssertionError('Moving cohort did not reach its first curve point')
		return a
	for era in range(4):
		g.restore(initial);boot_level(g,zone=15,timezone=era)
		raw=bytearray((R/'art/uncompressed/MMZ1 Sprite Atlas.unc').read_bytes())
		for off,name in (((454,'Generator Past'),) if era==1 else ((110,'Saw Good Future'),(148,'Seesaw Good Future')) if era==2 else ()):
			data=(R/f'art/uncompressed/MMZ1 {name}.unc').read_bytes();raw[off*32:off*32+len(data)]=data
		raw_vram(g.s['ArtTile_MMZ_Atlas'],raw)
		for bank,file in [('ArtTile_MMZ_HVPlatform','Morphing Orbs'),('ArtTile_MMZ_Propeller','MM Propeller'),('ArtTile_Wheel','Wheel carrier')]:raw_vram(g.s[bank],nemesis((R/f'art/nemesis/{file}.nem').read_bytes()))
		# Full authored timings already have native source comparisons. Here actors
		# land through the real frame executor and independently release from a group.
		for code,sub,state,height in [('SMZ_VanishPlatform',0x103,'Vanish_Cycle',17),('SMZ_SpinConvey',0x100,'PlatformGroup_TimedSolid',6),('SMZ_SpinConvey',0x101,'MMZ_SpinC_MoveSolid',6)]:
			a=setup(code,sub)
			for _ in range(450):
				state_ready=g.get(a,'platgroup_state',4)==g.s[state]
				if code=='SMZ_VanishPlatform':state_ready=state_ready and g.get(a,'vanish_contact',2)==0x101
				if state_ready and g.get(a,'platgroup_timer',2)>30:break
				if state=='MMZ_SpinC_MoveSolid':break
				g.run()
			else:raise AssertionError(('state-timeout',code))
			for actor in ('v_player','v_player2'):
				place(g,actor,g.get(a,'obX',2),g.get(a,'obY',2)-height-g.get(actor,'default_y_radius'));g.put(actor,'obControl',1)
			g.run(3)
			assert g.get(a,'obStatus')&0x18==0x18,('both-riders',era,code,sub,hex(g.get(a,'obStatus')))
			for actor in ('v_player','v_player2'):assert g.get(actor,'obStatus')&8,(era,code,actor)
			g.run(5);assert g.get(a,'obStatus')&0x18==0x18
			g.video.save((args.output/'objects')/f'era{era}-{sub:03X}-{code}.png')
			# Move Sonic off; Tails remains on the same moving/vanishing surface.
			g.put('v_player','obX',g.get(a,'obX',2)-80,2);g.run()
			assert not g.get(a,'obStatus')&8 and g.get(a,'obStatus')&16,(era,code,'independent-support')
			for _ in range(450):
				if not g.get(a,'obStatus')&16:break
				g.run()
			else:raise AssertionError((code,'did-not-release'))
			assert not g.get('v_player2','obStatus')&8
			assert not g.read('v_errortype')
			report.append(dict(era=era,code=code,subtype=sub,both_landed=True,independent_release=True))
		# Existing art is relocated, not copied; all propeller blades inherit it.
		a=setup('MM_Propeller',0);g.run(3)
		assert g.get(a,'obGfx',2)==g.s['ArtTile_MMZ_Propeller']
		for f in ('prop_upper','prop_lower'):assert g.get(g.get(a,f,2),'obGfx',2)==g.get(a,'obGfx',2)
		a=setup('MorphingPlatform',0);assert g.get(a,'obGfx',2)==g.s['ArtTile_MMZ_HVPlatform']
		assert g.get(a,'code')==g.s['MorphingPlatform_Run']
		morph = g.save()
		shapes = [struct.unpack_from('>4B',bytes(g.rom),g.s['HVPlat_StateTable']+i*4) for i in range(12)]
		actors = (('v_player',3),('v_player2',4))
		x,y = g.get(a,'obX',2),g.get(a,'obY',2)
		def pose(phase):
			# A restored late-scene companion may be in catch-up flight. Start
			# both actors visible and under manual control before contact setup.
			g.restore(morph)
			reset_cpu(g)
			g.write('Tails_CPU_idle_timer',600,2)
			g.write('Tails_CPU_interact',g.s['MorphingPlatform_Run'],4)
			for actor,bit in actors:g.put(actor,'obRender',0x84)
			frame,duration,width,height = shapes[phase]
			for f,v in (('mplat_state',phase),('mplat_timer',100),('obFrame',frame),
				('obWidth',width),('obActWid',width),('obHeight',height),('obStatus',0)):
				g.put(a,f,v)
			return width,height
		def attach(actor,bit,dx=0):
			place(g,actor,x+dx,y-g.get(a,'obHeight')-g.get(actor,'default_y_radius'),airborne=False)
			g.put(actor,'obControl',1)
			g.put(actor,'obStatus',8)
			g.put(actor,'standonobject',((a&65535)-(g.s['v_objspace']&65535))//g.s['object_size'])
			g.put(a,'obStatus',g.get(a,'obStatus')|(1<<bit))
		for phase in range(12):
			for owner,bit,other in (('v_player',3,'v_player2'),('v_player2',4,'v_player')):
				for side in (-1,1):
					width,height = pose(phase)
					attach(owner,bit)
					place(g,other,x+side*(width+8),y,airborne=False)
					g.put(other,'obControl',1)
					g.put(other,'obVelX',(-side*0x100)&65535,2)
					g.run(2)
					assert g.get(other,'obX',2)==x+side*(width+16),(era,phase,owner,side,'morph side contact')
					assert g.get(other,'obStatus')&32,(era,phase,owner,side,'morph push')
					assert g.get(owner,'obStatus')&8 and g.get(a,'obStatus')&(1<<bit),(era,phase,owner,side,'morph rider')
					assert g.get(owner,'obY',2)==y-height-g.get(owner,'default_y_radius')
					if phase in (0,6):g.video.save((args.output/'objects')/f'era{era}-morph-pose{phase}-{owner}-side{side}.png')
					g.put(owner,'obX',x+side*(width+1),2)
					g.run()
					assert not g.get(owner,'obStatus')&8 and not g.get(a,'obStatus')&(1<<bit),(era,phase,owner,side,'morph edge release')
					report.append(dict(era=era,code='MorphingPlatform',phase=phase,owner=owner,side=side,
						independent_side_contact=True,raw_standing_edge=True))
			for sonic_side in (-1,1):
				for airborne in (False,True):
					width,height = pose(phase)
					for actor,bit in actors:
						side = sonic_side if bit==3 else -sonic_side
						place(g,actor,x+side*(width+8),y,airborne=airborne)
						g.put(actor,'obControl',1)
						g.put(actor,'obVelX',(-side*0x100)&65535,2)
					for tick in range(8):
						g.run()
						assert g.get(a,'obStatus')&0x60==(0 if airborne else 0x60),(era,phase,sonic_side,airborne,tick,'both push')
						for actor,bit in actors:
							side = sonic_side if bit==3 else -sonic_side
							assert g.get(actor,'obX',2)==x+side*(width+16)
							assert g.get(actor,'obY',2)==y
							assert bool(g.get(actor,'obStatus')&32)==(not airborne)
					if phase in (0,6) and not airborne:g.video.save((args.output/'objects')/f'era{era}-morph-pose{phase}-opposed{sonic_side}.png')
					if not airborne:
						for actor,bit in actors:
							side = sonic_side if bit==3 else -sonic_side
							g.put(actor,'obX',x+side*(width+17),2)
							g.run()
							assert not g.get(a,'obStatus')&(1<<(bit+2)) and not g.get(actor,'obStatus')&32
							assert g.get(a,'obStatus')&(0x40 if bit==3 else 0x20)
							g.put(actor,'obX',x+side*(width+16),2)
							g.run()
							assert g.get(a,'obStatus')&0x60==0x60
					report.append(dict(era=era,code='MorphingPlatform',phase=phase,sonic_side=sonic_side,
						airborne=airborne,simultaneous_side_contacts=True))
		pose(0)
		for actor,bit in actors:attach(actor,bit,-4 if bit==3 else 4)
		g.put(a,'mplat_timer',shapes[0][1])
		for tick in range(sum(shape[1] for shape in shapes)):
			g.run()
			assert g.get(a,'obStatus')&0x18==0x18,(era,tick,'morph simultaneous riders')
			for actor,bit in actors:
				assert g.get(actor,'obStatus')&8
				assert g.get(actor,'obY',2)==y-g.get(a,'obHeight')-g.get(actor,'default_y_radius')
		assert not g.read('v_errortype')
		report.append(dict(era=era,code='MorphingPlatform',both_rider_timeline=336))
		# Let both complete character movement paths run under opposing held
		# inputs. A flat RAM terrain fixture supports their different radii.
		rom = bytes(g.rom)
		indices = g.read('v_colladdr1',4)
		block = next(b for b in range(1,551) if set(rom[g.s['ColArray1']+rom[indices+b*2]*16:
			g.s['ColArray1']+(rom[indices+b*2]+1)*16])=={16})|0xF000
		for phase in (0,6):
			for sonic_side in (-1,1):
				width,height = pose(phase)
				chunks = g.terrain_address('chunks')
				for row in range(8):
					for col in range(8):g.write(chunks+1023*128+row*16+col*2,block if row==7 else 0,2)
				for col in range(3,7):g.layout_cell(4,col,1023)
				for actor,bit in actors:
					side = sonic_side if bit==3 else -sonic_side
					place(g,actor,x+side*(width+12),624-g.get(actor,'default_y_radius'),airborne=False)
					g.put(actor,'obVelX',(-side*0x100)&65535,2)
					g.put(actor,'obInertia',(-side*0x100)&65535,2)
				g.buttons = {7 if sonic_side<0 else 6}
				g.buttons2 = {6 if sonic_side<0 else 7}
				for tick in range(60):
					g.run()
					assert g.get(a,'obStatus')&0x60==0x60,(era,phase,sonic_side,tick,'controller push',
						[(p,g.get(p,'obX',2),g.get(p,'obY',2),g.get(p,'obStatus'),g.get(p,'obControl')) for p,b in actors])
					for actor,bit in actors:
						side = sonic_side if bit==3 else -sonic_side
						assert g.get(actor,'obX',2)==x+side*(width+16)
						assert g.get(actor,'obStatus')&32 and not g.get(actor,'obStatus')&2
				g.video.save((args.output/'objects')/f'era{era}-morph-pose{phase}-controllers{sonic_side}.png')
				report.append(dict(era=era,code='MorphingPlatform',phase=phase,sonic_side=sonic_side,
					opposed_controller_frames=60))
	g.close()
	return report


def hazard_native(args):
	"""Compare motion against CD routines and its complete sine table."""
	import re
	R=ROOT;S=args.source;n=Native(args.rom,args.listing);slots=list(range(n.s['v_lvlobjspace']&0xffffff,n.s['v_lvlobjend']&0xffffff,n.s['object_size']));root=slots[5];count=0
	def call(name,a=root):
		n.act(name,a,regs={UC_M68K_REG_D7:0x3579006f});assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006f
		assert n.get(a,'code')
	def init(entry,sub,flip=0,zone=0):
		n.start();n.write('Current_Zone',zone);n.put(root,'code',n.s[entry]);n.put(root,'obX',600,2);n.put(root,'obY',600,2);n.put(root,'obSubtype',sub);n.put(root,'obStatus',flip)
		for a in ('v_player','v_player2'):n.put(a,'obX',100,2);n.put(a,'obY',100,2)
		call(entry)
	class CDSaw:
		def __init__(self,extended):
			self.routine=4 if extended else 8;self.timer=59;self.steps=0;self.anim=9 if extended else 0;self.x=1;self.prev=-1;self.at=0;self.wait=0;self.frame=0;self.animate()
		def animate(self):
			if self.anim!=self.prev:self.prev=self.anim;self.at=0;self.wait=0
			self.wait-=1
			if self.wait<0:self.wait=1;self.frame=min(self.anim,8)*2+self.at%2;self.at+=1
		def step(self):
			self.timer-=1
			if self.routine in (2,6):
				delta=1 if self.routine==2 else -1
				if self.timer==0:
					self.anim+=delta;self.timer=9;self.steps-=1
					if self.steps==0:self.routine+=2;self.timer=60
				self.x+=delta
			elif self.timer==0:
				self.routine=6 if self.routine==4 else 2;self.timer=1;self.steps=9
			self.animate()
	for flip in range(4):
		for extended in range(2):
			init('SMZ_Saws',0x216+(extended<<7),flip,zone=15);ref=CDSaw(extended)
			child=n.get(root,'saw_handle',2)|0xff0000
			assert n.get(child,'saw_parent',2)==root&65535
			for tick in range(1600):
				if tick:ref.step();call(n.get(root,'code'))
				assert (n.get(root,'obX',2),n.get(root,'obY',2),n.get(root,'obFrame'))==(600+ref.x*(-1 if flip&1 else 1),600+ref.x*(-1 if flip&2 else 1),ref.frame),('saw',flip,extended,tick,ref.__dict__)
				call('Saw_Handle',child);count+=1
			expected=[600-(80 if extended else 0)*(-1 if flip&b else 1) for b in (1,2)]
			assert [n.get(child,f,2) for f in ('obX','obY')]==expected
			assert n.get(root,'obColType')&63==n.s['Touch_Size_MMZSaw_ID']
			n.put(root,'saw_handle',0,2);n.act('Saw_Handle',child);assert not n.get(child,'code')
	# Exact source heights, including negative rounding and asymmetric source angles.
	text=(S/'src/common/math.asm').read_text().split('SineTable:',1)[1].split('Atan2:',1)[0];sine=[]
	for line in text.splitlines():
		m=re.search(r'dc.w\s+(.+)',line.split(';',1)[0])
		if m:sine.extend(int(v.strip().replace('$','0x'),0) for v in m[1].split(','))
	for amplitude in (32,48):
		init('SMZ_ScrapStomp',0x100+(64 if amplitude==48 else 0))
		for phase in range(1024):
			n.put(root,'MMZ_crush_phase',phase,2);n.act('MMZ_Crusher_Position',root)
			from native_test_core import UC_M68K_REG_D0
			assert n.cpu.reg_read(UC_M68K_REG_D0)&65535==600+sine[phase>>2]*amplitude//256
	for mode in (0,1,2):
		for amplitude in (32,48):
			for initial in range(4):
				for speed in range(4):
					sub=0x100+mode+(64 if amplitude==48 else 0)+(initial<<4)+(speed<<2)
					init('SMZ_ScrapStomp',sub)
					phase=initial*256;step=(4,8)[speed&1] if mode==1 else (4,8,16,32)[speed];pause=0;paused=False;hold=90 if speed&2 else 60
					for tick in range(500):
						if mode==1 and paused:
							pause-=1
							if pause<0:paused=False;phase=(phase+step)&1023
						elif mode==1 and phase in (256,768):paused=True;pause=hold
						else:phase=(phase+step)&1023
						call('Stomper_Run');assert n.get(root,'MMZ_crush_phase',2)==phase,('crusher-phase',mode,amplitude,initial,speed,tick,phase,n.get(root,'MMZ_crush_phase',2))
						assert n.get(root,'obY',2)==600+sine[phase>>2]*amplitude//256
						count+=1
	# Actual source radius rather than blindly keeping a foreign collision index.
	rom=(R/'s2built.bin').read_bytes();at=n.s['Touch_Sizes']+(n.s['Touch_Size_MMZSaw_ID']-1)*2;assert rom[at:at+2]==bytes((28,28))
	return dict(source_motion_updates=count,source_height_cases=2048,source_saw_half_size=28,object_loop_counter_preserved=True)

def configured_saws(args):
	"""Check fixed-point travel, selectable dwells and the one-slot blade."""
	n = Native(args.rom, args.listing)
	s = n.s
	root = (s['v_lvlobjspace'] & 0xFFFFFF) + 5 * s['object_size']
	start = (600 << 16 | 0x2000, 600 << 16 | 0x6000)
	bare_metal_frame = s['Map_MMZ_Saw_frames'] - 2
	cases = updates = 0
	for metal in (False, True):
		for motion in range(3):
			for value in range(16):
				for timed in (False, True):
					flip = value & 3
					far = bool(value & 8)
					axis = motion + 1 if value else 0
					reserved = 0xF060 if value & 4 else 0
					subtype = reserved | (motion << 8) | (far << 7) | (timed << 4) | value
					n.start()
					n.write('Current_Zone', 15 if metal else 8)
					for field, field_value, size in (
						('code', s['SMZ_Saws'], 4), ('obX', start[0], 4), ('obY', start[1], 4),
						('obSubtype', subtype, 2), ('obStatus', flip, 1),
					):
						n.put(root, field, field_value, size)
					n.act('SMZ_Saws', root)
					rail = metal and axis == 3
					assert bool(n.get(root, 'saw_handle', 2)) == rail, subtype
					assert n.get(root, 'obMap', 4) == s['Map_MMZ_Saw' if metal else 'Map_SMZ_Saw']
					assert n.get(root, 'obColType') == (0x80 | (s['Touch_Size_MMZSaw_ID'] if metal else 0x22))
					signs = tuple(-1 if flip & bit else 1 for bit in (1, 2))
					xy = [origin + (sign << 16 if rail else 0) for origin, sign in zip(start, signs)]
					directions = [
						sign * (-1 if far else 1) if axis & bit else 0
						for bit, sign in zip((1, 2), signs)
					]
					stroke = (73 if rail else 80) << 8
					speed = 0x100 if timed or not value else value * 0x40
					wait = value * 10 if timed else 0
					remaining = stroke
					hold = max(0, wait - 1)
					start_frame = n.get(root, 'obFrame')
					leg_ticks = (stroke + speed - 1) // speed
					for tick in range(48 if axis == 0 else 2 * leg_ticks + 3 * wait + 2):
						if tick and axis:
							if hold:
								hold -= 1
							else:
								step = min(remaining, speed)
								for i in range(2):
									xy[i] += directions[i] * (step << 8)
								remaining -= step
								if remaining == 0:
									directions = [-direction for direction in directions]
									remaining = stroke
									hold = wait
						if tick:
							n.act(n.get(root, 'code'), root, regs={UC_M68K_REG_D7: 0x3579006f})
							assert n.cpu.reg_read(UC_M68K_REG_D7) == 0x3579006f
						assert (n.get(root, 'obX', 4), n.get(root, 'obY', 4)) == tuple(xy), (metal, subtype, tick, xy)
						frame = n.get(root, 'obFrame')
						if axis == 0:
							assert n.get(root, 'code') == s['Saw_Draw'] and frame == start_frame
						elif not rail:
							first = bare_metal_frame if metal else 2
							assert frame in (first, first + 1), (metal, subtype, frame)
						updates += 1
					if rail:
						assert n.get(root, 'obFrame') < bare_metal_frame
					cases += 1

	# A rail retries atomically under slot pressure. A plain blade can use
	# the last slot without depending on a secondary object.
	n.start()
	for a in range(s['v_lvlobjspace'] & 0xFFFFFF, s['v_lvlobjend'] & 0xFFFFFF, s['object_size']):
		n.put(a, 'code', s['Saw_Draw'])
	n.put(root, 'code', s['SMZ_Saws'])
	n.put(root, 'obX', 600, 2)
	n.put(root, 'obY', 600, 2)
	n.write('Current_Zone', 15)
	n.put(root, 'obSubtype', 0x204)
	before = bytes(n.cpu.mem_read(root, s['object_size']))
	n.act('SMZ_Saws', root)
	assert bytes(n.cpu.mem_read(root, s['object_size'])) == before
	n.put(root, 'obSubtype', 0x104)
	n.act('SMZ_Saws', root)
	assert n.get(root, 'code') == s['Saw_Travel'] and not n.get(root, 'saw_handle', 2)
	return dict(configurations=cases, travel_updates=updates, rail_pool_retry=True)


def legacy_hazards(args):
	"""Compare retained S1 behavior with a matching pre-port ROM/listing."""
	old=Native(args.before_rom,args.before_listing);new=Native(args.rom,args.listing);cases=updates=0
	for entry,params in [('SMZ_Saws',range(5)),('SMZ_ScrapStomp',(0,0x13,0x24,0x34,0x40,0x80,0x81,0x83,0x88)),('Obj1B',(0,1))]:
		for param in params:
			for flip in range(4):
				objects=[]
				for n in (old,new):
					n.start();a=n.s['v_lvlobjspace']&0xffffff;objects.append(a)
					subtype = legacy_saw_subtype(param) if n is new and entry == 'SMZ_Saws' else param
					for f,v,z in [('code',n.s[entry],4),('obX',600,2),('obY',600,2),('obSubtype',subtype,2),('obStatus',flip,1)]:n.put(a,f,v,z)
					for who in ('v_player','v_player2'):n.put(who,'obX',100,2);n.put(who,'obY',100,2)
				if entry=='SMZ_Saws' and param>=3:
					for n in (old,new):n.put('v_player','obX',1000 if param==3 else 0,2);n.put('v_player','obY',600,2)
				for tick in range(600):
					for n,a in zip((old,new),objects):
						n.write('v_framecount',tick,2)
						n.cpu.mem_write((n.s['v_oscillate']+6)&0xFFFFFF,bytes([tick%48]));n.cpu.mem_write((n.s['v_oscillate']+14)&0xFFFFFF,bytes([tick%96]))
						for channel in (0,1,3,8):n.cpu.mem_write((n.s['f_switch']+channel)&0xFFFFFF,bytes([1 if 30<=tick<100 else 0]))
						if n.get(a,'code'):
							n.put(a,'obRender',0x84)
							n.act(n.get(a,'code'),a,regs={UC_M68K_REG_D7:0x3579006f})
							assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006f
					for field,size in [('obX',4),('obY',4),('obVelX',2),('obVelY',2),('obRoutine',1),('ob2ndRout',1),('obFrame',1),('obAnim',2),('obTimeFrame',2),('obStatus',1),('obColType',2)]:
						assert old.get(objects[0],field,size)==new.get(objects[1],field,size),(entry,param,flip,tick,field,old.get(objects[0],field,size),new.get(objects[1],field,size))
					assert bool(old.get(objects[0],'code'))==bool(new.get(objects[1],'code'))
					updates+=1
					if not old.get(objects[0],'code'):break
				cases+=1
	return dict(legacy_variants=cases,matching_updates=updates)

def hazard_game(args):
	"""Verify live harmful contacts, clearance and both crusher launch strengths."""
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_companion_followup import isolate,spawn,place
	g=Genesis(args.core,args.rom,args.listing,args.output/'hazards',args.pal,
		system_directory=args.system_directory)
	initial=g.save();report=[]
	def setup(code,sub,flip=0):
		isolate(g);g.placement_write(0,int.from_bytes(b'\x80'*g.placement_capacity(),'big'),g.placement_capacity())
		for actor in ('v_player','v_player2'):place(g,actor,600,500);g.put(actor,'obControl',0x81)
		g.write('Camera_X_pos',440,2);g.write('Camera_X_pos_coarse_back',256,2);g.write('Camera_Y_pos',480,2)
		a=spawn(g,code,600,600,sub);g.put(a,'obStatus',flip);g.put(a,'obRender',4|flip)
		for _ in range(30):
			g.run()
			if g.get(a,'code')!=g.s[code]:break
		else:raise AssertionError(('init',code))
		return a
	for era in range(4):
		g.restore(initial);boot_level(g,zone=15,timezone=era)
		for flip in range(4):
			a=setup('SMZ_Saws',0x216,flip);g.run(4);g.put(a,'saw_timer',200,2);base=g.save()
			for who in ('v_player','v_player2'):
				for dx,dy,hit in ((0,0,True),(52,0,False),(0,64,False)):
					g.restore(base);other='v_player' if who=='v_player2' else 'v_player2'
					place(g,other,500,500);g.put(other,'obControl',0x81)
					place(g,who,g.get(a,'obX',2)+dx,g.get(a,'obY',2)+dy);g.put(who,'obControl',1);g.put(who,'obStatusSecondary',0);g.put(who,'obRender',0x84)
					g.buttons2={4};g.run(4)
					assert (g.get(who,'obRoutine')==4)==hit,('saw-contact',era,flip,who,dx,dy,hit,g.get(who,'obRoutine'))
				report.append(dict(era=era,flip=flip,actor=who,blade_contact_and_clearance=True))
			g.restore(base);g.video.save((args.output/'hazards')/f'era{era}-saw-flip{flip}.png')
		for weak in range(2):
			a=setup('SMZ_ScrapStomp',0x101+(weak<<7));g.put(a,'MMZ_crush_phase',0x20C,2)
			table=g.get(a,'MMZ_crush_heights',4);raw=g.read(table+(0x20C>>2));dy=raw-256 if raw&128 else raw;g.put(a,'obY',600+dy,2)
			for who in ('v_player','v_player2'):
				place(g,who,600,g.get(a,'obY',2)-97-g.get(who,'default_y_radius'));g.put(who,'obControl',1);g.put(who,'obRender',0x84)
			g.buttons2={4}
			for _ in range(20):
				g.run()
				if g.get(a,'MMZ_crush_phase',2)!=0x20C:break
			assert g.get(a,'MMZ_crush_phase',2)==0x210
			for who in ('v_player','v_player2'):
				assert g.get(who,'obVelY',2)==((-0xA00 if weak else -0x1000)&65535),('launch',era,weak,who,g.get(who,'obVelY',2),hex(g.get(a,'obStatus')))
				assert g.get(who,'obStatus')&2 and not g.get(who,'obStatus')&8
			g.video.save((args.output/'hazards')/f'era{era}-crusher-launch{weak}.png');report.append(dict(era=era,weak=weak,both_launched=True))
		assert not g.read('v_errortype')
	g.close()
	return report


def spike_beds_native(args):
	n = Native(args.rom, args.listing)
	s = n.s
	spike = s['v_lvlobjspace']
	slot = (spike-s['v_objspace'])//s['object_size']
	paths = (0, s['Object_FilterPath'], s['Object_FilterPath']|s['Object_SecondaryPath'])
	actors = (('v_player', 19, 8), ('v_player2', 15, 16))

	def setup(flags, inverted, actor, radius, path):
		n.start()
		n.write('Camera_X_pos_coarse_back', 384, 2)
		n.write('v_rings', 10, 2)
		n.put(spike, 'code', s['Spikes'])
		n.put(spike, 'obX', 600, 2)
		n.put(spike, 'obY', 500, 2)
		n.put(spike, 'obSubtype', 0xE0|flags)
		n.put(spike, 'obStatus', 2 if inverted else 0)
		n.put(spike, 'obRender', 0x86 if inverted else 0x84)
		n.act('Spikes', spike)
		assert n.get(spike, 'obMap', 4) == s['Map_Obj36']
		assert n.get(spike, 'obRoutine') == (8 if inverted else 10)
		assert n.get(spike, 'obHeight') == 8
		assert bool(n.get(spike, 'obGfx', 2) & 0x8000) == (flags == paths[1])
		n.put(actor, 'obX', 600, 2)
		n.put(actor, 'obHeight', radius)
		n.put(actor, 'obTopSolidBit', 12+path*2)
		n.put(actor, 'obLRBSolidBit', 13+path*2)
		n.put(actor, 'obStatus', 2)

	for flags in paths:
		for actor, radius, bit in actors:
			for path in range(2):
				matches = flags in (0, paths[path+1])
				setup(flags, False, actor, radius, path)
				n.put(actor, 'obY', 492-radius, 2)
				n.put(actor, 'obVelY', 0x100, 2)
				n.act('Spikes', spike)
				assert n.get(actor, 'obRoutine') == (4 if matches else 2), (flags, actor, path, 'landing')
				if not matches:
					assert n.get(actor, 'obY', 2) == 492-radius
					assert not (n.get(spike, 'obStatus') & bit)

				setup(flags, False, actor, radius, path)
				n.put(actor, 'obStatus', 0)
				n.put(actor, 'obX', 626, 2)
				n.put(actor, 'obY', 500, 2)
				n.put(actor, 'obVelX', -0x100, 2)
				n.act('Spikes', spike)
				assert n.get(actor, 'obRoutine') == 2, (flags, actor, path, 'walk against side')
				assert n.get(actor, 'obX', 2) == (627 if matches else 626)

				for dense in (False, True):
					setup(flags, True, actor, radius, path)
					n.put(actor, 'obY', 522, 2)
					n.write('Collision_response_list', 0xFFFF if dense else 2, 2)
					n.cpu.mem_write((s['Collision_response_list'] & 0xFFFFFF)+2, struct.pack('>H', spike & 0xFFFF))
					n.act('TouchResponse', actor)
					assert n.get(actor, 'obRoutine') == (4 if matches else 2), (flags, actor, path, dense)

	for actor, radius, bit in actors:
		setup(paths[2], False, actor, radius, 0)
		n.put(actor, 'obStatus', 8)
		n.put(actor, 'standonobject', slot)
		n.put(spike, 'obStatus', bit)
		n.act('Spikes', spike)
		assert n.get(actor, 'obStatus') & 10 == 2
		assert not (n.get(spike, 'obStatus') & bit)
	return {'floor_damage': True, 'floor_sides_safe': True, 'inverted_damage': True,
		'collision_paths': 2, 'both_characters': True, 'off_path_riders_released': True}


def seesaw_game(args):
	"""Visit all three authored caps and exercise each with both characters."""
	from check_companion_followup import place, reset_cpu
	from check_object_course import boot_level
	from check_rising_crushers import ACTORS, seek
	from genesis_test_core import Genesis
	from object_layout import decode

	output = args.output/'seesaws'
	g = Genesis(args.core, args.rom, args.listing, output, args.pal, system_directory=args.system_directory)
	initial = g.save()
	s = g.s
	slots = range(s['v_lvlobjspace'] & 0xFFFF, s['v_lvlobjend'] & 0xFFFF, s['object_size'])
	traps = [(x, y) for x, y, oid, eras, sub in decode((ROOT/'level/objects/LV0F_1.bin').read_bytes())
		if oid == 0xBC and eras == 0xE0 and sub == 0]
	assert len(traps) == 3
	for era in range(4):
		g.restore(initial)
		g.buttons, g.buttons2 = set(), set()
		boot_level(g, zone=15, timezone=era)
		level = g.save()
		for x, y in traps:
			g.restore(level)
			seek(g, x, y)
			root = next(slot for slot in slots if g.get(slot, 'platgroup_state', 4) == s['MMZ_Seesaw_Base']
				and (g.get(slot, 'obX', 2), g.get(slot, 'obY', 2)) == (x, y))
			ball, cap = divmod(g.get(root, 'platgroup_members', 4), 65536)
			assert g.get(cap, 'obY', 2) == y-44 and g.get(ball, 'obFrame') == 5
			scene = g.save()
			for index, actor in enumerate(ACTORS):
				g.restore(scene)
				reset_cpu(g)
				g.buttons2 = {4}
				g.put(actor, 'obRender', 0x84)
				place(g, actor, x, y-44-12-g.get(actor, 'default_y_radius'))
				g.put(actor, 'obControl', 1)
				for _ in range(6):
					g.run()
					if g.get(root, 'obRoutine'):
						break
				assert g.get(root, 'obRoutine') == 2 and g.get(cap, 'obStatus') & (8 << index), (era, x, y, actor)
				g.put(actor, 'obControl', 0x81)
				g.run(55)
				assert g.get(ball, 'obFrame') == 7 and g.get(ball, 'obColType')
				assert (y-g.get(ball, 'obY', 2)) & 0x7FF > 0x100
				for _ in range(60):
					g.run()
					if g.get(ball, 'platgroup_state', 4) == s['MMZ_Seesaw_Idle']:
						break
				assert g.get(ball, 'obY', 2) == y+4 and g.get(cap, 'obY', 2) == y+28
				assert not g.read('v_errortype')
			if era == 0:
				g.video.save(output/f'{x:04x}-{y:04x}.png')
	g.close()
	return dict(placements=traps, eras=4, actor_launches=24)


def spike_beds_game(args):
	from check_object_course import boot_level
	from check_rising_crushers import seek
	from object_layout import decode
	from genesis_test_core import Genesis

	output = args.output/'spike-beds'
	g = Genesis(args.core, args.rom, args.listing, output, args.pal, system_directory=args.system_directory)
	initial = g.save()
	s = g.s
	slots = range(s['v_lvlobjspace'] & 0xFFFF, s['v_lvlobjend'] & 0xFFFF, s['object_size'])
	report = []
	for act, expected in ((1, 33), (2, 55)):
		rows = [r for r in decode((ROOT/f'level/objects/LV0F_{act}.bin').read_bytes())
			if r[2] == 0x15 and r[4] & 0xF0 == 0xE0]
		assert len(rows) == expected
		for era, mask in enumerate((0x40, 0x20, 0x80, 0x80)):
			g.restore(initial)
			g.buttons, g.buttons2 = set(), set()
			boot_level(g, zone=15, act=act-1, timezone=era)
			level = g.save()
			seen = 0
			shots = set()
			for x, y, _, presence, subtype in rows:
				if not presence & mask:
					continue
				inverted = bool(y & 0x4000)
				y &= 0xFFF
				g.restore(level)
				seek(g, x, max(132, y))
				bed = next(slot for slot in slots if g.get(slot, 'code') == s['Spikes']
					and g.get(slot, 'obX', 2) == x and g.get(slot, 'obY', 2) == y)
				assert g.get(bed, 'obRoutine') == (8 if inverted else 10), (act, era, x, y)
				assert g.get(bed, 'obHeight') == 8 and not g.read('v_errortype')
				assert bool(g.get(bed, 'obRender') & 2) == inverted
				assert g.get(bed, 'obSubtype', 2) == subtype
				assert bool(g.get(bed, 'obGfx', 2) & 0x8000) == bool(subtype & 0x1000 and not subtype & 0x800)
				if inverted not in shots and g.get(bed, 'obRender') & 0x80:
					g.video.save(output/f'act{act}-era{era}-inverted{int(inverted)}.png')
					shots.add(inverted)
				seen += 1
			report.append(dict(act=act, era=era, placements=seen))
	g.close()
	return report


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
	p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--output',type=Path,required=True)
	p.add_argument('--before-rom',type=Path,help='Optional pre-port ROM for retained S1 hazard comparison')
	p.add_argument('--before-listing',type=Path,help='Listing matching --before-rom')
	p.add_argument('--source',type=Path,help='Compare animation timing/payloads with scddisasm test')
	p.add_argument('--core',type=Path)
	p.add_argument('--system-directory',type=Path)
	p.add_argument('--pal',action='store_true')
	args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
	report=dict(native=native(args),placements=placement_native(args),ring_layouts=ring_layouts(args),
		morphing_platform=morph_native(args),configured_saws=configured_saws(args),spike_beds=spike_beds_native(args))
	if args.source:
		report['animations']=animation_checks(args)
		report['platforms']=platform_native(args)
		report['hazards']=hazard_native(args)
		report['floors_and_wheels']=floor_wheel_native(args)
	if args.core:
		report['game']=game(args)
		report['authored_game']=authored_game(args)
		report['platform_game']=platform_game(args)
		report['hazard_game']=hazard_game(args)
		report['floor_wheel_game']=floor_wheel_game(args)
		report['spike_beds_game']=spike_beds_game(args)
		report['seesaws']=seesaw_game(args)
	if args.before_rom or args.before_listing:
		assert args.before_rom and args.before_listing,'Supply the matching ROM and listing together'
		report['retained_s1_hazards']=legacy_hazards(args)
	(args.output/'report.json').write_bytes((json.dumps(report,indent=2)+'\n').replace('\n','\r\n').encode())
	print(json.dumps(report,indent=2))


if __name__=='__main__':main()
