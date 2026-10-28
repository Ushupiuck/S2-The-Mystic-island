#!/usr/bin/env python3
"""Generate static art and DPLCs from the selected signpost rectangles.

Sonic and the turning frames use S3&K art. Eggman retains that game's shape
with S1's dark moustache grooves; the NA Tails portrait keeps its drawing.
Frame 6 adds Mecha Sonic's frame-0 portrait, facing right on palette line two.
The editable 40x32 source preserves the original pixels. Packed rectangles
omit transparent tiles; the board and post retain the primary palette.

Monitor contents keep their 60-tile allocation. Move the Tails portrait from
tiles 28-31 to 56-59 so the 26-tile signpost buffer cannot overwrite it.
The original Signpost.bin is the editable source for the first six frames.
"""
from pathlib import Path
import struct
from build_card_art import dplc, used, mapped, tiles
from check_sprite_assets import frames
from import_scrap_madness import nemesis_inline

ROOT = Path(__file__).resolve().parents[1]


def mapping_file(rows):
    data = bytearray(len(rows)*2)
    for i, pieces in enumerate(rows):
        struct.pack_into('>H',data,i*2,len(data))
        data += struct.pack('>H',len(pieces))
        data += b''.join(struct.pack('>bBHh',*piece) for piece in pieces)
    return data


def mecha_panel(art):
    """Blank Eggman's left panel; preserve its border, then mirror the right."""
    panel = art[36*32:48*32]
    pixels = []
    for y in range(32):
        row = []
        for x in range(24):
            byte = panel[((x//8)*4+y//8)*32+(y%8)*4+(x%8)//2]
            colour = (byte >> (4 if not x%2 else 0)) & 15
            # Use Tails's pre-fix red fill (primary slot 4). Moustache tips
            # reach the rim; retain only its neutral colours there.
            row.append(4 if x >= 3 and 3 <= y < 29 or
                       colour not in (0,1,6,7,8,9) else colour)
        # Eggman's moustache also cuts holes into the gray rim. Reconstruct
        # that straight edge, rather than retaining those silhouette notches.
        if 8 <= y < 29:
            row[:3] = [9,8,7]
        pixels.append(row)
    board_art = tiles(pixels)
    board_tiles = [board_art[i:i+32] for i in range(0,12*32,32)]
    # The inner columns share their lower three tiles. Keep those contiguous
    # and retain both top tiles, including the different centre highlight.
    board = b''.join(board_tiles[:4]+[board_tiles[8]]+board_tiles[4:8])
    head = (ROOT/'art/uncompressed/Mecha Sonic signpost.unc').read_bytes()
    assert len(head) == 20*32
    # Front-facing panels use the same post at source tiles 68-69.
    first = len(art)//32
    portrait = first+9
    # Column-major source: one back-spike tile, three rear-head/body tiles, the
    # 16x32 centre, and the 8x24 face. These four rectangles contain every
    # nontransparent pixel without splitting the portrait into single tiles.
    # Offset the profile four pixels left and two up to centre its visual
    # mass rather than the long, mostly empty back-spike bounding box.
    rectangles = [(2,1,-2,0,-24), (5,3,-10,2,-16),
                  (8,8,-18,7,-8), (17,3,-10,2,8)]
    packed = bytearray()
    pieces = []
    covered = set()
    for tile,count,y,size,x in rectangles:
        pieces.append((y,size,0x2000|(portrait+len(packed)//32),x))
        packed += head[tile*32:(tile+count)*32]
        covered.update(range(tile,tile+count))
    assert all(i in covered or not any(head[i*32:(i+1)*32]) for i in range(20))
    pieces += [(-16,3,first,-24), (-16,3,0x800|first,16),
               (-16,3,first+5,-16), (-16,3,0x800|(first+5),8),
               (-16,0,first+4,-8), (-16,0,0x800|(first+4),0),
               (-8,2,first+6,-8), (-8,2,0x800|(first+6),0),
               (16,1,68,-4)]
    return board+packed, pieces


def panel_pixels(art, pieces):
    """Indexed 48x32 panel with its per-pixel palette line retained."""
    pixels = [[(0,0) for _ in range(48)] for _ in range(32)]
    for y,size,word,x in reversed(pieces):
        width,height=((size>>2)+1)*8,((size&3)+1)*8
        for py in range(height):
            for px in range(width):
                dx,dy=x+px+24,y+py+16
                if not (0<=dx<48 and 0<=dy<32):continue
                sx=width-1-px if word&0x800 else px
                sy=height-1-py if word&0x1000 else py
                off=((word&0x7FF)+(sx//8)*(height//8)+sy//8)*32+(sy%8)*4+(sx%8)//2
                colour=(art[off]>>(4 if not sx%2 else 0))&15
                if colour:pixels[dy][dx]=(colour,word&0x6000)
    return pixels


def mixed_panel(art, eggman, character, rim, width):
    """S3&K's checkerboard double-face turn, from the actual final portraits.

    Mecha uses a narrower 24px turn so its separate palette overlay fits the
    same 26-tile buffer. Sonic/Tails retain the 32px turning silhouette.
    """
    primary,secondary=[],[]
    for y in range(32):
        row,overlay=[],[]
        for x in range(width):
            rx=x*32//width
            if rx<3 or rx>=29 or y<3 or y>=29:
                colour,palette=rim[y][rx+8]
            else:
                face=character if (x+y)&1 else eggman
                colour,palette=face[y][x*48//width]
            row.append(colour if not palette else 0)
            overlay.append(colour if palette else 0)
        primary.append(row);secondary.append(overlay)
    first=len(art)//32
    raw=bytearray(tiles(primary))
    pieces=[(-16,((width//8-1)<<2)|3,first,-width//2)]
    for col in range(width//8):
        occupied=[ty for ty in range(4) if any(secondary[y][x] for y in range(ty*8,ty*8+8) for x in range(col*8,col*8+8))]
        if not occupied:continue
        top,bottom=min(occupied),max(occupied)+1
        pieces.append((-16+top*8,bottom-top-1,0x2000|(first+len(raw)//32),-width//2+col*8))
        raw+=tiles([row[col*8:col*8+8] for row in secondary[top*8:bottom*8]])
    assert len(raw)//32+2<=26
    post=(16,1,68,-4)
    reverse=[(y,size,word^0x800,-x-((size>>2)+1)*8) for y,size,word,x in pieces]
    return bytes(raw),pieces+[post],reverse+[post]


def signpost_frames(art):
    original=frames((ROOT/'mappings/sprite/Signpost.bin').read_bytes())
    assert len(art)==70*32 and len(original)==6
    rim=panel_pixels(art,original[3])
    extra,mecha=mecha_panel(art)
    art+=extra;original.append(mecha)
    faces=[panel_pixels(art,original[i]) for i in (2,0,1,6)]
    for slot,face,width in ((3,faces[1],32),(7,faces[2],32),(9,faces[3],24)):
        raw,left,right=mixed_panel(art,faces[0],face,rim,width)
        art+=raw
        if slot==3:original[3],original[5]=left,right
        else:original.extend((left,right))
    return art,original


def main():
    art = (ROOT/'art/uncompressed/Signpost.unc').read_bytes()
    art,original=signpost_frames(art)
    (ROOT/'art/uncompressed/Signpost extra.unc').write_bytes(art[70*32:])
    dynamic, runs = [], []
    for pieces in original:
        order = sorted(used(pieces))
        lookup = {tile:i for i,tile in enumerate(order)}
        for _,size,tile,_ in pieces:
            length = ((size>>2)+1)*((size&3)+1)
            assert all(lookup[(tile&0x7FF)+i] == lookup[tile&0x7FF]+i for i in range(length))
        dynamic.append(mapped(pieces,lookup))
        runs.append(dplc(order))
    (ROOT/'mappings/sprite/Signpost DPLC.bin').write_bytes(mapping_file(dynamic))
    (ROOT/'mappings/sprite/Mecha signpost debris.bin').write_bytes(mapping_file([[piece] for piece in dynamic[6]]))
    (ROOT/'art/nemesis/Signpost.nem').write_bytes(nemesis_inline(art))
    lines = ['; Generated by build_tools/build_signpost_art.py.\nDPLC_Signpost:\n']
    lines += [f'\t\tdc.w\tDPLC_Signpost_{i}-DPLC_Signpost\n' for i in range(len(runs))]
    for i,items in enumerate(runs):
        lines.append(f'DPLC_Signpost_{i}:\tdc.w\t{len(items)}\n')
        lines.append('\t\tdc.w\t'+','.join(f'${item:04X}' for item in items)+'\n')
    lines.append('\t\teven\n')
    (ROOT/'mappings/spriteDPLC/Signpost.asm').write_text(''.join(lines))

    path = ROOT/'mappings/sprite/Monitor.bin'
    monitor = frames(path.read_bytes())
    raw_path = ROOT/'art/nemesis/Monitor and contents.unc'
    raw = raw_path.read_bytes()
    assert len(raw) == 60*32
    portrait = monitor[3][0][2] & 0x7FF
    if portrait == 28:
        raw = raw[:28*32]+raw[32*32:]+raw[28*32:32*32]
        monitor = [[(y,size,(tile&~0x7FF) | (56 if (tile&0x7FF)==28 else
                            (tile&0x7FF)-4 if 32<=tile&0x7FF<60 else tile&0x7FF),x)
                    for y,size,tile,x in pieces] for pieces in monitor]
        path.write_bytes(mapping_file(monitor))
        raw_path.write_bytes(raw)
    else:
        assert portrait == 56, 'Unexpected monitor art layout'
    (ROOT/'art/nemesis/Monitor and contents.nem').write_bytes(nemesis_inline(raw))
    maximum = max(sum((x>>12)+1 for x in r) for r in runs)
    assert maximum == 26 and maximum <= 56
    mecha_tiles = sum((x>>12)+1 for x in runs[6])
    print(f'Signpost: {len(art)//32} source tiles, {len(original)} frames, '
          f'{maximum} VRAM tiles; Mecha: {mecha_tiles} VRAM tiles; Tails portrait: monitor tiles 56-59')


if __name__ == '__main__':
    main()
