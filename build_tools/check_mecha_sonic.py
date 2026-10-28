#!/usr/bin/env python3
"""Standard Mecha Sonic: upstream motion oracle and real SMZ2 trap/fight/results.

Game scenes use the authored placement and controller input for the crossing.
Focused actor positioning supplies jumping hits; this is not a full playthrough.
The optional upstream reference executes original 68000 attack/animation code;
audio/child effects and a flat floor are explicit fixture boundaries.
"""
from pathlib import Path
import argparse,json,re,struct,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]

def reference(m,args):
    import native_test_core as n
    source=(args.skdisasm/'sonic3k.asm').read_text()
    state=source[source.index('SSZEndBoss_Index:'):source.index('\nloc_7B2DC:')]
    state+=source[source.index('\nloc_7B3E6:'):source.index('\nloc_7B81A:')]
    anim=source[source.index('byte_7D4DE:'):source.index('byte_7D5F6:')]
    matches=list(re.finditer(r'(?m)^(byte_[0-9A-F]+):',anim))
    needed={'byte_7D4DE','byte_7D4EF','byte_7D523','byte_7D541','byte_7D54A','byte_7D596','byte_7D59B','byte_7D5A2'}
    anim=''.join(anim[x.start():matches[i+1].start() if i+1<len(matches) else len(anim)] for i,x in enumerate(matches) if x[1] in needed)
    raw=source[source.index('\nAnimate_RawMultiDelay:'):source.index('\nAnimate_RawMultiDelayFlipX:')]
    wait=source[source.index('\nObj_Wait:'):source.index('\nObjHitFloor2_DoRoutine:')]
    edge=source[source.index('\nloc_7D216:'):source.index('; =============== S U B R O U T I N E',source.index('\nloc_7D216:'))]
    aliases={'routine':'obRoutine','mapping_frame':'obFrame','render_flags':'obRender','x_pos':'obX','y_pos':'obY','x_vel':'obVelX','y_vel':'obVelY','y_radius':'obHeight','anim_frame':'obAniFrame','anim_frame_timer':'obTimeFrame','subtype':'obSubtype','Camera_X_pos':'Camera_X_pos','Camera_Y_pos':'Camera_Y_pos','Random_Number':'RandomNumber','MoveSprite':'ObjectMoveAndFall','MoveSprite2':'ObjectMove','MoveSprite_LightGravity':'ObjectMoveAndFall_LightGravity','ObjCheckFloorDist':'ObjHitFloor','Play_SFX':'PlaySound_Special','sfx_MechaLand':'SndID_MechaLand','sfx_Dash':'sfx_Dash','sfx_Thump':'SndID_Thump'}
    lines=['\tCPU 68000',f'\tinclude "{ROOT}/_definitions/s2.macrosetup.asm"','\t!org 0','\tphase $300000']
    lines += [f'{k} equ ${m.s[v]:X}' for k,v in aliases.items()]
    lines += ['_unkFAB4 equ $FFFFDF00','_unkFAB6 equ $FFFFDF02','_unkFAB0 equ $FFFFDF04','_unkFAB8 equ $FFFFDF06','loc_7B2DC equ Ref_Return','loc_7B3AC equ Ref_Return','Ref_Step:','\tmoveq #0,d0','\tmove.b routine(a0),d0','\tmove.w SSZEndBoss_Index(pc,d0.w),d1','\tjsr SSZEndBoss_Index(pc,d1.w)','\trts',state,anim,'\teven',raw,wait,edge,'Set_Raw_Animation:','\tmove.l a1,$30(a0)','\tclr.b anim_frame(a0)','\tclr.b anim_frame_timer(a0)','\trts','CreateChild6_Simple:','\tmoveq #1,d0','\trts','ChildObjDat_7D47A: dc.w 0','ChildObjDat_7D480: dc.w 0','ChildObjDat_7D486: dc.w 0','Ref_Return: rts','\tdephase']
    path=args.output/'reference.asm';path.write_text('\n'.join(lines)+'\n')
    tool=ROOT/'build_tools/Linux-x86_64'
    r=subprocess.run([str(tool/'asl'),'-xx','-n','-q','-A','-L','-U',str(path.resolve())],cwd=ROOT,capture_output=True,text=True)
    assert r.returncode==0,r.stdout+r.stderr
    subprocess.run([str(tool/'p2bin'),'-p=FF',str(path.with_suffix('.p')),str(path.with_suffix('.bin'))],check=True)
    labels={k:int(v,16) for k,v in re.findall(r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',path.with_suffix('.lst').read_text())}
    return labels,path.with_suffix('.bin').read_bytes()

def native(args):
    import native_test_core as n
    class Machine(n.Manager):
        def hook(self,cpu,address,size,unused):
            if address==self.s['ObjHitFloor']:
                a=cpu.reg_read(n.UC_M68K_REG_A0)
                distance=0x5C0-self.get(a,'obY',2)-self.get(a,'obHeight')-1
                cpu.reg_write(n.UC_M68K_REG_D1,distance&65535)
                stack=cpu.reg_read(n.UC_M68K_REG_A7)
                cpu.reg_write(n.UC_M68K_REG_PC,int.from_bytes(cpu.mem_read(stack,4),'big'))
                cpu.reg_write(n.UC_M68K_REG_A7,stack+4)
    m=Machine(args.rom,args.listing);m.start();pool=list(m.pool());body=pool[0];checks=[]
    for slot in pool:m.put(slot,'code',m.s['MS_Return'])
    m.put(body,'code',m.s['MechaSonic']);m.act('MS_Init',body)
    assert m.get(body,'MS_phase')==0
    m.put(pool[-1],'code',0);m.act('MS_Init',body)
    assert m.get(body,'MS_phase')==1 and m.get(pool[-1],'code')==m.s['MS_HeadHitbox']
    checks.append('constructor retries a full pool without a half-initialized hitbox')
    for slot in pool:m.put(slot,'code',m.s['MS_Return'])
    m.put(body,'code',m.s['MechaSonic']);m.put(body,'MS_phase',8)
    m.act('MS_Reward',body,{n.UC_M68K_REG_D7:0x55})
    assert m.get(body,'code')==m.s['MechaSonic']
    m.put(pool[-1],'code',0);m.act('MS_Reward',body,{n.UC_M68K_REG_D7:0x55})
    assert not m.get(body,'code') and m.get(pool[-1],'code')==m.s['Signpost'] and m.get(pool[-1],'obSubtype')==1
    assert m.cpu.reg_read(n.UC_M68K_REG_D7)==0x55
    checks.append('defeat waits for a real reward slot; palette handoff preserves dispatcher D7')
    m.start();body,child=pool[-1],pool[0]
    for f,v,z in [('code',m.s['MechaSonic'],4),('MS_phase',4,1),('MS_hitbox',child,2),('obX',0x1E80,2),('obY',0x5A0,2),('obFrame',0,1),('obRender',4,1)]:m.put(body,f,v,z)
    m.put(child,'code',m.s['MS_HeadHitbox']);m.put(child,'MS_parent',body,2)
    m.act('MS_UpdateHitbox',body,{n.UC_M68K_REG_D7:0x55})
    assert (m.get(child,'obX',2),m.get(child,'obY',2))==(0x1E90,0x594)
    assert m.read('Collision_response_list',2)==2 and m.read('Collision_response_entries',2)==child&65535
    assert m.cpu.reg_read(n.UC_M68K_REG_D7)==0x55
    m.put(child,'code',m.s['MS_Return']);m.put(child,'obX',0x1234,2)
    m.act('MS_UpdateHitbox',body);assert m.get(child,'obX',2)==0x1234
    m.put(child,'code',m.s['MS_HeadHitbox']);m.put(body,'code',m.s['MS_Return'])
    m.act('MS_HeadHitbox',child);assert not m.get(child,'code')
    checks.append('earlier invisible child registers in the same update; reused slots survive and orphan hitboxes retire')
    m.start();body=pool[0]
    for slot in pool:m.put(slot,'code',m.s['MS_Return'])
    m.put(body,'code',m.s['MechaSonic']);m.put(body,'MS_flags',4)
    end=m.s['v_lvlobjend']&0xFFFFFF;canary=bytes(m.cpu.mem_read(end,8))
    m.act('MS_MaintainJets',body)
    assert not m.get(body,'MS_jet1',2) and bytes(m.cpu.mem_read(end,8))==canary
    for index,field in ((-1,'MS_jet1'),(-2,'MS_jet2')):
        m.put(pool[index],'code',0);m.act('MS_MaintainJets',body)
        assert m.get(body,field,2)==pool[index]&65535 and m.get(pool[index],'code')==m.s['MS_Jet']
    checks.append('jet pairs recover from partial allocation without writing beyond the pool')
    if args.skdisasm:
        ref=Machine(args.rom,args.listing);labels,data=reference(m,args);ref.s.update(labels);ref.cpu.mem_write(0x300000,data)
        m.start();ref.start()
        fields=[('obRoutine',1),('obFrame',1),('obX',4),('obY',4),('obVelX',2),('obVelY',2),('obRender',1),('obHeight',1),('MS_flags',1),('MS_attack',1),('MS_attack_count',1),('MS_timer',2),('MS_accel',2),('obAniFrame',1),('obTimeFrame',1)]
        for machine in (m,ref):
            machine.write('Camera_X_pos',0x1E40,2);machine.write('Camera_Y_pos',0x500,2);machine.write('v_random',0x12345678,4)
            for key,val,z in [('code',machine.s['MechaSonic'],4),('MS_phase',4,1),('obRoutine',6,1),('MS_timer',63,2),('obFrame',2,1),('obRender',4,1),('obX',0x1E20,2),('obY',0x5A0,2),('obHeight',31,1),('obColProp',8,1),('obColType',9,1),('MS_left',0x1E60,2),('MS_right',0x1F60,2),('MS_top',0x530,2)]:machine.put(body,key,val,z)
        m.put(body,'MS_callback',m.s['MS_ReturnSweep'],4);ref.put(body,'MS_callback',labels['loc_7B41C'],4)
        for address,value,z in [(0xFFDF00,0x1E60,2),(0xFFDF02,0x1F60,2),(0xFFDF04,0x530,2),(0xFFDF06,0,1)]:ref.cpu.mem_write(address,value.to_bytes(z,'big'))
        states=set()
        for tick in range(8400):
            m.act('MS_RunFight',body);ref.act('Ref_Step',body)
            for field,z in fields:
                assert m.get(body,field,z)==ref.get(body,field,z),(tick,field,m.get(body,field,z),ref.get(body,field,z))
            assert m.get(body,'MS_history')==int.from_bytes(ref.cpu.mem_read(0xFFDF06,1),'big')
            assert m.read('v_random',4)==ref.read('v_random',4)
            states.add(m.get(body,'obRoutine'))
        assert {8,12,14,16,20,22,24,26,28,30,32,34,36,38,40}<=states,states
        checks.append('8400 updates match original skdisasm attack states, raw animations, positions, velocities and RNG')
    return checks

def game(args):
    from genesis_test_core import Genesis
    from check_object_course import boot_level
    from check_companion_followup import place
    g=Genesis(args.core,args.rom,args.listing,args.output/'game',args.pal,system_directory=args.system_directory)
    boot_level(g,zone=g.s['id_SMZ'],act=1,player=args.player)
    pool=list(range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']))
    def objects(label):return [o for o in pool if g.get(o,'code')==g.s[label]]
    def run(count=1):
        for _ in range(count):g.run();assert not g.read('v_errortype'),('CPU exception',g.frame)
    actors=['v_player'] if args.player==2 else ['v_player','v_player2']
    for j,actor in enumerate(actors):
        place(g,actor,0x1E10 if j==0 else 0x1E80,0x530 if j==0 else 0x5AD,j==0);g.put(actor,'obControl',0 if j==0 else 1)
    g.write('Camera_X_pos',0x1E40,2);g.write('Camera_Y_pos',0x500,2);g.write('v_rings',99,2);g.write('f_ringcount',1)
    g.write('Tails_CPU_idle_timer',6000,2);g.buttons2={4}
    run(90);signs=objects('Signpost');assert len(signs)==1
    sign=signs[0];assert g.get(sign,'obSubtype')==2 and g.get(sign,'obFrame')==2
    g.video.save(args.output/'game/before.png')
    g.put('v_player','obControl',0);g.put('v_player','obVelX',0x600,2);g.put('v_player','obInertia',0x600,2);g.buttons={7};spin=set();seen=set();broken=False;boss=None
    for t in range(400):
        run()
        if t==120:g.buttons=set()
        assert not g.get('v_endcard','code'),'premature act results'
        if g.get(sign,'code')==g.s['Signpost']:spin.add(g.get(sign,'obFrame'))
        if objects('MechaSonic'):
            boss=objects('MechaSonic')[0];g.buttons=set();seen.add(g.get(boss,'MS_phase'))
            if objects('MS_SignDebris') and not broken:g.video.save(args.output/'game/sign-destroyed.png');broken=True
            if g.get(boss,'MS_phase')==4:break
    assert boss and {2,4,6,9,10}<=spin and broken,(boss,spin,seen,broken,{f:g.get('v_player',f,z) for f,z in [('obX',2),('obY',2),('obVelX',2),('obStatus',1),('obControl',1),('obRoutine',1)]})
    assert g.get(sign,'code')!=g.s['Signpost']
    assert g.get(boss,'obColProp')==8
    assert g.read('Camera_Min_X_pos',2)==g.read('Camera_Max_X_pos',2)==0x1E40
    assert not objects('Signpost')
    checks=['authored SMZ2 sign: controller crossing, Eggman/Mecha mixed frames, side entry, debris and no early results']
    for actor in actors:
        place(g,actor,0x1E60,0x4D0);g.put(actor,'obControl',1)
    states=set()
    for t in range(2400):
        run();r=g.get(boss,'obRoutine');states.add(r)
        assert g.get(boss,'obColProp')==8 and not objects('Signpost'),(t,g.get(boss,'obColProp'))
        if r in (16,24,28,36) and t%32==0:g.video.save(args.output/f'game/attack-{r:02x}.png')
    assert {8,12,14,16,20,22,24,26,28,30,32,34,36,38,40}<=states,states
    checks.append('all standard attack states run on live SMZ2 terrain without spawning the reward')
    attacker='v_player2' if args.companion else 'v_player'
    assert attacker in actors
    score=g.read('v_score',4)
    for hit in range(8):
        for wait in range(2000):
            if g.get(boss,'MS_flash')==0 and 0<g.get(boss,'obColType')<0x40:break
            run()
        else:raise AssertionError(('no vulnerable state',hit))
        hp=g.get(boss,'obColProp');x=g.get(boss,'obX',2);y=g.get(boss,'obY',2)
        offset=6 if g.get(boss,'obRender')&1 else -6
        shape=g.get(boss,'obColType')&0x3F
        radius=args.rom.read_bytes()[g.s['Touch_Sizes']+(shape-1)*2+1]
        place(g,attacker,x+offset,y-radius-11)
        for f,v,z in [('obVelY',0x400,2),('obStatus',6,1),('obAnim',2,1),('obHeight',14,1),('obWidth',7,1),('jumping',1,1)]:g.put(attacker,f,v,z)
        run()
        assert g.get(boss,'obColProp')==hp-1,(hit,hp,g.get(boss,'obColProp'),g.get(boss,'obFrame'),g.get(attacker,'obRoutine'))
        place(g,attacker,0x1E60,0x510);g.put(attacker,'obControl',1)
        run()
        if hit==0:g.video.save(args.output/'game/hit-flash.png')
    assert g.read('v_score',4)==score+100
    assert g.get(boss,'MS_phase')==5 and not g.read('f_timecount')
    assert not objects('MS_HeadHitbox')
    phases=set()
    for t in range(800):
        run()
        if g.get(boss,'code')==g.s['MechaSonic']:
            phase=g.get(boss,'MS_phase');phases.add(phase)
            if phase==7 and t%8==0:g.video.save(args.output/'game/defeat.png')
        if objects('Signpost'):break
    assert {5,6,7}<=phases and objects('Signpost'),phases
    reward=objects('Signpost')[0]
    assert g.get(reward,'obSubtype')==1 and not objects('MechaSonic')
    for j,actor in enumerate(actors):place(g,actor,0x1E90-j*0x20,0x5AD,False)
    for t in range(1000):
        run()
        if g.get('v_endcard','code')==g.s['GotThrough'] and g.get('v_endcard','obRoutine'):
            run(60);g.video.save(args.output/'game/results.png');break
    else:raise AssertionError('no final falling-sign results')
    assert g.get(reward,'obFrame')==(1 if args.player==2 else 0)
    checks.append(f'eight real {attacker} hits, 1000 points, defeat bursts/collapse/sparks, then falling sign and character results')
    return checks

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--core',type=Path);p.add_argument('--system-directory',type=Path);p.add_argument('--skdisasm',type=Path)
    p.add_argument('--player',type=int,choices=(0,2),default=0);p.add_argument('--pal',action='store_true');p.add_argument('--companion',action='store_true');p.add_argument('--native',action='store_true')
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True);checks=[]
    if a.native:checks+=native(a)
    if a.core:checks+=game(a)
    assert checks
    (a.output/'report.json').write_text(json.dumps({'passed':True,'checks':checks,'controller_only_playthrough':False},indent=2)+'\n')
    print(f'{len(checks)} Mecha Sonic groups pass.')
if __name__=='__main__':main()
