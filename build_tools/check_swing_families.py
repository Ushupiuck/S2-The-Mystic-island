#!/usr/bin/env python3
"""Exercise swing solidity/hurt families and the retained gray/blue switches.

Real 68000 object and touch routines verify both actors. Full-frame switch
fixtures use the real terrain, movement and momentary switch code.
"""
from pathlib import Path
import argparse
import ctypes as C
import json

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_companion_followup import spawn, place, isolate
from check_caterkiller import CpuPrefix

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--core', type=Path, required=True)
    p.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--pal', action='store_true')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
                system_directory=args.system_directory)
    boot_level(g, zone=8, player=0)
    atlas = (ROOT / 'art/uncompressed/SMZ Sprite Atlas.unc').read_bytes()
    first = g.s['ArtTile_SMZ_Atlas'] * 32
    assert bytes(g.vram[(first + i) ^ 1] for i in range(len(atlas))) == atlas, 'Atlas upload differs from source pixels'
    base = g.save()
    cpu = CpuPrefix.in_dll(g.core, 'm68k')
    g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
    g.core.m68k_run.argtypes = [C.c_uint]
    rows = []

    def act(label, obj):
        g.core.m68k_set_reg(17, 0x2700)
        g.core.m68k_set_reg(8, 0xFF0000 | (obj & 65535))
        g.write(0x7E00, 0xFF7F00, 4)
        g.write(0x7F00, 0x60FE, 2)
        g.core.m68k_set_reg(15, 0xFF7E00)
        g.core.m68k_set_reg(16, g.s[label])
        for _ in range(200000):
            if g.core.m68k_get_reg(16) == 0xFF7F00:
                return
            g.core.m68k_run(cpu.cycles + 1)
        raise AssertionError((label, hex(g.core.m68k_get_reg(16))))

    def record(case, passed, **details):
        row = dict(case=case, passed=bool(passed), **details)
        rows.append(row)
        assert passed, row

    for zone in (0,8):
        for profile in range(12):
            for who in ('v_player','v_player2'):
                for immune in (False,True):
                    g.restore(base);isolate(g);g.write('Current_Zone',zone)
                    obj=spawn(g,'SwingingPtfm',250,950,(profile<<8)|0x26)
                    act('SwingingPtfm',obj)
                    other='v_player2' if who=='v_player' else 'v_player'
                    g.put(other,'code',0)
                    x,y=g.get(obj,'obX',2),g.get(obj,'obY',2)
                    place(g,who,x,y-g.get(obj,'obHeight')-g.get(who,'default_y_radius')+3)
                    g.put(who,'obVelY',0x100,2)
                    g.put(who,'flashtime',0x100 if immune else 0,2)
                    g.put(who,'obStatusSecondary',0)
                    g.write('v_rings',40,2)
                    g.put(obj,'obRender',0x84)
                    g.put(g.get(obj,'swing_body',2),'obRender',0x84)
                    act('SwingingPtfm_Interact',obj)
                    standing=bool(g.get(who,'obStatus')&8)
                    record(f'top-{zone}-{profile}-{who}-{immune}',
                           standing==(profile!=10 and (profile!=11 or immune)))
                    record(f'damage-{zone}-{profile}-{who}-{immune}',
                           (g.get(who,'obRoutine')==4)==(profile>=10 and not immune))

    # Direct spike/platform damage runs outside the NPC touch scan. Neither
    # Debug placement nor frame cycling may mutate a character through it.
    for profile in (2,5,10,11):
        for who in ('v_player','v_player2'):
            for debug_type in (1,2):
                g.restore(base);isolate(g)
                obj=spawn(g,'SwingingPtfm_ArtBall',250,950,(profile<<8)|0x26)
                act('SwingingPtfm_ArtBall',obj)
                body=g.get(obj,'swing_body',2)
                other='v_player2' if who=='v_player' else 'v_player'
                g.put(other,'code',0)
                y=g.get(body,'obY',2)
                if profile in (2,5):
                    y+=g.get(body,'obHeight')+g.get(who,'default_y_radius')-3
                place(g,who,g.get(body,'obX',2),y)
                g.put(who,'obVelY',0xFF00 if profile in (2,5) else 0x100,2)
                g.put(who,'obStatusSecondary',1)
                g.put(obj,'obRender',0x84);g.put(body,'obRender',0x84)
                g.write('Debug_placement_mode',debug_type,2)
                fields=(('obX',4),('obY',4),('obVelX',2),('obVelY',2),
                        ('obRoutine',1),('obStatusSecondary',1),('flashtime',2))
                before=[g.get(who,f,n) for f,n in fields]
                act('SwingingPtfm_Interact',obj)
                record(f'debug-damage-{profile}-{who}-{debug_type}',
                       [g.get(who,f,n) for f,n in fields]==before)

    for who in ('v_player', 'v_player2'):
        g.restore(base)  # resume whole frames only from the original boundary
        isolate(g)
        other = 'v_player2' if who == 'v_player' else 'v_player'
        g.put(other, 'code', 0)
        obj = spawn(g, 'SMZ_Button', 250, 1152)
        place(g, who, 250, 1070)
        g.buttons2 = {4}  # keep companion control manual
        g.write('Tails_CPU_idle_timer', 600, 2)
        g.put(who, 'obVelY', 0x100, 2)
        g.write('Camera_X_pos', 0, 2)
        g.write('Camera_Y_pos', 1040, 2)
        pressed = False
        for _ in range(60):
            g.run()
            pressed |= g.get(obj, 'obFrame') == 1 and bool(g.read('f_switch') & 1)
        record('switch-press-' + who, pressed)
        g.video.save(args.output / ('switch-' + who + '.png'))
        place(g, who, 320, 1070)
        g.put(who, 'obControl', 1)
        g.run(5)
        record('switch-release-' + who,
               g.get(obj, 'obFrame') == 0 and not g.read('f_switch') & 1)

    # Whole frames cover real button entry, sustained overlap with a spiked
    # ball in SMZ2, and immediate damage after leaving either Debug mode.
    from check_debug_states import press_debug
    g.write('v_gamemode',g.s['SegaScreen'],2);g.run()
    boot_level(g,zone=8,act=1)
    smz2=g.save()
    for debug_type in (1,2):
        g.restore(smz2);isolate(g)
        g.put('v_player2','code',0)
        g.write('Debug_mode_flag',1)
        g.put('v_player','obStatusSecondary',1)
        g.put('v_player','flashtime',0,2)
        press_debug(g,debug_type)
        x,y=g.get('v_player','obX',2),g.get('v_player','obY',2)
        obj=spawn(g,'SwingingPtfm_ArtBall',x,y-104,0xA26)
        g.run()
        body=g.get(obj,'swing_body',2)
        untouched=True
        for _ in range(60):
            g.put('v_player','obX',g.get(body,'obX',2),2)
            g.put('v_player','obY',g.get(body,'obY',2),2)
            g.run()
            untouched &= (g.get('v_player','obRoutine')==2 and
                          not g.get('v_player','flashtime',2) and
                          bool(g.get('v_player','obStatusSecondary')&1))
            assert not g.read('v_errortype')
        record(f'debug-ball-frames-{debug_type}',untouched)
        g.video.save(args.output/f'debug-ball-{debug_type}.png')
        press_debug(g,0)
        g.run(3)
        record(f'debug-ball-exit-{debug_type}',
               g.get('v_player','obRoutine')==4 and
               bool(g.get('v_player','flashtime',2)) and
               not g.get('v_player','obStatusSecondary')&1)
    g.close()
    report = dict(region='PAL' if args.pal else 'NTSC', rows=rows)
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'{len(rows)} swing/switch contact checks passed ({report["region"]}).')


if __name__ == '__main__':
    main()
