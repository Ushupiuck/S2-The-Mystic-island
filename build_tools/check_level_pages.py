#!/usr/bin/env python3
"""Check real menu navigation and boot every four-act zone selection."""
from pathlib import Path
import argparse,json
from genesis_test_core import Genesis

p=argparse.ArgumentParser(description=__doc__)
for n in ('rom','listing','core','output'):p.add_argument('--'+n,type=Path,required=True)
p.add_argument('--pal',action='store_true');args=p.parse_args()
g=Genesis(args.core,args.rom,args.listing,args.output,args.pal)
for _ in range(1800):
 g.run()
 if g.read('v_vbla_routine',2)==g.s['Vint_Title'] and g.read('v_generictimer',2)==375:break
else:raise AssertionError('title not reached')
g.write('f_levselcheat',1)
def press(button):
 g.buttons={button};g.run(1);g.buttons=set();g.run(2)
press(3);g.run(110);menu=g.save()
def text_at(row,col,n):
 addr=0xc000+row*128+col*2
 return [int.from_bytes(bytes(g.vram[(addr+i+j)^1] for j in range(2)),'big')&2047 for i in range(0,n*2,2)]
def encoded(s):return [0 if c==' ' else ord(c)-65+30 for c in s]
assert text_at(1,1,13)==encoded('TWILIGHT HILL')
for _ in range(16):press(5)
assert g.read('v_levselitem',2)==32
press(3);assert g.read('v_levselitem',2)==0x120
assert text_at(1,1,13)==encoded('SCRAP MADNESS')
assert text_at(23,1,8)==encoded('PREVIOUS')
press(5);assert g.read('v_levselitem',2)==0x121
press(6);assert g.read('v_levselsound',2)==255
press(7);assert g.read('v_levselsound',2)==0
press(0);assert not g.read('v_errortype')
press(4);press(3);assert g.read('v_levselitem',2)==32
assert text_at(23,1,4)==encoded('NEXT')
g.video.save(args.output/'page-1.png')
g.restore(menu)
for expected in (1,2,0):press(8);assert g.read('Player_mode',2)==expected
checks=[]
for zone in range(16):
 for act in range(4):
  g.restore(menu);g.write('v_levselitem',(zone//8)*256+(zone%8)*4+act,2)
  press(3)
  for tick in range(700):
   g.run()
   assert not g.read('v_errortype'),(zone,act,'CPU exception')
   if g.read('v_vbla_routine',2)==g.s['Vint_Level'] and g.read('f_timecount') and g.read('v_gamemode',2)==g.s['Level']:break
  else:raise AssertionError((zone,act,'boot timed out'))
  assert g.read('Current_ZoneAndAct',2)==zone*256+act,(zone,act,g.read('Current_ZoneAndAct',2))
  g.run(15);assert not g.read('v_errortype'),(zone,act)
  checks.append({'zone':zone,'act':act+1,'passed':True})
print('Menu paging, sound wrap, three character modes and all 64 act boots pass',flush=True)
(args.output/'report.json').write_text(json.dumps({'pal':args.pal,'checks':checks},indent=2));g.close()
