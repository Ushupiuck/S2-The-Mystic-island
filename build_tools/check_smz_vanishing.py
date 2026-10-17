#!/usr/bin/env python3
"""Exercise the real vanishing-platform actor with both player slots."""
from pathlib import Path
import argparse
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--rom', type=Path, required=True)
parser.add_argument('--listing', type=Path, required=True)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
sys.argv = ['native', '--rom', str(args.rom), '--listing', str(args.listing)]
ns = {'__file__': str(ROOT / 'build_tools/check_object_manager.py')}
exec((ROOT / 'build_tools/check_object_manager.py').read_text().split('m=Manager()')[0], ns)
m = ns['Native']()
obj = m.s['v_lvlobjspace']
checks = []
roles = [('sonic', 'v_player', 1), ('tails', 'v_player', 2),
         ('companion', 'v_player2', 2)]


def setup(role, frame=0, rolling=False):
    name, player, character = role
    m.start()
    m.write('Camera_X_pos', 400, 2)
    m.write('Player_mode', m.s['PlayerMode_Tails'] if name == 'tails' else 0, 2)
    for actor in ('v_player', 'v_player2'):
        m.put(actor, 'obX', 1000, 2)
    height = m.s['tails_height'] if character == 2 else 19
    radius = m.s['tails_roll_height'] if character == 2 else 14
    m.put(player, 'layout_id', character)
    m.put(player, 'obHeight', radius if rolling else height)
    m.put(player, 'default_y_radius', height)
    m.put(player, 'obX', 576, 2)
    m.put(player, 'obStatus', 6 if rolling else 2)
    for field, value, size in [
            ('code', m.s['SMZ_VanishPlatform'], 4), ('obX', 576, 2),
            ('obY', 512, 2), ('obRoutine', 2, 1), ('obRender', 0x84, 1),
            ('obActWid', 16, 1), ('obMap', m.s['Map_SMZ_VanP'], 4),
            ('obAnim', 1, 1), ('obPrevAni', 1, 1), ('obFrame', frame, 1),
            ('obTimeFrame', 20, 1), ('SMZ_vanp_timer', 1000, 2),
            ('SMZ_vanp_timelen', 127, 2)]:
        m.put(obj, field, value, size)
    return player, m.get(player, 'obHeight')


def actor_state(player):
    return tuple(m.get(player, field, size) for field, size in
                 [('obX', 2), ('obY', 2), ('obVelX', 2), ('obVelY', 2),
                  ('obInertia', 2), ('obStatus', 1)])


for role in roles:
    for frame in (0, 1):
        for rolling in (False, True):
            for offset in (-14, 0, 14):
                for speed in (-0x200, -0x600):
                    player, height = setup(role, frame, rolling)
                    m.put(player, 'obX', 576 + offset, 2)
                    m.put(player, 'obY', 512 + height - 4, 2)
                    m.put(player, 'obVelY', speed, 2)
                    before = actor_state(player)
                    m.act('SMZ_VanishPlatform', obj)
                    assert actor_state(player) == before, (role, frame, 'underside', before, actor_state(player))
                    checks.append([role[0], frame, rolling, 'rise-through', offset, speed])
            for direction in (-1, 1):
                player, _ = setup(role, frame, rolling)
                m.put(player, 'obX', 576 - direction * 24, 2)
                m.put(player, 'obY', 512, 2)
                m.put(player, 'obVelX', direction * 0x400, 2)
                m.put(player, 'obInertia', direction * 0x400, 2)
                before = actor_state(player)
                m.act('SMZ_VanishPlatform', obj)
                assert actor_state(player) == before, (role, frame, 'side', before, actor_state(player))
                checks.append([role[0], frame, rolling, 'side-through', direction])
        for depth in (0, 4, 10):
            player, height = setup(role, frame)
            m.put(player, 'obY', 504 - height + depth, 2)
            m.put(player, 'obVelY', 0x400, 2)
            m.act('SMZ_VanishPlatform', obj)
            assert m.get(player, 'obStatus') & 8, (role, frame, depth, 'did not land')
            assert not m.get(player, 'obStatus') & 2
            assert m.get(player, 'obY', 2) == 502 - height
            for _ in range(8):
                m.act('SMZ_VanishPlatform', obj)
                assert m.get(player, 'obY', 2) == 503 - height
                assert m.get(player, 'obStatus') & 8
            m.put(player, 'obX', 596, 2)
            m.act('SMZ_VanishPlatform', obj)
            assert not m.get(player, 'obStatus') & 8
            assert m.get(player, 'obStatus') & 2
            checks.append([role[0], frame, 'land-ride-exit', depth])

# The same object supports both players and releases each owned rider as it
# vanishes. The 2 and 3 animation frames must remain non-solid.
for frame in (2, 3):
    setup(roles[0])
    index = ((obj - m.s['v_objspace']) & 65535) // m.s['object_size']
    for player in ('v_player', 'v_player2'):
        height = 19 if player == 'v_player' else m.s['tails_height']
        m.put(player, 'obHeight', height)
        m.put(player, 'default_y_radius', height)
        m.put(player, 'obX', 576, 2)
        m.put(player, 'obY', 504 - height, 2)
        m.put(player, 'obVelY', 0x400, 2)
        m.put(player, 'obStatus', 2)
    m.act('SMZ_VanishPlatform', obj)
    assert m.get(obj, 'obStatus') & 0x18 == 0x18
    for player in ('v_player', 'v_player2'):
        assert m.get(player, 'standonobject') == index
    m.put(obj, 'obFrame', frame)
    m.act('SMZ_VanishPlatform', obj)
    assert not m.get(obj, 'obStatus') & 0x18
    for player in ('v_player', 'v_player2'):
        assert not m.get(player, 'obStatus') & 8
        assert m.get(player, 'obStatus') & 2
    checks.append(['both-players', frame, 'vanish-release'])

report = {'passed': True, 'rom_sha256': hashlib.sha256(args.rom.read_bytes()).hexdigest(),
          'companion_ai_run': False, 'checks': checks}
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
print(f'{len(checks)} vanishing-platform rise, side, landing, ride and release checks pass.')
