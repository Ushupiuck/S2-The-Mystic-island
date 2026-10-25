#!/usr/bin/env python3
"""Stress the actual imported SBZ acts, both actors and their native stage objects.

Start routes use controller input. Later fixtures position initial actors at
real placements and retain the stage's terrain, objects, collision and camera.
The lifecycle sweep never substitutes an artificial course or object layout.
"""
from object_layout import decode
from pathlib import Path
import argparse,json,struct
from genesis_test_core import Genesis
from check_object_course import boot_level,objects,snapshot
from check_companion_followup import place,reset_cpu,spawn

p=argparse.ArgumentParser(description=__doc__)
for n in ('rom','listing','core','output'):p.add_argument('--'+n,type=Path,required=True)
p.add_argument('--pal',action='store_true');p.add_argument('--skip-sweep',action='store_true');args=p.parse_args()
ROOT=Path(__file__).resolve().parents[1]
g=Genesis(args.core,args.rom,args.listing,args.output,args.pal);report=[]
def row():
 r={'cpu':g.read('Tails_CPU_routine',2),'reach':g.read('Tails_CPU_reach_state',2)}
 for prefix,a in [('s','v_player'),('t','v_player2')]:
  for f,z in [('obX',2),('obY',2),('obStatus',1),('obRoutine',1),('obControl',1),('obVelX',2),('obVelY',2),('jumping',1)]:r[prefix+f]=g.get(a,f,z)
 return r

def run(label,commands,alive=True):
 trace=[];invalid=[];previous=row();parents=set()
 for phase,buttons,n in commands:
  g.buttons=set(buttons)
  for _ in range(n):
   g.run();r=row();r['phase']=phase;trace.append(r)
   assert not g.read('v_errortype'),(label,r)
   if r['cpu']==4 and previous['cpu'] in (6,8) and r['sobRoutine']<6:
    index=g.get('v_player','standonobject');parent=(g.s['v_objspace']&65535)+index*g.s['object_size']
    valid=r['reach']==65535 and g.get(parent,'code') in (g.s['Obj1A'],g.s['Obj1B']) and g.get(parent,'obRoutine')==g.s['ledge_fragment_routine']
    if not valid:invalid.append(r)
   if g.get('v_player','obStatus')&8:
    index=g.get('v_player','standonobject');parent=(g.s['v_objspace']&65535)+index*g.s['object_size'];parents.add((g.get(parent,'code'),g.get(parent,'obX',2)))
   previous=r
 assert not invalid,(label,'unjustified direct flight',invalid[:1])
 if alive:assert all(r['sobRoutine']<6 and r['tobRoutine']<6 for r in trace),(label,'actor died')
 (args.output/(label+'-trace.json')).write_text(json.dumps(trace));g.video.save(args.output/(label+'.png'))
 data={'case':label,'frames':len(trace),'unjustified_flights':len(invalid),'cpu_states':sorted({r['cpu'] for r in trace}),'parents':sorted(parents),'lead_death':any(r['sobRoutine']>=6 for r in trace)};report.append(data);print(data,flush=True);return parents

def prime_history():
 for i in range(0,256,4):
  g.write(g.s['Sonic_Pos_Record_Buf']+i,g.get('v_player','obX',2),2);g.write(g.s['Sonic_Pos_Record_Buf']+i+2,g.get('v_player','obY',2),2)
  g.write(g.s['Sonic_Stat_Record_Buf']+i,0,4)

for act in (1,2):
 boot_level(g,zone=8,act=act-1);assert g.read('Current_ZoneAndAct',2)==0x800+act-1;base=g.save()
 terrain=(ROOT/'art/kosinski/level/8x8 - SMZ.unc').read_bytes();actual=bytes(g.vram[i^1] for i in range(len(terrain)));assert terrain==actual,'terrain art overwritten'
 slow=[('approach',(7,),72),('brake',(6,),24),('full-stop',(),80),('restart',(7,),30),('tap-jump',(7,8),5),('release',(),44),('land',(),15)]
 run(f'act-{act}-slow-stop-restart',slow)
 g.restore(base);run(f'act-{act}-fast',[('run',(7,),90),('jump',(7,8),18),('run-on',(7,),45),('stop',(),140)],alive=False)
 g.restore(base)
 if act==1:
  place(g,'v_player',480,1164,False);place(g,'v_player2',448,1168,False);prime_history();g.write('Camera_X_pos',320,2);g.write('Camera_Y_pos',1068,2);reset_cpu(g);g.run(3)
  run('act-1-edge-approach',[('walk-to-lip',(7,),30)])
  trap=next(a for a in objects(g,0xa3) if g.get(a,'obX',2)==576);g.buttons=set();waited=0
  for _ in range(600):
   g.run();waited+=1
   assert g.read('Tails_CPU_routine',2) in (6,8),'resting ledge caused a respawn/flight'
   assert g.get('v_player2','obRoutine')==2
   if g.get(trap,'obFrame')==0 and g.get(trap,'obAnim')==1 and g.read(trap+g.s['objoff_30'],2)>100:break
  else:raise AssertionError('trap did not close')
  report.append({'case':'act-1-wait-on-edge','frames':waited,'passed':True})
  parents=run('act-1-platform-by-platform',[('first-tap',(7,8),5),('first-steer',(7,),10),('first-landing',(),40),('second-tap',(7,8),5),('second-steer',(7,),24),('second-landing',(),30),('wait',(),80)])
  assert (g.s['SMZ_SpinPlatform'],576) in parents and (g.s['SMZ_Invisibarrier'],656) in parents,parents
  g.restore(base)
 # Contact tests use objects at their original stage positions.
 g.restore(base)
 if act==1:
  x,y=0x590,0x470
  for actor in ('v_player','v_player2'):place(g,actor,x-44,y);g.put(actor,'obControl',0x81)
  g.write('Camera_X_pos',x-160,2);g.write('Camera_Y_pos',y-112,2);g.run(3)
  junction=next(a for a in objects(g,0xa0) if g.get(a,'obX',2)==x and g.get(a,'obRoutine')==2)
  for _ in range(200):
   g.run()
   if g.get(junction,'obFrame')==14:break
  else:raise AssertionError('junction phase not reached')
  for actor in ('v_player','v_player2'):g.put(actor,'obControl',0);g.put(actor,'obVelX',0x100,2);g.put(actor,'obInertia',0x100,2)
  g.buttons=g.buttons2={7};reset_cpu(g);g.run(2)
  assert all(g.get(a,'obControl')==0x81 for a in ('v_player','v_player2')),'junction did not capture both'
  g.buttons=g.buttons2=set();g.run(90)
  assert all(g.get(a,'obControl')==0 for a in ('v_player','v_player2')) and not g.read('v_errortype')
  report.append({'case':'junction-independent-capture-release','passed':True})
 else:
  x,y=0x94,0x190
  for actor in ('v_player','v_player2'):place(g,actor,x-3,y)
  g.write('Camera_X_pos',0,2);g.write('Camera_Y_pos',288,2);reset_cpu(g);prime_history();g.run(2)
  assert all(g.get(a,'obControl')==0x81 for a in ('v_player','v_player2')),'pipe did not capture both'
  g.run(120)
  assert all(g.get(a,'obControl')==0 for a in ('v_player','v_player2')) and not g.read('v_errortype')
  report.append({'case':'pipe-independent-capture-release','passed':True})
  g.restore(base);x,y=0x2b0,0x750
  for actor,dy in [('v_player',67),('v_player2',63)]:place(g,actor,x,y-dy,False)
  g.write('Camera_X_pos',x-160,2);g.write('Camera_Y_pos',y-160,2);reset_cpu(g);prime_history();g.run(2)
  assert all(g.get(a,'stick_to_convex') and g.get(a,'obInertia',2)==0x400 for a in ('v_player','v_player2')),'disc did not affect both'
  report.append({'case':'disc-two-actor-attachment','passed':True})
 if act==1:
  for subtype in (0,2,0x10,0x12,0x20,0x22,0x30,0x32,0x40,0x42):
   g.restore(base);x,y=270,(1200 if subtype>>4==1 else 1152);spring=spawn(g,'Obj41',x,y,subtype);g.run(2)
   for actor,radius in [('v_player',19),('v_player2',15)]:
    if subtype>>4==0:xx,yy,vx,vy=x,y-8-radius-1,0,0x200
    elif subtype>>4==1:xx,yy,vx,vy=x+28,y,-0x400,0
    elif subtype>>4==2:xx,yy,vx,vy=x,y+8+radius+1,0,-0x400
    elif subtype>>4==3:xx,yy,vx,vy=x+12,y-30-radius,0,0x300
    else:xx,yy,vx,vy=x+12,y+30+radius,0,-0x400
    place(g,actor,xx,yy,subtype>>4!=1);g.put(actor,'obVelX',vx,2);g.put(actor,'obInertia',vx,2);g.put(actor,'obVelY',vy,2)
   reset_cpu(g);g.buttons2={4};launched=set();strength=0xa00 if subtype&2 else 0x1000
   for _ in range(25):
    g.run();assert not g.read('v_errortype')
    for actor in ('v_player','v_player2'):
     vx,vy=g.get(actor,'obVelX',2),g.get(actor,'obVelY',2)
     if (subtype>>4==1 and vx==strength) or (subtype>>4 in (0,3) and vy==(-strength&65535)) or (subtype>>4 in (2,4) and vy==strength):launched.add(actor)
   assert len(launched)==2,(subtype,launched)
   report.append({'case':f'spring-{subtype:02X}-both-actors','passed':True})
   # Airborne side contacts must also launch, as in S3&K.
   if subtype>>4==1:
    g.restore(base);spring=spawn(g,'Obj41',270,1152,subtype);g.run(2)
    for actor in ('v_player','v_player2'):place(g,actor,298,1152);g.put(actor,'obVelX',-0x400,2)
    reset_cpu(g);g.buttons2={4};launched=set()
    for _ in range(8):
     g.run()
     for actor in ('v_player','v_player2'):
      if g.get(actor,'obVelX',2)==strength:launched.add(actor)
    assert len(launched)==2,(subtype,'airborne side contact',launched)
    report.append({'case':f'airborne-side-spring-{subtype:02X}','passed':True})
 g.buttons=g.buttons2=set()
 if not args.skip_sweep:
  rows=[(x,y,oid,sub) for x,y,oid,eras,sub in decode((ROOT/f'level/objects/SMZ_{act}.bin').read_bytes())];seen=set();count=0
  for index,(x,y,oid,subtype) in enumerate(rows):
   g.restore(base);py=y&0xfff
   for a,offset in [('v_player',64),('v_player2',96)]:place(g,a,max(0,x-offset),max(32,py-64));g.put(a,'obControl',0x81)
   g.write('Camera_X_pos',max(0,x-160),2);g.write('Camera_Y_pos',max(0,min(0x720,py-112)),2)
   visible=False;found=False
   for _ in range(100):
    g.run();assert not g.read('v_errortype'),(act,index,hex(oid),x,py)
    # Remembered records retain their manager tag; children can share it.
    owners=[a for a in objects(g) if g.get(a,'respawn_addr',2)==g.placement_handle(index)]
    found|=bool(owners);visible|=any(g.get(a,'obRender')&128 for a in owners)
   assert found,(act,index,hex(oid),'placement not loaded')
   if oid not in seen:g.video.save(args.output/f'act-{act}-object-{oid:02X}.png')
   seen.add(oid);count+=1
  report.append({'case':f'act-{act}-all-placements','count':count,'ids':[f'{i:02X}' for i in sorted(seen)],'passed':True});print(report[-1],flush=True)
 # Reuse this core safely: return to the title mode before boot_level's next call.
 if act==1:
  g.restore(base);g.write('v_gamemode',g.s['SegaScreen'],2);g.run(1)
(args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n');g.close()
