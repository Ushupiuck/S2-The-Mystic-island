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


def path_math(rom,listing):
	"""Exercise the shared 68000 kernel, including signs and fractional timers."""
	from native_test_core import (UC_M68K_REG_D2,UC_M68K_REG_D6,UC_M68K_REG_D7,
		UC_M68K_REG_A0,UC_M68K_REG_A1,UC_M68K_REG_A3)
	n=Native(rom,listing);n.start()
	packet=(n.s['v_lvlobjspace']+n.s['objoff_30'])&0xFFFFFF
	guard=bytes(range(32))
	cases=0
	for speed in (0x100,0x180,0x200,0x280,0x400,0x800,0xC00,0x1000,0x2000):
		maximum=min(1024,speed*127//256)
		for distance in sorted({1,2,7,8,15,16,17,31,32,33,maximum-1,maximum}):
			if not 0<distance<=maximum:continue
			for minor in sorted({0,1,distance//3,distance-1,distance}):
				if not 0<=minor<=distance:continue
				for swap in (False,True):
					for sx,sy in ((1,1),(-1,1),(1,-1),(-1,-1)):
						dx,dy=(minor,distance) if swap else (distance,minor)
						dx*=sx;dy*=sy
						for actor in ('v_player','v_player2'):
							n.cpu.mem_write(packet,guard)
							n.put(actor,'obX',6000,2);n.put(actor,'obY',1400,2)
							n.cpu.mem_write(packet+4,struct.pack('>HH',6000+dx,1400+dy))
							regs={UC_M68K_REG_D2:speed,UC_M68K_REG_A0:n.s['v_lvlobjspace'],
								UC_M68K_REG_A1:n.s[actor],UC_M68K_REG_A3:packet,
								UC_M68K_REG_D6:0x12345678,UC_M68K_REG_D7:0x24681357}
							n.act('AutoTunnel_CalcSpeed',regs=regs)
							time=(distance<<16)//speed
							def velocity(delta,major):
								if major:return speed if delta>=0 else -speed
								v=(abs(delta)<<16)//time
								return v if delta>=0 else -v
							expected=(velocity(dx,abs(dx)>abs(dy))&65535,
								velocity(dy,abs(dy)>=abs(dx))&65535,time)
							actual=(n.get(actor,'obVelX',2),n.get(actor,'obVelY',2),
								int.from_bytes(n.cpu.mem_read(packet+2,2),'big'))
							assert actual==expected,(actor,speed,dx,dy,actual,expected)
							state=n.cpu.mem_read(packet,32)
							assert state[:2]==guard[:2] and state[8:]==guard[8:]
							for reg in (UC_M68K_REG_A0,UC_M68K_REG_A1,UC_M68K_REG_A3,
								UC_M68K_REG_D6,UC_M68K_REG_D7):
								assert n.cpu.reg_read(reg)==regs[reg]&0xFFFFFFFF,('clobbered register',reg)
							cases+=1
	for actor in ('v_player','v_player2'):
		n.put(actor,'obX',6000,2);n.put(actor,'obY',1400,2)
		n.cpu.mem_write(packet+4,struct.pack('>HH',6000,1400))
		n.act('AutoTunnel_CalcSpeed',regs={UC_M68K_REG_D2:0x1000,
			UC_M68K_REG_A1:n.s[actor],UC_M68K_REG_A3:packet})
		assert n.get(actor,'obVelX',2)==n.get(actor,'obVelY',2)==0
		assert n.cpu.mem_read(packet+2,2)==b'\0\0'
		cases+=1
	return dict(cases=cases,speeds=9,actors=2,duplicate_waypoints='zero velocity, no divide')


def path_routes(rom,listing,previous_rom,previous_listing):
	"""Compare complete authored journeys against the previous 68000 object."""
	from object_layout import decode
	new=Native(rom,listing);old=Native(previous_rom,previous_listing)
	placements=[r for r in decode((ROOT/'level/objects/SMZ_2.bin').read_bytes()) if r[2]==0xAB]
	assert len(placements)==8
	fields=(('obX',4),('obY',4),('obVelX',2),('obVelY',2),('obInertia',2),
		('obControl',1),('obRoutine',1),('obAnim',1),('obStatus',1),('jumping',1),
		('spindash_flag',1),('tails_flight_flag',1))
	updates=0;routes=[]
	for x,packed,_,_,subtype in sorted(placements,key=lambda row:row[4]):
		for delay,death in ((0,False),(37,False),(0,True)):
			for n in (new,old):
				n.start();obj=n.s['v_lvlobjspace']
				n.write('Camera_X_pos_coarse_back',(x&0xFF80)-128,2)
				n.write('v_rings',99,2)
				for field,value,size in (('code',n.s['SMZ_Teleport'],4),('obX',x,2),
					('obY',packed&0xFFF,2),('obSubtype',subtype,2),
					('obStatus',1 if packed&0x2000 else 0,1)):
					n.put(obj,field,value,size)
				for actor in ('v_player','v_player2'):
					n.put(actor,'obX',x-8 if packed&0x2000 else x+8,2)
					n.put(actor,'obY',packed&0xFFF,2)
					n.put(actor,'obControl',0x81 if actor=='v_player2' and delay else 0)
			captured=False
			for tick in range(400):
				for n in (new,old):
					if tick==delay:n.put('v_player2','obControl',0)
					if death and tick==80:n.put('v_player2','obRoutine',6)
					n.act('SMZ_Teleport_Main' if tick and 'SMZ_Teleport_Main' in n.s else 'SMZ_Teleport',n.s['v_lvlobjspace'])
				for actor in ('v_player','v_player2'):
					assert tuple(new.get(actor,f,z) for f,z in fields)==tuple(
						old.get(actor,f,z) for f,z in fields),(subtype,delay,death,tick,actor)
				assert new.cpu.mem_read((new.s['v_lvlobjspace']+0x30)&0xFFFFFF,20)==old.cpu.mem_read(
					(old.s['v_lvlobjspace']+0x30)&0xFFFFFF,20),(subtype,delay,death,tick,'rider packets')
				captured|=new.get('v_player','obControl')==0x81
				updates+=2
				if tick>delay and captured and not any(new.get(a,'obControl') for a in ('v_player','v_player2')):
					break
			assert captured and tick<399,(subtype,delay,death,'never released')
			routes.append(dict(subtype=subtype,tail_delay=delay,tail_dies=death,updates=tick+1))
	return dict(routes=routes,actor_updates=updates,mismatches=0)


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
	p.add_argument('--previous-rom',type=Path,help='Compare all authored paths against the previous controller')
	p.add_argument('--previous-listing',type=Path)
	p.add_argument('--before-rom',type=Path)
	p.add_argument('--before-listing',type=Path)
	p.add_argument('--core',type=Path)
	p.add_argument('--system-directory',type=Path)
	p.add_argument('--player',type=int,choices=(0,2),default=0)
	args=p.parse_args()
	args.output.mkdir(parents=True,exist_ok=True)
	report={'paths':path_math(args.rom,args.listing),
			'dispatch':dispatch_counts(args.rom,args.listing),
			'native':tunnel(args.rom,args.listing),
			'stars':tunnel(args.rom,args.listing,True)}
	assert not report['native']['position_mismatches'] and not report['stars']['position_mismatches'],report
	if bool(args.previous_rom)!=bool(args.previous_listing):
		p.error('--previous-rom and --previous-listing must be paired')
	if args.previous_rom:report['routes']=path_routes(args.rom,args.listing,args.previous_rom,args.previous_listing)
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
