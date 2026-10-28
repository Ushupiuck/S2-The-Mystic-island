#!/usr/bin/env python3
"""Full-frame collision-list capacity, lifecycle and both-actor checks.

RAM establishes focused scenes. The dispatcher, actors, pickups, damage and
list updates then run in the unmodified ROM, including both CPU backends.
"""
import argparse
import json
from pathlib import Path
from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import isolate, place, spawn


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','core','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--system-directory',type=Path);p.add_argument('--pal',action='store_true')
    p.add_argument('--player',type=int,choices=(0,2),default=0)
    args=p.parse_args();g=Genesis(args.core,args.rom,args.listing,args.output,args.pal,system_directory=args.system_directory)
    boot_level(g,zone=0,act=3,player=args.player);isolate(g);base=g.save()
    slots=list(range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']))
    actors=['v_player','v_player2'] if args.player==0 else ['v_player'];checks=[]
    def run(n=1):
        for _ in range(n):
            g.run();assert not g.read('v_errortype'),('exception',g.frame)
    def queue():
        count=g.read('Collision_response_list',2)
        if count==65535:return [a for a in slots if g.get(a,'code') and g.get(a,'obColType') and not g.get(a,'obRender')&64]
        assert count%2==0 and count<=g.s['Collision_response_bytes']
        return [g.read(g.s['Collision_response_entries']+i,2) for i in range(0,count,2)]
    def fixture():
        g.restore(base);isolate(g);g.write('f_timecount',0)
        for who in actors:
            place(g,who,80 if who=='v_player' else 48,500)
            g.put(who,'obControl',0xA1)
        g.write('f_playerctrl',0x80);g.write('Tails_CPU_idle_timer',6000,2);g.buttons2={4}
    for who in actors:
        fixture();dummy=g.s['Free_RAM_Start']&0xFFFFFF;g.write(dummy,0x4E75,2)
        for other in actors:
            if other!=who:place(g,other,48,500);g.put(other,'obControl',0xA1)
        for a in slots[:-1]:
            for f,v,n in [('code',dummy,4),('obColType',0x47,1),('obX',1600,2),('obY',500,2)]:g.put(a,f,v,n)
        ring=slots[-1]
        for f,v,n in [('code',g.s['Obj12'],4),('obX',80,2),('obY',500,2)]:g.put(ring,f,v,n)
        run(4);assert queue()==slots,('capacity',len(queue()))
        score=g.read('v_rings',2);place(g,who,80,500);g.put(who,'obControl',1);g.write('f_playerctrl',0)
        run(6)
        assert g.read('v_rings',2)==score+1,(who,'final-slot ring missed')
        assert g.get(ring,'obColType')==0 and queue()==slots[:-1]
        g.video.save(args.output/f'full-pool-{who}.png')
        checks.append(who+': all 90 candidates through dense fallback, last-slot ring pickup once and cleared hitbox removal')
    # Start/stop collision participation without changing the dummy's code.
    # This also covers invisible hitboxes and complete generation replacement.
    for who in actors:
        fixture();dummy=g.s['Free_RAM_Start']&0xFFFFFF;g.write(dummy,0x4E75,2)
        for other in actors:
            if other!=who:place(g,other,48,500);g.put(other,'obControl',0xA1)
        hazard=slots[0]
        for f,v,n in [('code',dummy,4),('obX',80,2),('obY',500,2),('obColType',0x87,1),('obRender',0,1)]:g.put(hazard,f,v,n)
        run(3);assert queue()==[hazard]
        g.put(hazard,'obColType',0);run(2);assert not queue()
        g.put(hazard,'obColType',0x87);run(2);assert queue()==[hazard]
        place(g,who,80,500);g.put(who,'obControl',1);g.write('f_playerctrl',0);g.write('v_rings',40,2)
        run()
        assert g.get(who,'obRoutine')==4,(who,'invisible hazard missed')
        assert g.read('v_rings',2)==(40 if who=='v_player2' else 0),(who,'ring count',g.read('v_rings',2))
        g.video.save(args.output/f'invisible-hazard-{who}.png')
        # Clearing a code pointer while bytes remain must be harmless.
        g.put(hazard,'code',0);run(3);assert hazard not in queue()
        checks.append(who+': invisible hazard, disabled/re-enabled hitbox, ordinary damage and stale-pointer removal')
    args.output.joinpath('report.json').write_text(json.dumps({'passed':True,'player':args.player,'pal':args.pal,'checks':checks,'controller_only_playthrough':False},indent=2)+'\n')
    print(f'{len(checks)} full-frame collision-list groups passed')
    g.close()

if __name__=='__main__':main()
