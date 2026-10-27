#!/usr/bin/env python3
"""Full-frame signpost fixtures: both entries, jumping hits, terrain and results.

RAM creates each scene; subsequent controller input/ROM physics and VDP DMA
execute normally. Focused actor repositioning is explicit, not a playthrough.
"""
import argparse
import json
import struct
from pathlib import Path
from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import isolate, spawn, place


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','core','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--system-directory',type=Path)
    p.add_argument('--player',type=int,choices=(0,2),default=0)
    p.add_argument('--pal',action='store_true')
    args=p.parse_args()
    g=Genesis(args.core,args.rom,args.listing,args.output,args.pal,system_directory=args.system_directory)
    boot_level(g,zone=0,act=0,player=args.player)
    isolate(g);base=g.save();checks=[];rom=args.rom.read_bytes()
    actors=['v_player','v_player2'] if args.player==0 else ['v_player']
    def run(n=1):
        for _ in range(n):
            g.run();assert not g.read('v_errortype'),('CPU exception',g.frame)
    def fixture(sub=1):
        g.restore(base)
        g.write('Camera_X_pos',0,2);g.write('Camera_Min_X_pos',0,2);g.write('Camera_Max_X_pos',0,2)
        for who in actors:
            place(g,who,80 if who=='v_player' else 48,940)
        g.write('Tails_CPU_idle_timer',6000,2);g.buttons2={4}
        return spawn(g,'Signpost',248,930,sub)
    def verify_dplc(sign):
        frame=g.get(sign,'obFrame');root=g.s['DPLC_Signpost']
        ptr=root+struct.unpack_from('>h',rom,root+frame*2)[0];data=bytearray()
        for i in range(struct.unpack_from('>H',rom,ptr)[0]):
            word=struct.unpack_from('>H',rom,ptr+2+i*2)[0]
            start=g.s['Art_Signpost']+(word&4095)*32
            data+=rom[start:start+((word>>12)+1)*32]
        actual=bytes(g.vram[(g.s['ArtTile_Signpost']*32+i)^1] for i in range(len(data)))
        assert actual==data,('signpost DPLC',frame)
    def finish(sign,label):
        states=set()
        for t in range(900):
            run();states.add(g.get(sign,'obRoutine'))
            if t in (4,40,80):g.video.save(args.output/f'{label}-{t}.png')
            if g.get('v_endcard','code')==g.s['GotThrough'] and g.get('v_endcard','obRoutine'):
                run(80);verify_dplc(sign)
                assert g.get(sign,'obFrame')==(1 if args.player==2 else 0)
                g.video.save(args.output/f'{label}-results.png')
                return states
        raise AssertionError((label,'no results',g.get(sign,'obRoutine'),g.get(sign,'obX',2),g.get(sign,'obY',2),g.get('v_player','obStatus'),g.get('v_player','obY',2)))

    sign=fixture()
    for _ in range(4):
        run()
        if g.get(sign,'obRoutine'):break
    assert g.get(sign,'obRoutine')==10 and g.get(sign,'obY',2)==g.read('Camera_Y_pos',2)-32, ('sky init',g.get(sign,'obRoutine'),g.get(sign,'obY',2),g.read('Camera_Y_pos',2))
    assert not g.read('f_timecount')
    states=finish(sign,'sky')
    assert {10,12,14,8}<=states,states
    checks.append('sky drop: real terrain landing, landing spin, final portrait/DMA and results')

    # Use real horizontal movement for the threshold crossing. The initial
    # position/speed establishes the focused scene, then only hold right.
    sign=fixture(0)
    # This artificial near-start arena is shorter than the normal 256px
    # signpost-art approach. Suppress that unrelated approach-lock service.
    g.write('f_timecount',0)
    place(g,'v_player',228,940,False)
    g.put('v_player','obVelX',0x600,2);g.put('v_player','obInertia',0x600,2)
    g.buttons={7};run(6);g.buttons=set()
    assert g.get(sign,'obRoutine')==10 and g.get(sign,'obSubtype')&1
    assert g.get(sign,'obVelY',2)&0x8000 and g.get(sign,'obX',2)==248
    # Brake after crossing so the actor stays in the scene while it lands.
    g.buttons={6};run(10);g.buttons=set()
    states=finish(sign,'fast-launch')
    assert 12 in states
    checks.append('normal placed sign launches vertically on a real fast crossing, then reaches results')

    # Actual upward player motion into a descending sign, once for each actor.
    for who in actors:
        sign=fixture();run(48)
        assert g.get(sign,'obRoutine')==10
        x=g.get(sign,'obX',2);y=g.get(sign,'obY',2)
        for actor in actors:
            place(g,actor,48,940)
        place(g,who,x-8,y+20)
        for f,v,n in [('obVelY',0xFC00,2),('obStatus',6,1),('obAnim',2,1),('obHeight',14,1),('obWidth',7,1),('jumping',1,1)]:g.put(who,f,v,n)
        score=g.read('v_score',4);run()
        assert g.read('v_score',4)==score+10,(who,'hit score')
        assert g.get(sign,'obVelY',2)==0xFE0C and g.get(sign,'obVelX',2)>0
        pops=[a for a in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']) if g.get(a,'code')==g.s['Points']]
        assert any(g.get(a,'points_parent',2)==g.s[who]&65535 for a in pops)
        run(4);g.video.save(args.output/f'hit-{who}.png')
        # Cooldown is real game time; keep the actor safely away afterward.
        place(g,who,80,900)
        run(30);assert g.read('v_score',4)==score+10
        # Exercise the screen-edge reflection with an actual moving sign.
        g.put(sign,'obX',297,2);g.put(sign,'obVelX',0x100,2)
        run();assert g.get(sign,'obVelX',2)==0xFF00
        g.put(sign,'obX',23,2);g.put(sign,'obVelX',0xFF00,2)
        run();assert g.get(sign,'obVelX',2)==0x100
        finish(sign,'hit-'+who)
        checks.append(who+': upward roll bounce, owned 100-point popup, cooldown, both screen edges and results')

    args.output.joinpath('report.json').write_text(json.dumps({'passed':True,'player':args.player,'pal':args.pal,'checks':checks,'controller_only_playthrough':False},indent=2)+'\n')
    print(f'{len(checks)} full-frame signpost groups passed')

if __name__=='__main__':main()
