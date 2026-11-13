#!/usr/bin/env python3
"""Check Metallic Madness's actual era bindings, parallax and visible tilemaps.

Native cases run the assembled MD hscroll function and CD source provider.
Optional game cases enter zone $0F through level select and compare visible
VDP tiles against authored terrain, including chunk IDs above $FF. Staged
camera visits are rendering fixtures, not a controller-only level playthrough.
"""
from pathlib import Path
import argparse
import ctypes as C
import json
import struct

from convert_s1_ss_background import kosinski_plus_decode
from level_layout import load
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
		expected=[(n.s['Kospm_MMZ1_Atlas'],n.s['ArtTile_MMZ_Atlas']*32)]
		if era==1:expected.append((n.s['Kospm_MMZ1_GeneratorPast'],n.s['ArtTile_MMZ_Generator']*32))
		elif era==2:
			expected.extend([(n.s['Kospm_MMZ1_SawGoodFuture'],n.s['ArtTile_MMZ_Saw']*32),
				(n.s['Kospm_MMZ1_SeesawGoodFuture'],n.s['ArtTile_MMZ_Seesaw']*32)])
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
	for label,tiles in [('ArtTile_MMZ_Atlas',505),('ArtTile_Ring',32),('ArtTile_Monitor',24),('ArtTile_Monitor_Icons',16),('ArtTile_Tails_Life',4),('ArtTile_Spikes',16)]:
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


def animation_checks(args):
	"""Compare the assembled VM's writes and DMA requests with CD source steps."""
	from import_metallic_madness import animations,table_values,number
	import re
	n=Native(args.rom,args.listing);rom=args.rom.read_bytes()
	_,reference=animations(args.source,(ROOT/'_definitions/s2.constants.asm').read_text())
	writes=updates=0
	for era,(key,title,_) in enumerate(ERAS):
		n.start();n.write('Current_ZoneAndAct',0xF00,2);n.write('Current_Timezone',era)
		initial=(ROOT/'palette/SonicAndTails.bin').read_bytes()+(ROOT/f'palette/MMZ1 {title}.bin').read_bytes()
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
		data=(args.source/f'src/r8/data_1{letter}.asm').read_text()
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
		# Other acts keep their existing callbacks; MMZ1 tables must not run.
		n.write('Current_Act',1);before=bytes(n.cpu.mem_read(n.s['v_palette']&0xFFFFFF,128))
		n.act('PalCycle_Load');n.act('Animate_Tiles')
		assert not n.uploads and n.cpu.mem_read(n.s['v_palette']&0xFFFFFF,128)==before
	return dict(eras=4,updates_per_era=1200,palette_changes=writes,dma_transfers=updates,
		shared_animated_tiles=reference['tiles'])


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
	def init(entry,sub,idx=5):
		n.start();root=slots()[idx];n.put(root,'code',n.s[entry]);n.put(root,'obX',600,2);n.put(root,'obY',300,2);n.put(root,'obSubtype',sub)
		for a in ('v_player','v_player2'):n.put(a,'obX',100,2);n.put(a,'obY',100,2)
		n.act(entry,root,regs={UC_M68K_REG_D7:0x3579006F})
		assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006F,'Constructor changed the object-loop counter'
		return root,[a for a in slots() if n.get(a,'code')==n.s['MMZ_Platform_Run']]
	def update(a):
		n.act('MMZ_Platform_Run',a,regs={UC_M68K_REG_D7:0x3579006F})
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
		root,members=init('SMZ_VanishPlatform',0x100+variant)
		assert len(members)==len(timers)
		members=[root]+[int.from_bytes(n.cpu.mem_read(root+n.s['MMZ_group_members']+i*2,2),'big')|0xff0000 for i in range(len(timers)-1)]
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
				assert bool(n.get(a,'MMZ_group_state',4)==n.s['MMZ_VanP_Stand'])==bool(ref['state']=='stand')
				checks+=1
		n.act('MMZ_Platform_Unload',root,regs={UC_M68K_REG_D7:0x3579006F})
		assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006F
		assert all(not n.get(a,'code') for a in members)
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
	members=[root]+[(int.from_bytes(n.cpu.mem_read(root+n.s['MMZ_group_members']+i*2,2),'big')|0xff0000) for i in range(4)]
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
	for entry,sub,count in (('SMZ_VanishPlatform',0x102,2),('SMZ_SpinConvey',0x101,4)):
		for free in range(count):
			n.start();ss=slots();root=ss[6]
			for a in ss:n.put(a,'code',n.s['PlayMusic'])
			for a in ss[:free]:n.put(a,'code',0)
			n.put(root,'code',n.s[entry]);n.put(root,'obX',600,2);n.put(root,'obY',300,2);n.put(root,'obSubtype',sub)
			before=bytes(n.cpu.mem_read(ss[0],len(ss)*n.s['object_size']));n.act(entry,root)
			assert bytes(n.cpu.mem_read(ss[0],len(before)))==before
	# A live same-family replacement at the same address cannot adopt a stale child.
	root,members=init('SMZ_VanishPlatform',0x101);child=next(a for a in members if a!=root)
	n.cpu.mem_write(root+n.s['MMZ_group_members'],b'\0'*8);update(child);assert not n.get(child,'code')
	report['platform_updates']=checks;report['allocation_failure_and_stale_owner']=True
	return report

def floor_wheel_native(args):
	"""Progressive floor edges, stationary riders and flat CD wheel patrols."""
	n=Native(args.rom,args.listing);checks=0
	states=('MMZ_Floor_Idle','MMZ_Floor_Delay','MMZ_Floor_Break','MMZ_Floor_Static',
		'MMZ_FloorPiece_Start','MMZ_FloorPiece_Wait','MMZ_FloorPiece_Fall',
		'MMZ_Wheel_Fall','MMZ_Wheel_Roll')
	states={n.s[name]:name for name in states}
	ss=list(range(n.s['v_lvlobjspace']&0xffffff,n.s['v_lvlobjend']&0xffffff,n.s['object_size']))
	def run(a):
		n.put(a,'obRender',n.get(a,'obRender')|128)
		n.act(states[n.get(a,'code')],a,regs={UC_M68K_REG_D7:0x3579006F})
		assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006F
	def setup(entry,sub):
		n.start();n.write('Camera_X_pos',440,2);root=ss[5]
		for actor in ('v_player','v_player2'):n.put(actor,'obX',100,2);n.put(actor,'obY',100,2)
		for f,v,z in [('code',n.s[entry],4),('obX',600,2),('obY',600,2),('obSubtype',sub,2)]:n.put(root,f,v,z)
		n.act(entry,root,regs={UC_M68K_REG_D7:0x3579006F})
		assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006F
		return root
	def attach(a,actor,x,bit):
		n.put(actor,'obX',x,2);n.put(actor,'obY',565,2);n.put(actor,'obStatus',8)
		n.put(actor,'standonobject',(a-(n.s['v_objspace']&0xffffff))//n.s['object_size'])
		n.put(a,'obStatus',n.get(a,'obStatus')|(1<<bit))
	for columns in range(1,9):
		for direction in (-1,1):
			for trigger in ('v_player','v_player2'):
				a=setup('Obj1B',0x100|columns)
				assert (n.get(a,'obFrame'),n.get(a,'obWidth'))==(columns-1,columns*8)
				attach(a,trigger,600,3 if trigger=='v_player' else 4)
				n.put(trigger,'obVelX',(direction*256)&65535,2);run(a)
				assert n.get(a,'code')==n.s['MMZ_Floor_Delay']
				assert n.get(a,'MMZ_floor_step',2)==(direction*8)&65535
				for remaining in range(columns-1,-1,-1):
					while n.get(a,'code')==n.s['MMZ_Floor_Delay']:run(a)
					assert n.get(a,'code')==n.s['MMZ_Floor_Break'];run(a)
					if remaining:
						assert n.get(a,'obX',2)==600+(columns-remaining)*8*direction
						assert n.get(a,'obWidth')==remaining*8 and n.get(a,'obFrame')==remaining-1
					else:assert not n.get(a,'code') and not n.get(trigger,'obStatus')&8
				pieces=[p for p in ss if n.get(p,'code')==n.s['MMZ_FloorPiece_Start']]
				assert len(pieces)==columns*2 and all(not n.get(p,'respawn_addr',2) for p in pieces)
				checks+=1
	# Shrinking the left edge must release its rider while the right-hand rider
	# keeps exactly the same world position and standing height.
	a=setup('Obj1B',0x104);attach(a,'v_player',580,3);attach(a,'v_player2',620,4);run(a)
	while n.get(a,'code')==n.s['MMZ_Floor_Delay']:run(a)
	run(a)
	assert not n.get('v_player','obStatus')&8 and n.get('v_player2','obStatus')&8
	assert (n.get('v_player2','obX',2),n.get('v_player2','obY',2))==(620,565)
	for count in (0,9,127):
		a=setup('Obj1B',0x180|count);assert n.get(a,'code')==n.s['MMZ_Floor_Static'] and n.get(a,'obWidth')==8
	# A full pool still consumes each slice without retry loops or corrupting
	# neighboring SSTs. Static blocks do not accidentally arm a collapse.
	a=setup('Obj1B',0x104)
	for p in ss:
		if p!=a:n.put(p,'code',n.s['PlayMusic'])
	n.put(a,'code',n.s['MMZ_Floor_Break']);run(a);assert n.get(a,'MMZ_floor_count',2)==3
	# Piece acceleration is 0.25px/update, capped at 22px/update, in 16.16.
	a=setup('Obj1B',0x101);n.put(a,'code',n.s['MMZ_FloorPiece_Fall']);n.put(a,'obY',0,4)
	y=0
	for tick in range(1,121):
		run(a);y+=min(tick*0x4000,0x160000)
		assert n.get(a,'obY',4)==y and n.get(a,'MMZ_floor_speed',4)==min(tick*0x4000,0x160000)
	# Isolate the native movement oracle from terrain probes: wall clearance is
	# eight pixels, the landed floor is flat. Real terrain/payload contacts run
	# separately in Genesis Plus GX.
	for label in ('ObjHitWallRight','ObjHitWallLeft'):n.cpu.mem_write(n.s[label],bytes.fromhex('72084E75'))
	for short in range(2):
		for yellow in range(2):
			for flip in range(2):
				a=setup('WheelCarrier',0x100|(short<<7)|yellow)
				if flip:n.put(a,'obVelX',0xFF00,2);n.put(a,'obStatus',1)
				n.cpu.mem_write(n.s['ObjHitFloor'],bytes.fromhex('72FF4E75'))
				n.cpu.ctl_remove_cache(n.s['ObjHitFloor'],n.s['ObjHitFloor']+4);run(a)
				assert n.get(a,'code')==n.s['MMZ_Wheel_Roll'] and n.get(a,'obY',2)==599
				n.cpu.mem_write(n.s['ObjHitFloor'],bytes.fromhex('72004E75'))
				n.cpu.ctl_remove_cache(n.s['ObjHitFloor'],n.s['ObjHitFloor']+4)
				x=600;vel=-1 if flip else 1;limit=64 if short else 80
				child=n.get(a,'wheel_child',4)
				assert n.get(child,'obSubtype')==(2 if yellow else 0)
				for _ in range(800):
					if abs(x-600)>=limit:vel=-vel
					x+=vel;run(a)
					assert (n.get(a,'obX',2),n.get(a,'obY',2),n.get(a,'obVelX',2))==(x,599,(vel*256)&65535),(short,yellow,flip,x,n.get(a,'obY',2))
					assert n.get(child,'obX',4)==n.get(a,'obX',4)
					checks+=1
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
			assert g.get(a,'code')==g.s['MMZ_Floor_Delay']
			place(g,'v_player',580,600-16-g.get('v_player','default_y_radius'));g.put('v_player','obControl',1)
			place(g,'v_player2',620,600-16-g.get('v_player2','default_y_radius'));g.put('v_player2','obControl',1)
			g.run(2);before=(g.get('v_player2','obX',2),g.get('v_player2','obY',2))
			for _ in range(20):
				g.run()
				if g.get(a,'MMZ_floor_count',2)==3:break
			else:raise AssertionError((era,'floor-did-not-crumble'))
			assert not g.get('v_player','obStatus')&8 and g.get('v_player2','obStatus')&8
			assert (g.get('v_player2','obX',2),g.get('v_player2','obY',2))==before,(era,trigger,'floor-hop')
			g.video.save(args.output/'floors-wheels'/f'era{era}-{trigger}-crumbling.png')
			g.run(35);assert not g.get(a,'code') and not g.get('v_player2','obStatus')&8
			report.append(dict(era=era,trigger=trigger,stationary_rider=True,removed_edge_released=True))
		g.restore(stage);a=spawn(g,'Obj1B',600,600,0x184);g.run(2)
		for actor in ('v_player','v_player2'):
			place(g,actor,600,600-16-g.get(actor,'default_y_radius'));g.put(actor,'obControl',1)
		g.run(30);assert g.get(a,'code')==g.s['MMZ_Floor_Static'] and g.get(a,'obStatus')&0x18==0x18
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
			assert g.get(a,'code')==g.s['MMZ_Wheel_Roll'],(era,short,'wheel-did-not-land')
			child=g.get(a,'wheel_child',4);assert g.get(child,'code')==g.s['Springs']
			assert g.get(child,'obSubtype')==(2 if short else 0)
			xs=[]
			for _ in range(350):
				g.run();xs.append(g.get(a,'obX',2))
				assert g.get(child,'obX',4)==g.get(a,'obX',4)
			assert (min(xs),max(xs))==(600-(64 if short else 80),600+(64 if short else 80)),(era,short,min(xs),max(xs))
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
	from check_companion_followup import isolate,spawn,place
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
				if g.get(a,'MMZ_group_phase',2):break
				g.run()
			else:raise AssertionError('Moving cohort did not reach its first curve point')
		return a
	for era in range(4):
		g.restore(initial);boot_level(g,zone=15,timezone=era)
		raw=bytearray((R/'art/uncompressed/MMZ1 Sprite Atlas.unc').read_bytes())
		for off,name in (((482,'Generator Past'),) if era==1 else ((110,'Saw Good Future'),(148,'Seesaw Good Future')) if era==2 else ()):
			data=(R/f'art/uncompressed/MMZ1 {name}.unc').read_bytes();raw[off*32:off*32+len(data)]=data
		raw_vram(g.s['ArtTile_MMZ_Atlas'],raw)
		for bank,file in [('ArtTile_MMZ_HVPlatform','Morphing Orbs'),('ArtTile_MMZ_Propeller','MM Propeller'),('ArtTile_Wheel','Wheel carrier')]:raw_vram(g.s[bank],nemesis((R/f'art/nemesis/{file}.nem').read_bytes()))
		# Full authored timings already have native source comparisons. Here actors
		# land through the real frame executor and independently release from a group.
		for code,sub,state,height in [('SMZ_VanishPlatform',0x102,'MMZ_VanP_Stand',16),('SMZ_SpinConvey',0x100,'MMZ_SpinC_Wait',5),('SMZ_SpinConvey',0x101,'MMZ_SpinC_MoveSolid',5)]:
			a=setup(code,sub)
			for _ in range(450):
				if g.get(a,'MMZ_group_state',4)==g.s[state] and g.get(a,'MMZ_group_timer',2)>30:break
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
	g.close()
	return report


def hazard_native(args):
	"""Compare motion against CD routines and its complete sine table."""
	import re
	R=ROOT;S=args.source;n=Native(args.rom,args.listing);slots=list(range(n.s['v_lvlobjspace']&0xffffff,n.s['v_lvlobjend']&0xffffff,n.s['object_size']));root=slots[5];count=0
	states=('MMZ_Saw_HoldIn','MMZ_Saw_Extend','MMZ_Saw_HoldOut','MMZ_Saw_Retract','MMZ_Crusher_Run');rev={n.s[k]:k for k in states}
	def call(name,a=root):
		n.act(name,a,regs={UC_M68K_REG_D7:0x3579006f});assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006f
		assert n.get(a,'code')
	def init(entry,sub,flip=0):
		n.start();n.put(root,'code',n.s[entry]);n.put(root,'obX',600,2);n.put(root,'obY',600,2);n.put(root,'obSubtype',sub);n.put(root,'obStatus',flip)
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
			init('SMZ_Saws',0x100+(extended<<7),flip);ref=CDSaw(extended)
			child=n.get(root,'MMZ_saw_handle',2)|0xff0000
			assert n.get(child,'MMZ_saw_parent',2)==root&65535
			for tick in range(1600):
				if tick:ref.step();call(rev[n.get(root,'code')])
				assert (n.get(root,'obX',2),n.get(root,'obY',2),n.get(root,'obFrame'))==(600+ref.x*(-1 if flip&1 else 1),600+ref.x*(-1 if flip&2 else 1),ref.frame),('saw',flip,extended,tick,ref.__dict__)
				call('MMZ_Saw_Handle',child);count+=1
			expected=[600-(80 if extended else 0)*(-1 if flip&b else 1) for b in (1,2)]
			assert [n.get(child,f,2) for f in ('obX','obY')]==expected
			assert n.get(root,'obColType')&63==n.s['Touch_Size_MMZSaw_ID']
			n.put(root,'MMZ_saw_handle',0,2);n.act('MMZ_Saw_Handle',child);assert not n.get(child,'code')
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
						call('MMZ_Crusher_Run');assert n.get(root,'MMZ_crush_phase',2)==phase,('crusher-phase',mode,amplitude,initial,speed,tick,phase,n.get(root,'MMZ_crush_phase',2))
						assert n.get(root,'obY',2)==600+sine[phase>>2]*amplitude//256
						count+=1
	# Actual source radius rather than blindly keeping a foreign collision index.
	rom=(R/'s2built.bin').read_bytes();at=n.s['Touch_Sizes']+(n.s['Touch_Size_MMZSaw_ID']-1)*2;assert rom[at:at+2]==bytes((28,28))
	return dict(source_motion_updates=count,source_height_cases=2048,source_saw_half_size=28,object_loop_counter_preserved=True)

def legacy_hazards(args):
	"""Compare retained S1 behavior with a matching pre-port ROM/listing."""
	old=Native(args.before_rom,args.before_listing);new=Native(args.rom,args.listing);cases=updates=0
	for entry,action,params in [('SMZ_Saws','SMZ_Saw_Action',range(5)),('SMZ_ScrapStomp','SMZ_Sto_Action',(0,0x13,0x24,0x34,0x40,0x80,0x81,0x83,0x88)),('Obj1B','Obj1B_Dispatch',(0,1))]:
		for param in params:
			for flip in range(4):
				objects=[]
				for n in (old,new):
					n.start();a=n.s['v_lvlobjspace']&0xffffff;objects.append(a)
					for f,v,z in [('code',n.s[entry],4),('obX',600,2),('obY',600,2),('obSubtype',param,2),('obStatus',flip,1)]:n.put(a,f,v,z)
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
							name=action if n.get(a,'code')==n.s.get(action) else entry
							n.act(name,a,regs={UC_M68K_REG_D7:0x3579006f})
							assert n.cpu.reg_read(UC_M68K_REG_D7)==0x3579006f
					for field,size in [('obX',4),('obY',4),('obVelX',2),('obVelY',2),('obRoutine',1),('ob2ndRout',1),('obFrame',1),('obAnim',2),('obTimeFrame',2),('obStatus',1),('obSubtype',2),('obColType',2),('objoff_30',16)]:
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
			a=setup('SMZ_Saws',0x100,flip);g.run(4);g.put(a,'MMZ_saw_timer',200,2);base=g.save()
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
	report=dict(native=native(args))
	if args.source:
		report['animations']=animation_checks(args)
		report['platforms']=platform_native(args)
		report['hazards']=hazard_native(args)
		report['floors_and_wheels']=floor_wheel_native(args)
	if args.core:
		report['game']=game(args)
		report['platform_game']=platform_game(args)
		report['hazard_game']=hazard_game(args)
		report['floor_wheel_game']=floor_wheel_game(args)
	if args.before_rom or args.before_listing:
		assert args.before_rom and args.before_listing,'Supply the matching ROM and listing together'
		report['retained_s1_hazards']=legacy_hazards(args)
	(args.output/'report.json').write_bytes((json.dumps(report,indent=2)+'\n').replace('\n','\r\n').encode())
	print(json.dumps(report,indent=2))


if __name__=='__main__':main()
