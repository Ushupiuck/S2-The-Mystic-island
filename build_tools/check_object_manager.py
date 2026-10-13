#!/usr/bin/env python3
"""Run the assembled S3&K manager/Debug regressions with optional Unicorn.

Build first with build.lua. This executes the ROM's 68000 instructions; only
external sound, DMA hardware, and the HUD's VDP writer are stubbed. Fixtures
use the real six-byte placement records and an independent window model.
"""
from pathlib import Path
import argparse
import re
import struct

try:
    from unicorn import (Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN, UC_HOOK_CODE,
                         UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE,
                         UC_HOOK_MEM_READ_UNMAPPED, UC_MEM_READ)
    from unicorn.m68k_const import *
except ImportError:
    raise SystemExit('This optional ROM test requires the unicorn Python package.')

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
parser.add_argument('--listing', type=Path, default=ROOT / 'main.lst')
args = parser.parse_args()
R = ROOT
STOP, STACK = 0x3FFF00, 0xFF8000
DATA = [UC_M68K_REG_D0, UC_M68K_REG_D1, UC_M68K_REG_D2, UC_M68K_REG_D3]


class Native:
    def __init__(self):
        listing = args.listing.read_text()
        assert 'Symbol Table' in listing, 'Build must finish before testing its listing'
        self.s = {name: int(value, 16) for name, value in re.findall(
            r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', listing)}
        self.cpu = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
        self.cpu.ctl_set_cpu_model(UC_CPU_M68K_M68000)
        self.cpu.mem_map(0, 0x400000)
        self.cpu.mem_map(0xFF0000, 0x10000)
        self.cpu.mem_map(0xFFFF0000, 0x10000)
        self.cpu.mem_write(0, args.rom.read_bytes())
        for label in ('QueueDMATransfer', 'PlayMusic', 'PlaySound', 'PlaySound_Special'):
            self.cpu.mem_write(self.s[label], bytes.fromhex('4E75'))
        self.cpu.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, self.bus)
        self.cpu.hook_add(UC_HOOK_MEM_READ_UNMAPPED, self.alias)
        self.cpu.hook_add(UC_HOOK_CODE, self.hook)
        self.uploads = []

    def bus(self, cpu, access, address, size, value, unused):
        physical = address & 0xFFFFFF
        if access != UC_MEM_READ:
            assert physical >= 0xFF0000, f'Unexpected CPU write outside RAM: {address:X}'
        if address != physical and physical >= 0xFF0000:
            if access == UC_MEM_READ:
                cpu.mem_write(address, bytes(cpu.mem_read(physical, size)))
            else:
                cpu.mem_write(physical, value.to_bytes(size, 'big'))

    def alias(self, cpu, access, address, size, value, unused):
        # Real 68000 addresses are 24-bit. Debug stores the ID in the top
        # mapping byte; Caterkiller stores a trail index above its parent.
        if address <= 0xFFFFFF:
            return False
        page = address & ~0xFFF
        physical = page & 0xFFFFFF
        if not (physical < 0x400000 or physical >= 0xFF0000):
            return False
        cpu.mem_map(page, 0x1000)
        cpu.mem_write(page, bytes(cpu.mem_read(physical, 0x1000)))
        return True

    def hook(self, cpu, address, size, unused):
        if address == self.s['QueueDMATransfer']:
            self.uploads.append(tuple(cpu.reg_read(reg) for reg in DATA[1:]))
            for reg in DATA:
                cpu.reg_write(reg, 0xDEADC0DE)
            cpu.reg_write(UC_M68K_REG_A1, 0xFFFFBABA)

    def write(self, name, value, size=1):
        self.cpu.mem_write(self.s[name] & 0xFFFFFF, value.to_bytes(size, 'big'))

    def read(self, name, size=1):
        return int.from_bytes(self.cpu.mem_read(self.s[name] & 0xFFFFFF, size), 'big')

    def put(self, obj, field, value, size=1):
        if isinstance(obj, str):
            obj = self.s[obj]
        self.cpu.mem_write((obj + self.s[field]) & 0xFFFFFF,
                          (value & ((1 << (8 * size)) - 1)).to_bytes(size, 'big'))

    def get(self, obj, field, size=1):
        if isinstance(obj, str):
            obj = self.s[obj]
        return int.from_bytes(self.cpu.mem_read((obj + self.s[field]) & 0xFFFFFF, size), 'big')

    def act(self, routine, obj=None, regs=None):
        self.cpu.reg_write(UC_M68K_REG_SR, 0x2000)
        for reg in DATA:
            self.cpu.reg_write(reg, 0xA5A51234)
        if obj is not None:
            address = self.s[obj] if isinstance(obj, str) else obj | 0xFF000000
            self.cpu.reg_write(UC_M68K_REG_A0, address)
        for reg, value in (regs or {}).items():
            self.cpu.reg_write(reg, value)
        self.cpu.reg_write(UC_M68K_REG_A7, STACK)
        self.cpu.mem_write(STACK, struct.pack('>I', STOP))
        self.cpu.emu_start(self.s[routine], STOP, count=100000)
        assert self.cpu.reg_read(UC_M68K_REG_PC) == STOP, routine
        assert self.cpu.reg_read(UC_M68K_REG_A7) == STACK + 4, routine

    def start(self):
        self.cpu.mem_write(0xFF0000, bytes(0x10000))
        self.cpu.mem_write(0xFFFF0000, bytes(0x10000))
        self.write('v_gamemode', self.s['Level'], 2)
        self.write('v_air', 30, 2)
        self.act('Init_SpriteTable')
        for obj, object_id in [('v_player', 1), ('v_player2', 2)]:
            for field, value, size in [('obID', object_id, 1), ('obRoutine', 2, 1),
                    ('obRender', 0x84, 1), ('obHeight', 19, 1), ('obWidth', 9, 1),
                    ('default_y_radius', 19, 1), ('default_x_radius', 9, 1),
                    ('obX', 600, 2), ('obY', 116, 2), ('obTopSolidBit', 12, 1),
                    ('obLRBSolidBit', 13, 1)]:
                self.put(obj, field, value, size)

class Manager(Native):
    def pool(self):
        return range(self.s['v_lvlobjspace'],self.s['v_lvlobjend'],self.s['object_size'])
    def live(self):
        return {self.get(a,'respawn_addr',2):a for a in self.pool() if self.get(a,'obID') and self.get(a,'respawn_addr',2)}
    def rows(self,name):
        return list(struct.iter_unpack('>HHBB',(R/'level/objects'/name).read_bytes()[:-6]))
    def cam(self,x,y):
        self.write('Camera_X_pos',x,2)
        self.write('Camera_Y_pos',y&65535,2)
    def fixture(self,rows):
        # Replace this level's relative pointer with a small ROM fixture near the
        # real index. Keep the leading sentinel and real six-byte placement format.
        self.start()
        i=self.s['ObjPos_Index']
        base=i+0x7000
        self.cpu.mem_write(i,struct.pack('>h',base-i))
        self.cpu.mem_write(base-6,bytes.fromhex('FFFF00000000'))
        self.cpu.mem_write(base,b''.join(struct.pack('>HHBB',*r) for r in rows)+bytes.fromhex('FFFF00000000'))
        return base
    def verify(self,rows,base=None):
        table=self.s['Object_Respawn_Table']&65535
        live=self.live()
        ptrs=[self.get(a,'respawn_addr',2) for a in self.pool() if self.get(a,'obID') and self.get(a,'respawn_addr',2)]
        assert len(ptrs)==len(set(ptrs)),('duplicate placement',ptrs)
        for ptr,a in live.items():
            idx=(ptr-table)&65535
            assert idx<len(rows),(hex(ptr),idx,len(rows))
            x,y,obj,sub=rows[idx]
            assert self.get(a,'obX',2)==x and self.get(a,'obY',2)==y&0xFFF
            assert self.get(a,'obID')==obj and self.get(a,'obSubtype')==sub
            assert self.get(a,'obStatus')==self.get(a,'obRender')==(y>>13)&3
            assert self.cpu.mem_read(0xFF0000+ptr,1)[0]&128
        if base is not None:
            for side in ('front','back'):
                lp=self.read('Object_load_addr_'+side,4)
                rp=self.read('Object_respawn_index_'+side,2)
                assert lp>=base and (lp-base)%6==0 and (lp-base)//6<=len(rows)
                assert rp==table+(lp-base)//6,(side,hex(lp),hex(rp))
        return live

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

m=Manager()
report={}
cases=0
# Every act uses the existing four-act zone math and the correct ROM layout.
names=['GHZ','LZ','CPZ','EHZ','HPZ','HTZ','MTZ']
for z,n in enumerate(names):
    for act in range(4):
        m.start()
        m.write('Current_ZoneAndAct',(z<<8)|act,2)
        m.cam(0,0)
        m.act('ObjectsManager')
        rows=m.rows(f'{n}_{act+1}.bin')
        base=m.s[f'ObjPos_{n}{act+1}']
        live=m.verify(rows,base)
        ids={(p-(m.s['Object_Respawn_Table']&65535))&65535 for p in live}
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
    loaded={(p-(m.s['Object_Respawn_Table']&65535))&65535 for p in live}
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
        loaded={(p-(m.s['Object_Respawn_Table']&65535))&65535 for p in live}
        assert eligible(rows,256,y,wrap)<=loaded,(wrap,y,eligible(rows,256,y,wrap)-loaded)
report['vertical_bands_jumps_and_wrap']=True
# Exhausted pool: no flag may be set without a real SST. Retry even if the
# camera remains still, preserve cursor pairing, and use all 90 slots exactly.
rows=[(256,128,0x36,i) for i in range(95)]
base=m.fixture(rows)
for a in m.pool():
    m.put(a,'obID',0x35)
m.cam(0,0)
m.act('ObjectsManager')
assert not m.live() and m.read('Object_load_retry')
assert bytes(m.cpu.mem_read(m.s['Object_Respawn_Table']&0xFFFFFF,95))==bytes(95)
for a in list(m.pool())[::2]:
    m.act('DeleteObject',a)
m.act('ObjectsManager')
assert len(m.verify(rows,base))==45 and m.read('Object_load_retry')
for a in m.pool():
    if m.get(a,'obID')==0x35:
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
    loaded={(p-(m.s['Object_Respawn_Table']&65535))&65535 for p in live}
    assert eligible(rows,x,0)<=loaded,(x,eligible(rows,x,0)-loaded)
report['full_768_placement_table']=True
# A preserved table survives reinitialization, and a normal new layout clears it.
m.start()
m.cpu.mem_write(m.s['Object_Respawn_Table']&0xFFFFFF,b'\x21'*768)
m.write('Respawn_table_keep',1)
m.cam(0,0)
m.act('ObjectsManager')
assert m.cpu.mem_read(m.s['Object_Respawn_Table']&0xFFFFFF,768)[-1]==0x21
m.write('Obj_placement_routine',0)
m.write('Respawn_table_keep',0)
m.act('ObjectsManager')
assert m.cpu.mem_read(m.s['Object_Respawn_Table']&0xFFFFFF,768)[-1]==0
report['reset_keep_state']=True
print(report,flush=True)

# Object ownership and Debug regressions use a fresh RAM/ROM machine.
m=Native()
report={}
def pool():
    return list(range(m.s['v_lvlobjspace'],m.s['v_lvlobjend'],m.s['object_size']))
def setup(objid,sub=0,state=0x80):
    m.start()
    obj=pool()[0]
    ptr=m.s['Object_Respawn_Table']&65535
    for f,v,n in [('obID',objid,1),('obX',240,2),('obY',240,2),('obSubtype',sub,1),('respawn_addr',ptr,2)]:
        m.put(obj,f,v,n)
    m.write('Object_Respawn_Table',state)
    return obj,ptr
# Loaded tags stay set during initialization, and persistent state survives unload.
for state in (0x80,0x81):
    obj,ptr=setup(0x26,0,state)
    m.act('Obj26',obj)
    assert m.read('Object_Respawn_Table')==state
    assert (m.get(obj,'obRoutine')==8)==bool(state&1)
    m.write('Camera_X_pos_coarse_back',0x1000,2)
    m.act('Obj26',obj)
    assert m.get(obj,'obID')==0 and m.read('Object_Respawn_Table')==state&127
obj,ptr=setup(0x26)
m.act('Obj26',obj)
m.put(obj,'obRoutine',4)
m.act('Obj26',obj)
assert m.read('Object_Respawn_Table')==0x81
for state in (0x80,0x81):
    obj,ptr=setup(0x79,1,state)
    m.act('Obj79',obj)
    assert m.read('Object_Respawn_Table')==state
    m.act('UnloadObject',obj)
    assert m.read('Object_Respawn_Table')==state&127
# Zero respawn pointers must not alter a real placement's state.
for objid,routine in ((0x26,'Obj26'),(0x79,'Obj79'),(0x47,'Obj47')):
    obj,ptr=setup(objid)
    m.put(obj,'respawn_addr',0,2)
    m.act(routine,obj)
    m.act('UnloadObject',obj)
    assert m.read('Object_Respawn_Table')==0x80
report['monitor_checkpoint_and_zero_pointer_state']=True
# Bumper score cap remains local to one placement, even after unloading.
obj,ptr=setup(0x47,state=0x89)
m.act('Obj47',obj)
m.act('Bumper_bump',obj,{UC_M68K_REG_A1:m.s['v_player']})
assert m.read('Object_Respawn_Table')==0x8A
score=m.read('v_score',4)
m.act('Bumper_bump',obj,{UC_M68K_REG_A1:m.s['v_player']})
assert m.read('v_score',4)==score
m.act('UnloadObject',obj)
assert m.read('Object_Respawn_Table')==10
report['bumper_cap_persists']=True
# Compound initializers must handle zero/one remaining helper slots atomically.
for objid,sub,routine,fields,needed in [(0x1D,16,'Bridge',('Bridge_child1','Bridge_child2'),2),(0x1E,0x10,'HPZ_Waterfall',('objoff_38','objoff_3C'),2),(0x50,0x11,'Obj50',('objoff_36',),1)]:
    for free in range(needed):
        obj,ptr=setup(objid,sub)
        for a in pool()[1:]:
            m.put(a,'obID',0x55)
        for a in pool()[1:1+free]:
            m.put(a,'obID',0)
        m.act(routine,obj)
        assert m.get(obj,'obRoutine')==0 and m.read('Object_Respawn_Table')==0x80,(routine,free)
        assert all(m.get(obj,f,4)==0 for f in fields),(routine,'half parent')
        assert sum(m.get(a,'obID')==0 for a in pool()[1:])==free,(routine,'leak')
        for a in pool()[1:1+needed]:
            m.put(a,'obID',0)
        m.act(routine,obj)
        assert m.get(obj,'obRoutine')!=0
        assert all(m.get(obj,f,4) for f in fields)
        for f in fields:
            child=m.get(obj,f,4)&0xFFFFFF
            if objid!=0x1D:
                assert m.get(child,'respawn_addr',2)==0
report['multipart_pool_exhaustion_and_retry']=5
# Dynamic objects do not consume a placement; explicit destruction does.
obj,ptr=setup(0x22,state=0x85)
m.act('DeleteObject',obj)
assert m.read('Object_Respawn_Table')==0x85
report['destruction_keeps_consumed_tag']=True
# Caterkiller's existing failed-allocation path retires its head and lets its
# partial chain clean itself up; only the head releases the placement byte.
for free in (0,1,2):
    obj,ptr=setup(0x60,state=0x85)
    for a in pool()[1:]:
        m.put(a,'obID',0x55)
    for a in pool()[1:1+free]:
        m.put(a,'obID',0)
    m.act('Caterkiller',obj)
    assert m.get(obj,'obRoutine')==10
    assert m.read('Object_Respawn_Table')==5
    children=[a for a in pool()[1:] if m.get(a,'obID')==0x60]
    assert len(children)==free and all(m.get(a,'respawn_addr',2)==0 for a in children)
    m.act('Cat_Delete',obj)
    assert m.get(obj,'obID')==0
report['caterkiller_owner_and_partial_allocation']=3
# Fragment copies are dynamic. The original collapsed scenery slot releases
# its placement when leaving the display area, retaining object-local bits.
obj,ptr=setup(0x1A,state=0x83)
m.put(obj,'obRoutine',4)
m.put(obj,'obRender',4)
m.act('Obj1A',obj)
assert m.read('Object_Respawn_Table')==3 and m.get(obj,'obID')==0
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
    for f,v,n in [('obID',objid,1),('character_id',objid-1,1),('obMap',m.s[mapname],4),('obGfx',m.s['ArtTile_'+who],2),('height_pixels',m.s[mapname+'_height'],1),('width_pixels',m.s[mapname+'_width'],1),('default_y_radius',h,1),('default_x_radius',w,1),('obStatus',0x7D,1),('obRender',0x85,1)]:
        m.put('v_player',f,v,n)
    m.write('v_jpadpress1',m.s['btnB'])
    m.act('Obj01_Control' if objid==1 else 'Obj02_Control','v_player')
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
    placed=[a for a in pool() if m.get(a,'obID')==0x12]
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
m.put('v_player','obID',4)
m.put('v_player','obMap',m.s['Map_Sonic'],4)
m.put('v_player','obGfx',m.s['ArtTile_Sonic'],2)
m.act('Debug_Begin','v_player')
m.write('v_jpadpress1',0)
m.act('DebugMode','v_player')
assert m.read('Current_ZoneAndAct',2)==0x301
assert m.get('v_player','obGfx',2)==m.s['ArtTile_SS_Rings']|0x2000
m.write('v_jpadpress1',m.s['btnC'])
m.act('DebugMode','v_player')
stage_ring=next(a for a in pool() if m.get(a,'obID')==0x12)
m.act('Obj12',stage_ring)
assert m.get(stage_ring,'obGfx',2)==m.s['ArtTile_SS_Rings']|0x2000
m.write('v_jpadpress1',m.s['btnB'])
m.act('DebugMode','v_player')
assert m.get('v_player','obHeight')==14 and m.get('v_player','obWidth')==7
assert m.read('v_ssrotate',2)==0x40 and m.read('Current_ZoneAndAct',2)==0x301
report['bonus_debug_return_zone_ring_bank_and_radii']=True
print(report,flush=True)
