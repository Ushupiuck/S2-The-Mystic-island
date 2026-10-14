#!/usr/bin/env python3
"""Check real stage-1 bumper approaches and ordinary play for wall embedding.

All initial positions are clear. The untouched stage grid, collision, bumper
callbacks and final movement run through the actual ROM. No recovery is used.
"""
from pathlib import Path
import argparse
import json

from genesis_test_core import Genesis


def boot_stage(g):
    for tick in range(1800):
        g.run()
        if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
            break
    else:
        raise AssertionError('Title not ready')
    g.write('f_levselcheat', 1)
    g.write('f_debugcheat', 1)
    g.buttons = {3}; g.run(2); g.buttons = set(); g.run(5)
    g.write('v_levselitem', 19, 2)
    g.write('v_lastbonus', 0)
    g.run(5)
    g.buttons = {3, 1}
    for tick in range(500):
        g.run()
        if g.read('v_vbla_routine', 2) == g.s['Vint_S1SS']:
            break
    else:
        raise AssertionError('Stage not ready')
    g.buttons = set(); g.run(12)
    g.write('Debug_mode_flag', 1)
    g.buttons = {0}; g.run(2); g.buttons = set(); g.run(2)
    assert g.read('Debug_placement_mode', 2)


def solid(item):
    return item != 0 and item != 0x28 and (item < 0x3A or item >= 0x4B)


def touching(g, x, y):
    col, row = (x + 20) // 24, (y + 68) // 24
    base = g.s['v_ssbuffer1'] + row * 128 + col
    return any(solid(g.read(base + offset)) for offset in (0, 1, 128, 129))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--probe', action='store_true')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
    boot_stage(g)
    g.buttons = {0}; g.run(1); g.buttons = set(); g.run(2)
    g.write('Debug_mode_flag', 0)
    assert not g.read('Debug_placement_mode', 2)
    baseline = g.save()
    rows = []
    layout = [g.read(g.s['v_ssbuffer1'] + i) for i in range(0x3020)]
    bumpers = [divmod(i,128) for i,v in enumerate(layout) if v==0x25]
    checked=bounced=embedded=0
    for br,bc in bumpers:
        for dc,dr,vx,vy in ((-2,-1,0x700,0),(-2,0,0x700,0),
                           (1,-1,-0x700,0),(1,0,-0x700,0),
                           (-1,-2,0,0x700),(0,-2,0,0x700),
                           (-1,1,0,-0x700),(0,1,0,-0x700)):
            for rx,ry in ((1,1),(1,23),(23,1),(23,23)):
                g.restore(baseline)
                x=(bc+dc)*24-20+rx;y=(br+dr)*24-68+ry
                if x<100 or y<100 or touching(g,x,y):continue
                for f,v,n in [('obX',x<<16,4),('obY',y<<16,4),
                              ('obVelX',vx,2),('obVelY',vy,2),('obInertia',0,2),
                              ('obStatus',6,1),('obRoutine',2,1),('ost_ss_item',0,1)]:
                    g.put('v_player',f,v,n)
                g.write('v_ssangle',0,2);g.write('v_ssrotate',0x40,2)
                checked+=1
                g.run()
                item=g.get('v_player','ost_ss_item')
                # SS_AniItems can replace the grid byte, and the movement guard
                # can record a blocking wall. Check the actual bumper animation.
                bumper_address=(g.s['v_ssbuffer1']+br*128+bc)&0xFFFFFF
                hit=any(g.read(g.s['v_ssitembuffer']+i)==2 and
                        g.read(g.s['v_ssitembuffer']+i+4,4)&0xFFFFFF==bumper_address
                        for i in range(0,0x100,8))
                if hit:
                    bounced+=1
                nx,ny=g.get('v_player','obX',2),g.get('v_player','obY',2)
                if touching(g,nx,ny):
                    embedded+=1
                    case={'bumper':[br,bc],'start':[x,y],'velocity':[vx,vy],
                          'final':[nx,ny],'item':item}
                    rows.append(case)
                    if embedded<=4:g.video.save(args.output/f'embedded-{embedded}.png')
                    if not args.probe:raise AssertionError(('Normal movement embedded Sonic',case))
                assert not g.read('v_errortype')
    rows.append({'case':'real-stage-bumper-approaches','checked':checked,
                 'bounce_contacts':bounced,'embedded':embedded})
    assert checked and bounced
    print(rows[-1],flush=True)
    for item,label in ((0x2A,'down-contact'),(0x27,'goal-contact')):
        found=False
        for cell,value in enumerate(layout):
            if value!=item:continue
            br,bc=divmod(cell,128)
            for dc,dr,vx,vy in ((-2,-1,0x700,0),(1,-1,-0x700,0),
                               (-1,-2,0,0x700),(-1,1,0,-0x700)):
                g.restore(baseline)
                x=(bc+dc)*24-20+23;y=(br+dr)*24-68+23
                if touching(g,x,y):continue
                for f,v,n in [('obX',x<<16,4),('obY',y<<16,4),
                              ('obVelX',vx,2),('obVelY',vy,2),('obInertia',0,2),
                              ('obStatus',6,1),('obRoutine',2,1),('ost_ss_item',0,1),
                              ('ost_ss_updown_time',0,1)]:
                    g.put('v_player',f,v,n)
                g.write('v_ssangle',0,2);g.write('v_ssrotate',0x80,2)
                g.run()
                found=(g.get('v_player','obRoutine')==4 if item==0x27 else
                       g.get('v_player','ost_ss_updown_time')==30)
                if found:break
            if found:break
        assert found,label
        assert not touching(g,g.get('v_player','obX',2),g.get('v_player','obY',2))
        if item==0x2A:
            assert g.read('v_ssrotate',2)==0x40
            assert g.read(g.s['v_ssbuffer1']+cell)==0x29
        else:
            for tick in range(1200):
                g.run()
                if g.get('v_endcard','layout_id')==0x96:break
            else:raise AssertionError('Normal GOAL contact did not reach results')
            g.run(150);g.video.save(args.output/'results.png')
        rows.append({'case':label,'callback':True,'normal_start_clear':True})
        print(rows[-1],flush=True)
    g.restore(baseline)
    initial_lag=g.read('Lag_frame_count',2)
    for tick in range(1200):
        g.buttons=({7} if (tick//80)&1 else {6}) | ({8} if tick%45<3 else set())
        g.run()
        assert not g.read('v_errortype')
        if g.get('v_player','obRoutine')==4:break
        if not args.probe:
            assert not touching(g,g.get('v_player','obX',2),g.get('v_player','obY',2))
    rows.append({'case':'ordinary-play','frames':tick+1,
                 'new_lag_frames':(g.read('Lag_frame_count',2)-initial_lag)&65535})
    (args.output/'report.json').write_text(json.dumps(rows,indent=2)+'\n')
    print(rows[-1]);g.close()


if __name__=='__main__':
    main()
