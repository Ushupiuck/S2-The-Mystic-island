#!/usr/bin/env python3
"""Check live visible FG/BG words across each authored terrain set in Mode 1.

Diagnostic camera targets use the real MD/CD scheduler, providers and VBlank.
The oracle reads authored geometry, not the constructor's cache/VDP records.
"""
from pathlib import Path
from functools import lru_cache
import argparse
import ctypes as C
import json
import struct
from genesis_test_core import Genesis
from check_object_course import boot_level
from level_layout import load
from convert_s1_ss_background import kosinski_plus_decode

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
for n in ('rom','listing','core','output'):p.add_argument('--'+n,type=Path,required=True)
p.add_argument('--system-directory',type=Path)
p.add_argument('--pal',action='store_true')
p.add_argument('--legacy-visible',action='store_true',help='Compare against the old padded background cells at visible coordinates')
a=p.parse_args()
g=Genesis(a.core,a.rom,a.listing,a.output,a.pal,system_directory=a.system_directory)
vsram=(C.c_uint8*128).in_dll(g.core,'vsram')
rom=a.rom.read_bytes();samples=0;report=[]

def word(memory,address):return (memory[address^1]<<8)|memory[(address+1)^1]

for zone,name in ((0,'GHZ'),(1,'LZ'),(2,'CPZ'),(3,'EHZ'),(4,'HPZ'),(5,'HTZ'),(6,'MTZ'),(8,'SMZ')):
    boot_level(g,zone=zone,act=0)
    fg,bg=load(ROOT/f'level/layout/{name}_1.kosp')
    if a.legacy_visible:
        old=kosinski_plus_decode((ROOT/f'md-only/layout/{name}_1.kosp').read_bytes())[0]
        fg=[list(old[y*256:y*256+128]) for y in range(16)]
        bg=[list(old[y*256+128:y*256+256]) for y in range(16)]
    header=g.s['LevelArtPointers']+zone*4*12
    blocks,chunks=[kosinski_plus_decode(rom[struct.unpack_from('>I',rom,header+offset)[0]&0xFFFFFF:])[0] for offset in (4,8)]
    @lru_cache(None)
    def tile(plane,x,y):
        cells=(fg,bg)[plane];cx,cy=(x&0x7FFF)//128,(y&0xFFF)//128
        chunk=cells[cy][cx] if not plane and cy<len(cells) and cx<len(cells[0]) else (0 if not plane else cells[cy%len(cells)][cx%len(cells[0])])
        e=struct.unpack_from('>H',chunks,chunk*128+((y//16&7)*8+(x//16&7))*2)[0]
        bx,by=(x//8&1)^bool(e&0x400),(y//8&1)^bool(e&0x800)
        return struct.unpack_from('>H',blocks,(e&1023)*8+(by*2+bx)*2)[0]^(0x800 if e&0x400 else 0)^(0x1000 if e&0x800 else 0)
    def check():
        global samples
        assert not g.read('v_errortype'),(name,g.frame)
        for plane in (0,1):
            py=word(vsram,plane*2)&0x7FF
            for sy in range(0,224,8):
                wy=py+sy
                scroll=word(g.vram,g.s['vram_hscroll']+sy*4+plane*2)
                scroll=scroll if scroll<0x8000 else scroll-65536
                for sx in range(0,320,8):
                    wx=(sx-scroll)&65535
                    source_x=wx
                    if plane and (name in ('EHZ','HTZ') or (name=='GHZ' and (not 4<=((wy//16)&15)<10 or (((wy//16)&15)==9 and wy&8))) or (name=='SMZ' and ((wy//16)&31)<4)):
                        source_x &=511
                    address=(0xE000 if plane else 0xC000)+(wy//8&31)*128+(wx//8&63)*2
                    actual=word(g.vram,address);expected=tile(plane,source_x,wy)
                    assert actual==expected,(name,g.frame,plane,(sx,sy),(source_x,wy),hex(actual),hex(expected))
                    samples+=1
    check();initial_y=g.read('Camera_Y_pos',2)
    for index,(tx,ty) in enumerate(((0x600,initial_y),(0x600,min(initial_y+384,0x720)),(0,initial_y))):
        for tick in range(100):
            for field,value,size in (('obX',tx+160,2),('obY',ty+96,2),('obVelX',0,2),('obVelY',0,2),('obInertia',0,2),('obControl',0x81,1),('obRoutine',2,1),('obStatus',0,1),('invtime',6000,2)):
                g.put('v_player',field,value,size)
            g.write('Camera_Min_Y_pos',0,2);g.write('Camera_Max_Y_pos',0x720,2);g.write('Camera_Max_Y_pos_target',0x720,2)
            g.run()
            if tick%4==0:check()
        check();g.video.save(a.output/f'{name}-{index}.png')
    report.append(name);print(name+' visible foreground/background pass.',flush=True)
    g.write('v_gamemode',g.s['SegaScreen'],2);g.run()
(a.output/'report.json').write_text(json.dumps(dict(terrain_sets=report,tile_samples=samples,pal=a.pal),indent=2)+'\n')
g.close()
