#!/usr/bin/env python3
"""Check lives colors, SBZ smoke/flames and EHZ hit-flash restoration in GX.

Uses real level loads, DMA, animation and sprite output. Boss-hit fixtures call
its assembled damage handler; they leave collision/drawing code unchanged.
"""
from object_layout import decode
from pathlib import Path
import argparse
import ctypes as C
import hashlib
import json
import struct
from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import place
from check_caterkiller import CpuPrefix
from check_sprite_assets import frames
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--core', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
p.add_argument('--system-directory', type=Path)
p.add_argument('--pal', action='store_true')
a = p.parse_args()
g = Genesis(a.core, a.rom, a.listing, a.output, a.pal, system_directory=a.system_directory)
rom = a.rom.read_bytes()
checks = []

def passed(case, **detail):
    checks.append(dict(case=case, **detail))
    print(case+': passed', flush=True)

def vram(first, count):
    return bytes(g.vram[(first+i)^1] for i in range(count))

def restart(zone, act=0, player=0):
    g.core.retro_reset()
    boot_level(g, zone=zone, act=act, player=player)
    assert not g.read('v_errortype')

restart(8)
base = g.save()
portrait = vram(g.s['ArtTile_Lives_Counter']*32, 4*32)
colors = {n for b in portrait for n in (b>>4, b&15)}
assert 4 not in colors and {5,12,13} <= colors, colors
assert g.read(g.s['v_palette']+24, 2) == 0xE
assert g.read(g.s['v_palette']+26, 2) == 8
sat = bytes(g.read(g.s['Sprite_Table']+i) for i in range(80*8))
icons = [struct.unpack_from('>H', sat, i+4)[0] for i in range(0,len(sat),8)
         if struct.unpack_from('>H', sat, i+4)[0]&2047 == g.s['ArtTile_Lives_Counter']]
assert icons and all(word>>13&3 == 0 for word in icons), icons
assert (frames(rom,g.s['Map_Obj26'])[2][0][2]+g.s['ArtTile_Monitor'])&2047 == g.s['ArtTile_Lives_Counter']
g.video.save(a.output/'sbz1-start.png')
passed('HUD and Sonic monitor share the corrected portrait, blue and both reds')

blocks = kosinski_plus_decode((ROOT/'mappings/16x16/SMZ1.kosp').read_bytes())[0]
refs = {word&2047 for word, in struct.iter_unpack('>H', blocks)}
assert set(range(g.s['ArtTile_SMZ_Smoke1'], g.s['ArtTile_SMZ_Smoke2']+12)) <= refs
assert not set(range(0x4BD,0x4C5)) & refs
smoke = (ROOT/'art/uncompressed/SMZ Smoke.bin').read_bytes()
smoke_frames = [smoke[i:i+384] for i in range(0,len(smoke),384)]
assert len(smoke_frames) == 8 and smoke_frames[-1] == bytes(384)
seen = [set(), set()]
protected = [(g.s['ArtTile_SMZ_Atlas']*32, (ROOT/'art/uncompressed/SMZ Sprite Atlas.unc').read_bytes()),
             (g.s['ArtTile_Spring_Diagonal']*32, vram(g.s['ArtTile_Spring_Diagonal']*32, 60*32))]
for tick in range(800):
    g.run()
    assert not g.read('v_errortype')
    for index, bank in enumerate(('ArtTile_SMZ_Smoke1','ArtTile_SMZ_Smoke2')):
        current = vram(g.s[bank]*32,384)
        assert current in smoke_frames, (tick,bank,'smoke art corrupted')
        seen[index].add(smoke_frames.index(current))
    for address, data in protected:
        assert vram(address,len(data)) == data, (tick,hex(address),'neighboring art corrupted')
assert all(len(values)==8 for values in seen), seen
g.video.save(a.output/'sbz1-smoke.png')
passed('Both smoke vents complete every frame; atlas and springs stay intact', frames=800)

for act in range(1,5):
    rows = ((x,y,oid,sub) for x,y,oid,eras,sub in decode((ROOT/f'level/objects/SMZ_{act}.bin').read_bytes()))
    assert all(oid != 0xB0 for _,_,oid,_ in rows)
for label in ('Debug_SMZ','Debug_SMZIndoor'):
    count = struct.unpack_from('>H',rom,g.s[label])[0]
    assert all(struct.unpack_from('>I',rom,g.s[label]+2+i*g.s['DebugEntry_size'])[0] != g.s['WheelCarrier']
               for i in range(count))
for label in (f'PLC_SMZ{act}_Main' for act in range(1,5)):
    count = struct.unpack_from('>H',rom,g.s[label])[0]+1
    assert all(struct.unpack_from('>I',rom,g.s[label]+2+i*6)[0] != g.s['Nem_Wheel'] for i in range(count))
passed('SMZ has no wheel placements, Debug entries or wheel-art PLC')

# At a real flame placement, let the stage's ordinary animation/render pass
# produce every frame and inspect only the flame's player-palette pieces.
g.restore(base)
x,y,oid,sub = next(row for row in ((x,y,oid,sub) for x,y,oid,eras,sub in decode((ROOT/'level/objects/SMZ_1.bin').read_bytes())) if row[2]==0xA7)
y &= 0xFFF
for actor in ('v_player','v_player2'):
    place(g,actor,x-80,max(64,y-80));g.put(actor,'obControl',0x81)
g.write('Camera_X_pos',max(0,x-160),2)
g.write('Camera_Y_pos',max(0,y-112),2)
flame_colors = set()
visible = False
for tick in range(260):
    g.run()
    for obj in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']):
        if g.get(obj,'code') != g.s['SMZ_Flamethrower'] or not g.get(obj,'obRoutine'):
            continue
        mapping = frames(rom,g.get(obj,'obMap',4),g.s['Map_SMZ_Flame_frames'])
        for _,size,word,_ in mapping[g.get(obj,'obFrame')]:
            total = (word+g.get(obj,'obGfx',2))&65535
            if total>>13&3: continue
            data = vram((total&2047)*32,((size>>2)+1)*((size&3)+1)*32)
            flame_colors.update(n for byte in data for n in (byte>>4,byte&15))
            if (14 in flame_colors and g.get(obj,'obRender')&128
                    and g.get(obj,'obFrame') in (10,21) and tick>60 and not visible):
                g.video.save(a.output/'sbz1-flame.png');visible = True
assert visible and 14 in flame_colors and 10 not in flame_colors, flame_colors
assert g.read(g.s['v_palette']+14*2, 2) == 0x0AE
passed('Visible SBZ flames use the golden orange core without changing global colors')

restart(8,1)
kemusi = vram(g.s['ArtTile_SMZ_Kemusi']*32,22*32)
for _ in range(240):
    g.run()
    assert vram(g.s['ArtTile_SMZ_Kemusi']*32,22*32) == kemusi
passed('Indoor Act 2 keeps Kemusi art; smoke DMA stays disabled')

restart(3,1)
stage = g.save()
cpu = CpuPrefix.in_dll(g.core,'m68k')
g.core.m68k_set_reg.argtypes = [C.c_int,C.c_uint]
g.core.m68k_run.argtypes = [C.c_uint]
def act(label,obj):
    g.core.m68k_set_reg(17,0x2700)
    g.core.m68k_set_reg(8,0xFF0000|(obj&65535))
    g.write(0x7E00,0xFF7F00,4);g.write(0x7F00,0x60FE,2)
    g.core.m68k_set_reg(15,0xFF7E00);g.core.m68k_set_reg(16,g.s[label])
    for _ in range(50000):
        if g.core.m68k_get_reg(16)==0xFF7F00:return
        g.core.m68k_run(cpu.cycles+1)
    raise AssertionError((label,hex(g.core.m68k_get_reg(16))))
obj = g.s['v_lvlobjspace']
for normal in (0x222,0,0x444):
    g.restore(stage)
    g.write(obj,0,g.s['object_size'])
    g.put(obj,'ob2ndRout',4)
    g.put(obj,'height_pixels',0x31)
    g.write(g.s['v_palette']+0x22,normal,2)
    for hit in range(7):
        g.put(obj,'obColType',0)
        for tick in range(32):
            act('EHZBoss_CheckHits',obj)
            actual = g.read(g.s['v_palette']+0x22,2)
            assert actual == (0xEEE if tick%2==0 else normal), (normal,hit,tick,hex(actual))
            assert g.get(obj,'height_pixels') == 0x31
        assert g.get(obj,'obColType') == 0xF and g.get(obj,'objoff_42') == 0
        act('EHZBoss_CheckHits',obj)
        assert g.read(g.s['v_palette']+0x22,2) == normal
passed('EHZ boss flashes restore the original shade after every hit; display bounds survive', hits=21)
g.close()
(a.output/'report.json').write_text(json.dumps(dict(pal=a.pal,
    rom_sha256=hashlib.sha256(rom).hexdigest(),checks=checks),indent=2)+'\n')
