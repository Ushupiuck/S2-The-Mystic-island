#!/usr/bin/env python3
"""Exercise restored EHZ tunnels and platform art in both real act loaders.

The unused S-tunnel is placed in a disposable live-layout scene. Only the
initial player state is staged; normal frames supply the complete traversal.
Platform scenes check loaded mapping pixels and actual landings, not screenshots
alone. These fixtures are not complete controller-only level playthroughs.
"""
from pathlib import Path
import argparse
import json

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import isolate, place, spawn
from check_sprite_assets import frames
from build_ehz_reflection_art import reflection_runs

ROOT = Path(__file__).resolve().parents[1]
TUNNEL = ((0x40,0x41),(0x50,0x51),(0x60,0x61))


def resident_terrain(g,act):
	"""Tilemap equality alone cannot detect an object PLC overwriting terrain."""
	raw = (ROOT/f'art/kosinski/level/8x8 - EHZ{"2" if act else ""}.unc').read_bytes()
	dynamic = set(range(1,17))
	for first,count in reflection_runs():
		dynamic.update(range(first,first+count))
	dynamic.update(range(g.s['ArtTile_Art_Flowers1'],g.s['ArtTile_Art_EHZPulseBall']+2))
	if act:
		dynamic.update(range(g.s['ArtTile_EHZ2_BGWaterfall'],
			g.s['ArtTile_EHZ2_BGWaterfall']+g.s['ArtTile_EHZ2_BGWaterfall_Count']))
	bad = []
	for tile in range(len(raw)//32):
		if tile in dynamic:
			continue
		actual = bytes(g.vram[(tile*32+i)^1] for i in range(32))
		if actual!=raw[tile*32:(tile+1)*32]:
			bad.append(hex(tile))
	assert not bad, ('Static terrain pixels overwritten',act+1,bad)
	return len(raw)//32-len(dynamic&set(range(len(raw)//32)))


def clear_scene(g):
	isolate(g)
	for y in range(2,11):
		for x in range(2,12):
			g.layout_cell(y,x,0)
	for field,value,size in (
		('Camera_X_pos',480,2),('Camera_Y_pos',480,2),
		('Camera_Min_X_pos',480,2),('Camera_Max_X_pos',480,2),
		('Camera_Max_X_pos_target',480,2),('Camera_Min_Y_pos',0,2),
		('Camera_Max_Y_pos',1024,2),('Camera_Max_Y_pos_target',1024,2),
		('Screen_redraw_flag',1,1)):
		g.write(field,value,size)
	place(g,'v_player2',500,600,False)
	g.put('v_player2','obControl',0x81)
	place(g,'v_player',640,608,False)
	g.put('v_player','obControl',0x81)
	for _ in range(4):
		run(g)
	isolate(g)


def run(g):
	g.run()
	assert not g.read('v_errortype'), 'ROM exception'
	assert g.get('v_player','obRoutine')<6, 'Player died'


def tunnel(g, act, player, path, output):
	clear_scene(g)
	for y,row in enumerate(TUNNEL):
		for x,cid in enumerate(row):
			g.layout_cell(4+y,4+x,cid)
	g.write('Screen_redraw_flag',1)
	place(g,'v_player',520,625,False)
	for field,value,size in (
		('obHeight',14,1),('obWidth',7,1),('obAnim',2,1),
		('obStatus',4,1),('obVelX',0x900,2),('obInertia',0x900,2),
		('obAngle',0,1),('obTopSolidBit',12+path*2,1),
		('obLRBSolidBit',13+path*2,1),('invtime',6000,2)):
		g.put('v_player',field,value,size)
	trace, pictures = [], []
	for tick in range(100):
		run(g)
		assert g.get('v_player','obTopSolidBit')==12+path*2
		row = [g.get('v_player',field,size) for field,size in
			(('obX',2),('obY',2),('obAngle',1),('obStatus',1))]
		trace.append(row)
		if tick%2==0:
			pictures.append(g.video.copy())
		if row[0]>=768 and row[1]>=832:
			break
	assert trace[-1][0]>=768 and trace[-1][1]>=832, ('Tunnel exit not reached',act,player,path,trace)
	# The final open exit starts at Y $370. Frame counts vary with region/CD
	# waits; require contact over the entire enclosed curve by position.
	assert all(not row[3]&2 for row in trace if row[1]<0x370), ('Lost tunnel surface contact',act,player,path,trace)
	assert any(b[0]<a[0] for a,b in zip(trace,trace[1:])), ('S-bend did not reverse horizontal travel',trace)
	stem = f'act{act+1}-player{player}-path{path}'
	pictures[0].save(output/(stem+'.webp'),save_all=True,
		append_images=pictures[1:],duration=34,loop=0,lossless=True)
	pictures[len(pictures)//2].save(output/(stem+'.png'))
	return dict(act=act+1,player=player,path=path,frames=len(trace),
		continuous_grounded_frames=next((i for i,r in enumerate(trace) if r[3]&2),len(trace)),
		grounded_s_bend=True,exit_reached=True,trace=trace)


def platforms(g, act, rom, output):
	clear_scene(g)
	base = g.save()
	terrain = (ROOT/f'art/kosinski/level/8x8 - EHZ{"2" if act else ""}.unc').read_bytes()
	report = []
	for shape in range(5):
		for flip in (range(4) if shape<2 else (0,)):
			g.restore(base)
			a = spawn(g,'Obj18',640,672,shape<<4)
			g.put(a,'obStatus',flip)
			place(g,'v_player',640,608)
			g.put('v_player','invtime',6000,2)
			trace = []
			for _ in range(48):
				run(g)
				trace.append([g.get('v_player',f,n) for f,n in (('obX',2),('obY',2),('obStatus',1),('obVelY',2))])
			g.video.save(output/f'act{act+1}-platform{shape}-flip{flip}.png')
			assert g.get('v_player','obStatus')&8, ('Platform landing failed',act,shape,flip,trace,
				{f:g.get(a,f,n) for f,n in (('code',4),('obX',2),('obY',2),('obRoutine',1),('obFrame',1),('obStatus',1),('obMap',4))})
			if shape<2:
				assert g.get(a,'obMap',4)==g.s['Map_Obj18_EHZ']
				row = frames(rom,g.get(a,'obMap',4))[g.get(a,'obFrame')]
				for _,size,tile,_ in row:
					first = (g.get(a,'obGfx',2)+tile)&2047
					count = ((size>>2)+1)*((size&3)+1)
					actual = bytes(g.vram[(first*32+i)^1] for i in range(count*32))
					assert actual==terrain[first*32:(first+count)*32], ('Platform tile pixels mismatch',act,shape,flip)
			g.video.save(output/f'act{act+1}-platform{shape}-flip{flip}.png')
			report.append(dict(act=act+1,shape=shape,flip=flip,standing_contact=True))
	return report


def seesaws(g,zone,act,output):
	raw = (ROOT/'art/uncompressed/Seesaw.unc').read_bytes()
	base = g.s['ArtTile_EHZ_Seesaw' if zone==3 else 'ArtTile_HTZ_Seesaw']
	assert bytes(g.vram[(base*32+i)^1] for i in range(len(raw)))==raw, ('Seesaw bank not resident',zone,act)
	clear_scene(g)
	scene = g.save()
	report = []
	for flip in (0,1):
		g.restore(scene)
		a = spawn(g,'Obj5E',640,672)
		g.put(a,'obStatus',flip)
		place(g,'v_player',640+(40 if flip else -40),592)
		g.put('v_player','obControl',0x81)
		for _ in range(4):
			run(g)
		place(g,'v_player',640+(40 if flip else -40),592)
		g.put('v_player','obStatusSecondary',2)
		g.put('v_player','invtime',6000,2)
		stood = launched = False
		seen = set()
		pictures = []
		finish = None
		for tick in range(150):
			run(g)
			parts = [b for b in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size'])
				if g.get(b,'code',4)==g.s['Obj5E']]
			assert len(parts)==2, ('Seesaw child missing',zone,act,parts)
			ball = next(b for b in parts if b!=a)
			assert g.get(a,'obGfx',2)&2047==base and g.get(ball,'obGfx',2)&2047==base
			assert g.get(ball,'obColType')==0x8B
			stood |= bool(g.get('v_player','obStatus')&8)
			launched |= bool(g.get(ball,'obVelY',2)&0x8000)
			frame = g.get(a,'obFrame')
			if frame not in seen:
				g.video.save(output/f'zone{zone}-act{act+1}-seesaw{frame}-flip{flip}.png')
			seen.add(frame)
			if tick%2==0:
				pictures.append(g.video.copy())
			if stood and launched and finish is None:
				finish = tick+12
			if finish is not None and tick>=finish:
				break
		assert stood and launched and {0,1,2}<=seen, ('Seesaw ride/launch failed',zone,act,flip,stood,launched,seen)
		pictures[0].save(output/f'zone{zone}-act{act+1}-seesaw-flip{flip}.webp',save_all=True,
			append_images=pictures[1:],duration=34,loop=0,lossless=True)
		report.append(dict(zone=zone,act=act+1,flip=flip,full_art_resident=True,
			plank_frames=sorted(seen),player_landed=True,spikeball_launched=True))
	return report


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
	p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--core',type=Path,required=True)
	p.add_argument('--system-directory',type=Path)
	p.add_argument('--output',type=Path,required=True)
	p.add_argument('--pal',action='store_true')
	args = p.parse_args()
	g = Genesis(args.core,args.rom,args.listing,args.output,args.pal,
		system_directory=args.system_directory)
	results, bodies, saws = [], [], []
	for act in (0,1):
		for player in (0,2):
			g.core.retro_reset()
			boot_level(g,zone=3,act=act,player=player)
			resident_terrain(g,act)
			base = g.save()
			for path in (0,1):
				g.restore(base)
				results.append(tunnel(g,act,player,path,args.output))
			if player==0:
				g.restore(base)
				bodies.extend(platforms(g,act,args.rom.read_bytes(),args.output))
				g.restore(base)
				saws.extend(seesaws(g,3,act,args.output))
	g.core.retro_reset()
	boot_level(g,zone=5,act=0,player=0)
	saws.extend(seesaws(g,5,0,args.output))
	for player in (0,2):
		# Acts can spend different frames waiting for the CD. Compare physics
		# updates, removing consecutive repeats caused by those scheduler waits.
		rows = []
		for result in (r for r in results if r['player']==player):
			active = []
			for row in result['trace']:
				if not active or row!=active[-1]:
					active.append(row)
			rows.append(active)
		assert all(row==rows[0] for row in rows), ('Act/path traversal geometry differs',player)
	report = dict(pal=args.pal,tunnel_runs=results,platform_landings=bodies,seesaw_runs=saws,
		controller_only_playthrough=False)
	(args.output/'report.json').write_bytes((json.dumps(report,indent=2)+'\n').replace('\n','\r\n').encode())
	print(f'{len(results)} S-tunnel traversals, {len(bodies)} platform landings and {len(saws)} full-art seesaw rides/ball launches pass.')
	g.close()


if __name__=='__main__':
	main()
