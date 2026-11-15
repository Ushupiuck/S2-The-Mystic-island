#!/usr/bin/env python3
"""Verify the merged checkpoint/time pole, art banks, both actors and lifetimes.

Native checks execute the real 68000 states and CD placement-state executor.
Optional core scenes use ordinary PLCs/constructors and inspect the actual SAT.
"""
from pathlib import Path
import argparse
import json
import struct
from native_test_core import Native,UC_M68K_REG_D7
from check_sprite_assets import frames
from check_boss_shared_art import raster
from import_ehz2_pp_background import nemesis

ROOT=Path(__file__).resolve().parents[1]


def native(a):
	m=Native(a.rom,a.listing);rom=a.rom.read_bytes();s=m.s
	pool=list(range(s['v_lvlobjspace'],s['v_lvlobjend'],s['object_size']))
	states=('Obj79','Checkpoint_Main','Checkpoint_WaitBall','Checkpoint_Ball','TimePole_Main','TimePole_Spin','Pole_Active')
	def tick(obj):
		label=next(n for n in states if s[n]==m.get(obj,'code'))
		m.act(label,obj,regs={UC_M68K_REG_D7:0x13572468})
		assert m.cpu.reg_read(UC_M68K_REG_D7)==0x13572468
	def setup(kind=1,handle=1,state=0x80,full=False):
		m.start();root=pool[0]
		for actor in ('v_player','v_player2'):
			m.put(actor,'obX',100,2);m.put(actor,'obY',100,2)
		for field,v,n in (('code',s['Obj79'],4),('obX',240,2),('obY',240,2),('obSubtype',kind,2),('respawn_addr',handle,2)):
			m.put(root,field,v,n)
		m.placement_write(0,state)
		if full:
			for q in pool[1:]:m.put(q,'code',s['Pole_Active'])
		tick(root);return root
	def contact(root,actor):
		m.put(actor,'obX',240,2);m.put(actor,'obY',224,2);tick(root)
	cases=0
	for who in ('v_player','v_player2'):
		for yellow in (0,0x400):
			for handle in (0,1):
				for full in (False,True):
					r=setup(1|yellow,handle,full=full);contact(r,who)
					assert m.read('v_lastlamp')==1 and m.read('v_lamp_xpos',2)==240 and m.read('v_lamp_ypos',2)==240
					assert m.placement_read()==(0x81 if handle else 0x80)
					if not full:
						child=m.get(r,'Pole_child',2)|0xFF0000;assert child and m.get(child,'Pole_child',2)==r&65535
						positions=set()
						for _ in range(64):
							tick(r);tick(child);positions.add((m.get(child,'obX',2),m.get(child,'obY',2)))
						assert not m.get(child,'code') and len(positions)>=24
					assert m.get(r,'code')==s['Pole_Active'] and m.get(r,'obFrame')==(2 if yellow else 1)
					cases+=1
	# A consumed sign is still visible but cannot arm another trip or touch any
	# of the existing checkpoint snapshot, even in a different era.
	for era in range(4):
		for kind,direction,base in ((0x100,255,6),(0x200,1,8)):
			for who in ('v_player','v_player2'):
				for handle in (0,1):
					r=setup(kind,handle);m.write('Current_Timezone',era)
					m.write('v_lastlamp',5);m.write('v_lamp_xpos',0x9876,2);m.write('v_lamp_time',0x12345678,4)
					contact(r,who)
					assert m.read('TimeWarp_Direction')==direction and m.get(r,'code')==s['TimePole_Spin']
					seen={m.get(r,'obFrame')}
					for _ in range(60):tick(r);seen.add(m.get(r,'obFrame'))
					assert seen=={base,base+1,10,11} and m.get(r,'code')==s['Pole_Active']
					assert m.read('v_lastlamp')==5 and m.read('v_lamp_xpos',2)==0x9876 and m.read('v_lamp_time',4)==0x12345678
					m.write('TimeWarp_Direction',0);tick(r);assert m.read('TimeWarp_Direction')==0
					assert m.placement_read()==(0x81 if handle else 0x80);cases+=1
	for kind,frame in ((1,1),(0x401,2),(0x100,7),(0x200,9)):
		r=setup(kind,state=0x81);assert m.get(r,'obFrame')==frame
		assert m.get(r,'code')==s['Pole_Active'] and not m.read('TimeWarp_Direction')
		m.act('UnloadObject',r);assert m.placement_read()==1;cases+=1
	# Every proximity boundary and both independent actor paths. The other actor
	# is kept far away so the result cannot borrow that actor's state.
	for who in ('v_player','v_player2'):
		for kind,half in ((1,8),(0x100,22)):
			for dx in (-half-1,-half,half-1,half):
				for dy in (-65,-64,39,40):
					r=setup(kind);m.put(who,'obX',240+dx,2);m.put(who,'obY',240+dy,2);tick(r)
					hit=-half<=dx<half and -64<=dy<40
					assert bool(m.placement_read()&1)==hit,(kind,who,dx,dy);cases+=1
		for layer in (12,14):
			for required in (12,14):
				r=setup(0x1100|(0x800 if required==14 else 0));m.put(who,'obTopSolidBit',layer)
				contact(r,who);assert bool(m.read('TimeWarp_Direction'))==(layer==required);cases+=1
		for blocked in ('dead','empty','locked','debug','global'):
			r=setup(0x100)
			if blocked=='dead':m.put(who,'obRoutine',6)
			elif blocked=='empty':m.put(who,'code',0)
			elif blocked=='locked':m.put(who,'obControl',0x80)
			elif blocked=='debug':m.write('Debug_placement_mode',1,2)
			else:m.write('f_playerctrl',0x80)
			contact(r,who);assert not m.read('TimeWarp_Direction');cases+=1
	# Reused slots are never adopted as the old parent or ball.
	r=setup();contact(r,'v_player');child=m.get(r,'Pole_child',2)|0xFF0000
	m.put(child,'code',s['Ring']);tick(r);assert m.get(child,'code')==s['Ring'] and m.get(r,'code')==s['Pole_Active']
	r=setup();contact(r,'v_player');child=m.get(r,'Pole_child',2)|0xFF0000
	m.put(r,'code',s['Ring']);tick(child);assert not m.get(child,'code') and m.get(r,'code')==s['Ring']
	r=setup();contact(r,'v_player');child=m.get(r,'Pole_child',2)|0xFF0000
	m.put(r,'Pole_child',pool[-1]&65535,2);tick(child);assert not m.get(child,'code')
	# The runtime absolute-word maps and compact editor maps render the same
	# pixels, including mirrors, with the genuine loaded common/act banks.
	raw=(ROOT/'art/uncompressed/Checkpoint.unc').read_bytes()
	atlas=(ROOT/'art/uncompressed/MMZ1 Sprite Atlas.unc').read_bytes()
	assert nemesis(rom[s['Nem_Lamppost']:])==raw[:320]
	assert nemesis(rom[s['Nem_CheckpointYellow']:])==raw[320:]
	editor=nemesis((ROOT/'art/nemesis/Checkpoint editor.nem').read_bytes())
	rows=frames(rom,s['Map_Obj79'],14)
	for i,row in enumerate(frames((ROOT/'mappings/sprite/Checkpoint editor.bin').read_bytes())):
		actual=raster(rows[i],[(s['ArtTile_Lamppost'],raw[:320]),(s['ArtTile_CheckpointYellow'],raw[320:]),(s['ArtTile_MMZ_Atlas'],atlas)])
		assert actual==raster(row,[(0,editor)]),(i,'bank crossing changed visible art')
		assert all((w&0x1800)==(v&0x1800) for (_,_,w,_),(_,_,v,_) in zip(rows[i],row))
	return dict(behavior_cases=cases,orbit_updates=512,recycled_slots=True,mapping_frames=14,atlas_tiles=477)


def game(a):
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_companion_followup import isolate,place,spawn
	g=Genesis(a.core,a.rom,a.listing,a.output.parent/('poles-pal' if a.pal else 'poles-ntsc'),a.pal,system_directory=a.system_directory)
	initial=g.save();report=[]
	def run(n):
		for _ in range(n):
			g.run();assert not g.read('v_errortype'),('CPU exception',g.frame)
	def vram(tile,count):return bytes(g.vram[(tile*32+i)^1] for i in range(count*32))
	for zone,era,mode in ((15,0,0),(15,1,0),(15,2,0),(15,3,0),(0,0,2)):
		g.restore(initial);boot_level(g,zone=zone,timezone=era,player=mode);isolate(g)
		g.placement_write(0,int.from_bytes(b'\x80'*g.placement_capacity(),'big'),g.placement_capacity())
		for actor in ('v_player','v_player2'):
			place(g,actor,500,520);g.put(actor,'obControl',0x81)
		g.write('Camera_X_pos',440,2);g.write('Camera_X_pos_coarse_back',256,2);g.write('Camera_Y_pos',424,2)
		for field in ('Camera_Min_Y_pos','Camera_Max_Y_pos','Camera_Max_Y_pos_target'):g.write(field,424,2)
		master=(ROOT/'art/uncompressed/Checkpoint.unc').read_bytes()
		assert vram(g.s['ArtTile_Lamppost'],10)==master[:320]
		assert vram(g.s['ArtTile_CheckpointYellow'],2)==master[320:]
		blue=spawn(g,'Obj79',440,600,7);red=spawn(g,'Obj79',492,600,1);yellow=spawn(g,'Obj79',544,600,0x402)
		past=future=None
		if zone==15:
			past=spawn(g,'Obj79',596,600,0x100);future=spawn(g,'Obj79',648,600,0x200)
			atlas=(ROOT/'art/uncompressed/MMZ1 Sprite Atlas.unc').read_bytes()
			assert vram(g.s['ArtTile_TimePostHeads'],22)==atlas[432*32:454*32]
		run(4)
		for post in (red,yellow):
			place(g,'v_player',g.get(post,'obX',2),584);g.put('v_player','obControl',1);run(3)
			place(g,'v_player',500,520);g.put('v_player','obControl',0x81);run(70)
		assert g.get(blue,'obFrame')==0 and g.get(red,'obFrame')==1 and g.get(yellow,'obFrame')==2
		run(5);g.video.save(g.output/('heads-era%d-zone%d.png'%(era,zone)))
		# Verify the actual hardware SAT includes each selected head, not just an
		# SST frame which can be one video frame ahead of the displayed image.
		expected={g.s['ArtTile_Lamppost']+6,g.s['ArtTile_Lamppost']+8,g.s['ArtTile_CheckpointYellow']}
		if past:expected|={g.s['ArtTile_TimePostHeads'],g.s['ArtTile_TimePostHeads']+8}
		for _ in range(30):
			visible=set();link=0
			for __ in range(80):
				words=[int.from_bytes(bytes(g.vram[(g.s['vram_sprites']+link*8+j+k)^1] for k in range(2)),'big') for j in (0,2,4,6)]
				visible.add(words[2]&2047);link=words[1]&127
				if not link:break
			if expected<=visible:break
			run(1)
		else:raise AssertionError(('head art missing from SAT',zone,era,expected,visible, (g.read('Camera_X_pos',2),g.read('Camera_Y_pos',2)), [{f:g.get(q,f,n) for f,n in (('code',4),('obX',2),('obY',2),('obFrame',1),('obRender',1),('obGfx',2),('obMap',4),('width_pixels',1),('height_pixels',1),('obPriority',2))} for q in (blue,red,yellow,past,future) if q]))
		if past:
			checkpoint=(g.read('v_lastlamp'),g.read('v_lamp_xpos',2),g.read('v_lamp_time',4))
			for who,post,direction in (('v_player',past,255),('v_player2',future,1)):
				place(g,who,g.get(post,'obX',2),584);g.put(who,'obControl',1);run(3)
				assert g.read('TimeWarp_Direction')==direction,(zone,era,who)
				place(g,who,500,520);g.put(who,'obControl',0x81);run(65)
				assert (g.read('v_lastlamp'),g.read('v_lamp_xpos',2),g.read('v_lamp_time',4))==checkpoint
				assert g.get(post,'code')==g.s['Pole_Active']
			g.video.save(g.output/('consumed-era%d.png'%era))
		report.append(dict(zone=zone,era=era,player_mode=mode,actual_sat_heads=True))
	g.close();return report


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin');p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--core',type=Path);p.add_argument('--system-directory',type=Path);p.add_argument('--pal',action='store_true')
	p.add_argument('--output',type=Path,required=True);a=p.parse_args()
	report={'native':native(a)}
	if a.core:report['game']=game(a)
	a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))


if __name__=='__main__':main()
