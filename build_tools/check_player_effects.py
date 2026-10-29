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
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--player', type=int, choices=(0, 2), default=0)
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
                system_directory=args.system_directory)
    boot_level(g, item=0, player=args.player)
    rom = args.rom.read_bytes()
    art_root = Path(__file__).resolve().parents[1] / 'art/uncompressed'
    shield_art = (art_root / 'Shield.unc').read_bytes()
    stars = (art_root / 'Invincibility.unc').read_bytes()
    if 'Player_Art_Buffer_Start' in g.s:
        for label, data in [('Art_Shield', shield_art), ('Art_Invincibility', stars),
                            ('Art_Ring', (art_root / 'Ring.bin').read_bytes())]:
            assert bytes(g.read(g.s[label] + i) for i in range(len(data))) == data, label
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

    # Keep the existing regular/lost-ring frame uploader honest with a RAM
    # source too. Lost-ring timing is held while each source frame is selected.
    ring_art = (art_root / 'Ring.bin').read_bytes()
    seen_rings = set()
    for frame in range(8):
        g.write('v_ani3_time', 0)
        g.write('v_ani3_frame', frame)
        g.write('v_ani3_prev', 255)
        expected = ring_art[frame*128:(frame+1)*128]
        for _ in range(8):
            g.run()
            assert not g.read('v_errortype')
            if vram(g.s['ArtTile_RingLoss'] * 32, 128) == expected:
                break
        else:
            raise AssertionError(('Lost-ring frame never reached VRAM', frame))
    for _ in range(48):
        previous = g.read('v_ani1_prev')
        g.run()
        frame = g.read('v_ani1_prev')
        if frame == previous:
            assert vram(g.s['ArtTile_Ring'] * 32, 128) == ring_art[frame*128:(frame+1)*128]
            seen_rings.add(frame)
    assert seen_rings == set(range(8)), seen_rings

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
                    source = (run & 0xFFF) * 32
                    size = ((run >> 12) + 1) * 32
                    expected.extend(shield_art[source:source + size])
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
    star_colors = {n for byte in stars for n in (byte >> 4, byte & 15)}
    assert star_colors == {0, 6, 7, 8, 9}, ('Stars must use the shared gray ramp', star_colors)
    assert vram(g.s['ArtTile_Invincibility'] * 32, len(stars)) == stars
    star_sprites = [i for i in range(g.read('v_spritecount'))
                   if g.s['ArtTile_Invincibility'] <= g.read(g.s['Sprite_Table'] + i * 8 + 4, 2) & 0x7FF
                   < g.s['ArtTile_Invincibility'] + len(stars) // 32]
    assert star_sprites, 'Stars never reached the sprite table'
    assert all(g.read(g.s['Sprite_Table']+i*8+4, 2) >> 13 & 3 == 0 for i in star_sprites)
    g.video.save(args.output / 'stars.png')
    for player in ('v_player', 'v_player2'):
        g.put(player, 'obStatusSecondary', g.get(player, 'obStatusSecondary') & ~2)
        g.put(player, 'invtime', 0, 2)
    resumed = shields('shields-restored.png')
    # Use a real sky-drop sign to retain both actors on screen during results
    # and observe concurrent shield, glyph and bonus-digit uploads.
    from check_companion_followup import place
    actors=['v_player'] if args.player else ['v_player','v_player2']
    for i,actor in enumerate(actors):
        place(g,actor,80+i*96,940,False);g.put(actor,'obControl',1)
        assert g.get(actor,'obStatusSecondary')&1
    for field in ('Camera_X_pos','Camera_Min_X_pos','Camera_Max_X_pos'):
        g.write(field,0,2)
    g.write('v_rings',123,2);g.write('v_timemin',0);g.write('v_timesec',30)
    g.write('f_ringcount',1)
    sign=next(a for a in slots if not g.get(a,'code'))
    for field,value,size in [('code',g.s['Signpost'],4),('obSubtype',1,2),('obX',248,2),('obY',930,2)]:
        g.put(sign,field,value,size)
    for _ in range(600):
        g.run();assert not g.read('v_errortype')
        if g.get('v_endcard','code')==g.s['GotThrough'] and g.get('v_endcard','obRoutine'):
            break
    else:raise AssertionError('Falling sign never reached results')
    during_results=shields('results-shields.png')
    assert all(g.get(actor,'obStatusSecondary')&1 for actor in actors)
    assert all(g.get(name,'code')==g.s['Obj38'] for name,_ in banks)
    root=g.s['DPLC_Cards'];scene=64+(args.player==2)
    cue=root+struct.unpack_from('>h',rom,root+scene*2)[0];glyphs=bytearray()
    for i in range(struct.unpack_from('>H',rom,cue)[0]):
        word=struct.unpack_from('>H',rom,cue+2+i*2)[0]
        source=g.s['Art_CardFont']+(word&4095)*32
        glyphs+=rom[source:source+((word>>12)+1)*32]
    assert vram(g.s['ArtTile_Results_Card']*32,len(glyphs))==glyphs
    # Reach the real tally, then allow shield and numeric uploads together.
    original_bonus=g.read('v_timebonus',2)+g.read('v_ringbonus',2)
    for _ in range(400):
        g.run();assert not g.read('v_errortype')
        if g.read('v_timebonus',2)+g.read('v_ringbonus',2)<original_bonus:break
    else:raise AssertionError('Results tally did not start')
    tally_shields=shields('results-tally-shields.png')
    font=(art_root/'HUD Numbers.bin').read_bytes()
    for offset,name in ((0,'v_timebonus'),(8,'v_ringbonus')):
        # Numeric state can be one frame ahead of DMA, so sample a stable pair.
        matched=False
        for _ in range(8):
            value=g.read(name,2);leading=True;expected=bytearray()
            for digit in f'{value:04d}':
                leading=leading and digit=='0'
                expected+=bytes(64) if leading else font[int(digit)*64:(int(digit)+1)*64]
            g.run();assert not g.read('v_errortype')
            if vram((g.s['ArtTile_Bonuses']+offset)*32,256)==expected:
                matched=True;break
        assert matched,(name,'bonus digits overlap shield or glyph DMA')
    assert vram(g.s['ArtTile_Results_Card']*32,len(glyphs))==glyphs
    report = {'region': 'PAL' if args.pal else 'NTSC', 'primary': 'Tails' if args.player else 'Sonic',
              'regular_and_lost_ring_frames': len(seen_rings),
              'shield_uploads': first, 'resident_star_tiles_match': len(stars) // 32,
              'star_sprites': len(star_sprites), 'shield_uploads_after_stars': resumed,
              'results_shields':during_results,'tally_shields':tally_shields,'results_glyphs_and_bonus_digits_match':True}
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(report, flush=True)
    g.close()


if __name__ == '__main__':
    main()
