#!/usr/bin/env python3
"""Check the sprite ABI and imported art against a built ASL ROM/listing.

Optional --skdisasm compares Tails pixels to the pinned S&K source art after
applying Mystic Island's palette-slot permutation. This tool does not edit assets.
"""
from argparse import ArgumentParser
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
TAILS_PALETTE_REMAP = (0, 6, 5, 3, 2, 4, 12, 13, 14, 15, 10, 11, 7, 8, 9, 1)


def frames(data, base=0, count=None):
    if count is None:
        boundary, offset = len(data) - base, 0
        while offset < boundary:
            target = struct.unpack_from('>h', data, base + offset)[0]
            assert target > 0 and target % 2 == 0
            boundary = min(boundary, target)
            offset += 2
            assert offset <= boundary and offset <= 512
        count = offset // 2
    assert 0 < count <= 256
    result = []
    for frame in range(count):
        offset = struct.unpack_from('>h', data, base + frame * 2)[0]
        assert offset >= count * 2 or offset < 0
        start = base + offset
        pieces = struct.unpack_from('>H', data, start)[0]
        assert pieces <= 64
        row = [struct.unpack_from('>bBHh', data, start + 2 + i * 6)
               for i in range(pieces)]
        assert all(size < 16 for _, size, _, _ in row)
        result.append(row)
    return result


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('--skdisasm', type=Path)
    args = parser.parse_args()
    binaries = sorted((ROOT / 'mappings/sprite').glob('*.bin'))
    for path in binaries:
        frames(path.read_bytes())

    rom = (ROOT / 's2built.bin').read_bytes()
    symbols = {name: int(value, 16) for name, value in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',
        (ROOT / 'md-main.lst').read_text())}
    # The VDP DMA source is a word address; an odd ROM pointer silently
    # uploads the preceding byte and shifts every pixel in the frame.
    for label in ('Art_Sonic', 'Art_Tails', 'Art_Tails_Extra', 'Art_Tails_Tails',
            'Art_SpindashDust', 'Art_WaterSplash', 'Art_AirCountdown',
            'Art_Points', 'Art_Shield', 'Art_Invincibility', 'Art_Ring',
            'Art_SSResultsRing', 'Art_BigRing', 'Art_BigFlash'):
        assert symbols[label] % 2 == 0, f'{label}: DMA source needs word alignment'
    if 'Player_Art_Buffer_Start' in symbols:
        for label, packed, source in (
                ('Art_Shield', 'Nem_Shield_Dynamic', 'Shield.unc'),
                ('Art_Invincibility', 'Nem_Invincibility', 'Invincibility.unc'),
                ('Art_Ring', 'Nem_Ring', 'Ring.bin')):
            size = (ROOT / 'art/uncompressed' / source).stat().st_size
            assert symbols[label + '_End'] - symbols[label] == size, label
            assert (struct.unpack_from('>H', rom, symbols[packed])[0] & 0x7FFF) * 32 == size
            assert 0xFF0000 <= symbols[label] & 0xFFFFFF < symbols['Main_RAM_Start'] & 0xFFFFFF
        assert symbols['Player_Art_Buffer_End'] == symbols['Main_RAM_Start']
    assert symbols['code'] == 0 and symbols['height_pixels'] == 6
    assert symbols['object_size'] == 0x4E
    assert symbols['vram_hscroll'] == 0xF000
    assert symbols['ArtTile_Ring'] * 32 == 0xD720
    assert symbols['ArtTile_HUD'] == symbols['ArtTile_Sparkles'] + 4
    assert symbols['ArtTile_SS_Rings'] * 32 == 0x2940
    assert symbols['ArtTile_SS_Sparkles'] * 32 == 0x29C0

    # The Sonic monitor icon reuses the lives art, outside the monitor bank.
    monitor_frames = frames(rom, symbols['Map_Obj26'])
    assert (monitor_frames[2][0][2] + symbols['ArtTile_Monitor']) & 0x7FF == symbols['ArtTile_Lives_Counter']

    assert symbols['ArtTile_Bubbles'] * 32 == 0x8B80
    assert struct.unpack_from('>H',rom,symbols['Nem_WaterBubbles'])[0] & 0x7FFF == 56
    assert symbols['ArtTile_Sonic_Dust'] * 32 == 0xFC00
    assert symbols['ArtTile_Tails_Dust'] * 32 == 0xFE00
    # The two bubble tables share their frame data, but select separate banks
    # for the six-tile numbers. Supply their assembled frame count explicitly.
    for label,bank in [('Map_Bubbles','ArtTile_Sonic_Dust'),('Map_Bubbles2','ArtTile_Tails_Dust')]:
        bubble_frames=frames(rom,symbols[label],symbols['Map_Bubbles_frames'])
        assert len(bubble_frames)==23
        for index,row in enumerate(bubble_frames):
            for _,size,tile,_ in row:
                tile=(tile+symbols['ArtTile_Bubbles'])&0x7FF
                length=((size>>2)+1)*((size&3)+1)
                if 9<=index<19:
                    assert tile==symbols[bank] and length==6
                else:
                    assert symbols['ArtTile_Bubbles']<=tile and tile+length<=symbols['ArtTile_Bubbles']+56
    for mapping,table,art,end,capacity in [('Map_Splash','DPLC_Splash','Art_WaterSplash','Art_WaterSplash_End',16)]:
        for index,row in enumerate(frames(rom,symbols[mapping],symbols[mapping+'_frames'])):
            pointer=symbols[table]+struct.unpack_from('>h',rom,symbols[table]+index*2)[0]
            runs=struct.unpack_from('>H',rom,pointer)[0];loaded=0
            for run in range(runs):
                packed=struct.unpack_from('>H',rom,pointer+2+run*2)[0]
                length=(packed>>12)+1;loaded+=length
                assert ((packed&0xFFF)+length)*32<=symbols[end]-symbols[art]
            assert loaded<=capacity
            assert all((tile&0x7FF)+((size>>2)+1)*((size&3)+1)<=loaded for _,size,tile,_ in row)
    assert symbols['Art_AirCountdown_End']-symbols['Art_AirCountdown']==10*6*32

    points_banks = [(symbols['ArtTile_Points'] * 32, (symbols['ArtTile_Points'] + 2) * 32),
                    (symbols['ArtTile_Points_2'] * 32, (symbols['ArtTile_Points_2'] + 2) * 32)]
    assert points_banks == [(0xDE60, 0xDEA0), (0xDEA0, 0xDEE0)]
    assert symbols['ArtTile_HUD_Numbers'] + 28 == symbols['ArtTile_Points']
    assert points_banks[-1][1] <= symbols['vram_bg']

    # End-of-level bonuses replace unused monitor contents. The signpost's
    # largest DPLC and Tails's permanent life icon must survive beside them.
    bonus_first = symbols['ArtTile_Hidden_Points']
    bonus_tiles = struct.unpack_from('>H', rom, symbols['Nem_Bonus'])[0] & 0x7FFF
    bonus_end = bonus_first + bonus_tiles
    signpost_table = symbols['DPLC_Signpost']
    for frame in range(symbols['Map_Signpost_frames']):
        start = signpost_table + struct.unpack_from('>h', rom, signpost_table + frame * 2)[0]
        runs = struct.unpack_from('>H', rom, start)[0]
        loaded = sum((struct.unpack_from('>H', rom, start + 2 + run * 2)[0] >> 12) + 1
                     for run in range(runs))
        assert symbols['ArtTile_Signpost'] + loaded <= bonus_first
    assert bonus_end <= symbols['ArtTile_Tails_Life']
    for bank in ('ArtTile_SMZ_Smoke1', 'ArtTile_SMZ_Smoke2'):
        first = symbols[bank]
        assert bonus_end <= first or bonus_first >= first + 12
    for row in frames(rom, symbols['Map_Obj7D'], symbols['Map_Obj7D_frames']):
        for _, size, tile, _ in row:
            assert (tile & 0x7FF) + ((size >> 2) + 1) * ((size & 3) + 1) <= bonus_tiles

    points_frames = frames(rom, symbols['Map_Points'])
    assert len(points_frames) == symbols['Points_HiddenFrame'] + 1
    for frame, row in enumerate(points_frames):
        table = symbols['DPLC_Points']
        start = table + struct.unpack_from('>h', rom, table + (frame + symbols['Points_FrameBias']) * 2)[0]
        count = struct.unpack_from('>H', rom, start)[0]
        loaded = 0
        for i in range(count):
            run = struct.unpack_from('>H', rom, start + 2 + i * 2)[0]
            length = (run >> 12) + 1
            assert ((run & 0xFFF) + length) * 32 <= symbols['Art_Points_End'] - symbols['Art_Points']
            loaded += length
        assert loaded <= 2, ('Points bank overflow', frame, loaded)
        for _, size, tile, _ in row:
            assert (tile & 0x7FF) + ((size >> 2) + 1) * ((size & 3) + 1) <= loaded

    assert symbols['ArtTile_Shield'] == symbols['ArtTile_Invincibility']
    assert symbols['ArtTile_Shield'] * 32 == 0xF380
    effect_banks = [(symbols['ArtTile_Shield'] * 32, symbols['VRAM_Sprite_Attribute_Table']),
                    (symbols['ArtTile_Shield_2'] * 32, symbols['ArtTile_Shield_2_End'] * 32)]
    stars_size = symbols['Art_Invincibility_End'] - symbols['Art_Invincibility']
    assert effect_banks[0][0] + stars_size <= effect_banks[0][1]

    shield_frames = frames(rom, symbols['Map_obj38'])
    for frame, row in enumerate(shield_frames):
        table = symbols['DPLC_Shield']
        start = table + struct.unpack_from('>h', rom, table + (frame + symbols['PlayerEffects_ShieldFrameBias']) * 2)[0]
        count = struct.unpack_from('>H', rom, start)[0]
        loaded = 0
        for i in range(count):
            run = struct.unpack_from('>H', rom, start + 2 + i * 2)[0]
            length = (run >> 12) + 1
            assert ((run & 0xFFF) + length) * 32 <= symbols['Art_Shield_End'] - symbols['Art_Shield']
            loaded += length
        assert all(loaded * 32 <= high - low for low, high in effect_banks)
        for _, size, tile, _ in row:
            assert (tile & 0x7FF) + ((size >> 2) + 1) * ((size & 3) + 1) <= loaded

    # Level and boss PLCs must leave both effect banks intact. Game-over
    # lettering deliberately replaces the dead primary player's bank.
    act_lists = tuple(label for label in symbols
                      if re.fullmatch(r'PLC_[A-Z0-9]+[1-4]_(Main|Extra)', label))
    act_count = symbols['LevelActCount']
    assert act_count == symbols['LevelCount'] * symbols['ActsPerZone']
    assert len(act_lists) == act_count * 2
    expected_ids = None
    for table in ('LevelArtPointers', 'LevelArtPointersP', 'LevelArtPointersGF', 'LevelArtPointersBF'):
        assert symbols[table + '_End'] - symbols[table] == act_count * 12, table
        ids = [rom[symbols[table]+act*12+offset] for act in range(act_count) for offset in (0,4)]
        targets = [symbols['ArtLoadCues'] + struct.unpack_from(
            '>h', rom, symbols['ArtLoadCues']+ident*2)[0] for ident in ids]
        assert len(set(ids)) == len(set(targets)) == act_count * 2, table
        assert set(targets) == {symbols[label] for label in act_lists}, table
        assert expected_ids is None or ids == expected_ids, table
        expected_ids = ids
    assert symbols['KosMLevelCues_End'] - symbols['KosMLoadCues'] == act_count * 2
    module_targets = [symbols['KosMLoadCues'] + struct.unpack_from(
        '>h', rom, symbols['KosMLoadCues']+act*2)[0] for act in range(act_count)]
    assert len(set(module_targets)) == act_count
    for label in act_lists + ('PLC_Main', 'PLC_Main2', 'PLC_Explode', 'PLC_Boss', 'PLC_Capsule') + tuple(
            'PLC_' + zone + 'Animals' for zone in ('GHZ', 'LZ', 'CPZ', 'EHZ', 'HPZ', 'HTZ')):
        base = symbols[label]
        count = struct.unpack_from('>h', rom, base)[0] + 1
        assert 0 <= count <= 16, (label, count)
        if label.endswith('_Main'):
            assert count + symbols['ActPLC_Main_Reserve'] <= 16, (label, count)
        for i in range(count):
            source, low = struct.unpack_from('>IH', rom, base + 2 + i * 6)
            high = low + (struct.unpack_from('>H', rom, source)[0] & 0x7FFF) * 32
            assert all(high <= a or low >= b for a, b in effect_banks + points_banks), (label, hex(low), hex(high))
    for label, base in symbols.items():
        if not re.fullmatch(r'PLCKosM_[A-Z0-9]+[1-4]', label):
            continue
        count = struct.unpack_from('>h', rom, base)[0] + 1
        for i in range(count):
            source, low = struct.unpack_from('>IH', rom, base + 2 + i * 6)
            high = low + struct.unpack_from('>H', rom, source)[0]
            assert all(high <= a or low >= b for a, b in effect_banks + points_banks), (label, hex(low), hex(high))

    # The complete level explosion/animal group ends at Plane A. Read the
    # actual art headers so a future larger asset cannot spill into its neighbor.
    group_limits = {
        symbols['ArtTile_Explosion'] * 32: symbols['ArtTile_Animal_1'] * 32,
        symbols['ArtTile_Animal_1'] * 32: symbols['ArtTile_Animal_2'] * 32,
        symbols['ArtTile_Animal_2'] * 32: symbols['vram_fg'],
    }
    assert sorted(group_limits) == [0xB040, 0xBC00, 0xBE40]
    for label in ('PLC_Explode',) + tuple('PLC_' + zone + 'Animals' for zone in ('GHZ', 'LZ', 'CPZ', 'EHZ', 'HPZ', 'HTZ')):
        base = symbols[label]
        count = struct.unpack_from('>H', rom, base)[0] + 1
        for i in range(count):
            source, low = struct.unpack_from('>IH', rom, base + 2 + i * 6)
            high = low + (struct.unpack_from('>H', rom, source)[0] & 0x7FFF) * 32
            assert low in group_limits and high <= group_limits[low], (label, hex(low), hex(high))
    explosion_tiles = struct.unpack_from('>H', rom, symbols['Nem_Explosion'])[0] & 0x7FFF
    for label in ('Map_Explosion', 'Map_FExplosion'):
        for frame, row in enumerate(frames(rom, symbols[label])):
            for _, size, tile, _ in row:
                assert (tile & 0x7FF) + ((size >> 2) + 1) * ((size & 3) + 1) <= explosion_tiles, (label, frame)

    imported_frames = 0
    for mapping, dplc, regular, extra, capacity in (
        ('Map_Tails', 'TailsDynPLC', "Tails' art.bin", 'Tails extra.bin', symbols['ArtTile_Ring'] - symbols['ArtTile_Tails']),
        ('Map_Tails_Tail', 'TailsTailsDynPLC', 'Tails tails.bin', None, symbols['ArtTile_Ring'] - symbols['ArtTile_TailsTails']),
    ):
        table = symbols[dplc]
        for frame, pieces in enumerate(frames(rom, symbols[mapping])):
            start = table + struct.unpack_from('>h', rom, table + frame * 2)[0]
            count = struct.unpack_from('>H', rom, start)[0]
            art = extra if extra and frame >= symbols['Tails_ExtraFirstFrame'] else regular
            art_length = (ROOT / 'art/uncompressed' / art).stat().st_size
            loaded = 0
            for i in range(count):
                run = struct.unpack_from('>H', rom, start + 2 + i * 2)[0]
                tiles = (run >> 12) + 1
                assert ((run & 0xFFF) + tiles) * 32 <= art_length, (art, frame, run)
                loaded += tiles
            assert loaded <= capacity, (mapping, frame, loaded)
            for _, size, tile, _ in pieces:
                assert (tile & 0x7FF) + ((size >> 2) + 1) * ((size & 3) + 1) <= loaded
            imported_frames += 1

    # The carry animation activates existing Sonic poses. Validate their art
    # ranges and destination bank too, rather than merely checking frame IDs.
    carry_script = rom[symbols['AniRaw_Tails_Carry']:symbols['AniRaw_Tails_Carry'] + 256]
    assert 0xFF in carry_script, 'Unterminated carry animation'
    carry_frames = set(carry_script[:carry_script.index(0xFF)])
    sonic = frames(rom, symbols['Map_Sonic'])
    table = symbols['SonicDynPLC']
    art_length = (ROOT / "art/uncompressed/Sonic's art.unc").stat().st_size
    for frame in carry_frames:
        assert frame < len(sonic)
        start = table + struct.unpack_from('>h', rom, table + frame * 2)[0]
        count = struct.unpack_from('>H', rom, start)[0]
        loaded = 0
        for i in range(count):
            run = struct.unpack_from('>H', rom, start + 2 + i * 2)[0]
            tiles = (run >> 12) + 1
            assert ((run & 0xFFF) + tiles) * 32 <= art_length, (frame, run)
            loaded += tiles
        assert loaded <= 32, ('Sonic carry bank overflow', frame, loaded)
        for _, size, tile, _ in sonic[frame]:
            assert (tile & 0x7FF) + ((size >> 2) + 1) * ((size & 3) + 1) <= loaded

    if args.skdisasm:
        source = args.skdisasm / 'General/Sprites/Tails/Art'
        for original, remapped in (
            ('Tails.unc', "Tails' art.bin"),
            ('Tails Extra.unc', 'Tails extra.bin'),
            ('Tails tails.unc', 'Tails tails.bin'),
        ):
            pixels = (source / original).read_bytes()
            expected = bytes(TAILS_PALETTE_REMAP[b >> 4] << 4 |
                             TAILS_PALETTE_REMAP[b & 15] for b in pixels)
            assert expected == (ROOT / 'art/uncompressed' / remapped).read_bytes(), remapped
        for original,remapped in [('Dash Dust/Dash Dust.unc','Water splash.unc'),('Bubbles/Air Countdown.unc','Drowning countdown.unc')]:
            pixels=(args.skdisasm/'General/Sprites'/original).read_bytes()
            if remapped=='Water splash.unc':pixels=pixels[:98*32]
            expected=bytes(TAILS_PALETTE_REMAP[b>>4]<<4|TAILS_PALETTE_REMAP[b&15] for b in pixels)
            assert expected==(ROOT/'art/uncompressed'/remapped).read_bytes(),remapped

    print(f'{len(binaries)} ordinary binary mappings, {imported_frames} Tails frames '
          f'and {len(carry_frames)} Sonic carry frames pass.')
    print(f'{len(shield_frames)} shield DPLC frames, the shared star bank and auxiliary shield bank pass, including level/boss PLC exclusions.')
    print(f'{len(points_frames) - 1} points values fit both two-tile banks; hidden-frame and HUD/plane/PLC boundaries pass.')
    print('Explosion/fiery and all six animal PLC pairs fit the reordered $B040-$BFFF group.')
    print('Life-monitor icon, 56 resident bubble tiles and both streamed splash/countdown banks pass.')
    print('Hidden bonuses fit between all signpost DPLC frames and Tails\'s life icon, clear of both SMZ smoke banks.')
    if args.skdisasm:
        print('All three Tails art files match the palette-remapped S&K source pixels.')


if __name__ == '__main__':
    main()
