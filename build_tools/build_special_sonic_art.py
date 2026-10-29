#!/usr/bin/env python3
"""Keep the rotating stage's five rolling poses in its unchanged slot order.

Extract only those source runs, rather than duplicating Sonic's entire atlas.
The ordinary player art remains the editable source. No stage palettes, wall,
emerald or background art are changed by the shared-level palette migration.
"""
from pathlib import Path
import struct
from check_sprite_assets import frames
from sprite_palette import PLAYER_FROM_LEGACY, remap_pixels

ROOT = Path(__file__).resolve().parents[1]


def main():
    source = (ROOT / "art/uncompressed/Sonic's art.unc").read_bytes()
    cues = (ROOT / 'mappings/spriteDPLC/Sonic DPLCs.bin').read_bytes()
    count = len(frames((ROOT / 'mappings/sprite/Sonic Mappings.bin').read_bytes()))
    inverse = [PLAYER_FROM_LEGACY.index(i) for i in range(16)]
    raw, rows, runs_by_data = bytearray(), [], {}
    for frame in range(count):
        runs = []
        if 0x3D <= frame <= 0x41:
            start = struct.unpack_from('>h', cues, frame*2)[0]
            n = struct.unpack_from('>H', cues, start)[0]
            for j in range(n):
                w = struct.unpack_from('>H', cues, start+2+j*2)[0]
                length = (w >> 12)+1
                pixels = remap_pixels(source[(w & 4095)*32:((w & 4095)+length)*32], inverse)
                if pixels not in runs_by_data:
                    runs_by_data[pixels] = len(raw)//32
                    raw += pixels
                runs.append(((length-1) << 12) | runs_by_data[pixels])
        rows.append(struct.pack('>H', len(runs)) + b''.join(struct.pack('>H', w) for w in runs))
    data = bytearray(count*2)
    shared = {}
    for frame, row in enumerate(rows):
        if row not in shared:
            shared[row] = len(data)
            data += row
        struct.pack_into('>H', data, frame*2, shared[row])
    (ROOT / 'art/uncompressed/Special stage Sonic.unc').write_bytes(raw)
    (ROOT / 'mappings/spriteDPLC/Special stage Sonic.bin').write_bytes(data)
    print(f'Rotating stage: five unchanged rolling poses, {len(raw)//32} source tiles.')


if __name__ == '__main__':
    main()
