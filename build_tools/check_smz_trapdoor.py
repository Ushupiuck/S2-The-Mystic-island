#!/usr/bin/env python3
"""Execute Sonic-only trapdoor closure/landing cases in the assembled ROM."""
from pathlib import Path
import argparse
import json

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--rom',type=Path,required=True)
p.add_argument('--listing',type=Path,required=True)
p.add_argument('--output',type=Path)
args=p.parse_args()
import native_test_core as m68k
m=m68k.Native(args.rom, args.listing)
obj=m.s['v_lvlobjspace']


def setup(x,y,vx,vy=0,status=0):
    m.start()
    m.put('v_player2','obRender',0)
    m.write('Camera_X_pos',400,2)
    # Advance from the final closing animation step to its first solid frame.
    for field,value,size in [('code',m.s['SMZ_SpinPlatform'],4),('obX',576,2),
            ('obY',1196,2),('obRoutine',2,1),('obMap',m.s['Map_SMZ_Trap'],4),
            ('obRender',0x84,1),('obActWid',64,1),('obAnim',1,1),
            ('obPrevAni',1,1),('obFrame',1,1),('obAniFrame',2,1),
            ('obTimeFrame',0,1),('SMZ_spin_timer',1000,2),('SMZ_spin_timelen',120,2)]:
        m.put(obj,field,value,size)
    for field,value,size in [('obX',x,2),('obY',y,2),('obVelX',vx,2),
            ('obInertia',vx,2),('obVelY',vy,2),('obStatus',status,1)]:
        m.put('v_player',field,value,size)


checks=[]
for x,direction in ((504,1),(648,-1)):
    for speed in (0x100,0x400,0x600):
        for depth in (-4,0,2,6,12):
            vx=direction*speed
            setup(x,1184-19+depth,vx)
            m.act('SMZ_Spin_Trapdoor',obj)
            assert m.get(obj,'obFrame')==0
            assert m.get('v_player','obVelX',2)==vx&65535,(x,speed,depth,'stopped')
            assert m.get('v_player','obInertia',2)==vx&65535
            assert m.get('v_player','obX',2)==x,(x,speed,depth,'pushed sideways')
            if depth==-4:
                assert m.get('v_player','obY',2)==1161
                assert not m.get('v_player','obStatus')&8
            else:
                assert m.get('v_player','obY',2)==1164,(x,speed,depth,m.get('v_player','obY',2),m.get('v_player','obStatus'))
                assert m.get('v_player','obStatus')&8
            assert not m.get('v_player','obStatus')&32
            checks.append({'case':'closing-edge-landing','x':x,'speed':vx,'foot_depth':depth})

# Rising into a closed door still hits its underside; this is not a one-way
# conversion. Standing on a closed door and release on opening stay intact.
setup(576,1221,0,vy=-0x200,status=2)
m.act('SMZ_Spin_Trapdoor',obj)
assert m.get('v_player','obVelY',2)==0
assert m.get('v_player','obY',2)==1227
assert not m.get('v_player','obStatus')&8
checks.append({'case':'closed-underside-blocks-jump','passed':True})
setup(576,1164,0)
m.act('SMZ_Spin_Trapdoor',obj)
assert m.get('v_player','obStatus')&8
for _ in range(8):
    m.act('SMZ_Spin_Trapdoor',obj)
    assert m.get('v_player','obY',2)==1164
checks.append({'case':'closed-ride-height','passed':True})
for field,value in [('obAnim',0),('obPrevAni',0),('obAniFrame',1),('obTimeFrame',0)]:
    m.put(obj,field,value)
m.act('SMZ_Spin_Trapdoor',obj)
assert m.get(obj,'obFrame')==1
assert not m.get('v_player','obStatus')&8
assert m.get('v_player','obStatus')&2
checks.append({'case':'opening-releases-rider','passed':True})
report={'passed':True,'checks':checks,'companion_ai_run':False}
if args.output:
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
print(f'{len(checks)} Sonic-only trapdoor landing, underside, support and release checks pass.')
