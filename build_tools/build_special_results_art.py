#!/usr/bin/env python3
"""Build the results screen's own palette, emeralds and continue sprites.

The rotating stage keeps every original palette and asset. Results use a dark
blue backdrop, the shared player row, aligned gold/gray UI colors and two rows
of independent emerald ramps. The original results emerald sheet is the pixel
source; each color now owns four tiles instead of sharing incompatible slots.
"""
from pathlib import Path
import struct
from import_ehz2_pp_background import nemesis
from import_scrap_madness import nemesis_compress
from build_end_art import pack_moduled
from build_signpost_art import mapping_file
from build_hud_art import lettering
from convert_s1_ss_background import kosinski_plus_decode
from sprite_palette import remap_pixels

ROOT = Path(__file__).resolve().parents[1]


def main():
    player = list(struct.unpack('>16H', (ROOT/'palette/SonicAndTails.bin').read_bytes()))
    player[0] = 0x200
    ui = player.copy()
    ui[13:16] = [0x0EE, 0x088, 0x044]
    gems = [[0x200, 0x222, 0, 0, 0, 0, 0xEEE, 0xECC] + [0]*8 for _ in range(2)]
    # Source tile, source colors dark -> light, four authored destination shades.
    colors = (
        (4, (2,3,4,5,6), (0x822,0xC42,0xE66,0xEAA)),
        (0, (10,11,12,13,14), (0x044,0x088,0x0CC,0x4EE)),
        (4, (2,3,4,5,6), (0x404,0x808,0xC4C,0xEAE)),
        (4, (2,3,4,5,6), (0x040,0x080,0x0C6,0x8EA)),
        (8, (14,13,12,11,6), (0x004,0x008,0x00E,0x88E)),
        (12, (9,8,7,6), (0x444,0x888,0xAAA,0xECC)),
    )
    original = nemesis((ROOT/'art/Bonus & Special Stage/Bonus Stage Result Emeralds.nem').read_bytes())
    raw, rows = bytearray(), []
    for i, (tile, indices, ramp) in enumerate(colors):
        line, slots = i//3, ((2,3,4,5),(8,9,10,11),(12,13,14,15))[i%3]
        for slot, value in zip(slots, ramp):
            gems[line][slot] = value
        lookup = [0]*16
        for old, new in zip(indices[:-1], slots):
            lookup[old] = new
        lookup[indices[-1]] = 6
        raw += remap_pixels(original[tile*32:(tile+4)*32], lookup)
        rows.append([(-8, 5, ((line+2)<<13) | i*4, -8)])
    rows.append([])
    (ROOT/'palette/Special Stage Results.bin').write_bytes(struct.pack('>64H',*(player+ui+gems[0]+gems[1])))
    (ROOT/'art/uncompressed/Results emeralds.unc').write_bytes(raw)
    (ROOT/'art/nemesis/Results emeralds.nem').write_bytes(nemesis_compress(raw))
    (ROOT/'mappings/sprite/SSR Emeralds.bin').write_bytes(mapping_file(rows))
    # Retain both original 16x24 continue poses. These older S2 banks use four
    # blue shades and the original orange slots, not today's shared indices.
    continue_from_s2 = (0,1,12,11,10,10,6,7,8,9,5,2,13,14,4,3)
    def poses(filename, skip=0):
        packed = (ROOT/f'art/moduled kosinski/{filename}.kospm').read_bytes()
        raw = kosinski_plus_decode(packed[2:])[0][skip*32:]
        assert len(raw) == 12*32
        return remap_pixels(raw,continue_from_s2)
    sonic = poses('Mini Sonic Continue',18)
    tails = poses('Mini Tails continue')
    text = lettering('CONTINUE',width=72)
    for name, data in (('Sonic',text+sonic),('Tails',tails)):
        (ROOT/f'art/uncompressed/Results continue {name}.unc').write_bytes(data)
        (ROOT/f'art/moduled kosinski/Results continue {name}.kospm').write_bytes(pack_moduled(data))
    # Both game/results ring copies now use aligned gold on the second line.
    (ROOT/'art/uncompressed/SS Results Ring.bin').write_bytes((ROOT/'art/uncompressed/Ring.bin').read_bytes())
    print('Independent results: navy/white/gold UI, six four-tile emeralds, original animated continue sprites.')


if __name__ == '__main__':
    main()
