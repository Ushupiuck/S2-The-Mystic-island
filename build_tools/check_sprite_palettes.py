#!/usr/bin/env python3
"""Validate shared slots, spring pieces, private results and terrain colors.

--reference compares decoded terrain RGB against a pre-migration Git commit.
It checks both planes, except EHZ2's deliberately readapted PP background;
all EHZ2 foreground blocks still require exact RGB equality. No ROM is edited.
"""
from pathlib import Path
from functools import lru_cache
import argparse
import json
import struct
import subprocess
from check_sprite_assets import frames
from convert_s1_ss_background import kosinski_plus_decode
from import_ehz2_pp_background import nemesis
from level_layout import decode

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference')
    p.add_argument('--output', type=Path)
    args = p.parse_args()
    player = (ROOT/'palette/SonicAndTails.bin').read_bytes()
    assert player == (ROOT/'palette/Sonic and Tails.bin').read_bytes()
    assert struct.unpack('>16H', player) == (
        0,0x222,0x06C,0x08E,0x0AE,0x8CE,0xEEE,0xECC,
        0xCAA,0x866,0xE66,0xC42,0x822,0x00E,0x008,0x004)
    names = ('GHZ','LZ','CPZ','EHZ','EHZ2 PP','HPZ','HTZ','MTZ','LZ4','SMZ1','SMZ2')
    for name in names:
        row = struct.unpack('>48H', (ROOT/f'palette/{name}.bin').read_bytes())[:16]
        assert row[6:10] == (0xEEE,0xECC,0xCAA,0x866), (name,'gray slots')
        assert row[13:16] == (0x0EE,0x088,0x044), (name,'yellow slots')
    from build_underwater_palettes import outputs
    for path, data in outputs():
        assert path.read_bytes() == data, path
    springs = [frames((ROOT/f'mappings/sprite/{name}').read_bytes())
               for name in ('Spring.bin','Spring (Yellow).bin')]
    for fi, (red,yellow) in enumerate(zip(*springs)):
        assert len(red) == len(yellow)
        for pi, (r,y) in enumerate(zip(red,yellow)):
            cap = pi == 0 if fi < 7 else pi < 3
            assert r[:2]+r[3:] == y[:2]+y[3:]
            assert y[2] == r[2] | (0x2000 if cap else 0), (fi,pi)
            count = 12 if fi < 7 else 18
            assert (r[2]&2047)+((r[1]>>2)+1)*((r[1]&3)+1) <= count
    for name, count in (('Vertical',12),('Horizontal',12),('Diagonal',18)):
        raw = (ROOT/f'art/uncompressed/{name} spring S3.unc').read_bytes()
        assert len(raw) == count*32
        assert nemesis((ROOT/f'art/nemesis/{name} spring.nem').read_bytes()) == raw
    results = struct.unpack('>64H',(ROOT/'palette/Special Stage Results.bin').read_bytes())
    assert results[1:16] == struct.unpack('>16H',player)[1:]
    assert results[29:32] == (0x0EE,0x088,0x044)
    gems = frames((ROOT/'mappings/sprite/SSR Emeralds.bin').read_bytes())
    assert len(gems) == 7 and not gems[6]
    assert {row[0][2]&2047 for row in gems[:6]} == set(range(0,24,4))
    assert [row[0][2]>>13&3 for row in gems[:6]] == [2,2,2,3,3,3]
    assert len(nemesis((ROOT/'art/nemesis/Results emeralds.nem').read_bytes())) == 24*32
    checks = dict(shared_level_rows=len(names),spring_frames=len(springs[0]),
                  spring_tiles=42,results_emeralds=6)
    if args.reference:
        @lru_cache(None)
        def read(path, prior=False):
            if prior:
                return subprocess.check_output(['git','show',args.reference+':'+path],cwd=ROOT)
            return (ROOT/path).read_bytes()
        def raw(path, prior=False):
            return kosinski_plus_decode(read(path,prior))[0]
        samples = []
        for name in ('GHZ','LZ','CPZ','EHZ','EHZ2','HPZ','HTZ','MTZ','SMZ1','SMZ2'):
            ap, bp = f'art/kosinski/level/8x8 - {name}.kosp', f'mappings/16x16/{name}.kosp'
            palname = 'EHZ2 PP' if name == 'EHZ2' else name
            art = [raw(ap,old) for old in (True,False)]
            blocks = [raw(bp,old) for old in (True,False)]
            palettes = [struct.unpack('>64H',read('palette/SonicAndTails.bin',old)+
                                     read('palette/'+palname+'.bin',old)) for old in (True,False)]
            if name == 'CPZ':
                # The old enemy row colored original red/brown loop pixels blue.
                # Compare against the intentional correction, retaining this
                # project's gray ramp and synchronized yellow slots.
                restored = list(palettes[0])
                for slot, color in {2:0x008,3:0x02C,4:0x06E,5:0x044,
                                    10:0x666,11:0x000,14:0xEA8,15:0x222}.items():
                    restored[16+slot] = color
                palettes[0] = tuple(restored)
            count = min(len(b) for b in blocks)//8
            bids = set(range(count))
            if name == 'EHZ2':
                chunks = raw('mappings/128x128/EHZ2.kosp',True)
                cids = set()
                for era in ('','past/','good future/','bad future/'):
                    fg,_ = decode(raw('level/layout/'+era+'EHZ_2.kosp',True))
                    cids |= {v for row in fg for v in row}
                bids = set(range(6)) | {struct.unpack_from('>H',chunks,c*128+j*2)[0]&1023
                                       for c in cids for j in range(64)}
            compared = 0
            for bid in sorted(bids):
                for piece in range(4):
                    ws = [struct.unpack_from('>H',b,bid*8+piece*2)[0] for b in blocks]
                    assert ws[0]&0xF800 == ws[1]&0xF800, (name,bid,piece,'attributes')
                    tiles = [a[(w&2047)*32:((w&2047)+1)*32] for a,w in zip(art,ws)]
                    if any(len(tile)!=32 for tile in tiles):
                        continue  # External resident/animated banks have separate checks.
                    def colors(tile, palette, word):
                        return [palette[(word>>13&3)*16+c] if c else None
                                for byte in tile for c in (byte>>4,byte&15)]
                    assert colors(tiles[0],palettes[0],ws[0]) == colors(tiles[1],palettes[1],ws[1]), (
                        name,bid,piece,hex(ws[0]),hex(ws[1]),'terrain RGB changed')
                    compared += 64
            samples.append(dict(bank=name,blocks=len(bids),pixels=compared))
        # The stage keeps original banks even where they used to be shared.
        for current, original in (
                ('Special stage bumper.nem','Bumper.nem'),
                ('Special stage sparkles.nem','Ring Sparkles.nem'),
                ('Special stage rings.nem','Ring.nem')):
            assert read('art/nemesis/'+current) == read('art/nemesis/'+original,True)
        original_palette = bytearray(read('palette/Special Stage.bin',True))
        for slot,color in ((10,0x8CE),(11,0x26C),(15,0x0AE)):
            struct.pack_into('>H',original_palette,slot*2,color)
        assert read('palette/Special Stage.bin') == original_palette
        from sprite_palette import PLAYER_TO_S1_STAGE_TAILS
        fur = [PLAYER_TO_S1_STAGE_TAILS[i] for i in (2,3,4)]
        assert len(set(fur)) == 3, 'Stage fur shades collapsed'
        assert len({struct.unpack_from('>H',original_palette,i*2)[0] for i in fur}) == 3
        old_source = read("art/uncompressed/Sonic's art.unc",True)
        cues = read('mappings/spriteDPLC/Sonic DPLCs.bin',True)
        stage = read('art/uncompressed/Special stage Sonic.unc')
        stage_cues = read('mappings/spriteDPLC/Special stage Sonic.bin')
        for frame in range(0x3D,0x42):
            def payload(art,cues):
                start = struct.unpack_from('>h',cues,frame*2)[0]
                n = struct.unpack_from('>H',cues,start)[0]
                words = struct.unpack_from('>'+str(n)+'H',cues,start+2)
                return b''.join(art[(w&4095)*32:((w&4095)+(w>>12)+1)*32] for w in words)
            assert payload(old_source,cues) == payload(stage,stage_cues), frame
        checks.update(terrain=samples,rotating_stage_shared_pixels_unchanged=True,rotating_stage_warm_slots=[10,11,15])
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(checks,indent=2)+'\n')
    print(json.dumps(checks,indent=2))


if __name__ == '__main__':
    main()
