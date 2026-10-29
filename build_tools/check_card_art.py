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
base = m.s['ArtTile_Title_Card']*32
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
        for frame,tile in ((3,m.s['ArtTile_Bonuses']),(4,m.s['ArtTile_Bonuses']+8)):
            assert (rows[frame][5][2]+m.s['ArtTile_Title_Card']) & 0xFFFF == tile
        checks.append({'case':'normal-character-and-bonus-addresses','mode':mode,'act':act+1})

for mode in (0,1,2):
    for emeralds in (0,1,5,6):
        reset()
        m.write('Player_mode',mode,2);m.write('v_emeralds',emeralds)
        m.act('Get_SpecialCardScene')
        state=0 if not emeralds else 2 if emeralds == 6 else 1
        scene=72+state*2+(mode == 2)
        assert m.cpu.reg_read(m68k.UC_M68K_REG_D0) == scene
        rows=frames(rom,m.cpu.reg_read(m68k.UC_M68K_REG_A3),7)
        assert (rows[2][5][2]+m.s['ArtTile_Title_Card']) & 0xFFFF == m.s['ArtTile_Bonuses']+8
        mini=m.s['ArtTile_Mini_Tails'] if mode == 2 else m.s['ArtTile_Mini_Sonic']+18
        assert (rows[4][-1][2]+m.s['ArtTile_Title_Card']) & 0xFFFF == 0x2000+mini
        checks.append({'case':'special-heading-and-character-addresses','mode':mode,'emeralds':emeralds})


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

monitor=frames(rom,m.s['Map_Obj26'])
assert monitor[3][0][2] & 0x7FF == 56
assert m.s['ArtTile_Signpost']+26 <= m.s['ArtTile_Tails_Life']
assert m.s['ArtTile_Tails_Life']+4 == m.s['ArtTile_Lamppost']
hud=frames(rom,m.s['Map_obj21'],8)
for i in range(8):
    expected=m.s['ArtTile_Tails_Life'] if i >= 4 else m.s['ArtTile_Lives_Counter']
    assert (hud[i][-2][2]+m.s['ArtTile_HUD']) & 0xFFFF == expected | 0x8000

# Arithmetic in a PLC macro argument needs parentheses before << 5.
tails_plc=m.s['PLC_LivesTails']
assert struct.unpack_from('>H',rom,tails_plc+2+6+4)[0] == (m.s['ArtTile_Lives_Counter']+4)*32
# Preserve the authored GHZ -> imported SMZ -> EHZ route as well as templates.
# These detours predate the eight-byte placement and special-stage Debug work.
detours = {(0, 2): (8, 0), (8, 1): (3, 0), (8, 2): (3, 0)}
assert rom[m.s['LevelOrder']:m.s['LevelOrder']+128] == bytes(
    v for zone in range(16) for act in range(4)
    for v in detours.get((zone, act), (zone,act+1) if act<3 else ((zone+1)%16,0)))

report={'passed':True,'checks':checks,'companion_ai_run':False,
        'card_scenes':78,'signpost_frames':len(dynamic),'tails_icon_tile':m.s['ArtTile_Tails_Life']}
if args.output:
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
print(f'{len(checks)} card/signpost/character checks pass; no companion AI executed.')
