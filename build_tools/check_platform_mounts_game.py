#!/usr/bin/env python3
"""Exercise mounted platform objects with the live object executor and renderer."""
import argparse
import json
from pathlib import Path
from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import place, isolate


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--system-directory', type=Path)
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, system_directory=args.system_directory)
    boot_level(g, zone=0, act=3, player=0)
    art = (Path(__file__).resolve().parents[1] / 'art/uncompressed/Platform button.unc').read_bytes()
    first = g.s['ArtTile_PlatformButton'] * 32
    assert bytes(g.vram[(first+i)^1] for i in range(len(art))) == art, 'portable button PLC upload'
    base = g.save()
    pool = list(range(g.s['v_lvlobjspace'] & 65535, g.s['v_lvlobjend'] & 65535, g.s['object_size']))
    checks = []

    def run(n=1):
        for _ in range(n):
            g.run()
            assert not g.read('v_errortype'), ('CPU exception', g.frame)

    def group(body):
        result = []
        child = g.get(body, 'PlatformMount_head', 2)
        while child:
            assert child not in result and len(result) < 2
            result.append(child)
            assert g.get(child, 'Mount_parent', 2) == body
            child = g.get(child, 'Mount_next', 2)
        return result

    def setup(setting, swing=False, earlier=False, word=None):
        g.restore(base); isolate(g)
        for a in pool: g.write(a, 0, g.s['object_size'])
        for who in ('v_player', 'v_player2'):
            place(g, who, 0x140, 0x210);g.put(who, 'obControl', 1)
        g.buttons2 = {4};g.write('Tails_CPU_idle_timer', 6000, 2)
        g.write('Camera_X_pos', 0x100, 2);g.write('Camera_Y_pos', 0x180, 2)
        root = pool[-5] if earlier else pool[0]
        for f,v,n in [('code',g.s['SwingingPtfm' if swing else 'Obj18'],4), ('obX',0x1A0,2),
                      ('obY',0x240,2), ('obSubtype',(0x2036 if swing else 0x21) if word is None else word,2),
                      ('PlatformMount_settings',setting,1)]:g.put(root,f,v,n)
        run(4)
        body = g.get(root, 'swing_body', 2) if swing else root
        assert body and g.get(body,'code')
        return root, body, group(body)

    # Each family follows a moving body after the parent updates, for either
    # allocation order. Animation still advances once per actual object update.
    for swing in (False, True):
        for earlier in (False, True):
            for setting in (1, 18, 21, 26):
                root,body,children = setup(setting,swing,earlier)
                assert len(children) == (2 if setting == 18 else 1)
                positions = set()
                for _ in range(100):
                    run();positions.add((g.get(body,'obX',2),g.get(body,'obY',2)))
                    assert group(body) == children
                    for child in children:
                        dx=g.get(child,'Mount_x',2);dx=dx-65536 if dx&32768 else dx
                        dy=g.get(child,'Mount_y',2);dy=dy-65536 if dy&32768 else dy
                        assert g.get(child,'obX',2) == g.get(body,'obX',2)+dx
                        assert g.get(child,'obY',2) == g.get(body,'obY',2)-g.get(body,'obHeight')+dy
                assert len(positions)>10, ('movement stopped',swing,earlier,setting)
    checks.append('16 full-frame moving payload groups: regular/swing, both SST orders and all four payload families')

    # Keep each art family in view for inspection, without changing its PLCs
    # or renderer. These stationary captures supplement the moving fixtures.
    for swing in (False,True):
        for setting in (1,18,21,26):
            root,body,children=setup(setting,swing,word=0x26 if swing else 0x20)
            x,y=g.get(body,'obX',2),g.get(body,'obY',2)
            for who in ('v_player','v_player2'):
                place(g,who,x-80,y-32);g.put(who,'obControl',1)
            g.write('Camera_X_pos',max(0,x-160),2);g.write('Camera_Y_pos',max(0,y-100),2)
            run(12)
            g.video.save(args.output / f'payload-{int(swing)}-{setting}.png')

    # Real landing, button animation/channel and standing ownership for either actor.
    for who in ('v_player','v_player2'):
        root,body,children=setup(16,word=0x10A0)
        child=children[0]
        other='v_player2' if who=='v_player' else 'v_player'
        place(g,other,g.get(child,'obX',2)-80,g.get(child,'obY',2)-30);g.put(other,'obControl',1)
        place(g,who,g.get(child,'obX',2),g.get(child,'obY',2)-g.get(who,'default_y_radius')-4)
        g.put(who,'obControl',1);g.put(who,'obVelY',0x100,2)
        run(8)
        assert g.read(g.s['f_switch']+15)&1 and g.get(child,'obFrame')==1, ('button landing',who, [(a,g.get(a,'obX',2),g.get(a,'obY',2),g.get(a,'obStatus'),g.get(a,'obRoutine'),g.get(a,'obControl')) for a in (who,body,child)])
        assert g.get(body,'Plat_flags')&8 and g.get(body,'Plat_sag')>0, ('mounted rider activation',who)
        g.video.save(args.output / f'button-rider-{who}.png')
        # Move away without deleting the body: real momentary release.
        place(g,who,0x140,0x180);g.put(who,'obControl',1);run(3)
        assert not g.read(g.s['f_switch']+15)&1
    checks.append('both actors land on channel-F button; payload rider arms falling/sag and stepping away releases channel')
    for who in ('v_player','v_player2'):
        root,body,children=setup(26,word=0x20)
        child=children[0];x,y=g.get(child,'obX',2),g.get(child,'obY',2)
        other='v_player2' if who=='v_player' else 'v_player'
        place(g,other,x-80,y-20);g.put(other,'obControl',1)
        place(g,who,x,y-80)
        for f,v,n in [('obStatus',6,1),('obAnim',g.s['AniIDSonAni_Roll'],1),
                      ('obHeight',14,1),('obWidth',7,1),('obVelY',0x100,2),
                      ('obStatusSecondary',0,1),('invtime',0,2)]:g.put(who,f,v,n)
        g.write('v_rings',40,2)
        run(100)
        assert g.get(child,'obRoutine')>=6 and g.get(body,'PlatformMount_flags')&2, ('monitor break',who)
        assert g.get(child,'obParent',2)==g.s[who]&65535, ('monitor collector',who)
        assert g.read('v_rings',2)==50, ('monitor reward',who,g.read('v_rings',2))
        g.video.save(args.output / f'monitor-break-{who}.png')
    checks.append('both actors roll into mounted monitors through live TouchResponse; correct collector, one ring reward and consumed body state')

    for who in ('v_player','v_player2'):
        root,body,children=setup(21,word=0x20)
        child=children[0];x,y=g.get(child,'obX',2),g.get(child,'obY',2)
        other='v_player2' if who=='v_player' else 'v_player'
        place(g,other,x-80,y-20);g.put(other,'obControl',1)
        place(g,who,x,y-16-g.get(who,'default_y_radius')+3)
        g.put(who,'obVelY',0x100,2);g.put(who,'obStatusSecondary',0);g.put(who,'invtime',0,2)
        g.write('v_rings',40,2)
        run(5)
        assert g.get(who,'obRoutine')==4, ('mounted spikes damage',who)
        assert g.read('v_rings',2)==(40 if who=='v_player2' else 0), ('ordinary shared-ring damage rule',who)
    checks.append('both actors take ordinary spike damage from the mounted S1 trio')

    g.close()
    (args.output/'game.json').write_text(json.dumps(checks,indent=2)+'\n')
    print('\n'.join('PASS '+check for check in checks))


if __name__ == '__main__':main()
