#!/usr/bin/env python3
"""Check assembled card/signpost DPLCs, queue backpressure and tile references.

Uses the optional Unicorn Native harness; no player or companion AI is run.
The signpost comparison renders every original sprite piece from source art
and checks the dynamically loaded version pixel-for-pixel, including flips.
"""
from pathlib import Path
import argparse
import json
import struct

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--rom',type=Path,required=True)
p.add_argument('--listing',type=Path,required=True)
p.add_argument('--output',type=Path)
args = p.parse_args()
import native_test_core as m68k
from check_sprite_assets import frames
from build_signpost_art import signpost_frames


class ArtNative(m68k.Native):
	def hook(self,cpu,address,size,unused):
		if address == self.s['QueueDMATransfer']:
			source,dest,words = (cpu.reg_read(getattr(m68k, 'UC_M68K_REG_'+n)) for n in ('D1','D2','D3'))
			self.uploads.append((source,dest & 0xFFFF,words & 0xFFFF))
			entries = 1 + int((source & 0x1FFFF)+(words & 0xFFFF)*2 > 0x20000)
			slot = self.read('VDP_Command_Buffer_Slot',2)+entries*self.s['DMAEntry.len']
			assert slot <= self.s['VDP_Command_Buffer_Slot'] & 0xFFFF
			self.write('VDP_Command_Buffer_Slot',slot,2)
			for reg in m68k.DATA:
				cpu.reg_write(reg,0xDEADC0DE)
			cpu.reg_write(m68k.UC_M68K_REG_A1,0xFFFFBABA)


m = ArtNative(args.rom, args.listing)
rom = args.rom.read_bytes()
obj = m.s['v_titlecard']
checks = []


def reset(full=False):
	m.cpu.mem_write(0xFF0000,bytes(65536))
	m.cpu.mem_write(0xFFFF0000,bytes(65536))
	m.uploads=[]
	slot=m.s['VDP_Command_Buffer_Slot'] if full else m.s['VDP_Command_Buffer']
	m.write('VDP_Command_Buffer_Slot',slot & 0xFFFF,2)


def runs(table,index):
	address = m.s[table]
	start = address+struct.unpack_from('>h',rom,address+index*2)[0]
	n = struct.unpack_from('>H',rom,start)[0]
	return struct.unpack_from('>'+str(n)+'H',rom,start+2)


def payload(table,index,art,end):
	data=bytearray()
	for run in runs(table,index):
		source=m.s[art]+(run & 0xFFF)*32
		size=((run>>12)+1)*32
		assert m.s[art] <= source < source+size <= m.s[end]
		data += rom[source:source+size]
	return bytes(data)


for scene in range(78):
	base = m.s['ArtTile_Results_Card' if scene >= 64 else 'ArtTile_Title_Card']*32
	reset(full=True)
	regs={m68k.UC_M68K_REG_D0:scene,m68k.UC_M68K_REG_D4:base,
		  m68k.UC_M68K_REG_D7:0x1976}
	m.act('Load_CardDPLC',obj,regs)
	assert not m.uploads and m.cpu.reg_read(m68k.UC_M68K_REG_SR) & 1
	assert m.get(obj,'card_dplc_left',2) == len(runs('DPLC_Cards',scene))
	# Leave most of the first queue occupied to force a real resume path.
	for tick in range(6):
		m.write('VDP_Command_Buffer_Slot',(m.s['VDP_Command_Buffer']+(12*m.s['DMAEntry.len'] if tick == 0 else 0)) & 0xFFFF,2)
		old = len(m.uploads)
		m.act('Load_CardDPLC',obj,regs)
		assert m.cpu.reg_read(m68k.UC_M68K_REG_D7) == 0x1976
		if not m.cpu.reg_read(m68k.UC_M68K_REG_SR) & 1:
			assert len(m.uploads) == old, 'Card became visible before its last DMA VBlank'
			break
	else:
		raise AssertionError(('card load did not finish',scene))
	data=b''.join(rom[src:src+words*2] for src,_,words in m.uploads)
	assert data == payload('DPLC_Cards',scene,'Art_CardFont','Art_CardFont_End')
	dest=base
	for _,target,words in m.uploads:
		assert target == dest
		dest += words*2
	assert dest <= 0xC000
	checks.append({'case':'card-queue-full-resume','scene':scene,'tiles':len(data)//32})
	m.act('Load_CardDPLC',obj,regs)
	assert len(m.uploads) == old

intro=frames(rom,m.s['Map_Card'],22)
for zone in range(16):
	for act in range(4):
		data=payload('DPLC_Cards',zone*4+act,'Art_CardFont','Art_CardFont_End')
		for row in (intro[zone],intro[16],intro[17+act],intro[21]):
			for _,size,tile,_ in row:
				assert (tile & 0x7FF)+((size>>2)+1)*((size&3)+1) <= len(data)//32

for mode in (0,1,2):
	for act in range(4):
		reset()
		m.write('Player_mode',mode,2);m.write('Current_Act',act)
		m.act('Get_NormalCardScene')
		assert m.cpu.reg_read(m68k.UC_M68K_REG_D0) == 64+act*2+(mode == 2)
		table=m.cpu.reg_read(m68k.UC_M68K_REG_A3)
		rows=frames(rom,table,10)
		for frame,tile in ((3,m.s['ArtTile_Bonuses']+1),(4,m.s['ArtTile_Bonuses']+5)):
			assert (rows[frame][-2][2]+m.s['ArtTile_Results_Card']) & 0xFFFF == tile
		assert (rows[3][-3][2]+m.s['ArtTile_Results_Card']) & 0xFFFF == m.s['ArtTile_Bonuses']
		checks.append({'case':'normal-character-and-bonus-addresses','mode':mode,'act':act+1})

# Cover every displayed finish time; only 9:59 receives the secret bonus.
bonuses=(5000,5000,1000,500,400,400,300,300,200,200,200,200,100,100,100,100,50,50,50,50,0)
for seconds in range(600):
	reset();m.write('v_timemin',seconds//60);m.write('v_timesec',seconds%60)
	m.write('v_rings',123,2)
	m.act('Load_EndOfAct')
	expected=10000 if seconds==599 else bonuses[min(seconds//15,len(bonuses)-1)]
	assert m.read('v_timebonus',2)==expected,(seconds,expected,m.read('v_timebonus',2))
	assert m.read('v_ringbonus',2)==1230
checks.append({'case':'all-600-finish-times-secret-959','secret_points':100000})
reset();m.write('v_timebonus',10000,2);m.write('v_ringbonus',1230,2)
m.write('v_scorelife',5000,4)
for tick in range(1000):m.act('Got_TimeBonus',obj)
assert not m.read('v_timebonus',2) and not m.read('v_ringbonus',2)
assert m.read('v_score',4)==11230
assert m.read('v_lives')==2, 'The full bonus must award both score-threshold lives'
checks.append({'case':'secret-bonus-full-tally','points':112300})

for mode in (0,1,2):
	for collected in (0,1):
		for emeralds in (0,1,5,6,7):
			reset()
			m.write('Player_mode',mode,2);m.write('v_emeralds',emeralds)
			m.write('v_ss_emerald_collected',collected)
			m.act('Get_SpecialCardScene')
			state=0 if not collected or not emeralds else 2 if emeralds == 7 else 1
			scene=72+state*2+(mode == 2)
			assert m.cpu.reg_read(m68k.UC_M68K_REG_D0) == scene
			rows=frames(rom,m.cpu.reg_read(m68k.UC_M68K_REG_A3),10)
			heading_y=struct.unpack_from('>H',rom,m.s['SSR_Config']+4)[0]-128+min(y for y,_,_,_ in rows[0])
			assert heading_y == (52,40,52)[state], ('Special heading row',state,heading_y)
			for frame in (4,5,6):
				assert [x for _,_,_,x in rows[frame][:3]] == [-80,-50,-18], 'CONTINUE lost its T-I kerning'
			oval=rows[3]
			xs=[x for _,_,_,x in oval]+[x+((size>>2)+1)*8 for _,size,_,x in oval]
			ys=[y for y,_,_,_ in oval]+[y+((size&3)+1)*8 for y,size,_,_ in oval]
			ox,oy=struct.unpack_from('>HH',rom,m.s['SSR_Config']+3*8+2)
			oval_center=(ox-128+(min(xs)+max(xs))/2,oy-128+(min(ys)+max(ys))/2)
			assert oval_center==(160,60)
			hx,hy=struct.unpack_from('>HH',rom,m.s['SSR_Config']+2)
			groups=[rows[0]+(rows[8] if state==2 else [])]
			if state==2:
				assert len(rows[0])==8 and len(rows[8])==7, 'GOT/THEM ALL split changed'
				assert {y for y,_,_,_ in rows[7]}=={-28} and {y for y,_,_,_ in rows[9]}=={-4}
				groups.append(rows[7]+rows[9])
			else:
				assert not any(rows[7:]), 'An unsuccessful result exposes split success headings'
			for joined in groups:
				xs=[x for _,_,_,x in joined]+[x+((size>>2)+1)*8 for _,size,_,x in joined]
				ys=[y for y,_,_,_ in joined]+[y+((size&3)+1)*8 for y,size,_,_ in joined]
				heading_center=(hx-128+(min(xs)+max(xs))/2,hy-128+(min(ys)+max(ys))/2)
				assert heading_center==oval_center, ('Heading not centered on oval',mode,state,heading_center,oval_center)
			assert (rows[2][-2][2]+m.s['ArtTile_Results_Card']) & 0xFFFF == m.s['ArtTile_Bonuses']+5
			mini=m.s['ArtTile_Mini_Tails'] if mode == 2 else m.s['ArtTile_Mini_Sonic']+18
			assert (rows[4][-1][2]+m.s['ArtTile_Results_Card']) & 0xFFFF == mini
			checks.append({'case':'special-heading-and-character-addresses','mode':mode,'emeralds':emeralds,'collected':collected})

# S3&K loc_2E4C4 / loc_2E4EA / loc_2E5C0: post-tally, Continue, announcement.
assert (m.s['SSR_PostTallyDelay'],m.s['SSR_ContinueDelay'],m.s['SSR_AnnouncementHold'])==(120,270,240)
for emeralds,collected in ((6,1),(7,0)):
	for rings in (0,122):
		reset()
		m.write('v_emeralds',emeralds);m.write('v_ss_emerald_collected',collected);m.write('v_rings',rings,2)
		for field,value,size in (('obRoutine',2,1),('obFrame',0,1),('obX',0x120,2),('ssr_mainX',0x120,2)):
			m.put(obj,field,value,size)
		m.act('BonusGotThrough',obj)
		assert m.get(obj,'obRoutine')==2 and not m.get('v_bsresright','code')
		ring=m.s['v_bsresring'];m.put(ring,'obRoutine',6);m.put(ring,'obFrame',2)
		m.act('BonusGotThrough',ring)
		assert m.get(ring,'objoff_38',2)==(60 if rings>=50 else 180)
		if rings>=50:
			m.put(ring,'obRoutine',0xE)
			m.act('SSR_Continue',ring)
			assert m.get(ring,'objoff_38',2)==360
		m.act('SSR_Exit',ring)
		assert m.read('Level_Inactive_flag',2)==1
		checks.append({'case':'ordinary-outcome-timers-and-exit','emeralds':emeralds,'collected':collected,'rings':rings})

for mode in (0,1,2):
	for rings in (0,49,50,122,999):
		reset()
		m.write('Player_mode',mode,2);m.write('v_emeralds',7);m.write('v_ss_emerald_collected',1)
		m.write('v_rings',rings,2);m.write('v_ringbonus',rings*10,2)
		m.write('v_score',800,4);m.write('v_scorelife',5000,4)
		header=m.s['v_bsrestext'];right=m.s['v_bsresright'];ring=m.s['v_bsresring']
		m.act('SSR_Main',header)
		assert right+m.s['object_size']<=m.s['v_lvlobjspace']
		assert m.get('v_bsresoval','obPriority',2)>m.get(right,'obPriority',2), 'Oval covers the right heading group'
		assert m.get(right,'obFrame')==8 and m.get(right,'obRoutine')==0x1C
		assert bool(m.get('v_ssrescontinue','code'))==(rings>=50)
		assert all(m.get(actor,'obRender') & 1<<m.s['obRender.explicit_height'] for actor in (header,right))
		entry=[]
		for tick in range(18):
			entry.append((m.get(header,'obX',2),m.get(right,'obX',2)))
			if tick<17:m.act('BonusGotThrough',header)
		assert entry==[(x,0x240-x) for x in range(16,0x121,16)]
		assert m.get(header,'obRoutine')==0x16
		oval=(m.get('v_bsresoval','obX',2),m.get('v_bsresoval','obScreenY',2))
		timing={};outgoing=[];incoming=[]
		for tick in range(rings+1600):
			m.act('BonusGotThrough',header)
			m.act('BonusGotThrough',ring)
			frame=m.get(header,'obFrame');pair=(m.get(header,'obX',2),m.get(right,'obX',2))
			assert (m.get('v_bsresoval','obX',2),m.get('v_bsresoval','obScreenY',2))==oval
			if m.read('v_ringbonus',2):
				assert frame==0 and pair==(0x120,0x120), 'Announcement raced the score tally'
			if 'tally' not in timing and m.get(ring,'obRoutine') in (8,0xC):
				timing['tally']=tick
				assert not m.read('v_ringbonus',2) and m.read('v_score',4)==800+rings*10
				assert m.get(ring,'objoff_38',2)==120
			if 'continue' not in timing and m.get('v_ssrescontinue','obFrame')==4:
				timing['continue']=tick
				assert tick-timing['tally']==121
				assert m.get(ring,'objoff_38',2)==270
			if 'departure' not in timing and m.get(header,'obRoutine')==0x18:
				timing['departure']=tick
				assert tick-timing['continue' if rings>=50 else 'tally']==(271 if rings>=50 else 121)
			if frame==0 and pair!=(0x120,0x120):outgoing.append(pair)
			if frame==7:
				if 'announcement' not in timing:
					timing['announcement']=tick
					assert tick-timing['departure']==5 and m.get(ring,'objoff_38',2)==240
				if not incoming or incoming[-1]!=pair:incoming.append(pair)
				assert m.get(right,'obFrame')==9
			if m.read('Level_Inactive_flag',2):
				assert tick-timing['announcement']==241
				break
		else:raise AssertionError(('Announcement sequence did not exit',mode,rings,timing))
		assert outgoing==[(0x120-i*32,0x120+i*32) for i in range(1,5)]
		assert incoming==[(x,0x240-x) for x in range(0,0x121,16)]
		rows=frames(rom,m.get(header,'obMap',4),10)
		left_edge=max(x+((size>>2)+1)*8 for _,size,_,x in rows[0])
		right_edge=min(x for _,_,_,x in rows[8])
		assert 0x120-160-128+left_edge<=0 and 0x120+160-128+right_edge>=320
		assert 0x120-128-128+left_edge>0 or 0x120+128-128+right_edge<320
		assert not m.read('Super_Sonic_flag')
		checks.append({'case':'post-tally-opposed-heading-announcement','mode':mode,'rings':rings,'timing':timing})


# Mini Sonic retains S1 palette indices: its source E must remain the third red.
from convert_s1_ss_background import kosinski_plus_decode
source=kosinski_plus_decode((ROOT/'art/moduled kosinski/Mini Sonic Continue.kospm').read_bytes()[2:])[0][18*32:]
portrait=(ROOT/'art/uncompressed/Results continue Sonic.unc').read_bytes()[18*32:]
source_pixels=[n for byte in source for n in (byte>>4,byte&15)]
portrait_pixels=[n for byte in portrait for n in (byte>>4,byte&15)]
assert len(source_pixels)==len(portrait_pixels)==16*24*2
assert all(new==15 for old,new in zip(source_pixels,portrait_pixels) if old==14), 'S1 dark red was converted as S2 orange'
assert source_pixels.count(14)==portrait_pixels.count(15)>0
assert 4 not in portrait_pixels, 'Mini Sonic retains orange shoe shadows'
assert struct.unpack_from('>H',(ROOT/'palette/SonicAndTails.bin').read_bytes(),15*2)[0]==0x004
checks.append({'case':'mini-sonic-s1-dark-red','dark_red_pixels':portrait_pixels.count(15)})



def render(data,pieces):
	canvas=bytearray(96*80)
	for y,size,word,x in reversed(pieces):
		w,h=(size>>2)+1,(size&3)+1
		for py in range(h*8):
			for px in range(w*8):
				sx=w*8-1-px if word & 0x800 else px
				sy=h*8-1-py if word & 0x1000 else py
				pos=((word & 0x7FF)+(sx//8)*h+sy//8)*32+(sy%8)*4+(sx%8)//2
				colour=(data[pos] >> (4 if not sx%2 else 0)) & 15
				if colour:
					canvas[(y+py+32)*96+x+px+40]=colour
	return bytes(canvas)


source=(ROOT/'art/uncompressed/Signpost.unc').read_bytes()
source,original=signpost_frames(source)
dynamic=frames(rom,m.s['Map_Signpost'],m.s['Map_Signpost_frames'])
assert len(dynamic)==len(original)==11
assert [word & 0x6000 for _,_,word,_ in dynamic[6]] == [0x2000]*12+[0]
for frame in range(len(dynamic)):
	reset(full=True)
	m.put(obj,'signpost_loaded',255)
	regs={m68k.UC_M68K_REG_D0:frame,m68k.UC_M68K_REG_A2:m.s['DPLC_Signpost'],
		  m68k.UC_M68K_REG_A3:(obj+m.s['signpost_loaded']) & 0xFFFFFF,
		  m68k.UC_M68K_REG_D4:m.s['ArtTile_Signpost']*32,
		  m68k.UC_M68K_REG_D6:m.s['Art_Signpost'],m68k.UC_M68K_REG_D7:0x1976}
	m.act('Load_DynamicPLC',obj,regs)
	assert m.get(obj,'signpost_loaded') == 255 and not m.uploads
	m.write('VDP_Command_Buffer_Slot',m.s['VDP_Command_Buffer'] & 0xFFFF,2)
	m.act('Load_DynamicPLC',obj,regs)
	assert m.get(obj,'signpost_loaded') == frame
	assert m.cpu.reg_read(m68k.UC_M68K_REG_D7) == 0x1976
	loaded=b''.join(rom[src:src+words*2] for src,_,words in m.uploads)
	assert len(loaded) <= 26*32
	assert render(loaded,dynamic[frame]) == render(source,original[frame])
	n=len(m.uploads);m.act('Load_DynamicPLC',obj,regs);assert len(m.uploads) == n
	checks.append({'case':'signpost-pixels-and-cache','frame':frame,'tiles':len(loaded)//32})

reset()
m.act('PalLoad2',obj,{m68k.UC_M68K_REG_D0:m.s['palid_TitleCard']})
assert bytes(m.cpu.mem_read(m.s['v_palette'] & 0xFFFFFF,32))==(ROOT/'palette/SonicAndTails.bin').read_bytes()
assert bytes(m.cpu.mem_read((m.s['v_palette']+32)&0xFFFFFF,32))==rom[m.s['Pal_TitleCardYellow']:m.s['Pal_TitleCardYellow']+32]
assert m.read('v_palette',2) == 0
checks.append({'case':'title-card-two-line-palette-pair'})

reset()
m.cpu.mem_write(m.s['v_palette'] & 0xFFFFFF,bytes([0x5A])*128)
m.act('PalLoad2',obj,{m68k.UC_M68K_REG_D0:m.s['palid_MechaSonic']})
palette=bytes(m.cpu.mem_read(m.s['v_palette'] & 0xFFFFFF,128))
assert palette[:32]==bytes([0x5A])*32 and palette[64:]==bytes([0x5A])*64
assert palette[32:64]==(ROOT/'palette/Mecha Sonic.bin').read_bytes()
m.put(obj,'obAnim',5)
m.act('AnimateSprite',obj,{m68k.UC_M68K_REG_A1:m.s['Ani_Signpost']})
assert m.get(obj,'obFrame')==6
checks.append({'case':'mecha-signpost-palette-line-two-and-animation'})

for mode in (0,1,2):
	reset()
	m.write('Player_mode',mode,2)
	m.put(obj,'obRoutine',4)
	m.put(obj,'obAnim',8 if mode==2 else 2)
	m.put(obj,'objoff_36',12,2)
	m.act('Signpost_Spin',obj)
	assert m.get(obj,'obRoutine') == 6
	assert m.get(obj,'obAnim') == (4 if mode == 2 else 3)
	m.act('AnimateSprite',obj,{m68k.UC_M68K_REG_A1:m.s['Ani_Signpost']})
	assert m.get(obj,'obFrame') == (1 if mode == 2 else 0)
	checks.append({'case':'signpost-final-character','mode':mode,'frame':m.get(obj,'obFrame')})

monitor=frames(rom,m.s['Map_MonitorHUD'],m.s['Map_Obj26_frames'])
for kind in (m.s['MonitorType_DoubleLife'],m.s['MonitorType_ExtraLife']):
	assert (monitor[kind+1][0][2]+m.s['ArtTile_Monitor'])&0x7FF==m.s['ArtTile_Lives_Counter']
assert m.s['ArtTile_Signpost']+26 <= m.s['ArtTile_Lamppost']
hud=frames(rom,m.s['Map_obj21'],8)
for row in hud:
	assert (row[-2][2]+m.s['ArtTile_HUD']) & 0xFFFF == m.s['ArtTile_Lives_Counter'] | 0x8000

# Arithmetic in a PLC macro argument needs parentheses before << 5.
tails_plc=m.s['PLC_LivesTails']
assert struct.unpack_from('>H',rom,tails_plc+2+6+4)[0] == (m.s['ArtTile_Lives_Counter']+4)*32
# Preserve the authored GHZ -> imported SMZ -> EHZ route as well as templates.
# These detours predate the eight-byte placement and special-stage Debug work.
detours = {(0, 2): (8, 0), (8, 1): (3, 0), (8, 2): (3, 0), (3, 1): (0, 0)}
assert rom[m.s['LevelOrder']:m.s['LevelOrder']+128] == bytes(
	v for zone in range(16) for act in range(4)
	for v in detours.get((zone, act), (zone,act+1) if act<3 else ((zone+1)%16,0)))

report={'passed':True,'checks':checks,'companion_ai_run':False,
		'card_scenes':78,'signpost_frames':len(dynamic),'hud_icon_tile':m.s['ArtTile_Lives_Counter']}
if args.output:
	args.output.parent.mkdir(parents=True,exist_ok=True)
	args.output.write_text(json.dumps(report,indent=2)+'\n')
print(f'{len(checks)} card/signpost/character checks pass; no companion AI executed.')
