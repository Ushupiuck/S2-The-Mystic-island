#!/usr/bin/env python3
"""Compare GHZ's rendered blocks and both collision paths with a Git baseline.

Uses the actual old/new index, height and width files. No conversion recipe or
hand-maintained remap is needed. The optional core check exercises the live CD
bank selection and all four acts with both primary characters.
"""
from pathlib import Path
import argparse
import configparser
import json
import struct
import subprocess

import numpy as np
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]


def profile_mask(row):
    heights = np.frombuffer(row, dtype=np.int8).astype(np.int16)
    y = np.arange(16)[:, None]
    return np.where(heights >= 0, y >= 16-heights, y < -heights) & (heights != 0)


def orient(data, flags):
    if flags & 0x400:
        data = data[:, ::-1]
    if flags & 0x800:
        data = data[::-1]
    return data


def tile_words(blocks, chunk_word):
    words = list(struct.unpack_from('>4H', blocks, (chunk_word & 0x3FF)*8))
    if chunk_word & 0x400:
        words = [words[i] ^ 0x800 for i in (1, 0, 3, 2)]
    if chunk_word & 0x800:
        words = [words[i] ^ 0x1000 for i in (2, 3, 0, 1)]
    return words


def runtime(args):
    from genesis_test_core import Genesis
    from check_object_course import boot_level
    g = Genesis(args.core, args.rom, args.listing,
                args.output/'runtime', args.pal, system_directory=args.system_directory)
    report = []
    loop_bases = {}
    for act in range(4):
        for player in (0, 2):
            if report:
                g.write('v_gamemode', g.s['SegaScreen'], 2)
                g.run()
            boot_level(g, zone=0, act=act, player=player)
            cd = bool(g.s.get('MegaCDMode1'))
            if cd:
                prg = g.memory_domains['PRGRAM']
                for label, path in (('MCD_TerrainHeights_Sub', 'Collision array 1.bin'),
                                    ('MCD_TerrainWidths_Sub', 'Collision array 2.bin'),
                                    ('MCD_TerrainAngles_Sub', 'Curve and resistance mapping.bin')):
                    source = (ROOT/'collision'/path).read_bytes()
                    actual = bytes(prg[(g.s[label]+i)^1] for i in range(len(source)))
                    assert actual == source, (act, player, label, 'Wrong resident bank')
            assert g.read('v_colladdr1', 4) & 0xFFFFFF == g.s[f'Col_GHZ{act+1}']
            first = g.get('v_player', 'obX', 2)
            g.put('v_player', 'obStatusSecondary', 2)
            g.put('v_player', 'invtime', 6000, 2)
            if act == 0:
                loop_bases[player] = g.save()
            # Short, repeatable entrance route. Longer blind input reaches
            # ordinary pits in the original ROM as well.
            for frame in range(90):
                g.buttons = {7} | ({0} if frame % 100 < 15 else set())
                g.run()
                assert not g.read('v_errortype')
                if cd:
                    assert g.read('MCD_status') == 1
                assert g.get('v_player', 'obRoutine') < 6, (act, player, frame, 'Character died')
            assert g.get('v_player', 'obX', 2) > first + 16, (act, player, 'No movement')
            g.video.save(args.output/'runtime'/f'ghz-{act+1}-player-{player}.png')
            report.append(dict(act=act+1, player=player, frames=90))
    loops = []
    for player, base in loop_bases.items():
        g.restore(base)
        height = g.get('v_player', 'obHeight')
        for field, value, size in (('obX', 0x14A0, 2), ('obY', 0x2C0-height-1, 2),
                                    ('obVelX', 0xB00, 2), ('obVelY', 0, 2),
                                    ('obInertia', 0xB00, 2), ('obAngle', 0, 1),
                                    ('obStatus', 0, 1), ('obAnim', 0, 1),
                                    ('obRoutine', 2, 1), ('obControl', 0, 1)):
            g.put('v_player', field, value, size)
        g.write('Camera_X_pos', 0x14A0-160, 2)
        g.write('Camera_Y_pos', 0x2C0-112, 2)
        g.write('Screen_redraw_flag', 1)
        quadrants = set()
        for frame in range(100):
            g.buttons = {7}
            g.run()
            assert not g.read('v_errortype')
            assert g.get('v_player', 'obRoutine') < 6
            quadrants.add(g.get('v_player', 'obAngle') & 0xC0)
            if g.get('v_player', 'obAngle') & 0xC0 == 0x80:
                g.video.save(args.output/'runtime'/f'loop-ceiling-player-{player}.png')
        assert quadrants == {0, 0x40, 0x80, 0xC0}, (player, 'Incomplete loop', quadrants)
        assert g.get('v_player', 'obX', 2) > 0x1600
        assert not g.get('v_player', 'obStatus') & 2, (player, 'Loop did not return to ground')
        loops.append(dict(player=player, angle_quadrants=sorted(quadrants), grounded_exit=True))
    g.close()
    return dict(entrances=report, loops=loops)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference', required=True, help='Git revision before the GHZ remap')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--core', type=Path)
    p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT/('md-main.lst' if (ROOT/'md-main.asm').exists() else 'main.lst'))
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--pal', action='store_true')
    args = p.parse_args()
    def old(path):
        return subprocess.check_output(['git', 'show', args.reference+':'+path], cwd=ROOT)

    blocks = (ROOT/'mappings/16x16/GHZ.unc').read_bytes()
    prior_blocks = old('mappings/16x16/GHZ.unc')
    chunks = (ROOT/'mappings/128x128/GHZ.unc').read_bytes()
    prior_chunks = old('mappings/128x128/GHZ.unc')
    for size, raw in (('16x16', blocks), ('128x128', chunks)):
        assert kosinski_plus_decode((ROOT/f'mappings/{size}/GHZ.kosp').read_bytes())[0] == raw
    assert len(chunks) == len(prior_chunks) == 0x8000
    assert len(blocks) == len(prior_blocks)
    old_h = old('collision/S1/Collision Array (Normal).bin')
    old_w = old('collision/S1/Collision Array (Rotated).bin')
    new_h = (ROOT/'collision/Collision array 1.bin').read_bytes()
    new_w = (ROOT/'collision/Collision array 2.bin').read_bytes()
    old_bank = [old('collision/'+name) for name in ('Collision array 1.bin', 'Collision array 2.bin', 'Curve and resistance mapping.bin')]
    new_angles = (ROOT/'collision/Curve and resistance mapping.bin').read_bytes()
    changed = set()
    for i in range(256):
        if (old_bank[0][i*16:i*16+16], old_bank[1][i*16:i*16+16], old_bank[2][i]) != (new_h[i*16:i*16+16], new_w[i*16:i*16+16], new_angles[i]):
            assert not any(old_bank[0][i*16:i*16+16]+old_bank[1][i*16:i*16+16]), ('Replaced an existing S2 shape', i)
            changed.add(i)
    for path in (ROOT/'collision').glob('*/*.bin'):
        if path.parent.name == 'S1' or path.stem.startswith(('LZ', 'SMZ', 'GHZ')):
            continue
        assert path.read_bytes() == old(path.relative_to(ROOT).as_posix()), path
        assert not changed.intersection(path.read_bytes()), ('Occupied S2 index reused', path)

    comparisons = 0
    for path in sorted((ROOT/'collision').glob('*/GHZ*.bin')):
        current = path.read_bytes()
        prior = old(path.relative_to(ROOT).as_posix())
        assert len(current) == len(prior)
        # Check every editable definition, including ones not yet placed.
        for block in range(len(blocks)//8):
            for flags in (0, 0x400, 0x800, 0xC00):
                # Recover the new chunk orientation that preserves this art.
                candidates = [f for f in (0, 0x400, 0x800, 0xC00)
                              if tile_words(blocks, block | f) == tile_words(prior_blocks, block | flags)]
                assert candidates, ('Block art changed', path, block, flags)
                valid = False
                for f in candidates:
                    matches = []
                    for side in (0, 1):
                        index, new_index = prior[block*2+side], current[block*2+side]
                        for before, after in ((old_h, new_h), (old_w, new_w)):
                            a = profile_mask(before[index*16:index*16+16])
                            b = profile_mask(after[new_index*16:new_index*16+16])
                            if before is old_w:
                                a, b = a.T, b.T
                            matches.append(np.array_equal(orient(a, flags), orient(b, f)))
                    if all(matches):
                        valid = True
                        break
                assert valid, ('Collision silhouette changed', path, block, flags)
                comparisons += 2
    col = (ROOT/'collision/present/GHZ1.bin').read_bytes()
    prior_col = old('collision/present/GHZ1.bin')
    for position in range(0, len(chunks), 2):
        before = int.from_bytes(prior_chunks[position:position+2], 'big')
        after = int.from_bytes(chunks[position:position+2], 'big')
        assert before & 0xF3FF == after & 0xF3FF, ('Chunk ID/solidity changed', position)
        assert tile_words(prior_blocks, before) == tile_words(blocks, after), ('Chunk art changed', position)
        for side in (0, 1):
            i = prior_col[(before & 0x3FF)*2+side]
            j = col[(after & 0x3FF)*2+side]
            for src, dst in ((old_h, new_h), (old_w, new_w)):
                # Width masks transpose into the block's world axes.
                a = profile_mask(src[i*16:i*16+16]); b = profile_mask(dst[j*16:j*16+16])
                if src is old_w:
                    a, b = a.T, b.T
                assert np.array_equal(orient(a, before), orient(b, after)), ('Chunk collision changed', position, side)
    ini = configparser.ConfigParser(interpolation=None)
    ini.read_string('[DEFAULT]\n'+(ROOT/'SonLVL INI Files/SonLVL.ini').read_text())
    for act in range(1, 5):
        entry = ini[f'Twilight Hill Zone Act {act}']
        assert entry['colarr1'] == '../collision/Collision array 1.bin'
        assert entry['colarr2'] == '../collision/Collision array 2.bin'
        assert entry['angles'] == '../collision/Curve and resistance mapping.bin'
        assert entry['colind'] == f'../collision/present/GHZ{act}.bin'
    args.output.mkdir(parents=True, exist_ok=True)
    result = dict(reference=args.reference, paths_and_flips=comparisons, chunk_cells=len(chunks)//2,
                  formerly_empty_s2_rows=sorted(changed), geometry_and_rendering_preserved=True)
    if args.core:
        result['runtime'] = runtime(args)
    (args.output/'report.json').write_text(json.dumps(result, indent=2)+'\n')
    print(result, flush=True)


if __name__ == '__main__':
    main()
