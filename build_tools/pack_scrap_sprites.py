#!/usr/bin/env python3
"""Pack the imported SBZ sprite atlas and verify each frame pixel for pixel.

Requires import_scrap_madness.py first. The reference ROM supplies the
unchanged shared mapping tables, not a different or synthetic level.
"""
from pathlib import Path
import struct,re,collections
R=Path(__file__).resolve().parents[1]
import argparse
p=argparse.ArgumentParser(description='Pack SBZ sprites without changing their visible indexed pixels.')
p.add_argument('--source',type=Path,required=True)
p.add_argument('--rom',type=Path,required=True)
p.add_argument('--listing',type=Path,required=True)
args=p.parse_args();S=args.source
from check_sprite_assets import frames
from import_scrap_madness import mapping,nemesis_inline,remap_pixels,palette_lookup
from convert_s1_ss_background import kosinski_plus_decode
import native_test_core as m68k
m = m68k.Native(args.rom, args.listing)
rom = args.rom.read_bytes()
def dec(path):
 d=path.read_bytes();n=struct.unpack_from('>H',d)[0]&32767;m.cpu.mem_write(0x300000,d);m.act('NemDecToRAM',limit=2000000,regs={m68k.UC_M68K_REG_A0:0x300000,m68k.UC_M68K_REG_A4:0xff0000});return bytes(m.cpu.mem_read(0xff0000,n*32))
bank={}
def fill(base,raw):
 for i in range(len(raw)//32):bank[base+i]=raw[i*32:(i+1)*32]
for name,base in [('Stomper',0x2c0),('Small Vertical Door',0x2e8),('Crushing Girder',0x2f0),('Spinning Platform',0x302),('Running Disc',0x344),('Junction Wheel',0x348),('Giant Spikeball',0x391),('Pizza Cutter',0x3b5),('Flaming Pipe',0x3d9),('Collapsing Floor',0x3f5),('Sliding Floor Trap',0x460),('Large Horizontal Door',0x46f),('Electrocuter',0x47e),('Trapdoor',0x492),('Vanishing Block',0x429)]:
 raw=dec(R/f'art/nemesis/S1/SBZ {name}.nem')
 if name=='Giant Spikeball':
  lookup=palette_lookup(struct.unpack('>16H',(S/'palette/Sonic.bin').read_bytes()),struct.unpack('>16H',(R/'palette/SonicAndTails.bin').read_bytes()[:32]))
  # Ball and chain use the player palette; the anchor uses stage line 3.
  raw=remap_pixels(raw[:0x18*32],lookup)+raw[0x18*32:0x20*32]+remap_pixels(raw[0x20*32:],lookup)
 fill(base,raw)
 if name=='Collapsing Floor':fill(base+4,raw)
fill(0x400,dec(R/'art/nemesis/S1/Enemy Bomb.nem'))
button = dec(R/'art/nemesis/S1/SBZ Button.nem')
assert len(button) == 8*32, 'Re-import the gray/blue-only button art first.'
fill(0x336,button)
for name,base in [('Enemy Caterkiller',0x2b0),('Enemy Ballhog (Horizontal)',0x620)]:fill(base,kosinski_plus_decode((R/f'art/moduled kosinski/{name}.kospm').read_bytes()[2:])[0])
sources={'Jun':'Rotating Junction','Disc':'Running Disc','Trap':'Trapdoor','Spin':'SBZ Spinning Platforms','Saw':'Saws and Pizza Cutters','Stomp':'SBZ Stomper and Door','VanP':'SBZ Vanishing Platforms','Flame':'Flamethrower','Elec':'Electrocuter','Gird':'Girder Block','Bomb':'Bomb Enemy','But':'Button'}
inputs={name:(frames(mapping((S/f'_maps/{sources[name]}.asm').read_text(),
                                    frame_count=2 if name == 'But' else None)),base) for name,base in [('Jun',0x4348),('Disc',0xc344),('Trap',0x4492),('Spin',0x302),('Saw',0x43b5),('Stomp',0x22c0),('VanP',0x4429),('Flame',0x83d9),('Elec',0x47e),('Gird',0x42f0),('Bomb',0x400),('But',0x336)]}
inputs['Stomp']=(inputs['Stomp'][0][:4]+[inputs['Stomp'][0][0]],0x22c0)
mb=frames(mapping((S/'_maps/Moving Blocks (MZ and SBZ).asm').read_text()));mb=[mb[2],mb[2],mb[2],mb[3],mb[2]];inputs['MBlock']=(mb,lambda i:0x4460 if i==3 else 0x22c0)
for name,label,base in [('Floor','Map_Obj1B',0x43f5),('Door','Map_obj30',0x42e8),('Cat','Map_Cat',0x22b0),('Hog','Map_BallHogH',0x2620)]:
 if label not in m.s:label=label.replace('Map_obj30','Map_Obj30')
 rs=frames(rom,m.s[label],m.s[label+'_frames'])
 if name=='Floor':rs=rs[:2]+rs[:2]
 inputs[name]=(rs,base)
inputs['Swing']=(frames(mapping((S/'_maps/Big Spiked Ball.asm').read_text())),lambda i:0x4391 if i==2 else 0x391)
def find_tiles(sequence, pattern):
    """Find an entire column-major sprite rectangle at a tile boundary."""
    return next((i for i in range(len(sequence)-len(pattern)+1)
                 if sequence[i:i+len(pattern)] == pattern), None)


def pack_rectangles(patterns):
    """Share complete rectangles and overlapping ends; never split a piece."""
    strings = []
    for pattern in sorted(set(patterns), key=lambda p: (-len(p), p)):
        if not any(find_tiles(s, pattern) is not None for s in strings):
            strings.append(pattern)
    while True:
        best = (0, 0, 0)
        for i, a in enumerate(strings):
            for j, b in enumerate(strings):
                if i == j:
                    continue
                for count in range(min(len(a), len(b)), 0, -1):
                    if a[-count:] == b[:count]:
                        if count > best[0]:
                            best = count, i, j
                        break
        count, i, j = best
        if not count:
            return tuple(tile for s in strings for tile in s)
        joined = strings[i] + strings[j][count:]
        strings = [s for k, s in enumerate(strings)
                   if k not in (i, j) and find_tiles(joined, s) is None]
        strings.append(joined)


def rectangle(tile, size, gfx):
    start = (tile+gfx) & 2047
    count = ((size >> 2)+1) * ((size & 3)+1)
    return tuple(bank[start+i] for i in range(count))


# Only the first two pieces of each rotating junction frame change their art.
# Their source tiles form five contiguous runs; flips reuse those runs across
# all sixteen angles. Keep the centre and outer ring in the shared static bank.
gap_first, gap_end = 0x22, 0x49
gap_art = b''.join(bank[0x348+t] for t in range(gap_first, gap_end))
gap_runs = []
for row in inputs['Jun'][0][:16]:
    ranges = [(tile & 2047, ((size >> 2)+1)*((size & 3)+1))
              for y, size, tile, x in row[:2]]
    first = min(tile for tile, count in ranges)
    last = max(tile+count for tile, count in ranges)
    assert gap_first <= first < last <= gap_end
    gap_runs.append((first-gap_first, last-first))

constants = (R/'s2.constants.asm').read_text()
def art_tile(name):
    return int(re.search(r'^'+name+r':\s+equ\s+\$([\dA-Fa-f]+)',
                         constants, re.M)[1], 16)

atlas_base = art_tile('ArtTile_SMZ_Atlas')
gap_base = art_tile('ArtTile_SMZ_Junction_Gap')
gap_offset = gap_base-atlas_base
capacity = gap_offset
assert max(count for first, count in gap_runs) <= m.s['ArtTile_SMZ_Smoke1']-gap_base
patterns = []
for name, (rs, base) in inputs.items():
    for i, row in enumerate(rs):
        gfx = base(i) if callable(base) else base
        patterns.extend(rectangle(tile, size, gfx)
                        for j, (y, size, tile, x) in enumerate(row)
                        if name != 'Jun' or i == 16 or j >= 2)
atlas_tiles = pack_rectangles(patterns)
packed_count = len(atlas_tiles)
# The universal water bank displaced one static SMZ terrain tile. Keep it
# in the atlas's final padding slot, which neither act animates/overwrites.
terrain = kosinski_plus_decode((R/'art/kosinski/level/SMZ Terrain Tile.kosp').read_bytes())[0]
assert len(terrain) == 32 and len(atlas_tiles) < capacity
assert m.s['ArtTile_SMZ_Terrain_Tile'] == atlas_base+capacity-1
atlas_tiles += (bytes(32),)*(capacity-1-len(atlas_tiles)) + (terrain,)
atlas = b''.join(atlas_tiles)
assert len(atlas_tiles) <= capacity, (len(atlas_tiles), capacity)
out = {}
for name, (rs, base) in inputs.items():
    data = bytearray(len(rs)*2)
    for i, row in enumerate(rs):
        gfx = base(i) if callable(base) else base
        pieces = []
        for j, (y, size, tile, x) in enumerate(row):
            if name == 'Jun' and i < 16 and j < 2:
                first, count = gap_runs[i]
                pos = gap_offset+(tile & 2047)-gap_first-first
            else:
                pos = find_tiles(atlas_tiles, rectangle(tile, size, gfx))
            assert pos is not None, (name, i, tile)
            pieces.append((y, size, ((tile+gfx) & 0xF800) | pos, x))
        struct.pack_into('>H', data, i*2, len(data))
        data += struct.pack('>H', len(pieces))
        data += b''.join(struct.pack('>bBHh', *piece) for piece in pieces)
    out[name] = data
# Independently compare visible indexed pixels, flags and positions in every frame.
def pixels(row,get,gfx):
 result={}
 for y,size,tile,x in row:
  total=(tile+gfx)&65535;t=total&2047;w,h=(size>>2)+1,(size&3)+1
  for px in range(w*8):
   for py in range(h*8):
    xx=w*8-1-px if total&0x800 else px;yy=h*8-1-py if total&0x1000 else py
    cell=get(t+(xx//8)*h+yy//8);b=cell[(yy&7)*4+(xx&7)//2];colour=b>>4 if xx%2==0 else b&15
    if colour:result[x+px,y+py]=(total&0xe000,colour)
 return result
for name,(rs,base) in inputs.items():
 packed=frames(out[name]);assert len(rs)==len(packed),(name,len(rs),len(packed))
 for i,(old,new) in enumerate(zip(rs,packed)):
  resident = dict(enumerate(atlas_tiles))
  if name == 'Jun' and i < 16:
   first, count = gap_runs[i]
   resident.update((gap_offset+t, gap_art[(first+t)*32:(first+t+1)*32])
                   for t in range(count))
  assert pixels(old,lambda t:bank[t],base(i) if callable(base) else base)==pixels(new,lambda t:resident[t],0),(name,i,'pixel mismatch')
  gfx = base(i) if callable(base) else base
  assert [(y,s,(t+gfx)&0xF800,x) for y,s,t,x in old] == [
      (y,s,t&0xF800,x) for y,s,t,x in new], (name,i,'piece layout changed')

# The common S3&K loader uses a word count followed by packed tile runs.
# Index zero is empty so a newly allocated object's zero cache forces upload.
dplc = ['; Generated by pack_scrap_sprites.py; one changing-edge run per angle.',
        '        dc.w .empty-DPLC_SMZ_Junction']
dplc += [f'        dc.w .gap{i:X}-DPLC_SMZ_Junction' for i in range(16)]
dplc += ['.empty: dc.w 0']
for i, (first, count) in enumerate(gap_runs):
    dplc.append(f'.gap{i:X}: dc.w 1,${((count-1)<<12)|first:04X}')

for name, data in out.items():
    (R/f'mappings/sprite/SMZ {name}.bin').write_bytes(data)
(R/'art/nemesis/SMZ Sprite Atlas.nem').write_bytes(nemesis_inline(atlas))
(R/'art/uncompressed/SMZ Sprite Atlas.unc').write_bytes(atlas)
(R/'art/uncompressed/SMZ Junction Gap.unc').write_bytes(gap_art)
(R/'mappings/spriteDPLC/SMZ Junction.asm').write_text('\n'.join(dplc)+'\n')
print('Atlas:', packed_count, 'used tiles; capacity:', capacity,
      '; original rectangles retained in all', sum(len(rs) for rs,_ in inputs.values()), 'frames')
print('Junction DPLC:', max(count for first,count in gap_runs),
      'resident tiles;', len(gap_art)//32, 'source tiles; terrain unchanged')
for name in ('Jun','Gird','Trap','Stomp','Swing'):
    print(name, 'pieces:', [len(row) for row in frames(out[name])])
