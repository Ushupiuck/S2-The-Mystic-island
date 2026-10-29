#!/usr/bin/env python3
"""Audit per-act SMZ art against a Git baseline, independent of the splitter.

Compare every retained chunk cell and both collision paths at every layout
position in all eras. Numeric tile/block/chunk IDs may change; pixels, tile
attributes, chunk flags and collision profiles must not. No ROM is modified.
"""
from pathlib import Path
from functools import lru_cache
import argparse
import configparser
import json
import struct
import subprocess

from convert_s1_ss_background import kosinski_plus_decode
from level_layout import project_s2

ROOT = Path(__file__).resolve().parents[1]


def audit(reference):
    old_paths = set(subprocess.check_output(
        ['git', 'ls-tree', '-r', '--name-only', reference], cwd=ROOT).decode().splitlines())

    @lru_cache(None)
    def read(path, prior=False):
        return (subprocess.check_output(['git', 'show', reference+':'+path], cwd=ROOT)
                if prior else (ROOT/path).read_bytes())

    def raw(path, prior=False):
        source = path+'.unc'
        exists = source in old_paths if prior else (ROOT/source).exists()
        if exists:
            return read(source, prior)
        return kosinski_plus_decode(read(path+'.kosp', prior))[0]

    def bank(act, prior=False):
        split = 'mappings/16x16/SMZ1.unc' in old_paths if prior else True
        name = f'SMZ{act if act < 3 else 1}' if split else 'SMZ'
        return (raw('art/kosinski/level/8x8 - '+name, prior),
                raw('mappings/16x16/'+name, prior),
                raw('mappings/128x128/'+(name if act < 3 else 'SMZ Blank'), prior))

    # Collision profile bytes stay authoritative, including directional angles.
    profile_files = ('Collision array 1.bin', 'Collision array 2.bin', 'Curve and resistance mapping.bin')
    profiles = [tuple(read('collision/'+p, prior) for p in profile_files) for prior in (True,False)]
    assert profiles[0] == profiles[1], 'The split must not change the shared collision bank'
    ini = configparser.ConfigParser(interpolation=None)
    ini.read_string('[DEFAULT]\n'+read('SonLVL INI Files/SonLVL.ini').decode())
    report = []
    for act in range(1,5):
        before, after = bank(act, True), bank(act)
        art, blocks, chunks = after
        assert not any(art[:17*32]) and len(art) <= 0x2B9*32
        for path, data in zip(('art/kosinski/level/8x8 - ', 'mappings/16x16/', 'mappings/128x128/'), after):
            name = f'SMZ{act if act < 3 else 1}'
            if path.endswith('128x128/') and act >= 3:
                name = 'SMZ Blank'
            assert kosinski_plus_decode(read(path+name+'.kosp'))[0] == data
        entry = ini[f'Scrap Madness Zone Act {act}']
        name = f'SMZ{act if act < 3 else 1}'
        assert entry['tiles'] == f'../art/kosinski/level/8x8 - {name}.kosp'
        assert entry['blocks'] == f'../mappings/16x16/{name}.kosp'
        assert entry['chunks'] == f'../mappings/128x128/{name if act < 3 else "SMZ Blank"}.kosp'
        seen, blocks_seen = set(), set()
        checks = 0
        for layout_dir, collision_dir in (('', 'present'), ('past/', 'past'),
                                          ('good future/', 'good Future'), ('bad future/', 'bad future')):
            path = f'level/layout/{layout_dir}SMZ_{act}.kosp'
            layouts = [project_s2(kosinski_plus_decode(read(path, prior))[0]) for prior in (True,False)]
            assert len(layouts[0]) == len(layouts[1]) == 4096
            columns = [read(f'collision/{collision_dir}/SMZ{act}.bin', prior) for prior in (True,False)]
            assert len(columns[1]) == len(blocks)//4
            for old, new in set(zip(*layouts)):
                seen.add(new)
                for cell in range(64):
                    words = [struct.unpack_from('>H', b[2], chunk*128+cell*2)[0]
                             for b, chunk in zip((before,after),(old,new))]
                    assert words[0] & 0xFC00 == words[1] & 0xFC00, ('Chunk flags', act, old, new, cell)
                    ids = [w & 0x3FF for w in words]
                    blocks_seen.add(ids[1])
                    for index in range(4):
                        tiles = [struct.unpack_from('>H', b[1], block*8+index*2)[0]
                                 for b, block in zip((before,after),ids)]
                        assert tiles[0] & 0xF800 == tiles[1] & 0xF800, ('Tile attributes',act,ids,index)
                        tile_ids = [t & 0x7FF for t in tiles]
                        pixels = [b[0][t*32:(t+1)*32] for b,t in zip((before,after),tile_ids)]
                        assert pixels[0] == pixels[1], ('Tile pixels',act,ids,tile_ids)
                        if not pixels[0]:
                            assert tile_ids[0] == tile_ids[1], 'External animation bank moved'
                    for path_index in (0,1):
                        assert columns[0][ids[0]*2+path_index] == columns[1][ids[1]*2+path_index], ('Collision index',act,ids,path_index)
                    checks += 1
        assert seen == set(range(len(chunks)//128)), ('Unreferenced chunk in act bank',act)
        # Reserved blocks 0..5 also support the starter and floor editor tools.
        if act < 3:
            assert blocks_seen | set(range(6)) == set(range(len(blocks)//8))
        report.append(dict(act=act, tiles=len(art)//32, blocks=len(blocks)//8,
                           chunks=len(chunks)//128, era_chunk_cells=checks,
                           pixels_attributes_and_both_paths_preserved=True))
    return report


def headers(rom, listing):
    from native_test_core import Native, UC_M68K_REG_A2
    m = Native(rom, listing)
    data = rom.read_bytes()
    for era in range(4):
        for act in range(4):
            m.write('Current_ZoneAndAct', 0x800+act, 2)
            m.write('Current_Timezone', era)
            m.act('GetLevelArtHeader')
            address = m.cpu.reg_read(UC_M68K_REG_A2)
            bank = act+1 if act < 2 else 1
            pointers = struct.unpack_from('>3I', data, address)
            for pointer,label in zip(pointers,(f'Kosp_SMZ{bank}',f'Map16_SMZ{bank}',
                                               f'Map128_SMZ{bank}' if act<2 else 'Map128_SMZBlank')):
                assert pointer & 0xFFFFFF == m.s[label], (era,act,label)
                assert pointer & 1 == 0, ('Odd ROM include address',label)
    return 16


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference', required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--rom', type=Path)
    p.add_argument('--listing', type=Path)
    args = p.parse_args()
    result = dict(acts=audit(args.reference))
    if args.rom:
        result['runtime_header_selections'] = headers(args.rom,args.listing)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__ == '__main__':
    main()
