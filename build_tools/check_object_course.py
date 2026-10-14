#!/usr/bin/env python3
"""Run the disposable LZ2 course with actual Genesis Plus GX emulation.

Scripted positioning visits each real placement, then leaves/revisits its
loading window. This is a lifecycle/rendering sweep, supplemented by explicit
interaction tests; it is not a controller-only playthrough of every subtype.
"""
from pathlib import Path
import argparse
import json
from genesis_test_core import Genesis


def boot_level(g,item=10,player=0):
    for _ in range(1800):
        g.run()
        if g.read('v_vbla_routine',2)==g.s['Vint_Title'] and g.read('v_generictimer',2)==375:
            break
    else:
        raise AssertionError('Title did not start')
    g.write('f_levselcheat',1)
    g.buttons={3};g.run(2);g.buttons=set();g.run(5)
    g.write('Player_mode',player,2)
    g.write('v_levselitem',item,2);g.run(5)
    g.buttons={3};g.run(2);g.buttons=set()
    for _ in range(600):
        g.run()
        if g.read('v_vbla_routine',2)==g.s['Vint_Level'] and g.read('f_timecount') and g.read('v_gamemode',2)==g.s['Level']:
            break
    else:
        raise AssertionError('Level did not start')
    g.run(90)


def position(g,x,y=0x4ED,frozen=True):
    for field,value,size in [('obX',x,2),('obY',y,2),('obVelX',0,2),
                             ('obVelY',0,2),('obInertia',0,2),('obStatus',0,1),
                             ('obControl',1 if frozen else 0,1),('obRoutine',2,1),
                             ('obStatusSecondary',2,1),('invtime',6000,2),
                             ('flashtime',0,2)]:
        g.put('v_player',field,value,size)
    g.write('v_rings',99,2)
    g.write('Camera_X_pos',max(0,min(0x3FFF,x-160)),2)
    g.write('Camera_Y_pos',max(0,y-160),2)
    g.write('Camera_Max_Y_pos',0x720,2)
    g.write('Camera_Max_Y_pos_target',0x720,2)


def objects(g,oid=None):
    return [a for a in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size'])
            if g.get(a,'layout_id') and (oid is None or g.get(a,'layout_id')==oid)]


def owner(g,obj):
    pointer=(g.s['Object_Respawn_Table']+obj['index'])&65535
    return [a for a in objects(g) if not g.get(a,'obRender')&0x40 and g.get(a,'respawn_addr',2)==pointer]


def snapshot(g,a):
    return {f:g.get(a,f,z) for f,z in [('layout_id',1),('code',4),('obRoutine',1),('ob2ndRout',1),
            ('obX',2),('obY',2),('obRender',1),('obFrame',1),('obMap',4),('obGfx',2),
            ('respawn_addr',2),('obStatus',1),('obColType',1),('height_pixels',1)]}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build',type=Path,required=True)
    p.add_argument('--core',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--pal',action='store_true')
    p.add_argument('--player',type=int,default=0,choices=(0,2))
    p.add_argument('--bank',type=int)
    args=p.parse_args()
    g=Genesis(args.core,args.build/'object-course.bin',args.build/'object-course.lst',args.output,args.pal)
    boot_level(g,player=args.player)
    assert g.read('Current_ZoneAndAct',2)==0x101
    report={'region':'PAL' if args.pal else 'NTSC','player':'Tails' if args.player==2 else 'Sonic','placements':[], 'failures':[]}
    executed=set()
    initial=g.save()
    for i,bank in enumerate(json.loads((args.build/'course.json').read_text())['banks']):
        if args.bank is not None and i!=args.bank:
            continue
        for obj in bank['objects']:
            g.restore(initial)
            # Preserve the assembled object code and load the real placements.
            # Hide the companion during the lifecycle pass to attribute contacts.
            g.put('v_player2','layout_id',0)
            position(g,obj['world_x']-64)
            states=[];seen=False; rendered=False;live_frames=0
            previous_vint=g.read('Vint_runcount',4)
            for tick in range(240):
                g.run()
                if tick%30==29:
                    current_vint=g.read('Vint_runcount',4)
                    if current_vint==previous_vint:
                        report['failures'].append({'name':obj['name'],'reason':'VInt counter stalled','pc':g.core.m68k_get_reg(16)})
                        break
                    previous_vint=current_vint
                actors=owner(g,obj)
                if len(actors)>1:
                    report['failures'].append({'name':obj['name'],'reason':'duplicate placement owner','actors':actors})
                    break
                if actors:
                    seen=True;live_frames+=1
                    state=snapshot(g,actors[0]);rendered|=bool(state['obRender']&128)
                    if tick%30==0:states.append(state)
                if g.read('v_gamemode',2)!=g.s['Level'] or g.get('v_player','obRoutine')>=6:
                    report['failures'].append({'name':obj['name'],'reason':'mode/death during passive test','mode':g.read('v_gamemode',2),'pc':g.core.m68k_get_reg(16)})
                    break
            entry={'name':obj['name'],'id':obj['id'],'bank':i,'seen':seen,
                   'rendered':rendered,'live_frames':live_frames,'states':states}
            g.video.save(args.output/f'{i:02}-{obj["index"]:02}.png')
            if not seen:
                report['failures'].append({'name':obj['name'],'reason':'placement never spawned','pc':g.core.m68k_get_reg(16)})
            if seen:
                exit_x=obj['world_x']+0x700
                if exit_x>0x3FFF:
                    exit_x=obj['world_x']-0x700
                position(g,exit_x)
                g.run(90)
                entry['owners_after_leaving']=len(owner(g,obj))
                position(g,obj['world_x']-64)
                g.run(120)
                entry['owners_after_revisit']=len(owner(g,obj))
                entry['respawn_state']=g.read(g.s['Object_Respawn_Table']+obj['index'])
                if entry['owners_after_leaving']:
                    report['failures'].append({'name':obj['name'],'reason':'owner survived outside X window'})
                if entry['owners_after_revisit']>1:
                    report['failures'].append({'name':obj['name'],'reason':'duplicate on revisit'})
            report['placements'].append(entry)
            executed.update(i for i in range(1,256) if g.read(g.s['ObjectTest_Executed']+i))
            report['executed_ids']=[f'{i:02X}' for i in sorted(executed)]
            print(obj['name'], 'spawn',seen,'visible',rendered,'leave/revisit',entry.get('owners_after_leaving'),entry.get('owners_after_revisit'),flush=True)
            (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    g.close()
    print('Failures:',len(report['failures']),flush=True)
    if report['failures']:
        print(json.dumps(report['failures'],indent=2))
        raise SystemExit(1)


if __name__=='__main__':
    main()
