#!/usr/bin/env python3
"""Execute both signpost modes, fast launch and S3&K airborne edge cases.

Native fixtures stub sound/DMA and provide explicit floor/wall distances.
The companion game runner checks actual terrain, rendering and results.
"""
import argparse
import json
from pathlib import Path
import native_test_core as c


class SignpostNative(c.Manager):
    floor = 1
    wall = 1
    def hook(self, cpu, address, size, unused):
        for name, distance in (('ObjHitFloor', self.floor), ('ObjHitWallLeft', self.wall), ('ObjHitWallRight', self.wall)):
            if address == self.s[name]:
                cpu.reg_write(c.UC_M68K_REG_D1, distance & 65535)
                sp=cpu.reg_read(c.UC_M68K_REG_A7)&0xFFFFFF
                target=int.from_bytes(cpu.mem_read(sp,4),'big')
                cpu.reg_write(c.UC_M68K_REG_A7,sp+4)
                cpu.reg_write(c.UC_M68K_REG_PC,target)
                return
        super().hook(cpu,address,size,unused)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','output'):p.add_argument('--'+name,type=Path,required=True)
    args=p.parse_args();m=SignpostNative(args.rom,args.listing);checks=[]
    guard=0x12345678
    def act(label,obj):
        m.write('VDP_Command_Buffer_Slot',m.s['VDP_Command_Buffer']&65535,2)
        m.act(label,obj,{c.UC_M68K_REG_D7:guard})
        assert m.cpu.reg_read(c.UC_M68K_REG_D7)==guard,(label,'d7')
    def setup(subtype=0,px=0x7F0):
        m.start();m.floor=m.wall=1
        m.write('Camera_X_pos',0x780,2);m.write('Camera_Y_pos',0x200,2)
        m.write('Camera_X_pos_coarse_back',0x700,2);m.write('Camera_Max_X_pos',0x780,2)
        m.write('v_scorelife',5000,4);m.write('f_timecount',1)
        obj=next(iter(m.pool()))
        for f,v,n in [('code',m.s['Signpost'],4),('obX',0x800,2),('obY',0x300,2),('obSubtype',subtype,2)]:m.put(obj,f,v,n)
        for who in ('v_player','v_player2'):
            for f,v,n in [('code',m.s['Obj01'],4),('obX',px,2),('obY',0x300,2),('obRoutine',2,1),('obAnim',2,1),('obVelY',0xFF00,2)]:m.put(who,f,v,n)
        return obj
    for word in (0,0xFFFE):
        obj=setup(word);act('Signpost_Init',obj)
        assert m.get(obj,'obRoutine')==2 and m.get(obj,'obY',2)==0x300 and m.read('f_timecount')
        m.put('v_player','obX',0x801,2);act('Signpost_Main',obj)
        assert m.get(obj,'obRoutine')==4 and not m.read('f_timecount')
        assert m.get(obj,'obSubtype')==word
    checks.append('placed entry remains stationary and preserves the complete subtype word')
    for speed,air,launched in ((0x5FF,0,False),(0x600,0,True),(0x1000,0,True),(0x600,2,False),(0xFA00,0,False)):
        obj=setup();act('Signpost_Init',obj)
        m.put('v_player','obX',0x830,2) # deliberately skip old 32px trigger window
        m.put('v_player','obInertia',speed,2);m.put('v_player','obStatus',air)
        act('Signpost_Main',obj)
        assert m.get(obj,'obRoutine')==(10 if launched else 4),(speed,air)
        assert m.get(obj,'obVelY',2)==(0xFC00 if launched else 0)
        assert m.get(obj,'obX',2)==0x800 and m.get(obj,'obVelX',2)==0
        assert m.get(obj,'obSubtype')==int(launched)
    checks.append('fast crossing threshold, negative speed, airborne pass and skipped-window crossing')
    for word in (1,0xFFFF):
        obj=setup(word);act('Signpost_Init',obj)
        assert m.get(obj,'obRoutine')==10 and m.get(obj,'obY',2)==0x1E0
        assert m.get(obj,'obAnim')==1 and not m.read('f_timecount')
        assert m.read('Camera_Min_X_pos',2)==m.read('Camera_Max_X_pos',2)==0x780
    checks.append('sky subtype starts camera-relative, spinning and arena/clock locked')
    # Range boundaries, valid animation/upward speed, live and unhurt only.
    for who in ('v_player','v_player2'):
        for dx,dy,anim,vy,routine,live,hit in (
            (-32,-24,2,0xFF00,2,1,True),(31,23,2,0xFFFF,2,1,True),
            (-33,0,2,0xFF00,2,1,False),(32,0,2,0xFF00,2,1,False),
            (0,-25,2,0xFF00,2,1,False),(0,24,2,0xFF00,2,1,False),
            (0,0,2,0,2,1,False),(0,0,2,1,2,1,False),
            (0,0,0,0xFF00,2,1,False),(0,0,2,0xFF00,4,1,False),
            (0,0,2,0xFF00,2,0,False),(0,0,2,0xFF00,2,1,True)):
            obj=setup();other='v_player2' if who=='v_player' else 'v_player'
            m.put(other,'code',0)
            for f,v,n in [('code',m.s['Obj01'] if live else 0,4),('obX',0x800+dx,2),('obY',0x300+dy,2),('obAnim',anim,1),('obVelY',vy,2),('obRoutine',routine,1)]:m.put(who,f,v,n)
            act('Signpost_CheckPlayerHit',obj)
            assert m.read('v_score',4)==(10 if hit else 0),(who,dx,dy,anim,vy,routine)
            pops=[a for a in m.pool() if m.get(a,'code')==m.s['Points']]
            assert len(pops)==int(hit)
            if hit:
                assert m.get(pops[0],'points_parent',2)==m.s[who]&65535
                assert m.get(obj,'obVelX',2)==((-dx if dx else 8)*16)&65535
                assert m.get(obj,'obVelY',2)==0xFE00 and m.get(obj,'signpost_hit_delay')==32
                for _ in range(32):act('Signpost_CheckPlayerHit',obj)
                assert m.read('v_score',4)==10 and m.get(obj,'signpost_hit_delay')==0
                act('Signpost_CheckPlayerHit',obj);assert m.read('v_score',4)==20
    checks.append('both actors: exact hit boundaries, upward roll, owner popup, velocity and 32-update cooldown')
    obj=setup();act('Signpost_CheckPlayerHit',obj)
    assert m.read('v_score',4)==20
    assert {m.get(a,'points_parent',2) for a in m.pool() if m.get(a,'code')==m.s['Points']}=={m.s['v_player']&65535,m.s['v_player2']&65535}
    checks.append('simultaneous player hits both score, preserving the second actor across allocations')
    obj=setup()
    for a in m.pool():
        if a!=obj:m.put(a,'code',m.s['ObjNull'])
    act('Signpost_CheckPlayerHit',obj);assert m.read('v_score',4)==20 and m.get(obj,'obVelY',2)==0xFE00
    act('Signpost_SpawnAirSparkle',obj)
    checks.append('full pool preserves physics and awards without popup/sparkle allocations')
    for x,vx,wall,bounce in ((0x8A9,0x100,1,True),(0x797,0xFF00,1,True),(0x800,0x100,-1,True),(0x800,0xFF00,-1,True),(0x800,0x100,1,False),(0x800,0xFF00,1,False)):
        obj=setup();m.wall=wall;m.put(obj,'obX',x,2);m.put(obj,'obVelX',vx,2)
        act('Signpost_CheckWall',obj);assert m.get(obj,'obVelX',2)==((-vx if bounce else vx)&65535)
    checks.append('both camera edges and both terrain wall sensors reflect horizontal speed')
    for y,vy,floor,land in ((0x24F,0, -2,False),(0x260,0xFF00,-2,False),(0x260,0,1,False),(0x260,0,-2,True)):
        obj=setup();m.put('v_player','code',0);m.put('v_player2','code',0)
        m.put(obj,'obRoutine',10);m.put(obj,'obY',y,2);m.put(obj,'obVelY',vy,2);m.floor=floor;m.write('Vint_runcount',1,4)
        act('Signpost_Fall',obj)
        assert m.get(obj,'obRoutine')==(12 if land else 10)
        assert m.get(obj,'obVelY',2)==(vy+12)&65535
        if land:assert m.get(obj,'obY',2)==y-2 and m.get(obj,'objoff_34',2)==64
    for mode in (0,1,2):
        obj=setup();m.write('Player_mode',mode,2);m.put(obj,'objoff_34',64,2);m.put(obj,'obRoutine',12)
        for _ in range(64):act('Signpost_Landed',obj)
        assert m.get(obj,'obRoutine')==12
        act('Signpost_Landed',obj)
        assert m.get(obj,'obRoutine')==14 and m.get(obj,'obAnim')==(4 if mode==2 else 3)
        assert m.read('f_lockctrl') and not m.read('v_jpadholdlogical',2)
    checks.append('gravity $C, ascending/high-screen floor rejection, 65-update landing spin and character portraits')
    obj=setup();act('Signpost_SpawnAirSparkle',obj)
    sparkle=next(a for a in m.pool() if m.get(a,'code')==m.s['Signpost_AirSparkle'])
    xs=[];tiers=set()
    for _ in range(32):
        act('Signpost_AirSparkle',sparkle);assert 1<=m.get(sparkle,'obFrame')<m.s['Map_Ring_frames'];xs.append(m.get(sparkle,'obX',2));tiers.add(m.get(sparkle,'obPriority',2))
    assert min(xs)<0x800<max(xs) and tiers=={0x280,0x380}
    act('Signpost_AirSparkle',sparkle);assert not m.get(sparkle,'code')
    checks.append('32-update orbit sparkle alternates depth, crosses its origin and deletes cleanly')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps({'passed':True,'checks':checks},indent=2)+'\n')
    print(f'{len(checks)} signpost groups passed')

if __name__=='__main__':main()
