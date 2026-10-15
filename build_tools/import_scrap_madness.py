#!/usr/bin/env python3
"""Rebuild Scrap Madness assets from sonicretro/s1disasm (REV01).

The source checkout is read-only. Geometry keeps S1's tiles, blocks and
collision shapes; 256px chunks become deduplicated 128px chunks. Ring groups
become the existing ring-manager format, while placement IDs/flags become
the six-byte S3&K format used by Mystic Island.
"""
from pathlib import Path
import argparse
import json
import re
import struct
import sys
from convert_s1_ss_background import enigma, kosinski_plus, kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]
SENTINEL = bytes.fromhex('FFFF00000000')
# Source IDs which already have a compatible Mystic Island implementation.
OBJECTS = {0x0D: 0x7E, 0x15: 0x17, 0x1E: 0x21, 0x26: 0x26,
           0x2A: 0x30, 0x32: 0xAF, 0x41: 0x41, 0x52: 0xAD,
           0x53: 0x1B, 0x5F: 0xAE, 0x66: 0xA0, 0x67: 0xA1,
           0x68: 0xA2, 0x69: 0xA3, 0x6A: 0xA4, 0x6B: 0xA5,
           0x6C: 0xA6, 0x6D: 0xA7, 0x6E: 0xA8, 0x6F: 0xA9,
           0x70: 0xAA, 0x71: 0xAC, 0x72: 0xAB, 0x78: 0x60,
           0x79: 0x79, 0x7D: 0x7D}
RING_STEPS = ((16,0),(24,0),(32,0),(0,16),(0,24),(0,32),
              (16,16),(24,24),(32,32),(-16,16),(-24,24),(-32,32),
              (16,8),(24,16),(-16,8),(-24,16))


def classic_kosinski(data):
    position = 2
    descriptor = int.from_bytes(data[:2], 'little')
    remaining = 16
    output = bytearray()

    def byte():
        nonlocal position
        value = data[position]
        position += 1
        return value

    def bit():
        nonlocal descriptor, remaining, position
        value = descriptor & 1
        descriptor >>= 1
        remaining -= 1
        # The original 68000 routine refills before processing bit 16.
        if not remaining:
            descriptor = int.from_bytes(data[position:position+2], 'little')
            position += 2
            remaining = 16
        return value

    while True:
        if bit():
            output.append(byte())
            continue
        if bit():
            low, high = byte(), byte()
            offset = ((high & 0xF8) << 5 | low) - 8192
            count = (high & 7) + 2
            if not high & 7:
                count = byte()
                if not count:
                    return bytes(output)
                if count == 1:
                    continue
                count += 1
        else:
            count = 2 + bit() * 2 + bit()
            offset = byte() - 256
        assert -len(output) <= offset < 0
        for _ in range(count):
            output.append(output[offset])


def pack(path, raw):
    packed = bytes(kosinski_plus(raw))
    assert kosinski_plus_decode(packed)[0] == raw
    (ROOT/path).parent.mkdir(parents=True, exist_ok=True)
    (ROOT/path).write_bytes(packed)


def number(text):
    text = re.sub(r'\$([\da-fA-F]+)', r'0x\1', text.strip())
    assert re.fullmatch(r'[\dxa-fA-F+*/() \-]+', text), text
    return eval(text, {'__builtins__': {}}, {})


def mapping(source):
    """Read the numeric S1 sprite macros and emit the normal six-byte ABI."""
    entries = re.findall(r'mappingsTableEntry\.w\s+(\.[\w]+)', source)
    frames = {}
    for label, body in re.findall(r'^(\.[\w]+):\s*spriteHeader(.*?)(?=^\.[\w]+_End)',
                                 source, re.M | re.S):
        pieces = []
        for args in re.findall(r'^\s*spritePiece\s+([^;\n]+)', body, re.M):
            x,y,w,h,tile,xf,yf,pal,pri = map(number, args.split(','))
            pieces.append(struct.pack('>bBHh', y, (w-1)*4+h-1,
                                     tile | xf<<11 | yf<<12 | pal<<13 | pri<<15, x))
        frames[label] = struct.pack('>H', len(pieces)) + b''.join(pieces)
    assert entries and all(label in frames for label in entries)
    out = bytearray(len(entries)*2)
    offsets = {}
    for i, label in enumerate(entries):
        frame = frames[label]
        if frame not in offsets:
            offsets[frame] = len(out)
            out.extend(frame)
        struct.pack_into('>H', out, i*2, offsets[frame])
    return bytes(out)


def nemesis_inline(data):
    """Small deterministic Nemesis encoder; preserves source pixels exactly."""
    assert len(data) % 32 == 0
    pixels = [v for byte in data for v in (byte >> 4, byte & 15)]
    codes, i = [], 0
    while i < len(pixels):
        count = 1
        while count < 8 and i + count < len(pixels) and pixels[i + count] == pixels[i]:
            count += 1
        codes.append('111111' + format(count-1, '03b') + format(pixels[i], '04b'))
        i += count
    bits = ''.join(codes)
    bits += '0' * (-len(bits) % 8)
    return struct.pack('>H', len(data)//32) + b'\xff' + bytes(
        int(bits[i:i+8], 2) for i in range(0, len(bits), 8)) + b'\0\0'


def palette_lookup(source, target):
    def rgb(color):
        return (color & 14, (color >> 4) & 14, (color >> 8) & 14)
    def distance(a, b):
        return sum((x-y)**2 for x, y in zip(rgb(a), rgb(b)))
    lookup = [0] + [min(range(1, 16), key=lambda i: distance(c, target[i]))
                    for c in source[1:]]
    # These slots retain their role as the gray ramp. Their S3 shades are
    # intentional; nearest-color matching would shift every shade darker.
    for index in (7, 8, 9):
        lookup[index] = index
    return lookup


def remap_pixels(raw, lookup):
    return bytes(lookup[b >> 4] << 4 | lookup[b & 15] for b in raw)


def remap_player_art(name, raw, lookup):
    """Keep stage-palette parts intact in art shared with player-palette FX."""
    if name == 'SBZ Electrocuter':
        # First eight tiles: line 4 cyan dome and line 3 body. Only the
        # remaining discharge tiles use the shared player palette.
        return raw[:8*32] + remap_pixels(raw[8*32:], lookup)
    if name == 'SBZ Flaming Pipe':
        # Flames use line 1; both pipe ends use stage line 3.
        return remap_pixels(raw[:20*32], lookup) + raw[20*32:]
    return remap_pixels(raw, lookup)


def geometry(source):
    words = enigma((source/'map16/SBZ.eni').read_bytes(), 0)
    blocks = struct.pack('>'+str(len(words))+'H', *words)
    old = classic_kosinski((source/'map256/SBZ (REV01).kos').read_bytes())
    assert len(old) % 512 == 0 and len(blocks) <= 0x1800
    chunks = [bytes(128)]
    chunk_ids = {chunks[0]: 0}
    halves = {(0, x, y): 0 for x in range(2) for y in range(2)}
    layouts = []
    for act in (1,2):
        layout = bytearray(4096)
        for bg in (False,True):
            data = (source/f'levels/sbz{act}{"bg" if bg else ""}.bin').read_bytes()
            width,height = data[0]+1,data[1]+1
            assert len(data) == width*height+2
            for cy in range(16):
                for cx in range(128):
                    if not bg and (cx >= width*2 or cy >= height*2):
                        continue
                    cell = data[2 + (cy//2 % height)*width + cx//2 % width] & 127
                    key = cell,cx&1,cy&1
                    if key not in halves:
                        assert 0 < cell <= len(old)//512
                        words = []
                        for by in range(8):
                            for bx in range(8):
                                offset = (cell-1)*512 + ((cy&1)*8+by)*32 + ((cx&1)*8+bx)*2
                                word = struct.unpack_from('>H',old,offset)[0]
                                assert word & 0x3FF < len(blocks)//8
                                # S1 X/Y flips and solidity become both S2 paths.
                                words.append((word&0x3FF) | (word&0x1800)>>1 |
                                             (word&0x6000)>>1 | (word&0x6000)<<1)
                        chunk = struct.pack('>64H', *words)
                        if chunk not in chunk_ids:
                            chunk_ids[chunk] = len(chunks)
                            chunks.append(chunk)
                        halves[key] = chunk_ids[chunk]
                    layout[cy*256 + (128 if bg else 0) + cx] = halves[key]
        layouts.append(bytes(layout))
        pack(f'level/layout/SMZ_{act}.kosp', layout)
    assert len(chunks) <= 256, len(chunks)
    pack('mappings/16x16/SMZ.kosp', blocks)
    pack('mappings/128x128/SMZ.kosp', b''.join(chunks))
    collisions = (source/'collide/SBZ.bin').read_bytes()
    # The last two source blocks are background-only and have no collision entry.
    assert len(collisions) <= len(blocks)//8
    collisions += bytes(len(blocks)//8-len(collisions))
    (ROOT/'collision/present/SMZ.bin').write_bytes(b''.join(bytes((v,v)) for v in collisions))
    for act in (1,2):
        (ROOT/f'startpos/SMZ_{act}.bin').write_bytes((source/f'startpos/sbz{act}.bin').read_bytes())
        palette = bytearray((source/f'palette/SBZ Act {act}.bin').read_bytes())
        assert len(palette) == 96
        # The first imported row is palette line 2, shared by terrain/objects.
        palette[14:20] = (ROOT/'palette/SonicAndTails.bin').read_bytes()[14:20]
        (ROOT/f'palette/SMZ{act}.bin').write_bytes(palette)
    return {'blocks':len(blocks)//8,'chunks':len(chunks)}


def placements(source):
    report = []
    for act in (1,2):
        name = 'sbz1 (REV01).bin' if act == 1 else 'sbz2.bin'
        data = (source/'objpos'/name).read_bytes()
        objects, rings = [], []
        for x,y,oid,subtype in struct.iter_unpack('>HHBB',data):
            if x == 65535:
                break
            oid &= 127
            if oid == 0x25:
                dx,dy = RING_STEPS[subtype>>4]
                for n in range(min(subtype&7,6)+1):
                    rings.append((x+n*dx,(y&0xFFF)+n*dy))
                continue
            if oid == 0x6F and subtype & 128:
                group = (source/f'objpos/platforms/sbz1pf{(subtype&127)+1}.bin').read_bytes()
                count = struct.unpack_from('>H',group)[0]+1
                assert len(group) in (count*6+2,count*6+8)
                for px,py,psub in struct.iter_unpack('>HHH',group[2:2+count*6]):
                    objects.append((px,py,OBJECTS[oid],psub&255))
                continue
            assert oid in OBJECTS, hex(oid)
            if oid == 0x15:
                subtype = 0x50 | (subtype & 15)
            if oid == 0x26:
                # S1 has unused high-nibble monitor variants; decode the item.
                subtype = {0:0,1:3,2:2,3:5,4:6,5:7,6:4,7:0,8:0}[subtype & 15]
            if oid == 0x32:
                subtype &= 15   # original SBZ switches use normal press behavior
            # S1 flags are Y bits 14/15; S3&K uses bits 13/14.
            objects.append((x,(y&0xFFF)|((y&0xC000)>>1),OBJECTS[oid],subtype))
        objects.sort()
        rings = sorted(set(rings))
        assert len(rings) <= 254, len(rings)
        assert len(objects) <= 768
        (ROOT/f'level/objects/SMZ_{act}.bin').write_bytes(
            b''.join(struct.pack('>HHBB',*row) for row in objects) + SENTINEL)
        (ROOT/f'level/rings/SMZ_{act}.bin').write_bytes(
            b''.join(struct.pack('>HH',*row) for row in rings) + b'\xFF\xFF')
        report.append({'act':act,'objects':len(objects),'rings':len(rings)})
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--rom',type=Path,required=True)
    p.add_argument('--listing',type=Path,required=True)
    args=p.parse_args()
    source=args.source
    # Execute the hack's real decoder instead of depending on a third-party codec.
    sys.argv=['decode','--rom',str(args.rom),'--listing',str(args.listing)]
    namespace={'__file__':str(ROOT/'build_tools/check_object_manager.py')}
    exec((ROOT/'build_tools/check_object_manager.py').read_text().split('m=Manager()')[0],namespace)
    machine=namespace['Native']()

    def nemesis(path):
        data=path.read_bytes()
        count=struct.unpack_from('>H',data)[0]&32767
        assert count*32 < 0x8000
        machine.cpu.mem_write(0x300000,data)
        machine.act('NemDecToRAM',limit=1000000,regs={namespace['UC_M68K_REG_A0']:0x300000,
                                      namespace['UC_M68K_REG_A4']:0xFF0000})
        return bytes(machine.cpu.mem_read(0xFF0000,count*32))

    report=geometry(source)
    report['acts']=placements(source)
    art=nemesis(source/'artnem/8x8 - SBZ.nem')
    pack('art/kosinski/level/8x8 - SMZ.kosp',art)
    (ROOT/'art/kosinski/level/8x8 - SMZ.unc').write_bytes(art)
    maps={'Rotating Junction':'Jun','Running Disc':'Disc','Trapdoor':'Trap',
          'SBZ Spinning Platforms':'Spin','Saws and Pizza Cutters':'Saw',
          'SBZ Stomper and Door':'Stomp','SBZ Vanishing Platforms':'VanP',
          'Flamethrower':'Flame','Electrocuter':'Elec','Girder Block':'Gird',
          'Invisible Barriers':'Invis','Moving Blocks (MZ and SBZ)':'MBlock',
          'Bomb Enemy':'Bomb','Button':'But'}
    for filename,label in maps.items():
        (ROOT/f'mappings/sprite/SMZ {label}.bin').write_bytes(mapping((source/f'_maps/{filename}.asm').read_text()))
    art_names=('SBZ Running Disc','SBZ Junction Wheel','SBZ Pizza Cutter',
               'SBZ Stomper','SBZ Spinning Platform','SBZ Trapdoor',
               'SBZ Collapsing Floor','SBZ Electrocuter','SBZ Vanishing Block',
               'SBZ Flaming Pipe','SBZ Small Vertical Door','SBZ Sliding Floor Trap',
               'SBZ Large Horizontal Door','SBZ Crushing Girder','Enemy Bomb','SBZ Giant Spikeball',
               'SBZ Button')
    for name in art_names:
        filename = {'SBZ Giant Spikeball': 'SYZ Large Spikeball',
                    'SBZ Button': 'Switch'}.get(name, name)
        path=source/f'artnem/{filename}.nem'
        if not path.exists() and name=='Enemy Bomb':
            path=next((source/'artnem').glob('*Bomb*'))
        data = path.read_bytes()
        if name in ('SBZ Flaming Pipe', 'SBZ Electrocuter',
                    'SBZ Spinning Platform', 'Enemy Bomb', 'SBZ Button'):
            original = struct.unpack('>16H', (source/'palette/Sonic.bin').read_bytes())
            target = struct.unpack('>16H', (ROOT/'palette/SonicAndTails.bin').read_bytes()[:32])
            data = nemesis_inline(remap_player_art(name, nemesis(path),
                                                 palette_lookup(original, target)))
        (ROOT/f'art/nemesis/S1/{name}.nem').write_bytes(data)
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    main()
