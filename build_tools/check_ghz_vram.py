#!/usr/bin/env python3
"""Check built GHZ art loads, cross-bank mappings and common sprite banks."""
import argparse
from pathlib import Path
import re
import struct

from check_sprite_assets import frames

ROOT = Path(__file__).resolve().parents[1]


def check_boss(rom, symbols, cues):
    boss = cues('PLC_GHZBoss')
    assert [source for source, _, _ in boss] == [symbols[name] for name in (
        'Nem_OldEggPod', 'Nem_Weapons', 'Nem_Exhaust', 'Nem_Prison', 'Nem_BossExplosion')]
    protected = [(symbols['ArtTile_Shield_2'] * 32, symbols['ArtTile_Shield_2_End'] * 32),
                 (symbols['vram_fg'], 0x10000)]
    for i, (_, low, high) in enumerate(boss):
        assert all(high <= a or low >= b for _, a, b in boss[:i]), (
            'GHZ boss/capsule overlap', hex(low), hex(high))
        assert all(high <= a or low >= b for a, b in protected), (
            'GHZ boss overwrote fixed bank', hex(low), hex(high))
    resident = [(a, b) for _, a, b in boss + cues('PLC_GHZ3_Main')]
    for mapping, base in (('Map_Eggman', 'ArtTile_Eggman'),
                          ('Map_BossItems', 'ArtTile_Eggman_Weapons'),
                          ('Map_GBall', 'ArtTile_GHZ_Giant_Ball'),
                          ('Map_BossExplosion', 'ArtTile_BossExplosion'),
                          ('Map_Pri', 'ArtTile_Prison_Capsule')):
        for row in frames(rom, symbols[mapping]):
            for _, size, tile, _ in row:
                low = ((symbols[base] + tile) & 0x7FF) * 32
                high = low + ((size >> 2) + 1) * ((size & 3) + 1) * 32
                assert any(a <= low < high <= b for a, b in resident), (
                    'unloaded GHZ boss art', mapping, hex(low), hex(high))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    parser.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    symbols = {name: int(value, 16) for name, value in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',
        args.listing.read_text())}

    def cues(label):
        start = symbols[label]
        count = struct.unpack_from('>h', rom, start)[0] + 1
        assert 0 <= count <= 16, (label, count)
        result = []
        for i in range(count):
            source, dest = struct.unpack_from('>IH', rom, start + 2 + i * 6)
            header = struct.unpack_from('>H', rom, source)[0]
            length = header if label.startswith('PLCKosM') else (header & 0x7FFF) * 32
            assert length and length % 32 == 0 and dest % 32 == 0, (label, hex(dest), length)
            result.append((source, dest, dest + length))
        return result

    check_boss(rom, symbols, cues)
    print('GHZ boss/capsule art, protected banks and mappings pass.', flush=True)

    common = sum((cues(label) for label in ('PLC_Main2', 'PLC_Explode',
                                          'PLC_GHZAnimals')), [])
    # GHZ's 32-tile Chopper occupies the diagonal-spring bank plus four tiles
    # before it. The shared spring banks themselves have no gaps.
    expected = {
        'ArtTile_Spring_Diagonal': 0x4DD,
        'ArtTile_Spring_Vertical': 0x4F9,
        'ArtTile_Spring_Horizontal': 0x509,
        'ArtTile_Spikes': 0x519,
        'ArtTile_Monitor': 0x529,
        'ArtTile_Lamppost': 0x565,
    }
    for name, tile in expected.items():
        assert symbols[name] == tile, (name, hex(symbols[name]))
    assert symbols['ArtTile_Chopper'] + 4 == symbols['ArtTile_Spring_Diagonal']
    for art, first, following in (
            ('Nem_DSpring', 'ArtTile_Spring_Diagonal', 'ArtTile_Spring_Vertical'),
            ('Nem_VSpring2', 'ArtTile_Spring_Vertical', 'ArtTile_Spring_Horizontal'),
            ('Nem_HSpring2', 'ArtTile_Spring_Horizontal', 'ArtTile_Spikes')):
        tiles = struct.unpack_from('>H', rom, symbols[art])[0] & 0x7FFF
        assert symbols[first] + tiles == symbols[following], (art, 'gap or overlap')
    newtron_tiles = struct.unpack_from('>H', rom, symbols['Kospm_Newtron'])[0] // 32
    assert newtron_tiles == 85
    assert symbols['ArtTile_Newtron'] + newtron_tiles == symbols['ArtTile_Chopper']
    assert 'Nem_NewtronTail' not in symbols and 'ArtTile_Newtron_Tail' not in symbols
    for row in frames(rom, symbols['Map_Newtron']):
        for _, size, tile, _ in row:
            assert (tile & 0x7FF) + ((size >> 2) + 1) * ((size & 3) + 1) <= newtron_tiles
    assert symbols['ArtTile_Points_2'] + 2 == symbols['ArtTile_GHZ_Edge_Wall']
    assert symbols['ArtTile_GHZ_Edge_Wall'] + 8 == symbols['vram_bg'] // 32 - 1

    assert struct.unpack_from('>H', rom, symbols['Nem_VSpikes'])[0] & 0x7FFF == 16
    spike_frames = frames(rom, symbols['Map_Obj36'])
    assert len(spike_frames) == 14
    for row in spike_frames:
        for _, size, tile, _ in row:
            assert (tile & 0x7FF) + ((size >> 2) + 1) * ((size & 3) + 1) <= 16
            assert tile & 0x6000 == 0  # player palette, including side pieces
    # New editor placements may mix the eight S3 arrangements with the six
    # imported S1 arrangements. Every subtype must name a resident frame.
    for act in range(1, 5):
        pos = symbols[f'ObjPos_GHZ{act}']
        while struct.unpack_from('>H', rom, pos)[0] != 0xFFFF:
            _, _, obj, eras, subtype = struct.unpack_from('>HHBBH', rom, pos)
            if obj == symbols['id_Obj36']:
                assert subtype >> 4 < len(spike_frames), ('GHZ spike arrangement', act, hex(subtype))
            pos += symbols['omSize']

    level_end = len((ROOT / 'art/kosinski/level/8x8 - GHZ.unc').read_bytes())
    assert level_end <= symbols['ArtTile_GHZ_Bridge'] * 32
    for act in range(1, 5):
        loaded = (common + cues(f'PLC_GHZ{act}_Main') + cues(f'PLC_GHZ{act}_Extra')
                  + cues(f'PLCKosM_THZ{act}'))
        for i, (source, low, high) in enumerate(loaded):
            # Dry GHZ acts intentionally lend the surface bank to the wall.
            # check_ghz_boss executes the real water initializer for all acts;
            # enabling water requires relocating this borrowed allocation.
            borrowed_surface = (source == symbols['Nem_GHZ_BWall'] and
                                symbols['ArtTile_Water_Surface'] * 32 <= low < high <=
                                (symbols['ArtTile_Water_Surface'] + 16) * 32)
            assert low >= level_end or borrowed_surface, ('GHZ terrain overwritten', act, hex(low))
            assert all(high <= a or low >= b for _, a, b in loaded[:i]), (
                'GHZ art overlap', act, hex(low), hex(high))
            assert high <= symbols['ArtTile_Shield_2'] * 32 or (
                symbols['ArtTile_Explosion'] * 32 <= low < high <= symbols['vram_fg']) or (
                low == symbols['ArtTile_GHZ_Edge_Wall'] * 32 and high == 0xDFE0), (
                    'fixed bank overwritten', act, hex(low), hex(high))
        # Check actual sprite tile references against resident banks, including
        # the complete Newtron and the wall cap borrowed from terrain.
        available = [(0, level_end)] + [(a, b) for _, a, b in loaded]
        mappings = [('Map_Obj36', 'ArtTile_Spikes')]
        if act < 4:
            mappings += [('Map_Newtron', 'ArtTile_Newtron'),
                         ('Map_obj44', 'ArtTile_GHZ_Edge_Wall')]
        else:
            assert not cues('PLCKosM_THZ4')
            assert [src for src, _, _ in cues('PLC_GHZ4_Main')] == [symbols['Nem_Swing'], symbols['Nem_GHZ_Ball']]
            assert [src for src, _, _ in cues('PLC_GHZ4_Extra')] == [symbols[n] for n in ('Nem_HSpring2','Nem_VSpring2','Nem_HangingSurface')]
            mappings += [('Map_PullChain','ArtTile_HangingSurface'),
                         ('Map_HangingSurface','ArtTile_HangingSurface')]
        for mapping, base in mappings:
            for row in frames(rom, symbols[mapping]):
                for _, size, tile, _ in row:
                    low = ((symbols[base] + tile) & 0x7FF) * 32
                    high = low + ((size >> 2) + 1) * ((size & 3) + 1) * 32
                    assert any(a <= low < high <= b for a, b in available), (
                        'unloaded mapping art', act, mapping, hex(low), hex(high))
        if act == 4:
            # The act's curated Debug entries must use art its own PLCs load.
            available += [(symbols['ArtTile_Ring']*32, symbols['ArtTile_HUD']*32)]
            assert struct.unpack_from('>h',rom,symbols['DebugList']+6)[0]+symbols['DebugList']==symbols['Debug_GHZ4']
            pos=symbols['Debug_GHZ4']
            count=struct.unpack_from('>H',rom,pos)[0]
            for i in range(count):
                obj,mapping,sub,frame,unused,gfx=struct.unpack_from('>IIHBBH',rom,pos+2+i*symbols['DebugEntry_size'])
                assert obj not in (symbols['Crabmeat'],symbols['Newtron'],symbols['MotoBug'],symbols['Obj22'],symbols['Obj2B'])
                offset=struct.unpack_from('>h',rom,mapping+frame*2)[0]
                pieces=struct.unpack_from('>H',rom,mapping+offset)[0]
                for j in range(pieces):
                    y,size,tile,x=struct.unpack_from('>bBHh',rom,mapping+offset+2+j*6)
                    low=((gfx+tile)&0x7FF)*32
                    high=low+((size>>2)+1)*((size&3)+1)*32
                    assert any(a<=low<high<=b for a,b in available),('GHZ4 Debug art',i,hex(low),hex(high))
    # General-object slots coexist with the other live zone loads too. Boss
    # and capsule lists are intentionally excluded: they reuse these slots.
    shared = cues('PLC_Main2')
    act_lists = [name for name in symbols if re.fullmatch(r'PLC_\w+_(Main|Extra)', name)]
    assert len(act_lists) == symbols['LevelActCount'] * 2
    assert len({symbols[name] for name in act_lists}) == len(act_lists), 'Acts share physical PLC lists'
    for label in act_lists:
        count = len(cues(label))
        reserved = symbols['ActPLC_Main_Reserve'] if label.endswith('_Main') else 0
        assert count + reserved <= 16, ('Act request queue overflow', label, count, reserved)
        index = symbols['plcid_' + label[4:]]
        assert 0 <= index <= 255, ('PLC ID exceeds header byte', label, index)
        ptr = symbols['ArtLoadCues'] + index * 2
        assert symbols['ArtLoadCues'] + struct.unpack_from('>h', rom, ptr)[0] == symbols[label], (
            'PLC ID resolves to another list', label, index)
    for label in act_lists + [f'PLCKosM_CVZ{act}' for act in range(1, 5)]:
        for source, low, high in cues(label):
            assert all(source == s or high <= a or low >= b for s, a, b in shared), (
                'common sprite bank overwritten', label, hex(low), hex(high))
    hpz = cues('PLC_HPZ1_Main') + cues('PLC_HPZ1_Extra') + cues('PLCKosM_CVZ1') + shared
    for i, (_, low, high) in enumerate(hpz):
        assert all(high <= a or low >= b for _, a, b in hpz[:i]), (
            'HPZ art overlap', hex(low), hex(high))
    # Retired LZ Ballhog fixtures do not reserve either of its art banks.
    assert not {src for src,_,_ in cues('PLCKosM_THZ1')}&{symbols['Kospm_BallhogV'],symbols['Kospm_BallhogH']}
    pos=symbols['ObjPos_GHZ1']
    while struct.unpack_from('>H',rom,pos)[0]!=0xFFFF:
        assert rom[pos+4]!=0x21,'temporary GHZ1 Ballhog placement'
        pos+=symbols['omSize']
    for act in range(1,5):
        assert not {src for src,_,_ in cues(f'PLCKosM_RRZ{act}')}&{symbols['Kospm_BallhogV'],symbols['Kospm_BallhogH']}
        pos=symbols[f'ObjPos_LZ{act}']
        while struct.unpack_from('>H',rom,pos)[0]!=0xFFFF:
            assert rom[pos+4]!=0x21,('temporary LZ Ballhog placement',act)
            pos+=symbols['omSize']
    print('Checked all four GHZ acts, cross-bank mappings, GHZ boss/capsule, HPZ art and common sprite banks across live zone PLCs.')


if __name__ == '__main__':
    main()
