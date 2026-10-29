#!/usr/bin/env python3
"""Compare editable terrain art and both collision paths with a Git baseline.

Uses actual old/new indices, height/width maps and angles, independently of the
conversion recipe. The optional core check visits every terrain set with both
characters and exercises GHZ's loop. Reports belong in an ignored output folder.
"""
from pathlib import Path
import argparse
import configparser
from collections import Counter
from functools import lru_cache
import json
import struct
import subprocess

import numpy as np
from level_layout import project_s2
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]
ZONE_IDS = dict(GHZ=0, LZ=1, CPZ=2, EHZ=3, HPZ=4, HTZ=5, MTZ=6, SMZ=8)
ZONES = tuple(ZONE_IDS)
BANK_FILES = ('Collision array 1.bin', 'Collision array 2.bin', 'Curve and resistance mapping.bin')
S1_FILES = ('S1/Collision Array (Normal).bin', 'S1/Collision Array (Rotated).bin', 'S1/Angle Map.bin')


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


def geometry_source(zone, size, old=None, old_paths=None):
    path = f'mappings/{size}/{zone}.unc'
    if old is not None:
        return (old(path) if path in old_paths else
                kosinski_plus_decode(old(path[:-4]+'.kosp'))[0])
    source = ROOT/path
    return (source.read_bytes() if source.exists() else
            kosinski_plus_decode(source.with_suffix('.kosp').read_bytes())[0])


def runtime(args):
    from genesis_test_core import Genesis
    from check_object_course import boot_level
    g = Genesis(args.core, args.rom, args.listing,
                args.output/'runtime', args.pal, system_directory=args.system_directory)
    report = []
    loop_bases = {}
    levels = ([(0, act) for act in range(4)] +
              [(zone, 0) for zone in range(1, 7)] + [(8, 0), (8, 1)])
    names = {value: key for key, value in ZONE_IDS.items()}
    for zone, act in levels:
        for player in (0, 2):
            if report:
                g.write('v_gamemode', g.s['SegaScreen'], 2)
                g.run()
            boot_level(g, zone=zone, act=act, player=player)
            cd = bool(g.s.get('MegaCDMode1'))
            if cd:
                prg = g.memory_domains['PRGRAM']
                files = BANK_FILES
                for label, path in zip(('MCD_TerrainHeights_Sub', 'MCD_TerrainWidths_Sub',
                                         'MCD_TerrainAngles_Sub'), files):
                    source = (ROOT/'collision'/path).read_bytes()
                    actual = bytes(prg[(g.s[label]+i)^1] for i in range(len(source)))
                    assert actual == source, (act, player, label, 'Wrong resident bank')
            assert g.read('v_colladdr1', 4) & 0xFFFFFF == g.s[f'Col_{names[zone]}{act+1}']
            first = g.get('v_player', 'obX', 2)
            g.put('v_player', 'obStatusSecondary', 2)
            g.put('v_player', 'invtime', 6000, 2)
            if zone == 0 and act == 0:
                loop_bases[player] = g.save()
            # Short, repeatable entrance route. Longer blind input reaches
            # ordinary pits in the original ROM as well.
            frames = 90 if zone == 0 else 60
            for frame in range(frames):
                g.buttons = {7} | ({0} if frame % 100 < 15 else set())
                g.run()
                assert not g.read('v_errortype')
                if cd:
                    assert g.read('MCD_status') == 1
                assert g.get('v_player', 'obRoutine') < 6, (act, player, frame, 'Character died')
            assert g.get('v_player', 'obX', 2) > first + 16, (act, player, 'No movement')
            g.video.save(args.output/'runtime'/f'{names[zone].lower()}-{act+1}-player-{player}.png')
            report.append(dict(zone=names[zone], act=act+1, player=player, frames=frames))
    loops = []
    for player, base in loop_bases.items():
        g.restore(base)
        height = g.get('v_player', 'obHeight')
        for field, value, size in (('obX', 0x14A0, 2), ('obY', 0x4C0-height-1, 2),
                                    ('obVelX', 0xB00, 2), ('obVelY', 0, 2),
                                    ('obInertia', 0xB00, 2), ('obAngle', 0, 1),
                                    ('obStatus', 0, 1), ('obAnim', 0, 1),
                                    ('obRoutine', 2, 1), ('obControl', 0, 1)):
            g.put('v_player', field, value, size)
        g.write('Camera_X_pos', 0x14A0-160, 2)
        g.write('Camera_Y_pos', 0x4C0-112, 2)
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


def native_probes(args, old, old_paths):
    """Compare real floor/wall executors at distinct affected placed orientations."""
    from native_test_core import (Native, UC_M68K_REG_D1, UC_M68K_REG_D2,
                                  UC_M68K_REG_D3, UC_M68K_REG_D5,
                                  UC_M68K_REG_D6, UC_M68K_REG_A3,
                                  UC_M68K_REG_A4)
    machines = (Native(args.previous_rom, args.previous_listing), Native(args.rom, args.listing))
    for m in machines:
        m.start()
    report = {}
    for zone, act in ((zone, act) for zone in args.zones
                      for act in ((1, 2) if zone == 'SMZ' else (1,))):
        if zone == 'SMZ':
            # Pair the actual layout cells before probing: independent banks
            # need not retain either chunk IDs or block IDs from the baseline.
            prior_name = f'SMZ{act}' if f'mappings/128x128/SMZ{act}.unc' in old_paths else 'SMZ'
            source = (geometry_source(prior_name, '128x128', old, old_paths),
                      geometry_source(f'SMZ{act}', '128x128'))
            path = f'level/layout/SMZ_{act}.kosp'
            layouts = (project_s2(kosinski_plus_decode(old(path))[0]),
                       project_s2(kosinski_plus_decode((ROOT/path).read_bytes())[0]))
            pairs = sorted(set(zip(*layouts)))
            chunks = tuple(b''.join(raw[pair[n]*128:(pair[n]+1)*128] for pair in pairs)
                           for n, raw in enumerate(source))
        else:
            chunks = (geometry_source(zone, '128x128', old, old_paths),
                      geometry_source(zone, '128x128'))
        columns = (old(f'collision/present/{zone}{act}.bin'),
                   (ROOT/f'collision/present/{zone}{act}.bin').read_bytes())
        for revision, m in enumerate(machines):
            m.write('Current_Zone', ZONE_IDS[zone])
            m.write('Current_Act', act-1)
            m.cpu.mem_write(m.s['Chunk_Table'] & 0xFFFFFF, chunks[revision])
            ptr = m.s[f'Col_{zone}{act}']
            m.write('v_colladdr1', ptr, 4)
            m.write('v_colladdr2', ptr+1, 4)
        cases = 0
        differences = Counter()
        seen = set()
        for position in range(0, len(chunks[0]), 2):
            words = [int.from_bytes(c[position:position+2], 'big') for c in chunks]
            indices = [c[(w & 0x3FF)*2:(w & 0x3FF)*2+2] for c, w in zip(columns, words)]
            changed_bank = zone in ('LZ', 'SMZ') and 'collision/'+S1_FILES[0] in old_paths
            if not changed_bank and words[0] == words[1] and indices[0] == indices[1]:
                continue
            # Repeat one real placed example per old/new block orientation.
            # The exhaustive static check covers every neighbouring cell.
            key = tuple(words), tuple(indices)
            if key in seen:
                continue
            seen.add(key)
            chunk, cell = divmod(position//2, 64)
            for m in machines:
                m.cpu.mem_write(m.s['v_lvllayout'] & 0xFFFFFF, bytes((chunk,))*0x1000)
            x0, y0 = 256+(cell % 8)*16, 256+(cell//8)*16
            for routine, flip in (('FindFloor', 0x800), ('FindWall', 0x400)):
                for path, solidity in ((0, 12), (0, 13), (1, 14), (1, 15)):
                    for direction in (1, -1):
                        for x in (0, 7, 8, 15):
                            for y in (-1, 0, 7, 15, 16):
                                results = []
                                for m in machines:
                                    m.write('Collision_addr', m.read('v_colladdr'+str(path+1), 4), 4)
                                    m.write('Primary_Angle', 3)
                                    m.act(routine, 'v_player', {
                                        UC_M68K_REG_D2: y0+y, UC_M68K_REG_D3: x0+x,
                                        UC_M68K_REG_D5: solidity,
                                        UC_M68K_REG_D6: flip if direction < 0 else 0,
                                        UC_M68K_REG_A3: (direction*16) & 0xFFFFFFFF,
                                        UC_M68K_REG_A4: m.s['Primary_Angle'] & 0xFFFFFF,
                                    })
                                    results.append((m.cpu.reg_read(UC_M68K_REG_D1) & 65535,
                                                    m.read('Primary_Angle')))
                                (a, aa), (b, ba) = results
                                assert a == b, ('Native distance changed', zone, position, routine, path, direction, x, y, results)
                                assert (aa & 1) == (ba & 1), ('Native angle marker changed', results)
                                delta = 0 if aa & 1 else abs((aa-ba+128)%256-128)
                                assert delta <= args.max_angle_change, ('Native angle changed', results)
                                differences[delta] += 1
                                cases += 1
        name = zone+str(act) if zone == 'SMZ' else zone
        report[name] = dict(probes=cases, angle_differences=dict(sorted(differences.items())))
        print(name, report[name], flush=True)
    return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference', required=True, help='Git revision before the terrain edit')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--zones', nargs='+', choices=ZONES, default=ZONES)
    p.add_argument('--reference-ghz-bank', choices=('S1', 'S2'), default='S2')
    p.add_argument('--max-angle-change', type=int, default=0,
                   help='Maximum permitted even-angle difference, in 1/256 turns')
    p.add_argument('--core', type=Path)
    p.add_argument('--previous-rom', type=Path)
    p.add_argument('--previous-listing', type=Path)
    p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT/('md-main.lst' if (ROOT/'md-main.asm').exists() else 'main.lst'))
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--pal', action='store_true')
    args = p.parse_args()
    if bool(args.previous_rom) != bool(args.previous_listing):
        p.error('--previous-rom and --previous-listing must be supplied together')
    def old(path):
        return subprocess.check_output(['git', 'show', args.reference+':'+path], cwd=ROOT)

    old_paths = set(subprocess.check_output(
        ['git', 'ls-tree', '-r', '--name-only', args.reference], cwd=ROOT).decode().splitlines())
    banks = {('S2', 'old'): tuple(old('collision/'+f) for f in BANK_FILES),
             ('shared', 'new'): tuple((ROOT/'collision'/f).read_bytes() for f in BANK_FILES)}
    legacy = 'collision/'+S1_FILES[0] in old_paths
    if legacy:
        banks['S1', 'old'] = tuple(old('collision/'+f) for f in S1_FILES)
    before, after = banks['S2', 'old'], banks['shared', 'new']
    for i in (0, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF):
        for n in (0, 1):
            assert before[n][i*16:i*16+16] == after[n][i*16:i*16+16], ('Protected solid changed', i)
        assert before[2][i] == after[2][i], ('Protected angle changed', i)
    empty = {i for i in range(1, 256)
             if not any(after[0][i*16:i*16+16]+after[1][i*16:i*16+16])}
    assert not list((ROOT/'collision/S1').glob('*.bin')), 'Obsolete runtime S1 bank remains'
    for path in (ROOT/'collision').glob('*/*.bin'):
        assert not empty.intersection(path.read_bytes()), ('Empty solid referenced', path)

    @lru_cache(None)
    def surface(bank, revision, index, flags):
        h, w, angles = banks[bank, revision]
        masks = (profile_mask(h[index*16:index*16+16]),
                 profile_mask(w[index*16:index*16+16]).T)
        geometry = tuple(orient(m, flags).tobytes() for m in masks)
        angle = angles[index]
        if not index:
            return geometry, None
        if flags & 0x400:
            angle = -angle & 255
        if flags & 0x800:
            angle = 128-angle & 255
        return geometry, None if angle & 1 else angle

    def compare(bank, i, j, old_flags, new_flags):
        a, aa = surface(bank, 'old', i, old_flags)
        b, ba = surface('shared', 'new', j, new_flags)
        if a != b or (aa is None) != (ba is None):
            return None
        return 0 if aa is None else abs((aa-ba+128)%256-128)

    results = {}
    for zone in args.zones:
        if zone == 'SMZ':
            from check_smz_art import audit
            results[zone] = dict(independent_acts=audit(args.reference))
            continue
        bank = 'S1' if legacy and zone in ('LZ', 'SMZ') else 'S2'
        if zone == 'GHZ' and args.reference_ghz_bank == 'S1':
            bank = 'S1'
        blocks = geometry_source(zone, '16x16')
        prior_blocks = geometry_source(zone, '16x16', old, old_paths)
        chunks = geometry_source(zone, '128x128')
        prior_chunks = geometry_source(zone, '128x128', old, old_paths)
        starter = dict(GHZ='Blank', MTZ='MTZ Blank', SMZ='SMZ Blank').get(zone)
        if starter:
            chunks += geometry_source(starter, '128x128')
            prior_chunks += geometry_source(starter, '128x128', old, old_paths)
        assert len(blocks) == len(prior_blocks)
        assert len(chunks) == len(prior_chunks)
        for size, raw in (('16x16', blocks), ('128x128', geometry_source(zone, '128x128'))):
            assert kosinski_plus_decode((ROOT/f'mappings/{size}/{zone}.kosp').read_bytes())[0] == raw
        indices = [(p.read_bytes(), old(p.relative_to(ROOT).as_posix()))
                   for p in sorted((ROOT/'collision').glob('*/'+zone+'*.bin'))]
        assert len(indices) == 16, (zone, 'Missing act/timezone index')
        errors = Counter()
        # One block orientation must work for both paths in every act/timezone.
        for block in range(len(blocks)//8):
            candidates = [f for f in (0, 0x400, 0x800, 0xC00)
                          if tile_words(blocks, block | f) == tile_words(prior_blocks, block)]
            valid = []
            for f in candidates:
                ds = [compare(bank, prior[block*2+side], current[block*2+side], flags, flags ^ f)
                      for current, prior in indices for side in (0, 1)
                      for flags in (0, 0x400, 0x800, 0xC00)]
                if all(d is not None and d <= args.max_angle_change for d in ds):
                    valid.append(ds)
            assert valid, ('Block art, geometry or angle changed', zone, block)
            errors.update(min(valid, key=sum))
        chunk_errors = Counter()
        opaque_cells = 0
        # Verify actual placed orientations, independently of the block check.
        for position in range(0, len(chunks), 2):
            a = int.from_bytes(prior_chunks[position:position+2], 'big')
            b = int.from_bytes(chunks[position:position+2], 'big')
            assert a & 0xF3FF == b & 0xF3FF, ('Chunk ID/solidity changed', zone, position)
            if (a & 0x3FF)*8 >= len(prior_blocks):
                # Some old chunk sets contain unplaced definitions beyond the
                # editable block sheet. Preserve those opaque cells verbatim.
                assert a == b, ('Out-of-sheet chunk cell changed', zone, position)
                for current, prior in indices:
                    start = (a & 0x3FF)*2
                    assert current[start:start+2] == prior[start:start+2]
                opaque_cells += 1
                continue
            assert tile_words(prior_blocks, a) == tile_words(blocks, b), ('Chunk art changed', zone, position)
            for current, prior in indices:
                for side in (0, 1):
                    i = prior[(a & 0x3FF)*2+side]
                    j = current[(b & 0x3FF)*2+side]
                    d = compare(bank, i, j, a & 0xC00, b & 0xC00)
                    assert d is not None and d <= args.max_angle_change, ('Chunk collision changed', zone, position, side, d)
                    chunk_errors[d] += 1
        results[zone] = dict(editable_blocks=len(blocks)//8, path_flip_checks=sum(errors.values()),
                             chunk_cells=len(chunks)//2, unchanged_opaque_cells=opaque_cells,
                             angle_differences=dict(sorted(errors.items())),
                             placed_angle_differences=dict(sorted(chunk_errors.items())))
    ini = configparser.ConfigParser(interpolation=None)
    ini.read_string('[DEFAULT]\n'+(ROOT/'SonLVL INI Files/SonLVL.ini').read_text())
    for prefix, zone in (('Twilight Hill', 'GHZ'), ('Rustic Ruins', 'LZ'), ('Scrap Madness', 'SMZ')):
        for act in range(1, 5):
            entry = ini[f'{prefix} Zone Act {act}']
            assert entry['colarr1'] == '../collision/Collision array 1.bin'
            assert entry['colarr2'] == '../collision/Collision array 2.bin'
            assert entry['angles'] == '../collision/Curve and resistance mapping.bin'
            assert entry['colind'] == f'../collision/present/{zone}{act}.bin'
    args.output.mkdir(parents=True, exist_ok=True)
    result = dict(reference=args.reference, zones=results, empty_shared_slots=sorted(empty),
                  protected_solids_preserved=True, geometry_and_rendering_preserved=True)
    if args.previous_rom:
        result['native_probes'] = native_probes(args, old, old_paths)
    if args.core:
        result['runtime'] = runtime(args)
    (args.output/'report.json').write_text(json.dumps(result, indent=2)+'\n')
    print(result, flush=True)


if __name__ == '__main__':
    main()
