#!/usr/bin/env python3
"""Import the complete standard Sky Sanctuary Mecha fight's indexed assets.

Source: skdisasm 73de97c6b55055bcb8089c1d55d006b02136f163.
Raw art/mapping outputs remain directly editable. The distinct Master Emerald
rematch is not selected by this standard-fight import.
"""
from pathlib import Path
import argparse,re,struct
from build_signpost_art import mapping_file
from import_scrap_madness import nemesis_inline
ROOT=Path(__file__).resolve().parents[1]

def blocks(path):
    result={};name=None
    for raw in path.read_text().splitlines():
        line=raw.split(';')[0].strip()
        if not line:continue
        m=re.match(r'(\w+):\s*(.*)',line)
        if m:name=m[1];result[name]=[];line=m[2]
        if line:result[name].append(line)
    return result

def num(s):return int(s.strip().replace('$','0x'),0)

def maps(path):
    b=blocks(path);root=next(iter(b));out=[]
    for line in b[root]:
        ref=re.match(r'dc.w\s+(\w+)-',line)[1];lines=b[ref]
        n=num(lines[0].split(None,1)[1]);data=[]
        for line in lines[1:]:data.extend(num(v)&255 for v in line.split(None,1)[1].split(','))
        assert len(data)==n*6
        out.append([struct.unpack('>bBHh',bytes(data[i:i+6])) for i in range(0,len(data),6)])
    return out

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--extra-raw',type=Path,required=True);a=p.parse_args()
    src=a.source/'General/Sprites/Mecha Sonic'
    art=(src/'Mecha Sonic.unc').read_bytes();(ROOT/'art/uncompressed/Mecha Sonic.unc').write_bytes(art)
    rows=maps(src/'Map - Mecha Sonic.asm');assert len(rows)==22
    (ROOT/'mappings/sprite/Mecha Sonic.bin').write_bytes(mapping_file(rows))
    effects=maps(src/'Map - Mecha Sonic Extra.asm')[:8]
    (ROOT/'mappings/sprite/Mecha Sonic effects.bin').write_bytes(mapping_file(effects))
    extra=a.extra_raw.read_bytes()[:22*32];assert len(extra)==22*32
    (ROOT/'art/uncompressed/Mecha Sonic effects.unc').write_bytes(extra)
    (ROOT/'art/nemesis/Mecha Sonic effects.nem').write_bytes(nemesis_inline(extra))
    b=blocks(src/'DPLC - Mecha Sonic.asm');base=next(iter(b));runs=[]
    for line in b[base]:
        ref=re.match(r'dc.w\s+(\w+)-',line)[1];v=[num(x.split(None,1)[1]) for x in b[ref]]
        assert len(v)==v[0]+2
        runs.append([((w&15)<<12)|(w>>4) for w in v[1:]])
    text=['; Standard Mecha fight DPLCs, converted from the pinned skdisasm source.\nDPLC_MechaSonic:\n']
    for i in range(len(runs)):text.append(f'\tdc.w .frame{i:02X}-DPLC_MechaSonic\n')
    for i,run in enumerate(runs):text.append(f'.frame{i:02X}:\tdc.w {len(run)}\n\tdc.w '+','.join(f'${w:04X}' for w in run)+'\n')
    (ROOT/'mappings/spriteDPLC/Mecha Sonic.asm').write_text(''.join(text)+'\teven\n')
    for name in ('Flash 1','Flash 2'):(ROOT/f'palette/Mecha Sonic {name}.bin').write_bytes((src/f'Palettes/{name}.bin').read_bytes())
    (ROOT/'palette/Mecha Sonic.bin').write_bytes((src/'Palettes/Main.bin').read_bytes())
    for short,file,prefix in [('Land','96 - Mecha Land.asm','Sound_96'),('Spark','5C - Mecha Spark.asm','Sound_5C'),('Thump','49 - Thump.asm','Sound_49')]:
        text=(a.source/'Sound/SFX'/file).read_text().replace(prefix,'Mecha'+short)
        (ROOT/f'sound/SFX/Mecha {short}.asm').write_text('; From pinned skdisasm; legacy SMPS voice format 0.\n'+text.rstrip()+'\n')
    print('Imported 22 body frames, 8 effect frames, 39-tile body buffer and 22 resident effect tiles.')
if __name__=='__main__':main()
