#!/usr/bin/env python3
"""Check companion pursuit and lost rings at the real $800 wrapping seam.

Native checks isolate assembled movement/timer code. The optional GX fixture
enters SMZ2's authored 50-ring transporter, then stages repeated companion
recoveries with normal game updates. --probe records failures in an old ROM.
"""
from pathlib import Path
import argparse
import json
import struct
from native_test_core import Native, UC_M68K_REG_A1, UC_HOOK_CODE


def native_checks(args):
    m = Native(args.rom, args.listing)
    failures = []
    wrap = m.s['Level_YWrapMask']+1
    samples = 0
    for enabled in (False, True):
        for source in (0, 4, 0x30, wrap-0x30, wrap-8, wrap-4):
            for target in (0, 4, 0x30, wrap-0x30, wrap-8, wrap-4):
                m.start()
                m.write('Camera_Min_Y_pos', 0xFF00 if enabled else 0, 2)
                a, b = m.s['v_player2'], m.s['v_player']
                for actor in (a, b):
                    m.put(actor, 'obX', 0x1000, 2)
                    m.put(actor, 'obY', target, 2)
                m.put(a, 'obY', source, 2)
                m.put(a, 'obRender', 0x80)
                history = struct.pack('>HH', 0x1000, target)*64
                m.cpu.mem_write(m.s['Sonic_Pos_Record_Buf'] & 0xFFFFFF, history)
                m.act('Tails_FlySwim_Unknown', a, {UC_M68K_REG_A1:b})
                dy = source-target
                if enabled:
                    dy = (dy+wrap//2) % wrap-wrap//2
                step = min(abs(dy)//16+1, 6) * (-1 if dy>0 else 1) if dy else 0
                actual = (m.get(a, 'obY', 2)-source+32768) % 65536-32768
                if actual != step:
                    failures.append(dict(case='flight-step',wrap=enabled,source=source,
                                         target=target,expected=step,actual=actual))
                samples += 1
    m.cpu.mem_write(m.s['DisplaySprite'], bytes.fromhex('4E75'))
    displayed=[]
    m.cpu.hook_add(UC_HOOK_CODE,lambda cpu,address,size,data:
                   displayed.append(True) if address==m.s['DisplaySprite'] else None)
    for vx in (0, 0x80, 0x100, 0x380, 0xFC80):
        for vy, y in ((0x400, wrap-4), (0xFC00, 4)):
            m.start()
            a = m.s['v_lvlobjspace']
            for field,value,size in (('code',m.s['Obj13'],4),('obRoutine',2,1),
                                     ('obX',0x1000,2),('obY',y,2),
                                     ('obVelX',vx,2),('obVelY',vy,2),('obDelayAni',255,1)):
                m.put(a,field,value,size)
            m.write('Camera_Min_Y_pos', 0xFF00, 2)
            for tick in range(1,256):
                displayed.clear()
                m.act('Obj13',a)
                live = bool(m.get(a,'code',4))
                good = live == (tick<255)
                if live:
                    good &= m.get(a,'obDelayAni') == 255-tick and m.get(a,'obY',2)<wrap
                    remaining=255-tick
                    good &= bool(displayed)==(remaining>80 or not remaining&1)
                if not good:
                    failures.append(dict(case='ring-motion/lifetime',vx=vx,vy=vy,tick=tick,
                                         y=m.get(a,'obY',2),timer=m.get(a,'obDelayAni'),live=live))
                    break
    m.start()
    a = m.s['v_lvlobjspace']
    m.put(a,'code',m.s['Obj13'],4);m.put(a,'obX',0x1000,2);m.put(a,'obY',0x300,2)
    m.write('v_rings',32,2);m.write('Camera_Max_Y_pos',0x720,2)
    m.act('Obj13',a)
    rings = [p for p in range(m.s['v_lvlobjspace'],m.s['v_lvlobjend'],m.s['object_size'])
             if m.get(p,'code',4)==m.s['Obj13']]
    if len(rings)!=32 or any(m.get(p,'obDelayAni') != (254 if p==a else 255) for p in rings):
        failures.append(dict(case='all-32-ring-timers',count=len(rings),
                             timers=[m.get(p,'obDelayAni') for p in rings]))
    # A collected lost ring still awards once and finishes the sparkle path.
    m.put(a,'obRoutine',4);m.act('Obj13',a)
    if m.read('v_rings',2)!=1 or m.get(a,'obRoutine')!=6:
        failures.append(dict(case='lost-ring-collection'))
    for _ in range(60):
        if not m.get(a,'code',4):break
        m.act('Obj13',a)
    if m.get(a,'code',4):failures.append(dict(case='collected-ring-sparkle-expiry'))
    # Ordinary levels still cull rings below their lower boundary.
    m.start();m.put(a,'code',m.s['Obj13'],4);m.put(a,'obRoutine',2)
    m.put(a,'obY',0x500,2);m.put(a,'obDelayAni',255)
    m.write('Camera_Max_Y_pos',0x300,2);m.act('Obj13',a)
    if m.get(a,'code',4): failures.append(dict(case='non-wrapping-bottom-cull'))
    return dict(flight_samples=samples,ring_lifetime_cases=10,scatter_count=len(rings),failures=failures)


def game_checks(args):
    from genesis_test_core import Genesis
    from check_object_course import boot_level, objects
    from check_companion_followup import place, reset_cpu, spawn
    g = Genesis(args.core,args.rom,args.listing,args.output,args.pal,
                system_directory=args.system_directory)
    boot_level(g,zone=8,act=1)
    place(g,'v_player',0x88C,0x190,False);g.put('v_player','obControl',1)
    g.put('v_player','invtime',6000,2)
    place(g,'v_player2',0x800,0x190);g.put('v_player2','obControl',1);reset_cpu(g)
    g.write('Camera_X_pos',0x7F4,2);g.write('Camera_Y_pos',0x100,2)
    g.write('Screen_redraw_flag',1);g.run(16)
    gate = next(a for a in objects(g,0xAB) if g.get(a,'obSubtype',2)==7)
    g.write('v_rings',49,2);g.put('v_player','obControl',0);g.run()
    assert not g.get('v_player','obControl'), '49 rings opened the gate'
    place(g,'v_player',0x88C,0x190,False);g.put('v_player','invtime',6000,2)
    g.write('v_rings',50,2);g.run()
    assert g.get('v_player','obControl')==0x81 and g.get(gate,'objoff_30')==1
    for tick in range(180):
        g.run()
        if tick>3 and not g.get('v_player','obControl') and g.get('v_player','obY',2)<0x180:
            break
    else: raise AssertionError('Secret transporter never released Sonic')
    g.run(20);g.put('v_player','obControl',1);g.run(80)
    sx,sy=g.get('v_player','obX',2),g.get('v_player','obY',2)
    cases=[]
    for case in ('below','respawn','offscreen-flight','dead','respawn-again'):
        place(g,'v_player2',sx-100,sy+120);reset_cpu(g)
        if case=='below':
            g.write('Tails_CPU_routine',4,2);g.put('v_player2','obControl',0x81)
        elif case=='dead':
            g.put('v_player2','obRoutine',6);g.put('v_player2','obVelY',0xF900,2)
        elif case=='offscreen-flight':
            g.write('Tails_CPU_routine',4,2);g.put('v_player2','obX',0x7000,2)
            g.put('v_player2','obControl',0x81)
        else:
            g.write('Tails_CPU_routine',2,2);g.put('v_player2','obX',0x7F00,2)
            g.put('v_player2','obY',0,2);g.put('v_player2','obControl',0x81)
        caught=False;trace=[]
        for tick in range(1000):
            g.run();assert not g.read('v_errortype')
            cpu=g.read('Tails_CPU_routine',2)
            dy=((g.get('v_player2','obY',2)-sy+1024)&2047)-1024
            if tick%12==0:
                trace.append([tick,cpu,g.get('v_player2','obY',2),g.read('Tails_CPU_flight_timer',2)])
            if cpu==6 and g.get('v_player2','obRoutine')==2 and not g.get('v_player2','obControl') and abs(dy)<48 and abs(g.get('v_player2','obX',2)-sx)<80:
                caught=True;break
        # Direct retries should rejoin promptly, rather than circle the level.
        prompt = case not in ('respawn','respawn-again') or tick<180
        cases.append(dict(case=case,recovered=caught,frames=tick+1,prompt=prompt))
        (args.output/(case+'-trace.json')).write_text(json.dumps(trace))
        g.video.save(args.output/(case+'.png'))
    ring_cases=[]
    pool=range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size'])
    for y in (4,0x7FC):
        for actor in pool:
            if g.get(actor,'code')==g.s['Obj13']:g.write(actor,0,g.s['object_size'])
        place(g,'v_player',sx,y,False);g.put('v_player','obControl',1)
        g.put('v_player','invtime',6000,2);g.run(30)
        g.write('v_rings',32,2);spawn(g,'Obj13',sx+80,y);g.run()
        rings=[a for a in pool if g.get(a,'code')==g.s['Obj13']]
        assert len(rings)==32 and not g.read('v_rings',2), 'Real scatter did not create 32 rings'
        # Suppress collection only after the real scatter, to isolate movement
        # and expiry while retaining normal terrain probes and game scheduling.
        for actor in rings:g.put(actor,'obColType',0)
        canonical=True;full_lifetime=True
        for tick in range(30):
            canonical &= all(g.get(a,'obY',2)<0x800 for a in rings if g.get(a,'code'))
            full_lifetime &= all(g.get(a,'code')==g.s['Obj13'] for a in rings)
            g.run();assert not g.read('v_errortype')
        g.video.save(args.output/f'lost-rings-{y:03x}.png')
        for tick in range(600):
            if not any(g.get(a,'code')==g.s['Obj13'] for a in rings):break
            g.run();assert not g.read('v_errortype')
        expired=not any(g.get(a,'code')==g.s['Obj13'] for a in rings)
        ring_cases.append(dict(y=y,canonical=canonical,alive_through_30_frames=full_lifetime,expired=expired))
    g.close()
    failures=[c for c in cases if not c['recovered'] or not c['prompt']]
    failures += [c for c in ring_cases if not c['canonical'] or not c['alive_through_30_frames'] or not c['expired']]
    return dict(secret_gate_49_rejected_50_accepted=True,cases=cases,
                ring_cases=ring_cases,failures=failures)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--core',type=Path);p.add_argument('--system-directory',type=Path)
    p.add_argument('--pal',action='store_true');p.add_argument('--probe',action='store_true')
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    report=dict(native=native_checks(args))
    if args.core:report['game']=game_checks(args)
    (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    if not args.probe:
        assert not any(value['failures'] for value in report.values())


if __name__=='__main__':main()
