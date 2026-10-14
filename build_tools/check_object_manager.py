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
from itertools import product

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
        # layout_id is a test-only projection through the placement pointer table.
        # The engine stores and tests the full code pointer, never that byte ID.
        self.object_codes = [0] + list(struct.unpack_from(
            '>255I', args.rom.read_bytes(), self.s['Obj_Index']))
        self.ids_by_code = {pointer: oid for oid, pointer in
                            enumerate(self.object_codes[1:], 1)}
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
        # Real 68000 addresses are 24-bit. Caterkiller stores a trail index
        # above its parent pointer.
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
        if field == 'layout_id':
            field, value, size = 'code', self.object_codes[value], 4
        elif field in ('code', 'obID'):
            size = 4
        if isinstance(obj, str):
            obj = self.s[obj]
        self.cpu.mem_write((obj + self.s[field]) & 0xFFFFFF,
                          (value & ((1 << (8 * size)) - 1)).to_bytes(size, 'big'))

    def get(self, obj, field, size=1):
        projected = field == 'layout_id'
        if projected:
            field, size = 'code', 4
        elif field in ('code', 'obID'):
            size = 4
        if isinstance(obj, str):
            obj = self.s[obj]
        value = int.from_bytes(self.cpu.mem_read((obj + self.s[field]) & 0xFFFFFF, size), 'big')
        return self.ids_by_code.get(value, value) if projected else value

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
            for field, value, size in [('layout_id', object_id, 1), ('obRoutine', 2, 1),
                    ('obRender', 0x84, 1), ('obHeight', 19, 1), ('obWidth', 9, 1),
                    ('default_y_radius', 19, 1), ('default_x_radius', 9, 1),
                    ('obX', 600, 2), ('obY', 116, 2), ('obTopSolidBit', 12, 1),
                    ('obLRBSolidBit', 13, 1)]:
                self.put(obj, field, value, size)

class Manager(Native):
    def pool(self):
        return range(self.s['v_lvlobjspace'],self.s['v_lvlobjend'],self.s['object_size'])
    def live(self):
        return {self.get(a,'respawn_addr',2):a for a in self.pool() if self.get(a,'layout_id') and self.get(a,'respawn_addr',2)}
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
        ptrs=[self.get(a,'respawn_addr',2) for a in self.pool() if self.get(a,'layout_id') and self.get(a,'respawn_addr',2)]
        assert len(ptrs)==len(set(ptrs)),('duplicate placement',ptrs)
        for ptr,a in live.items():
            idx=(ptr-table)&65535
            assert idx<len(rows),(hex(ptr),idx,len(rows))
            x,y,obj,sub=rows[idx]
            assert self.get(a,'obX',2)==x and self.get(a,'obY',2)==y&0xFFF
            assert self.get(a,'code')==self.object_codes[obj]
            assert self.get(a,'obSubtype')==sub
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
    m.put(a,'layout_id',0x35)
m.cam(0,0)
m.act('ObjectsManager')
assert not m.live() and m.read('Object_load_retry')
assert bytes(m.cpu.mem_read(m.s['Object_Respawn_Table']&0xFFFFFF,95))==bytes(95)
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
    for f,v,n in [('layout_id',objid,1),('obX',240,2),('obY',240,2),('obSubtype',sub,1),('respawn_addr',ptr,2)]:
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
    assert m.get(obj,'layout_id')==0 and m.read('Object_Respawn_Table')==state&127
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
for objid,sub,routine,fields,needed in [(0x1D,16,'Bridge',('Bridge_child1','Bridge_child2'),2),(0x1E,0x10,'HPZ_Waterfall',('objoff_3C','objoff_40'),2),(0x50,0x11,'Obj50',('objoff_3A',),1)]:
    for free in range(needed):
        obj,ptr=setup(objid,sub)
        for a in pool()[1:]:
            m.put(a,'layout_id',0x55)
        for a in pool()[1:1+free]:
            m.put(a,'layout_id',0)
        m.act(routine,obj)
        assert m.get(obj,'obRoutine')==0 and m.read('Object_Respawn_Table')==0x80,(routine,free)
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
assert m.read('Object_Respawn_Table')==0x85
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
    assert m.read('Object_Respawn_Table')==5
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
assert m.read('Object_Respawn_Table')==3 and m.get(obj,'layout_id')==0
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
print(report,flush=True)
