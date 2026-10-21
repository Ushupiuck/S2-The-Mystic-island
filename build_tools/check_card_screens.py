#!/usr/bin/env python3
"""Exercise title/results screens in Genesis Plus GX with solo characters.

These are explicit UI/VRAM fixtures, not natural route or companion-AI runs.
Normal results use the real signpost object and its complete spin sequence.
Special results use the special stage's real Start+A Debug exit.
"""
from pathlib import Path
import argparse
import json
import struct
from genesis_test_core import Genesis
from check_object_course import boot_level
from check_sprite_assets import frames

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
for name in ('rom','listing','core','output'):
    p.add_argument('--'+name,type=Path,required=True)
p.add_argument('--case',choices=('intro','normal','special'),required=True)
p.add_argument('--player',type=int,choices=(1,2),default=1)
p.add_argument('--act',type=int,choices=range(4),default=0)
p.add_argument('--emeralds',type=int,choices=range(7),default=0)
p.add_argument('--rings',type=int,default=122)
p.add_argument('--pal',action='store_true')
p.add_argument('--system-directory',type=Path)
args=p.parse_args()
g=Genesis(args.core,args.rom,args.listing,args.output,args.pal,system_directory=args.system_directory)
rom=args.rom.read_bytes()
report={'case':args.case,'player_mode':args.player,'pal':args.pal,
        'natural_playthrough':False,'companion_ai_run':False}


def step(n=1):
    g.run(n)
    assert not g.read('v_errortype'),('CPU exception',g.read('v_errortype'),g.frame)


def vram(start,size):
    return bytes(g.vram[(start+i)^1] for i in range(size))


def card_data(scene):
    root=g.s['DPLC_Cards']
    ptr=root+struct.unpack_from('>h',rom,root+scene*2)[0]
    count=struct.unpack_from('>H',rom,ptr)[0]
    out=bytearray()
    for i in range(count):
        word=struct.unpack_from('>H',rom,ptr+2+i*2)[0]
        source=g.s['Art_CardFont']+(word&0xFFF)*32
        out+=rom[source:source+((word>>12)+1)*32]
    return bytes(out)


def assert_card(scene):
    data=card_data(scene)
    assert vram(g.s['ArtTile_Title_Card']*32,len(data)) == data,('card VRAM',scene)


def assert_ink_color(actor, frame, pieces, count, expected=0x0EE):
    rows=frames(rom,g.get(actor,'obMap',4),count)
    base=g.get(actor,'obGfx',2)
    for index in pieces:
        _,size,word,_=rows[frame][index]
        tile=(base+word)&65535
        data=vram((tile&2047)*32,((size>>2)+1)*((size&3)+1)*32)
        colors={n for b in data for n in (b>>4,b&15)}-{0,1}
        actual={g.read(g.s['v_palette']+((tile>>13&3)*16+n)*2,2) for n in colors}
        assert actual=={expected},('label colors',actor,frame,index,actual)


def assert_bonus():
    source=(ROOT/'art/uncompressed/HUD Numbers.bin').read_bytes()
    for offset,name in ((0,'v_timebonus'),(8,'v_ringbonus')):
        value=g.read(name,2)
        leading=True;expected=bytearray()
        for digit in f'{value:04d}':
            leading=leading and digit=='0'
            expected += bytes(64) if leading else source[int(digit)*64:(int(digit)+1)*64]
        actual=vram((g.s['ArtTile_Bonuses']+offset)*32,8*32)
        assert actual == expected,(name,value,'numeric VRAM')


def assert_score():
    source=(ROOT/'art/uncompressed/HUD Numbers.bin').read_bytes()
    leading=True;expected=bytearray()
    for digit in f"{g.read('v_score',4):06d}":
        leading=leading and digit=='0'
        expected += bytes(64) if leading else source[int(digit)*64:(int(digit)+1)*64]
    assert vram(g.s['ArtTile_HUD_Numbers']*32,len(expected))==expected, 'score VRAM'


def menu():
    for _ in range(1800):
        step()
        if g.read('v_vbla_routine',2)==g.s['Vint_Title'] and g.read('v_generictimer',2)==375:
            break
    else:
        raise AssertionError('Title did not start')
    g.write('f_levselcheat',1);g.write('f_debugcheat',1)
    g.buttons={3};step(2);g.buttons=set();step(100)
    g.write('Player_mode',args.player,2)


if args.case == 'intro':
    menu();saved=g.save();checks=[]
    for zone in range(16):
        for act in range(4):
            g.restore(saved)
            g.write('v_levselitem',(zone//8)*256+(zone%8)*4+act,2)
            g.buttons={3};step(2);g.buttons=set()
            for _ in range(700):
                step()
                if (g.get('v_ttlcardact','code')==g.s['TitleCards'] and
                    g.get('v_ttlcardact','obX',2)==g.get('v_ttlcardact','card_mainX',2)):
                    break
            else:
                raise AssertionError(('intro did not settle',zone,act))
            assert_card(zone*4+act)
            assert g.get('v_ttlcardname','obFrame')==zone
            assert g.get('v_ttlcardact','obFrame')==17+act
            assert_ink_color('v_ttlcardact',17+act,(1,),22)
            if zone in (0,2,4,7,8,10,15) and act in (0,3):
                step();g.video.save(args.output/f'zone-{zone:02X}-act-{act+1}.png')
            for _ in range(700):
                step()
                if g.get('v_ttlcardact','code')==g.s['TitleCards']:
                    assert_ink_color('v_ttlcardact',17+act,(1,),22)
                if g.read('Water_flag') and g.read('v_vbla_routine',2) in (
                        g.s['Vint_LevelLoad'],g.s['Vint_Level'],g.s['Vint_Fade']):
                    actual=g.read(g.s['v_palette_water']+0x38,2)
                    target=g.read(g.s['v_palette_water_fading']+0x38,2)
                    assert actual==target,('underwater ACT color during fade',zone,act,actual,target)
                if (g.read('v_gamemode',2)==g.s['Level'] and
                    g.read('v_vbla_routine',2)==g.s['Vint_Level'] and g.read('f_timecount')):
                    break
            else:
                raise AssertionError(('intro did not reach gameplay',zone,act))
            checks.append({'zone':zone,'act':act+1,'passed':True})
    report['checks']=checks
elif args.case == 'normal':
    boot_level(g,zone=0,act=args.act,player=args.player)
    assert g.get('v_player2','code')==0, 'Solo fixture unexpectedly spawned a companion'
    portrait=(ROOT/'art/nemesis/Monitor and contents.unc').read_bytes()[56*32:60*32]
    assert vram(g.s['ArtTile_Tails_Life']*32,4*32)==portrait
    if args.player == 2:
        name=(ROOT/'art/uncompressed/Tails Life Text Source.unc').read_bytes()
        for tile in (0,2,4,6):
            assert vram((g.s['ArtTile_Lives_Counter']+4+tile)*32,32)==name[tile*32:(tile+1)*32]
    for field,value,size in [('obX',272,2),('obControl',1,1),('obStatus',0,1),
                              ('obVelX',0,2),('obVelY',0,2),('obInertia',0,2)]:
        g.put('v_player',field,value,size)
    for field in ('Camera_X_pos','Camera_Min_X_pos','Camera_Max_X_pos'):
        g.write(field,0,2)
    g.write('Debug_placement_mode',0,2)
    g.write('v_score',800,4);g.write('f_scorecount',1)
    g.write('v_rings',args.rings,2);g.write('f_ringcount',1)
    g.write('v_timemin',1);g.write('v_timesec',52);g.write('f_timecount',1)
    actor=next(a for a in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size'])
               if not g.get(a,'code'))
    g.put(actor,'code',g.s['Signpost']);g.put(actor,'obX',248,2)
    g.put(actor,'obY',g.get('v_player','obY',2)-13,2)
    seen=set()
    for _ in range(170):
        step()
        assert g.get(actor,'code')==g.s['Signpost'], 'Signpost unexpectedly unloaded'
        seen.add(g.get(actor,'obFrame'))
        assert vram(g.s['ArtTile_Tails_Life']*32,4*32)==portrait, 'Signpost overwrote Tails life icon'
        if g.get(actor,'obRoutine')==6:
            break
    else:
        g.video.save(args.output/'signpost-stalled.png')
        raise AssertionError(('Signpost did not finish spinning',
                              {n:g.get(actor,n,z) for n,z in [('obRoutine',1),('obFrame',1),('obAnim',1),('objoff_34',2),('obX',2),('obY',2)]},
                              'player',g.get('v_player','obX',2),'seen',sorted(seen)))
    assert seen==set(range(6)),seen
    expected_frame=1 if args.player==2 else 0
    assert g.get(actor,'obAnim')==(4 if args.player==2 else 3), 'Wrong signpost final animation'
    assert g.get(actor,'obFrame')==expected_frame, 'Wrong signpost final portrait'
    step(2)  # Present the final portrait after its queued DMA reaches VBlank.
    assert g.get(actor,'signpost_loaded')==expected_frame
    g.video.save(args.output/'signpost.png')
    g.put('v_player','obX',300,2)
    for _ in range(150):
        step()
        if g.get('v_endcard','code')==g.s['GotThrough'] and g.get('v_endcard','obRoutine'):
            break
    else:
        raise AssertionError('Normal results did not start')
    step(80)
    scene=64+args.act*2+(args.player==2)
    assert_card(scene);assert_bonus();assert_score()
    expected=g.s['Map_Got_Tails'] if args.player==2 else g.s['Map_Obj3A']
    assert g.get('v_endcard','obMap',4)==expected
    assert g.get('v_endcardact','obFrame')==6+args.act
    assert_ink_color('v_endcard',2,(0,1),10)
    assert_ink_color('v_endcard',3,(0,1,2),10)
    assert_ink_color('v_endcard',4,(1,2),10)
    assert_ink_color('v_endcardact',6+args.act,(1,),10)
    assert vram(g.s['ArtTile_Tails_Life']*32,4*32)==portrait
    g.video.save(args.output/'results.png')
    assert g.get(actor,'obFrame')==expected_frame, 'Signpost portrait changed during results'
    report.update(signpost_frames=sorted(seen),signpost_final_frame=expected_frame,portrait_preserved=True,
                  time_bonus=g.read('v_timebonus',2),ring_bonus=g.read('v_ringbonus',2),act=args.act+1)
else:
    menu();g.write('v_levselitem',g.s['LevelSelect_BonusItem'],2)
    g.buttons={3};step(2);g.buttons=set()
    for _ in range(800):
        step()
        if g.read('v_vbla_routine',2)==g.s['Vint_S1SS']:
            break
    else:
        raise AssertionError('Special stage did not start')
    step(100)
    g.write('v_emeralds',args.emeralds)
    for i in range(args.emeralds):
        g.write(g.s['v_emldlist']+i,i)
    g.write('v_rings',args.rings,2);g.write('v_score',800,4)
    g.write('Current_ZoneAndAct',0x300,2)
    g.write('Debug_mode_flag',1);g.write('f_slomocheat',1)
    g.buttons={3};step(2);g.buttons=set();step(2)
    assert g.read('f_pause',2)==1
    g.buttons={1};step(2);g.buttons=set()
    # Start+A is only the fixture's exit mechanism. Disable coordinate Debug
    # before HUD_Base builds the ordinary results score strip.
    g.write('Debug_mode_flag',0);g.write('f_slomocheat',0)
    for _ in range(1000):
        step()
        if g.get('v_endcard','code')==g.s['BonusGotThrough'] and g.get('v_endcard','obRoutine'):
            break
    else:
        raise AssertionError('Special results did not start')
    step(80)
    state=0 if not args.emeralds else 2 if args.emeralds==6 else 1
    assert_card(72+state*2+(args.player==2));assert_bonus();assert_score()
    assert g.get('v_endcard','obMap',4)==g.s[f'Map_SSR_{state}_{int(args.player==2)}']
    ink=int.from_bytes((ROOT/'palette/Special Stage Results.bin').read_bytes()[30:32],'big')
    assert_ink_color('v_endcard',1,(0,1),7,ink)
    assert_ink_color('v_endcard',2,(1,2),7,ink)
    g.video.save(args.output/'results.png')
    poses=set()
    if args.rings>=50:
        for _ in range(800):
            step()
            frame=g.get('v_ssrescontinue','obFrame')
            if frame in (4,5):
                if frame not in poses:
                    step()  # The video callback presents the preceding SAT.
                    g.video.save(args.output/f'continue-{frame-4}.png')
                poses.add(frame)
                if poses=={4,5}:
                    break
        assert poses=={4,5},poses
        assert_ink_color('v_endcard',4,(0,),7,ink)
    report.update(emeralds=args.emeralds,rings=args.rings,continue_poses=sorted(poses))

report['passed']=True
(args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print({k:v for k,v in report.items() if k!='checks'} | {'checks':len(report.get('checks',[]))},flush=True)
g.close()
