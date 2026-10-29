#!/usr/bin/env python3
"""Build gameplay labels/counters from the shared Ristar CONTINUE font.

Keep the existing 8x16 glyph cells and VRAM layout. Life portraits, names and
their separate digit source are deliberately independent of this generator.
"""
from pathlib import Path
from build_card_art import tiles
from import_scrap_madness import nemesis_compress

ROOT = Path(__file__).resolve().parents[1]


def lettering(text, ink=6, shadow=False, width=None):
    font = (ROOT/'art/uncompressed/Level select and Debug Mode text.bin').read_bytes()
    pixels = [[0]*(width or len(text)*8) for _ in range(16)]
    for column, char in enumerate(text):
        if char == ' ':
            continue
        if char == ':':
            # The menu font has no colon (tile 10 is '$'). Match its stroke
            # weight with two square dots inside the same eight-pixel cell.
            rows = (0,0,0x18,0x18,0,0x18,0x18,0)
            glyph = bytes(((15 if row & (0x80 >> x) else 0) << 4) |
                          (15 if row & (0x40 >> x) else 0)
                          for row in rows for x in range(0,8,2))
        else:
            index = ord(char)-ord('0') if char.isdigit() else ord(char)-ord('A')+17
            glyph = font[index*32:(index+1)*32]
        assert len(glyph) == 32, char
        for y in range(8):
            for x in range(8):
                value = glyph[y*4+x//2] >> (0 if x&1 else 4) & 15
                assert value in (0,15)
                if value:
                    px, py = column*8+x, y+4
                    if shadow and px+1 < len(pixels[0]):
                        pixels[py+1][px+1] = 1
                    pixels[py][px] = ink
    return tiles(pixels)


def main():
    labels = lettering('SCOR',13,True)+lettering('TIME',13,True)
    digits = b''.join(lettering(c,6,True) for c in '0123456789:')
    assert len(labels) == 16*32 and len(digits) == 22*32
    (ROOT/'art/nemesis/HUD.nem').write_bytes(nemesis_compress(labels))
    (ROOT/'art/uncompressed/HUD Numbers.bin').write_bytes(digits)
    # Results reuse SCORE's first letter for BONUS's final S.
    (ROOT/'art/uncompressed/SS Results Labels.unc').write_bytes(
        lettering('SCORE',13,True)+lettering('BONU',13,True))
    print('HUD labels and score/time/ring/bonus digits use the CONTINUE font; life HUD retained.')


if __name__ == '__main__':
    main()
