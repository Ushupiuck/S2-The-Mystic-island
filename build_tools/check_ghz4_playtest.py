#!/usr/bin/env python3
"""Play GHZ4's authored platform/water course in the live emulator.

The entrance route uses controller input only after boot. Focused station visits
position actors in RAM but retain the authored placements, loader and physics.
"""
import argparse
import json
from pathlib import Path
from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import place
from object_layout import decode

ROOT=Path(__file__).resolve().parents[1]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','core','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--system-directory',type=Path)
    p.add_argument('--player',type=int,choices=(0,2),default=0)
    p.add_argument('--pal',action='store_true')
    args=p.parse_args()
    g=Genesis(args.core,args.rom,args.listing,args.output,args.pal,system_directory=args.system_directory)
    boot_level(g,zone=0,act=3,player=args.player)
    rows=decode((ROOT/'level/objects/GHZ_4.bin').read_bytes())
    pool=range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size'])
    base=g.save();checks=[];trace=[]
    assert g.read('Water_flag') and g.read('v_waterpos2',2)==0x600
    assert g.read('Camera_Max_Y_pos',2)==0x700

    def run(n=1):
        for _ in range(n):
            g.run();assert not g.read('v_errortype'),('CPU exception',g.frame)

    def owner(x):
        idx=next(i for i,r in enumerate(rows) if r[0]==x)
        return next((a for a in pool if g.get(a,'code') and g.get(a,'respawn_addr',2)==g.placement_handle(idx)),0)

    def body(root):
        return g.get(root,'swing_body',2) if g.get(root,'code')==g.s['SwingingPtfm'] else root

    def children(b):
        result=[];a=g.get(b,'PlatformMount_head',2)
        while a:
            assert a not in result and len(result)<2
            result.append(a);a=g.get(a,'Mount_next',2)
        return result

    # All four lines are tinted; the four cycling colors use the same tint.
    wet=(ROOT/'palette/GHZ4 Underwater.bin').read_bytes()
    cycle=(ROOT/'palette/GHZ4 Underwater Cycle.bin').read_bytes()
    seen=set()
    for _ in range(36):
        run()
        actual=bytes(g.read(g.s['v_palette_water']+i) for i in range(128))
        assert actual[:0x50]==wet[:0x50] and actual[0x58:]==wet[0x58:], 'underwater palette load'
        phase=actual[0x50:0x58]
        assert phase in [cycle[i:i+8] for i in range(0,len(cycle),8)]
        seen.add(phase)
    assert len(seen)==4
    checks.append('full underwater palette and all four matching waterfall phases')
    g.restore(base)

    # Controller-only route: clear the entrance monitors, land on the button,
    # brake on it, detach and remain aboard the same body as it becomes a raft.
    jumped=False;jump_start=-100;pressed=detached=floated=False
    for t in range(260):
        x=g.get('v_player','obX',2);vx=g.get('v_player','obVelX',2);vx=vx-65536 if vx&32768 else vx
        standing=bool(g.get('v_player','obStatus')&8);buttons=set()
        if standing:
            if vx>0x40:buttons={6}
            elif vx< -0x40:buttons={7}
        else:
            if x<360:buttons={7}
            elif x>398 or vx>0x40:buttons={6}
            elif vx< -0x40:buttons={7}
            if not jumped and x>=218:jumped=True;jump_start=t
            if jumped and t-jump_start<24:buttons.add(0)
        g.buttons=buttons;run()
        assert g.get('v_player','obRoutine')<6, ('entrance death',args.player,t)
        root=owner(0x180);b=body(root) if root else 0
        if b:
            pressed|=bool(g.read('f_switch')&1)
            detached|=g.get(root,'obRoutine')==4
            floated|=g.get(b,'obRoutine')==12
        trace.append([t,g.get('v_player','obX',2),g.get('v_player','obY',2),g.get('v_player','obStatus'),g.get(b,'obRoutine') if b else -1,sorted(buttons)])
        if t in (105,150,210,259):g.video.save(args.output/f'entrance-{t}.png')
    assert pressed and detached and floated and g.get('v_player','obStatus')&8, ('entrance',args.player,pressed,detached,floated)
    assert g.get(b,'obVelX',2)==0 and g.get(b,'obX',2)+g.get(b,'obActWid')<=0x200, 'raft entered the solid bank'
    checks.append('controller-only entrance: button landing/braking, detachment, raft ride and solid-bank stop')

    def visit(x,y):
        g.restore(base)
        for who in ('v_player','v_player2'):
            if not g.get(who,'code'):continue
            place(g,who,x-80,y-40);g.put(who,'obControl',1)
        g.write('Tails_CPU_idle_timer',6000,2);g.buttons2={4}
        g.write('Camera_X_pos',max(0,x-160),2);g.write('Camera_Y_pos',max(0,y-110),2)
        g.write('Screen_redraw_flag',1);run(12)
        root=owner(x);assert root, ('placement not loaded',hex(x))
        b=body(root);assert b
        return root,b,children(b)

    actors=['v_player'] if args.player==2 else ['v_player','v_player2']
    for who in actors:
        for local_x,strength in ((-16,0xF000),(16,0xF600)):
            root,b,group=visit(0x400,0x480)
            child=next(a for a in group if g.get(a,'Mount_x',2)==local_x&65535)
            place(g,who,g.get(child,'obX',2),g.get(child,'obY',2)-g.get(who,'default_y_radius')-10)
            g.put(who,'obVelY',0x100,2)
            launched=False
            for _ in range(30):
                run();launched|=g.get(who,'obVelY',2)==strength
                if launched:break
            assert launched, ('spring launch',who,local_x)
            g.video.save(args.output/f'spring-{who}-{local_x}.png')
        root,b,group=visit(0x680,0x3E8);child=group[0]
        place(g,who,g.get(child,'obX',2),g.get(child,'obY',2)-70)
        for f,v,n in [('obStatus',6,1),('obAnim',g.s['AniIDSonAni_Roll'],1),('obHeight',14,1),('obWidth',7,1),('obVelY',0x100,2)]:g.put(who,f,v,n)
        g.write('v_rings',40,2);run(100)
        assert g.get(child,'obRoutine')>=6 and g.get(child,'obParent',2)==g.s[who]&65535
        assert g.read('v_rings',2)==50
        g.video.save(args.output/f'monitor-{who}.png')
        # After breaking the box, running into the rail must still supply
        # momentum; the mounted reward must not disable its parent's behavior.
        place(g,who,g.get(b,'obX',2)+12,g.get(b,'obY',2)-g.get(b,'obHeight')-g.get(who,'default_y_radius')+2)
        g.put(who,'obVelX',0x800,2);g.put(who,'obVelY',0x100,2)
        started=False
        for _ in range(12):
            run();started|=bool(g.get(root,'swing_mode_started'))
        assert started, ('authored momentum rail',who)
        root,b,group=visit(0x900,0x480);child=group[0]
        place(g,who,g.get(child,'obX',2),g.get(child,'obY',2)-g.get(who,'default_y_radius')-20)
        g.put(who,'obVelY',0x100,2);g.put(who,'obStatusSecondary',0);g.put(who,'invtime',0,2)
        g.write('v_rings',40,2);hurt=False
        for _ in range(20):run();hurt|=g.get(who,'obRoutine')==4
        assert hurt, ('spike damage',who)
    checks.append('authored spring colors/strengths, monitor collector/reward, momentum rail and spike damage for every active character')

    if args.player==0:
        # Both arrangements use the same physical body through detachment.
        for top,bottom in (('v_player','v_player2'),('v_player2','v_player')):
            root,b,group=visit(0x180,0x588);button=group[0];grip=g.get(b,'Plat_hanger',2)
            assert grip
            place(g,top,g.get(button,'obX',2),g.get(button,'obY',2)-45)
            g.put(top,'obVelY',0x100,2)
            place(g,bottom,g.get(grip,'obX',2),g.get(grip,'obY',2)+30)
            both=floated=False
            for t in range(180):
                run()
                both|=g.get(top,'obStatus')&8 and g.get(bottom,'obControl')==3
                if g.get(b,'obRoutine')==12:
                    floated=True
                    assert g.get(top,'obStatus')&8 and g.get(bottom,'obControl')==3
                    assert g.get(bottom,'obStatus')&64, 'hanging character did not enter water'
                    assert abs(g.get(b,'obY',2)-g.read('v_waterpos2',2))<=5
                    g.video.save(args.output/f'floating-grip-{bottom}.png')
                    break
            assert both and floated
        checks.append('both standing/hanging arrangements detach into water using the same body and grip')
    g.close()
    (args.output/'playtest.json').write_text(json.dumps(dict(checks=checks,entrance_trace=trace),indent=2)+'\n')
    print('\n'.join('PASS '+check for check in checks))


if __name__=='__main__':main()
