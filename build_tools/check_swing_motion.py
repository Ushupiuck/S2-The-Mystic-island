#!/usr/bin/env python3
"""Execute Obj17 settings, S3&K motion, contact, relay and release regressions.

Optional pinned upstream source assembles the original SOZ/DEZ integrators.
Optional libretro fixtures run both actors in disposable GHZ4 scenes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import native_test_core as c
from object_layout import decode


def fixture(m, subtype, flip=0, full=False):
    m.start()
    pool = list(m.pool())
    if full:
        for obj in pool:
            m.put(obj, 'code', m.s['ObjNull'])
    obj = pool[0]
    m.write('Camera_X_pos_coarse_back', 0x1700, 2)
    for f,v,n in [('code',m.s['SwingingPtfm'],4),('obX',0x1800,2),('obY',0x400,2),
                  ('obSubtype',subtype,2),('obStatus',flip,1)]:
        m.put(obj,f,v,n)
    m.act('SwingingPtfm',obj)
    return obj


def physical(m, o):
    if m.get(o,'code')==m.s['SwingingPtfm']:
        pointer=m.get(o,'swing_body',2)
        return (pointer|0xFF0000) if pointer else 0
    return o


def visible(m,o,flags):
    m.put(o,'obRender',flags)
    body=physical(m,o)
    if body:m.put(body,'obRender',flags)


def position(m,o):
    return m.get(o,'obX',2),m.get(o,'obY',2)


def native(args):
    m=c.Manager(args.rom,args.listing)
    old=c.Manager(args.before_rom,args.before_listing) if args.before_rom else None
    checks=[]
    halves=0
    if old:
        for length in range(9):
            for flip in (0,1):
                o=fixture(m,0x10|length,flip)
                r=fixture(old,0x10|length,flip)
                for angle in list(range(129))+list(range(128,-1,-1)):
                    for machine in (m,old):
                        machine.cpu.mem_write((machine.s['v_oscillate']+0x1A)&0xFFFFFF,bytes([angle]))
                    m.act('SwingingPtfm_UpdateMotion',o)
                    old.act('SwingingPtfm_UpdateMotion',r)
                    assert position(m,o)==position(old,r),(length,flip,angle)
                    halves+=1
        checks.append(f'{halves} exact parent half-swing samples against previous ROM')
    rotations=0
    for length in range(9):
        for flip in range(4):
            for phase in range(4):
                sub=(phase<<14)|0x30|length
                o=fixture(m,sub,flip)
                first=position(m,o)
                for tick in range(257):
                    if tick:m.act('SwingingPtfm_UpdateMotion',o)
                    angle=tick&255
                    if flip&1:angle=128-angle
                    if flip&2:angle=-angle
                    angle=(angle+phase*64)&255
                    sine=struct.unpack('>h',bytes(m.cpu.mem_read(m.s['Sine_Data']+angle*2,2)))[0]
                    cosine=struct.unpack('>h',bytes(m.cpu.mem_read(m.s['Sine_Data']+angle*2+128,2)))[0]
                    expected=(0x1800+((cosine*(length*16+8))>>8),0x400+((sine*(length*16+8))>>8))
                    assert position(m,o)==expected,(length,flip,phase,tick,position(m,o),expected)
                    rotations+=1
                assert position(m,o)==first
                assert m.get(o,'obSubtype')==sub
    checks.append(f'{rotations} exact rotated/mirrored poses and 256-update periods')
    # Invalid lengths never become packed records; all setting words survive.
    for profile in range(16):
        for mode in range(8):
            sub=0xF080|(profile<<8)|(mode<<4)|15
            o=fixture(m,sub)
            h=m.get(o,'swing_helper_ptr',4)&0xFFFFFF
            assert m.get(o,'obSubtype')==sub
            assert m.get(h,'mainspr_childsprites')==8
            assert m.get(h+m.s['object_size'],'code')==0
    for sub in (6,0x36,0x46,0xF086):
        o=fixture(m,sub,full=True)
        assert not m.get(o,'swing_helper_ptr',4)
        m.act('SwingingPtfm_UpdateMotion',o)
        m.act('SwingingPtfm_DelAll',o)
        assert not m.get(o,'code')
    checks.append('128 independent constructors; reserved lengths and interactions; full-pool/null-helper boundaries')

    # The body may occupy an earlier slot. Its own executor must not apply a
    # competing movement, and the parent must update it exactly once after pose.
    m.start();pool=list(m.pool());o=pool[10]
    for a in pool:
        if a not in (pool[0],pool[1],o):m.put(a,'code',m.s['ObjNull'])
    m.write('Camera_X_pos_coarse_back',0x1700,2)
    for f,v,n in [('code',m.s['SwingingPtfm'],4),('obX',0x1800,2),('obY',0x400,2),('obSubtype',0x36,2)]:m.put(o,f,v,n)
    m.act('SwingingPtfm',o);b=physical(m,o)
    assert b&0xFFFFFF==pool[0]&0xFFFFFF
    assert m.get(o,'swing_helper_ptr',4)&0xFFFFFF==pool[1]&0xFFFFFF
    word=0x40A2
    m.put(b,'obSubtype',word);m.put(b,'Plat_movement',m.s['Plat_Horizontal128'],4)
    m.put(b,'Plat_originX',0x100,2);m.put(b,'Plat_flags',0x11)
    m.put('v_player2','code',0)
    x,y=position(m,b)
    for f,v,n in [('obX',x,2),('obY',y-8-19,2),('obStatus',8,1),('standonobject',(b-(m.s['v_objspace']&0xFFFFFF))//m.s['object_size'],1)]:m.put('v_player',f,v,n)
    m.put(b,'obStatus',8);visible(m,o,0x94)
    for _ in range(80):
        before=position(m,b);m.act('Platform_SuspendedBody',b);assert position(m,b)==before
        m.act('SwingingPtfm_SetSolid',o)
        assert m.get(b,'obSubtype')==word
        assert m.get(b,'obX',2)==m.get(o,'obX',2)
        assert 0<=m.get(b,'obY',2)-m.get(o,'obY',2)<=4
    assert m.get(b,'obY',2)-m.get(o,'obY',2)==4
    m.act('SwingingPtfm_DelAll',o);assert not m.get(b,'code')
    checks.append('earlier body slot: one parent-driven update, own horizontal motion paused, complete word retained and rider sag applied')

    # A reused packed-helper SST must never receive chain-coordinate writes.
    o=fixture(m,0x36);h=m.get(o,'swing_helper_ptr',4)&0xFFFFFF
    m.put(h,'code',m.s['ObjNull']);guard=bytes(m.cpu.mem_read(h,m.s['object_size']))
    m.act('SwingingPtfm_UpdateMotion',o)
    assert bytes(m.cpu.mem_read(h,m.s['object_size']))==guard
    assert not m.get(o,'swing_helper_ptr',4)
    m.act('SwingingPtfm_DelAll',o);assert m.get(h,'code')==m.s['ObjNull']
    checks.append('reused helper is protected from pose writes and group deletion')

    for released in (False,True):
        o=fixture(m,0x1026);b=physical(m,o)
        if released:
            m.put(o,'obStatus',8);m.put(o,'swing_mode_timer',30,2)
            m.act('SwingingPtfm_DetachCheck',o)
            assert m.get(b,'obRoutine')==10
        m.act('DeleteObject',o);m.act('Platform_SuspendedBody',b)
        assert not m.get(b,'code')
    o=fixture(m,0x26);b=physical(m,o)
    m.put(b,'code',m.s['ObjNull']);guard=bytes(m.cpu.mem_read(b,m.s['object_size']))
    m.act('SwingingPtfm_Interact',o);m.act('SwingingPtfm_DelAll',o)
    assert bytes(m.cpu.mem_read(b,m.s['object_size']))==guard
    checks.append('attached/released orphan bodies retire; reused body slots survive old-parent interaction and cleanup')

    contacts=0
    for kind in ('swing', 'ordinary'):
        for profile in range(12):
            for who,other in [('v_player','v_player2'),('v_player2','v_player')]:
                for inv in (0,0x100,-1):
                    def body():
                        if kind == 'swing':
                            return fixture(m,(profile<<8)|0x26), 'SwingingPtfm_Interact'
                        m.start();o=next(iter(m.pool()))
                        m.write('Camera_X_pos_coarse_back',0x1700,2)
                        for f,v,n in [('code',m.s['Obj18'],4),('obSubtype',profile<<8,2),('obX',0x1800,2),('obY',0x400,2)]:m.put(o,f,v,n)
                        m.act('Obj18',o)
                        return o,'Plat_Top'
                    for side in ('top','bottom','side'):
                        o,entry=body();m.put(other,'code',0)
                        x,y=position(m,o);height=m.get(o,'obHeight')
                        m.put(who,'obX',x+(m.get(o,'obActWid')+6 if side=='side' else 0),2)
                        m.put(who,'obY',y-height-19+3 if side=='top' else y+height+14 if side=='bottom' else y,2)
                        m.put(who,'obVelY',0x100 if side=='top' else 0xFF00,2);m.put(who,'obStatus',2)
                        m.put(who,'flashtime',max(0,inv),2);m.put(who,'obStatusSecondary',2 if inv<0 else 0)
                        m.write('v_rings',40,2);visible(m,o,0x94)
                        m.act(entry,o)
                        hurt=(profile>=10 or (side=='bottom' and profile in (2,5))) and not inv
                        assert (m.get(who,'obRoutine')==4)==hurt,(kind,side,profile,who,inv,'damage')
                        if side=='top':
                            standing=bool(m.get(who,'obStatus')&8)
                            assert standing==(profile!=10 and (profile!=11 or bool(inv))),(kind,profile,who,inv,'standing')
                        elif side=='bottom' and not hurt and profile not in (6,7,8,9):
                            assert m.get(who,'obVelY',2)==(0xFF00 if profile in (0,3,10) else 0),(kind,profile,who,inv,'underside')
                        elif side=='side' and not hurt:
                            assert (m.get(who,'obX',2)>x+m.get(o,'obActWid')+6)==(profile in (1,2,4,5,7,9,11)),(kind,profile,who,inv,'side solidity')
                        contacts+=1
    checks.append(f'{contacts} native contacts: both objects, twelve shared profiles, both players, word flash and stars')

    belts=0
    for kind in ('swing','ordinary'):
        for profile in (3,4,5,8,9):
            for flip in (0,1):
                if kind=='swing':o=fixture(m,(profile<<8)|0x26,flip);entry='SwingingPtfm_Interact'
                else:
                    m.start();o=next(iter(m.pool()));m.write('Camera_X_pos_coarse_back',0x1700,2)
                    for f,v,n in [('code',m.s['Obj18'],4),('obSubtype',profile<<8,2),('obStatus',flip,1),('obX',0x1800,2),('obY',0x400,2)]:m.put(o,f,v,n)
                    m.act('Obj18',o);entry='Plat_Top'
                x,y=position(m,o);radius=m.get(o,'obHeight')
                for who in ('v_player','v_player2'):
                    m.put(who,'obX',x,2);m.put(who,'obY',y-radius-19+2,2);m.put(who,'obVelY',0x100,2);m.put(who,'obStatus',2)
                visible(m,o,0x94);m.act(entry,o)
                for who in ('v_player','v_player2'):
                    assert m.get(who,'obX',2)==x+(-2 if flip else 2),(kind,profile,who,'belt direction')
                    assert m.get(who,'conveyor_applied')==1
                m.act(entry,o)
                for who in ('v_player','v_player2'):assert m.get(who,'obX',2)==x+(-2 if flip else 2),'duplicate conveyor push'
                belts+=1
    checks.append(f'{belts} conveyor combinations: both objects, both riders/directions, hanging included, no duplicate push')

    # Momentum must originate at the rail, with the expected speed threshold,
    # input scaling and either-player support. Geometry calls are stubbed only
    # for the isolated angular integration below; libretro uses real terrain.
    for who,other in [('v_player','v_player2'),('v_player2','v_player')]:
        for flip in (0,1):
            reaches=[]
            for speed in (0x100,0x200,0x400,0x800):
                o=fixture(m,0x46,flip);m.put(other,'code',0)
                x,y=position(m,o)
                m.put(who,'obX',x+(-16 if flip else 16),2)
                m.put(who,'obY',y-8-19,2)
                m.put(who,'obVelX',(-speed if flip else speed)&65535,2)
                m.act('Platform_SwingMomentumInput',o)
                assert bool(m.get(o,'swing_mode_started'))==(speed>=0x200)
                peak=0
                # Stub returns a clear wall while retaining the real momentum
                # and position code. Save/restore it around this one test.
                address=m.s['Platform_BodyWall'];saved=bytes(m.cpu.mem_read(address,4))
                m.cpu.mem_write(address,bytes.fromhex('727F4E75'))
                for tick in range(150):
                    m.act('SwingingPtfm_UpdateMotion',o)
                    peak=max(peak,m.get(o,'obAngle',2))
                m.cpu.mem_write(address,saved)
                reaches.append(peak)
                assert not m.get(o,'swing_mode_started')
                assert m.get(o,'obAngle',2)==0
            assert reaches==sorted(reaches) and len(set(reaches))==4,reaches
    checks.append('either-player ICZ rail: mirrored speed threshold, scaled excursion, gravity return')

    # Release needs no allocation and retains the original physical SST.
    o=fixture(m,0x1026);child=physical(m,o)
    m.put(o,'obStatus',8)
    for a in m.pool():
        if not m.get(a,'code'):m.put(a,'code',m.s['ObjNull'])
    before=[m.get(a,'code') for a in m.pool()]
    m.put(o,'swing_mode_timer',30,2);m.put(o,'respawn_addr',1,2);m.put(child,'obStatus',8)
    m.put('v_player','obStatus',8)
    stand=(child-(m.s['v_objspace']&0xFFFFFF))//m.s['object_size']
    m.put('v_player','standonobject',stand)
    m.act('SwingingPtfm_DetachCheck',o)
    assert m.get(o,'obRoutine')==4 and m.get(child,'obRoutine')==10
    assert physical(m,o)==child and m.get(child,'code')==m.s['Platform_SuspendedBody']
    assert m.get(o,'respawn_addr',2)==1 and m.get(child,'respawn_addr',2)==0
    assert m.get('v_player','standonobject')==stand
    assert [m.get(a,'code') for a in m.pool()]==before
    m.act('SwingingPtfm_DelAll',o)
    assert not m.get(child,'code') and not m.get(o,'code')
    checks.append('full-pool detachment: same Obj18 SST, same standing index, no allocation/copy, sole placement owner and cleanup')
    o=fixture(m,0x1048)
    h=m.get(o,'swing_helper_ptr',4)&0xFFFFFF
    m.put(o,'obAngle',0x4900,2);m.put(o,'swing_ang_vel',0x300,2)
    m.put(o,'swing_mode_started',1)
    m.act('SwingingPtfm_DetachCheck',o)
    child=m.get(o,'swing_body',2)|0xFF0000
    assert m.get(child,'obVelX',2)==0x400 and m.get(child,'obVelY',2)==0xFA00
    assert m.get(h,'code')==m.s['SwingingPtfm_ChainDebris']
    assert not m.get(o,'swing_helper_ptr',4) and m.get(o,'ob2ndRout')==1
    for tick in range(60):m.act('SwingingPtfm_ChainDebris',h)
    assert not m.get(h,'code')
    checks.append('ICZ breakaway launch; packed eight-link breakup expires without extra SSTs')
    for flip in (0,1):
        o=fixture(m,0x1016,flip)
        m.put(o,'obStatus',flip|8)
        m.cpu.mem_write((m.s['v_oscillate']+0x1A)&0xFFFFFF,bytes([0]))
        m.act('SwingingPtfm_DetachCheck',o)
        assert m.get(o,'obRoutine')==4,('half release',flip)
    checks.append('both detachable half-swings release at the original oscillator endpoint')
    o=fixture(m,0x26)
    m.put(o,'obStatus',8);m.put(physical(m,o),'obStatus',8);m.put('v_player','obStatus',8)
    m.put('v_player','standonobject',(physical(m,o)-(m.s['v_objspace']&0xFFFFFF))//m.s['object_size'])
    m.act('SwingingPtfm_DelAll',o)
    assert m.get('v_player','obStatus')&0xA==2
    checks.append('unloading an attached platform releases its actual rider')




    # Relay forwarding uses actual body contact, not nearest-object searches.
    o=fixture(m,0x2020)
    h=m.get(o,'swing_helper_ptr',4)
    # Make a second stationary receiver then an ICZ receiver, all touching.
    members=[o]
    for index,sub in enumerate((0x2020,0x2040),1):
        a=next(a for a in m.pool() if not m.get(a,'code'))
        for f,v,n in [('code',m.s['SwingingPtfm'],4),('obSubtype',sub,2),('obX',0x1800+index*40,2),('obY',0x400,2)]:m.put(a,f,v,n)
        m.act('SwingingPtfm',a);members.append(a)
    m.put(o,'swing_impulse',0x600,2)
    fixed=[position(m,a) for a in members[:2]]
    m.act('SwingingPtfm_Relay',o)
    assert m.get(members[1],'swing_impulse',2)==0x600
    m.act('SwingingPtfm_Relay',members[1])
    assert m.get(members[2],'swing_impulse',2)==0x600
    m.act('SwingingPtfm_Relay',members[2])
    assert m.get(members[2],'swing_ang_vel',2)==0x300
    assert not m.get(o,'swing_impulse',2)
    assert fixed==[position(m,a) for a in members[:2]]
    receiver=members[2]
    address=m.s['Platform_BodyWall'];saved=bytes(m.cpu.mem_read(address,4))
    m.cpu.mem_write(address,bytes.fromhex('727F4E75'))
    for tick in range(150):m.act('SwingingPtfm_UpdateMotion',receiver)
    m.cpu.mem_write(address,saved)
    assert m.get(receiver,'swing_mode_started')==0

    checks.append('contact relay through stationary member into ICZ; no feedback or stationary motion')
    assert m.s['object_size']==0x4E and m.s['obSubtype']==0x2C
    if args.s3_source:checks+=compare_upstream(m,args)
    return dict(checks=checks)


def compare_upstream(m,args):
    raw=args.s3_source.read_bytes()
    assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()=='0f10a373ff0e3d5c0033ed7d13c678bcb927c7b0'
    source=raw.decode()
    origin=0x3C0000;ref=0xFF7000
    blocks=[]
    for first in ('sub_41636','sub_4757A'):
        start=source.index('\n'+first+':')+1
        end=source.index('; End of function '+first,start)
        blocks.append(source[start:end])
    header=f'''\tcpu 68000
\torg ${origin:X}
angle equ $26
status equ $2A
p1_standing_bit equ 3
Debug_placement_mode equ ${m.s['Debug_placement_mode']&0xFFFFFF:X}
signextendB function n,n
sfx_GravityLift equ 1
Play_SFX equ ${origin+0x1000:X}
'''
    path=args.output/'s3-lift-reference.asm';path.write_text(header+'\n'.join(blocks)+f'\n\torg ${origin+0x1000:X}\n\trts\n')
    asl=c.ROOT/'build_tools/Linux-x86_64/asl';p2bin=c.ROOT/'build_tools/Linux-x86_64/p2bin'
    subprocess.run([str(asl),'-xx','-n','-q','-A','-L','-U','-E','-i','.',str(path)],check=True)
    subprocess.run([str(p2bin),str(path.with_suffix('.p')),str(path.with_suffix('.bin'))],check=True)
    symbols={n:int(v,16) for n,v in re.findall(r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',path.with_suffix('.lst').read_text())}
    m.s.update({'Ref_'+n:v for n,v in symbols.items()})
    m.cpu.mem_write(origin,path.with_suffix('.bin').read_bytes()[origin:])
    samples=0
    for mode,label in [(5,'sub_41636'),(6,'sub_4757A')]:
        for standing in (8,16,24):
            o=fixture(m,(mode<<4)|6)
            m.cpu.mem_write(ref,bytes(0x50))
            m.cpu.mem_write(ref+0x26,struct.pack('>H',0x4000 if mode==5 else 0))
            for tick in range(1400):
                mask=standing if tick<300 or 800<=tick<900 else 0
                m.put(o,'obStatus',mask)
                m.cpu.mem_write(ref+0x2A,bytes([8 if mask else 0]))
                m.act('SwingingPtfm_UpdateMotion',o)
                m.act('Ref_'+label,ref)
                for own,offset,size in [('obAngle',0x26,2),('swing_ang_vel',0x32,2),('swing_mode_timer',0x34,2),('swing_mode_started',0x31,1),('swing_dir_flag',0x30,1)]:
                    expected=int.from_bytes(m.cpu.mem_read(ref+offset,size),'big')
                    assert m.get(o,own,size)==expected,(mode,standing,tick,own,m.get(o,own,size),expected)
                samples+=1
    return [f'{samples} SOZ/DEZ state samples against unchanged assembled S3&K integrators; either-rider adaptation']


def game(args):
    from genesis_test_core import Genesis
    from check_object_course import boot_level
    from check_companion_followup import place, isolate
    g = Genesis(args.core, args.rom, args.listing, args.output / 'game', args.pal,
                system_directory=args.system_directory)
    boot_level(g, zone=0, act=3, player=0)
    base = g.save()
    pool = list(range(g.s['v_lvlobjspace'] & 65535, g.s['v_lvlobjend'] & 65535, g.s['object_size']))
    rows = []
    for subtype, flips in ((0x16, (0, 1)), (0x36, (0,)), (0x4036, (1,))):
        g.restore(base)
        isolate(g)
        for a in pool:
            g.write(a, 0, g.s['object_size'])
        for actor in ('v_player', 'v_player2'):
            place(g, actor, 400, 540)
            g.put(actor, 'obControl', 1)
        g.write('Camera_X_pos', 250, 2)
        g.write('Camera_Y_pos', 480, 2)
        objects = pool[:len(flips)]
        for obj, flip in zip(objects, flips):
            for field, value, size in (('code', g.s['SwingingPtfm'], 4),
                                       ('obX', 400, 2), ('obY', 600, 2),
                                       ('obSubtype', subtype, 2), ('obStatus', flip, 1)):
                g.put(obj, field, value, size)
        g.buttons2 = {4}
        g.write('Tails_CPU_idle_timer', 6000, 2)
        positions = [set() for _ in objects]
        for frame in range(540):
            g.run()
            assert not g.read('v_errortype')
            for n, obj in enumerate(objects):
                assert g.get(obj, 'code') == g.s['SwingingPtfm']
                positions[n].add((g.get(obj, 'obX', 2), g.get(obj, 'obY', 2)))
            if len(objects) == 1 and frame == 2:
                obj = objects[0]
                x, y = g.get(obj, 'obX', 2), g.get(obj, 'obY', 2)
                for actor, dx in (('v_player', -4), ('v_player2', 4)):
                    place(g, actor, x + dx, y - 8 - g.get(actor, 'obHeight') + 3)
                    g.put(actor, 'obVelY', 0x300, 2)
                    g.put(actor, 'obControl', 1)
                g.put(obj, 'obRender', g.get(obj, 'obRender') | 0x80)
            if len(objects) == 1 and frame > 6:
                assert g.get(objects[0], 'obStatus') & 0x18 == 0x18, ('rider lost', subtype, frame)
            if len(objects) == 2 and frame > 2:
                assert any(g.get(obj, 'obY', 2) == 704 for obj in objects), 'Both logs left the waiting position'
            if frame in (30, 90, 180, 270):
                g.video.save(args.output / 'game' / f'motion-{subtype:04X}-{frame}.png')
        assert all(len(points) > 30 for points in positions)
        rows.append(dict(subtype=subtype, flips=flips, distinct_positions=[len(p) for p in positions]))
    g.close()
    return rows



def extended_game(args):
    from genesis_test_core import Genesis
    from check_object_course import boot_level
    from check_companion_followup import place,isolate
    g=Genesis(args.core,args.rom,args.listing,args.output/'extended-game',args.pal,system_directory=args.system_directory)
    boot_level(g,zone=0,act=3,player=0)
    base=g.save();pool=list(range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']))
    checks=[]
    def setup(sub,x=400,y=600):
        g.restore(base);isolate(g)
        for a in pool:g.write(a,0,g.s['object_size'])
        for who in ('v_player','v_player2'):
            place(g,who,x-80,y-100);g.put(who,'obControl',1)
        g.buttons2={4};g.write('Tails_CPU_idle_timer',6000,2)
        g.write('Camera_X_pos',max(0,x-160),2);g.write('Camera_Y_pos',max(0,y-120),2)
        o=pool[0]
        for f,v,n in [('code',g.s['SwingingPtfm'],4),('obX',x,2),('obY',y,2),('obSubtype',sub,2)]:g.put(o,f,v,n)
        for _ in range(6):
            run(1)
            if g.get(o,'obRoutine')==2:break
        assert g.get(o,'obRoutine')==2,('constructor did not execute',sub)
        return o
    def run(n=1):
        for _ in range(n):
            g.run();assert not g.read('v_errortype'),('exception',g.core.m68k_get_reg(16))
    def board(o,who,dx=0):
        x,y=g.get(o,'obX',2),g.get(o,'obY',2)
        place(g,who,x+dx,y-g.get(o,'obHeight')-g.get(who,'default_y_radius')+2)
        g.put(who,'obControl',1);g.put(who,'obVelY',0x100,2)
        g.put(o,'obRender',g.get(o,'obRender')|128)
    for mode in (5,6):
        for phase in range(4):
            for rider,bit in [('v_player',8),('v_player2',16)]:
                o=setup((phase<<14)|(mode<<4)|5)
                initial=g.get(o,'obAngle',2)
                board(o,rider)
                for _ in range(8):
                    run()
                    if g.get(o,'obStatus')&bit:break
                assert g.get(o,'obStatus')&bit,('board',mode,phase,rider)
                paused=False
                for tick in range(450):
                    run()
                    assert g.get(o,'obStatus')&bit,('rider lost',mode,phase,rider,tick)
                    if g.get(o,'swing_mode_timer',2)==30:
                        paused=True;break
                assert paused,('no endpoint pause',mode,phase,rider)
                endpoint=(g.get(o,'obX',2),g.get(o,'obY',2))
                run(40)
                assert g.get(o,'swing_mode_timer',2)==30 and endpoint==(g.get(o,'obX',2),g.get(o,'obY',2))
                place(g,rider,160,540);g.put(rider,'obControl',1)
                # Releasing both actors must allow the held endpoint timer to run.
                for tick in range(450):
                    run()
                    if not g.get(o,'swing_mode_started') and g.get(o,'obAngle',2)==initial:break
                else:raise AssertionError(('lift never returned',mode,phase,rider))
                if phase==0:g.video.save(args.output/'extended-game'/f'lift-{mode}-{rider}.png')
                checks.append(dict(case='lift',mode=mode,phase=phase,rider=rider))
    for who in ('v_player','v_player2'):
        for speed in (0x200,0x800):
            o=setup(0x45)
            board(o,who,16)
            g.put(who,'obVelX',speed,2);g.put(who,'obInertia',speed,2)
            run(2)
            assert g.get(o,'swing_mode_started'),('no ICZ input',who,speed)
            peak=0;ride=0
            for tick in range(150):
                run();peak=max(peak,g.get(o,'obAngle',2));ride+=bool(g.get(o,'obStatus')&(8 if who=='v_player' else 16))
            assert not g.get(o,'swing_mode_started') and peak>0 and ride>100,(who,speed,peak,ride)
            g.video.save(args.output/'extended-game'/f'momentum-{who}-{speed:X}.png')
            checks.append(dict(case='momentum',rider=who,speed=speed,peak=peak,ride_updates=ride))
    for sub in (0x1005,0x1045):
        o=setup(sub)
        board(o,'v_player',16 if sub==0x1045 else 0)
        if sub==0x1045:
            g.put('v_player','obVelX',0x800,2);g.put('v_player','obInertia',0x800,2)
        released=False;body=0
        for tick in range(360):
            run()
            if g.get(o,'obRoutine')==4:
                body=g.get(o,'swing_body',2)
                released=True;break
        assert released and body and g.get(body,'code')==g.s['Platform_SuspendedBody'],('release',sub)
        assert not g.get(body,'respawn_addr',2)
        run(75)
        assert g.get('v_player','obRoutine')<6
        g.video.save(args.output/'extended-game'/f'release-{sub:04X}.png')
        checks.append(dict(case='release',subtype=sub,body=body))
    # The real GHZ4 arch stops an outward ICZ swing until its momentum
    # dissipates. Initial impulse is fixture state; no wall routine is patched.
    o=setup(0x46,x=0x1000,y=0x300)
    g.put(o,'swing_mode_started',1);g.put(o,'swing_ang_vel',0x400,2)
    held=0
    for tick in range(240):
        angle=g.get(o,'obAngle',2)
        run()
        velocity=g.get(o,'swing_ang_vel',2)
        if angle==g.get(o,'obAngle',2) and 0<velocity<0x8000:
            held+=1
            if held==10:g.video.save(args.output/'extended-game'/'momentum-wall.png')
    assert held>=20 and not g.get(o,'swing_mode_started'),('wall hold/return',held)
    checks.append(dict(case='momentum-wall',held_updates=held,returned=True))
    # Same real GHZ4 floor: dry bounce/slide, water above it, and floor above
    # water. These fixtures exercise actual cartridge/CD terrain services.
    for water in (None,0x300,0x380):
        controller=setup(0x26,x=0x400,y=0x280)
        o=physical(g,controller)&65535
        g.put(controller,'obRoutine',4)
        g.put(o,'Plat_flags',g.get(o,'Plat_flags')&~16)
        g.put(o,'obRoutine',10);g.put(o,'obVelX',0,2);g.put(o,'obVelY',0x300,2)
        g.write('Water_flag',int(water is not None))
        if water is not None:
            for label in ('v_waterpos1','v_waterpos2','v_waterpos3'):g.write(label,water,2)
        floated=bounced=landed=False
        for tick in range(180):
            run();assert g.get(o,'code'), ('body unloaded',water,tick,g.read('Camera_X_pos',2))
            floated|=g.get(o,'obRoutine')==12
            bounced|=bool(g.get(o,'obVelY',2)&0x8000)
            landed|=g.get(o,'Plat_state')==1
        assert floated==(water==0x300),(water,floated,bounced,landed,g.get(o,'obY',2))
        if water!=0x300:assert bounced and landed
        g.video.save(args.output/'extended-game'/f'detached-water-{water}.png')
        checks.append(dict(case='environment',water=water,floated=floated,bounced=bounced,landed=landed))
    g.close();return checks


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom',type=Path,default=c.ROOT/'s2built.bin')
    p.add_argument('--listing',type=Path,default=c.ROOT/'md-main.lst')
    p.add_argument('--before-rom',type=Path)
    p.add_argument('--before-listing',type=Path)
    p.add_argument('--s3-source',type=Path)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--core',type=Path)
    p.add_argument('--system-directory',type=Path)
    p.add_argument('--pal',action='store_true')
    p.add_argument('--game-part',choices=('basic','extended'),help=argparse.SUPPRESS)
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    if args.game_part:
        result=game(args) if args.game_part=='basic' else extended_game(args)
        (args.output/(args.game_part+'-game.json')).write_text(json.dumps(result,indent=2)+'\n')
        print(args.game_part+' game fixtures passed')
        return
    report=native(args)
    if args.core:
        # This core cannot reliably unload/reload a cartridge in one process.
        # Give each suite one core lifetime; game code is never patched.
        for part,key in [('basic','game'),('extended','extended_game')]:
            command=[sys.executable,str(Path(__file__).resolve()),'--rom',str(args.rom.resolve()),
                     '--listing',str(args.listing.resolve()),'--core',str(args.core.resolve()),
                     '--output',str(args.output.resolve()),'--game-part',part]
            if args.pal:command+=['--pal']
            if args.system_directory:command+=['--system-directory',str(args.system_directory.resolve())]
            subprocess.run(command,check=True)
            report[key]=json.loads((args.output/(part+'-game.json')).read_text())
    (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
