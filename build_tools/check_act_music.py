#!/usr/bin/env python3
"""Verify per-act lookup, both callers, music priorities and live playback.

A disposable ROM assigns distinct IDs across acts; the source ROM is unchanged.
Native calls execute actual 68000 code and stop before the audio dispatch.
"""
from pathlib import Path
import argparse
import ctypes as C
import json

from genesis_test_core import Genesis
from check_object_course import boot_level
from check_caterkiller import CpuPrefix

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--core', type=Path, required=True)
    p.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT / 'main.lst')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--system-directory', type=Path)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    # Read symbols without creating another emulator instance.
    import re
    symbols = {name: int(value, 16) for name, value in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', args.listing.read_text())}
    count = (symbols['LevelCount'] + 1) * 4
    assert symbols['MusicList_End'] - symbols['MusicList'] == count
    ids = list(range(1, count + 1))
    ids[:2] = [symbols['MusID_GHZ'], symbols['MusID_LBZ2_S3']]
    rom = bytearray(args.rom.read_bytes())
    rom[symbols['MusicList']:symbols['MusicList_End']] = bytes(ids)
    test_rom = args.output / 'different-act-music.bin'
    test_rom.write_bytes(rom)
    g = Genesis(args.core, test_rom, args.listing, args.output, args.pal,
                system_directory=args.system_directory)
    boot_level(g, zone=0, act=0)
    base = g.save()
    cpu = CpuPrefix.in_dll(g.core, 'm68k')
    g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
    g.core.m68k_run.argtypes = [C.c_uint]

    def act(label, stop=None):
        g.core.m68k_set_reg(17, 0x2700)
        g.core.m68k_set_reg(0, 0x1234)
        g.write(0x7E00, 0xFF7F00, 4)
        g.write(0x7F00, 0x60FE, 2)
        g.core.m68k_set_reg(15, 0xFF7E00)
        g.core.m68k_set_reg(16, g.s[label])
        for _ in range(20000):
            pc = g.core.m68k_get_reg(16)
            if pc == 0xFF7F00 or stop and pc == g.s[stop]:
                return pc, g.core.m68k_get_reg(0) & 65535
            g.core.m68k_run(cpu.cycles + 1)
        raise AssertionError(label)

    for index, expected in enumerate(ids):
        for routine, stop in (('GetLevelMusic', None), ('Level_PlayBgm', 'PlaySound'),
                              ('ResumeMusic', 'PlayMusic')):
            g.restore(base)
            g.write('Current_ZoneAndAct', (index // 4) * 256 + index % 4, 2)
            g.write('v_air', 5, 2)
            for who in ('v_player', 'v_player2'):
                g.put(who, 'obStatusSecondary', 0)
            g.write('f_lockscreen', 0)
            pc, result = act(routine, stop)
            assert result == expected, (routine, index, expected, result)
            assert pc == (g.s[stop] if stop else 0xFF7F00)
    for invincible, boss, expected in ((True, False, g.s['bgm_Invincible']),
                                      (False, True, g.s['bgm_Boss']),
                                      (True, True, g.s['bgm_Boss'])):
        g.restore(base)
        g.write('v_air', 5, 2)
        g.put('v_player2', 'obStatusSecondary', 2 if invincible else 0)
        g.write('f_lockscreen', int(boss))
        assert act('ResumeMusic', 'PlayMusic') == (g.s['PlayMusic'], expected)
    g.restore(base)
    g.write('v_air', 13, 2)
    assert act('ResumeMusic', 'PlayMusic') == (0xFF7F00, 0x1234)

    # Resume complete emulator frames only from a genuine frame boundary.
    g.restore(base)
    zram = (C.c_uint8 * 8192).in_dll(g.core, 'zram')
    banks = []
    for act_number in (0, 1):
        if act_number:
            g.write('v_gamemode', g.s['SegaScreen'], 2)
            g.run()
            boot_level(g, zone=0, act=act_number)
        expected_bank = rom[g.s['zMasterPlaylist'] + (ids[act_number] - 1) * 4]
        actual_bank = zram[g.s['zAbsVar.MusicBankNumber']]
        assert actual_bank == expected_bank, (act_number, actual_bank, expected_bank)
        assert zram[g.s['zSongFM1.PlaybackControl']] & 0x80
        g.run(120)
        assert not g.read('v_errortype')
        banks.append(actual_bank)
    assert ids[0] != ids[1]
    g.close()
    report = dict(region='PAL' if args.pal else 'NTSC', lookup_and_callers=count * 3,
                  priority_cases=4, live_act_music_ids=ids[:2], live_act_music_banks=banks)
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(report, flush=True)


if __name__ == '__main__':
    main()
