#!/usr/bin/env python3
"""Standard Mecha Sonic: upstream motion oracle and real SMZ2 trap/fight/results.

Game scenes use the authored placement and controller input for the crossing.
Focused actor positioning supplies jumping hits; this is not a full playthrough.
The optional upstream reference executes original 68000 attack/animation code;
audio/child effects and a flat floor are explicit oracle boundaries. Separate
live audio checks observe the restored jet sound through the actual Z80/YM path.
"""
from pathlib import Path
import argparse,json,re,struct,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]

def reference(m,args):
	import native_test_core as n
	source=(args.skdisasm/'sonic3k.asm').read_text()
	state=source[source.index('SSZEndBoss_Index:'):source.index('\nloc_7B2DC:')]
	state+=source[source.index('\nloc_7B3E6:'):source.index('\nloc_7B81A:')]
	anim=source[source.index('byte_7D4DE:'):source.index('byte_7D5F6:')]
	matches=list(re.finditer(r'(?m)^(byte_[0-9A-F]+):',anim))
	needed={'byte_7D4DE','byte_7D4EF','byte_7D523','byte_7D541','byte_7D54A','byte_7D596','byte_7D59B','byte_7D5A2'}
	anim=''.join(anim[x.start():matches[i+1].start() if i+1<len(matches) else len(anim)] for i,x in enumerate(matches) if x[1] in needed)
	raw=source[source.index('\nAnimate_RawMultiDelay:'):source.index('\nAnimate_RawMultiDelayFlipX:')]
	wait=source[source.index('\nObj_Wait:'):source.index('\nObjHitFloor2_DoRoutine:')]
	edge=source[source.index('\nloc_7D216:'):source.index('; =============== S U B R O U T I N E',source.index('\nloc_7D216:'))]
	aliases={'routine':'obRoutine','mapping_frame':'obFrame','render_flags':'obRender','x_pos':'obX','y_pos':'obY','x_vel':'obVelX','y_vel':'obVelY','y_radius':'obHeight','anim_frame':'obAniFrame','anim_frame_timer':'obTimeFrame','subtype':'obSubtype','Camera_X_pos':'Camera_X_pos','Camera_Y_pos':'Camera_Y_pos','Random_Number':'RandomNumber','MoveSprite':'ObjectMoveAndFall','MoveSprite2':'ObjectMove','MoveSprite_LightGravity':'ObjectMoveAndFall_LightGravity','ObjCheckFloorDist':'ObjHitFloor','Play_SFX':'PlaySound_Special','sfx_MechaLand':'SndID_MechaLand','sfx_Dash':'sfx_Dash','sfx_Thump':'SndID_Thump'}
	lines=['\tCPU 68000',f'\tinclude "{ROOT}/_definitions/s2.macrosetup.asm"','\t!org 0','\tphase $300000']
	lines += [f'{k} equ ${m.s[v]:X}' for k,v in aliases.items()]
	lines += ['_unkFAB4 equ $FFFFDF00','_unkFAB6 equ $FFFFDF02','_unkFAB0 equ $FFFFDF04','_unkFAB8 equ $FFFFDF06','loc_7B2DC equ Ref_Return','loc_7B3AC equ Ref_Return','Ref_Step:','\tmoveq #0,d0','\tmove.b routine(a0),d0','\tmove.w SSZEndBoss_Index(pc,d0.w),d1','\tjsr SSZEndBoss_Index(pc,d1.w)','\trts',state,anim,'\teven',raw,wait,edge,'Set_Raw_Animation:','\tmove.l a1,$30(a0)','\tclr.b anim_frame(a0)','\tclr.b anim_frame_timer(a0)','\trts','CreateChild6_Simple:','\tmoveq #1,d0','\trts','ChildObjDat_7D47A: dc.w 0','ChildObjDat_7D480: dc.w 0','ChildObjDat_7D486: dc.w 0','Ref_Return: rts','\tdephase']
	path=args.output/'reference.asm';path.write_bytes(('\n'.join(lines)+'\n').replace('\n','\r\n').encode())
	tool=ROOT/'build_tools/Linux-x86_64'
	r=subprocess.run([str(tool/'asl'),'-xx','-n','-q','-A','-L','-U',str(path.resolve())],cwd=ROOT,capture_output=True,text=True)
	assert r.returncode==0,r.stdout+r.stderr
	subprocess.run([str(tool/'p2bin'),'-p=FF',str(path.with_suffix('.p')),str(path.with_suffix('.bin'))],check=True)
	labels={k:int(v,16) for k,v in re.findall(r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',path.with_suffix('.lst').read_text())}
	return labels,path.with_suffix('.bin').read_bytes()

def native(args):
	import native_test_core as n
	class Machine(n.Manager):
		def hook(self,cpu,address,size,unused):
			if address==self.s['PlayMusic'] and hasattr(self,'sounds'):
				self.sounds.append(cpu.reg_read(n.UC_M68K_REG_D0)&255)
			if address==self.s['PlayMusic'] and hasattr(self,'music'):
				self.music.append(cpu.reg_read(n.UC_M68K_REG_D0)&255)
			if address==self.s['ObjHitFloor']:
				a=cpu.reg_read(n.UC_M68K_REG_A0)
				distance=0x5C0-self.get(a,'obY',2)-self.get(a,'obHeight')-1
				cpu.reg_write(n.UC_M68K_REG_D1,distance&65535)
				stack=cpu.reg_read(n.UC_M68K_REG_A7)
				cpu.reg_write(n.UC_M68K_REG_PC,int.from_bytes(cpu.mem_read(stack,4),'big'))
				cpu.reg_write(n.UC_M68K_REG_A7,stack+4)
	m=Machine(args.rom,args.listing);m.start();pool=list(m.pool());body=pool[0];checks=[]
	from check_sprite_assets import frames
	entry_map=frames((ROOT/'mappings/sprite/Mecha Sonic.bin').read_bytes())[2]
	entry_feet=max(y+((size&3)+1)*8 for y,size,_,_ in entry_map)
	assert m.s['MS_EntryRadius']+1==entry_feet, ('Entry pose clips the floor',entry_feet)
	checks.append('entry floor sensor matches the actual frame-2 foot baseline')
	for slot in pool:m.put(slot,'code',m.s['MS_Return'])
	m.put(body,'code',m.s['MechaSonic']);m.act('MS_Init',body)
	assert m.get(body,'MS_phase')==0
	m.put(pool[-1],'code',0);m.act('MS_Init',body)
	assert m.get(body,'MS_phase')==1 and m.get(pool[-1],'code')==m.s['MS_HeadHitbox']
	assert m.get(body,'obColProp')==16
	checks.append('16-hit constructor retries a full pool without a half-initialized hitbox')
	for slot in pool:m.put(slot,'code',m.s['MS_Return'])
	m.put(body,'code',m.s['MechaSonic']);m.put(body,'MS_phase',8)
	m.put(body,'MS_script',m.s['MS_AnimDefeat'],4);m.put(body,'MS_history',50)
	m.act('MS_Reward',body,{n.UC_M68K_REG_D7:0x55})
	assert m.get(body,'code')==m.s['MechaSonic']
	m.put(pool[-1],'code',0);m.act('MS_Reward',body,{n.UC_M68K_REG_D7:0x55})
	assert m.get(body,'code')==m.s['MechaSonic'] and m.get(body,'MS_phase')==9
	assert m.get(pool[-1],'code')==m.s['Signpost'] and m.get(pool[-1],'obSubtype')==1
	for _ in range(300):m.act('MechaSonic',body)
	assert m.get(body,'code')==m.s['MechaSonic'] and sum(m.get(o,'code')==m.s['Signpost'] for o in pool)==1
	assert m.cpu.reg_read(n.UC_M68K_REG_D7)==0x55
	checks.append('defeat retries one falling sign, retains body/palette/effects and preserves dispatcher D7')
	m.start();body,child=pool[-1],pool[0]
	for f,v,z in [('code',m.s['MechaSonic'],4),('MS_phase',4,1),('MS_hitbox',child,2),('obX',0x1E80,2),('obY',0x5A0,2),('obFrame',0,1),('obRender',4,1)]:m.put(body,f,v,z)
	m.put(child,'code',m.s['MS_HeadHitbox']);m.put(child,'MS_parent',body,2)
	m.act('MS_UpdateHitbox',body,{n.UC_M68K_REG_D7:0x55})
	assert (m.get(child,'obX',2),m.get(child,'obY',2))==(0x1E90,0x594)
	assert m.read('Collision_response_list',2)==2 and m.read('Collision_response_entries',2)==child&65535
	assert m.cpu.reg_read(n.UC_M68K_REG_D7)==0x55
	m.put(child,'code',m.s['MS_Return']);m.put(child,'obX',0x1234,2)
	m.act('MS_UpdateHitbox',body);assert m.get(child,'obX',2)==0x1234
	m.put(child,'code',m.s['MS_HeadHitbox']);m.put(body,'code',m.s['MS_Return'])
	m.act('MS_HeadHitbox',child);assert not m.get(child,'code')
	checks.append('earlier invisible child registers in the same update; reused slots survive and orphan hitboxes retire')
	m.start();body=pool[0]
	for slot in pool:m.put(slot,'code',m.s['MS_Return'])
	m.put(body,'code',m.s['MechaSonic']);m.put(body,'MS_flags',4)
	end=m.s['v_lvlobjend']&0xFFFFFF;canary=bytes(m.cpu.mem_read(end,8))
	m.act('MS_MaintainJets',body)
	assert not m.get(body,'MS_jet1',2) and bytes(m.cpu.mem_read(end,8))==canary
	for index,field in ((-1,'MS_jet1'),(-2,'MS_jet2')):
		m.put(pool[index],'code',0);m.act('MS_MaintainJets',body)
		assert m.get(body,field,2)==pool[index]&65535 and m.get(pool[index],'code')==m.s['MS_Jet']
	checks.append('jet pairs recover from partial allocation without writing beyond the pool')
	m.sounds=[]
	for _ in range(8):m.act('MS_MaintainJets',body)
	assert not m.sounds, 'Maintaining the pair retriggered the jet sound'
	m.act('MS_CreateJets',body,{n.UC_M68K_REG_A2:m.s['MS_JetsDash']})
	assert m.sounds==[m.s['sfx_Roll']],m.sounds
	for _ in range(8):m.act('MS_MaintainJets',body)
	assert m.sounds==[m.s['sfx_Roll']],m.sounds
	m.start();m.sounds=[];body=pool[0]
	for slot in pool:m.put(slot,'code',m.s['MS_Return'])
	m.put(body,'code',m.s['MechaSonic']);m.put(body,'MS_flags',4)
	m.act('MS_MaintainJets',body);assert not m.sounds
	m.put(pool[-1],'code',0);m.act('MS_MaintainJets',body)
	assert m.sounds==[m.s['sfx_Roll']],m.sounds
	checks.append('jet allocation/recovery and a reused pair changing kind play Roll once; full-pool retries and maintenance do not retrigger it')

	for pal,ticks in ((0,120),(0x40,100)):
		m.start();body,sign=pool[:2]
		m.put(body,'code',m.s['MechaSonic']);m.put(body,'MS_phase',2)
		m.put(body,'MS_sign',sign,2);m.put(body,'MS_sign_y',0x5A4,2)
		m.write('Camera_X_pos',m.s['MS_ArenaX'],2);m.write('Camera_Y_pos',m.s['MS_ArenaY'],2)
		m.put(sign,'code',m.s['Signpost']);m.put(sign,'obRoutine',16)
		m.put(sign,'obFrame',6);m.put(sign,'signpost_loaded',6)
		m.write('v_megadrive',pal)
		for _ in range(ticks+10):m.act('MS_AwaitPortrait',body)
		assert not m.get(body,'MS_timer',2) and m.get(body,'MS_phase')==2
		m.put(sign,'obRoutine',18);m.put(sign,'signpost_loaded',255)
		m.act('MS_AwaitPortrait',body);assert not m.get(body,'MS_timer',2)
		m.put(sign,'signpost_loaded',6);m.put(sign,'obFrame',4)
		m.act('MS_AwaitPortrait',body);assert not m.get(body,'MS_timer',2)
		m.put(sign,'obFrame',6);m.act('MS_AwaitPortrait',body)
		assert m.get(body,'MS_timer',2)==ticks+1
		for y in (0x440,0x560):
			m.write('Camera_Y_pos',y,2);m.act('MS_AwaitPortrait',body)
			assert m.get(body,'MS_timer',2)==ticks+1 and m.get(body,'MS_phase')==2
		m.write('Camera_Y_pos',m.s['MS_ArenaY'],2)
		for _ in range(ticks):
			m.act('MS_AwaitPortrait',body)
			assert m.get(body,'MS_phase')==2 and not m.get(body,'obVelX',2)
		m.act('MS_AwaitPortrait',body)
		assert m.get(body,'MS_phase')==3 and m.get(body,'obVelX',2)==0xF800
	checks.append('settled final portrait/DPLC gates a separate two-second NTSC/PAL warning plus first-DMA grace')
	for actor,mode,dx,change,expected in (
			('v_player',0,0,None,True),('v_player',2,-24,None,True),
			('v_player2',0,24,None,True),('v_player2',1,0,None,False),
			('v_player',0,25,None,False),('v_player',0,-25,None,False),
			('v_player',0,0,('spindash_flag',0,1),False),
			('v_player',0,0,('obAnim',2,1),False),
			('v_player',0,0,('obStatus',2,1),False),
			('v_player',0,0,('obRoutine',6,1),False),
			('v_player',0,0,('code',0,4),False),
			('v_player',0,0,('obVelX',0x100,2),False)):
		m.start();body=pool[0];m.write('Player_mode',mode,2)
		for f,v,z in [('code',m.s['MechaSonic'],4),('MS_phase',4,1),('obRoutine',12,1),
						('obX',0x1F00,2),('obY',0x520,2),('obHeight',31,1),
						('obColType',9,1),('obColProp',16,1),('MS_script',m.s['MS_AnimLandingRoll'],4),
						('MS_callback',m.s['MS_Landed'],4),('MS_left',0x1E60,2),('MS_right',0x1F60,2)]:m.put(body,f,v,z)
		for f,v,z in [('obX',0x1F00+dx,2),('obY',0x5B1,2),('obHeight',14,1),
						('obStatus',0,1),('spindash_flag',1,1),('obAnim',m.s['AniIDSonAni_Spindash'],1)]:m.put(actor,f,v,z)
		if change:m.put(actor,*change)
		m.act('MS_CheckLandingCamper',body)
		assert bool(m.get(body,'MS_flags')&2)==expected,(actor,mode,dx,change)
		if expected:
			assert m.get(body,'obFrame')==3 and m.get(body,'obVelY',2)==0x800
			assert m.get(body,'obHeight')==15 and m.get(body,'MS_callback',4)==m.s['MS_CounterLanded']
			m.put(actor,'spindash_flag',0)  # committed aim survives release
			for _ in range(40):
				m.act('MS_RunFight',body)
				if not m.get(body,'MS_flags')&2:break
				assert m.get(body,'obColType')==0x86 and 3<=m.get(body,'obFrame')<=5
			else:raise AssertionError('Counter dive never landed')
			assert m.get(body,'obY',2)==0x5A0 and m.get(body,'obHeight')==31
			assert m.get(body,'MS_flags')&1 and m.get(body,'obRoutine')==14
	checks.append('landing camper detection: both actors, inclusive footprint, released/moving/air/dead/solo exclusions; harmful roll commits then unrolls on the same floor')
	for x in (0x1E60,0x1EA0,0x1EE0,0x1F20,0x1F60):
		for turn in (0,8):
			for facing in (0,1):
				m.start();body=pool[0]
				m.write('Camera_X_pos',m.s['MS_ArenaX'],2)
				for f,v,z in [('code',m.s['MechaSonic'],4),('MS_phase',4,1),('obColProp',16,1),
						('obX',x,2),('obY',0x5B0,2),('obHeight',15,1),('MS_flags',turn|2,1),
						('obRender',4|facing,1),('MS_left',0x1E60,2),('MS_right',0x1F60,2)]:m.put(body,f,v,z)
				m.act('MS_CounterLanded',body)
				assert m.get(body,'obY',2)==0x5A0 and m.get(body,'obRender')&1==int(x<=0x1EE0)
				assert m.get(body,'MS_script',4)==m.s['MS_AnimTurnStand' if turn else 'MS_AnimGroundWindup']
				states=set()
				for _ in range(200):
					m.act('MS_RunFight',body);states.add(m.get(body,'obRoutine'))
					if m.get(body,'obRoutine')==14:
						assert m.get(body,'obRender')&1==int(x<=0x1EE0),('Outward windup',x,turn,facing)
					if m.get(body,'obRoutine')==16:
						assert 0x1E60<=m.get(body,'obX',2)<=0x1F60
						assert m.get(body,'obRender')&1==int(x<=0x1EE0)
						velocity=m.get(body,'obVelX',2)
						assert (velocity<0x8000)==(x<=0x1EE0),('Outward dash',x,velocity)
					if m.get(body,'obRoutine')==20:break
				assert 20 in states and (turn or 16 in states),(x,turn,facing,states)
	checks.append('20 counter landings across both arena halves and both original choices resume inward movement, stay inside dash boundaries and reach the next jump')
	for who in ('v_player','v_player2'):
		for boss_code in ('MechaSonic','Obj3D','EHZBoss'):
			for vx,vy,inertia in ((0x600,0x400,0x600),(0xFC00,0xFA00,0xFE00),(0,0x80,0)):
				m.start();body=pool[0]
				m.put(body,'code',m.s[boss_code]);m.put(body,'obColProp',8)
				m.put(who,'obAnim',2)
				for field,value in (('obVelX',vx),('obVelY',vy),('obInertia',inertia)):m.put(who,field,value,2)
				m.act('Touch_Enemy',who,{n.UC_M68K_REG_A1:body})
				assert m.get(body,'obColProp')==7 and not m.get(body,'obColType')
				assert [m.get(who,f,2) for f in ('obVelX','obVelY','obInertia')]==[(-v)&65535 for v in (vx,vy,inertia)]
	checks.append('shared boss touch response preserves full reversed X/Y velocity and ground speed for both actors and all three boss families')
	for start in (0x380,0x4FF,0x500,0x501,0x580,0x720):
		m.start();m.write('Current_ZoneAndAct',(m.s['id_SMZ']<<8)|1,2);m.write('Dynamic_Resize_Routine',1)
		for field,value in (('Camera_X_pos',0x1E40),('Camera_Y_pos',start),('Camera_Min_Y_pos',0xFF00),
				('Camera_Max_Y_pos',max(0x510,start+8)),('Camera_Max_Y_pos_target',0x800),('Camera_Y_pos_bias',m.s['Camera_LookCenter'])):m.write(field,value,2)
		m.put('v_player','obY',start+m.s['Camera_LookCenter'],2)
		for _ in range(600):
			before=m.read('Camera_Y_pos',2);m.act('DynScreenResizeLoad')
			m.act('ScrollVertical','v_player',{n.UC_M68K_REG_A1:m.s['Camera_Y_pos'],n.UC_M68K_REG_A2:m.s['Verti_block_crossed_flag'],
					n.UC_M68K_REG_A3:m.s['Scroll_flags'],n.UC_M68K_REG_A4:m.s['Camera_Y_pos_diff']})
			after=m.read('Camera_Y_pos',2)
			assert abs(after-before)<=2 and abs(after-0x500)<=abs(before-0x500),(start,before,after)
			if after==0x500:break
		else:raise AssertionError(('Camera failed to settle',start,after))
		assert m.read('Camera_Min_X_pos',2)==m.read('Camera_Max_X_pos',2)==0x1E40
	checks.append('arena camera converges from six heights above/on/below its target without a snap')
	for label in ('MS_Defeated','BGHZ_Defeat','EHZBoss_Defeated'):
		m.start();m.music=[];body=pool[0]
		m.put(body,'objoff_38',pool[1],4)
		m.act(label,body)
		assert m.music==[m.s['MusID_FadeOut']],(label,m.music)
	checks.append('all three implemented bosses request a music fade at defeat')
	m.start();body=pool[0];player=m.s['v_player']
	for f,v,z in [('code',m.s['MechaSonic'],4),('MS_phase',4,1),('MS_flags',1,1),
					('obColProp',16,1),('obX',0x1F00,2),('obY',0x5A0,2)]:m.put(body,f,v,z)
	for hit in range(3):
		for f,v,z in [('obX',0x1F00,2),('obY',0x580,2),('obStatus',6,1),
						('obAnim',2,1),('obVelY',0x400,2)]:m.put(player,f,v,z)
		m.act('Touch_Enemy',player,{n.UC_M68K_REG_A1:body,n.UC_M68K_REG_D7:0x55})
		assert m.get(body,'obColProp')==15-hit
		assert m.get(body,'MS_head_hits')==((hit+1)%3)
		assert bool(m.get(body,'MS_shot_pending'))==(hit==2)
		assert m.cpu.reg_read(n.UC_M68K_REG_D7)==0x55
	for slot in pool[1:]:m.put(slot,'code',m.s['MS_Return'])
	m.act('MS_FireCounterShot',body);assert m.get(body,'MS_shot_pending')
	ball=pool[-1];m.put(ball,'code',0)
	m.act('MS_FireCounterShot',body,{n.UC_M68K_REG_D7:0x55})
	assert not m.get(body,'MS_shot_pending') and m.get(ball,'code')==m.s['MS_EnergyBall']
	assert m.get(ball,'obVelY',2)==0xFC00 and not m.get(ball,'obVelX',2)
	assert m.get(ball,'obY',2)==0x580 and m.get(ball,'obFrame')==8 and m.get(ball,'obColType')==0x87
	assert m.cpu.reg_read(n.UC_M68K_REG_D7)==0x55
	m.write('Camera_Y_pos',0x500,2);m.act('MS_EnergyBall',ball)
	assert m.get(ball,'obY',2)==0x57C
	m.put(body,'MS_phase',5);m.act('MS_EnergyBall',ball);assert not m.get(ball,'code')
	for field,value,size in [('obStatus',0,1),('obVelY',0xFC00,2),('obY',0x5A0,2),('obX',0x1F20,2)]:
		for f,v,z in [('obX',0x1F00,2),('obY',0x580,2),('obStatus',6,1),('obVelY',0x400,2)]:m.put(player,f,v,z)
		m.put(body,'MS_phase',4);m.put(body,'MS_head_hits',2)
		m.put(player,field,value,size);m.act('MS_RecordHit',player,{n.UC_M68K_REG_A1:body})
		assert not m.get(body,'MS_head_hits') and not m.get(body,'MS_shot_pending'),field
	checks.append('real touch damage counts only downward grounded head bounces; third hit queues exactly one upward ball, retries a full pool and cleans up at defeat')
	if args.skdisasm:
		ref=Machine(args.rom,args.listing);labels,data=reference(m,args);ref.s.update(labels);ref.cpu.mem_write(0x300000,data)
		m.start();ref.start()
		fields=[('obRoutine',1),('obFrame',1),('obX',4),('obY',4),('obVelX',2),('obVelY',2),('obRender',1),('obHeight',1),('MS_flags',1),('MS_attack',1),('MS_attack_count',1),('MS_timer',2),('MS_accel',2),('obAniFrame',1),('obTimeFrame',1)]
		for machine in (m,ref):
			machine.write('Camera_X_pos',0x1E40,2);machine.write('Camera_Y_pos',0x500,2);machine.write('v_random',0x12345678,4)
			for key,val,z in [('code',machine.s['MechaSonic'],4),('MS_phase',4,1),('obRoutine',6,1),('MS_timer',63,2),('obFrame',2,1),('obRender',4,1),('obX',0x1E20,2),('obY',0x5A0,2),('obHeight',31,1),('obColProp',16,1),('obColType',9,1),('MS_left',0x1E60,2),('MS_right',0x1F60,2),('MS_top',0x530,2)]:machine.put(body,key,val,z)
		m.put(body,'MS_callback',m.s['MS_ReturnSweep'],4);ref.put(body,'MS_callback',labels['loc_7B41C'],4)
		for address,value,z in [(0xFFDF00,0x1E60,2),(0xFFDF02,0x1F60,2),(0xFFDF04,0x530,2),(0xFFDF06,0,1)]:ref.cpu.mem_write(address,value.to_bytes(z,'big'))
		states=set()
		for tick in range(8400):
			m.act('MS_RunFight',body);ref.act('Ref_Step',body)
			for field,z in fields:
				actual=m.get(body,field,z)
				if field=='MS_flags':actual &= ~3  # local grounded/dive bits
				assert actual==ref.get(body,field,z),(tick,field,actual,ref.get(body,field,z))
			assert m.get(body,'MS_history')==int.from_bytes(ref.cpu.mem_read(0xFFDF06,1),'big')
			assert m.read('v_random',4)==ref.read('v_random',4)
			states.add(m.get(body,'obRoutine'))
		assert {8,12,14,16,20,22,24,26,28,30,32,34,36,38,40}<=states,states
		checks.append('8400 updates match original skdisasm attack states, raw animations, positions, velocities and RNG')
	return checks

def game(args):
	import ctypes as C
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_music_sequences import current_music
	from check_companion_followup import place
	g=Genesis(args.core,args.rom,args.listing,args.output/'game',args.pal,system_directory=args.system_directory)
	zram=g.zram
	rom=args.rom.read_bytes()
	def song_entry(music):
		return g.s[music]
	def playing_song():
		return current_music(g,rom,zram)
	boot_level(g,zone=g.s['id_SMZ'],act=1,player=args.player)
	pool=list(range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']))
	def objects(label):return [o for o in pool if g.get(o,'code')==g.s[label]]
	def run(count=1):
		for _ in range(count):g.run();assert not g.read('v_errortype'),('CPU exception',g.frame)
	actors=['v_player'] if args.player==2 else ['v_player','v_player2']
	for j,actor in enumerate(actors):
		place(g,actor,0x1E10 if j==0 else 0x1E80,0x530 if j==0 else 0x5AD,j==0);g.put(actor,'obControl',0 if j==0 else 1)
	g.write('Camera_X_pos',0x1E40,2);g.write('Camera_Y_pos',0x500,2);g.write('v_rings',99,2);g.write('f_ringcount',1)
	g.write('Tails_CPU_idle_timer',6000,2);g.buttons2={4}
	run(90);signs=objects('Signpost');assert len(signs)==1
	sign=signs[0];assert g.get(sign,'obSubtype')==2 and g.get(sign,'obFrame')==2
	g.video.save(args.output/'game/before.png')
	if args.approach!='level':
		y=0x440 if args.approach=='above' else 0x560
		g.write('Camera_Y_pos',y,2);g.write('Camera_Max_Y_pos',max(0x510,y+8),2)
		place(g,'v_player',0x1ED8,0x4A0 if args.approach=='above' else 0x5AD,args.approach=='above')
		g.put('v_player','obVelY',0x300 if args.approach=='above' else 0,2)
	for actor in actors:g.put(actor,'obStatusSecondary',2);g.put(actor,'invtime',2000,2)
	zram[g.s['zAbsVar.QueueToPlay']]=g.s['bgm_Invincible']
	g.put('v_player','obControl',0);g.put('v_player','obVelX',0x600,2);g.put('v_player','obInertia',0x600,2);g.buttons={7};spin=set();seen=set();broken=False;boss=None
	settled=None;entry=None;warning_ticks=100 if args.pal else 120
	root=g.s['DPLC_Signpost'];cue=root+struct.unpack_from('>h',args.rom.read_bytes(),root+12)[0]
	portrait=bytearray()
	for i in range(struct.unpack_from('>H',rom,cue)[0]):
		word=struct.unpack_from('>H',rom,cue+2+i*2)[0]
		start=g.s['Art_Signpost']+(word&4095)*32
		portrait+=rom[start:start+((word>>12)+1)*32]
	camera=[]
	for t in range(700):
		run()
		camera.append(g.read('Camera_Y_pos',2))
		if len(camera)>1:assert abs(camera[-1]-camera[-2])<=16,('Camera snapped',camera[-2:])
		if t==120:g.buttons=set()
		assert not g.get('v_endcard','code'),'premature act results'
		if g.get(sign,'code')==g.s['Signpost']:
			spin.add(g.get(sign,'obFrame'))
			if settled is None and g.get(sign,'obRoutine')==18 and g.get(sign,'obFrame')==6 and g.get(sign,'signpost_loaded')==6:
				actual=bytes(g.vram[(g.s['ArtTile_Signpost']*32+i)^1] for i in range(len(portrait)))
				if actual==portrait:
					settled=g.frame;g.video.save(args.output/'game/settled-warning.png')
		if objects('MechaSonic'):
			boss=objects('MechaSonic')[0];g.buttons=set();seen.add(g.get(boss,'MS_phase'))
			if g.get(boss,'MS_phase')>=3 and entry is None:
				entry=g.frame
				assert g.get(boss,'obY',2)+g.get(boss,'obHeight')+1==0x5C0
				assert g.get(boss,'obY',2)+32==0x5C0, 'Entry sprite feet clip the authored floor'
				g.video.save(args.output/'game/entry.png')
				assert settled is not None and entry-settled>=warning_ticks,(settled,entry,warning_ticks)
			if settled is not None and g.frame-settled<warning_ticks:
				assert g.get(boss,'MS_phase')<3 and not objects('MS_SignDebris')
			if objects('MS_SignDebris') and not broken:g.video.save(args.output/'game/sign-destroyed.png');broken=True
			if g.get(boss,'MS_phase')==4:break
	assert boss and {2,4,6,9,10}<=spin and broken,(boss,spin,seen,broken,{f:g.get('v_player',f,z) for f,z in [('obX',2),('obY',2),('obVelX',2),('obStatus',1),('obControl',1),('obRoutine',1)]})
	assert entry is not None and settled is not None
	assert g.get(sign,'code')!=g.s['Signpost']
	assert g.get(boss,'obColProp')==16
	assert g.read('Camera_Min_X_pos',2)==g.read('Camera_Max_X_pos',2)==0x1E40
	assert not objects('Signpost')
	assert g.read('f_lockscreen') and playing_song()==song_entry('MusID_Boss3')
	for actor in actors:g.put(actor,'invtime',1,2)
	run(4)
	assert playing_song()==song_entry('MusID_Boss3') and all(not g.get(a,'obStatusSecondary')&2 for a in actors)
	(args.output/'game/camera.json').write_bytes((json.dumps({'approach':args.approach,'y':camera})+'\n').replace('\n','\r\n').encode())
	checks=['authored SMZ2 sign: controller crossing, Eggman/Mecha mixed frames, side entry, debris and no early results']
	checks.append(f'settled visible portrait gets {entry-settled} frames before Mecha enters; minimum {warning_ticks}')
	fight=g.save()
	place(g,'v_player',0x1F60,0x5AD,False);g.put('v_player','obStatusSecondary',2);g.put('v_player','invtime',600,2)
	g.buttons={7}
	for _ in range(120):
		run();assert g.get('v_player','obX',2)<=0x1F68,('Escaped right edge',g.get('v_player','obX',2))
	g.restore(fight);g.buttons=set()
	checks.append(f'{args.approach} camera entry stays smooth, entry feet meet the floor, right boundary holds, and invincibility expiry retains Boss 3 music')
	# Exercise both random landing choices at both edges and with either player facing.
	for counter_x,turn,player_facing in ((x,t,f) for x in (0x1E60,0x1F60) for t in (0,8) for f in (0,1)):
		g.restore(fight);g.buttons=set()
		# Position the descent, then use actual down+B input to charge beneath it.
		for actor in actors:place(g,actor,0x1E60,0x4D0);g.put(actor,'obControl',1)
		place(g,'v_player',counter_x,0x5AD,False)
		g.put('v_player','obStatus',player_facing)
		g.put('v_player','obStatusSecondary',1)	# absorb the counter without a ring burst obscuring the stance
		g.buttons={5};run(4);g.buttons={5,0};run();g.buttons={5}
		assert g.get('v_player','spindash_flag'),'Controller input did not start the charge'
		for f,v,z in [('obRoutine',12,1),('obX',counter_x,2),('obY',0x520,2),
						('obVelX',0,2),('obVelY',0,2),('obHeight',31,1),('MS_flags',turn,1),
						('obStatus',0,1),('MS_flash',0,1),('obFrame',3,1),
						('MS_script',g.s['MS_AnimLandingTurn'],4),('MS_callback',g.s['MS_Landed'],4),
						('obAniFrame',0,1),('obTimeFrame',0,1)]:g.put(boss,f,v,z)
		run();assert g.get(boss,'MS_flags')&2
		g.video.save(args.output/'game/counter-dive.png')
		hurt=False
		for _ in range(40):
			run();hurt |= g.get('v_player','obRoutine')==4
			assert g.get(boss,'obColProp')==16,'Charging player damaged the rolling counter'
			if not g.get(boss,'MS_flags')&2:break
		else:raise AssertionError('Live counter did not land')
		assert hurt,'Rolling counter did not hit the charging player'
		assert g.get(boss,'obHeight')==31 and g.get(boss,'MS_flags')&1
		assert g.get(boss,'obRender')&1==int(counter_x<=0x1EE0),(counter_x,turn,player_facing,'outward landing')
		assert g.get(boss,'obY',2)+32==0x5C0
		g.video.save(args.output/f'game/counter-landed-{counter_x:X}-{turn}-{player_facing}.png')
		for actor in actors:place(g,actor,0x1EE0,0x4D0);g.put(actor,'obControl',1)
		g.buttons=set()
		for tick in range(210):
			run()
			routine=g.get(boss,'obRoutine')
			if routine==14:
				assert g.get(boss,'obRender')&1==int(counter_x<=0x1EE0),(counter_x,turn,'outward windup')
				if tick==5:g.video.save(args.output/f'game/counter-windup-{counter_x:X}-{turn}-{player_facing}.png')
			if routine==16:
				velocity=g.get(boss,'obVelX',2)
				assert (velocity<0x8000)==(counter_x<=0x1EE0),(counter_x,'outward follow-up dash')
				if tick==45:g.video.save(args.output/f'game/counter-dash-{counter_x:X}.png')
			if routine==20:break
		else:raise AssertionError('Counter did not resume the next jump')
	checks.append('eight actual down+B counters cover both edges, landing choices and player facings: harmful roll, aligned feet, inward windup/dash and next jump')
	g.restore(fight);g.buttons=set();g.buttons2={4}
	# Freeze the ordinary ground windup long enough for three genuine contacts.
	# Only actor positions/velocity are restaged; HP and the streak are never edited.
	for actor in actors:place(g,actor,0x1E60,0x4D0);g.put(actor,'obControl',1)
	for f,v,z in [('obRoutine',14,1),('obX',0x1F00,2),('obY',0x5A0,2),
					('obVelX',0,2),('obVelY',0,2),('obFrame',0,1),('MS_flags',1,1),
					('MS_script',g.s['MS_AnimDashStop'],4),('MS_callback',g.s['MS_PrepareJump'],4),
					('obAniFrame',4,1),('obTimeFrame',127,1),('obColType',0x23,1)]:g.put(boss,f,v,z)
	shooter='v_player2' if args.companion else 'v_player'
	x=g.get(boss,'obX',2);y=g.get(boss,'obY',2)
	place(g,shooter,x-6,y-30)
	for f,v,z in [('obVelY',0x400,2),('obStatus',6,1),('obAnim',2,1),
			('obHeight',14,1),('obWidth',7,1),('jumping',1,1)]:g.put(shooter,f,v,z)
	# From the first contact onward the character follows real air physics.
	# No position, velocity, HP, cooldown or hit streak is repaired between bounces.
	contacts=[];last_hp=16
	for _ in range(160):
		run();hp=g.get(boss,'obColProp')
		if hp!=last_hp:
			assert hp==last_hp-1 and g.get(shooter,'obVelY',2)&0x8000
			contacts.append({'frame':g.frame,'y':g.get(shooter,'obY',2),'rebound':g.get(shooter,'obVelY',2)})
			last_hp=hp
			assert g.get(boss,'MS_head_hits')==len(contacts)%3
			if len(contacts)==3:break
		assert g.get(shooter,'obRoutine')==2,('Lost bounce',contacts)
	else:raise AssertionError(('No three natural consecutive bounces',contacts,last_hp))
	(args.output/'game/consecutive-bounces.json').write_bytes((json.dumps(contacts,indent=2)+'\n').replace('\n','\r\n').encode())

	run();balls=objects('MS_EnergyBall');assert len(balls)==1
	ball=balls[0];assert g.get(ball,'obVelY',2)==0xFC00 and not g.get(ball,'obVelX',2)
	# Check its actual rendered tile bytes and hardware sprite-table entry.
	raw=(ROOT/'art/uncompressed/Mecha Sonic effects.unc').read_bytes()[22*32:24*32]
	assert bytes(g.vram[((g.s['ArtTile_MechaEffects']+22)*32+i)^1] for i in range(len(raw)))==raw
	visible=False
	for _ in range(4):
		index=0
		for _ in range(g.s['Sprite_Table_Max']):
			address=g.s['Sprite_Table']+index*8
			visible |= g.read(address+4,2)&2047==g.s['ArtTile_MechaEffects']+22
			index=g.read(address+3)&127
			if not index:break
		if visible:break
		run()
	assert visible,'Counter ball absent from the hardware sprite table'
	g.video.save(args.output/'game/third-head-hit-shot.png')
	for _ in range(80):
		run()
		if not objects('MS_EnergyBall'):break
	else:raise AssertionError('Counter ball did not retire above the camera')
	checks.append(f'three uninterrupted {shooter} head bounces retain HP damage and fire once on hit three; energy ball VRAM, SAT, upward motion and screen exit verified')
	g.restore(fight);g.buttons=set();g.buttons2={4}
	for actor in actors:
		place(g,actor,0x1E60,0x4D0);g.put(actor,'obControl',1)
	# The source jet constructor (loc_7C902) plays Roll. Verify that the
	# real fight starts that FM4 voice, rather than only seeing a 68k queue.
	voice=(g.s['Snd_Roll']+int.from_bytes(rom[g.s['Snd_Roll']:g.s['Snd_Roll']+2],'little'))&0x7FFF|0x8000
	jet_audio=[];jet_keyons=[];audio_chunks=[]
	Batch=C.CFUNCTYPE(C.c_size_t,C.c_void_p,C.c_size_t)
	def batch(data,count):
		audio_chunks.append(C.string_at(data,count*4));return count
	g.callbacks[3]=Batch(batch);g.core.retro_set_audio_sample_batch(g.callbacks[3])
	def rolling():
		start=g.s['zSFX_FM4']
		ptr=start+g.s['zTrack.VoicePtrLow']
		return bool(zram[start]&128) and int.from_bytes(bytes(zram[ptr:ptr+2]),'little')==voice
	writer_slot=None
	if g.emulator.startswith('Genesis Plus GX'):
		Write=C.CFUNCTYPE(None,C.c_uint,C.c_uint8)
		writer_slot=C.c_void_p.in_dll(g.core,'z80_writemem')
		original_address=writer_slot.value;original=Write(original_address);ym_address=[0]
		def write(address,value):
			if address==0x4000:ym_address[0]=value
			if address==0x4001 and ym_address[0]==0x28 and value==0xF4 and rolling():jet_keyons.append(g.frame)
			original(address,value)
		writer=Write(write);writer_slot.value=C.cast(writer,C.c_void_p).value
	states=set()
	for t in range(2400):
		run();r=g.get(boss,'obRoutine');states.add(r)
		if rolling():jet_audio.append(g.frame)
		assert g.get(boss,'obColProp')==16 and not objects('Signpost'),(t,g.get(boss,'obColProp'))
		if r in (16,24,28,36) and t%32==0:g.video.save(args.output/f'game/attack-{r:02x}.png')
	assert {8,12,14,16,20,22,24,26,28,30,32,34,36,38,40}<=states,states
	if writer_slot is not None:
		writer_slot.value=original_address
		assert jet_keyons, 'Jet Roll never keyed on FM4 at the actual YM port'
	assert len(jet_audio)>30, ('Missing live jet sound',jet_audio)
	assert any(any(chunk) for chunk in audio_chunks), 'No fight audio'
	import wave
	with wave.open(str(args.output/'game/jet-sound.wav'),'wb') as wav:
		wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(round(g.sample_rate));wav.writeframes(b''.join(audio_chunks))
	# Keep the callback alive through the remainder of the fight.
	g.callbacks[3]=Batch(lambda data,count:count);g.core.retro_set_audio_sample_batch(g.callbacks[3])
	checks.append('actual attacks run the Roll FM4 voice with PCM output; Genesis Plus GX also verifies YM key-on writes')
	checks.append('all standard attack states run on live SMZ2 terrain without spawning the reward')
	attacker='v_player2' if args.companion else 'v_player'
	assert attacker in actors
	score=g.read('v_score',4)
	for hit in range(16):
		for wait in range(2000):
			if g.get(boss,'MS_flash')==0 and 0<g.get(boss,'obColType')<0x40:break
			run()
		else:raise AssertionError(('no vulnerable state',hit))
		hp=g.get(boss,'obColProp');x=g.get(boss,'obX',2);y=g.get(boss,'obY',2)
		offset=6 if g.get(boss,'obRender')&1 else -6
		shape=g.get(boss,'obColType')&0x3F
		radius=args.rom.read_bytes()[g.s['Touch_Sizes']+(shape-1)*2+1]
		place(g,attacker,x+offset,y-radius-11)
		for f,v,z in [('obVelY',0x400,2),('obStatus',6,1),('obAnim',2,1),('obHeight',14,1),('obWidth',7,1),('jumping',1,1)]:g.put(attacker,f,v,z)
		run()
		assert g.get(boss,'obColProp')==hp-1,(hit,hp,g.get(boss,'obColProp'),g.get(boss,'obFrame'),g.get(attacker,'obRoutine'))
		place(g,attacker,0x1E60,0x510);g.put(attacker,'obControl',1)
		run()
		if hit==0:g.video.save(args.output/'game/hit-flash.png')
	assert g.read('v_score',4)==score+100
	assert g.get(boss,'MS_phase')==5 and not g.read('f_timecount')
	assert not objects('MS_HeadHitbox')
	run(3);fade_start=zram[g.s['zAbsVar.FadeOutCounter']]
	assert 0<fade_start<=0x28,('Boss music did not start fading',fade_start)
	phases=set()
	for t in range(800):
		run()
		if g.get(boss,'code')==g.s['MechaSonic']:
			phase=g.get(boss,'MS_phase');phases.add(phase)
			if phase==7 and t%8==0:g.video.save(args.output/'game/defeat.png')
		if objects('Signpost'):break
	assert {5,6,7}<=phases and objects('Signpost'),phases
	assert not zram[g.s['zAbsVar.FadeOutCounter']]
	assert not zram[g.s['zSongFM1.PlaybackControl']]&128
	reward=objects('Signpost')[0]
	assert g.get(reward,'obSubtype')==1 and objects('MechaSonic')==[boss]
	assert g.get(boss,'MS_phase')==9 and not g.read('f_lockscreen')
	for j,actor in enumerate(actors):place(g,actor,0x1E90-j*0x20,0x5AD,False)
	for t in range(1000):
		run()
		if g.get('v_endcard','code')==g.s['GotThrough'] and g.get('v_endcard','obRoutine'):
			run(60);g.video.save(args.output/'game/results.png')
			assert g.get(boss,'code')==g.s['MechaSonic'] and g.get(boss,'MS_phase')==9
			assert g.get(boss,'obFrame')==15 and g.get(boss,'obY',2)==0x5A0
			break
	else:raise AssertionError('no final falling-sign results')
	assert g.get(reward,'obFrame')==(1 if args.player==2 else 0)
	# Follow the ordinary results route all the way to the next level's load.
	for _ in range(1800):
		assert g.get(boss,'code')==g.s['MechaSonic'] and g.get(boss,'MS_phase')==9
		run()
		if g.read('Current_ZoneAndAct',2)!=((g.s['id_SMZ']<<8)|1):
			break
	else:raise AssertionError('Results never handed off to the next level')
	for _ in range(600):
		run()
		if not objects('MechaSonic') and g.read('Level_started_flag') and g.read('v_gamemode',2)==g.s['Level']:break
	else:raise AssertionError('The next level did not finish loading')
	assert not objects('MechaSonic')
	assert g.read('Current_ZoneAndAct',2)==g.s['id_EHZ']<<8
	g.video.save(args.output/'game/next-level.png')

	checks.append(f'sixteen real {attacker} hits, 1000 points, defeat bursts/collapse/sparks, then falling sign and character results')
	return checks

def main():
	p=argparse.ArgumentParser(description=__doc__)
	for name in ('rom','listing','output'):p.add_argument('--'+name,type=Path,required=True)
	p.add_argument('--core',type=Path);p.add_argument('--system-directory',type=Path);p.add_argument('--skdisasm',type=Path)
	p.add_argument('--approach',choices=('level','above','below'),default='level')
	p.add_argument('--player',type=int,choices=(0,2),default=0);p.add_argument('--pal',action='store_true');p.add_argument('--companion',action='store_true');p.add_argument('--native',action='store_true')
	a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True);checks=[]
	if a.native:checks+=native(a)
	if a.core:checks+=game(a)
	assert checks
	(a.output/'report.json').write_bytes((json.dumps({'passed':True,'checks':checks,'controller_only_playthrough':False},indent=2)+'\n').replace('\n','\r\n').encode())
	print(f'{len(checks)} Mecha Sonic groups pass.')
if __name__=='__main__':main()
