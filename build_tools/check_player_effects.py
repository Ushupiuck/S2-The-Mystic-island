#!/usr/bin/env python3
"""Verify real shield/star VRAM uploads and their transitions in Genesis Plus GX."""
from pathlib import Path
import argparse
import json
import struct

from genesis_test_core import Genesis
from check_object_course import boot_level


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    p.add_argument('--player', type=int, choices=(0, 2), default=0)
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
    boot_level(g, item=0, player=args.player)
    rom = args.rom.read_bytes()
    slots = range(g.s['v_lvlobjspace'] & 0xFFFF, g.s['v_lvlobjend'] & 0xFFFF, g.s['object_size'])
    # Isolate the effects fixture from nearby level objects and their temporary
    # test-zone art allocations; retain the live player dust controllers.
    for obj in slots:
        if g.get(obj, 'code') != g.s['SpindashDust']:
            g.write(obj, 0, g.s['object_size'])
    banks = [('v_shieldobj', g.s['ArtTile_Shield'] * 32)]
    if not args.player:
        banks.append(('v_shieldobj2', g.s['ArtTile_Shield_2'] * 32))

    def vram(address, length):
        return bytes(g.vram[(address + i) ^ 1] for i in range(length))

    def reward(kind):
        obj = next(a for a in slots if not g.get(a, 'code'))
        for field, value, size in [('code', g.s['Obj29'], 4), ('obAnim', kind, 1),
                ('obX', g.get('v_player', 'obX', 2), 2), ('obY', g.get('v_player', 'obY', 2), 2),
                ('obParent', g.s['v_player'] & 0xFFFF, 2)]:
            g.put(obj, field, value, size)
        g.run(40)

    def shields(screenshot):
        seen = {name: set() for name, _ in banks}
        captured = False
        for _ in range(60):
            previous = {name: g.get(name, 'effect_loaded_frame') for name, _ in banks}
            g.run()
            for name, bank in banks:
                frame = g.get(name, 'effect_loaded_frame')
                # CPU state can already describe the next queued frame. Sample
                # stable cache frames after VBlank has performed their DMA.
                if frame != previous[name] or not 2 <= frame <= 4:
                    continue
                table = g.s['DPLC_Shield']
                pos = table + struct.unpack_from('>h', rom, table + frame * 2)[0]
                count = struct.unpack_from('>H', rom, pos)[0]
                expected = bytearray()
                for i in range(count):
                    run = struct.unpack_from('>H', rom, pos + 2 + i * 2)[0]
                    source = g.s['Art_Shield'] + (run & 0xFFF) * 32
                    size = ((run >> 12) + 1) * 32
                    expected.extend(rom[source:source + size])
                assert vram(bank, len(expected)) == expected, (name, frame, hex(bank))
                seen[name].add(frame)
                if name == banks[0][0] and frame == 2 and not captured:
                    g.video.save(args.output / screenshot)
                    captured = True
        assert all(frames == {2, 3, 4} for frames in seen.values()), seen
        return {name: sorted(frames) for name, frames in seen.items()}

    reward(6)
    first = shields('shields.png')
    reward(7)
    g.run(5)
    stars = rom[g.s['Art_Invincibility']:g.s['Art_Invincibility_End']]
    assert vram(g.s['ArtTile_Invincibility'] * 32, len(stars)) == stars
    star_sprites = [i for i in range(g.read('v_spritecount'))
                   if g.s['ArtTile_Invincibility'] <= g.read(g.s['Sprite_Table'] + i * 8 + 4, 2) & 0x7FF
                   < g.s['ArtTile_Invincibility'] + len(stars) // 32]
    assert star_sprites, 'Stars never reached the sprite table'
    g.video.save(args.output / 'stars.png')
    for player in ('v_player', 'v_player2'):
        g.put(player, 'obStatusSecondary', g.get(player, 'obStatusSecondary') & ~2)
        g.put(player, 'invtime', 0, 2)
    resumed = shields('shields-restored.png')
    report = {'region': 'PAL' if args.pal else 'NTSC', 'primary': 'Tails' if args.player else 'Sonic',
              'shield_uploads': first, 'resident_star_tiles_match': len(stars) // 32,
              'star_sprites': len(star_sprites), 'shield_uploads_after_stars': resumed}
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(report, flush=True)
    g.close()


if __name__ == '__main__':
    main()
