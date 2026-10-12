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


def frames(data, base=0):
    count = struct.unpack_from('>H', data, base)[0] // 2
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
        (ROOT / 'main.lst').read_text())}
    assert symbols['height_pixels'] == 0x49 and symbols['object_size'] == 0x4A
    assert symbols['vram_hscroll'] == 0xF000
    assert symbols['ArtTile_Ring'] * 32 == 0xD780
    assert symbols['ArtTile_SS_Rings'] * 32 == 0xF600

    imported_frames = 0
    for mapping, dplc, regular, extra, capacity in (
        ('Map_Tails', 'TailsDynPLC', "Tails' art.bin", 'Tails extra.bin', 28),
        ('Map_Tails_Tail', 'TailsTailsDynPLC', 'Tails tails.bin', None, 12),
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

    print(f'{len(binaries)} ordinary binary mappings and {imported_frames} Tails frames pass.')
    if args.skdisasm:
        print('All three Tails art files match the palette-remapped S&K source pixels.')


if __name__ == '__main__':
    main()
