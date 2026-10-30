#!/usr/bin/env python3
"""Extract compact rolling body/tail art in the shared S1 stage palette.

Ordinary character sources remain editable. Sonic keeps his original five
poses; Tails uses three rolling body poses and sixteen directional tail poses.
This generator changes no stage wall, emerald, background or palette data.
"""
from pathlib import Path
import re
import struct
from sprite_palette import PLAYER_FROM_LEGACY, PLAYER_TO_S1_STAGE_TAILS, remap_pixels

ROOT = Path(__file__).resolve().parents[1]


def binary_cues(data):
    count = struct.unpack_from('>H',data)[0]//2
    rows = []
    for frame in range(count):
        start = struct.unpack_from('>H',data,frame*2)[0]
        n = struct.unpack_from('>H',data,start)[0]
        rows.append(list(struct.unpack_from('>'+str(n)+'H',data,start+2)))
    return rows


def asm_cues(path):
    """Read the retained AS word-count/run tables, without requiring a ROM."""
    order, labels, current = [], {}, None
    for line in path.read_text().splitlines():
        line = line.split(';')[0].strip()
        if not line:
            continue
        if ':' in line:
            current, line = line.split(':',1)
            labels[current] = []
        match = re.search(r'\bdc\.w\s+(.+)',line)
        if not match:
            continue
        for value in match[1].split(','):
            value = value.strip()
            if '-' in value:
                order.append(value.split('-')[0])
            else:
                labels[current].append(int(value[1:],16) if value.startswith('$') else int(value))
    rows = []
    for label in order:
        n,*words = labels[label]
        assert n == len(words),label
        rows.append(words)
    return rows


def compact(source, cues, selected, lookup):
    raw, rows, runs_by_data = bytearray(), [], {}
    for frame, cue in enumerate(cues):
        runs = []
        if frame in selected:
            for w in cue:
                length = (w >> 12)+1
                pixels = remap_pixels(source[(w&4095)*32:((w&4095)+length)*32],lookup)
                assert len(pixels) == length*32
                if pixels not in runs_by_data:
                    runs_by_data[pixels] = len(raw)//32
                    raw += pixels
                runs.append(((length-1)<<12)|runs_by_data[pixels])
        rows.append(struct.pack('>H',len(runs))+b''.join(struct.pack('>H',w) for w in runs))
    data, shared = bytearray(len(rows)*2), {}
    for frame,row in enumerate(rows):
        if row not in shared:
            shared[row] = len(data)
            data += row
        struct.pack_into('>H',data,frame*2,shared[row])
    return bytes(raw),bytes(data)


def main():
    inverse = [PLAYER_FROM_LEGACY.index(i) for i in range(16)]
    banks = (
        ('Sonic',"Sonic's art.unc",binary_cues((ROOT/'mappings/spriteDPLC/Sonic DPLCs.bin').read_bytes()),range(0x3D,0x42),inverse),
        ('Tails',"Tails' art.bin",asm_cues(ROOT/'mappings/spriteDPLC/Tails.asm'),range(0x96,0x99),PLAYER_TO_S1_STAGE_TAILS),
        ('Tails tails','Tails tails.bin',asm_cues(ROOT/'mappings/spriteDPLC/Tails tails.asm'),range(5,0x15),PLAYER_TO_S1_STAGE_TAILS),
    )
    for name,filename,cues,selected,lookup in banks:
        raw,table = compact((ROOT/'art/uncompressed'/filename).read_bytes(),cues,selected,lookup)
        (ROOT/f'art/uncompressed/Special stage {name}.unc').write_bytes(raw)
        (ROOT/f'mappings/spriteDPLC/Special stage {name}.bin').write_bytes(table)
        print(f'Rotating stage {name}: {len(selected)} poses, {len(raw)//32} source tiles.')


if __name__ == '__main__':
    main()
