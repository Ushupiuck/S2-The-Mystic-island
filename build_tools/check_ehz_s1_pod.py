#!/usr/bin/env python3
"""Exercise the S1-pod EHZ boss in real Mode 1 gameplay.

Arena/player placement is staged. Eight hits use actual rolling collisions;
entry, terrain driving, hop, ignition, escape and capsule use normal game code.
"""
from pathlib import Path
import argparse,json,struct
from PIL import Image
from check_boss_shared_art import raster,unpack
from check_sprite_assets import frames
from check_ehz_boss import symbols
ROOT=Path(__file__).resolve().parents[1]


def check_art(rom,s):
	banks=[(s['ArtTile_Eggman'],unpack(rom,s['Kospm_OldEggPod'])),(s['ArtTile_EggmanFace'],unpack(rom,s['Kospm_EggmanFace']))]
	for old,new,n in (('Map_Eggman','Map_EHZBoss_Vehicle',1),('Map_GHZBoss_Cockpit','Map_EHZBoss_Cockpit',7)):
		for original,adapted in zip(frames(rom,s[old],n),frames(rom,s[new],n)):
			expected={(x,y-4):c for (x,y),c in raster(original,banks,s['ArtTile_Eggman']).items()}
			assert raster(adapted,banks,s['ArtTile_Eggman'])==expected,(old,new)
	plc=s['PLC_Boss']
	n=struct.unpack_from('>H',rom,plc)[0]+1
	entries=[struct.unpack_from('>IH',rom,plc+2+6*i) for i in range(n)]
	assert (s['Kospm_OldEggPod'],s['ArtTile_Eggman']*32) in entries
	assert all(source not in (s['Kospm_EggPod'],s['Kospm_EggChopper']) for source,dest in entries)
	assert 'Map_EHZBoss_Propeller' not in s


def save_gif(images,path,stride=2,pal=False):
	if not images:
		return
	colors=sorted({c for im in images for c in im.get_flattened_data()})
	assert len(colors)<=256,len(colors)
	p=Image.new('P',(1,1))
	flat=[v for c in colors for v in c]
	p.putpalette(flat+[0]*(768-len(flat)))
	indexed=[im.quantize(palette=p,dither=Image.Dither.NONE) for im in images]
	tick_ms=1000*stride/(50 if pal else 60)
	durations=[round((i+1)*tick_ms/10)*10-round(i*tick_ms/10)*10 for i in range(len(indexed))]
	indexed[0].save(path,save_all=True,append_images=indexed[1:],duration=durations,loop=0,optimize=False,disposal=2)


def live(a,act):
	from genesis_test_core import Genesis
	from check_object_course import boot_level,objects
	from check_companion_followup import isolate,place,spawn
	out=a.output/f'ehz{act+1}'
	out.mkdir(parents=True,exist_ok=True)
	g=Genesis(a.core,a.rom,a.listing,out,a.pal,system_directory=a.system_directory)
	s=g.s
	rom=a.rom.read_bytes()
	boot_level(g,zone=s['id_EHZ'],act=act,player=a.player)
	isolate(g)
	g.put('v_player2','code',0)
	for name,value in (
		('Camera_X_pos',s['EHZBoss_CameraLeft']),
		('Camera_Y_pos',s['EHZBoss_CameraY']),
		('Camera_Min_X_pos',s['EHZBoss_CameraLeft']),
		('Camera_Max_X_pos',s['EHZBoss_CameraFightRight']),
		('Camera_Min_Y_pos',s['EHZBoss_CameraY']),
		('Camera_Max_Y_pos',s['EHZBoss_CameraY']),
		('Camera_Max_Y_pos_target',s['EHZBoss_CameraY']),
	):
		g.write(name,value,2)
	g.write('Screen_redraw_flag',1)
	g.write('Dynamic_Resize_Routine',6 if act else 0)
	if act==0:
		# This otherwise-unplaced Act-1 boss fixture must suppress the ordinary
		# end-of-act signpost loader, which would lower Min_X below the arena.
		g.write('f_timecount',0)
	def park():
		place(g,'v_player',s['EHZBoss_LandingX']-64,s['EHZBoss_LandingY']-30,False)
		g.put('v_player','obControl',0x81)
		g.put('v_player','flashtime',6000,2)
	def valid():
		assert not g.read('v_errortype'),hex(g.core.m68k_get_reg(16))
		assert g.read('v_gamemode',2)==s['Level']
		assert g.get('v_player','obRoutine')<6, ('Player died',g.frame,g.get('v_player','obX',2),g.get('v_player','obY',2),g.read('Camera_Y_pos',2),g.read('Camera_Max_Y_pos',2),[(p,g.get(p,'obRoutine'),g.get(p,'obY',2)) for p in objects(g,0x55)])
		assert not any(g.get(p,'obRoutine') in (4,12) for p in objects(g,0x55)),'Rotor child exists'
	park()
	g.run(120)
	valid()
	assert not g.read('v_plc_buffer',4)
	plc=s['PLC_Boss']
	n=struct.unpack_from('>H',rom,plc)[0]+1
	payload=bytearray(rom[plc+2:plc+2+n*6]+bytes(6))
	for i in range(n):
		payload[6*i]|=0x80
	for i,v in enumerate(payload):
		g.write(s['v_plc_buffer']+i,v)
	for _ in range(600):
		g.run()
		valid()
		if not g.read('v_plc_buffer',4) and not g.read('v_plc_patternsleft',2):
			break
	else:
		raise AssertionError('Boss PLC did not finish')
	for label,base in (
		('Kospm_OldEggPod','ArtTile_Eggman'),
		('Kospm_EggmanFace','ArtTile_EggmanFace'),
		('Kospm_EHZ_Boss','ArtTile_ArtNem_EHZBoss'),
		('Kospm_Exhaust','ArtTile_Eggman_Exhaust'),
	):
		raw=unpack(rom,s[label])
		assert bytes(g.vram[(s[base]*32+i)^1] for i in range(len(raw)))==raw,label
	body=spawn(g,'EHZBoss',s['EHZBoss_LandingX'],s['EHZBoss_LandingY']+8)
	entry=[]
	entry_flames=set()
	cycles=set()
	for tick in range(500):
		g.run()
		valid()
		cycles.add(tuple(g.read(s['v_palette']+0x24+2*i,2) for i in range(4)))
		flames=[p for p in objects(g,0x55) if g.get(p,'obRoutine')==16]
		if tick>2 and g.get(body,'ob2ndRout')==0:
			assert len(flames)==1
			entry_flames.add(g.get(flames[0],'obFrame'))
			assert g.get(flames[0],'obX',2)==g.get(body,'obX',2)+34
			assert g.get(flames[0],'obY',2)==g.get(body,'obY',2)-4
		if tick%2==0:
			entry.append(g.video.copy())
		if g.get(body,'ob2ndRout')==4:
			break
	else:
		raise AssertionError('Boss did not dock')
	assert entry_flames=={0,1},entry_flames
	assert len(cycles)>1,'EHZ animated palette stopped'
	face=next(p for p in objects(g,0x55) if g.get(p,'obRoutine')==14)
	flame=next(p for p in objects(g,0x55) if g.get(p,'obRoutine')==16)
	assert g.get(flame,'obFrame')==4,'Flame stayed on while docked'
	g.run(4)
	g.video.save(out/'docked.png')
	save_gif(entry,out/'landing.gif',pal=a.pal)
	from check_boss_shared_art import live_gallery
	live_gallery(g,a,act)
	if act==0:
		# Act 1 has no authored EHZ fight arena. Its fixture verifies entry,
		# docking, palette animation and every pose/facing; Act 2 owns the fight.
		g.close()
		return {'act':1,'landing_and_docking':True,'poses_and_facings':14,'animated_palette_phases':len(cycles),'no_rotor':True,'authored_fight':False}
	facings=set()
	drive=[]
	for tick in range(750):
		g.run()
		valid()
		flip=g.get(body,'obStatus')&1
		facings.add(flip)
		car=next(p for p in objects(g,0x55) if g.get(p,'obRoutine')==6)
		assert g.get(car,'obY',2)==g.get(body,'obY',2)+8
		assert g.get(flame,'obFrame')==4
		if tick%4==0:
			drive.append(g.video.copy())
		if 30<=g.get(body,'obX',2)-g.read('Camera_X_pos',2)<=290:
			g.video.save(out/f'drive-facing{flip}.png')
	assert facings=={0,1}
	save_gif(drive,out/'driving.gif',stride=4,pal=a.pal)
	hits=[]
	score=g.read('v_score',4)
	normal=g.read(s['v_palette']+0x22,2)
	for hit in range(8):
		for _ in range(400):
			if 32<=g.get(body,'obX',2)-g.read('Camera_X_pos',2)<=288:
				break
			g.run()
			valid()
		hp=g.get(body,'obColProp')
		for field,value,size in (
			('obControl',0,1),
			('obX',g.get(body,'obX',2),2),
			('obY',g.get(body,'obY',2)-24,2),
			('obVelX',0,2),
			('obVelY',0x300,2),
			('obInertia',0,2),
			('obStatus',6,1),
			('obHeight',14,1),
			('obWidth',7,1),
			('obAnim',s['AniIDSonAni_Roll'],1),
			('flashtime',6000,2),
		):
			g.put('v_player',field,value,size)
		for _ in range(10):
			g.run()
			valid()
			if g.get(body,'obColProp')==hp-1:
				break
		else:
			raise AssertionError(('Rolling collision missed',hit,hp))
		hits.append(g.get(body,'obColProp'))
		park()
		if hit<7:
			g.run(34)
			valid()
			assert g.get(body,'obColType')==15
			assert g.read(s['v_palette']+0x22,2)==normal
	assert hits==list(range(7,-1,-1))
	assert g.read('v_score',4)==score+100
	escape=[]
	hop=[]
	flare=set()
	ignition_y=None
	before_hop=None
	for tick in range(800):
		g.run()
		valid()
		if g.get(body,'code'):
			phase=g.get(body,'ob2ndRout')
			ter=g.get(body,'objoff_30')
			if phase==10 and ter==2:
				hop.append(g.get(body,'obY',2))
				assert g.get(flame,'obFrame')==4
				if before_hop is None:
					before_hop=g.get(body,'obY',2)
			if phase==10 and ter==4:
				if ignition_y is None:
					ignition_y=g.get(body,'obY',2)
					g.video.save(out/'ignition.png')
				flare.add(g.get(flame,'obFrame'))
				assert g.get(flame,'obX',2)==g.get(body,'obX',2)-34
				assert g.get(flame,'obY',2)==g.get(body,'obY',2)-4
		if tick%2==0:
			escape.append(g.video.copy())
		if not g.get(body,'code'):
			break
	else:
		raise AssertionError('Boss did not leave')
	assert before_hop-min(hop)==8,(before_hop,hop)
	assert ignition_y==min(hop)
	assert {0,1,2,3}<=flare,flare
	assert not g.get(face,'code') and not g.get(flame,'code')
	save_gif(escape,out/'escape.gif',pal=a.pal)
	if act==1:
		place(g,'v_player',0x2B50,0x6D0,False)
		g.put('v_player','obControl',1)
		g.run(90)
		buttons=[p for p in objects(g,0x3E) if g.get(p,'obSubtype')==1]
		assert len(buttons)==1
		button=buttons[0]
		for f,v,n in (
			('obControl',0,1),
			('obX',g.get(button,'obX',2),2),
			('obY',g.get(button,'obY',2)-40,2),
			('obVelX',0,2),
			('obVelY',0x100,2),
			('obStatus',2,1),
			('obAnim',0,1),
		):
			g.put('v_player',f,v,n)
		for _ in range(180):
			g.run()
			valid()
			if g.read('Boss_defeated_flag')==2:
				break
		else:
			raise AssertionError('Capsule did not open')
		g.run(4)
		assert any(g.get(p,'code')==s['Flicky'] for p in objects(g))
		g.video.save(out/'capsule.png')
	g.close()
	return {'act':act+1,'hits':hits,'facings':sorted(facings),'hop_pixels':8,'entry_flame':sorted(entry_flames),'escape_flare':sorted(flare),'animated_palette_phases':len(cycles),'no_rotor':True,'capsule_tested':act==1}


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
	p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--core',type=Path,required=True)
	p.add_argument('--system-directory',type=Path,required=True)
	p.add_argument('--output',type=Path,required=True)
	p.add_argument('--pal',action='store_true')
	p.add_argument('--player',type=int,default=0)
	p.add_argument('--act',type=int,choices=(0,1))
	a=p.parse_args()
	a.output.mkdir(parents=True,exist_ok=True)
	check_art(a.rom.read_bytes(),symbols(a.listing))
	reports=[]
	for act in ((a.act,) if a.act is not None else (0,1)):
		reports.append(live(a,act))
		print(json.dumps(reports[-1]),flush=True)
	(a.output/'report.json').write_text(json.dumps(reports,indent=2)+'\n')


if __name__=='__main__':
	main()
