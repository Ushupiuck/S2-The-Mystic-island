#!/usr/bin/env python3
"""Verify generated initialization bounds against the final S3&K mappings."""
import argparse
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parent.parent
BOUNDS = ROOT / '_definitions/Sprite Bounds.asm'


def mapping_bounds(rom, address, frames):
    assert 0 < frames <= 256, f'Invalid mapping frame count at {address:X}'
    width = height = 0
    for frame in range(frames):
        offset = struct.unpack_from('>h', rom, address + frame * 2)[0]
        position = address + offset
        count = struct.unpack_from('>H', rom, position)[0]
        assert count < 0x8000, f'Invalid piece count at {position:X}'
        for piece in range(count):
            y, size, _, x = struct.unpack_from('>bBHh', rom, position + 2 + piece * 6)
            assert size < 16, f'Invalid sprite size at {position:X}'
            width = max(width, abs(x), abs(x + ((size >> 2) + 1) * 8))
            height = max(height, abs(y), abs(y + ((size & 3) + 1) * 8))
    assert max(width, height) <= 255, 'Display bounds must fit their SST bytes'
    return width, height, frames


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    parser.add_argument('--listing', type=Path, default=ROOT / 'main.lst')
    args = parser.parse_args()
    source = BOUNDS.read_text()
    expected = {}
    for label, dimension, value in re.findall(r'^(Map\w*)_(width|height) = \$([0-9A-F]+)$', source, re.M):
        expected.setdefault(label, {})[dimension] = int(value, 16)
    for label, value in re.findall(r'^(Map\w*)_frames = (\d+)$', source, re.M):
        expected.setdefault(label, {})['frames'] = int(value)
    symbols = {name: int(value, 16) for name, value in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', args.listing.read_text())}
    rom = args.rom.read_bytes()
    frames = 0
    for label, dimensions in expected.items():
        assert set(dimensions) == {'width', 'height', 'frames'}, f'Incomplete bounds for {label}'
        # Unused conditional references can have no mapping in this build.
        if dimensions['frames'] == 0:
            assert label not in symbols and dimensions['width'] == dimensions['height'] == 0
            continue
        width, height, count = mapping_bounds(rom, symbols[label], dimensions['frames'])
        frames += count
        assert (width, height) == (dimensions['width'], dimensions['height']), (
            f'{label}: mappings need {width}x{height} half-bounds; rebuild with build.lua')
    assert expected, 'No display bounds found'
    print(f'Checked {len(expected)} mapping bounds across {frames} frames.')


if __name__ == '__main__':
    main()
