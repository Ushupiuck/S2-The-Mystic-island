#!/usr/bin/env python3
"""Pack the S1 card font into per-screen DPLCs and generate their mappings.

The original 128-tile sheet is the authoritative source for existing pixels,
including K and U. V/W retain its serif proportions, palette and drop shadow;
zero shares O's shape. ACT 4 follows the original 16x24 orange digits.
No decompression buffer is required: DPLCs read the raw art directly from ROM.
"""
from pathlib import Path
import json
from import_scrap_madness import nemesis_inline

ROOT = Path(__file__).resolve().parents[1]
NAMES = ('TWILIGHT HILL', 'RUSTIC RUINS', 'ANCIENT WORKBENCH',
         'EMERALD HILL', 'CRYSTAL VALLEY', 'EGG MOUNTAIN', 'METROPOLIS',
         'SHOCKING BLIZZARD', 'SCRAP MADNESS', 'DEATH EGG',
         'LEVEL 0A', 'LEVEL 0B', 'LEVEL 0C', 'LEVEL 0D', 'LEVEL 0E', 'LEVEL 0F')
GLYPHS = dict(zip('ABCDEFGHIKLMNOPRSTUYZ',
                  (0, 4, 8, 12, 16, 20, 24, 28, 32, 34, 38, 42, 46,
                   50, 54, 58, 62, 66, 70, 74, 78)))
GLYPHS.update(V=128, W=132)
GLYPHS['0'] = GLYPHS['O']
OVAL = [(-28, 12, 0x70, -12), (-28, 2, 0x74, 20),
        (-20, 4, 0x77, -20), (-12, 5, 0x79, -28),
        (20, 12, 0x1870, -20), (4, 2, 0x1874, -28),
        (12, 4, 0x1877, 4), (-4, 5, 0x1879, 12),
        (-20, 8, 0x7D, -4), (-12, 12, 0x7C, -12),
        (-4, 8, 0x7C, -12), (4, 12, 0x7C, -20),
        (12, 8, 0x7C, -20)]
ACT = (0x8E, 0x5A, 0x60, 0x88)  # 1 padded to six tiles; 2/3; new 4


def tiles(pixels):
    h, w = len(pixels), len(pixels[0])
    assert not w % 8 and not h % 8
    return bytes((pixels[ty+y][tx+x] << 4) | pixels[ty+y][tx+x+1]
                 for tx in range(0, w, 8) for ty in range(0, h, 8)
                 for y in range(8) for x in range(0, 8, 2))


def serif(points):
    """Rasterize a 15-pixel cap with the original white/gray/black slots."""
    def inside(x, y):
        hit = False
        for (ax, ay), (bx, by) in zip(points, points[1:]+points[:1]):
            if (ay > y) != (by > y) and x < (bx-ax)*(y-ay)/(by-ay)+ax:
                hit = not hit
        return hit
    body = [[0]*16 for _ in range(16)]
    for y in range(15):
        for x in range(15):
            n = sum(inside(x+(sx+.5)/4, y+(sy+.5)/4)
                    for sy in range(4) for sx in range(4))
            body[y][x] = 6 if n >= 12 else 8 if n >= 6 else 7 if n >= 2 else 0
    out = [[0]*16 for _ in range(16)]
    for y in range(15):
        for x in range(15):
            if body[y][x]:
                out[y+1][x+1] = 1
    for y in range(16):
        for x in range(16):
            if body[y][x]:
                out[y][x] = body[y][x]
    return tiles(out)


def act_four():
    body = [[False]*16 for _ in range(24)]
    for y in range(23):
        for x in range(15):
            body[y][x] = (9 <= x <= 12 or 13 <= y <= 16 or
                          y < 14 and 8-y//2 <= x <= 11-y//2)
    out = [[0]*16 for _ in range(24)]
    for y in range(23):
        for x in range(15):
            if body[y][x]:
                out[y+1][x+1] = 1
    for y in range(24):
        for x in range(16):
            if body[y][x]:
                out[y][x] = 15
    return tiles(out)


def count(size):
    return ((size >> 2)+1)*((size & 3)+1)


def used(pieces):
    return {t for _, size, word, _ in pieces
            for t in range(word & 0x7FF, (word & 0x7FF)+count(size))}


def lettering(text, space=12, x=None):
    width = sum(space if c == ' ' else 8 if c == 'I' else 16 for c in text)
    x = -width//2 if x is None else x
    out = []
    for c in text:
        if c != ' ':
            out.append((-8, 1 if c == 'I' else 5, GLYPHS[c], x))
        x += space if c == ' ' else 8 if c == 'I' else 16
    return out


def pack(prefix, pieces):
    order = list(prefix) + sorted(used(pieces)-set(prefix))
    assert len(order) == len(set(order))
    lookup = {t: i for i, t in enumerate(order)}
    # Every original sprite rectangle must still be one contiguous tile run.
    for _, size, word, _ in pieces:
        first = word & 0x7FF
        assert all(lookup[first+i] == lookup[first]+i for i in range(count(size)))
    return order, lookup


def dplc(order):
    runs = []
    for tile in order:
        if runs and tile == runs[-1][0]+runs[-1][1] and runs[-1][1] < 16:
            runs[-1][1] += 1
        else:
            runs.append([tile, 1])
    return tuple(((n-1) << 12) | tile for tile, n in runs)


def mapped(pieces, lookup):
    return [(y, size, (word & ~0x7FF) | lookup[word & 0x7FF], x)
            for y, size, word, x in pieces]


def row(y, size, word, x):
    return y, size, word, x


def emit_table(label, frames, description=''):
    lines = [f'{label}: ; {description}']
    for i in range(len(frames)):
        lines.append(f'\t\tdc.w {label}_{i}-{label}')
    for i, pieces in enumerate(frames):
        lines.append(f'{label}_{i}: dc.w {len(pieces)}')
        for y, size, word, x in pieces:
            word = f'${word:X}' if isinstance(word, int) else word
            lines.append(f'\t\tdc.w ${((y & 255) << 8) | size:04X}, {word}, ${x & 65535:04X}')
    return '\n'.join(lines)+'\n\t\teven\n'


def main():
    raw = bytearray((ROOT/'art/uncompressed/Title Cards Base.unc').read_bytes())
    assert len(raw) == 128*32
    raw += serif([(0,0),(6,0),(6,1),(5,1),(9,11),(13,1),(11,1),
                  (11,0),(15,0),(15,1),(14,1),(9,15),(7,15),(2,1),(0,1)])
    raw += serif([(0,0),(5,0),(5,1),(4,1),(6,10),(8,4),(7,1),(6,1),
                  (6,0),(11,0),(11,1),(10,1),(12,10),(14,1),(12,1),
                  (12,0),(15,0),(15,1),(12,15),(10,15),(8,8),(6,15),
                  (4,15),(1,1),(0,1)])
    raw += act_four()
    raw += raw[0x57*32:0x5A*32] + bytes(3*32)
    assert len(raw) == 148*32
    (ROOT/'art/uncompressed/Card Font.unc').write_bytes(raw)

    scenes = []
    intro_common = sorted(used(OVAL+lettering('ZONE')+[row(4,12,0x53,-20)]))
    intro_frames = []
    intro_lookups = []
    for zone, name in enumerate(NAMES):
        text = lettering(name)
        for act in range(4):
            prefix = intro_common + list(range(ACT[act], ACT[act]+6))
            order, lookup = pack(prefix, text)
            scenes.append((f'{name} ACT {act+1}', order))
            if act == 0:
                intro_frames.append(mapped(text, lookup))
                intro_lookups.append(lookup)
    common = intro_lookups[0]
    intro_frames.append(mapped(lettering('ZONE', x=-32), common))
    digit_slot = len(intro_common)
    for act in range(4):
        intro_frames.append(mapped([row(4,12,0x53,-20)], common)+
                            [row(-12,2 if act == 0 else 6,digit_slot,12 if act == 0 else 8)])
    intro_frames.append(mapped(OVAL, common))
    header = '; Generated by build_tools/build_card_art.py. Do not hand-edit.\n'
    (ROOT/'mappings/sprite/Title_Cards.asm').write_text(
        header+emit_table('Map_Cards', intro_frames, '16 names, ZONE, ACT 1-4, oval'))

    result_constants = '''; HUD and dynamic bonus references are relative to the current card bank.
Map_Results_ScoreLetters = ArtTile_HUD-ArtTile_Title_Card
Map_Results_TimeLetters = ArtTile_HUD+8-ArtTile_Title_Card
Map_Results_ScoreE = ArtTile_HUD_E-ArtTile_Title_Card
Map_Results_ScoreDigits = ArtTile_HUD_Numbers-ArtTile_Title_Card
Map_Results_Zero = ArtTile_HUD_Numbers+$C-ArtTile_Title_Card
Map_Results_TimeDigits = ArtTile_Bonuses-ArtTile_Title_Card
Map_Results_RingDigits = ArtTile_Bonuses+8-ArtTile_Title_Card
Map_Results_RingTile = make_art_tile(ArtTile_Ring,1,0)-ArtTile_Title_Card
Map_SSResults_RingTile = ArtTile_SS_Rings-ArtTile_Title_Card
Map_Results_ContinueText = ArtTile_Mini_Sonic-ArtTile_Title_Card
'''

    def fixed(lookup, special=False, tails=False):
        score = [row(-8,13,'Map_Results_ScoreLetters',-80),
                 row(-8,1,'Map_Results_ScoreE',-48),
                 row(-8,9,'Map_Results_ScoreDigits',24),
                 row(-8,13,'Map_Results_ScoreDigits+6',48),
                 row(-9,4,lookup[0x6E],-51), row(-1,4,lookup[0x6E] | 0x1800,-51)]
        def bonus(time):
            icon = (row(-8,13,'Map_Results_TimeLetters',-80) if time else
                    row(-8,5,'Map_SSResults_RingTile' if special else 'Map_Results_RingTile',-64))
            return [icon, row(-8,13,lookup[0x66],-39),
                    row(-8,1,'Map_Results_ScoreLetters',-7),
                    row(-9,4,lookup[0x6E],-10), row(-1,4,lookup[0x6E] | 0x1800,-10),
                    row(-8,13,'Map_Results_TimeDigits' if time else 'Map_Results_RingDigits',40),
                    row(-8,1,'Map_Results_Zero',72)]
        return score, bonus

    normal_common = sorted(used(OVAL+[row(4,12,0x53,-20),
                                      row(-8,13,0x66,0),row(-9,4,0x6E,0)]))
    normal_output = [header, result_constants]
    for act in range(4):
        for tails in (False, True):
            name = 'TAILS HAS' if tails else 'SONIC HAS'
            text = lettering(name, space=16, x=-72)+lettering('PASSED')
            order, lookup = pack(normal_common+list(range(ACT[act],ACT[act]+6)),text)
            scenes.append((name+f' PASSED ACT {act+1}',order))
            if act:
                continue  # All four acts use the same six-tile digit destination.
            score, bonus = fixed(lookup)
            frames = [mapped(lettering(name,space=16,x=-72),lookup),
                      mapped(lettering('PASSED'),lookup),score,bonus(True),bonus(False),
                      mapped(OVAL,lookup)]
            for a in range(4):
                frames.append(mapped([row(4,12,0x53,-20)],lookup)+
                              [row(-12,2 if a == 0 else 6,len(normal_common),12 if a == 0 else 8)])
            normal_output.append(emit_table('Map_Got_Tails' if tails else 'Map_Obj3A',frames,name))
    (ROOT/'mappings/sprite/Got_Through.asm').write_text(''.join(normal_output))

    special_common = sorted(used(OVAL+[row(-8,13,0x66,0),row(-9,4,0x6E,0)]))
    special_output = [header]
    for state in range(3):
        for tails in (False,True):
            name = ('SPECIAL STAGE','CHAOS EMERALDS',
                    ('TAILS' if tails else 'SONIC')+' GOT THEM ALL')[state]
            text = lettering(name,space=8)
            order, lookup = pack(special_common,text)
            scenes.append((name,order))
            score, bonus = fixed(lookup,special=True,tails=tails)
            mini = 'ArtTile_Mini_Tails' if tails else 'ArtTile_Mini_Sonic+18'
            continues = [row(-8,13,'Map_Results_ContinueText',-80),
                         row(-8,13,'Map_Results_ContinueText+8',-48),
                         row(-8,1,'Map_Results_ContinueText+16',-16)]
            frames = [mapped(text,lookup),score,bonus(False),mapped(OVAL,lookup),
                      continues+[row(-8,6,f'make_art_tile({mini},1,0)-ArtTile_Title_Card',64)],
                      continues+[row(-8,6,f'make_art_tile({mini}+6,1,0)-ArtTile_Title_Card',64)],
                      continues]
            special_output.append(emit_table(f'Map_SSR_{state}_{int(tails)}',frames,name))
    special_output.append('Card_SS_MapPointers:\n')
    for state in range(3):
        for tails in (False,True):
            special_output.append(f'\t\tdc.l Map_SSR_{state}_{int(tails)}\n')
    (ROOT/'mappings/sprite/SSResults.asm').write_text(''.join(special_output))

    assert len(scenes) == 78
    lines = [header,'DPLC_Cards:\n']
    unique = {}
    for i,(name,order) in enumerate(scenes):
        key=dplc(order)
        unique.setdefault(key,i)
        lines.append(f'\t\tdc.w DPLC_Card_{unique[key]}-DPLC_Cards ; {name}\n')
    for runs,i in unique.items():
        lines.append(f'DPLC_Card_{i}: dc.w {len(runs)}\n')
        lines.append('\t\tdc.w '+','.join(f'${run:04X}' for run in runs)+'\n')
    lines.append('\t\teven\n')
    (ROOT/'mappings/spriteDPLC/Cards.asm').write_text(''.join(lines))
    life_text = (ROOT/'art/uncompressed/Tails Life Text Source.unc').read_bytes()
    assert len(life_text) == 8*32
    (ROOT/'art/nemesis/Tails Life Text.nem').write_bytes(nemesis_inline(life_text))
    report={'font_source_tiles':len(raw)//32,'intro_max_tiles':max(len(x[1]) for x in scenes[:64]),
            'normal_result_tiles':[len(x[1]) for x in scenes[64:72]],
            'special_result_tiles':[len(x[1]) for x in scenes[72:]],
            'scenes':[{'name':name,'tiles':len(order),'runs':len(dplc(order))} for name,order in scenes]}
    assert max(len(order) for _,order in scenes) <= 127
    print(json.dumps({k:v for k,v in report.items() if k!='scenes'},indent=2))
    return report


if __name__ == '__main__':
    main()
