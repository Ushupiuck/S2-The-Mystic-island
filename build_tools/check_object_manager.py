#!/usr/bin/env python3
"""Run the assembled S3&K manager/Debug regressions with optional Unicorn.

Build first with build.lua. This executes the ROM's 68000 instructions; only
external sound, DMA hardware, and the HUD's VDP writer are stubbed. Fixtures
use the real six-byte placement records and an independent window model.
"""
from pathlib import Path
import argparse
import struct
from itertools import product

from native_test_core import (Native, Manager, UC_M68K_REG_A0, UC_M68K_REG_A1,
                              UC_M68K_REG_A2, UC_M68K_REG_A3, UC_M68K_REG_A4,
                              UC_M68K_REG_D0, UC_M68K_REG_D1, UC_M68K_REG_D2,
                              UC_M68K_REG_D3, UC_M68K_REG_D4, UC_M68K_REG_D5,
                              UC_M68K_REG_D6, UC_M68K_REG_D7, UC_M68K_REG_SR)

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
parser.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
args = parser.parse_args()


def eligible(rows,x,y,wrap=False):
    x=x&0xFF80
    y=y&0xFF80
    lo=max(0,x-128)
    hi=x+640
    top=y-128
    bottom=y+512
    if wrap:
        top&=0x7FF
        bottom&=0x7FF
    else:
        top=max(top,0)
    return {i for i,(px,py,*_) in enumerate(rows) if lo<=px<hi and (py&0x8000 or (top<=py&0xFFF<=bottom if top<=bottom else (py&0xFFF>=top or py&0xFFF<=bottom)))}

m=Manager(args.rom, args.listing)
report={}
cases=0
# Every act uses the existing four-act zone math and the correct ROM layout.
names=['GHZ','LZ','CPZ','EHZ','HPZ','HTZ','MTZ','LV07','SMZ','LV09','LV0A','LV0B','LV0C','LV0D','LV0E','LV0F']
for z,n in enumerate(names):
    for act in range(4):
        m.start()
        m.write('Current_ZoneAndAct',(z<<8)|act,2)
        m.cam(0,0)
        m.act('ObjectsManager')
        rows=m.rows(f'{n}_{act+1}.bin')
        base=m.s[f'ObjPos_{n}{act+1}']
        live=m.verify(rows,base)
        ids={(p-m.respawn_base)&65535 for p in live}
        assert ids==eligible(rows,0,0),(n,act,ids,eligible(rows,0,0))
        m.act('ObjectsManager')
        m.verify(rows,base)
        cases+=1
report['real_acts']=cases
# Dense boundaries, all four flip combinations, bypass flags and a full-byte ID.
rows=sorted([(x,y|flags,0x36,0xA0) for x in (0,127,128,255,256,639,640,768,896,1024) for y,flags in [(0,0),(128,0x2000),(256,0x4000),(512,0x6000),(1408,0x8000)]])
rows.append((1100,0x8100,0xFC,7))
rows.sort()
base=m.fixture(rows)
m.cam(0,0)
m.act('ObjectsManager')
m.verify(rows,base)
for x,y in [(128,0),(256,128),(384,256),(512,384),(768,512),(1024,0),(128,768),(0,0)]:
    m.cam(x,y)
    # Deletion uses the current X range; only use the owner lifetime helper here.
    m.write('Camera_X_pos_coarse_back',(x-128)&0xFF80,2)
    for a in list(m.live().values()):
        m.act('MarkObjGone2',a)
    m.act('ObjectsManager')
    live=m.verify(rows,base)
    loaded={(p-m.respawn_base)&65535 for p in live}
    assert eligible(rows,x,y)<=loaded,(x,y,eligible(rows,x,y)-loaded)
    m.act('ObjectsManager')
    assert live==m.verify(rows,base)
report['horizontal_backtracking_flips_full_byte_id']=True
# Vertical-only movement in both directions, large jumps and $800 wrapping.
for wrap in (False,True):
    rows=[(256,y|((i&3)<<13),0x36,0xA0) for i,y in enumerate(range(0,2048,64))]+[(300,0x8E00,0x41,0)]
    base=m.fixture(rows)
    m.write('Camera_Min_Y_pos',0xFF00 if wrap else 0,2)
    for y in [0,128,256,384,768,1536,1920,0,1920,1792,640,0]:
        m.cam(256,y)
        m.act('ObjectsManager')
        live=m.verify(rows,base)
        loaded={(p-m.respawn_base)&65535 for p in live}
        assert eligible(rows,256,y,wrap)<=loaded,(wrap,y,eligible(rows,256,y,wrap)-loaded)
report['vertical_bands_jumps_and_wrap']=True
# Exhausted pool: no flag may be set without a real SST. Retry even if the
# camera remains still, preserve cursor pairing, and use all 90 slots exactly.
rows=[(256,128,0x36,i) for i in range(95)]
base=m.fixture(rows)
for a in m.pool():
    m.put(a,'layout_id',0x35)
m.cam(0,0)
m.act('ObjectsManager')
assert not m.live() and m.read('Object_load_retry')
assert m.placement_data(95)==bytes(95)
for a in list(m.pool())[::2]:
    m.act('DeleteObject',a)
m.act('ObjectsManager')
assert len(m.verify(rows,base))==45 and m.read('Object_load_retry')
for a in m.pool():
    if m.get(a,'layout_id')==0x35:
        m.act('DeleteObject',a)
m.act('ObjectsManager')
assert len(m.verify(rows,base))==90 and m.read('Object_load_retry')
# Destroyed placements are consumed, freeing five slots for the remainder.
for a in list(m.live().values())[:5]:
    m.act('DeleteObject',a)
m.act('ObjectsManager')
assert len(m.verify(rows,base))==90 and not m.read('Object_load_retry')
report['pool_exhaustion_stationary_retry']=True
# No byte-index wrap at placement 255. All 768 reserved entries are addressable.
rows=[(i*16,128,0x41,0) for i in range(768)]
base=m.fixture(rows)
for x in range(0,12288,128):
    m.cam(x,0)
    m.write('Camera_X_pos_coarse_back',(x-128)&0xFF80,2)
    for a in list(m.live().values()):
        m.act('MarkObjGone2',a)
    m.act('ObjectsManager')
    live=m.verify(rows,base)
    loaded={(p-m.respawn_base)&65535 for p in live}
    assert eligible(rows,x,0)<=loaded,(x,eligible(rows,x,0)-loaded)
report['full_768_placement_table']=True
# A preserved table survives reinitialization, and a normal new layout clears it.
m.start()
m.placement_write(0,b'\x21'*768)
m.write('Respawn_table_keep',1)
m.cam(0,0)
m.act('ObjectsManager')
assert m.placement_data(768)[-1]==0x21
m.write('Obj_placement_routine',0)
m.write('Respawn_table_keep',0)
m.act('ObjectsManager')
assert m.placement_data(768)[-1]==0
report['reset_keep_state']=True
print(report,flush=True)

# Object ownership and Debug regressions use a fresh RAM/ROM machine.
m=Native(args.rom, args.listing)
report={}
def pool():
    return list(range(m.s['v_lvlobjspace'],m.s['v_lvlobjend'],m.s['object_size']))
def setup(objid,sub=0,state=0x80):
    m.start()
    obj=pool()[0]
    ptr=m.respawn_base
    for f,v,n in [('layout_id',objid,1),('obX',240,2),('obY',240,2),('obSubtype',sub,1),('respawn_addr',ptr,2)]:
        m.put(obj,f,v,n)
    m.placement_write(0,state)
    return obj,ptr
# Loaded tags stay set during initialization, and persistent state survives unload.
for state in (0x80,0x81):
    obj,ptr=setup(0x26,0,state)
    m.act('Obj26',obj)
    assert m.placement_read()==state
    assert (m.get(obj,'obRoutine')==8)==bool(state&1)
    m.write('Camera_X_pos_coarse_back',0x1000,2)
    m.act('Obj26',obj)
    assert m.get(obj,'layout_id')==0 and m.placement_read()==state&127
obj,ptr=setup(0x26)
m.act('Obj26',obj)
m.put(obj,'obRoutine',4)
m.act('Obj26',obj)
assert m.placement_read()==0x81
for state in (0x80,0x81):
    obj,ptr=setup(0x79,1,state)
    m.act('Obj79',obj)
    assert m.placement_read()==state
    m.act('UnloadObject',obj)
    assert m.placement_read()==state&127
# Zero respawn pointers must not alter a real placement's state.
for objid,routine in ((0x26,'Obj26'),(0x79,'Obj79'),(0x47,'Obj47')):
    obj,ptr=setup(objid)
    m.put(obj,'respawn_addr',0,2)
    m.act(routine,obj)
    m.act('UnloadObject',obj)
    assert m.placement_read()==0x80
report['monitor_checkpoint_and_zero_pointer_state']=True
# Bumper score cap remains local to one placement, even after unloading.
obj,ptr=setup(0x47,state=0x89)
m.act('Obj47',obj)
m.act('Bumper_bump',obj,{UC_M68K_REG_A1:m.s['v_player']})
assert m.placement_read()==0x8A
score=m.read('v_score',4)
m.act('Bumper_bump',obj,{UC_M68K_REG_A1:m.s['v_player']})
assert m.read('v_score',4)==score
m.act('UnloadObject',obj)
assert m.placement_read()==10
report['bumper_cap_persists']=True
# Compound initializers must handle zero/one remaining helper slots atomically.
for objid,sub,routine,fields,needed in [(0x1D,16,'Bridge',('Bridge_child1','Bridge_child2'),2),(0x1E,0x10,'HPZ_Waterfall',('objoff_3C','objoff_40'),2),(0x50,0x11,'Obj50',('objoff_3A',),1)]:
    for free in range(needed):
        obj,ptr=setup(objid,sub)
        for a in pool()[1:]:
            m.put(a,'layout_id',0x55)
        for a in pool()[1:1+free]:
            m.put(a,'layout_id',0)
        m.act(routine,obj)
        assert m.get(obj,'obRoutine')==0 and m.placement_read()==0x80,(routine,free)
        assert all(m.get(obj,f,4)==0 for f in fields),(routine,'half parent')
        assert sum(m.get(a,'layout_id')==0 for a in pool()[1:])==free,(routine,'leak')
        for a in pool()[1:1+needed]:
            m.put(a,'layout_id',0)
        m.act(routine,obj)
        assert m.get(obj,'obRoutine')!=0
        assert all(m.get(obj,f,4) for f in fields)
        for f in fields:
            child=m.get(obj,f,4)&0xFFFFFF
            if objid!=0x1D:
                assert m.get(child,'respawn_addr',2)==0
report['multipart_pool_exhaustion_and_retry']=5
# Both riders update their private log indexes. An old literal offset here
# used to overwrite the low byte of the second helper pointer in real demos.
obj,ptr=setup(0x1D,16)
m.act('Bridge',obj)
children=tuple(m.get(obj,f,4) for f in ('Bridge_child1','Bridge_child2'))
m.put(obj,'obStatus',0x18)
for player,x in (('v_player',256),('v_player2',192)):
    m.put(player,'obX',x,2)
    m.put(player,'obStatus',8)
m.act('Bridge',obj)
assert tuple(m.get(obj,f,4) for f in ('Bridge_child1','Bridge_child2'))==children
assert m.get(obj,'objoff_43')==9 and m.get(obj,'objoff_3F')==5
for _ in range(20):
    m.act('Bridge',obj)
    assert tuple(m.get(obj,f,4) for f in ('Bridge_child1','Bridge_child2'))==children
report['bridge_two_riders_preserve_helper_pointers']=True
# Negative Y speed on an uphill slope is grounded motion, not a rising jump.
for player in ('v_player','v_player2'):
    for vy in (0,0x100,0xFF00):
        obj,ptr=setup(0x26,1)
        m.act('Obj26',obj)
        m.put(player,'obX',240,2);m.put(player,'obY',240,2)
        m.put(player,'obAnim',m.s['AniIDSonAni_Roll'])
        m.put(player,'obStatus',4);m.put(player,'obVelY',vy,2)
        m.act('loc_198FA',player,{UC_M68K_REG_A1:obj|0xFF000000})
        assert m.get(obj,'obRoutine')==4 and m.get(obj,'obParent',2)==m.s[player]&65535
    obj,ptr=setup(0x26,1);m.act('Obj26',obj)
    m.put(player,'obY',260,2);m.put(player,'obStatus',6)
    m.put(player,'obAnim',m.s['AniIDSonAni_Roll']);m.put(player,'obVelY',0xFF00,2)
    m.act('loc_198FA',player,{UC_M68K_REG_A1:obj|0xFF000000})
    assert m.get(obj,'obRoutine')==2 and m.get(obj,'ob2ndRout')==4
report['monitor_ground_roll_slopes_and_airborne_underside']=8
# A held charge is still solid when falling onto a monitor. Rolling attacks
# use TouchResponse instead; these states must not leave a collision gap.
for player,character in [('v_player',1),('v_player',2),('v_player2',2)]:
    obj,ptr=setup(0x26,6)
    m.put(player,'layout_id',character)
    m.write('Player_mode',m.s['PlayerMode_Tails'] if player=='v_player' and character==2 else 0,2)
    m.act('Obj26',obj)
    for field,value,size in [('obX',240,2),('obY',207,2),('obVelY',0x400,2),
            ('obStatus',2,1),('obAnim',m.s['AniIDSonAni_Spindash'],1),
            ('spindash_flag',1,1),('spindash_counter',0x600,2)]:
        m.put(player,field,value,size)
    m.act('Monitor_SolidCharacter',obj,{
        UC_M68K_REG_A1:m.s[player]&0xFFFFFFFF,UC_M68K_REG_D1:0x1A,
        UC_M68K_REG_D2:0xF,UC_M68K_REG_D3:0x10,UC_M68K_REG_D4:240,
        UC_M68K_REG_D6:3 if player=='v_player' else 4})
    assert m.get(player,'obStatus')&8 and not m.get(player,'obStatus')&2
    assert m.get(obj,'obRoutine')==2 and m.get(player,'spindash_flag')==1
    assert m.get(player,'spindash_counter',2)==0x600
report['held_charge_lands_on_monitor_for_all_player_roles']=True

# Harmful monitor rewards must mutate the collector, never the floating icon.
# Cover shields/zero rings and both invulnerability protections, including the
# companion's intentional immunity to scattering the shared ring inventory.
damage_cases=0
for player,character in [('v_player',1),('v_player',2),('v_player2',2)]:
    for rings,shield,invincible,flashing in product((0,30),(False,True),(False,True),(False,True)):
        m.start()
        m.put(player,'layout_id',character)
        m.write('Player_mode',m.s['PlayerMode_Tails'] if player=='v_player' and character==2 else 0,2)
        m.write('v_rings',rings,2)
        m.put(player,'obStatusSecondary',int(shield)|(int(invincible)<<m.s['obStatusSecondary_isInvincible']))
        m.put(player,'flashtime',8 if flashing else 0,2)
        icon=pool()[0]
        for field,value,size in [('code',m.s['Obj29'],4),('obRoutine',4,1),
                ('obAnim',0,1),('obParent',m.s[player]&65535,2),('obX',600,2),('obY',180,2)]:
            m.put(icon,field,value,size)
        before=bytes(m.cpu.mem_read(icon&0xFFFFFF,m.s['object_size']))
        partner='v_player2' if player=='v_player' else 'v_player'
        other=bytes(m.cpu.mem_read(m.s[partner]&0xFFFFFF,m.s['object_size']))
        m.act('Monitor_Null',icon,{UC_M68K_REG_A1:m.s[player]&0xFFFFFFFF})
        assert m.cpu.reg_read(UC_M68K_REG_A0)&0xFFFFFF==icon&0xFFFFFF
        assert bytes(m.cpu.mem_read(icon&0xFFFFFF,m.s['object_size']))==before
        assert bytes(m.cpu.mem_read(m.s[partner]&0xFFFFFF,m.s['object_size']))==other
        protected=invincible or flashing
        expected=2 if protected else (4 if shield or rings else 6)
        assert m.get(player,'obRoutine')==expected,(player,rings,shield,invincible,flashing)
        assert bool(m.get(player,'obStatusSecondary')&1)==(shield and protected)
        scatters=[a for a in pool() if m.get(a,'code')==m.s['Obj13']]
        assert bool(scatters)==(not protected and not shield and rings>0 and player=='v_player')
        damage_cases+=1
    for routine,present in [(0,False),(4,True),(6,True)]:
        m.start()
        m.put(player,'code',m.s['Obj01' if character==1 else 'Obj02'] if present else 0)
        m.put(player,'obRoutine',routine)
        icon=pool()[0];m.put(icon,'code',m.s['Obj29']);m.put(icon,'obRoutine',4)
        before=bytes(m.cpu.mem_read(m.s[player]&0xFFFFFF,m.s['object_size']))
        m.act('Monitor_Null',icon,{UC_M68K_REG_A1:m.s[player]&0xFFFFFFFF})
        assert bytes(m.cpu.mem_read(m.s[player]&0xFFFFFF,m.s['object_size']))==before
report['harmful_monitor_targets_collector_and_preserves_icon']=damage_cases

# Drive the complete giant-ring flash, including its terminal state. The old
# extra stack pop escaped the direct object dispatcher instead of returning.
for primary in (1,2):
    m.start();m.put('v_player','layout_id',primary)
    parent,flash=pool()[:2]
    for field,value,size in [('code',m.s['GiantRing'],4),('obRoutine',2,1)]:
        m.put(parent,field,value,size)
    for field,value,size in [('code',m.s['GiantRingFlash'],4),
            ('objoff_40',parent&0xFFFFFFFF,4),('obX',600,2),('obY',116,2)]:
        m.put(flash,field,value,size)
    for tick in range(30):
        m.act('GiantRingFlash',flash)
        if not m.get('v_player','code'):
            break
    else:
        raise AssertionError('Giant-ring flash did not hide the primary player')
    assert m.read('f_bigring')==1 and m.read('v_gfxbigring')==0
    assert m.get(flash,'obRoutine')==4
    m.act('GiantRingFlash',flash)
    assert not m.get(flash,'code')
report['giant_ring_final_frame_preserves_stack_and_clears_full_player_pointer']=True

# A real ROM pointer has a zero leading byte. A live player must finish
# leaving the screen; a hidden player can immediately queue the result card.
m.start()
sign=pool()[0];m.put(sign,'code',m.s['Signpost']);m.put(sign,'obRoutine',6)
m.write('Camera_Max_X_pos',600,2);m.put('v_player','obX',600,2)
m.act('Signpost_EndLevel',sign)
assert m.get(sign,'obRoutine')==6 and not m.get('v_endcard','code')
m.put('v_player','code',0)
m.act('Signpost_EndLevel',sign)
assert m.get(sign,'obRoutine')==8 and m.get('v_endcard','code')==m.s['GotThrough']
m.write('v_timebonus',0x1234,2)
m.act('Load_EndOfAct',sign)
assert m.read('v_timebonus',2)==0x1234,'Existing result card was restarted'
report['signpost_and_result_card_use_full_pointer_existence']=True
# Dynamic objects do not consume a placement; explicit destruction does.
obj,ptr=setup(0x22,state=0x85)
m.act('DeleteObject',obj)
assert m.placement_read()==0x85
report['destruction_keeps_consumed_tag']=True
# Caterkiller's existing failed-allocation path retires its head and lets its
# partial chain clean itself up; only the head releases the placement byte.
for free in (0,1,2):
    obj,ptr=setup(0x60,state=0x85)
    for a in pool()[1:]:
        m.put(a,'layout_id',0x55)
    for a in pool()[1:1+free]:
        m.put(a,'layout_id',0)
    m.act('Caterkiller',obj)
    assert m.get(obj,'obRoutine')==10
    assert m.placement_read()==5
    children=[a for a in pool()[1:] if m.get(a,'layout_id')==0x60]
    assert len(children)==free and all(m.get(a,'respawn_addr',2)==0 for a in children)
    m.act('Cat_Delete',obj)
    assert m.get(obj,'layout_id')==0
report['caterkiller_owner_and_partial_allocation']=3
# Fragment copies are dynamic. The original collapsed scenery slot releases
# its placement when leaving the display area, retaining object-local bits.
obj,ptr=setup(0x1A,state=0x83)
m.put(obj,'obRoutine',4)
m.put(obj,'obRender',4)
m.act('Obj1A',obj)
assert m.placement_read()==3 and m.get(obj,'layout_id')==0
report['collapsed_scenery_releases_placement']=True
# Natural top/bottom wrapping keeps a small camera delta and redraws the row.
for camera,player,target,flag,delta in [(0xFF00,0x75F,0x6FF,1,0xFF00),(0x7FF,0x61,1,2,0x200)]:
    m.start()
    m.write('Camera_Min_Y_pos',0xFF00,2)
    m.write('Camera_Max_Y_pos',0x700,2)
    m.write('Camera_Y_pos',camera,2)
    m.write('Camera_Y_pos_bias',96,2)
    m.put('v_player','obY',player,2)
    m.put('v_player','obStatus',0)
    m.cpu.mem_write(0xFF9000,bytes(4))
    m.act('ScrollVertical','v_player',{UC_M68K_REG_A1:m.s['Camera_Y_pos'],UC_M68K_REG_A2:0xFF9000,UC_M68K_REG_A3:0xFF9002,UC_M68K_REG_A4:m.s['Camera_Y_pos_diff']})
    assert m.read('Camera_Y_pos',2)==target and m.read('Camera_Y_pos_diff',2)==delta
    assert m.cpu.mem_read(0xFF9002,1)[0]&flag
m.start()
obj,ptr=setup(7)
m.write('v_waterpos1',0x800,2)
before=bytes(m.cpu.mem_read(m.s['Object_Display_Lists']&0xFFFFFF,0x400))
m.act('WaterSurface_Main',obj)
assert bytes(m.cpu.mem_read(m.s['Object_Display_Lists']&0xFFFFFF,0x400))==before
report['vertical_wrap_redraw_and_hidden_water']=True


# Exercise actual player entry, initialized placement, list cycling, spawning,
# complete restoration, and frame count wrapping for both playable characters.
m.cpu.mem_write(m.s['HUD_Base'],bytes.fromhex('203CDEADC0DE4E75'))
for who,objid,mode,mapname,h,w in [('Sonic',1,1,'Map_Sonic',19,9),('Tails',2,2,'Map_Tails',15,9)]:
    m.start()
    m.write('Player_mode',mode,2)
    m.write('Debug_mode_flag',1)
    m.write('Camera_Min_Y_pos',0x80,2)
    m.write('Camera_Max_Y_pos_target',0x280,2)
    for f,v,n in [('layout_id',objid,1),('character_id',objid-1,1),('obMap',m.s[mapname],4),('obGfx',m.s['ArtTile_'+who],2),('height_pixels',m.s[mapname+'_height'],1),('width_pixels',m.s[mapname+'_width'],1),('default_y_radius',h,1),('default_x_radius',w,1),('obStatus',0x7D,1),('obRender',0x85,1)]:
        m.put('v_player',f,v,n)
    m.write('v_jpadpress1',m.s['btnB'])
    m.act('Obj01' if objid==1 else 'Obj02','v_player')
    assert m.read('Debug_placement_mode',2)==1
    m.write('v_jpadpress1',0)
    m.act('DebugMode','v_player')
    assert m.read('Debug_placement_mode',2)==0x201
    assert m.read('Debug_saved_mappings',4)==m.s[mapname]
    assert m.get('v_player','obMap',4)&0xFFFFFF==m.s['Map_Ring']
    m.write('v_jpadhold1',m.s['btnA'])
    m.write('v_jpadpress1',m.s['btnA'])
    m.act('DebugMode','v_player')
    assert m.read('Debug_object')==1
    m.write('v_jpadhold1',m.s['btnA']|m.s['btnC'])
    m.write('v_jpadpress1',m.s['btnC'])
    m.act('DebugMode','v_player')
    assert m.read('Debug_object')==0
    m.write('v_jpadhold1',0)
    m.write('v_jpadpress1',m.s['btnC'])
    m.act('DebugMode','v_player')
    placed=[a for a in pool() if m.get(a,'layout_id')==0x12]
    assert len(placed)==1 and m.get(placed[0],'respawn_addr',2)==0
    assert m.get(placed[0],'obStatus')==1, 'Debug placement lost the facing flag'
    for f,v,n in [('obVelX',0x1234,2),('obVelY',0x3456,2),('spindash_counter',0x9876,2),('obControl',0x81,1),('move_lock',0xABCD,2),('stick_to_convex',1,1),('tails_flight_flag',7,1),('tails_flight_energy',24,1)]:
        m.put('v_player',f,v,n)
    m.write('v_jpadpress1',m.s['btnB'])
    m.act('DebugMode','v_player')
    assert m.read('Debug_placement_mode',2)==0
    assert m.get('v_player','obMap',4)==m.s[mapname] and m.get('v_player','obGfx',2)==m.s['ArtTile_'+who]
    assert m.get('v_player','obHeight')==h and m.get('v_player','obWidth')==w
    assert m.get('v_player','obStatus')==3
    assert all(m.get('v_player',f,n)==0 for f,n in [('obVelX',2),('obVelY',2),('spindash_counter',2),('move_lock',2),('obControl',1),('stick_to_convex',1)])
    assert m.read('Camera_Min_Y_pos',2)==0x80 and m.read('Camera_Max_Y_pos_target',2)==0x280
    if objid==2:
        assert m.get('v_player','tails_flight_flag')==m.get('v_player','tails_hidden')==0
    m.write('v_jpadhold1',m.s['btnC'])
    m.act('Debug_Begin','v_player')
    assert m.read('Debug_placement_mode',2)==2
    m.put('v_player','obFrame',m.s[mapname+'_frames']-1)
    m.write('v_jpadpress1',0)
    m.act('DebugMode','v_player')
    assert m.get('v_player','obFrame')==0
    m.write('v_jpadpress1',m.s['btnB'])
    m.act('DebugMode','v_player')
    assert m.read('Debug_placement_mode',2)==0
report['primary_character_debug_restore_and_frame_cycle']=2

# Entry belongs before the player-state dispatch, so B also works during
# recoil and death. C+B keeps the existing frame-cycle entry in each state.
for objid,mode in ((1,1),(2,2)):
    for routine in (2,4,6):
        for held_c in (False,True):
            m.start();m.put('v_player','layout_id',objid)
            m.write('Player_mode',mode,2);m.write('Debug_mode_flag',1)
            m.put('v_player','obRoutine',routine)
            m.write('v_jpadpress1',m.s['btnB'])
            m.write('v_jpadhold1',m.s['btnC'] if held_c else 0)
            m.act('Obj01' if objid==1 else 'Obj02','v_player')
            assert m.read('Debug_placement_mode',2)==(2 if held_c else 1)
report['both_primary_characters_enter_debug_in_normal_hurt_and_death_states']=12
for objid,mode,mapname in ((1,1,'Map_Sonic'),(2,2,'Map_Tails')):
    m.start();m.put('v_player','layout_id',objid)
    m.write('Player_mode',mode,2);m.write('Debug_mode_flag',1)
    m.put('v_player','obRoutine',0);m.put('v_player','obControl',1)
    m.write('v_jpadpress1',m.s['btnB'])
    m.act('Obj01' if objid==1 else 'Obj02','v_player')
    assert not m.read('Debug_placement_mode',2)
    assert m.get('v_player','obMap',4)==m.s[mapname]
    assert m.get('v_player','obRoutine')==2
report['debug_cannot_skip_character_initialization']=True
# Companion controls remain active when player 1 uses Debug.
m.start()
m.write('Debug_mode_flag',1)
m.write('Debug_placement_mode',0x201,2)
m.write('v_jpadpress1',m.s['btnB'])
m.write('v_jpadhold2',m.s['btnB'])
m.act('Tails_Control','v_player2')
assert m.read('Debug_placement_mode',2)==0x201
report['companion_has_no_debug_access']=True
# Bonus-stage Debug keeps its return zone, stage mappings and collision radii.
m.start()
m.write('v_gamemode',m.s['BonusStage'],2)
m.write('Current_ZoneAndAct',0x301,2)
m.put('v_player','layout_id',4)
m.put('v_player','obMap',m.s['Map_Sonic'],4)
m.put('v_player','obGfx',m.s['ArtTile_Sonic'],2)
m.act('Debug_Begin','v_player')
m.write('v_jpadpress1',0)
m.act('DebugMode','v_player')
assert m.read('Current_ZoneAndAct',2)==0x301
assert m.get('v_player','obGfx',2)==m.s['ArtTile_SS_Rings']|0x2000
m.write('v_jpadpress1',m.s['btnC'])
m.act('DebugMode','v_player')
stage_ring=next(a for a in pool() if m.get(a,'layout_id')==0x12)
m.act('Obj12',stage_ring)
assert m.get(stage_ring,'obGfx',2)==m.s['ArtTile_SS_Rings']|0x2000
m.write('v_jpadpress1',m.s['btnB'])
m.act('DebugMode','v_player')
assert m.get('v_player','obHeight')==14 and m.get('v_player','obWidth')==7
assert m.read('v_ssrotate',2)==0x40 and m.read('Current_ZoneAndAct',2)==0x301
report['bonus_debug_return_zone_ring_bank_and_radii']=True
# A collected giant ring must remain renderable at every small-ring clock
# phase: its animation changes art, whereas its mappings have one frame.
for phase in range(8):
    m.start()
    m.write('Camera_X_pos',440,2)
    m.write('Camera_Y_pos',0,2)
    m.write('Camera_X_pos_copy',440,2)
    m.write('Camera_Y_pos_copy',0,2)
    a=next(iter(pool()))
    for field,value,size in [('layout_id',0x7B,1),('obRoutine',4,1),('obX',600,2),
            ('obY',116,2),('obRender',4,1),('obMap',m.s['Map_GiantRing'],4),
            ('obGfx',m.s['ArtTile_Giant_Ring'],2),('obPriority',0x100,2),
            ('obActWid',64,1),('height_pixels',32,1)]:
        m.put(a,field,value,size)
    m.write('v_ani1_frame',phase)
    m.act('GiantRing',a)
    assert m.get(a,'obFrame') < m.s['Map_GiantRing_frames']
    m.act('Render_Sprites')
    assert m.read('v_spritecount')==4
report['collected_giant_ring_renders_at_all_eight_small_ring_phases']=True
for mode,objid in [(m.s['PlayerMode_Sonic'],1),(m.s['PlayerMode_Tails'],2)]:
    m.start()
    m.write('Player_mode',mode,2)
    m.put('v_player','layout_id',0)
    a=next(iter(pool()))
    m.put(a,'layout_id',0x7A)
    m.put(a,'obj7A_vanishtime',1,2)
    m.act('Obj7A_LoadSonic',a)
    assert m.get('v_player','layout_id')==objid and not m.get(a,'layout_id')
report['warp_restores_both_primary_characters']=True
# The compiled S1 visibility helpers are not placement objects, but remain
# available to imported code. Exercise their centre/partial-width distinction.
for routine,left_visible in [('ChkObjectVisible',False),('ChkPartiallyVisible',True)]:
    for x,y,visible in [(395,116,left_visible),(400,116,True),
                         (735,116,routine=='ChkPartiallyVisible'),
                         (736,116,False),(560,224,False)]:
        m.start()
        m.write('Camera_X_pos',400,2)
        m.write('Camera_Y_pos',0,2)
        a=pool()[0]
        m.put(a,'obX',x,2)
        m.put(a,'obY',y,2)
        m.put(a,'obActWid',16)
        m.act(routine,a)
        assert bool(m.cpu.reg_read(UC_M68K_REG_D0)==0)==visible,(routine,x,y)
report['legacy_visibility_helper_edges']=True
# Direct dispatch must accept routines outside Obj_Index, process the final
# slot, and honor a routine pointer changed by the preceding state.
m.start()
m.cpu.mem_write(m.s['v_objspace']&0xFFFFFF,
                bytes(m.s['object_size']*m.s['object_slot_count']))
first,second=0x3E0000,0x3E0040
m.cpu.mem_write(first,bytes.fromhex('317C1357')+
    struct.pack('>H',m.s['obVelX'])+bytes.fromhex('20BC')+
    struct.pack('>I',second)+bytes.fromhex('4E75'))
m.cpu.mem_write(second,bytes.fromhex('317C2468')+
    struct.pack('>H',m.s['obVelX'])+bytes.fromhex('20BC000000004E75'))
slots=[m.s['v_objspace'],m.s['v_objend']-m.s['object_size']]
assert first not in m.object_codes and second not in m.object_codes
for a in slots:m.put(a,'code',first)
m.act('ExecuteObjects')
for a in slots:
    assert m.get(a,'obVelX',2)==0x1357 and m.get(a,'code')==second
m.act('ExecuteObjects')
for a in slots:
    assert m.get(a,'obVelX',2)==0x2468 and not m.get(a,'code')
report['direct_pointer_dispatch_state_changes_and_final_slot']=True

# Both alive and deleted queued objects have a zero leading byte. Only a
# full-longword existence test can distinguish them.
m.start()
m.write('Camera_X_pos',0,2);m.write('Camera_Y_pos',0,2)
m.write('Camera_X_pos_copy',0,2);m.write('Camera_Y_pos_copy',0,2)
for a in slots:
    for field,value,size in [('code',first,4),('obX',160,2),('obY',112,2),
            ('obMap',m.s['Map_Ring'],4),('obGfx',m.s['ArtTile_Ring'],2),
            ('width_pixels',16,1),('height_pixels',16,1),('obPriority',0,2),
            ('obFrame',0,1),('obRender',4,1)]:
        m.put(a,field,value,size)
    m.act('DisplaySprite',a)
m.put(slots[-1],'code',0)
m.act('Render_Sprites')
assert m.read('v_spritecount')==1
report['full_pointer_existence_and_deleted_queue_guard']=True

# The AI's remembered interaction must compare all 32 bits. Test equal
# pointers and different pointers with identical low words.
for standing,respawns in [(0x3E1000,False),(0x3F1000,True)]:
    m.start()
    a=pool()[0]
    m.put(a,'code',standing)
    m.put('v_player2','obRender',4)
    m.put('v_player2','obStatus',1<<m.s['status.player.on_object'])
    m.put('v_player2','standonobject',m.s['reserved_object_slots'])
    m.write('Tails_CPU_interact',0x3E1000,4)
    m.write('Tails_CPU_routine',0,2)
    m.act('TailS3_sub_13EFC','v_player2')
    assert (m.read('Tails_CPU_routine',2)==2)==respawns
report['tails_cpu_remembers_full_routine_pointer']=True
# Switching source art must upload again even when its frame number matches.
for player,destination,cache in [('v_player',0xFC00,'v_splash'),('v_player2',0xFE00,'v_tsplash')]:
    m.start();m.uploads.clear()
    for table,art,kind in [('DPLC_SpindashDust','Art_SpindashDust','WaterArt_Dust'),('DPLC_Splash','Art_WaterSplash','WaterArt_Splash'),('DPLC_SpindashDust','Art_SpindashDust','WaterArt_Dust')]:
        regs={UC_M68K_REG_D0:1,UC_M68K_REG_A2:m.s[table],UC_M68K_REG_D4:destination,UC_M68K_REG_D5:m.s[kind],UC_M68K_REG_D6:m.s[art]}
        before=len(m.uploads)
        m.act('PlayerWaterArt_LoadDPLC',regs=regs)
        assert len(m.uploads)>before and m.uploads[-1][1]&65535==destination
        assert m.get(cache,'water_loaded_kind')==m.s[kind]
        m.act('PlayerWaterArt_LoadDPLC',regs=regs)
        assert len(m.uploads)==before+1
    m.write('VDP_Command_Buffer_Slot',m.s['VDP_Command_Buffer_Slot']&65535,2)
    regs={UC_M68K_REG_D0:1,UC_M68K_REG_A2:m.s['DPLC_Splash'],UC_M68K_REG_D4:destination,UC_M68K_REG_D5:m.s['WaterArt_Splash'],UC_M68K_REG_D6:m.s['Art_WaterSplash']}
    m.act('PlayerWaterArt_LoadDPLC',regs=regs)
    assert m.get(cache,'water_loaded_frame')==255 and m.cpu.reg_read(UC_M68K_REG_SR)&1
    m.write('VDP_Command_Buffer_Slot',m.s['VDP_Command_Buffer']&65535,2)
    m.act('PlayerWaterArt_LoadDPLC',regs=regs)
    assert m.get(cache,'water_loaded_frame')==1 and not m.cpu.reg_read(UC_M68K_REG_SR)&1
    for frame in range(9,19):
        obj=pool()[0]
        m.put(obj,'obParent',m.s[player]&65535,2);m.put(obj,'obFrame',frame)
        m.act('Obj0A_LoadArt',obj)
        assert m.uploads[-1][1]&65535==destination and m.uploads[-1][2]&65535==6*16,(player,frame,m.uploads[-1])
report['water_shared_banks_source_switch_dma_retry_and_all_numbers']=True
# Resolve the carry through an actual BCC: Unicorn's lazy CMP flags need not
# be materialized by an SR read immediately after returning from the helper.
m.s['Native_TestDustCarry']=0x3E0800
m.cpu.mem_write(0x3E0800,bytes.fromhex('4EB9')+struct.pack('>I',m.s['Dust_CheckAir'])+bytes.fromhex('640470014E7570004E75'))
for primary_id in (1,2):
    m.start();m.put('v_player','layout_id',primary_id)
    m.write('v_air',11,2);m.put('v_player','air_left',30)
    m.act('Native_TestDustCarry',regs={UC_M68K_REG_A2:m.s['v_player']&0xFFFFFFFF})
    assert m.cpu.reg_read(UC_M68K_REG_D0)==1,'primary dust ignored the active air supply'
report['both_primary_characters_reserve_low_air_bank_for_numbers']=True

# A held charge survives falling, but its dust must not. Exercise the actual
# dust controller, player landing routines and entire splash animation together.
for player,character,cache,destination,landing in [
        ('v_player',1,'v_splash',0xFC00,'Sonic_ResetOnFloor'),
        ('v_player',2,'v_splash',0xFC00,'Tails_ResetOnFloor'),
        ('v_player2',2,'v_tsplash',0xFE00,'Tails_ResetOnFloor')]:
    m.start();m.uploads.clear()
    m.put(player,'layout_id',character)
    m.write('Player_mode',m.s['PlayerMode_Tails'] if character==2 and player=='v_player' else 0,2)
    m.put(player,'air_left',30)
    m.put(player,'obAnim',m.s['AniIDSonAni_Spindash'])
    m.put(player,'spindash_flag',1)
    m.put(player,'spindash_counter',0x600,2)
    m.act('CreatePlayerDust',player)
    dust=m.get(player,'player_dust_ptr',2)|0xFF0000
    queue=(m.s['v_spritequeue']+0x80)&0xFFFFFF
    def dust_tick():
        m.cpu.mem_write(queue,b'\0\0')
        before=len(m.uploads)
        m.act('SpindashDust',dust)
        return int.from_bytes(m.cpu.mem_read(queue,2),'big'),len(m.uploads)-before
    assert dust_tick()[0]==2
    for velocity in (0xFA00,0,0x600):
        m.put(player,'obStatus',1<<m.s['status.player.in_air'])
        m.put(player,'obVelY',velocity,2)
        assert dust_tick()==(0,0),(player,'airborne dust',velocity)
        assert m.get(dust,'obAnim')==0
        assert m.get(player,'spindash_flag')==1
        assert m.get(player,'spindash_counter',2)==0x600
    m.act(landing,player)
    assert not m.get(player,'obStatus')&(1<<m.s['status.player.in_air'])
    assert dust_tick()[0]==2,(player,'dust did not resume on landing')

    # Use the real one-way-platform collision/ride path too, rather than
    # setting the standing flag in the fixture. Object ground is ground.
    platform=pool()[1]
    for field,value,size in [('code',m.s['Obj18'],4),('obX',600,2),('obY',144,2)]:
        m.put(platform,field,value,size)
    def platform_landing():
        m.put(platform,'obStatus',0)
        m.put(player,'obVelY',0x600,2)
        m.act('PlatformObject_SingleCharacter',platform,{
            UC_M68K_REG_A1:m.s[player]&0xFFFFFFFF,UC_M68K_REG_D1:32,
            UC_M68K_REG_D3:8,UC_M68K_REG_D4:600,
            UC_M68K_REG_D6:3 if player=='v_player' else 4})
        assert m.get(player,'obStatus')&(1<<m.s['status.player.on_object'])
        assert not m.get(player,'obStatus')&(1<<m.s['status.player.in_air'])
        assert m.get(player,'spindash_flag')==1
    m.put(player,'obStatus',1<<m.s['status.player.in_air'])
    assert dust_tick()==(0,0)
    platform_landing()
    assert dust_tick()[0]==2,(player,'dust did not resume on platform')

    m.put(player,'obStatus',1<<m.s['status.player.in_air'])
    assert dust_tick()==(0,0)
    m.act('SpawnPlayerSplash',player)
    m.act('Splash',cache)
    platform_landing()
    splash_frames=set()
    for tick in range(50):
        m.cpu.mem_write(queue,b'\0\0')
        m.act('Splash',cache)
        splash_live=bool(m.get(cache,'code'))
        queued=int.from_bytes(m.cpu.mem_read(queue,2),'big')
        before=len(m.uploads)
        m.act('SpindashDust',dust)
        if splash_live:
            splash_frames.add(m.get(cache,'obFrame'))
            assert int.from_bytes(m.cpu.mem_read(queue,2),'big')==queued
            assert len(m.uploads)==before,(player,'dust overwrote splash')
            assert m.get(cache,'water_loaded_kind')==m.s['WaterArt_Splash']
        else:
            assert int.from_bytes(m.cpu.mem_read(queue,2),'big')==2
            assert m.get(cache,'water_loaded_kind')==m.s['WaterArt_Dust']
            assert m.uploads[-1][1]&65535==destination
            assert m.get(dust,'obFrame')==1,(player,'dust did not restart cleanly')
            break
    else:
        raise AssertionError((player,'dust never resumed after splash'))
    assert splash_frames==set(range(1,10)),(player,splash_frames)
report['airborne_charge_hides_dust_floor_and_platform_resume_after_splash']=True

# Packed star state survives full, partial and empty child compaction, drawing,
# and repeated animation updates. No global SST growth is required for it.
for camera,alternating in ((0,False),(400,True),(1600,False)):
    m.start();m.write('Camera_X_pos',camera,2)
    m.put('v_player','obX',600 if camera else 160,2)
    m.put('v_player','obStatusSecondary',2)
    m.put('v_starsobj','code',m.s['Obj35'])
    m.put('v_shieldobj','effect_loaded_frame',m.s['PlayerEffects_StarsLoaded'])
    history=b''.join(struct.pack('>HH',1200 if alternating and i%2==0 else
                                (600 if camera else 160),116) for i in range(64))
    m.cpu.mem_write(m.s['Sonic_Pos_Record_Buf']&0xFFFFFF,history)
    for tick in range(90):
        m.act('Obj35','v_starsobj',{UC_M68K_REG_D7:0x13579BDF})
        assert m.cpu.reg_read(UC_M68K_REG_D7)==0x13579BDF
        angles=[m.cpu.mem_read(
            (m.s['v_starsobj']+m.s['invincibility_angles']+i*6)&0xFFFFFF,1)[0] for i in range(4)]
        frames=[m.cpu.mem_read((m.s['v_starsobj']+m.s['invincibility_frames']+i*6)&0xFFFFFF,1)[0]
                for i in range(4)]
        assert angles==[(phase+tick*(18 if i==0 else 2))&255
                        for i,phase in enumerate((4,0,22,44))],(tick,angles)
        assert frames==[tick%n for n in (12,10,12,12)],(tick,frames)
        m.act('Render_Sprites')
        assert frames==[m.cpu.mem_read((m.s['v_starsobj']+m.s['invincibility_frames']+i*6)&0xFFFFFF,1)[0]
                        for i in range(4)]
report['packed_star_state_survives_child_compaction_and_rendering']=270

# A partner's composite stars live in the scanned dynamic pool. Their orbit
# state overlays collision bytes, even when no children are on screen.
for camera,partner_x in ((0,160),(1600,600)):
    m.start();m.write('Camera_X_pos',camera,2)
    for actor,x,history in (('v_player',camera+160,'Sonic_Pos_Record_Buf'),
                            ('v_player2',partner_x,'Tails_Pos_Record_Buf')):
        m.put(actor,'obX',x,2);m.put(actor,'obY',112,2)
        m.put(actor,'obVelX',0x200,2);m.put(actor,'obVelY',0x100,2)
        m.put(actor,'obStatusSecondary',2)
        m.cpu.mem_write(m.s[history]&0xFFFFFF,struct.pack('>HH',x,112)*64)
    m.put('v_starsobj','code',m.s['Obj35'])
    m.put('v_shieldobj','effect_loaded_frame',m.s['PlayerEffects_StarsLoaded'])
    for tick in range(128):
        m.act('Obj35','v_starsobj')
        partner=next(a for a in pool() if m.get(a,'code')==m.s['Obj35'])
        m.act('Obj35',partner)
        effects=[m.s['v_starsobj'],partner]
        before=[bytes(m.cpu.mem_read(a&0xFFFFFF,m.s['object_size'])) for a in effects]
        for actor in ('v_player','v_player2'):
            player_before=bytes(m.cpu.mem_read(m.s[actor]&0xFFFFFF,m.s['object_size']))
            m.act('TouchResponse',actor)
            assert bytes(m.cpu.mem_read(m.s[actor]&0xFFFFFF,m.s['object_size']))==player_before,(
                'composite stars changed player collision state',camera,tick,actor)
            assert [bytes(m.cpu.mem_read(a&0xFFFFFF,m.s['object_size'])) for a in effects]==before,(
                'touch response mutated composite star data',camera,tick,actor)
            assert m.read('v_score',4)==0 and m.read('v_itembonus',2)==0,(
                'composite stars awarded a phantom enemy kill',camera,tick,actor)
report['composite_stars_cannot_mutate_players_or_award_phantom_kills']=512

# The same scan must still process real enemies and breakable monitors for
# either player after excluding display-only composite SSTs.
for actor in ('v_player','v_player2'):
    for kind in ('enemy','monitor'):
        m.start();target=pool()[0]
        m.put(actor,'obX',160,2);m.put(actor,'obY',112,2)
        m.put(actor,'obStatusSecondary',2);m.put(actor,'obAnim',m.s['AniIDSonAni_Roll'])
        m.put(actor,'obVelY',0x100,2)
        m.put(target,'code',m.s['Crabmeat'] if kind=='enemy' else m.s['Obj26'])
        m.put(target,'obRender',4);m.put(target,'obX',160,2);m.put(target,'obY',112,2)
        m.put(target,'obColType',9 if kind=='enemy' else 0x46)
        m.act('TouchResponse',actor)
        if kind=='enemy':
            assert m.get(target,'code')==m.s['Explosion'] and m.read('v_score',4)>0
        else:
            assert m.get(target,'obRoutine')==4 and m.get(target,'obParent',2)==m.s[actor]&65535
report['real_enemy_and_monitor_touches_still_work_for_both_players']=4

for obj in (pool()[0],pool()[-1]):
    m.start();address=obj&0xFFFFFF
    m.cpu.mem_write(address,b'\xA5'*m.s['object_size'])
    m.cpu.mem_write(address+m.s['object_size'],b'\x5A'*4)
    m.act('DeleteObject',obj)
    assert bytes(m.cpu.mem_read(address,m.s['object_size']))==bytes(m.s['object_size'])
    assert bytes(m.cpu.mem_read(address+m.s['object_size'],4))==b'\x5A'*4
report['non_longword_sst_delete_clears_final_word_without_touching_next_slot']=True

# Landing uses the actual depressed log, not the bridge parent's original Y.
obj,ptr=setup(0x1D,16);m.act('Bridge',obj)
child=m.get(obj,'Bridge_child1',4)&0xFFFFFF
m.put(child,'sub2_y_pos',280,2)
m.put('v_player2','obX',112,2);m.put('v_player2','obY',254,2)
m.put('v_player2','obHeight',15);m.put('v_player2','obStatus',2)
m.put('v_player2','obVelY',0x100,2)
m.act('sub_7DC0',obj,{UC_M68K_REG_D1:136,UC_M68K_REG_D2:256,
        UC_M68K_REG_D3:8,UC_M68K_REG_D4:240})
assert m.get(obj,'obStatus')&16 and m.get('v_player2','obStatus')&8, (m.get(obj,'obStatus'),m.get('v_player2','obStatus'),m.get('v_player2','obY',2))
m.put('v_player2','obControl',0x81)
m.act('sub_7DC0',obj,{UC_M68K_REG_D1:136,UC_M68K_REG_D2:256,
        UC_M68K_REG_D3:8,UC_M68K_REG_D4:240})
assert not m.get(obj,'obStatus')&16 and not m.get('v_player2','obStatus')&8
report['depressed_bridge_landing_and_catchup_rider_release']=True

# Over-screen owns Debug/input; scripted exits own both logical controllers.
for primary in (1,2):
    m.start();m.put('v_player','layout_id',primary)
    m.put('v_player','obRoutine',8);m.write('Debug_mode_flag',1)
    m.write('f_lockctrl',m.s['PlayerInputLock_Over'])
    m.write('v_jpadpress1',m.s['btnB'])
    m.act('Obj01' if primary==1 else 'Obj02','v_player')
    assert not m.read('Debug_placement_mode',2)
for lock,logical in ((m.s['PlayerInputLock_Automatic'],m.s['btnR']<<8),
                     (m.s['PlayerInputLock_Over'],0)):
    m.start();m.write('f_lockctrl',lock);m.write('v_jpadholdlogical',logical,2)
    m.write('v_jpadhold2',(m.s['btnL']<<8)|m.s['btnC'],2)
    m.act('Tails_Control','v_player2')
    assert m.read('v_jpadholdlogical2',2)==logical
    assert m.read('v_jpadhold2',2)==(m.s['btnL']<<8)|m.s['btnC']
    assert not m.read('Tails_CPU_idle_timer',2)
m.start();m.write('f_lockctrl',m.s['PlayerInputLock_Over'])
m.write('v_jpadpress1',m.s['btnB'])
obj=pool()[0];m.put(obj,'code',m.s['GameOver']);m.put(obj,'obRoutine',4)
m.act('Over_Wait',obj)
assert m.read('v_gamemode',2)==m.s['SegaScreen'] and not m.read('f_lockctrl')
report['over_screen_blocks_debug_and_exits_keep_raw_buttons']=True
report['scripted_input_overrides_controller2_and_ai']=True

for role in ('v_player','v_player2'):
    obj,ptr=setup(0x7D,3)
    m.put('v_player','obX',2000,2);m.put('v_player2','obX',2000,2)
    m.put(role,'obX',240,2);m.put(role,'obY',240,2)
    m.act('Obj7D',obj)
    assert m.get(obj,'obRoutine')==2 and m.read('v_score',4)==10
report['hidden_bonus_accepts_either_live_character']=True

# Collision must test the exact delta that the 8.8 velocity later commits.
# At this boundary the old full-precision prediction was clear, but rounding
# a negative step moved Sonic into the adjacent wall by 77/65536 of a pixel.
m.start();m.put('v_player','layout_id',4)
x=51*24-20;y=50*24-68+5
m.put('v_player','obX',(x<<16)|7603,4);m.put('v_player','obY',y<<16,4)
m.put('v_player','obVelX',0,2);m.put('v_player','obVelY',0,2)
m.write('v_ssangle',0xE000,2)
m.cpu.mem_write((m.s['v_ssbuffer1']+50*128+50)&0xFFFFFF,b'\x01')
m.act('BonusPlayer_Fall','v_player')
for pos,vel in (('obX','obVelX'),('obY','obVelY')):
    delta=m.get('v_player',vel,2)
    if delta&32768: delta-=65536
    m.put('v_player',pos,(m.get('v_player',pos,4)+(delta<<8))&0xFFFFFFFF,4)
m.act('SSS_FindWall','v_player',{UC_M68K_REG_D2:m.get('v_player','obY',4),
                               UC_M68K_REG_D3:m.get('v_player','obX',4)})
assert not m.cpu.reg_read(UC_M68K_REG_D5)&255
assert m.get('v_player','obX',2)==x
report['special_stage_negative_fraction_cannot_cross_wall_boundary']=True

# An ordinary unreachable platform never becomes a timed flight trigger.
for height in (24,48,132,256):
    obj,ptr=setup(0x18,0)
    m.put('v_player','obX',600,2);m.put('v_player','obY',116,2)
    m.put('v_player2','obX',568,2);m.put('v_player2','obY',116+height,2)
    m.write('Tails_CPU_routine',6,2)
    for tick in range(420):
        m.put('v_player2','obStatus',2 if tick%64<48 else 0)
        m.put('v_player2','jumping',int(tick%64<48))
        m.put('v_player2','obVelX',0x100,2)
        m.act('Tails_CPU_CheckReach','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
        assert not m.cpu.reg_read(UC_M68K_REG_D0) and m.read('Tails_CPU_routine',2)==6
        assert m.read('Tails_CPU_reach_state',2) in (0,1)
report['unreachable_platforms_keep_normal_jump_approach']=1680

# A stopped slope lock still recovers after the floor angle has reset. Moving
# backwards needs an actual slope: a flat spring landing must keep steering.
for side,inertia,locked,air,manual,angle in product((-1,1),(-0x80,0,0x80),
        (False,True),(False,True),(False,True),(0,0x17,0x18,0x30,0xE7,0xE8)):
    m.start();m.put('v_player','obX',600+side*32,2);m.put('v_player','obY',116,2)
    m.put('v_player2','obX',600,2);m.put('v_player2','obY',116,2)
    m.put('v_player2','obRender',0x80);m.put('v_player2','obStatus',2 if air else 0)
    m.put('v_player2','obAngle',angle)
    m.put('v_player2','obInertia',inertia,2);m.put('v_player2','move_lock',30 if locked else 0,2)
    m.write('Tails_CPU_routine',6,2);m.write('Tails_CPU_idle_timer',120 if manual else 0,2)
    m.act('TailS3_loc_13D78','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
    slope=angle in (0x18,0x30,0xE7)
    expected=locked and not air and not manual and (inertia==0 or slope and side*inertia<0)
    assert m.read('Tails_CPU_routine',2)==(8 if expected else 6),(side,inertia,locked,air,manual,angle)
report['slope_spindash_recovery_respects_springs_motion_air_and_manual_input']=288

# A deliberate lead jump retains a pending approach; a fall cancels it.
# Neither case is permission to enter flight or to invent a fresh approach.
for approach,air,jumping in product((0,1),(0,2),(0,1)):
    m.start();m.put('v_player','obY',116,2)
    m.put('v_player','obStatus',air);m.put('v_player','jumping',jumping)
    m.put('v_player2','obY',180,2);m.put('v_player2','obStatus',2)
    m.write('Tails_CPU_reach_state',approach,2);m.write('Tails_CPU_routine',6,2)
    m.act('Tails_CPU_CheckReach','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
    assert m.read('Tails_CPU_routine',2)==6
    assert m.read('Tails_CPU_reach_state',2)==(approach if not air or jumping else 0)
report['approach_follows_lead_jump_but_not_fall']=8

# Ordinary respawn pursuit closes either vertical gap without overshooting.
# Local collapse flights retain their independent one-pixel limit below.
for dy in (-384,-128,-16,-2,-1,0,1,2,16,128,384):
    m.start();m.put('v_player','obY',700,2)
    m.put('v_player2','obY',700+dy,2)
    m.cpu.mem_write(m.s['Sonic_Pos_Record_Buf']&0xFFFFFF,struct.pack('>HH',600,700)*64)
    m.write('Tails_CPU_routine',4,2)
    m.act('TailS3_loc_13C50','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
    new_dy=m.get('v_player2','obY',2)-700
    assert abs(new_dy-dy)<=6 and new_dy*dy>=0,(dy,new_dy)
    assert abs(new_dy)<abs(dy) if dy else new_dy==0
report['respawn_vertical_pursuit_bounds_and_no_overshoot']=11

# Local collapse flight has normal bounded movement in either direction,
# including large inherited leader velocities and final one-pixel approach.
for dx,dy,velocity in product((-256,-32,-6,-1,1,6,32,256),
                              (-128,-16,-1,0,1,16,128),(-0x2000,-0x600,0,0x600,0x2000)):
    m.start()
    m.put('v_player','obX',600,2);m.put('v_player','obY',200,2)
    m.put('v_player','obVelX',velocity,2)
    m.put('v_player2','obX',600+dx,2);m.put('v_player2','obY',200+dy,2)
    m.cpu.mem_write(m.s['Sonic_Pos_Record_Buf']&0xFFFFFF,struct.pack('>HH',600,200)*64)
    m.write('Tails_CPU_routine',4,2);m.write('Tails_CPU_reach_state',65535,2)
    m.act('TailS3_loc_13C50','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
    new_dx=m.get('v_player2','obX',2)-600;new_dy=m.get('v_player2','obY',2)-200
    assert abs(new_dx-dx)<=6 and abs(new_dy-dy)<=1,(dx,dy,velocity,new_dx,new_dy)
    assert abs(new_dx)<abs(dx) and abs(new_dy)<=abs(dy)
    assert new_dx*dx>=0 and new_dy*dy>=0
report['collapse_flight_speed_bounds_and_no_overshoot']=280

# The ledge must actually fragment. Tails first jumps toward the lead;
# Sonic may run away or deliberately jump, including the descending half.
# Falling off with no jump flag must never provoke this flight.
cases=0
for oid,triggered,fragmented,moving,lead_phase,tail_phase,towards in product(
        (0x1A,0x1B),(False,True),(False,True),(False,True),
        ('run','jump-rise','jump-descend','fall'),('ground','fall','jump'),(False,True)):
    obj,ptr=setup(oid,0)
    index=(obj-m.s['v_objspace'])//m.s['object_size']
    for actor in ('v_player','v_player2'):
        m.put(actor,'standonobject',index);m.put(actor,'obY',116,2)
    m.put('v_player','obStatus',0 if lead_phase=='run' else 2)
    m.put('v_player','obX',600,2)
    m.put('v_player','jumping',int(lead_phase.startswith('jump')))
    m.put('v_player','obVelY',0xFC00 if lead_phase=='jump-rise' else 0x400,2)
    m.put('v_player2','obStatus',8 if tail_phase=='ground' else 2)
    m.put('v_player2','obX',568,2);m.put('v_player2','obY',164,2)
    m.put('v_player2','jumping',int(tail_phase=='jump'))
    m.put('v_player2','obVelX',0x400 if towards else 0xFC00,2)
    m.put('v_player','obVelX',0x400 if moving else 0,2)
    m.put(obj,'obRoutine',m.s['ledge_fragment_routine'] if fragmented else 2)
    m.put(obj,'ledge_collapse_flag',int(triggered));m.put(obj,'obStatus',8)
    m.write('Tails_CPU_routine',6,2)
    m.act('Tails_CPU_CheckReach','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
    expected=fragmented and moving and lead_phase!='fall' and tail_phase=='jump' and towards
    assert bool(m.cpu.reg_read(UC_M68K_REG_D0))==expected, (oid,triggered,fragmented,moving,lead_phase,tail_phase,towards)
    assert m.read('Tails_CPU_routine',2)==(4 if expected else 6)
    if expected:
        assert m.read('Tails_CPU_reach_state',2)==65535
        assert not m.get(obj,'obStatus')&16 and not m.get('v_player2','obStatus')&8
    cases+=1
report['collapsed_target_only_interrupts_horizontal_approach_jump']=cases

# Crossing paired ledges or jumping above the target needs no flight.
for lead_air,dy in product((False,True),(-48,0,16,48)):
    obj,ptr=setup(0x1A,0)
    m.put(obj,'obRoutine',m.s['ledge_fragment_routine'])
    m.put('v_player','standonobject',(obj-m.s['v_objspace'])//m.s['object_size'])
    m.put('v_player','obX',600,2);m.put('v_player','obY',200,2)
    m.put('v_player','obVelX',0x400,2);m.put('v_player','obStatus',2 if lead_air else 0)
    m.put('v_player','jumping',int(lead_air))
    m.put('v_player2','obX',568,2);m.put('v_player2','obY',200+dy,2)
    m.put('v_player2','obStatus',6);m.put('v_player2','jumping',1)
    m.put('v_player2','obVelX',0x400,2);m.write('Tails_CPU_routine',6,2)
    m.act('Tails_CPU_CheckReach','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
    assert (m.read('Tails_CPU_routine',2)==4)==(dy==48)
report['collapsed_target_at_or_below_tails_keeps_normal_jump']=8

# A lingering fragment reference must not interrupt a later jump after Sonic
# has run out of reach. Check both directions, exact limits and zero motion.
for dx,velocity in product((-129,-128,-32,0,32,128,129),(-0x400,0,0x400)):
    obj,ptr=setup(0x1A,0)
    m.put(obj,'obRoutine',m.s['ledge_fragment_routine'])
    m.put('v_player','standonobject',(obj-m.s['v_objspace'])//m.s['object_size'])
    m.put('v_player','obX',600+dx,2);m.put('v_player','obY',116,2)
    m.put('v_player','obVelX',0x400,2)
    m.put('v_player2','obX',600,2);m.put('v_player2','obY',164,2)
    m.put('v_player2','obStatus',6);m.put('v_player2','jumping',1)
    m.put('v_player2','obVelX',velocity,2);m.write('Tails_CPU_routine',6,2)
    m.act('Tails_CPU_CheckReach','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
    expected=0<abs(dx)<=m.s['Tails_CPU_ReachWidth'] and dx*velocity>0
    assert (m.read('Tails_CPU_routine',2)==4)==expected, (dx,velocity)
report['collapsed_target_rejects_distant_or_wrong_direction_jumps']=21

# A retained index is not permission to interpret an unrelated/reused slot.
for index,code_pointer in ((m.s['object_slot_count'],m.s['Obj1A']),
                           (m.s['reserved_object_slots'],m.s['Obj18'])):
    obj,ptr=setup(0x1A,0)
    m.put(obj,'code',code_pointer);m.put(obj,'obRoutine',m.s['ledge_fragment_routine'])
    m.put(obj,'ledge_collapse_flag',1)
    m.put('v_player','standonobject',index);m.put('v_player','obVelX',0x400,2)
    m.act('Tails_CPU_TargetHasCollapsed','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
    assert not m.cpu.reg_read(UC_M68K_REG_D0)
report['collapsed_target_rejects_invalid_or_reused_slot']=True

# Matching the recorded position must not make Tails drop during either
# half of Sonic's jump. A grounded target allows normal following to resume; a genuine fall releases immediately even at a distance.
for lead_phase in ('run','jump-rise','jump-descend','idle'):
    m.start()
    for actor in ('v_player','v_player2'):
        m.put(actor,'obX',600,2);m.put(actor,'obY',116,2)
    m.put('v_player','obStatus',2 if lead_phase.startswith('jump') else 0)
    m.put('v_player','jumping',int(lead_phase.startswith('jump')))
    m.put('v_player','obVelX',0 if lead_phase=='idle' else 0x400,2)
    m.put('v_player','obVelY',0xFC00 if lead_phase=='jump-rise' else 0x400,2)
    m.cpu.mem_write(m.s['Sonic_Pos_Record_Buf']&0xFFFFFF,struct.pack('>HH',600,116)*64)
    m.write('Tails_CPU_routine',4,2);m.write('Tails_CPU_reach_state',65535,2)
    m.act('TailS3_loc_13C50','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
    flying=lead_phase.startswith('jump')
    assert m.read('Tails_CPU_routine',2)==(4 if flying else 6)
    assert m.get('v_player2','obControl')==(0x81 if flying else 0)
report['ledge_flight_follows_whole_jump_and_lands_at_grounded_target']=True
m.write('Tails_CPU_routine',4,2);m.write('Tails_CPU_reach_state',65535,2)
m.put('v_player2','obControl',0x81)
m.put('v_player','obStatus',2);m.put('v_player','jumping',0)
m.put('v_player','obVelY',0x100,2)
m.act('Tails_FlySwim_Unknown','v_player2',{UC_M68K_REG_A1:m.s['v_player']})
assert m.read('Tails_CPU_routine',2)==6 and not m.get('v_player2','obControl')
assert not m.read('Tails_CPU_reach_state',2) and m.get('v_player2','obStatus')&2
report['ledge_flight_releases_immediately_when_sonic_falls']=True

# The real air-expiry path locks both logical inputs before its 120-frame
# drowning animation. Companion drowning must not lock the primary player.
for actor,primary_id in (('v_player',1),('v_player',2),('v_player2',1)):
    m.start();m.put('v_player','layout_id',primary_id)
    m.put(actor,'obStatus',64);m.put(actor,'air_left',0)
    m.write('v_air',0,2);m.write('Player_mode',2 if primary_id==2 else 0,2)
    m.write('v_jpadholdlogical',0x0808,2);m.write('v_jpadholdlogical2',0x0404,2)
    bubble=m.s['v_sonicbubbles' if actor=='v_player' else 'v_tailsbubbles']
    m.put(bubble,'obParent',m.s[actor]&65535,2)
    m.act('Obj0A_Countdown',bubble)
    assert m.get(actor,'obAnim')==m.s['AniIDSonAni_Drown']
    assert m.get(actor,'obControl')==0x81
    if actor=='v_player':
        assert m.read('f_lockctrl')==m.s['PlayerInputLock_Drowning']
        assert not m.read('v_jpadholdlogical',2) and not m.read('v_jpadholdlogical2',2)
    else:assert not m.read('f_lockctrl')
report['real_drowning_locks_only_primary_controls_before_death_routine']=3
print(report,flush=True)
