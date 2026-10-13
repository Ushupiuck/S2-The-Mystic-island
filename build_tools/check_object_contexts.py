#!/usr/bin/env python3
"""Check objects which require their own screen or a scripted spawning context."""
from pathlib import Path
import argparse
import json
from genesis_test_core import Genesis
from check_object_course import boot_level,position


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build',type=Path,required=True)
    p.add_argument('--core',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--pal',action='store_true')
    p.add_argument('--player',type=int,default=0,choices=(0,2))
    p.add_argument('--case',choices=('stage','warp'),required=True)
    args=p.parse_args()
    g=Genesis(args.core,args.build/'object-course.bin',args.build/'object-course.lst',args.output,args.pal)
    executed=set();report={'case':args.case,'region':'PAL' if args.pal else 'NTSC','primary_mode':args.player}
    def step(frames=1):
        g.run(frames)
        executed.update(i for i in range(1,256) if g.read(g.s['ObjectTest_Executed']+i))
    if args.case=='warp':
        boot_level(g,player=args.player)
        g.put('v_player2','obID',0);position(g,192)
        # The original compressed warp art exists, but its ordinary PLC ID now
        # selects stage art. Queue its real art explicitly in the test course.
        queue=g.s['v_plc_buffer']
        g.write(queue,g.s['Nem_Warp'],4)
        g.write(queue+4,g.s['ArtTile_Warp']*32,2)
        g.write(queue+6,0,4)
        for _ in range(90):
            step()
            if not g.read('v_plc_buffer',4):break
        a=next(a for a in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']) if not g.get(a,'obID'))
        g.put(a,'obID',0x7A)
        vanished=False;returned=False;after_id=None
        for _ in range(250):
            step();vanished|=not g.get('v_player','obID')
            if vanished and g.get('v_player','obID'):
                returned=True;after_id=g.get('v_player','obID');break
        assert vanished and returned,(vanished,returned)
        report.update(vanished=vanished,returned=returned,restored_id=after_id)
        expected=2 if args.player==2 else 1
        assert after_id==expected,('warp restored wrong character',after_id,expected)
        g.video.save(args.output/'warp-return.png')
    else:
        for _ in range(1800):
            step()
            if g.read('v_vbla_routine',2)==g.s['Vint_Title'] and g.read('v_generictimer',2)==375:break
        else:raise AssertionError('title')
        g.write('f_levselcheat',1);g.write('f_debugcheat',1)
        g.buttons={3};step(2);g.buttons=set();step(5)
        g.write('v_levselitem',19,2);g.write('v_lastbonus',0)
        g.buttons={3,1}
        for _ in range(500):
            step()
            if g.read('v_vbla_routine',2)==g.s['Vint_S1SS']:break
        else:raise AssertionError('stage')
        g.buttons=set();step(180)
        assert g.get('v_player','obID')==4
        g.video.save(args.output/'stage.png')
        # Existing emeralds exercise all six results objects. This does not
        # inject the stage's exit routine: Start+A takes its real Debug path.
        g.write('v_emeralds',6)
        for i in range(6):g.write(g.s['v_emldlist']+i,i)
        g.write('Current_ZoneAndAct',0x300,2)
        g.write('Debug_mode_flag',1);g.write('f_slomocheat',1)
        g.buttons={3};step(2);g.buttons=set();step(2)
        assert g.read('f_pause',2)==1
        g.buttons={1};step(2);g.buttons=set()
        for _ in range(800):
            step()
            if g.read('v_vbla_routine',2)==g.s['Vint_SSResults']:break
        else:raise AssertionError('stage results')
        for _ in range(600):
            step()
            if 0x97 in executed:break
        else:raise AssertionError('emerald results objects did not execute')
        assert {4,0x96,0x97}.issubset(executed),sorted(executed)
        step(60)
        g.video.save(args.output/'six-emerald-results.png')
        for _ in range(1600):
            step()
            if g.read('v_vbla_routine',2)==g.s['Vint_Level'] and g.read('v_gamemode',2)==g.s['Level'] and g.read('f_timecount'):break
        else:raise AssertionError('results did not return to gameplay')
        report.update(stage_player=True,results=True,six_emeralds=True,returned_zone_act=g.read('Current_ZoneAndAct',2))
        g.video.save(args.output/'return.png')
    report['executed_ids']=[f'{i:02X}' for i in sorted(executed)]
    (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(report,flush=True)
    g.close()


if __name__=='__main__':main()
