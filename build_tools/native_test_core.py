"""Reusable 68000 ROM fixtures for native checks and asset importers.

Importing this module does not parse arguments or run regressions. Pass the
matching ROM and listing to Native/Manager; defaults use this checkout's build.
Sound/DMA/VDP boundaries are stubbed. CD terrain requests execute the assembled
executor in a second 68000; hardware scheduling is covered by libretro checks.
"""
from pathlib import Path
import re
import struct
from object_layout import decode, encode, with_timezones, SIZE, TERMINATOR

try:
    from unicorn import (Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN, UC_HOOK_CODE,
                         UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE,
                         UC_HOOK_MEM_READ_UNMAPPED, UC_MEM_READ)
    from unicorn.m68k_const import *
except ImportError:
    raise SystemExit('This optional ROM test requires the unicorn Python package.')

ROOT = Path(__file__).resolve().parent.parent
STOP = 0x3FFF00
DATA = [UC_M68K_REG_D0, UC_M68K_REG_D1, UC_M68K_REG_D2, UC_M68K_REG_D3]


class Native:
    def __init__(self, rom=None, listing=None):
        rom = Path(rom) if rom is not None else ROOT / 's2built.bin'
        listing = Path(listing) if listing is not None else ROOT / 'md-main.lst'
        data = rom.read_bytes()
        listing = listing.read_text()
        assert 'Symbol Table' in listing, 'Build must finish before testing its listing'
        self.s = {name: int(value, 16) for name, value in re.findall(
            r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', listing)}
        self.respawn_base = 1 if 'MCD_SubObjects' in self.s or 'Object_Respawn_Base' in self.s else self.s['Object_Respawn_Table'] & 65535
        self.stack = (self.s['v_systemstack'] & 0xFFFFFF) - 4
        self.cpu = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
        self.cpu.ctl_set_cpu_model(UC_CPU_M68K_M68000)
        self.cpu.mem_map(0, 0x400000)
        # Model the MD-visible bank-0 chunk/scene storage for native fixtures.
        # Hardware ownership and bank switching belong to the emulator checks.
        if self.s['MegaCDMode1']:
            self.cpu.mem_map(0x420000, 0x20000)
        if 'MCD_TerrainRequest' in self.s:
            self.cpu.mem_map(0x600000, 0x40000)
            self.cpu.mem_map(0xA12000, 0x1000)
            self.sub = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
            self.sub.ctl_set_cpu_model(UC_CPU_M68K_M68000)
            self.sub.mem_map(0, 0xC0000)
            self.sub.mem_map(0xFF0000, 0x10000)
            self.sub.mem_map(0xFFFF0000, 0x10000)
            begin, end = self.s['MCD_SubProgram'], self.s['MCD_SubProgramEnd']
            self.sub.mem_write(0, data[begin:end])
        self.cpu.mem_map(0xFF0000, 0x10000)
        self.cpu.mem_map(0xFFFF0000, 0x10000)
        self.cpu.mem_write(0, data)
        # layout_id is a test-only projection through the placement pointer table.
        # The engine stores and tests the full code pointer, never that byte ID.
        self.object_codes = [0] + list(struct.unpack_from(
            '>255I', data, self.s['Obj_Index']))
        self.ids_by_code = {pointer: oid for oid, pointer in
                            enumerate(self.object_codes[1:], 1)}
        for label in ('QueueDMATransfer', 'PlayMusic', 'PlaySound', 'PlaySound_Special'):
            self.cpu.mem_write(self.s[label], bytes.fromhex('4E75'))
        self.cpu.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, self.bus)
        self.cpu.hook_add(UC_HOOK_MEM_READ_UNMAPPED, self.alias)
        self.cpu.hook_add(UC_HOOK_CODE, self.dispatch_hook)
        self.uploads = []

    def bus(self, cpu, access, address, size, value, unused):
        physical = address & 0xFFFFFF
        if access != UC_MEM_READ:
            assert (physical >= 0xFF0000 or
                    (self.s['MegaCDMode1'] and 0x420000 <= physical < 0x440000) or
                    ('MCD_TerrainRequest' in self.s and
                     (0x600000 <= physical < 0x640000 or 0xA12000 <= physical < 0xA13000))), f'Unexpected CPU write outside RAM: {address:X}'
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

    def dispatch_hook(self, cpu, address, size, unused):
        if address in (self.s.get('MCD_TerrainRequest'), self.s.get('MCD_WaitReply')):
            waiting = address == self.s.get('MCD_WaitReply')
            command = int.from_bytes(cpu.mem_read(0xA12010, 2), 'big') if waiting else cpu.reg_read(UC_M68K_REG_D0) & 65535
            self.cd_request(command)
            if waiting:
                cpu.mem_write(0xA1202E, bytes(cpu.mem_read(0xA1201E, 2)))
            stack = cpu.reg_read(UC_M68K_REG_A7) & 0xFFFFFF
            target = int.from_bytes(cpu.mem_read(stack, 4), 'big')
            cpu.reg_write(UC_M68K_REG_SR, cpu.reg_read(UC_M68K_REG_SR) & ~1)
            cpu.reg_write(UC_M68K_REG_A7, stack + 4)
            cpu.reg_write(UC_M68K_REG_PC, target)
            return
        self.hook(cpu, address, size, unused)

    def refresh_terrain(self):
        # Legacy native fixtures edit MD staging. Refresh CD tables only for
        # geometry calls; hardware boot/ownership is checked under libretro.
        s, sub, cpu = self.s, self.sub, self.cpu
        for source, dest, length in (
                ('Chunk_Table', 'MCD_ChunkTable_SubStart', 0x8000),
                ('v_16x16', 'MCD_TerrainBlocks_Sub', 0x1800),
                ('v_lvllayout', 'MCD_TerrainLayout_Sub', 0x1000)):
            sub.mem_write(s[dest], bytes(cpu.mem_read(s[source] & 0xFFFFFF, length)))
        # Older ROMs remain usable as comparison baselines.
        legacy = ('S1_' if 'S1_ColArray1' in s and
                  self.read('Current_Zone') in (1, s['id_SMZ']) else '')
        for source, dest, length in (
                ('ColArray1', 'MCD_TerrainHeights_Sub', 0x1000),
                ('ColArray2', 'MCD_TerrainWidths_Sub', 0x1000),
                ('AngleMap', 'MCD_TerrainAngles_Sub', 0x100)):
            sub.mem_write(s[dest], bytes(cpu.mem_read(s[legacy + source], length)))
        for i in (1, 2):
            pointer = self.read('v_colladdr' + str(i), 4) & 0xFFFFFF
            # Preserve independently supplied fixture paths, including offsets.
            dest = s['MCD_TerrainIndex_Sub'] + (i - 1) * s['MCD_TerrainIndexCapacity']
            # The ordinary allocation is interleaved. The fixture's second
            # table lives in otherwise unused PRG RAM for independent paths.
            if i == 2:
                dest = 0x70000
            sub.mem_write(dest, bytes(cpu.mem_read(pointer, s['MCD_TerrainIndexCapacity'])))
            sub.mem_write(s['MCD_TerrainPath' + str(i) + '_Sub'], struct.pack('>I', dest))
        path = 2 if self.read('Collision_addr', 4) == self.read('v_colladdr2', 4) else 1
        sub.mem_write(s['MCD_TerrainPath_Sub'], bytes(sub.mem_read(s['MCD_TerrainPath' + str(path) + '_Sub'], 4)))
        sub.mem_write(s['MCD_TerrainPrimary_Sub'], bytes((self.read('Primary_Angle'), self.read('Secondary_Angle'))))
    def cd_request(self, command):
        s, sub, cpu = self.s, self.sub, self.cpu
        kind = command & 255
        if kind in (7, 8, 11) or kind >= 0x20:
            self.refresh_terrain()
        if kind in (5, 6, 12, 14, 15, 16, 17, 18):
            sub.mem_write(0x80000, bytes(cpu.mem_read(0x600000, 0x40000)))
        sub.mem_write(0xFF800E, bytes(cpu.mem_read(0xA1200E, 0x22)))
        sub.mem_write(s['MCD_SubMainCommand'], struct.pack('>H', command))
        sub.mem_write(s['MCD_SubOwnFlags'], bytes((s['MCD_ServiceReady'],)))
        routine = {5: 'MCD_SubTerrainLoad', 6: 'MCD_SubTerrainDraw', 12: 'MCD_SubObjectsLoad',
                   13: 'MCD_SubObjectState', 14: 'MCD_SubDecompress',
                   15: 'MCD_SubDecompress', 16: 'MCD_SubDecompress', 17: 'MCD_SubDecompress',
                   18: 'MCD_SubArtFrame', 7: 'MCD_SubTerrainProbe', 8: 'MCD_SubTerrainProbe',
                   9: 'MCD_SubTerrainLayout', 10: 'MCD_SubTerrainLayout',
                   11: 'MCD_SubTerrainAir'}.get(kind, 'MCD_SubTerrainObject')
        stop, stack = 0x7FBF0, s['MCD_SubStack_Top'] - 4
        sub.mem_write(stack, struct.pack('>I', stop))
        sub.reg_write(UC_M68K_REG_SR, 0x2700)
        sub.reg_write(UC_M68K_REG_A7, stack)
        sub.reg_write(UC_M68K_REG_D0, command)
        sub.emu_start(s[routine], stop, count=300000)
        assert sub.reg_read(UC_M68K_REG_PC) == stop, routine
        assert sub.reg_read(UC_M68K_REG_A7) == stack + 4, routine
        result = sub.reg_read(UC_M68K_REG_D0) & 65535
        sub.mem_write(s['MCD_SubOwnResult'], struct.pack('>H', result))
        cpu.mem_write(0xA12020, bytes(sub.mem_read(0xFF8020, 0x10)))
        cpu.mem_write(0xA1200F, bytes(sub.mem_read(0xFF800F, 1)))
        cpu.reg_write(UC_M68K_REG_D0, result)
        if kind in (5, 6, 12, 14, 15, 16, 17, 18):
            cpu.mem_write(0x600000, bytes(sub.mem_read(0x80000, 0x40000)))

    def placement_handle(self, index):
        return self.respawn_base + index

    def placement_read(self, index=0, size=1):
        return int.from_bytes(self.placement_data(size, index), 'big')

    def placement_data(self, size, index=0):
        if 'MCD_SubObjects' in self.s:
            base=int.from_bytes(self.sub.mem_read(self.s['MCD_ObjectRespawnBase_Sub'],4),'big') or self.s['MCD_ObjectRespawn_Sub']
            return bytes(self.sub.mem_read(base + index, size))
        base = (self.read('Object_Respawn_Base', 4) if 'Object_Respawn_Base' in self.s else 0) or self.s['Object_Respawn_Table']
        return bytes(self.cpu.mem_read((base & 0xFFFFFF) + index, size))

    def placement_write(self, index, value, size=1):
        data = value if isinstance(value, bytes) else value.to_bytes(size, 'big')
        if 'MCD_SubObjects' in self.s:
            base=int.from_bytes(self.sub.mem_read(self.s['MCD_ObjectRespawnBase_Sub'],4),'big') or self.s['MCD_ObjectRespawn_Sub']
            self.sub.mem_write(base + index, data)
        else:
            base = (self.read('Object_Respawn_Base', 4) if 'Object_Respawn_Base' in self.s else 0) or self.s['Object_Respawn_Table']
            self.cpu.mem_write((base & 0xFFFFFF) + index, data)

    def write(self, name, value, size=1):
        self.cpu.mem_write(self.s[name] & 0xFFFFFF, value.to_bytes(size, 'big'))

    def read(self, name, size=1):
        return int.from_bytes(self.cpu.mem_read(self.s[name] & 0xFFFFFF, size), 'big')

    def put(self, obj, field, value, size=1):
        if field == 'layout_id':
            field, value, size = 'code', self.object_codes[value], 4
        elif field == 'obSubtype':
            size = 2
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
        elif field == 'obSubtype':
            size = 2
        elif field in ('code', 'obID'):
            size = 4
        if isinstance(obj, str):
            obj = self.s[obj]
        value = int.from_bytes(self.cpu.mem_read((obj + self.s[field]) & 0xFFFFFF, size), 'big')
        return self.ids_by_code.get(value, value) if projected else value

    def act(self, routine, obj=None, regs=None, limit=100000):
        self.cpu.reg_write(UC_M68K_REG_SR, 0x2000)
        for reg in DATA:
            self.cpu.reg_write(reg, 0xA5A51234)
        if obj is not None:
            address = self.s[obj] if isinstance(obj, str) else obj | 0xFF000000
            self.cpu.reg_write(UC_M68K_REG_A0, address)
        for reg, value in (regs or {}).items():
            self.cpu.reg_write(reg, value)
        self.cpu.reg_write(UC_M68K_REG_A7, self.stack)
        self.cpu.mem_write(self.stack, struct.pack('>I', STOP))
        self.cpu.emu_start(self.s[routine], STOP, count=limit)
        assert self.cpu.reg_read(UC_M68K_REG_PC) == STOP, routine
        assert self.cpu.reg_read(UC_M68K_REG_A7) == self.stack + 4, routine

    def start(self):
        if self.s['MegaCDMode1']:
            self.cpu.mem_write(0x420000, bytes(0x20000))
        self.cpu.mem_write(0xFF0000, bytes(0x10000))
        self.cpu.mem_write(0xFFFF0000, bytes(0x10000))
        if 'MCD_TerrainRequest' in self.s:
            self.sub.mem_write(self.s['MCD_ChunkTable_SubStart'], bytes(self.s['MCD_SubUserRAM_End'] - self.s['MCD_ChunkTable_SubStart']))
            self.sub.mem_write(self.s['MCD_ObjectRespawnBase_Sub'],struct.pack('>I',self.s['MCD_ObjectRespawn_Sub']))
            self.cpu.mem_write(0xA12000, bytes(0x1000))
            self.cpu.mem_write(0xA12003, b'\1')
            self.write('MCD_status', 1)
            self.write('MCD_TerrainReady', 1)
        if 'Object_Respawn_Base' in self.s:
            self.write('Object_Respawn_Base', self.s['Object_Respawn_Table'] & 0xFFFFFF, 4)
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
    def act(self, routine, obj=None, regs=None, limit=100000):
        if routine == 'ObjectsManager' and 'MCD_SubObjects' in self.s:
            # Native fixtures call successive loading frames without VBlank.
            # Consume the previous frame's empty stream at the real boundary.
            if self.read('MCD_TerrainPending', 2) == 2:
                super().act('LoadTilesAsYouMove')
        return super().act(routine, obj, regs, limit)
    def pool(self):
        return range(self.s['v_lvlobjspace'],self.s['v_lvlobjend'],self.s['object_size'])
    def live(self):
        return {self.get(a,'respawn_addr',2):a for a in self.pool() if self.get(a,'layout_id') and self.get(a,'respawn_addr',2)}
    def rows(self,name):
        return decode((ROOT/'level/objects'/name).read_bytes())
    def cam(self,x,y):
        self.write('Camera_X_pos',x,2)
        self.write('Camera_Y_pos',y&65535,2)
    def fixture(self,rows):
        # Replace this level's relative pointer with a small ROM fixture near the
        # real index. Keep the leading sentinel and eight-byte placement format.
        self.start()
        i=self.s['ObjPos_Index']
        base=i+0x7000
        self.cpu.mem_write(i,struct.pack('>h',base-i))
        self.cpu.mem_write(base-SIZE,TERMINATOR)
        self.cpu.mem_write(base,encode(with_timezones(r) for r in rows))
        return base
    def verify(self,rows,base=None):
        table=self.respawn_base
        live=self.live()
        ptrs=[self.get(a,'respawn_addr',2) for a in self.pool() if self.get(a,'layout_id') and self.get(a,'respawn_addr',2)]
        assert len(ptrs)==len(set(ptrs)),('duplicate placement',ptrs)
        for ptr,a in live.items():
            idx=(ptr-table)&65535
            assert idx<len(rows),(hex(ptr),idx,len(rows))
            x,y,obj,timezones,sub=with_timezones(rows[idx])
            assert self.get(a,'obX',2)==x and self.get(a,'obY',2)==y&0xFFF
            assert self.get(a,'code')==self.object_codes[obj]
            assert self.get(a,'obSubtype')==sub
            assert self.get(a,'obStatus')==self.get(a,'obRender')==(y>>13)&3
            assert self.placement_read(idx)&128
        if base is not None:
            for side in ('front','back'):
                if 'MCD_SubObjects' in self.s:
                    suffix = side.title() + '_Sub'
                    lp = int.from_bytes(self.sub.mem_read(self.s['MCD_Object' + suffix],4),'big')
                    rp = int.from_bytes(self.sub.mem_read(self.s['MCD_ObjectRespawn' + suffix],4),'big')
                    first = self.s['MCD_ObjectPlacements_Sub']
                    state = int.from_bytes(self.sub.mem_read(self.s['MCD_ObjectRespawnBase_Sub'],4),'big')
                else:
                    lp=self.read('Object_load_addr_'+side,4)
                    rp=self.read('Object_respawn_index_'+side,2)
                    first = base
                    state = (self.read('Object_Respawn_Base', 4) & 65535) if 'Object_Respawn_Base' in self.s else table
                assert lp>=first and (lp-first)%SIZE==0 and (lp-first)//SIZE<=len(rows)
                assert rp==state+(lp-first)//SIZE,(side,hex(lp),hex(rp))
        return live
