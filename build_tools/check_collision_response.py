#!/usr/bin/env python3
"""Execute the live candidate-list ABI, dispatcher ordering and touch math.

Optional previous ROM comparison uses its original full-pool TouchResponse.
DMA/sound are stubbed; gameplay and CPU costs use the separate core runner.
"""
import argparse
import json
import random
import struct
from pathlib import Path
import native_test_core as c


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--previous-rom',type=Path);p.add_argument('--previous-listing',type=Path)
    args=p.parse_args();m=c.Manager(args.rom,args.listing);checks=[];guard=0x13579BDF
    nop=0x3E0000;m.cpu.mem_write(nop,bytes.fromhex('4E75'))
    slots=list(m.pool());capacity=m.s['Collision_response_capacity'];assert capacity==len(slots)==90
    def act(name,obj=None,regs=None):
        m.act(name,obj,{c.UC_M68K_REG_D7:guard,**(regs or {})})
        if name!='ExecuteObjects':assert m.cpu.reg_read(c.UC_M68K_REG_D7)==guard,(name,'d7')
    def reset():
        m.start();m.cpu.mem_write(m.s['v_objspace']&0xFFFFFF,bytes(m.s['v_objend']-m.s['v_objspace']))
        m.write('v_scorelife',5000,4)
    def target(a,flag=0x47,render=4):
        for f,v,n in [('code',nop,4),('obColType',flag,1),('obRender',render,1),('obX',600,2),('obY',116,2)]:m.put(a,f,v,n)
    def queue():
        count=m.read('Collision_response_list',2)
        if count==65535:
            return [a&65535 for a in slots if m.get(a,'code') and m.get(a,'obColType') and not m.get(a,'obRender')&64]
        assert count%2==0 and count<=m.s['Collision_response_bytes']
        return list(struct.unpack('>'+str(count//2)+'H',bytes(m.cpu.mem_read(m.s['Collision_response_entries']&0xFFFFFF,count)))) if count else []
    reset();order=slots.copy();random.Random(317).shuffle(order)
    m.write('Free_RAM_Start',0x1357ACE0,4)
    prefix=order[:m.s['Collision_response_list_capacity']]
    for a in prefix:target(a);act('Add_SpriteToCollisionResponseList',a)
    assert queue()==sorted(a&65535 for a in prefix)
    for a in prefix:act('Add_SpriteToCollisionResponseList',a)
    assert m.read('Collision_response_list',2)==m.s['Collision_response_bytes']
    for a in order[len(prefix):]:target(a);act('Add_SpriteToCollisionResponseList',a)
    assert m.read('Collision_response_list',2)==65535
    assert queue()==[a&65535 for a in slots]
    for a in order:act('Add_SpriteToCollisionResponseList',a)
    assert len(queue())==90 and m.read('Free_RAM_Start',4)==0x1357ACE0
    checks.append('all 90 slots: bounded pointer queue, complete dense fallback and canary preserved')
    reset()
    for a,flag,render,code in ((slots[0],0,4,nop),(slots[1],9,0,nop),(slots[2],9,0x44,nop),(slots[3],9,4,0)):
        target(a,flag,render);m.put(a,'code',code);act('Add_SpriteToCollisionResponseList',a)
    assert queue()==[slots[1]&65535]
    checks.append('invisible live hitboxes register; empty, disabled and composite slots do not')
    # Native fixture routines read the count before the reset at slot six.
    recorder=0x3E0100
    m.cpu.mem_write(recorder,bytes.fromhex('3179')+struct.pack('>I',m.s['Collision_response_list']&0xFFFFFF)+struct.pack('>H',m.s['obVelX'])+bytes.fromhex('4E75'))
    reset();target(slots[0]);act('Add_SpriteToCollisionResponseList',slots[0])
    for who in ('v_player','v_player2'):m.put(who,'code',recorder)
    target(slots[-1],0x47,0);m.put(slots[0],'obColType',0)
    # Reserved overlaid bytes must never become candidates.
    reserved=m.s['v_player']+2*m.s['object_size'];target(reserved,9)
    act('ExecuteObjects')
    assert m.get('v_player','obVelX',2)==m.get('v_player2','obVelX',2)==2
    assert queue()==[slots[-1]&65535]
    checks.append('both players consume the old list before reset; dynamic final slot registers, reserved SSTs stay excluded')
    reset();target(slots[0],0xD7)
    player_call=0x3E0120
    m.cpu.mem_write(player_call,bytes.fromhex('4EB9')+struct.pack('>I',m.s['TouchResponse'])+bytes.fromhex('4E75'))
    for who in ('v_player','v_player2'):
        for f,v,n in [('code',player_call,4),('obX',600,2),('obY',116,2),('obHeight',19,1),('obAnim',0,1)]:m.put(who,f,v,n)
    act('Add_SpriteToCollisionResponseList',slots[0]);act('ExecuteObjects')
    assert m.get(slots[0],'obColProp')==3 and len(queue())==1
    checks.append('both live TouchResponse calls share one list: primary and companion boss-hit responses survive')
    # An owner enables a lower slot after that child already ran. Use the same
    # hook as the actual newborn/projectile/mounted-monitor paths.
    parent=slots[10];child=slots[1];owner_code=0x3E0200
    m.cpu.mem_write(owner_code,bytes.fromhex('43F8')+struct.pack('>H',child&65535)+bytes.fromhex('137C0087')+struct.pack('>H',m.s['obColType'])+bytes.fromhex('4EB9')+struct.pack('>I',m.s['Touch_RegisterEarlierObject'])+bytes.fromhex('4E75'))
    reset();target(child,0);target(slots[5],9);target(parent,9);m.put(parent,'code',owner_code)
    act('ExecuteObjects');assert queue()==[a&65535 for a in (child,slots[5],parent)]
    act('ExecuteObjects');assert queue()==[a&65535 for a in (child,slots[5],parent)]
    checks.append('a late-enabled earlier child is inserted immediately without duplicates and retains slot priority')
    reset();target(slots[0],0x40);act('Add_SpriteToCollisionResponseList',slots[0])
    for who in ('v_player','v_player2'):
        m.put(who,'obX',600,2);m.put(who,'obY',116,2);m.put(who,'obHeight',19)
        before=m.get(slots[0],'obRoutine');act('TouchResponse',who);assert m.get(slots[0],'obRoutine')==before
    for code,flag,render in ((0,0x47,4),(nop,0,4),(nop,9,0x44)):
        target(slots[0],flag,render);m.put(slots[0],'code',code)
        act('TouchResponse','v_player');assert m.get(slots[0],'obRoutine')==0
    checks.append('queued dead/disabled/composite entries and zero-size response flags are rejected at consumption')
    # Every subset of a four-slot group must preserve pool-scan priority.
    for mask in range(16):
        reset()
        for i in range(4):
            if mask&(1<<i):target(slots[4+i],0xE1);act('Add_SpriteToCollisionResponseList',slots[4+i])
        for f,v,n in [('obX',600,2),('obY',116,2),('obHeight',19,1)]:m.put('v_player',f,v,n)
        act('TouchResponse','v_player')
        hit=[i for i in range(4) if m.get(slots[4+i],'obColProp')]
        assert hit==([next(i for i in range(4) if mask&(1<<i))] if mask else []),(mask,hit)
    checks.append('all 16 four-slot subsets preserve the earliest eligible slot without phantom candidates')
    reset()
    for a in slots:target(a)
    act('ExecuteObjects');assert m.read('Collision_response_list',2)==65535
    for a in slots[4:]:m.put(a,'obColType',0)
    m.write('Timer_frames',1,2);act('ExecuteObjects');assert m.read('Collision_response_list',2)==65535
    m.write('Timer_frames',16,2);act('ExecuteObjects');assert queue()==[a&65535 for a in slots[:4]]
    checks.append('dense scenes bypass rebuilding between probes and return to the list when the crowd clears')
    # Compare every existing size with the pre-port rectangle code, at exact
    # outside/touching/inside boundaries, ducking and rolling, for both actors.
    compared=0
    if args.previous_rom:
        old=c.Manager(args.previous_rom,args.previous_listing)
        for size in range(1,39):
            width,height=old.cpu.mem_read(old.s['Touch_Sizes']+(size-1)*2,2)
            for who in ('v_player','v_player2'):
                for duck in (False,True):
                    ph=5 if duck else 16
                    positions=[(-width-9,0),(-width-8,0),(width+8,0),(width+9,0),(0,-height-ph-1),(0,-height-ph),(0,height+ph),(0,height+ph+1),(0,0)]
                    for dx,dy in positions:
                        snapshots=[]
                        for machine,dense in ((old,False),(m,False),(m,True)):
                            machine.start();a=next(iter(machine.pool()))
                            machine.write('v_scorelife',5000,4)
                            for f,v,n in [('obX',600,2),('obY',116,2),('obHeight',19,1),('obAnim',machine.s['AniIDSonAni_Duck'] if duck else machine.s['AniIDSonAni_Roll'],1),('obVelY',0x100,2)]:machine.put(who,f,v,n)
                            for f,v,n in [('code',machine.s['Obj12'],4),('obX',600+dx,2),('obY',116+dy,2),('obRender',4,1),('obColType',0x40|size,1)]:machine.put(a,f,v,n)
                            if machine is m:
                                machine.act('Add_SpriteToCollisionResponseList',a)
                                if dense:machine.write('Collision_response_list',65535,2)
                            machine.act('TouchResponse',who)
                            snapshots.append(([machine.get(a,f,n) for f,n in [('obRoutine',1),('ob2ndRout',1),('obParent',2),('obColType',1)]],[machine.get(who,f,n) for f,n in [('obVelY',2),('obRoutine',1),('flashtime',2)]]))
                        assert snapshots[0]==snapshots[1]==snapshots[2],(size,who,duck,dx,dy,snapshots)
                        compared+=2
        for flag in (9,0x46,0x47,0x81,0x87,0x98,0xD7):
            for who in ('v_player','v_player2'):
                for anim in (0,2):
                    for protection in (0,1,2):
                        snapshots=[]
                        for machine,dense in ((old,False),(m,False),(m,True)):
                            machine.start();a=next(iter(machine.pool()))
                            machine.write('v_scorelife',5000,4);machine.write('v_rings',30,2)
                            for f,v,n in [('obX',600,2),('obY',116,2),('obHeight',19,1),('obAnim',anim,1),('obVelY',0x100,2),('obStatusSecondary',protection,1)]:machine.put(who,f,v,n)
                            for f,v,n in [('code',machine.s['Obj26'] if flag==0x46 else machine.s['Crabmeat'],4),('obX',600,2),('obY',116,2),('obRender',4,1),('obColType',flag,1)]:machine.put(a,f,v,n)
                            if machine is m:
                                machine.act('Add_SpriteToCollisionResponseList',a)
                                if dense:machine.write('Collision_response_list',65535,2)
                            machine.act('TouchResponse',who)
                            snapshots.append(([machine.get(who,f,n) for f,n in [('obRoutine',1),('obAnim',1),('obVelX',2),('obVelY',2),('flashtime',2),('obStatusSecondary',1)]],[machine.get(a,f,n) for f,n in [('obRoutine',1),('obColType',1),('obColProp',1),('obParent',2)]],machine.get(a,'code')==machine.s['Explosion'],machine.read('v_score',4),machine.read('v_rings',2)))
                        assert snapshots[0]==snapshots[1]==snapshots[2],('response',hex(flag),who,anim,protection,snapshots)
                        compared+=2
        # All existing engine globals stay put; only the free allocation's
        # start changes because this feature consumes its first 50 bytes.
        fixed=[name for name,v in old.s.items() if name in m.s and 0xFF8000<=(v&0xFFFFFF)<=0xFFFFFF and name not in ('Free_RAM_Start',)]
        for name in fixed:assert m.s[name]==old.s[name],(name,old.s[name],m.s[name])
        checks.append(f'{compared} old/new size-edge/duck/actor comparisons; {len(fixed)} existing upper-RAM symbols preserved')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps({'passed':True,'checks':checks,'differential_cases':compared},indent=2)+'\n')
    print(f'{len(checks)} collision-list groups passed; {compared} old/new rectangle comparisons')

if __name__=='__main__':main()
