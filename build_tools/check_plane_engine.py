#!/usr/bin/env python3
"""Audit Mode 1 plane files and execute the assembled CD drawing path.

Uses independent world-coordinate tile lookup and applies real VDP records.
Exercises word IDs across PRG banks, unequal planes, all block flips, live
block/layout edits, cache reuse, scroll reversals and vertical/VRAM wrapping.
"""
from pathlib import Path
import argparse
import json
import random
import struct
from level_layout import load, encode, decode, from_s2
from convert_s1_ss_background import kosinski_plus_decode
from native_test_core import Native, UC_M68K_REG_SR, UC_M68K_REG_A7, UC_M68K_REG_A6, UC_M68K_REG_PC

ROOT = Path(__file__).resolve().parents[1]


def source_audit(compare_legacy=False):
    count = 0
    for path in sorted((ROOT/'level/layout').rglob('*.kosp')):
        fg, bg = load(path)
        if compare_legacy:
            old = ROOT/'md-only/layout'/path.relative_to(ROOT/'level/layout')
            assert (fg, bg) == from_s2(kosinski_plus_decode(old.read_bytes())[0]), path
        count += 1
    sample = encode([[0, 256, 768, 1023]], [[1023], [768], [256]])
    assert encode(*decode(sample)) == sample
    for offset in (0, 2, 4, 12, 76, 588, 652, len(sample)-1):
        damaged = bytearray(sample); damaged[offset] ^= 1
        try:
            decode(damaged)
        except (ValueError, struct.error):
            pass
        else:
            # A valid cell edit is fine; malformed offsets/header must fail.
            assert offset == len(sample)-1
    return count


class Drawing:
    def __init__(self, rom, listing):
        self.m = Native(rom, listing)
        self.s, self.cpu = self.m.s, self.m.sub
        self.vram = bytearray(65536)
        self.stop, self.stack = 0x7FBF0, self.s['MCD_SubStack_Top']-4
        self.bytes = []
        self.samples = 0

    def put(self, name, value, size=2):
        self.cpu.mem_write(self.s[name], (value & ((1 << (size*8))-1)).to_bytes(size, 'big'))

    def call(self, label):
        self.cpu.reg_write(UC_M68K_REG_SR, 0x2700)
        self.cpu.reg_write(UC_M68K_REG_A7, self.stack)
        self.cpu.mem_write(self.stack, struct.pack('>I', self.stop))
        self.cpu.emu_start(self.s[label], self.stop, count=600000)
        assert self.cpu.reg_read(UC_M68K_REG_PC) == self.stop, label
        assert self.cpu.reg_read(UC_M68K_REG_A7) == self.stack+4, label

    def install(self, fg, bg, chunks, blocks):
        self.fg, self.bg, self.chunks, self.blocks = fg, bg, chunks, blocks
        for name, data in (('MCD_TerrainLayout_Sub', encode(fg, bg)),
                           ('MCD_ChunkTable_SubStart', chunks), ('MCD_TerrainBlocks_Sub', blocks)):
            self.cpu.mem_write(self.s[name], data)
        self.put('MCD_TerrainFGDraw_Sub', self.s['Plane_SourceForeground'], 4)
        self.put('MCD_TerrainBGDraw_Sub', self.s['Plane_SourcePlain'], 4)
        self.call('Plane_Invalidate')

    def tile(self, plane, x, y):
        cx, cy = (x & 0x7FFF)//128, (y & 0xFFF)//128
        if plane is self.fg:
            chunk = plane[cy][cx] if cy < len(plane) and cx < len(plane[0]) else 0
        else:
            chunk = plane[cy % len(plane)][cx % len(plane[0])]
        entry = struct.unpack_from('>H', self.chunks, chunk*128+((y//16&7)*8+(x//16&7))*2)[0]
        bx, by = (x//8&1)^bool(entry&0x400), (y//8&1)^bool(entry&0x800)
        tile = struct.unpack_from('>H', self.blocks, (entry&0x3FF)*8+(by*2+bx)*2)[0]
        return tile ^ (0x800 if entry&0x400 else 0) ^ (0x1000 if entry&0x800 else 0)

    def draw(self, x, y, bx, by, provider='Plain', redraw=False):
        self.put('MCD_TerrainCamera_Sub', x)
        self.cpu.mem_write(self.s['MCD_TerrainCamera_Sub']+4, struct.pack('>H', y&65535))
        self.put('MCD_TerrainBG_Sub', bx)
        self.put('MCD_TerrainBG2_Sub', bx*3//4)
        self.put('MCD_TerrainBG3_Sub', bx//2)
        self.put('MCD_TerrainVScroll_Sub', by)
        self.put('MCD_TerrainBGDraw_Sub', self.s['Plane_Source'+provider], 4)
        self.put('MCD_TerrainRedraw_Sub', int(redraw), 1)
        start = self.s['MCD_TerrainStream_Sub']
        self.cpu.reg_write(UC_M68K_REG_A6, start)
        self.call('Plane_DrawFrame')
        end = self.cpu.reg_read(UC_M68K_REG_A6)
        raw = bytes(self.cpu.mem_read(start, end-start))
        self.bytes.append(len(raw))
        assert len(raw) < self.s['MCD_TerrainStreamCapacity']-0x40
        p = 0
        while p < len(raw):
            command, count = struct.unpack_from('>IH', raw, p); p += 6
            address = ((command >> 16)&0x3FFF) | ((command&3)<<14)
            assert command&0xC0000000 == 0x40000000, hex(command)
            for _ in range(count*2):
                self.vram[address:address+2] = raw[p:p+2]; p += 2
                address = (address+2)&65535
        assert p == len(raw)
        for plane, px, py, bank in ((self.fg,x,y,0xC000),(self.bg,bx,by,0xE000)):
            for sy in range(0,224,8):
                wy = (py+sy)&65535
                band = wy//16
                if plane is self.bg and provider != 'Plain':
                    if provider == 'SMZ':
                        row = band&31; px = 0 if row<4 else bx//2 if row<14 else bx*3//4 if row<21 else bx
                    elif provider == 'GHZ':
                        row = band&15; px = bx//2 if 4<=row<7 else bx*3//4 if 7<=row<9 or (row==9 and not wy&8) else 0
                    elif provider == 'Fixed':
                        px = 0
                fixed = plane is self.bg and (provider == 'Fixed' or (provider == 'SMZ' and band&31<4) or (provider == 'GHZ' and (not 4<=band&15<10 or (band&15==9 and wy&8))))
                for sx in range(0,512 if fixed else 320,8):
                    wx = (px+sx)&65535
                    address = bank+(wy//8&31)*128+(wx//8&63)*2
                    actual = struct.unpack_from('>H', self.vram, address)[0]
                    expected = self.tile(plane, wx, wy)
                    assert actual == expected, ('tile',len(self.bytes),provider,bank,(x,y,bx,by),(sx,sy),(wx,wy),hex(actual),hex(expected))
                    self.samples += 1
        return len(raw)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--legacy-equivalence', action='store_true')
    args = p.parse_args()
    files = source_audit(args.legacy_equivalence)
    d = Drawing(args.rom, args.listing)
    # Execute the actual MD act/era selection, stopping at its codec boundary.
    from native_test_core import (UC_M68K_REG_A0, UC_M68K_REG_A1, UC_M68K_REG_A2,
                                  UC_M68K_REG_D2, UC_M68K_REG_D3)
    zones = ['GHZ','LZ','CPZ','EHZ','HPZ','HTZ','MTZ','LV07','SMZ',
             'LV09','LV0A','LV0B','LV0C','LV0D','LV0E','LV0F']
    eras = ['', 'past/', 'good future/', 'bad future/']
    rom = args.rom.read_bytes()
    begin,end = d.s['MCD_CompressedAssets'],d.s['MCD_CompressedAssets_End']
    spans = dict(struct.iter_unpack('>II',rom[begin:end]))
    for name in ('Level_Index','Level_Index_Past','Level_Index_GoodFuture','Level_Index_BadFuture'):
        assert d.s[name]%2 == 0, (name,'odd word table')
    d.m.cpu.mem_write(d.s['MCD_KosToCD'], bytes.fromhex('4E75'))
    for zone, name in enumerate(zones):
        for act in range(4):
            d.m.write('Current_ZoneAndAct',zone*256+act,2)
            d.m.act('GetLevelPlaneRecord')
            assert d.m.cpu.reg_read(UC_M68K_REG_A2) == d.s['LevelPlane_Records']+(zone*4+act)*24
            for era, folder in enumerate(eras):
                d.m.write('Current_Timezone',era)
                d.m.act('LevelLayoutLoad')
                address = d.m.cpu.reg_read(UC_M68K_REG_A0)
                assert address%2 == 0, (name,act,era,'odd layout archive')
                expected = (ROOT/f'level/layout/{folder}{name}_{act+1}.kosp').read_bytes()
                assert rom[address:address+len(expected)] == expected, (name,act,era)
                assert d.m.cpu.reg_read(UC_M68K_REG_A1) == d.s['MCD_TerrainLayout_Sub']
                assert spans[address] == address+len(expected), (name,act,era,'compressed span')
                d.m.act('GetLevelArtHeader')
                header = d.m.cpu.reg_read(UC_M68K_REG_A2)
                pointer = struct.unpack_from('>I',rom,header+8)[0]&0xFFFFFF
                chunks = kosinski_plus_decode(rom[pointer:])[0]
                assert len(chunks)%128 == 0 and len(chunks)<=0x20000
                fg,bg = load(ROOT/f'level/layout/{folder}{name}_{act+1}.kosp')
                assert max(v for plane in (fg,bg) for row in plane for v in row) < len(chunks)//128, (name,act,era,'unloaded chunk')
    rng = random.Random(504)
    # Deliberately unequal, non-power-of-two BG dimensions and IDs in all banks.
    fg = [[rng.randrange(1024) for _ in range(37)] for _ in range(25)]
    bg = [[rng.randrange(1024) for _ in range(7)] for _ in range(3)]
    chunks = b''.join(struct.pack('>H', rng.randrange(32)|rng.randrange(4)*0x400) for _ in range(1024*64))
    blocks = b''.join(struct.pack('>H', rng.randrange(0x10000)) for _ in range(32*4))
    d.install(fg,bg,chunks,blocks)
    for provider in ('Plain','SMZ','GHZ','Fixed'):
        d.call('Plane_Invalidate')
        for x,y in [(0,0),(0,0),(16,0),(48,16),(32,32),(0,240),(752,224),(768,228),
                    (752,244),(768,256),(784,272),(3008,1824),(3008,0),(0,0)]:
            d.draw(x,y,x//2,y//8,provider)
        for i in range(100):
            d.draw(1024+i*16, 1200+i*8, 512+i*8, 200+i*2, provider)
        assert d.draw(2608,1992,1304,398,provider)==0
    # Collision's independent lookup must reach the same physical chunk cells.
    for _ in range(1000):
        x, y = rng.randrange(32768), rng.randrange(4096)
        d.cpu.reg_write(UC_M68K_REG_D2,y)
        d.cpu.reg_write(UC_M68K_REG_D3,x)
        d.call('MCD_SubFindTerrainBlock')
        cid = fg[y//128][x//128] if y//128<len(fg) and x//128<len(fg[0]) else 0
        expected = d.s['MCD_ChunkTable_SubStart']+cid*128+(y//16&7)*16+(x//16&7)*2
        assert d.cpu.reg_read(UC_M68K_REG_A1)==expected
    # Live block edits stay in PRG RAM and are observed on an explicit redraw.
    blocks = bytes(v^0x21 for v in blocks)
    d.blocks = blocks
    d.cpu.mem_write(d.s['MCD_TerrainBlocks_Sub'], blocks)
    d.draw(2608,1992,1304,398,'Fixed',True)
    # Layout service reads/writes words, including IDs beyond 255.
    args_address = d.s['MCD_SubMainArgument']
    d.cpu.mem_write(args_address, struct.pack('>HH',0x0102,1023))
    from native_test_core import UC_M68K_REG_D0
    d.cpu.reg_write(UC_M68K_REG_D0,d.s['MCD_CommandLayoutWrite'])
    d.call('MCD_SubTerrainLayout')
    assert d.cpu.reg_read(UC_M68K_REG_D0)==1023
    d.cpu.reg_write(UC_M68K_REG_D0,d.s['MCD_CommandLayoutRead'])
    d.call('MCD_SubTerrainLayout')
    assert d.cpu.reg_read(UC_M68K_REG_D0)==1023
    result = dict(layouts=files, draws=len(d.bytes), tile_samples=d.samples, max_record_bytes=max(d.bytes),
                  word_ids=True, independent_dimensions=True, mutable_blocks=True, act_era_selections=256, collision_lookups=1000)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(result)


if __name__ == '__main__': main()
