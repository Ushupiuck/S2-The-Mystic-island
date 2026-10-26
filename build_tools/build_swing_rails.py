#!/usr/bin/env python3
"""Build ICZ-style rail mappings from each zone's existing platform/link tiles.

No art/VRAM allocation: the upright rail reuses one chain-link sprite beside
its platform. Source mappings remain independently editable and unchanged.
"""
from pathlib import Path
import struct
from check_sprite_assets import frames

ROOT = Path(__file__).resolve().parents[1]
CONFIGS = (
    ('Swinging platform.bin', 'Swinging platform rail.bin', 16, -16),
    ('SLZ Swinging Platform.bin', 'SLZ Swinging Platform rail.bin', 24, -24),
    ('SMZ Swing.bin', 'SMZ Swing rail.bin', 16, -32),
)


def generate():
    result = {}
    for source, output, rail_x, rail_y in CONFIGS:
        original = frames((ROOT / 'mappings/sprite' / source).read_bytes())
        rail = [(y + rail_y, size, tile, x + rail_x)
                for y, size, tile, x in original[1]]
        body = original[0] + rail
        data = struct.pack('>HH', 2, len(body))
        data += b''.join(struct.pack('>bBHh', *piece) for piece in body)
        result[ROOT / 'mappings/sprite' / output] = data
    return result


if __name__ == '__main__':
    for path, data in generate().items():
        path.write_bytes(data)
        print(path.relative_to(ROOT))
