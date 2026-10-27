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
    base=g.save();checks=[];terrain_floor={}
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

    chain_art=(Path(__file__).resolve().parents[1]/'art/uncompressed/Hanging chain.unc').read_bytes()
    assert bytes(g.vram[(bank+320+i)^1] for i in range(64))==chain_art
    for reverse in (False,True):
        g.restore(base);isolate(g)
        g.write('Tails_CPU_idle_timer',600,2)
        g.write('Camera_X_pos',0x360,2);g.write('Camera_Y_pos',0x190,2)
        g.write('Camera_X_pos_coarse_back',0x300,2)
        for actor in actors:
            place(g,actor,0x400,0x180);g.put(actor,'obControl',1)
        chain=spawn(g,'PullChain',0x400,0x1A0,0x208|(0x80 if reverse else 0))
        for _ in range(8):
            run()
            if g.get(chain,'Pull_hanger',2):break
        child=g.get(chain,'Pull_hanger',2);assert child
        for i,actor in enumerate(actors):place(g,actor,0x3F8+i*16,g.get(child,'obY',2)+30)
        for _ in range(8):
            run()
            if all(g.get(actor,'obControl')==3 for actor in actors):break
        assert all(g.get(actor,'obControl')==3 and g.get(actor,'obX',2)==0x400 for actor in actors)
        for _ in range(100):
            before=g.get(chain,'Pull_extension',2);run();after=g.get(chain,'Pull_extension',2)
            assert after-before in ((-2,0) if reverse else (0,2)),('chain step',reverse,before,after)
            assert all(g.get(actor,'obControl')==3 for actor in actors)
            if after==(0 if reverse else 64):break
        assert after==(0 if reverse else 64)
        g.video.save(args.output/('pull-chain-'+('raise' if reverse else 'lower')+'.png'))
        # Releasing one player cannot send the other back to the resting end.
        for actor in actors:
            buttons='buttons2' if actor=='v_player2' else 'buttons'
            setattr(g,buttons,{0})
            for _ in range(6):
                run()
                if not g.get(actor,'obControl'):break
            setattr(g,buttons,set());assert not g.get(actor,'obControl')
            g.put(actor,'obControl',1);g.put(actor,'obX',0x480,2)
            if actor!=actors[-1]:
                run(8);assert g.get(chain,'Pull_extension',2)==(0 if reverse else 64)
        for _ in range(100):
            run()
            if g.get(chain,'Pull_extension',2)==(64 if reverse else 0):break
        assert g.get(chain,'Pull_extension',2)==(64 if reverse else 0)
        assert g.get(chain,'Pull_anchorY',2)==0x1A0
    checks.append('DA: both movement directions, centred independent players, 2px steps and return after the final release')

    g.restore(base);isolate(g)
    g.write('Camera_X_pos',0x360,2);g.write('Camera_X_pos_coarse_back',0x300,2)
    chain=spawn(g,'PullChain',0x400,0x1A0,0xFFF)
    for camera in (0x190,0x400,0x600):
        g.write('Camera_Y_pos',camera,2);g.write('Camera_Max_Y_pos',0x720,2)
        for actor in actors:place(g,actor,0x400,camera+100);g.put(actor,'obControl',1)
        run(4)
        assert g.get(chain,'Pull_extension',2)==1016
        assert g.get(chain,'obFrame')<30
        assert g.get(chain,'Pull_hanger',2)
        g.video.save(args.output/('pull-chain-long-%04X.png'%camera))
    checks.append('DA: maximum 1256px chain draws through three camera heights without moving its physical anchor')

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
        terrain_floor[who]=g.get(who,'obY',2)+g.get(who,'obHeight')
        checks.append(who+': real terrain contact releases; distant terrain does not')

    if len(actors)==2:
        for family in ('regular','swing'):
            for profile in (6,7,8,9):
                for bottom,top in [('v_player','v_player2'),('v_player2','v_player')]:
                    g.restore(base);isolate(g)
                    g.write('Tails_CPU_idle_timer',600,2)
                    g.write('Camera_X_pos',0x360,2);g.write('Camera_Y_pos',0x190,2)
                    g.write('Camera_X_pos_coarse_back',0x300,2)
                    settings=(profile<<8)|(0x81 if family=='regular' else 0x25)
                    platform=spawn(g,'Obj18' if family=='regular' else 'SwingingPtfm',0x400,0x200 if family=='regular' else 0x1A8,settings)
                    field='Plat_hanger' if family=='regular' else 'swing_hanger'
                    for actor in actors:place(g,actor,0x400,0x180);g.put(actor,'obControl',1)
                    for _ in range(8):
                        run()
                        if g.get(platform,field,2):break
                    child=g.get(platform,field,2);assert child
                    place(g,bottom,g.get(child,'obX',2),g.get(child,'obY',2)+30)
                    place(g,top,g.get(platform,'obX',2),g.get(platform,'obY',2)-g.get(platform,'obHeight')-g.get(top,'obHeight')+2)
                    g.put(top,'obVelY',0x100,2)
                    # Belt riders are expected to walk off if they stand still;
                    # check the simultaneous interaction before reaching the edge.
                    run(8 if profile>=8 else 30)
                    assert g.get(bottom,'obControl')==3,(family,profile,bottom,'hanging')
                    assert g.get(top,'obStatus')&8,(family,profile,top,'standing')
                    assert g.get(bottom,'obY',2)==g.get(child,'obY',2)+36
                    if profile>=8:assert g.get(top,'obX',2)>g.get(platform,'obX',2),(family,profile,'belt did not carry')
                    else:
                        dx=g.get(bottom,'obX',2)-g.get(platform,'obX',2)
                        for _ in range(50):
                            run()
                            assert g.get(bottom,'obControl')==3 and g.get(top,'obStatus')&8
                            assert g.get(bottom,'obX',2)-g.get(platform,'obX',2)==dx
                    g.video.save(args.output/(family+'-%X-'%profile+bottom+'-below-'+top+'.png'))
                    checks.append(family+' profile %X: '%profile+bottom+' hangs while '+top+' stands/conveys')

        # The requested falling conveyor/bar combination, using the normal
        # object executor and real player collision for both solidity variants.
        for profile in (8,9):
            g.restore(base);isolate(g);g.write('Tails_CPU_idle_timer',600,2)
            g.write('Camera_X_pos',0x360,2);g.write('Camera_Y_pos',0x100,2);g.write('Camera_X_pos_coarse_back',0x300,2)
            for actor in actors:place(g,actor,0x400,0x100);g.put(actor,'obControl',1)
            platform=spawn(g,'Obj18',0x400,0x1A0,(profile<<8)|0x1080)
            for _ in range(8):
                run()
                if g.get(platform,'Plat_hanger',2):break
            child=g.get(platform,'Plat_hanger',2);assert child
            place(g,'v_player',0x400,g.get(platform,'obY',2)-g.get(platform,'obHeight')-g.get('v_player','obHeight')+2)
            place(g,'v_player2',0x400,g.get(child,'obY',2)+30)
            g.put('v_player','obVelY',0x100,2)
            run(8)
            assert g.get('v_player','obStatus')&8 and g.get('v_player2','obControl')==3
            assert g.get('v_player','obX',2)>g.get(platform,'obX',2)
            g.video.save(args.output/('falling-conveyor-%X-before.png'%profile))
            falling=False;released=False
            for _ in range(100):
                run()
                falling|=g.get(platform,'Plat_movement',4)==g.s['Plat_Falling']
                if g.get(platform,'code')==g.s['Plat_FallingIntangible']:
                    released=True;break
            assert falling and released and not g.get(child,'code')
            assert not g.get('v_player2','obControl')
            g.video.save(args.output/('falling-conveyor-%X-after.png'%profile))
            checks.append('falling conveyor/grip %X: delay, belt carry, hanging descent and release on intangible transition'%profile)

        # A grip must not turn full solidity into a free escape from crushing.
        # Put the real GHZ4 floor twelve pixels beneath the hanging feet; the
        # normal floor-release path runs before the descending body closes it.
        for family in ('regular','swing'):
            for profile in (6,7,8,9):
                for bottom in actors:
                    top='v_player2' if bottom=='v_player' else 'v_player'
                    g.restore(base);isolate(g);g.write('Tails_CPU_idle_timer',600,2)
                    g.write('Camera_X_pos',0x360,2);g.write('Camera_Y_pos',0x1D0,2);g.write('Camera_X_pos_coarse_back',0x300,2)
                    for actor in actors:place(g,actor,0x480,0x180);g.put(actor,'obControl',1)
                    settings=(profile<<8)|(0x1000 if family=='regular' else 0x1025)
                    parent=spawn(g,'Obj18' if family=='regular' else 'SwingingPtfm',0x400,0x180,settings)
                    field='Plat_hanger' if family=='regular' else 'swing_hanger'
                    for _ in range(8):
                        run()
                        if g.get(parent,field,2):break
                    child=g.get(parent,field,2);assert child
                    delta=terrain_floor[bottom]-(g.get(child,'obY',2)+36+g.get(bottom,'obHeight'))-12
                    g.put(parent,'obY',g.get(parent,'obY',2)+delta,2)
                    if family=='regular':
                        for name in ('Plat_rawY','Plat_originY'):g.put(parent,name,g.get(parent,name,2)+delta,2)
                    else:g.put(parent,'swing_orig_y',g.get(parent,'swing_orig_y',2)+delta,2)
                    run(2)
                    place(g,bottom,g.get(child,'obX',2),g.get(child,'obY',2)+30)
                    place(g,top,g.get(parent,'obX',2),g.get(parent,'obY',2)-g.get(parent,'obHeight')-g.get(top,'obHeight')+2)
                    g.put(top,'obVelY',0x100,2)
                    # Stars protect against damage, never against physical crushing.
                    g.put(bottom,'obStatusSecondary',2);g.put(bottom,'invtime',600,2)
                    run(5)
                    assert g.get(bottom,'obControl')==3,(family,profile,bottom,'pre-crush grip',terrain_floor,delta,g.get(parent,'obY',2),g.get(child,'obY',2),[(a,g.get(a,'obX',2),g.get(a,'obY',2),g.get(a,'obHeight'),g.get(a,'obStatus'),g.get(a,'obRoutine'),g.get(a,'obControl')) for a in actors])
                    if family=='swing':g.put(parent,'swing_mode_timer',29,2)
                    dead=False;landed=False
                    for _ in range(130):
                        run()
                        landed|=not g.get(bottom,'obStatus')&2 and not g.get(bottom,'obControl')
                        dead|=g.get(bottom,'obRoutine')>=6
                        if dead:break
                    assert dead==(profile in (7,9)),(family,profile,bottom,'crush',dead,landed,g.get(bottom,'obY',2),g.get(parent,'obY',2))
                    assert landed or dead,(family,profile,bottom,'never landed',g.get(bottom,'obControl'),g.get(bottom,'obRoutine'),g.get(bottom,'obX',2),g.get(bottom,'obY',2),g.get(parent,'obRoutine'),g.get(parent,'obY',2))
                    g.video.save(args.output/('crush-'+family+'-%X-'%profile+bottom+'.png'))
                    checks.append(family+' profile %X: '%profile+bottom+(' crushed against real floor despite stars' if profile in (7,9) else ' lands safely as top-only body passes'))

    (args.output/'game.json').write_text(json.dumps({'pal':args.pal,'player':args.player,'checks':checks},indent=2)+'\n')
    g.close();print('\n'.join('PASS '+row for row in checks))


if __name__=='__main__':main()
