#!/usr/bin/env python3
"""Check restored LZ1 conveyors in Genesis Plus GX, with actual player riding."""
import argparse
import json
import struct
from pathlib import Path

from genesis_test_core import Genesis
from check_object_course import boot_level

p = argparse.ArgumentParser(description=__doc__)
for name in ('rom', 'listing', 'core', 'output'):
    p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--system-directory', type=Path)
p.add_argument('--pal', action='store_true')
p.add_argument('--player', type=int, choices=(0, 2), default=0)
p.add_argument('--spiked', action='store_true', help='Change the first real group to subtype C0 in a disposable ROM')
args = p.parse_args()
rom = args.rom
if args.spiked:
    import re
    symbols = {n: int(v, 16) for n, v in re.findall(r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', args.listing.read_text())}
    data = bytearray(rom.read_bytes())
    pos = symbols['ObjPos_LZ1']
    while struct.unpack_from('>H', data, pos)[0] != 0xFFFF:
        if data[pos + 4:pos + 6] == bytes((0x1F, 0x80)):
            data[pos + 5] = 0xC0
            break
        pos += 6
    else:
        raise AssertionError('No LZ1 group-0 placement')
    struct.pack_into('>H', data, 0x18E, sum(struct.unpack_from('>H', data, i)[0] for i in range(0x200, len(data), 2)) & 65535)
    args.output.mkdir(parents=True, exist_ok=True)
    rom = args.output / 'spiked-fixture.bin'
    rom.write_bytes(data)
g = Genesis(args.core, rom, args.listing, args.output, args.pal,
            system_directory=args.system_directory)
boot_level(g, zone=1, act=0, player=args.player)
pool = range(g.s['v_lvlobjspace'] & 65535, g.s['v_lvlobjend'] & 65535, g.s['object_size'])
actors = ['v_player', 'v_player2'] if args.player == 0 else ['v_player']


def run(frames=1):
    for _ in range(frames):
        g.run()
        assert not g.read('v_errortype'), ('CPU exception', g.frame)


def platforms():
    return [a for a in pool if g.get(a, 'code') == g.s['LabyrinthConvey']
            and g.get(a, 'obRoutine') == 2 and g.get(a, 'LCon_originX', 2) == 0x1070]


def position(x, y):
    for actor in actors:
        for field, value, size in (
                ('obX', x, 2), ('obY', y, 2), ('obVelX', 0, 2), ('obVelY', 0, 2),
                ('obInertia', 0, 2), ('obControl', 1, 1), ('obStatus', 2, 1),
                ('obAnim', 0, 1), ('jumping', 0, 1), ('standonobject', 0, 1),
                ('obRoutine', 2, 1), ('obStatusSecondary', 2, 1),
                ('invtime', 6000, 2), ('flashtime', 0, 2)):
            g.put(actor, field, value, size)
        g.put(actor, 'obHeight', g.get(actor, 'default_y_radius'))
        g.put(actor, 'obWidth', g.get(actor, 'default_x_radius'))
    g.write('Tails_CPU_idle_timer', 600, 2)
    g.write('Camera_X_pos', x - 160, 2)
    g.write('Camera_Y_pos', y - 100, 2)


position(0x1070, 0x300)
run(90)
objects = platforms()
assert len(objects) == 8, ('missing real-layout group', len(objects))
assert {g.get(a, 'obFrame') for a in objects} == {5 if args.spiked else 4}
assert sum(bool(g.get(a, 'respawn_addr', 2)) for a in objects) == 1
platform = min((a for a in objects if g.get(a, 'obVelY', 2) == 0xFF00
                and not g.get(a, 'obVelX', 2)), key=lambda a: g.get(a, 'obY', 2))
x, y = g.get(platform, 'obX', 2), g.get(platform, 'obY', 2)
position(x, y - 30)
for actor, dx in zip(actors, (-4, 4)):
    g.put(actor, 'obX', x + dx, 2)
    g.put(actor, 'obY', y - 8 - g.get(actor, 'obHeight'), 2)
    g.put(actor, 'obVelY', 0x100, 2)
run(2)
mask = 0x18 if len(actors) == 2 else 8
assert g.get(platform, 'obStatus') & mask == mask, (
    'boarding', hex(g.get(platform, 'obStatus')),
    [(a, g.get(a, 'obStatus'), g.get(a, 'obY', 2), g.get(a, 'obHeight')) for a in actors])
offsets = {a: (g.get(a, 'obX', 2) - g.get(platform, 'obX', 2),
               g.get(a, 'obY', 2) - g.get(platform, 'obY', 2)) for a in actors}
# Verify the complete live conveyor bank, including its final tile, against
# the editable sheet. The old allocation overlapped Ball Hog V by one tile.
raw = (Path(__file__).resolve().parents[1] / 'art/moduled kosinski/LZ conveyor.unc').read_bytes()
bank = g.s['ArtTile_LZ_Conveyor_Belt'] * 32
assert bytes(g.vram[(bank + i) ^ 1] for i in range(len(raw))) == raw
g.video.save(args.output / 'boarding.png')
start_y = g.get(platform, 'obY', 2)
for tick in range(40):
    run()
    assert g.get(platform, 'obStatus') & mask == mask, ('lost rider', tick)
    for actor in actors:
        actual = (g.get(actor, 'obX', 2) - g.get(platform, 'obX', 2),
                  g.get(actor, 'obY', 2) - g.get(platform, 'obY', 2))
        assert actual == offsets[actor], ('carry offset', actor, tick, offsets[actor], actual)
assert g.get(platform, 'obY', 2) - start_y == -40
g.video.save(args.output / 'riding.png')

# Feed the same flag written by switch E, retaining real motion/collision and
# the original S1 one-way latch. Native tests cover the flag/phase combinations.
g.write(g.s['f_switch'] + 14, 1)
run(12)
assert g.read('f_conveyrev') == 1
assert {g.get(a, 'LCon_increment') for a in platforms()} == {0xFC}
assert g.get(platform, 'obStatus') & mask == mask
g.write(g.s['f_switch'] + 14, 0)
run(12)
assert {g.get(a, 'LCon_increment') for a in platforms()} == {0xFC}
g.video.save(args.output / 'reversed.png')

# Ordinary controller input leaves the real moving carrier.
g.put('v_player', 'obControl', 0)
g.buttons = {1}
run(2)
g.buttons = set()
assert g.get('v_player', 'obStatus') & 2 and not g.get('v_player', 'obStatus') & 8
assert not g.get(platform, 'obStatus') & 8
if len(actors) == 2:
    assert g.get(platform, 'obStatus') & 0x10
g.video.save(args.output / 'jump.png')

# Real camera travel unloads/releases the group, then reconstructs exactly one
# copy with the persistent switch reversal inherited by every new platform.
position(0x200, 0x200)
run(90)
assert not platforms()
position(0x1070, 0x300)
run(90)
objects = platforms()
assert len(objects) == 8 and sum(bool(g.get(a, 'respawn_addr', 2)) for a in objects) == 1
assert {g.get(a, 'LCon_increment') for a in objects} == {0xFC}
g.video.save(args.output / 'reloaded.png')

# Rise into both undersides. Normal platforms remain harmless; spiked members
# use the real hurt/ring/shield path for both actors, without harming riders.
platform = objects[0]
x, y = g.get(platform, 'obX', 2), g.get(platform, 'obY', 2)
position(x, y + 30)
g.put(platform, 'obStatus', g.get(platform, 'obStatus') & ~0x18)
g.write('v_rings', 99, 2)
for actor, dx in zip(actors, (-4, 4)):
    g.put(actor, 'obX', x + dx, 2)
    g.put(actor, 'obY', y + 8 + g.get(actor, 'obHeight') - 6, 2)
    g.put(actor, 'obVelY', -0x100, 2)
    g.put(actor, 'obStatusSecondary', 0)
    g.put(actor, 'invtime', 0, 2)
    g.put(actor, 'flashtime', 0, 2)
# A libretro frame may begin partway through the current object pass. Hold the
# rising contact until a complete pass sees it, without resetting a hurt actor.
for tick in range(4):
    run()
    if args.spiked and all(g.get(actor, 'obRoutine') == 4 for actor in actors):
        break
    for actor in actors:
        if g.get(actor, 'obRoutine') == 2:
            g.put(actor, 'obY', g.get(platform, 'obY', 2) + 8 + g.get(actor, 'obHeight') - 6, 2)
            g.put(actor, 'obVelY', -0x100, 2)
assert {g.get(actor, 'obRoutine') for actor in actors} == {4 if args.spiked else 2}, {
    'platform': [g.get(platform, f, n) for f, n in (('obRoutine', 1), ('obRender', 1), ('obFrame', 1), ('LCon_settings', 1), ('obX', 2), ('obY', 2))],
    'actors': {a: [g.get(a, f, n) for f, n in (('obRoutine', 1), ('obX', 2), ('obY', 2), ('obVelY', 2), ('obStatus', 1), ('obStatusSecondary', 1), ('flashtime', 2), ('obControl', 1))] for a in actors},
    'global_control': g.read('f_playerctrl'), 'debug': g.read('Debug_placement_mode', 2)}
g.video.save(args.output / 'underside.png')
report = {'region': 'PAL' if args.pal else 'NTSC', 'player_mode': args.player,
          'real_lz1_group': 8, 'riders': actors, 'carried_pixels': 40,
          'switch_reversal_persists': True, 'controller_jump_detaches': True,
          'whole_group_unload_reload': True, 'spiked': args.spiked,
          'underside_response': 'hurt' if args.spiked else 'harmless', 'vram_sheet_matches': True}
(args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(report)
