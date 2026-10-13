#!/usr/bin/env python3
"""Check built GHZ art loads, cross-bank mappings and common sprite banks."""
from pathlib import Path
import re
import struct

from check_sprite_assets import frames

ROOT = Path(__file__).resolve().parents[1]


def main():
    rom = (ROOT / 's2built.bin').read_bytes()
    symbols = {name: int(value, 16) for name, value in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',
        (ROOT / 'main.lst').read_text())}

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

    common = sum((cues(label) for label in ('PLC_Main2', 'PLC_GHZ', 'PLC_GHZ2',
                                          'PLC_Explode', 'PLC_GHZAnimals')), [])
    # These banks are shared across stages. GHZ supplies its shorter spring
    # art and uses only otherwise empty space inside the reserved spring slots.
    expected = {
        'ArtTile_Spring_Diagonal': 0x4D5,
        'ArtTile_Spring_Vertical': 0x4F5,
        'ArtTile_Spring_Horizontal': 0x509,
        'ArtTile_Spikes': 0x517,
        'ArtTile_Monitor': 0x527,
        'ArtTile_Lamppost': 0x563,
    }
    for name, tile in expected.items():
        assert symbols[name] == tile, (name, hex(symbols[name]))
    assert symbols['ArtTile_Chopper'] == symbols['ArtTile_Spring_Diagonal']
    assert symbols['ArtTile_Newtron_Tail'] == symbols['ArtTile_Spring_Vertical'] + 16
    assert symbols['ArtTile_Points_2'] + 2 == symbols['ArtTile_GHZ_Edge_Wall']
    assert symbols['ArtTile_GHZ_Edge_Wall'] + 8 == symbols['vram_bg'] // 32 - 1

    tail = next(cue for cue in common if cue[0] == symbols['Nem_NewtronTail'])
    assert tail[1:] == (symbols['ArtTile_Newtron_Tail'] * 32,
                       (symbols['ArtTile_Newtron_Tail'] + 4) * 32)
    assert struct.unpack_from('>H', rom, symbols['Nem_VSpikes'])[0] & 0x7FFF == 16
    spike_frames = frames(rom, symbols['Map_Obj36'])
    assert len(spike_frames) == 8
    for row in spike_frames:
        for _, size, tile, _ in row:
            assert (tile & 0x7FF) + ((size >> 2) + 1) * ((size & 3) + 1) <= 16
            assert tile & 0x6000 == 0  # player palette, including side pieces

    level_end = len((ROOT / 'art/kosinski/level/8x8 - GHZ.unc').read_bytes())
    assert level_end == symbols['ArtTile_GHZ_Bridge'] * 32
    for act in range(1, 5):
        loaded = common + cues(f'PLCKosM_THZ{act}')
        for i, (_, low, high) in enumerate(loaded):
            assert low >= level_end, ('GHZ terrain overwritten', act, hex(low))
            assert all(high <= a or low >= b for _, a, b in loaded[:i]), (
                'GHZ art overlap', act, hex(low), hex(high))
            assert high <= symbols['ArtTile_Shield_2'] * 32 or (
                symbols['ArtTile_Explosion'] * 32 <= low < high <= symbols['vram_fg']) or (
                low == symbols['ArtTile_GHZ_Edge_Wall'] * 32 and high == 0xDFE0), (
                    'fixed bank overwritten', act, hex(low), hex(high))
        # Check actual sprite tile references against resident banks, including
        # Newtron's four shared tiles and the wall cap borrowed from terrain.
        available = [(0, level_end)] + [(a, b) for _, a, b in loaded]
        for mapping, base in (('Map_Newtron', 'ArtTile_Newtron'),
                              ('Map_obj44', 'ArtTile_GHZ_Edge_Wall'),
                              ('Map_Obj36', 'ArtTile_Spikes')):
            for row in frames(rom, symbols[mapping]):
                for _, size, tile, _ in row:
                    low = ((symbols[base] + tile) & 0x7FF) * 32
                    high = low + ((size >> 2) + 1) * ((size & 3) + 1) * 32
                    assert any(a <= low < high <= b for a, b in available), (
                        'unloaded mapping art', act, mapping, hex(low), hex(high))
    # General-object slots coexist with the other live zone loads too. Boss
    # and capsule lists are intentionally excluded: they reuse these slots.
    shared = cues('PLC_Main2')
    for label in ('PLC_LZ', 'PLC_LZ2', 'PLC_CPZ', 'PLC_CPZ2', 'PLC_EHZ', 'PLC_EHZ2',
                  'PLC_HPZ', 'PLC_HPZ2', 'PLC_HTZ', 'PLC_HTZ2',
                  'PLCKosM_CVZ1', 'PLCKosM_CVZ2', 'PLCKosM_CVZ3', 'PLCKosM_CVZ4'):
        for source, low, high in cues(label):
            assert all(source == s or high <= a or low >= b for s, a, b in shared), (
                'common sprite bank overwritten', label, hex(low), hex(high))
    hpz = cues('PLC_HPZ') + cues('PLC_HPZ2') + cues('PLCKosM_CVZ1') + shared
    for i, (_, low, high) in enumerate(hpz):
        assert all(high <= a or low >= b for _, a, b in hpz[:i]), (
            'HPZ art overlap', hex(low), hex(high))
    boss = cues('PLC_GHZBoss')
    assert [source for source, _, _ in boss] == [symbols[name] for name in (
        'Nem_OldEggPod', 'Nem_Weapons', 'Nem_Exhaust', 'Nem_Prison')]
    protected = [(symbols['ArtTile_Shield_2'] * 32, symbols['ArtTile_Shield_2_End'] * 32),
                 (symbols['vram_fg'], 0x10000)]
    for i, (_, low, high) in enumerate(boss):
        assert all(high <= a or low >= b for _, a, b in boss[:i]), (
            'GHZ boss/capsule overlap', hex(low), hex(high))
        assert all(high <= a or low >= b for a, b in protected), (
            'GHZ boss overwrote fixed bank', hex(low), hex(high))
    resident = [(a, b) for _, a, b in boss + cues('PLC_GHZ')]
    for mapping, base in (('Map_Eggman', 'ArtTile_Eggman'),
                          ('Map_BossItems', 'ArtTile_Eggman_Weapons'),
                          ('Map_GBall', 'ArtTile_GHZ_Giant_Ball'),
                          ('Map_Pri', 'ArtTile_Prison_Capsule')):
        for row in frames(rom, symbols[mapping]):
            for _, size, tile, _ in row:
                low = ((symbols[base] + tile) & 0x7FF) * 32
                high = low + ((size >> 2) + 1) * ((size & 3) + 1) * 32
                assert any(a <= low < high <= b for a, b in resident), (
                    'unloaded GHZ boss art', mapping, hex(low), hex(high))
    print('Checked all four GHZ acts, cross-bank mappings, GHZ boss/capsule, HPZ art and common sprite banks across live zone PLCs.')


if __name__ == '__main__':
    main()
