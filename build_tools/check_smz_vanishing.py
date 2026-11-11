#!/usr/bin/env python3
"""Exercise the real vanishing-platform actor with both player slots."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--rom', type=Path, required=True)
parser.add_argument('--listing', type=Path, required=True)
parser.add_argument('--output', type=Path)
parser.add_argument('--core', type=Path)
parser.add_argument('--system-directory', type=Path)
parser.add_argument('--pal', action='store_true')
parser.add_argument('--game-only', action='store_true', help=argparse.SUPPRESS)
args = parser.parse_args()


def game_checks():
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_companion_followup import isolate,place,spawn,reset_cpu
	output=args.output.parent if args.output else ROOT/'test-results/smz-vanp-game'
	g=Genesis(args.core,args.rom,args.listing,output,args.pal,
			  system_directory=args.system_directory)
	rows=[]
	x,y=0x1200,0x300
	for name,actor,mode in (('sonic','v_player',0),('tails','v_player',2),('companion','v_player2',0)):
		if rows:
			g.buttons=g.buttons2=set()
			g.write('v_gamemode',g.s['SegaScreen'],2)
			g.run()
		boot_level(g,zone=8,act=0,player=mode)
		level=g.save()
		for direction in (-1,1):
			for reversed_slots in (False,True):
				g.restore(level)
				isolate(g)
				reset_cpu(g)
				# Isolate the support calculation from the authored terrain.
				# All object/character/camera code and sprite art stay live.
				for cy in range(y//128-2,y//128+2):
					for cx in range(x//128-2,x//128+3):g.layout_cell(cy,cx,0)
				platforms={}
				for offset in ((32,0) if reversed_slots else (0,32)):
					a=spawn(g,'SMZ_VanishPlatform',x+offset,y)
					platforms[offset]=a
					for f,v,z in (('obRoutine',2,1),('obRender',0x84,1),('obActWid',16,1),
						('obMap',g.s['Map_SMZ_VanP'],4),('obGfx',g.s['ArtTile_SMZ_Atlas'],2),
						('obPriority',0x200,2),('height_pixels',32,1),('obAnim',1,1),
						('obPrevAni',1,1),('obAniFrame',3,1),('obTimeFrame',127,1),
						('SMZ_vanp_timer',1000,2),('SMZ_vanp_timelen',127,2)):
						g.put(a,f,v,z)
				start=x-8 if direction>0 else x+40
				height=g.get(actor,'default_y_radius')
				for who in ('v_player','v_player2'):
					place(g,who,start if who==actor else x-96,
						  y-9-height if who==actor else y-120,False)
					g.put(who,'obControl',0x81)
				g.write('Camera_X_pos',x-168,2)
				g.write('Camera_X_pos_coarse_back',(x-168-128)&0xFF80,2)
				g.write('Camera_Y_pos',y-9-height-g.s['Camera_LookCenter'],2)
				g.write('Screen_redraw_flag',1)
				g.run(20)
				# Loading the new camera range can spawn authored conveyors.
				# Clear those after the redraw, retaining the tested pair.
				for a in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']):
					if a not in platforms.values() and g.get(a,'code')!=g.s['SpindashDust']:
						g.write(a,0,g.s['object_size'])
				place(g,actor,start,y-9-height,False)
				g.put(actor,'obStatus',8)
				g.put(actor,'obVelX',direction*0x100&65535,2)
				g.put(actor,'obInertia',direction*0x100&65535,2)
				old=platforms[0 if direction>0 else 32]
				new=platforms[32 if direction>0 else 0]
				index=lambda a:(a-(g.s['v_objspace']&65535))//g.s['object_size']
				g.put(actor,'standonobject',index(old))
				g.put(old,'obStatus',8 if actor=='v_player' else 16)
				camera=y-9-height-g.s['Camera_LookCenter']
				if actor=='v_player':g.write('Camera_Y_pos',camera,2)
				samples=[];cross=None
				for tick in range(40):
					if actor=='v_player2':g.buttons2={7 if direction>0 else 6}
					else:g.buttons={7 if direction>0 else 6}
					g.run()
					sample=dict(x=g.get(actor,'obX',2),y=g.get(actor,'obY',2),
								owner=g.get(actor,'standonobject'),camera=g.read('Camera_Y_pos',2))
					samples.append(sample)
					assert not g.read('v_errortype'),(name,direction,tick,'ROM exception')
					assert sample['y']+g.get(actor,'obHeight')==y-9,(name,direction,reversed_slots,tick,sample)
					if actor=='v_player':assert sample['camera']==camera,(name,'camera blink',tick,sample)
					if sample['owner']==index(new) and cross is None:
						cross=tick
						g.video.save(output/f'{name}-{direction}-{int(reversed_slots)}-cross.png')
					if cross is not None and tick>=cross+6:break
				assert cross is not None,(name,direction,reversed_slots,'No platform handoff')
				assert g.get(new,'obStatus')&(8 if actor=='v_player' else 16)
				rows.append(dict(character=name,direction=direction,reversed_slots=reversed_slots,
								 cross=cross,samples=samples))
				g.buttons=g.buttons2=set()
	g.close()
	report=dict(passed=True,pal=args.pal,cases=rows)
	if args.output:
		args.output.parent.mkdir(parents=True,exist_ok=True)
		args.output.write_text(json.dumps(report,indent=2)+'\n')
	print('12 controller-driven platform handoffs preserve foot height and the primary camera.')


if args.game_only:
	if not args.core:parser.error('--game-only requires --core')
	game_checks()
	raise SystemExit

import native_test_core as m68k
m = m68k.Native(args.rom, args.listing)
obj = m.s['v_lvlobjspace']
checks = []
roles = [('sonic', 'v_player', 1), ('tails', 'v_player', 2),
		 ('companion', 'v_player2', 2)]


def setup(role, frame=0, rolling=False):
	name, player, character = role
	m.start()
	m.write('Camera_X_pos', 400, 2)
	m.write('Player_mode', m.s['PlayerMode_Tails'] if name == 'tails' else 0, 2)
	for actor in ('v_player', 'v_player2'):
		m.put(actor, 'obX', 1000, 2)
	height = m.s['tails_height'] if character == 2 else 19
	radius = m.s['tails_roll_height'] if character == 2 else 14
	m.put(player, 'layout_id', character)
	m.put(player, 'obHeight', radius if rolling else height)
	m.put(player, 'default_y_radius', height)
	m.put(player, 'obX', 576, 2)
	m.put(player, 'obStatus', 6 if rolling else 2)
	for field, value, size in [
			('code', m.s['SMZ_VanishPlatform'], 4), ('obX', 576, 2),
			('obY', 512, 2), ('obRoutine', 2, 1), ('obRender', 0x84, 1),
			('obActWid', 16, 1), ('obMap', m.s['Map_SMZ_VanP'], 4),
			('obAnim', 1, 1), ('obPrevAni', 1, 1), ('obFrame', frame, 1),
			('obTimeFrame', 20, 1), ('SMZ_vanp_timer', 1000, 2),
			('SMZ_vanp_timelen', 127, 2)]:
		m.put(obj, field, value, size)
	return player, m.get(player, 'obHeight')


def actor_state(player):
	return tuple(m.get(player, field, size) for field, size in
				 [('obX', 2), ('obY', 2), ('obVelX', 2), ('obVelY', 2),
				  ('obInertia', 2), ('obStatus', 1)])


for role in roles:
	for frame in (0, 1):
		for rolling in (False, True):
			for offset in (-14, 0, 14):
				for speed in (-0x200, -0x600):
					player, height = setup(role, frame, rolling)
					m.put(player, 'obX', 576 + offset, 2)
					m.put(player, 'obY', 512 + height - 4, 2)
					m.put(player, 'obVelY', speed, 2)
					before = actor_state(player)
					m.act('SMZ_VanishPlatform', obj)
					assert actor_state(player) == before, (role, frame, 'underside', before, actor_state(player))
					checks.append([role[0], frame, rolling, 'rise-through', offset, speed])
			for direction in (-1, 1):
				player, _ = setup(role, frame, rolling)
				m.put(player, 'obX', 576 - direction * 24, 2)
				m.put(player, 'obY', 512, 2)
				m.put(player, 'obVelX', direction * 0x400, 2)
				m.put(player, 'obInertia', direction * 0x400, 2)
				before = actor_state(player)
				m.act('SMZ_VanishPlatform', obj)
				assert actor_state(player) == before, (role, frame, 'side', before, actor_state(player))
				checks.append([role[0], frame, rolling, 'side-through', direction])
		for depth in (0, 4, 10):
			player, height = setup(role, frame)
			m.put(player, 'obY', 504 - height + depth, 2)
			m.put(player, 'obVelY', 0x400, 2)
			m.act('SMZ_VanishPlatform', obj)
			assert m.get(player, 'obStatus') & 8, (role, frame, depth, 'did not land')
			assert not m.get(player, 'obStatus') & 2
			assert m.get(player, 'obY', 2) == 503 - height
			for _ in range(8):
				m.act('SMZ_VanishPlatform', obj)
				assert m.get(player, 'obY', 2) == 503 - height
				assert m.get(player, 'obStatus') & 8
			m.put(player, 'obX', 596, 2)
			m.act('SMZ_VanishPlatform', obj)
			assert not m.get(player, 'obStatus') & 8
			assert m.get(player, 'obStatus') & 2
			checks.append([role[0], frame, 'land-ride-exit', depth])

# The shared landing entry also serves alternate, sloped and bridge supports.
# A flat slope profile gives an independent surface for all three public APIs.
for entry in ('PlatformObject','PlatformObject2','SlopedPlatform'):
	for role in roles:
		for width in (16,32,64):
			for surface_height in (8,9,32):
				player,radius=setup(role)
				m.put(obj,'obActWid',width)
				m.put(player,'obY',512-surface_height-radius+2,2)
				m.put(player,'obVelY',0x200,2)
				m.cpu.mem_write(0x3E0000,bytes([surface_height])*256)
				registers={m68k.UC_M68K_REG_D1:width,m68k.UC_M68K_REG_D3:surface_height,
					m68k.UC_M68K_REG_D4:576,m68k.UC_M68K_REG_A2:0x3E0000}
				for tick in range(6):
					m.act(entry,obj,registers)
					assert m.get(player,'obY',2)+m.get(player,'obHeight')==512-surface_height,(entry,role,width,surface_height,tick)
				checks.append([entry,role[0],width,surface_height,'same landing and ride surface'])

# The first contact and the established ride must share one surface. Exercise
# adjacent platforms in both slot orders, including rolling radius changes.
for role in roles:
	for frame in (0,1):
		for rolling in (False,True):
			for direction in (-1,1):
				for reversed_slots in (False,True):
					player,height=setup(role,frame,rolling)
					second=obj+m.s['object_size']
					m.cpu.mem_write(second&0xFFFFFF,bytes(m.cpu.mem_read(obj&0xFFFFFF,m.s['object_size'])))
					left,right=(second,obj) if reversed_slots else (obj,second)
					m.put(left,'obX',576,2);m.put(right,'obX',608,2)
					for platform in (left,right):m.put(platform,'obTimeFrame',127)
					m.put(player,'obX',568 if direction>0 else 616,2)
					m.put(player,'obY',503-height,2)
					m.put(player,'obVelX',direction*0x100,2)
					m.put(player,'obVelY',0,2)
					m.put(player,'obInertia',direction*0x100,2)
					for tick in range(48):
						if tick<40:m.put(player,'obX',m.get(player,'obX',2)+direction,2)
						for platform in (obj,second):m.act('SMZ_VanishPlatform',platform)
						assert m.get(player,'obY',2)+m.get(player,'obHeight')==503,(role,frame,rolling,direction,reversed_slots,tick,'height changed')
						assert m.get(player,'obStatus')&8
					target=right if direction>0 else left
					assert m.get(player,'standonobject')==((target-m.s['v_objspace'])&65535)//m.s['object_size']
					checks.append([role[0],frame,rolling,direction,reversed_slots,'level platform handoff'])

# The same object supports both players and releases each owned rider as it
# vanishes. The 2 and 3 animation frames must remain non-solid.
for frame in (2, 3):
	setup(roles[0])
	index = ((obj - m.s['v_objspace']) & 65535) // m.s['object_size']
	for player in ('v_player', 'v_player2'):
		height = 19 if player == 'v_player' else m.s['tails_height']
		m.put(player, 'obHeight', height)
		m.put(player, 'default_y_radius', height)
		m.put(player, 'obX', 576, 2)
		m.put(player, 'obY', 504 - height, 2)
		m.put(player, 'obVelY', 0x400, 2)
		m.put(player, 'obStatus', 2)
	m.act('SMZ_VanishPlatform', obj)
	assert m.get(obj, 'obStatus') & 0x18 == 0x18
	for player in ('v_player', 'v_player2'):
		assert m.get(player, 'standonobject') == index
	m.put(obj, 'obFrame', frame)
	m.act('SMZ_VanishPlatform', obj)
	assert not m.get(obj, 'obStatus') & 0x18
	for player in ('v_player', 'v_player2'):
		assert not m.get(player, 'obStatus') & 8
		assert m.get(player, 'obStatus') & 2
	checks.append(['both-players', frame, 'vanish-release'])

if args.core:
	game_output=(args.output.with_suffix('') if args.output else ROOT/'test-results/smz-vanp')/'game/report.json'
	command=[sys.executable,str(Path(__file__).resolve()),'--rom',str(args.rom),
			 '--listing',str(args.listing),'--core',str(args.core),'--game-only','--output',str(game_output)]
	if args.system_directory:command+=['--system-directory',str(args.system_directory)]
	if args.pal:command+=['--pal']
	subprocess.run(command,check=True)

report = {'passed': True, 'rom_sha256': hashlib.sha256(args.rom.read_bytes()).hexdigest(),
		  'companion_ai_run': False, 'checks': checks}
if args.output:
	args.output.parent.mkdir(parents=True, exist_ok=True)
	args.output.write_text(json.dumps(report, indent=2) + '\n')
print(f'{len(checks)} vanishing-platform rise, side, landing, ride and release checks pass.')
