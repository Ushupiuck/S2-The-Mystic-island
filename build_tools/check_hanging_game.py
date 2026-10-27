#!/usr/bin/env python3
"""Full-frame hanging fixtures: real players, terrain, solids, animation/DMA.

Fixture RAM writes establish the scene. Player motion, grabbing, regrabbing,
traversal, landing and rendering then execute the unmodified game code.
"""
import argparse
import json
from pathlib import Path
from check_object_course import boot_level
from check_companion_followup import isolate, spawn, place
from genesis_test_core import Genesis


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','core','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--system-directory',type=Path)
    p.add_argument('--pal',action='store_true')
    p.add_argument('--player',type=int,choices=(0,2),default=0)
    args=p.parse_args()
    g=Genesis(args.core,args.rom,args.listing,args.output,args.pal,system_directory=args.system_directory)
    boot_level(g,zone=0,act=3,player=args.player)
    base=g.save();checks=[]
    actors=['v_player','v_player2'] if args.player==0 else ['v_player']

    def run(n=1):
        for _ in range(n):
            g.run()
            assert not g.read('v_errortype'),('CPU exception',g.frame)

    def fixture(who,sub=0):
        g.restore(base);isolate(g)
        g.write('Tails_CPU_idle_timer',600,2)
        g.write('Camera_X_pos',0x360,2);g.write('Camera_Y_pos',0x190,2)
        g.write('Camera_X_pos_coarse_back',0x300,2)
        g.write('Camera_Max_Y_pos',0x720,2)
        for actor in actors:
            place(g,actor,0x400,0x200)
            g.put(actor,'obControl',1)
        h=spawn(g,'HangingSurface',0x400,0x220,sub)
        place(g,who,0x400,0x220+(12 if sub&128 else 30))
        for _ in range(8):
            run()
            if g.get(who,'obControl')==3:break
        assert g.get(who,'obControl')==3,('grab',who,sub,hex(g.get(h,'code')),hex(g.get(who,'obY',2)),hex(g.read('Camera_X_pos_coarse_back',2)),g.get(who,'obRoutine'))
        return h

    # Actual PLC upload and SAT output, rather than a mapping-only preview.
    hand_art=(Path(__file__).resolve().parents[1]/'art/uncompressed/Hanging surface.unc').read_bytes()
    bank=g.s['ArtTile_HangingSurface']*32
    assert bytes(g.vram[(bank+i)^1] for i in range(len(hand_art)))==hand_art

    def drawn_grips(h):
        helper=g.get(h,'Hang_display',2)
        assert helper and g.get(helper,'code')==g.s['Hanging_DisplayHelper']
        count=g.get(helper,'obFrame')+1
        sat=[]
        for i in range(g.read('v_spritecount')):
            p=g.s['Sprite_Table']+i*8
            tile=g.read(p+4,2)&0x7FF
            if tile in (g.s['ArtTile_HangingSurface'],g.s['ArtTile_HangingSurface']+4):
                sat.append((g.read(p+6,2),tile))
        assert len(sat)==count*2,('handhold SAT count',count,sat)
        assert all(sat[i+2][0]-sat[i][0]==32 for i in range(0,len(sat)-2,2))
        return count

    for count in (1,2,3,8):
        h=fixture('v_player',0x80|count)
        run(8)
        assert drawn_grips(h)==count
        assert g.get('v_player','obControl')==3
        g.video.save(args.output/('handholds-%02d.png'%count))
    checks.append('1/2/3/8 handholds: real act PLC pixels, two SAT pieces per grip and 32px spacing')

    h=fixture('v_player',0xBF)
    for camera in (0x40,0x360,0x680):
        for actor in actors:
            g.put(actor,'obControl',1);g.put(actor,'obX',camera+160,2)
            g.put(actor,'obVelX',0,2);g.put(actor,'obInertia',0,2)
        g.write('Camera_X_pos',camera,2);g.write('Camera_X_pos_coarse_back',camera&0xFF80,2)
        run(4)
        assert 9<=drawn_grips(h)<=11
        assert g.get(h,'Hang_halfwidth',2)==63*16
        g.video.save(args.output/('handholds-63-camera-%04X.png'%camera))
    g.put(h,'obSubtype',0x4BF,2);run(4)
    assert not g.get(h,'Hang_display',2)
    checks.append('63-grip row: camera views near both ends and centre, clipped SAT output and hide-art cleanup')

    for who in actors:
        h=fixture(who)
        run(30)
        g.video.save(args.output/(who+'-classic.png'))
        buttons='buttons2' if who=='v_player2' else 'buttons'
        setattr(g,buttons,{0});run(1);setattr(g,buttons,set())
        for _ in range(6):
            if not g.get(who,'obControl'):break
            run()
        assert not g.get(who,'obControl'),('jump release',who)
        assert g.get(who,'jumping')==1
        for _ in range(90):
            run()
            if g.get(who,'obControl')==3:break
        assert g.get(who,'obControl')==3,('neutral regrab',who)
        checks.append(who+': neutral jump and automatic regrab with actual player physics')

        h=fixture(who,0x84)
        g.put(who,'obX',0x400-48,2)
        first=g.get(who,'obX',2)
        setattr(g,buttons,{7})
        poses=set()
        for i in range(95):
            run();poses.add(g.get(who,'obFrame'))
            if i in (0,8,16,24):g.video.save(args.output/(who+'-traverse-%02d.png'%i))
        setattr(g,buttons,set())
        assert g.get(who,'obX',2)==first+96,('traverse endpoint',who,hex(g.get(who,'obX',2)))
        assert g.get(who,'obControl')==3 and len(poses)>=4
        checks.append(who+': four-grip traversal, alternating animated hands, clamped endpoint')

        # Platform below the character stays harmless at a 40px gap, then an
        # authored upward oscillator meets the feet and takes over standing.
        h=fixture(who)
        floor=spawn(g,'Obj18',0x400,0x220+36+g.get(who,'obHeight')+49,0x183)
        # Pause the oscillator only during construction, then use its real
        # changing Y values. Record the actual landing rather than proximity.
        seen=False
        for _ in range(180):
            old_control=g.get(who,'obControl')
            run()
            if old_control==3 and not g.get(who,'obControl'):
                assert g.get(who,'obStatus')&8,('solid landing',who)
                assert not g.get(who,'obStatus')&2
                seen=True;break
        assert seen,('rising solid never reached grip',who)
        run(10);g.video.save(args.output/(who+'-solid-support.png'))
        checks.append(who+': actual rising full-solid platform releases grip and carries character')

        # Actual GHZ4 floor at this X: move the hanging origin down until the
        # character's feet meet it. A positive probe must leave control intact.
        h=fixture(who)
        for y in range(0x220,0x350):
            g.put(h,'obY',y,2);run()
            if not g.get(who,'obControl'):break
        assert not g.get(who,'obControl'),('terrain did not release',who)
        assert not g.get(who,'obStatus')&2
        g.video.save(args.output/(who+'-terrain-support.png'))
        checks.append(who+': real terrain contact releases; distant terrain does not')

    if len(actors)==2:
        for bottom,top in [('v_player','v_player2'),('v_player2','v_player')]:
            g.restore(base);isolate(g)
            g.write('Tails_CPU_idle_timer',600,2)
            g.write('Camera_X_pos',0x360,2);g.write('Camera_Y_pos',0x190,2)
            g.write('Camera_X_pos_coarse_back',0x300,2)
            platform=spawn(g,'Obj18',0x400,0x240,0x0901)
            for actor in actors:place(g,actor,0x400,0x200);g.put(actor,'obControl',1)
            for _ in range(8):
                run()
                if g.get(platform,'Plat_hanger',2):break
            child=g.get(platform,'Plat_hanger',2)
            assert child
            place(g,bottom,g.get(child,'obX',2),g.get(child,'obY',2)+30)
            place(g,top,g.get(platform,'obX',2),g.get(platform,'obY',2)-27+2)
            g.put(top,'obVelY',0x100,2)
            for _ in range(30):run()
            assert g.get(bottom,'obControl')==3,(bottom,'hanging')
            assert g.get(top,'obStatus')&8,(top,'standing')
            dx=g.get(bottom,'obX',2)-g.get(platform,'obX',2)
            for _ in range(80):
                run()
                assert g.get(bottom,'obControl')==3
                assert g.get(top,'obStatus')&8
                assert g.get(bottom,'obX',2)-g.get(platform,'obX',2)==dx
            assert (g.s['v_objspace']+g.get(top,'standonobject')*g.s['object_size'])&65535==platform,('wrong standing owner',top)
            g.video.save(args.output/(bottom+'-below-'+top+'.png'))
            checks.append(bottom+' hangs below while '+top+' rides the moving/sagging parent')

    (args.output/'game.json').write_text(json.dumps({'pal':args.pal,'player':args.player,'checks':checks},indent=2)+'\n')
    g.close();print('\n'.join('PASS '+row for row in checks))


if __name__=='__main__':main()
