#!/usr/bin/env python3
"""Check the shared four-slot monitor cache, resident lives and authored demand.

Native calls execute the assembled loader; only the DMA boundary is stubbed.
Real-core visits add visible four-kind boxes and floating rewards.
"""
from pathlib import Path
import argparse
import itertools
import json
import struct
from native_test_core import Native,UC_M68K_REG_D0,UC_M68K_REG_D7,UC_M68K_REG_A1,UC_M68K_REG_SR
from object_layout import decode,mount_settings
from check_sprite_assets import frames
from import_ehz2_pp_background import nemesis

ROOT=Path(__file__).resolve().parents[1]


def native(args):
	m=Native(args.rom,args.listing);rom=args.rom.read_bytes();checks=0
	art=(ROOT/'art/uncompressed/Monitor icons.unc').read_bytes()
	def load(kind,full=False):
		m.uploads.clear()
		m.write('VDP_Command_Buffer_Slot',(m.s['VDP_Command_Buffer_Slot'] if full else m.s['VDP_Command_Buffer'])&65535,2)
		m.act('MonitorArt_Select',regs={UC_M68K_REG_D0:kind,UC_M68K_REG_D7:0x13572468})
		assert m.cpu.reg_read(UC_M68K_REG_D7)==0x13572468
		return not m.cpu.reg_read(UC_M68K_REG_SR)&1
	def tags():return bytes(m.cpu.mem_read(m.s['MonitorArt_Tags']&0xffffff,4))
	for group in itertools.combinations(range(8),4):
		for kinds in (group,group[::-1]):
			m.start()
			for slot,kind in enumerate(kinds):
				assert load(kind)
				assert len(m.uploads)==1
				source,dest,length=m.uploads[0];assert length&65535==64
				assert dest&65535==(m.s['ArtTile_Monitor_Icons']+slot*4)*32
				assert rom[source:source+128]==art[kind*128:(kind+1)*128]
				mapping=m.cpu.reg_read(UC_M68K_REG_A1)
				row=frames(rom,mapping,12)[kind+1]
				assert (row[0][2]+m.s['ArtTile_Monitor'])&2047==m.s['ArtTile_Monitor_Icons']+slot*4
				assert row[0][2]&0x6000==(0x2000 if kind==1 else 0)
				checks+=1
			for kind in kinds:
				assert load(kind) and not m.uploads;checks+=1
			before=tags();fifth=next(k for k in range(8) if k not in kinds)
			assert not load(fifth) and tags()==before and not m.uploads
			m.write('Timer_frames',1,2);assert not load(fifth)
			m.write('Timer_frames',2,2);assert load(fifth) and tags()[0]==fifth
	# Whole-frame queue refusal must leave the victim's old art tag intact.
	m.start();assert not load(0,True) and tags()==b'\xff'*4 and not m.uploads
	assert load(0)
	for kind in (8,9):assert load(kind) and not m.uploads
	# The permanent life portraits bypass the content cache and retain rewards.
	for kind,label,count in ((8,'Monitor_SonicLife',2),(9,'Monitor_TailsLife',1)):
		m.start();m.write('v_lives',3);m.act(label);assert m.read('v_lives')==3+count
	m.start();m.write('Timer_frames',65535,2)
	for kind in range(4):assert load(kind)
	m.write('Timer_frames',0,2);assert not load(4)
	m.write('Timer_frames',1,2);assert load(4)
	maps=frames(rom,m.s['Map_Obj26'],12)
	assert (maps[9][0][2]+m.s['ArtTile_Monitor'])&2047==m.s['ArtTile_Lives_Counter']
	assert (maps[10][0][2]+m.s['ArtTile_Monitor'])&2047==m.s['ArtTile_Tails_Life']
	master=(ROOT/'art/nemesis/Monitor and contents.unc').read_bytes()
	assert nemesis(rom[m.s['Nem_MonitorBodies']:])==master[:24*32]
	assert nemesis(rom[m.s['Nem_MonitorTailsLife']:])==master[56*32:]
	assert m.s['ArtTile_Monitor_FreeEnd']-m.s['ArtTile_Monitor_Free']==16
	return dict(cache_cases=checks,content_slots=4,reclaimed_tiles=16,whole_queue_retry=True,
		prior_pass_pinning=True,timestamp_wrap=True,life_rewards_preserved=True)


def placements():
	maximum=0;witness=None;views=0
	for path in (ROOT/'level/objects').glob('*.bin'):
		rows=[]
		for row in decode(path.read_bytes()):
			x,y,oid,eras,kind=row;mount=mount_settings(row)
			if oid==0x12:assert kind&15<10
			elif 22<=mount<32:kind=mount-22
			elif oid==0xB0 and kind in (5,6):kind=1 if kind==5 else 2
			else:continue
			if kind<8:rows.append((x,y&4095,eras,kind))
		for era in (32,64,128):
			r=[(x,y,t) for x,y,e,t in rows if e&era]
			for x,_,_ in r:
				for _,y,_ in r:
					types={t for xx,yy,t in r if x<=xx<x+352 and y<=yy<y+288};views+=1
					assert len(types)<=4,(path,era,x,y,types,'visible monitor DPLC demand exceeds four slots')
					if len(types)>maximum:maximum=len(types);witness=(path.name,era,x,y,sorted(types))
	return dict(maximum_visible_kinds=maximum,witness=witness,views=views)


def game(args):
	from genesis_test_core import Genesis
	from check_object_course import boot_level
	from check_companion_followup import isolate,spawn,place
	g=Genesis(args.core,args.rom,args.listing,args.output.parent/('monitor-pal' if args.pal else 'monitor-ntsc'),args.pal,system_directory=args.system_directory)
	initial=g.save();report=[]
	art=(ROOT/'art/uncompressed/Monitor icons.unc').read_bytes()
	portrait=(ROOT/'art/nemesis/Monitor and contents.unc').read_bytes()[56*32:]
	sonic=nemesis((ROOT/'art/nemesis/Sonic lives counter.nem').read_bytes())[:128]
	def vram(first,size):return bytes(g.vram[(first*32+i)^1] for i in range(size))
	for mode,era in ((0,0),(0,1),(0,2),(0,3),(2,0)):
		g.restore(initial);boot_level(g,zone=args.zone,act=args.act,timezone=era,player=mode);isolate(g)
		g.placement_write(0,int.from_bytes(b'\x80'*g.placement_capacity(),'big'),g.placement_capacity())
		for actor in ('v_player','v_player2'):
			place(g,actor,600,520);g.put(actor,'obControl',0x81)
		g.write('Camera_X_pos',440,2);g.write('Camera_X_pos_coarse_back',256,2);g.write('Camera_Y_pos',424,2)
		kinds=(0,1,2,6,8,9)
		objects=[spawn(g,'Monitor',504+i*48,600,kind) for i,kind in enumerate(kinds)]
		g.run(30)
		tags=[g.read(g.s['MonitorArt_Tags']+i) for i in range(4)]
		assert set(tags)==set(kinds[:4]),(mode,era,tags)
		for slot,kind in enumerate(tags):assert vram(g.s['ArtTile_Monitor_Icons']+slot*4,128)==art[kind*128:(kind+1)*128],(mode,era,slot,kind)
		assert vram(g.s['ArtTile_Tails_Life'],128)==portrait
		assert vram(g.s['ArtTile_Lives_Counter'],128)==sonic
		def sat():
			entries=[];index=0
			for _ in range(80):
				at=g.s['vram_sprites']+index*8
				data=bytes(g.vram[(at+i)^1] for i in range(8))
				y,link,tile,x=struct.unpack('>4H',data)
				entries.append(((x&511)-128,(y&511)-128,tile&2047))
				index=link&127
				if not index:break
			return entries
		for _ in range(30):
			visible=sat();expected=[]
			for a,kind in zip(objects,kinds):
				tile=g.s['ArtTile_Lives_Counter'] if kind==8 else g.s['ArtTile_Tails_Life'] if kind==9 else g.s['ArtTile_Monitor_Icons']+tags.index(kind)*4
				expected.append((g.get(a,'obX',2)-g.read('Camera_X_pos',2)-8,g.get(a,'obY',2)-g.read('Camera_Y_pos',2)-11,tile))
			if all(entry in visible for entry in expected):break
			g.run()
		else:raise AssertionError(('six monitor icons missing from real SAT',mode,era,expected,visible))
		g.video.save(g.output/f'era{era}-mode{mode}-four-slots-and-lives.png')
		# Force a real player ball impact on the regular-shield monitor. The
		# reward floats and keeps the same physical icon slot as the broken box.
		if mode==0:
			target=objects[2];place(g,'v_player',g.get(target,'obX',2),g.get(target,'obY',2)-30)
			for field,value,size in (('obAnim',2,1),('obStatus',6,1),('obHeight',9,1),('obWidth',7,1),('jumping',1,1),('obVelY',0x100,2)):
				g.put('v_player',field,value,size)
			for _ in range(12):
				g.run()
				icons=[a for a in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']) if g.get(a,'code')==g.s['MonitorContents']]
				if icons:break
			else:raise AssertionError(('monitor did not break',era))
			icon=icons[0];assert g.get(icon,'obAnim')==2
			g.run(12);slot=next(i for i in range(4) if g.read(g.s['MonitorArt_Tags']+i)==2)
			assert vram(g.s['ArtTile_Monitor_Icons']+slot*4,128)==art[256:384]
			g.video.save(g.output/f'era{era}-floating-shield.png')
			g.run(45);assert g.get('v_player','obStatusSecondary')&g.s['Status_Shield'] if 'Status_Shield' in g.s else g.get('v_player','obStatusSecondary')&1
		assert not g.read('v_errortype')
		report.append(dict(mode=mode,era=era,four_distinct_contents=True,both_life_icons_resident=True))
	g.close();return report


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin');p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--core',type=Path);p.add_argument('--system-directory',type=Path);p.add_argument('--pal',action='store_true')
	p.add_argument('--zone',type=int,choices=range(16),default=8,help='Fixture zone (default: Scrap Madness)')
	p.add_argument('--act',type=int,choices=range(4),default=0,help='Zero-based fixture act')
	p.add_argument('--output',type=Path,required=True);args=p.parse_args()
	report=dict(native=native(args),placements=placements())
	if args.core:report['game']=game(args)
	args.output.parent.mkdir(parents=True,exist_ok=True)
	args.output.write_bytes((json.dumps(report,indent=2)+'\n').replace('\n','\r\n').encode());print(json.dumps(report,indent=2))


if __name__=='__main__':main()
