#!/usr/bin/env python3
"""Execute the assembled SBZ door with either player using Genesis Plus GX.

This is a collision fixture, separate from the controller-only route runs.
The CPU calls real ROM routines and returns into a small RAM spin loop.
"""
from pathlib import Path
import argparse
import ctypes as C
import hashlib
import json
import tempfile

from genesis_test_core import Genesis

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--core', type=Path, required=True)
parser.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
parser.add_argument('--listing', type=Path, default=ROOT / 'main.lst')
parser.add_argument('--output', type=Path)
args = parser.parse_args()
checks = []


class DoorFixture:
    def __init__(self, directory):
        self.g = Genesis(args.core, args.rom, args.listing, directory)
        self.g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
        self.g.core.m68k_run.argtypes = [C.c_uint]
        self.cycles = 10_000_000
        self.obj = self.g.s['v_lvlobjspace']

    def act(self, count=1):
        for _ in range(count):
            self.g.write(0xFF8000, 0x60FE, 2)
            self.g.write(0xFF8FF0, 0xFF8000, 4)
            for register, value in [(17, 0x2700), (15, 0xFF8FF0),
                                    (8, self.obj), (16, self.g.s['Obj30'])]:
                self.g.core.m68k_set_reg(register, value)
            self.cycles += 100_000
            self.g.core.m68k_run(self.cycles)
            assert self.g.core.m68k_get_reg(16) == 0xFF8000, 'Door did not return'

    def start(self, flip=0, settle=True, solo_tails=False):
        C.memset(self.g.ram, 0, 65536)
        self.g.write('Current_Zone', self.g.s['id_SMZ'])
        self.g.write('v_gamemode', self.g.s['Level'], 2)
        self.g.write('Camera_X_pos', 400, 2)
        self.g.write('Player_mode', self.g.s['PlayerMode_Tails'] if solo_tails else 0, 2)
        for actor, character in [('v_player', 2 if solo_tails else 1), ('v_player2', 2)]:
            height = self.g.s['tails_height'] if character == 2 else 19
            for field, value, size in [('layout_id', character, 1), ('obRoutine', 2, 1),
                    ('character_id', character - 1, 1), ('obRender', 0x84, 1),
                    ('obHeight', height, 1), ('obWidth', 9, 1),
                    ('default_y_radius', height, 1), ('default_x_radius', 9, 1),
                    ('obX', 900, 2), ('obY', 512, 2)]:
                self.g.put(actor, field, value, size)
        if solo_tails:
            self.g.put('v_player2', 'code', 0, 4)
        for field, value, size in [('code', self.g.s['Obj30'], 4), ('obX', 576, 2),
                ('obY', 512, 2), ('obStatus', flip, 1), ('obRender', 0x84, 1)]:
            self.g.put(self.obj, field, value, size)
        if settle:
            self.act(20)
            assert self.g.get(self.obj, 'obFrame') == 0, 'Door did not close'

    def player(self, actor, x, y=512):
        self.g.put(actor, 'obX', x, 2)
        self.g.put(actor, 'obY', y, 2)

    def opening(self):
        return self.g.get(self.obj, 'obAnim') == 1


with tempfile.TemporaryDirectory(prefix='sbz-door-') as directory:
    m = DoorFixture(Path(directory))
    for flip in (0, 1):
        direction = -1 if flip else 1
        approach = 576 - direction * 32
        for actor in ('v_player2', 'v_player'):
            m.start(flip)
            m.player(actor, approach)
            m.act()
            assert m.opening(), (actor, flip, 'Cannot open from approach side')
            m.act(20)
            assert m.g.get(m.obj, 'obFrame') == 8
            checks.append([actor, flip, 'opens'])

            # The first player has left; the second still needs the opening.
            m.player('v_player', 576 + direction * 96)
            m.player('v_player2', approach)
            m.act(20)
            assert m.opening(), (flip, 'Closed before Tails could pass')
            checks.append([actor, flip, 'waits-for-second-player'])

            for offset in (-16, -8, 0, 8, 16, 23):
                x = 576 + direction * offset
                m.player('v_player2', x)
                m.g.put('v_player2', 'obVelX', direction * 0x400, 2)
                m.g.put('v_player2', 'obInertia', direction * 0x400, 2)
                m.act()
                assert m.opening(), (flip, offset, 'Closed during crossing')
                assert m.g.get('v_player2', 'obX', 2) == x
                assert m.g.get('v_player2', 'obVelX', 2) == (direction * 0x400) & 65535
                checks.append([actor, flip, 'pass-through', offset])
            m.player('v_player2', 576 + direction * 25)
            m.act(20)
            assert not m.opening() and m.g.get(m.obj, 'obFrame') == 0
            checks.append([actor, flip, 'closes-after-both-clear'])

            for settle in (False, True):
                m.start(flip, settle=settle)
                m.player(actor, 576 + direction * 12)
                m.act(20)
                assert not m.opening(), (actor, flip, settle, 'Wrong-side entry')
                checks.append([actor, flip, 'one-way', settle])

            for condition in ('absent', 'dead', 'scripted', 'above', 'below'):
                m.start(flip)
                m.player(actor, approach)
                if condition == 'absent':
                    m.g.put(actor, 'code', 0, 4)
                elif condition == 'dead':
                    m.g.put(actor, 'obRoutine', 6)
                elif condition == 'scripted':
                    m.g.put(actor, 'obControl', 0x81)
                else:
                    m.g.put(actor, 'obY', 512 + (32 if condition == 'below' else -33), 2)
                m.act()
                assert not m.opening(), (actor, flip, condition, 'Invalid trigger')
                checks.append([actor, flip, 'ignores', condition])

            m.start(flip)
            m.player(actor, approach)
            m.g.put(actor, 'obControl', 1)
            m.act()
            assert m.opening(), (actor, flip, 'Input-only lock blocked player')
            checks.append([actor, flip, 'accepts-input-only-lock'])

        m.start(flip, solo_tails=True)
        m.player('v_player', approach)
        m.act()
        assert m.opening(), (flip, 'Solo Tails cannot open door')
        checks.append(['solo-tails', flip, 'opens'])
    m.g.close()

report = {'rom_sha256': hashlib.sha256(args.rom.read_bytes()).hexdigest(),
          'checks': len(checks), 'results': checks,
          'kind': 'direct real-68000 object fixture; not AI route evidence'}
if args.output:
    args.output.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'checks': len(checks), 'passed': True}))
