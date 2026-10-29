#!/usr/bin/env python3
"""Flatten only SMZ2's final 320px fight floor using private chunk copies.

The existing sign remains at $1EE0/$5A4. Preserve the stair approach before
$1E40, clear the raised steps inside the arena, and use existing steel block 5
for a solid floor at $5C0. No art, shared block or collision profile changes.
Run after importing SMZ geometry; repeated runs reuse identical chunk copies.
"""
from pathlib import Path
import struct
from convert_s1_ss_background import kosinski_plus, kosinski_plus_decode
from level_layout import load as load_layout, save as save_layout
ROOT=Path(__file__).resolve().parents[1]

def build():
    path=ROOT/'mappings/128x128/SMZ2.unc';raw=path.read_bytes()
    chunks=[raw[i:i+128] for i in range(0,len(raw),128)]
    primary=load_layout(ROOT/'level/layout/SMZ_2.kosp')[0]
    paths=list((ROOT/'level/layout').rglob('SMZ_2.kosp'))
    assert len(paths)==4
    for file in paths:
        layout,bg=load_layout(file)
        for cx in range(0x1E40//128,(0x1F80-1)//128+1):
            row=0x580//128;old=layout[row][cx]
            # A fresh geometry import has no previous generated tail chunks.
            if old>=len(chunks):old=primary[row][cx]
            values=list(struct.unpack('>64H',chunks[old]))
            for by in range(5):
                for bx in range(8):
                    x=cx*128+bx*16
                    if 0x1E40<=x<0x1F80:values[by*8+bx]=0 if by<4 else 0xF005
            chunk=struct.pack('>64H',*values)
            if chunk not in chunks:chunks.append(chunk)
            layout[row][cx]=chunks.index(chunk)
        assert len(chunks)<=1024
        save_layout(file,layout,bg)
    raw=b''.join(chunks);path.write_bytes(raw)
    path.with_suffix('.kosp').write_bytes(kosinski_plus(raw))
    return len(chunks)
if __name__=='__main__':print(f'SMZ2 Mecha floor: {build()} total chunks; other acts retain their original references.')
