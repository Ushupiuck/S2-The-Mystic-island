#!/usr/bin/env python3
"""Check final shield/star positions after real tunnel and dispatcher updates.

Native actors are held by fixture callbacks; the actual dispatcher, shields
and pipe controller run unchanged. Optional core checks stage an authored SMZ2
tunnel with real players, rendering and DMA. Positioning is a test fixture.
"""
from pathlib import Path
import argparse
import json
import struct
from native_test_core import Native

ROOT=Path(__file__).resolve().parents[1]


def dispatch_counts(rom,listing):
	n=Native(rom,listing)
	stub=0x3EF000
	n.cpu.mem_write(stub,struct.pack('>3H',0x5268,n.s['objoff_2E'],0x4E75))
	slots=range(n.s['v_objspace'],n.s['v_lvlobjend'],n.s['object_size'])
	for dense in (False,True):
		n.start()
		n.write('Collision_response_list',65535 if dense else 0,2)
		n.write('Timer_frames',1,2)
		for a in slots:
			n.put(a,'code',stub)
			n.put(a,'objoff_2E',0,2)
			n.put(a,'obColType',0)
		n.act('ExecuteObjects')
		assert all(n.get(a,'objoff_2E',2)==1 for a in slots), ('Object ran twice or was skipped',dense)
	return {'slots':len(slots),'dispatch_modes':2,'updates_per_slot':1}


def tunnel(rom,listing,stars=False):
	n=Native(rom,listing)
	n.start()
	n.write('Camera_X_pos_coarse_back',0x100,2)
	actors=('v_player','v_player2')
	shields=('v_shieldobj','v_shieldobj2')
	for actor,shield in zip(actors,shields):
		for field,value,size in (('code',n.s['MS_Return'],4),('obX',0x180,2),
				('obY',0x400,2),('obRoutine',2,1),('obStatusSecondary',2 if stars else 1,1)):
			n.put(actor,field,value,size)
		if not stars:
			n.put(shield,'code',n.s['Obj38'])
			n.put(shield,'obParent',n.s[actor]&65535,2)
	if stars:
		n.put('v_starsobj','code',n.s['Obj35'])
		n.put('v_shieldobj','effect_loaded_frame',n.s['PlayerEffects_StarsLoaded'])
	a=n.s['v_lvlobjspace']
	for field,value,size in (('code',n.s['SMZ_Teleport'],4),('obX',0x180,2),
			('obY',0x400,2),('obSubtype',0,2)):
		n.put(a,field,value,size)
	mismatches=0
	moving=0
	previous=None
	for tick in range(120):
		n.write('v_spritequeue',0,n.s['v_spritequeue_end']-n.s['v_spritequeue'])
		n.write('Camera_X_pos',n.get('v_player','obX',2)-160,2)
		n.write('Camera_Y_pos',n.get('v_player','obY',2)-112,2)
		n.act('ExecuteObjects')
		positions=[]
		for actor,shield in zip(actors,shields):
			body=(n.get(actor,'obX',2),n.get(actor,'obY',2))
			if stars:
				partner=actor=='v_player2'
				candidates=[n.s['v_starsobj']]+list(range(n.s['v_lvlobjspace'],n.s['v_lvlobjend'],n.s['object_size']))
				effect=next(a for a in candidates if n.get(a,'code')==n.s['Obj35'] and
						bool(n.get(a,'invincibility_flags')&2)==partner)
				assert n.get(effect,'mainspr_childsprites')>=2
				angle=n.get(effect,'invincibility_angles')&0x3E
				for child in range(2):
					phase=(angle+child*32)&0x3E
					dx,dy=struct.unpack('>bb',n.cpu.mem_read(n.s['InvincibilityStars_Positions']+phase,2))
					actual=struct.unpack('>HH',n.cpu.mem_read((effect+n.s['subspr_data']+child*6)&0xFFFFFF,4))
					mismatches+=actual!=tuple((p+d)&65535 for p,d in zip(body,(dx,dy)))
			else:
				effect=(n.get(shield,'obX',2),n.get(shield,'obY',2))
				assert n.get(shield,'code')==n.s['Obj38']
				mismatches+=body!=effect
			positions.append(body)
		moving+=previous is not None and positions!=previous
		previous=positions
		n.uploads.clear()
	assert moving>40,moving
	return {'frames':120,'moving_frames':moving,'owner_samples':240,'position_mismatches':mismatches}


def live(args):
	from genesis_test_core import Genesis
	from check_object_course import boot_level,objects
	from object_layout import decode
	g=Genesis(args.core,args.rom,args.listing,args.output/'game',
				system_directory=args.system_directory)
	boot_level(g,zone=8,act=1,player=args.player)
	x,packed,_,_,subtype=next(row for row in decode((ROOT/'level/objects/SMZ_2.bin').read_bytes())
							if row[2]==0xAB and row[4]==args.tunnel)
	y=packed&0xFFF
	actors=('v_player','v_player2') if args.player==0 else ('v_player',)
	shields=('v_shieldobj','v_shieldobj2') if args.player==0 else ('v_shieldobj',)
	for actor in actors:
		for field,value,size in (('obX',x-8 if packed&0x2000 else x+8,2),('obY',y,2),
				('obControl',0x81,1),('obVelX',0,2),('obVelY',0,2),('obInertia',0,2),
				('obRoutine',2,1),('obStatusSecondary',2 if args.stars else 1,1),('invtime',1200,2),('flashtime',600,2)):
			g.put(actor,field,value,size)
	g.write('v_rings',99,2)
	g.write('Tails_CPU_idle_timer',6000,2)
	g.write('Camera_X_pos',max(0,x-160),2)
	g.write('Camera_Y_pos',(y-96)&0x7FF,2)
	g.run(16)
	assert any(g.get(a,'obSubtype',2)==subtype for a in objects(g,0xAB))
	for actor,shield in zip(actors,shields):
		g.put(actor,'obControl',0)
		if not args.stars:
			g.put(shield,'code',g.s['Obj38'])
			g.put(shield,'obRoutine',0)
			g.put(shield,'obParent',g.s[actor]&65535,2)
	if args.stars:
		g.write('v_starsobj',0,g.s['object_size'])
		g.put('v_starsobj','code',g.s['Obj35'])
	all_objects=range(g.s['v_objspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size'])
	captured=False
	samples=0
	partial_frames=0
	frames=[]
	def object_pass_active():
		# A libretro video boundary can interrupt the 68000 halfway through
		# an object update. Compare completed passes, not mixed-frame SSTs.
		sp=g.core.m68k_get_reg(15)&65535
		depth=min(256,((g.s['v_systemstack']&65535)-sp)&65535)
		return any(g.s['ExecuteObjects']<=g.read(sp+i,4)<g.s['Obj_Index_Zero']
					for i in range(0,max(0,depth-3),2))
	for tick in range(400):
		for actor in actors:g.put(actor,'flashtime',13,2)	# visible phase while protecting the staged actors
		g.run()
		assert not g.read('v_errortype')
		if object_pass_active():
			partial_frames+=1
			continue
		captured|=all(g.get(actor,'obControl')==0x81 for actor in actors)
		for actor,shield in zip(actors,shields):
			if args.stars:
				partner=actor=='v_player2'
				effect=next(a for a in all_objects if g.get(a,'code')==g.s['Obj35'] and
						bool(g.get(a,'invincibility_flags')&2)==partner)
				assert g.get(effect,'mainspr_childsprites')>=2
				angle=g.get(effect,'invincibility_angles')&0x3E
				for child in range(2):
					phase=(angle+child*32)&0x3E
					dx,dy=struct.unpack_from('>bb',args.rom.read_bytes(),g.s['InvincibilityStars_Positions']+phase)
					actual=tuple(g.read(effect+g.s['subspr_data']+child*6+i,2) for i in (0,2))
					expected=((g.get(actor,'obX',2)+dx)&65535,(g.get(actor,'obY',2)+dy)&65535)
					assert actual==expected,(tick,actor,'leading stars trail owner',actual,expected,'camera',g.read('Camera_X_pos',2),g.read('Camera_Y_pos',2),'children',g.get(effect,'mainspr_childsprites'),'flags',g.get(actor,'obControl'),'count',g.get(actor,'obRoutine'),'pc',hex(g.core.m68k_get_reg(16)))
			else:
				assert g.get(shield,'code')==g.s['Obj38'],(tick,actor,hex(g.get(shield,'code')),g.get(actor,'obRoutine'),g.get(actor,'obStatusSecondary'),g.get(actor,'obX',2),g.get(actor,'obY',2))
				assert (g.get(actor,'obX',2),g.get(actor,'obY',2))==(
						g.get(shield,'obX',2),g.get(shield,'obY',2)),(tick,actor,'shield trails owner')
			samples+=1
		if tick%2==0:frames.append(g.video.copy())
		if tick in (35,70,105):g.video.save(args.output/f'game/tunnel-effects-{tick}.png')
		if tick>3 and captured and all(not g.get(actor,'obControl') for actor in actors):break
	assert captured and samples>60 and all(not g.get(actor,'obControl') for actor in actors)
	all_objects=range(g.s['v_objspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size'])
	assert sum(g.get(a,'code')==g.s['Obj35' if args.stars else 'Obj38'] for a in all_objects)==len(actors)
	frames[0].save(args.output/'tunnel-shields.webp',save_all=True,append_images=frames[1:],duration=34,loop=0,lossless=True)
	g.close()
	return {'frames':tick+1,'owner_samples':samples,'position_mismatches':0,'active_effects':len(actors),'stars':args.stars,'partial_frame_samples_skipped':partial_frames}


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
	p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--output',type=Path,required=True)
	p.add_argument('--stars',action='store_true')
	p.add_argument('--tunnel',type=int,choices=range(8),default=0)
	p.add_argument('--before-rom',type=Path)
	p.add_argument('--before-listing',type=Path)
	p.add_argument('--core',type=Path)
	p.add_argument('--system-directory',type=Path)
	p.add_argument('--player',type=int,choices=(0,2),default=0)
	args=p.parse_args()
	args.output.mkdir(parents=True,exist_ok=True)
	report={'dispatch':dispatch_counts(args.rom,args.listing),
			'native':tunnel(args.rom,args.listing),
			'stars':tunnel(args.rom,args.listing,True)}
	assert not report['native']['position_mismatches'] and not report['stars']['position_mismatches'],report
	if args.before_rom:
		report['before']=tunnel(args.before_rom,args.before_listing)
		assert report['before']['position_mismatches']>0,report
		report['before_stars']=tunnel(args.before_rom,args.before_listing,True)
		assert report['before_stars']['position_mismatches']>0,report
	if args.core:report['game']=live(args)
	(args.output/'report.json').write_bytes((json.dumps(report,indent=2)+'\n').replace('\n','\r\n').encode())
	print(json.dumps(report,indent=2))


if __name__=='__main__':
	main()
