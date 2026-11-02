#!/usr/bin/env python3
"""Check the seventh stage item, ownership, selection and real pickup/results.

Stage 7 is a copy of the gray-stage layout with cyan substituted. The game
fixtures enter it from level select, then use Debug placement and normal item
collision for real goal exits; they are not full-stage controller playthroughs.
"""
from pathlib import Path
import argparse,json,struct
from native_test_core import Native
from unicorn.m68k_const import UC_M68K_REG_D0,UC_M68K_REG_D4,UC_M68K_REG_A1,UC_M68K_REG_A7,UC_M68K_REG_PC

ROOT=Path(__file__).resolve().parents[1]


def native(args):
	n=Native(args.rom,args.listing);n.start();n.write('v_oscillate',0xBEEF,2)
	assert n.read('Debug_SS',2)==8
	assert [int.from_bytes(n.cpu.mem_read(n.s['Debug_SS_Entries']+i*n.s['DebugEntry_size']+n.s['DebugEntry_subtype'],2),'big') for i in range(8)]==[0x3A,0x3B,0x3C,0x3D,0x3E,0x3F,0x40,0x34]
	cell=n.s['v_ssblockbuffer']&0xFFFFFF
	for count,item in enumerate((0x3B,0x3C,0x3D,0x3E,0x3F,0x40,n.s['S1SS_CyanItem'])):
		n.cpu.mem_write(cell,bytes([item]))
		n.act('SSS_ChkEmerald','v_player',{UC_M68K_REG_D4:item,UC_M68K_REG_A1:cell})
		assert n.read('v_emeralds')==count+1
		assert n.read('v_ss_emerald_collected')==1
		assert n.read('v_emldlist',count+1)==int.from_bytes(bytes(range(count+1)),'big')
		assert n.read('v_oscillate',2)==0xBEEF
		if count==0:
			n.act('SSS_ChkEmerald','v_player',{UC_M68K_REG_D4:item,UC_M68K_REG_A1:cell})
			assert n.read('v_emeralds')==1, 'Duplicate advanced a partial collection'
	for item in (0x3B,n.s['S1SS_CyanItem']):
		n.cpu.mem_write(cell,bytes([item]))
		n.act('SSS_ChkEmerald','v_player',{UC_M68K_REG_D4:item,UC_M68K_REG_A1:cell})
		assert n.read('v_emeralds')==7 and n.read('v_oscillate',2)==0xBEEF
	n.act('ChaosEmeralds','v_ssresemeralds')
	for i in range(7):
		obj=n.s['v_ssresemeralds']+i*n.s['object_size']
		assert n.get(obj,'code')==n.s['SSRC_Flash'] and n.get(obj,'obFrame')==i
		assert (n.get(obj,'obX',2),n.get(obj,'obScreenY',2))==((0x110,0xE4),(0x130,0xE4),(0x100,0xFC),(0x150,0xE4),(0xF0,0xE4),(0x120,0xFC),(0x140,0xFC))[i]
		for clock in (0,1):
			n.write('Vint_runcount',clock,4)
			n.write('v_spritequeue',0,n.s['v_spritequeue_end']-n.s['v_spritequeue'])
			n.act('SSRC_Flash',obj)
			assert n.get(obj,'obFrame')==i
			n.act('Render_Sprites')
			assert n.read('v_spritecount')==clock
	class Picker(Native):
		def hook(self,cpu,address,size,unused):
			if address==self.s['S1SS_LoadData']:
				self.selected=cpu.reg_read(UC_M68K_REG_D0)&65535
				sp=cpu.reg_read(UC_M68K_REG_A7)
				cpu.reg_write(UC_M68K_REG_PC,int.from_bytes(cpu.mem_read(sp,4),'big'))
				cpu.reg_write(UC_M68K_REG_A7,sp+4)
				return
			super().hook(cpu,address,size,unused)
	p=Picker(args.rom,args.listing)
	for mask in range(128):
		owned=[i for i in range(7) if mask>>i&1]
		for start in range(7):
			p.start();p.write('v_emeralds',len(owned));p.write('v_lastbonus',start)
			p.write('v_ss_emerald_collected',1)
			p.cpu.mem_write(p.s['v_emldlist']&0xFFFFFF,bytes(owned))
			p.act('BonusStage_Load')
			assert 0<=p.selected<7,(mask,start,p.selected)
			if mask!=127:assert p.selected not in owned,(mask,start,p.selected)
			assert p.read('v_lastbonus')==(p.selected+1)%7
			assert not p.read('v_ss_emerald_collected')
	from convert_s1_ss_background import kosinski_plus_decode
	assert p.s['S1SS_StageCount']==7
	assert p.s['Kospm_SSBgTransition']%2==0, 'Stage data left the module header unaligned'
	assert int.from_bytes(p.cpu.mem_read(p.s['Bonus_LayoutIndex']+6*4,4),'big')==p.s['BS_7']
	assert kosinski_plus_decode((ROOT/'Bonus & Special Stages/7.kosp').read_bytes())[0]==(ROOT/'Bonus & Special Stages/7.unc').read_bytes()
	return {'seven_awards':True,'duplicates_rejected':True,'following_word_preserved':True,
			'seven_results_objects':True,'stage_selection_cases':896,'four_over_three':True}


def live(args):
	from genesis_test_core import Genesis
	g=Genesis(args.core,args.rom,args.listing,args.output/'game',system_directory=args.system_directory)
	def step(n=1):
		g.run(n)
		if g.read('v_errortype'):
			g.video.save(args.output/'game/exception.png')
			sp=g.read(g.s['v_regbuffer']+60,4)
			raise AssertionError(('CPU exception',g.read('v_errortype'),g.frame,hex(sp),hex(g.read(sp+2,4)),hex(g.read('v_spbuffer',4))))
	def press(button):
		g.buttons={button};step(2);g.buttons=set();step(2)
	for _ in range(1800):
		step()
		if g.read('v_vbla_routine',2)==g.s['Vint_Title'] and g.read('v_generictimer',2)==375:break
	else:raise AssertionError('Title did not settle')
	g.write('f_levselcheat',1);press(3);step(110)
	g.write('Player_mode',args.player,2);g.write('v_levselitem',g.s['LevelSelect_BonusItem'],2)
	# Enter the actual seventh layout with the original six emeralds held.
	g.write('v_emeralds',6);g.write('v_lastbonus',6)
	g.write('v_ss_emerald_collected',1)
	for i in range(6):g.write(g.s['v_emldlist']+i,i)
	press(3)
	for _ in range(800):
		step()
		if g.read('v_vbla_routine',2)==g.s['Vint_S1SS']:break
	else:raise AssertionError('Stage did not start')
	assert g.read('v_lastbonus')==0 and g.read('v_emeralds')==6
	assert not g.read('v_ss_emerald_collected')
	loaded=[g.read(g.s['v_ssblockbuffer']+r*g.s['S1SS_LayoutStride']+c) for r in range(64) for c in range(64)]
	assert loaded.count(g.s['S1SS_CyanItem'])==1 and 0x40 not in loaded
	step(100)
	from import_ehz2_pp_background import nemesis
	stage=nemesis((ROOT/'art/Bonus & Special Stage/Bonus Stage Emeralds.nem').read_bytes())
	bank=g.s['ArtTile_SS_Emerald']*32
	assert bytes(g.vram[(bank+i)^1] for i in range(len(stage)))==stage
	palette=(ROOT/'palette/Special Stage.bin').read_bytes()
	assert bytes(g.read(g.s['v_palette']+i) for i in range(32))==palette[:32]
	g.write('Debug_mode_flag',1);press(0)
	assert g.read('Debug_placement_mode',2)
	for index in range(1,8):
		press(1);assert g.read('Debug_object')==index
	press(1);assert g.read('Debug_object')==0
	g.buttons={1,8};step(2);g.buttons=set();step(2)
	assert g.read('Debug_object')==7, 'Backward wrap lost the cyan entry'
	g.write('v_ssangle',0,2);g.write('v_ssrotate',0,2)
	base=g.s['v_ssblockbuffer'];stride=g.s['S1SS_LayoutStride'];col=row=32
	for y in range(row-3,row+4):
		for x in range(col-3,col+4):g.write(base+y*stride+x,0)
	x=(col+32)*24-20;y=(row+32)*24-68
	g.put('v_player','obX',x<<16,4);g.put('v_player','obY',y<<16,4)
	if args.fail:
		g.write(base+row*stride+col,0x27)  # real GOAL block
		g.put('v_player','obVelX',0,2);g.put('v_player','obVelY',0,2)
		press(0);expected_count=6;state=0
	else:
		# Cyan is placed through Debug; gray supplies the optional second pickup.
		press(8)
		cyan=base+row*stride+col
		assert g.read(cyan)==g.s['S1SS_CyanItem']
		if args.pickup_count==2:g.write(cyan+1,0x40)
		g.write(cyan-1,0x3B)
		step(30);g.video.save(args.output/'game/blue-cyan-stage.png')
		g.write('v_emeralds',5)
		for i in range(5):g.write(g.s['v_emldlist']+i,i)
		g.put('v_player','obVelX',0,2);g.put('v_player','obVelY',0,2)
		press(0)
		assert not g.read('Debug_placement_mode',2)
		assert g.read('v_emeralds')==6,('Cyan was not collected',g.read('v_emeralds'))
		assert g.read('v_ss_emerald_collected')==1
		if args.pickup_count==2:
			g.put('v_player','obVelX',0x600,2);g.buttons={7}
			for tick in range(18):
				step()
				if g.read('v_emeralds')==7:break
			else:raise AssertionError(('Second emerald was not collected',g.get('v_player','obX',2),g.get('v_player','obY',2)))
		expected_count=5+args.pickup_count;state=2 if expected_count==7 else 1
	g.buttons=set();g.write('Debug_mode_flag',0)
	for _ in range(1000):
		step()
		if g.get('v_endcard','code')==g.s['BonusGotThrough'] and g.get('v_endcard','obRoutine'):break
	else:raise AssertionError('Real emerald goal did not reach results')
	step(110)
	assert g.read('v_emeralds')==expected_count
	assert bool(g.read('v_ss_emerald_collected'))==(not args.fail)
	assert g.get('v_endcard','obMap',4)==g.s[f'Map_SSR_{state}_{int(args.player==2)}']
	raw=(ROOT/'art/uncompressed/Results emeralds.unc').read_bytes();bank=g.s['ArtTile_SS_Results_Emeralds']*32
	assert bytes(g.vram[(bank+i)^1] for i in range(len(raw)))==raw
	for _ in range(8):
		step()
		if sum(g.s['ArtTile_SS_Results_Emeralds'] <= g.read(g.s['Sprite_Table']+i*8+4,2)&2047 < g.s['ArtTile_SS_Results_Emeralds']+28 for i in range(g.read('v_spritecount')))==expected_count:
			step();g.video.save(args.output/'game/seven-emerald-results.png');break
	else:raise AssertionError('Seven visible emeralds did not render')
	g.close();return {'cyan_debug_item':52,'debug_entries':8,'forward_backward_wrap':True,'stage_seven_entered':True,'failed':args.fail,'emeralds':expected_count,'heading_state':state,'player':args.player}


def main():
	p=argparse.ArgumentParser(description=__doc__)
	for name in ('rom','listing'):p.add_argument('--'+name,type=Path,default=ROOT/('s2built.bin' if name=='rom' else 'md-main.lst'))
	p.add_argument('--output',type=Path,required=True);p.add_argument('--core',type=Path)
	p.add_argument('--fail',action='store_true');p.add_argument('--pickup-count',type=int,choices=(1,2),default=2)
	p.add_argument('--system-directory',type=Path);p.add_argument('--player',type=int,choices=(1,2),default=1)
	a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True);report={'native':native(a)}
	if a.core:report['game']=live(a)
	(a.output/'report.json').write_bytes((json.dumps(report,indent=2)+'\n').replace('\n','\r\n').encode())
	print(json.dumps(report,indent=2))


if __name__=='__main__':
	main()
