#!/usr/bin/env python3
"""Import Sonic's seven FBZ hanging poses from the pinned skdisasm checkout.

Existing Sonic frames retain their byte IDs. While hanging, a small separate
mapping/DPLC set streams into the ordinary Sonic bank; Tails already has these
S3&K frames. The output raw art and mapping ASM remain directly editable.
"""
import argparse
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
REVISION = '73de97c6b55055bcb8089c1d55d006b02136f163'
POSES = (0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x91)
REMAP = (0, 6, 5, 3, 2, 4, 12, 13, 14, 15, 10, 11, 7, 8, 9, 1)


def records(path):
    text = path.read_text()
    base = text.split(':')[0]
    labels = re.findall(r'dc.w\s+(\w+)-' + base, text)
    bodies = dict(re.findall(r'^(\w+):([^:]*?)(?=^\w+:|\Z)', text, re.M | re.S))
    result = []
    for index, label in enumerate(labels):
        if index not in POSES:
            result.append(b'')
            continue
        data = bytearray()
        for size, values in re.findall(r'dc\.([bw])\s+([^;\n]+)', bodies[label]):
            for value in values.split(','):
                value = value.strip()
                n = int(value[1:], 16) if value.startswith('$') else int(value)
                data.extend(n.to_bytes(1 if size == 'b' else 2, 'big'))
        result.append(bytes(data))
    return result


def emit(label, rows, pieces=False):
    lines = ['; Imported from skdisasm ' + REVISION + '.', label + ':']
    lines += ['\t\tdc.w .pose%d-%s' % (i, label) for i in range(len(rows))]
    for i, row in enumerate(rows):
        lines += ['.pose%d:\tdc.w %d\t; S3&K frame $%02X' % (i, int.from_bytes(row[:2], 'big'), POSES[i])]
        stride = 6 if pieces else 2
        for j in range(2, len(row), stride):
            if pieces:
                lines.append('\t\tdc.b ' + ','.join('$%02X' % b for b in row[j:j+6]))
            else:
                lines.append('\t\tdc.w $%04X' % int.from_bytes(row[j:j+2], 'big'))
    return '\n'.join(lines) + '\n'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    args = p.parse_args()
    source = args.source / 'General/Sprites/Sonic'
    maps = records(source / 'Map - Sonic.asm')
    cues = records(source / 'DPLC - Sonic.asm')
    art = (source / 'Art/Sonic.unc').read_bytes()
    output = bytearray()
    out_cues = []
    for frame in POSES:
        row = cues[frame]
        runs = []
        for i in range(int.from_bytes(row[:2], 'big')):
            run = int.from_bytes(row[2+i*2:4+i*2], 'big')
            count = (run >> 12) + 1
            data = art[(run & 4095)*32:((run & 4095)+count)*32]
            assert len(data) == count * 32
            runs.append(struct.pack('>H', ((count-1) << 12) | (len(output)//32)))
            output.extend((REMAP[b >> 4] << 4) | REMAP[b & 15] for b in data)
        out_cues.append(struct.pack('>H', len(runs)) + b''.join(runs))
    (ROOT / 'art/uncompressed/Sonic hanging.unc').write_bytes(output)
    (ROOT / 'mappings/sprite/Sonic hanging.asm').write_text(emit('Map_HangingSonic', [maps[f] for f in POSES], True))
    (ROOT / 'mappings/spriteDPLC/Sonic hanging.asm').write_text(emit('DPLC_HangingSonic', out_cues))
    print('Imported seven Sonic hanging poses, %d tiles; existing frame IDs unchanged.' % (len(output)//32))


if __name__ == '__main__':
    main()
