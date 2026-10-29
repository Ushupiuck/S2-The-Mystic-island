#!/usr/bin/env python3
"""Check Debug HUD switching and real monitor-inflicted recoil/death in GX.

Fixtures only place the hazard and position the player. The collision,
damage, button handling, Debug entry and restoration use the real ROM code.
"""
from pathlib import Path
import argparse
import json
import struct

from genesis_test_core import Genesis
from check_object_course import boot_level


def press_debug(g, debug_type):
    # Recoil can lag a displayed frame. Hold the press until the engine handles it.
    g.buttons = {0, 8} if debug_type == 2 else {0}
    for _ in range(4):
        g.run()
        if g.read('Debug_placement_type') == debug_type:
            break
    else:
        raise AssertionError(('Debug button was not handled', debug_type))
    g.buttons = set()


def check_hud(g, rom, output):
    baseline = g.save()
    if g.read('Current_ZoneAndAct', 2) == 0x0301:
        # EHZ2's private scenery palette must preserve shared HUD ink/shading.
        # Read live colors after the real palette loader, not the importer report.
        palette = struct.unpack('>48H', (Path(__file__).resolve().parents[1]/'palette/EHZ.bin').read_bytes())
        for index in (1, 6, 7, 8, 12, 13, 14):
            assert g.read(g.s['v_palette']+(16+index)*2, 2) == palette[index], (
                'EHZ2 background overwrote a shared HUD color', index)
    art = rom[g.s['Art_HUD']:]
    font = rom[g.s['Art_DebugDigits']:g.s['Art_DebugDigits'] + 16 * 32]
    glyphs = [font[i:i + 32] for i in range(0, len(font), 32)]
    assert {n for b in font for n in (b >> 4, b & 15)} == {0, 6}
    shared = rom[g.s['Art_Text']:g.s['Art_Text_End']]
    expected = shared[:10 * 32] + shared[17 * 32:23 * 32]
    assert font == bytes(b & 0x66 for b in expected), 'HUD changed the shared Ristar glyph shapes'

    def tiles(first, count):
        address = first * 32
        return bytes(g.vram[(address + i) ^ 1] for i in range(count * 32))

    def digits(text):
        return b''.join(art[int(c) * 64:(int(c) + 1) * 64] for c in text)

    def check_mapping(placement):
        # The second HUD piece is SCORE's E during play, coordinates in placement.
        relative = g.s['Map_Obj21_DebugDigits' if placement else 'Map_Obj21_ScoreE']
        expected = (g.s['ArtTile_HUD'] + relative) & 0xFFFF
        assert g.read(g.s['Sprite_Table'] + 12, 2) == expected, (
            'Wrong HUD mapping for active Debug type', placement)

    def check_numbers():
        first = g.s['ArtTile_HUD_Numbers']
        assert tiles(first, 14) == digits('1234560'), 'Score not restored'
        assert tiles(first + 14, 2) == digits(str(g.read('v_timemin')))
        assert tiles(first + 18, 4) == digits(f"{g.read('v_timesec'):02}"), (
            'Time still contains Debug digits or initial zeroes')
        assert tiles(first + 22, 6) == digits('123'), 'Rings not restored'

    cases = []
    for running in (0, 1):
        for frame_cycle in (False, True):
            g.restore(baseline)
            g.write('Debug_mode_flag', 1)
            g.write('v_score', 123456, 4)
            g.write('v_rings', 123, 2)
            g.write('v_time', 1 << 16 | 37 << 8 | 20, 4)
            for flag in ('f_scorecount', 'f_ringcount', 'f_timecount'):
                g.write(flag, 0x80)
            g.run(3)
            g.write('f_timecount', running)
            before = g.read('v_time', 4)
            g.run(3)
            check_mapping(False)
            check_numbers()
            assert (g.read('v_time', 4) != before) == bool(running), (
                'Enabling Debug changed normal clock rules', running)
            label = f"hud-{'running' if running else 'stopped'}-{'cycle' if frame_cycle else 'placement'}"
            g.video.save(output / f'{label}-play.png')
            before = g.read('v_time', 4)
            press_debug(g, 2 if frame_cycle else 1)
            g.run(3)
            assert g.read('Debug_placement_type') == (2 if frame_cycle else 1)
            assert g.read('v_rings', 2) == 123, 'Debug clock wrote outside the timer'
            check_mapping(not frame_cycle)
            if frame_cycle:
                check_numbers()
                assert (g.read('v_time', 4) != before) == bool(running)
            else:
                assert tiles(g.s['ArtTile_HUD_Numbers'], 14) != digits('1234560')
                first = g.s['ArtTile_HUD_Debug_Numbers']
                assert all(tiles(first + i, 1) in glyphs for i in range(16)), (
                    'Coordinates did not use the white hexadecimal font')
                assert g.read('v_time', 4) != before, 'Placement clock stopped'
            g.video.save(output / f'{label}-debug.png')
            press_debug(g, 0)
            g.run(3)
            assert not g.read('Debug_placement_mode', 2)
            assert g.read('f_timecount') == running, 'Debug exit restarted a stopped clock'
            check_mapping(False)
            check_numbers()
            assert not g.read('v_errortype')
            g.video.save(output / f'{label}-exit.png')
            cases.append({'running_clock': bool(running), 'frame_cycle': frame_cycle,
                          'normal_hud_restored': True})

    for debug_type in (0, 1, 2):
        g.restore(baseline)
        g.write('Debug_mode_flag', 1)
        if debug_type:
            press_debug(g, debug_type)
            g.run(3)
        g.write('v_time', 9 << 16 | 59 << 8 | 59, 4)
        g.write('f_timecount', 1)
        g.run(3)
        assert bool(g.read('f_timeover')) == (debug_type != 1), (
            'Time Over must be bypassed only in placement', debug_type)
        if debug_type != 1:
            assert not g.read('Debug_placement_mode', 2)
            assert g.get('v_player', 'obRoutine') == 6, 'Time Over did not kill the player'
    g.restore(baseline)
    return {'switches': cases, 'time_over_only_bypassed_in_placement': True}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--player', type=int, choices=(0, 2), default=0)
    p.add_argument('--zone', type=int, default=0)
    p.add_argument('--act', type=int, choices=range(1, 5), default=1)
    p.add_argument('--system-directory', type=Path)
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
                system_directory=args.system_directory)
    boot_level(g, zone=args.zone, act=args.act-1, player=args.player)
    g.put('v_player2', 'code', 0)
    baseline = g.save()
    slots = range(g.s['v_lvlobjspace'] & 0xFFFF,
                  g.s['v_lvlobjend'] & 0xFFFF, g.s['object_size'])
    report = {'region': 'PAL' if args.pal else 'NTSC',
              'player': 'Tails' if args.player else 'Sonic', 'cases': []}
    report['hud'] = check_hud(g, args.rom.read_bytes(), args.output)
    for routine, rings, label in ((4, 40, 'hurt'), (6, 0, 'dying')):
        for frame_cycle in (False, True):
            g.restore(baseline)
            g.write('Debug_mode_flag', 0)  # zero-ring Debug immunity is intentional
            g.write('v_rings', rings, 2)
            x = g.get('v_player', 'obX', 2)
            y = g.get('v_player', 'obY', 2) - 64
            obj = next(a for a in slots if not g.get(a, 'code'))
            for field, value, size in [('code', g.s['Obj26'], 4),
                    ('obX', x, 2), ('obY', y, 2), ('obSubtype', 0, 1)]:
                g.put(obj, field, value, size)
            for field, value, size in [('obY', y - 110, 2), ('obStatus', 6, 1),
                    ('obAnim', g.s['AniIDSonAni_Roll'], 1),
                    ('obPrevAni', 0xFF, 1), ('obStatusSecondary', 0, 1),
                    ('flashtime', 0, 2), ('obVelX', 0, 2), ('obVelY', 0, 2),
                    ('obHeight', g.s['tails_roll_height' if args.player else 'sonic_roll_height'], 1),
                    ('obWidth', g.s['tails_roll_width' if args.player else 'sonic_roll_width'], 1)]:
                g.put('v_player', field, value, size)
            for tick in range(180):
                g.run()
                if g.get('v_player', 'obRoutine') == routine:
                    break
            else:
                raise AssertionError(('Monitor did not produce the real state', label))
            code = g.get('v_player', 'code')
            mapping = g.get('v_player', 'obMap', 4)
            g.write('Debug_mode_flag', 1)
            expected = 2 if frame_cycle else 1
            press_debug(g, expected)
            assert g.read('Debug_placement_type') == expected, (label, frame_cycle)
            g.run(3)
            assert g.get('v_player', 'code') == code
            if frame_cycle:
                before = g.get('v_player', 'obFrame')
                g.run(2)
                assert g.get('v_player', 'obFrame') != before
            else:
                assert g.get('v_player', 'obMap', 4) != mapping
            g.video.save(args.output / f'{label}-{expected}-debug.png')
            press_debug(g, 0)
            assert not g.read('Debug_placement_mode', 2)
            assert g.get('v_player', 'code') == code
            assert g.get('v_player', 'obMap', 4) == mapping
            if not frame_cycle:
                assert g.get('v_player', 'obRoutine') == 2
                assert g.get('v_player', 'obHeight') == g.get('v_player', 'default_y_radius')
                assert g.get('v_player', 'obWidth') == g.get('v_player', 'default_x_radius')
                assert not g.get('v_player', 'obVelX', 2)
                assert not g.get('v_player', 'obVelY', 2)
                g.buttons = set()
                g.run(45)
                assert g.get('v_player', 'obRoutine') == 2
            assert not g.read('v_errortype')
            row = {'state': label, 'debug_type': expected, 'entered': True,
                   'code_preserved': True, 'mappings_restored': True,
                   'exit_routine': g.get('v_player', 'obRoutine')}
            report['cases'].append(row)
            g.video.save(args.output / f'{label}-{expected}-exit.png')
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(report)
    g.close()


if __name__ == '__main__':
    main()
