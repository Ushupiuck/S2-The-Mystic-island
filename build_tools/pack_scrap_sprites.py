#!/usr/bin/env python3
"""Pack the imported SBZ sprite atlas and verify each frame pixel for pixel.

Requires import_scrap_madness.py first. The reference ROM supplies the
unchanged shared mapping tables, not a different or synthetic level.
"""
from pathlib import Path
import sys,struct,re,collections
R=Path(__file__).resolve().parents[1]
import argparse
p=argparse.ArgumentParser(description='Pack SBZ sprites without changing their visible indexed pixels.')
p.add_argument('--source',type=Path,required=True)
p.add_argument('--rom',type=Path,required=True)
p.add_argument('--listing',type=Path,required=True)
args=p.parse_args();S=args.source
sys.path.insert(0,str(R/'build_tools'));from check_sprite_assets import frames
from import_scrap_madness import mapping,nemesis_inline,remap_pixels,palette_lookup
from convert_s1_ss_background import kosinski_plus_decode,kosinski_plus
sys.argv=['atlas','--rom',str(args.rom),'--listing',str(args.listing)];ns={'__file__':str(R/'build_tools/check_object_manager.py')};exec((R/'build_tools/check_object_manager.py').read_text().split('m=Manager()')[0],ns);m=ns['Native']();rom=args.rom.read_bytes()
def dec(path):
 d=path.read_bytes();n=struct.unpack_from('>H',d)[0]&32767;m.cpu.mem_write(0x300000,d);m.act('NemDecToRAM',limit=2000000,regs={ns['UC_M68K_REG_A0']:0x300000,ns['UC_M68K_REG_A4']:0xff0000});return bytes(m.cpu.mem_read(0xff0000,n*32))
bank={}
def fill(base,raw):
 for i in range(len(raw)//32):bank[base+i]=raw[i*32:(i+1)*32]
for name,base in [('Stomper',0x2c0),('Small Vertical Door',0x2e8),('Crushing Girder',0x2f0),('Spinning Platform',0x302),('Running Disc',0x344),('Junction Wheel',0x348),('Giant Spikeball',0x391),('Pizza Cutter',0x3b5),('Flaming Pipe',0x3d9),('Collapsing Floor',0x3f5),('Sliding Floor Trap',0x460),('Large Horizontal Door',0x46f),('Electrocuter',0x47e),('Trapdoor',0x492),('Vanishing Block',0x429)]:
 raw=dec(R/f'art/nemesis/S1/SBZ {name}.nem')
 if name=='Giant Spikeball':raw=remap_pixels(raw,palette_lookup(struct.unpack('>16H',(S/'palette/Sonic.bin').read_bytes()),struct.unpack('>16H',(R/'palette/SonicAndTails.bin').read_bytes()[:32])))
 fill(base,raw)
 if name=='Collapsing Floor':fill(base+4,raw)
fill(0x400,dec(R/'art/nemesis/S1/Enemy Bomb.nem'));fill(0x332,dec(R/'art/nemesis/Button.nem'))
for name,base in [('Enemy Caterkiller',0x2b0),('Enemy Ballhog (Horizontal)',0x620)]:fill(base,kosinski_plus_decode((R/f'art/moduled kosinski/{name}.kospm').read_bytes()[2:])[0])
sources={'Jun':'Rotating Junction','Disc':'Running Disc','Trap':'Trapdoor','Spin':'SBZ Spinning Platforms','Saw':'Saws and Pizza Cutters','Stomp':'SBZ Stomper and Door','VanP':'SBZ Vanishing Platforms','Flame':'Flamethrower','Elec':'Electrocuter','Gird':'Girder Block','Bomb':'Bomb Enemy','But':'Button'}
inputs={name:(frames(mapping((S/f'_maps/{sources[name]}.asm').read_text())),base) for name,base in [('Jun',0x4348),('Disc',0xc344),('Trap',0x4492),('Spin',0x302),('Saw',0x43b5),('Stomp',0x22c0),('VanP',0x4429),('Flame',0x83d9),('Elec',0x47e),('Gird',0x42f0),('Bomb',0x400),('But',0x336)]}
inputs['Stomp']=(inputs['Stomp'][0][:4]+[inputs['Stomp'][0][0]],0x22c0)
mb=frames(mapping((S/'_maps/Moving Blocks (MZ and SBZ).asm').read_text()));mb=[mb[2],mb[2],mb[2],mb[3],mb[2]];inputs['MBlock']=(mb,lambda i:0x4460 if i==3 else 0x22c0)
for name,label,base in [('Floor','Map_Obj1B',0x43f5),('Door','Map_obj30',0x42e8),('Cat','Map_Cat',0x22b0),('Hog','Map_BallHogH',0x2620)]:
 if label not in m.s:label=label.replace('Map_obj30','Map_Obj30')
 rs=frames(rom,m.s[label],m.s[label+'_frames'])
 if name=='Floor':rs=rs[:2]+rs[:2]
 inputs[name]=(rs,base)
inputs['Swing']=(frames(mapping((S/'_maps/Big Spiked Ball.asm').read_text())),0x391)
atlas=bytearray();patterns={};out={}
for name,(rs,base) in inputs.items():
 new=[]
 for frame,row in enumerate(rs):
  pieces=[];gfx=base(frame) if callable(base) else base
  for y,size,tile,x in row:
   total=(tile+gfx)&65535;t=total&2047;w,h=(size>>2)+1,(size&3)+1
   cells=[[bank[t+cx*h+cy] for cy in range(h)] for cx in range(w)]
   # Two-tile rectangles preserve VDP batching while sharing repeated strips.
   for left in range(0,w,2):
    for top in range(0,h,2):
     ww,hh=min(2,w-left),min(2,h-top);body=b''.join(cells[cx][cy] for cx in range(left,left+ww) for cy in range(top,top+hh))
     if not any(body):continue
     if body not in patterns:patterns[body]=len(atlas)//32;atlas+=body
     xx=x+((w-left-ww) if total&0x800 else left)*8;yy=y+((h-top-hh) if total&0x1000 else top)*8
     pieces.append((yy,(ww-1)*4+hh-1,(total&0xf800)|patterns[body],xx))
  assert len(pieces)<=64,(name,frame,len(pieces));new.append(pieces)
 data=bytearray(len(new)*2)
 for i,row in enumerate(new):struct.pack_into('>H',data,i*2,len(data));data+=struct.pack('>H',len(row))+b''.join(struct.pack('>bBHh',*p) for p in row)
 out[name]=data
print('Atlas tiles',len(atlas)//32,'capacity525; max pieces',max(len(row) for d in out.values() for row in frames(d)),flush=True)
# Recover larger VDP rectangles wherever their complete pixels remain contiguous.
for name,(rs,base) in inputs.items():
 new=[]
 for frame,row in enumerate(rs):
  result=[];gfx=base(frame) if callable(base) else base
  for y,size,tile,x in row:
   total=(tile+gfx)&65535;t=total&2047;w,h=(size>>2)+1,(size&3)+1
   body=b''.join(bank[t+i] for i in range(w*h));pos=atlas.find(body)
   if pos>=0 and pos%32==0:
    result.append((y,size,(total&0xf800)|pos//32,x));continue
   for left in range(0,w,2):
    for top in range(0,h,2):
     ww,hh=min(2,w-left),min(2,h-top);body=b''.join(bank[t+cx*h+cy] for cx in range(left,left+ww) for cy in range(top,top+hh))
     if not any(body):continue
     xx=x+((w-left-ww) if total&0x800 else left)*8;yy=y+((h-top-hh) if total&0x1000 else top)*8
     result.append((yy,(ww-1)*4+hh-1,(total&0xf800)|patterns[body],xx))
  new.append(result)
 data=bytearray(len(new)*2)
 for i,row in enumerate(new):struct.pack_into('>H',data,i*2,len(data));data+=struct.pack('>H',len(row))+b''.join(struct.pack('>bBHh',*p) for p in row)
 out[name]=data
# Independently compare visible indexed pixels, flags and positions in every frame.
def pixels(row,get,gfx):
 result={}
 for y,size,tile,x in row:
  total=(tile+gfx)&65535;t=total&2047;w,h=(size>>2)+1,(size&3)+1
  for px in range(w*8):
   for py in range(h*8):
    xx=w*8-1-px if total&0x800 else px;yy=h*8-1-py if total&0x1000 else py
    cell=get(t+(xx//8)*h+yy//8);b=cell[(yy&7)*4+(xx&7)//2];colour=b>>4 if xx%2==0 else b&15
    if colour:result[x+px,y+py]=(total&0xe000,colour)
 return result
for name,(rs,base) in inputs.items():
 packed=frames(out[name]);assert len(rs)==len(packed),(name,len(rs),len(packed))
 for i,(old,new) in enumerate(zip(rs,packed)):
  assert pixels(old,lambda t:bank[t],base(i) if callable(base) else base)==pixels(new,lambda t:atlas[t*32:(t+1)*32],0),(name,i,'pixel mismatch')
print('Pixel/priority/palette equivalence passed:',sum(len(rs) for rs,_ in inputs.values()),'frames; junction pieces:',[len(row) for row in frames(out['Jun'])])
assert len(atlas)//32<=525
for name,d in out.items():(R/f'mappings/sprite/SMZ {name}.bin').write_bytes(d)

(R/'art/nemesis/SMZ Sprite Atlas.nem').write_bytes(nemesis_inline(atlas))
(R/'art/uncompressed/SMZ Sprite Atlas.unc').write_bytes(atlas)
# Geometry's two smoke banks move together; ordinary terrain remains intact.
p=R/'mappings/16x16/SMZ.kosp';raw=kosinski_plus_decode(p.read_bytes())[0]
words=struct.unpack('>'+str(len(raw)//2)+'H',raw)
raw=b''.join(struct.pack('>H',(w&~2047)|((w&2047)-0x448+0x4bd)) if 0x448<=w&2047<0x460 else struct.pack('>H',w) for w in words)
p.write_bytes(kosinski_plus(raw))
