#!/usr/bin/env python3
"""Check real rotating-stage entry, compact player art and the separate tail.

Direction/exit cases explicitly stage player state in an unchanged empty part
of the real layout; ordinary entry and the first 180 gameplay frames use the
actual menu, physics, renderer and CD/VDP upload paths.
"""
from pathlib import Path
import argparse
import ctypes as C
import json
import struct

from genesis_test_core import Genesis
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
for name in ('rom','listing','core','output'):
    p.add_argument('--'+name,type=Path,required=True)
p.add_argument('--system-directory',type=Path)
p.add_argument('--player',type=int,choices=(1,2),default=2)
p.add_argument('--pal',action='store_true')
a = p.parse_args()
g = Genesis(a.core,a.rom,a.listing,a.output,a.pal,system_directory=a.system_directory)
rom = a.rom.read_bytes()
registers = (C.c_uint8*32).in_dll(g.core,'reg')
clouds = kosinski_plus_decode((ROOT/'art/Bonus & Special Stage/Bonus Clouds.kospm').read_bytes()[2:])[0][:81*32]
transition = kosinski_plus_decode((ROOT/'art/Bonus & Special Stage/Bonus BG Transition.kospm').read_bytes()[2:])[0]
entry_checks = 0


def vram(tile,length):
    return bytes(g.vram[(tile*32+i)^1] for i in range(length))


def step(n=1):
    global entry_checks
    for _ in range(n):
        g.run()
        assert not g.read('v_errortype'),('CPU exception',g.frame)
        if (g.read('v_gamemode',2)==g.s['BonusStage'] and
                g.read('v_ssbg_art_uploaded',2)==8 and registers[1]&0x40):
            assert not g.read('Kos_module_queue',4),'Background modules still queued while the stage is visible'
            assert vram(g.s['ArtTile_SS_Background_Transition'],len(transition))==transition,'Opaque entry tiles not loaded before display enable'
            assert vram(g.s['ArtTile_SS_Background_Clouds'],len(clouds))==clouds,'Cloud art incomplete at entry'
            entry_checks += 1


def press(buttons):
    g.buttons=set(buttons);step(2);g.buttons=set();step(3)


def cue(table,source,frame):
    base=g.s[table]
    start=base+struct.unpack_from('>H',rom,base+frame*2)[0]
    count=struct.unpack_from('>H',rom,start)[0]
    words=struct.unpack_from('>'+str(count)+'H',rom,start+2)
    return b''.join(rom[g.s[source]+(w&4095)*32:g.s[source]+((w&4095)+(w>>12)+1)*32] for w in words)


def tail_visible():
    first=g.s['ArtTile_TailsTails']
    index=0
    for _ in range(g.s['Sprite_Table_Max']):
        address=g.s['Sprite_Table']+index*8
        if first <= g.read(address+4,2)&2047 < first+9:
            return True
        index=g.read(address+3)&127
        if not index:
            break
    return False


for _ in range(1800):
    step()
    if g.read('v_vbla_routine',2)==g.s['Vint_Title'] and g.read('v_generictimer',2)==375:
        break
else:
    raise AssertionError('Title did not start')
g.write('f_levselcheat',1);g.write('f_debugcheat',1)
press({3});step(100)
g.write('Player_mode',a.player,2)
g.write('v_levselitem',g.s['LevelSelect_BonusItem'],2)
g.buttons={3};step(2);g.buttons=set()
for _ in range(800):
    step()
    if g.read('v_vbla_routine',2)==g.s['Vint_S1SS']:
        break
else:
    raise AssertionError('Rotating stage did not start')
step(5)
assert entry_checks,'Visible entry was not sampled'
assert g.get('v_player','code')==g.s['BonusPlayer']
assert g.get('v_player','obMap',4)==g.s['Map_Tails' if a.player==2 else 'Map_Sonic']
assert g.get('v_player','character_id')==int(a.player==2)
assert not g.get('v_player2','code'),'Rotating stage spawned a companion AI'
entry=g.save()
g.video.save(a.output/'entry.png')

body_range=range(0x96,0x99) if a.player==2 else range(0x3D,0x42)
name='Tails' if a.player==2 else 'Sonic'
base=g.s['ArtTile_Tails' if a.player==2 else 'ArtTile_Sonic']
cache='Tails_LastLoadedDPLC' if a.player==2 else 'Sonic_LastLoadedDPLC'
body_frames,tail_frames=set(),set()
for tick in range(180):
    previous=g.read(cache)
    previous_tail=g.read('TailsTails_LastLoadedDPLC')
    step()
    frame=g.get('v_player','obFrame');body_frames.add(frame)
    assert frame in body_range,('Unexpected stage body frame',frame)
    candidates=[cue('DPLC_SpecialStage'+name,'Art_SpecialStage'+name,f)
                for f in {previous,g.read(cache)} if f in body_range]
    assert any(vram(base,len(data))==data for data in candidates),'Body VRAM is not a complete compact frame'
    if a.player==2:
        assert g.get('v_player2tails','code')==g.s['Obj05'],'Tails lost his tail object'
        assert g.get('v_player2tails','obParent',2)==g.s['v_player']&65535
        for field in ('obX','obY'):
            assert g.get('v_player2tails',field,2)==g.get('v_player',field,2)
        frame=g.get('v_player2tails','obFrame');tail_frames.add(frame)
        assert frame in range(5,0x15),('Unexpected directional tail frame',frame)
        candidates=[cue('DPLC_SpecialStageTailsTail','Art_SpecialStageTailsTail',f)
                    for f in {previous_tail,g.read('TailsTails_LastLoadedDPLC')} if f in range(5,0x15)]
        assert any(vram(g.s['ArtTile_TailsTails'],len(data))==data for data in candidates),'Tail VRAM is not a complete compact frame'
        assert tail_visible(),'Tail did not reach the hardware sprite table'
    if tick==95:
        g.video.save(a.output/(name+'-in-stage.png'))

# The player and stage items share the authored warm ramp throughout play.
expected=(ROOT/'palette/Special Stage.bin').read_bytes()[:32]
assert bytes(g.read(g.s['v_palette']+i) for i in range(32))==expected

if a.player==2:
    g.restore(entry)
    empty=None
    for row in range(8,58):
        for col in range(8,58):
            if all(g.read(g.s['v_ssbuffer1']+(row+y)*128+col+x)==0
                   for y in range(5) for x in range(5)):
                empty=(col,row);break
        if empty:break
    assert empty,'No clear direction fixture area'
    groups=set()
    for i,(vx,vy) in enumerate(((768,0),(768,768),(0,768),(-768,768),(-768,0),(-768,-768),(0,-768),(768,-768))):
        g.restore(entry)
        g.put('v_player','obX',(empty[0]+2)*24-8,2)
        g.put('v_player','obY',(empty[1]+2)*24-56,2)
        g.put('v_player','obVelX',vx,2);g.put('v_player','obVelY',vy,2)
        g.put('v_player','obInertia',0,2);g.put('v_player','obStatus',6)
        g.write('v_ssangle',0,2);g.write('v_ssrotate',0,2)
        step(6)
        frame=g.get('v_player2tails','obFrame');groups.add((frame-5)//4)
        assert tail_visible()
        g.video.save(a.output/f'tail-direction-{i}.png')
    assert groups=={0,1,2,3},('Missing directional tail family',groups)

# Both Debug modes retain the selected private body source and hide the tail.
for buttons,kind in (({0},1),({0,8},2)):
    g.restore(entry);g.write('Debug_mode_flag',1)
    press(buttons)
    assert g.read('Debug_placement_type')==kind
    if a.player==2:
        assert g.get('v_player2tails','code')==g.s['Obj05']
        assert not tail_visible(),'Tail follows the Debug cursor/frame preview'
    if kind==2:
        seen=set()
        for _ in range(12):
            step();seen.add(g.get('v_player','obFrame'))
        assert seen==set(body_range),('Stage Debug escaped its compact body set',seen)
    press({0});step(6)
    assert not g.read('Debug_placement_mode',2)
    if a.player==2:
        assert tail_visible(),'Tail did not return after Debug'

# Exercise the real accelerating goal exit, including the tail during fade.
g.restore(entry);g.put('v_player','obRoutine',4);step(12)
if a.player==2:assert tail_visible(),'Goal exit removed the tail too early'
for _ in range(450):
    step()
    if g.get('v_endcard','code')==g.s['BonusGotThrough'] and g.get('v_endcard','obRoutine'):
        break
else:
    raise AssertionError('Goal exit did not reach results')
assert not g.get('v_player2tails','code'),'Tail leaked into the results scene'
report=dict(passed=True,player=name,pal=a.pal,visible_entry_checks=entry_checks,
            gameplay_frames=180,body_frames=sorted(body_frames),tail_frames=sorted(tail_frames),
            directional_families=sorted(groups) if a.player==2 else [],
            stage_palette_matches_source=True,debug_modes=2,goal_exit=True,natural_playthrough=False)
(a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(report,flush=True)
g.close()
