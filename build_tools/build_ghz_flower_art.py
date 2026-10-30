#!/usr/bin/env python3
"""Regenerate the GHZ stalk and packed block definitions.

Flower .unc sources: sonicretro/s1disasm 89c0e0e06b51fd9ebac44d988e4a89bd643fd031.
The existing GHZ Flower Stalk.nem remains the authoritative static stalk source.
Heads and stalk occupy $381-$3A0, formerly the retired Ballhog ground-explosion bank.
Block .unc definitions remain authoritative for the relocated flower references.
"""
from pathlib import Path
from convert_s1_ss_background import kosinski_plus
from import_ehz2_pp_background import nemesis

ROOT = Path(__file__).resolve().parents[1]


def main():
    for name, count, frames in (
            ('GHZ Flower Large', 16, 2), ('GHZ Flower Small', 12, 3)):
        raw = (ROOT/f'art/uncompressed/{name}.unc').read_bytes()
        assert len(raw) == count*32*frames
    stalk = nemesis((ROOT/'art/nemesis/S1/GHZ Flower Stalk.nem').read_bytes())
    assert len(stalk) == 4*32
    (ROOT/'art/uncompressed/GHZ Flower Stalk.unc').write_bytes(stalk)
    blocks = ROOT/'mappings/16x16/GHZ'
    blocks.with_suffix('.kosp').write_bytes(kosinski_plus(blocks.with_suffix('.unc').read_bytes()))
    print('GHZ: two flower sources validated; four stalk tiles and packed blocks regenerated.')


if __name__ == '__main__':
    main()
