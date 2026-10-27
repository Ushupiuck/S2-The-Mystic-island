#!/usr/bin/env python3
"""Check shared water/terrain allocation and carrier/contact regressions.

Uses real ROM routines in Genesis Plus GX. Fixtures place actors/objects;
collision, carrier motion, animation, rendering and DMA run the built game.
--probe records an older ROM's failures, without treating them as passes.
"""
from pathlib import Path
import argparse,ctypes as C,hashlib,json,struct,subprocess
from genesis_test_core import Genesis
from check_caterkiller import CpuPrefix
from check_companion_followup import isolate,place,spawn
from check_object_course import boot_level
from check_sprite_assets import frames
from convert_s1_ss_background import kosinski_plus_decode

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
for key in ('core','output'):p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
p.add_argument('--reference',default='1749b38b24af145c9c3634fefc7395faec1a00c7')
p.add_argument('--system-directory',type=Path)
p.add_argument('--pal',action='store_true');p.add_argument('--probe',action='store_true')
a=p.parse_args();rows=[]
def record(case,ok=True,**detail):
 rows.append(dict(case=case,passed=bool(ok),**detail));print(rows[-1],flush=True)
 if not a.probe:assert ok,rows[-1]
def old(path):return subprocess.check_output(['git','show',a.reference+':'+str(path)],cwd=ROOT)

if not a.probe:
 # Compare every block, including blocks not currently placed in any chunk.
 for zone in ('GHZ','LZ','CPZ','EHZ','HPZ','HTZ','MTZ','SMZ'):
  ap=Path(f'art/kosinski/level/8x8 - {zone}.kosp');mp=Path(f'mappings/16x16/{zone}.kosp')
  before=kosinski_plus_decode(old(ap))[0];after=kosinski_plus_decode((ROOT/ap).read_bytes())[0]
  bm=kosinski_plus_decode(old(mp))[0];am=kosinski_plus_decode((ROOT/mp).read_bytes())[0]
  assert len(bm)==len(am)
  assert (ROOT/ap.with_suffix('.unc')).read_bytes()==after
  assert not any(after[:17*32]), (zone,'transparent tile / water prefix changed')
  for (ow,),(nw,) in zip(struct.iter_unpack('>H',bm),struct.iter_unpack('>H',am)):
   assert ow&0xF800==nw&0xF800,(zone,'tile flags changed')
   ot,nt=ow&2047,nw&2047
   assert not 1<=nt<17,(zone,'terrain still uses water tiles',nt)
   if zone=='SMZ' and ot==0x4AF:
    previous=kosinski_plus_decode(old('art/kosinski/level/SMZ Terrain Tile.kosp'))[0]
   elif ot*32>=len(before):
    assert ot==nt;continue  # separate animated art
   else:previous=before[ot*32:(ot+1)*32]
   current=after[nt*32:(nt+1)*32]
   assert previous==current,(zone,hex(ot),hex(nt),'pixels changed')
  record(zone+' all block pixels preserved',blocks=len(bm)//8)
 atlas=(ROOT/'art/uncompressed/SMZ Sprite Atlas.unc').read_bytes()
 assert atlas[:497*32]==old('art/uncompressed/SMZ Sprite Atlas.unc')[:497*32]
 assert len(atlas)==503*32 and not any(atlas[497*32:])
 record('SMZ sprite pixels preserved; displaced tile restored to terrain')
 assert len(kosinski_plus_decode((ROOT/'art/kosinski/level/8x8 - GHZ.kosp').read_bytes())[0])==0x321*32
 record('Ten unused GHZ slots reclaimed into contiguous terrain capacity')

 # Compare visible indexed pixels; CPZ trims only an empty top-row column.
 def sprite_pixels(row,art):
  pixels={}
  for y,size,tile,x in row:
   w,h=(size>>2)+1,(size&3)+1;base=tile&2047
   for px in range(w*8):
    for py in range(h*8):
     sx=w*8-1-px if tile&0x800 else px;sy=h*8-1-py if tile&0x1000 else py
     address=(base+(sx//8)*h+sy//8)*32+(sy%8)*4+(sx%8)//2
     byte=art[address];colour=byte>>4 if sx%2==0 else byte&15
     if colour:pixels[x+px,y+py]=(tile&0xe000,colour)
  return pixels
 for zone,names in [('GHZ',('18 - GHZ platform mappings','GHZ Collapsing Ledge')),
                    ('EHZ',('18 - EHZ platform mappings',)),('CPZ',('Tilting Platform',))]:
  artpath=Path(f'art/kosinski/level/8x8 - {zone}.kosp')
  before=kosinski_plus_decode(old(artpath))[0];after=kosinski_plus_decode((ROOT/artpath).read_bytes())[0]
  for name in names:
   path=Path('mappings/sprite')/(name+'.bin')
   oldframes,newframes=frames(old(path)),frames((ROOT/path).read_bytes())
   assert len(oldframes)==len(newframes)
   for of,nf in zip(oldframes,newframes):assert sprite_pixels(of,before)==sprite_pixels(nf,after),name
   record(name+' shared terrain pixels preserved')

g=Genesis(a.core,a.rom,a.listing,a.output,a.pal,system_directory=a.system_directory)
assert g.s['ArtTile_Water_Surface']==1
g.core.m68k_set_reg.argtypes=[C.c_int,C.c_uint];g.core.m68k_run.argtypes=[C.c_uint]
cpu=CpuPrefix.in_dll(g.core,'m68k');rom=a.rom.read_bytes()
def act(label,obj=None,regs=None):
 g.core.m68k_set_reg(17,0x2700)
 if obj is not None:g.core.m68k_set_reg(8,0xFF0000|(obj&65535))
 for reg,value in (regs or {}).items():g.core.m68k_set_reg(reg,value&0xFFFFFFFF)
 g.core.m68k_set_reg(15,0xFF8000);g.write(0x8000,0xFF8004,4);g.write(0x8004,0x60FE,2)
 g.core.m68k_set_reg(16,g.s[label] if isinstance(label,str) else label)
 start=cpu.cycles
 for _ in range(30000):
  if g.core.m68k_get_reg(16)==0xFF8004:
   assert g.core.m68k_get_reg(15)==0xFF8004,'unbalanced stack'
   return cpu.cycles-start
  g.core.m68k_run(cpu.cycles+1)
 raise AssertionError((label,'routine did not return',hex(g.core.m68k_get_reg(16))))
def vram(first,count):return bytes(g.vram[(first+i)^1] for i in range(count))
def clear_queue():g.write('VDP_Command_Buffer_Slot',g.s['VDP_Command_Buffer'],2)
def queued_bytes():
 return sum(((g.read(ptr+g.s['DMAEntry.SizeH'])<<8)|g.read(ptr+g.s['DMAEntry.SizeL']))*2
  for ptr in range(g.s['VDP_Command_Buffer']&65535,g.read('VDP_Command_Buffer_Slot',2),g.s['DMAEntry.len']))
def water_pair():
 act('WaterSurface',g.s['v_watersurface1']);act('WaterSurface',g.s['v_watersurface2'])
def init_water():
 for name in ('v_watersurface1','v_watersurface2'):
  g.write(g.s[name],0,g.s['object_size']);g.put(name,'code',g.s['WaterSurface'])
 g.put('v_watersurface1','obX',0x60,2);g.put('v_watersurface2','obX',0x120,2)
 g.write('v_waterpos1',100,2);g.write('f_pause',0,2)
 g.write('v_jpadpress1',0);g.write('v_jpadpresslogical',0)

try:
 boot_level(g,zone=0,player=0);stage=g.save();isolate(g)
 if not a.probe:
  init_water();clear_queue();act('InitDMAQueue')
  # Disable display in this isolated transfer fixture; live pause is checked below.
  code=bytes.fromhex('33FC811400C0000433FC8F0200C000044E75')
  for i,b in enumerate(code):g.ram[(0x7F00+i)^1]=b
  act(0xFF7F00)
  surf=rom[g.s['Art_Water_Surface']:g.s['Art_Water_Surface']+24*32]
  oldmap=frames(old('mappings/sprite/Water surface.bin'))
  newmap=frames((ROOT/'mappings/sprite/Water surface.bin').read_bytes())
  cycles=[];previous_phase=None;uploads=0
  for tick in range(64):
   clear_queue();water_pair();phase=g.get('v_watersurface1','obFrame')
   assert phase==g.get('v_watersurface2','obFrame')
   assert queued_bytes()==(256 if phase!=previous_phase else 0),('duplicate/missing wave DMA',tick,queued_bytes())
   uploads+=phase!=previous_phase;previous_phase=phase
   cycles.append(act('ProcessDMAQueue'));g.run()
   assert vram(g.s['ArtTile_Water_Surface']*32,256)==surf[phase*256:(phase+1)*256],(tick,phase,hex(g.s['Art_Water_Surface']),vram(g.s['ArtTile_Water_Surface']*32,24).hex(),surf[phase*256:phase*256+24].hex())
  record('64 water phases; one upload shared by both objects',maximum_bytes_per_frame=256,uploads=uploads,max_dma_master_cycles=max(cycles))
  for phase in range(3):
   init_water();g.put('v_watersurface1','obFrame',phase);g.put('v_watersurface2','obFrame',phase)
   g.write('v_jpadpress1',g.s['btnStart']);clear_queue();water_pair()
   assert queued_bytes()==512;act('ProcessDMAQueue');g.run()
   resident=vram(g.s['ArtTile_Water_Surface']*32,512)
   assert oldmap[phase+3]==newmap[phase+3]
   other=2 if phase==1 else 1
   assert resident==surf[phase*256:(phase+1)*256]+surf[other*256:(other+1)*256]
   g.write('f_pause',1,2);g.write('v_jpadpress1',0);clear_queue();water_pair()
   assert queued_bytes()==0,'paused waves uploaded again'
   record('paused wave '+str(phase)+' unchanged',bytes_on_pause=512)
  init_water();g.write('VDP_Command_Buffer_Slot',g.s['VDP_Command_Buffer_Slot'],2)
  water_pair();assert not g.get('v_watersurface1','surf_loaded')
  clear_queue();water_pair();assert queued_bytes()==256
  record('full DMA queue retries the complete water frame')
 # Exact circular disc acquisition, with the real player handler for each actor.
 g.restore(stage);isolate(g);disc=spawn(g,'SMZ_RunningDisc',0x180,0x400,0x80)
 g.write('Camera_X_pos',0x100,2);act('SMZ_Disc_Main',disc)
 dbase=g.save();cases=0
 for who in ('v_player','v_player2'):
  for dx,dy,inside in ((0,-67,True),(60,0,True),(50,-50,True),(65,-50,False),(-65,-50,False),(71,71,False)):
   g.restore(dbase);place(g,who,0x180+dx,0x400+dy,False)
   flag=disc+g.s['SMZ_disc_sonic_attached']+(who=='v_player2')
   act('SMZ_Disc_MoveSonic',disc,{9:g.s[who],11:0xFF0000|flag})
   attached=bool(g.read(flag));cases+=1
   record(who+' disc acquisition '+str((dx,dy)),attached==inside,attached=attached)
 # First landing and continued standing must use the same visible 16px top.
 g.restore(stage);isolate(g);spring=spawn(g,'Obj41',0x180,0x400,0x10)
 g.write('Camera_X_pos',0x100,2);act('Obj41_Init',spring);sbase=g.save()
 for who in ('v_player','v_player2'):
  g.restore(sbase);place(g,who,0x180,0x400-16-g.get(who,'obHeight')+2,True)
  g.put(who,'obVelY',0x100,2);act('Obj41_Horizontal',spring)
  landed=g.get(who,'obY',2)+g.get(who,'obHeight')
  act('Obj41_Horizontal',spring)
  stood=g.get(who,'obY',2)+g.get(who,'obHeight')
  record(who+' horizontal spring top',landed==0x3F0 and stood==landed,landed_feet=landed,standing_feet=stood)
 # Run real object passes. A teleporter updates Tails after his reserved slot.
 g.restore(stage);isolate(g);place(g,'v_player',0x240,0x400,False)
 place(g,'v_player2',0x180,0x400,False);g.write('Tails_CPU_idle_timer',6000,2)
 pipe=spawn(g,'SMZ_Teleport',0x180,0x400,0)
 g.write('Camera_X_pos',0x100,2);g.write('Camera_Y_pos',0x380,2)
 act('SMZ_Teleport',pipe)
 assert g.get('v_player2','obControl')==0x81,'teleporter fixture failed to capture Tails'
 tails=[];moves=0;previous=None
 for tick in range(90):
  clear_queue();g.write('v_spritequeue',0,g.s['v_spritequeue_end']-g.s['v_spritequeue'])
  act('ExecuteObjects')
  body=(g.get('v_player2','obX',2),g.get('v_player2','obY',2))
  tail=(g.get('v_player2tails','obX',2),g.get('v_player2tails','obY',2))
  tails.append(body==tail)
  if previous is not None:moves+=body!=previous
  previous=body
 record('teleporter tail follows final body position',all(tails) and moves>40,moving_frames=moves,mismatched_frames=tails.count(False))
 # A genuine moving solid must also leave body/tail together after riding.
 g.restore(stage);isolate(g);swing=spawn(g,'SwingingPtfm',0x180,0x300,3)
 g.write('Camera_X_pos',0x100,2);g.write('Camera_Y_pos',0x300,2)
 act('SwingingPtfm',swing);act('SwingingPtfm',swing)
 x,y=g.get(swing,'obX',2),g.get(swing,'obY',2)
 place(g,'v_player',x+32,y-30,False);g.put('v_player','obControl',1)
 place(g,'v_player2',x,y-9-g.get('v_player2','obHeight'),False)
 swingbody=g.get(swing,'swing_body',2)
 g.put('v_player2','obStatus',8);g.put('v_player2','standonobject',(swingbody-(g.s['v_objspace']&65535))//g.s['object_size'])
 g.put(swingbody,'obStatus',g.get(swingbody,'obStatus')|16);g.write('Tails_CPU_idle_timer',6000,2)
 mismatches=riding=moving=0;previous=None
 for tick in range(160):
  clear_queue();g.write('v_spritequeue',0,g.s['v_spritequeue_end']-g.s['v_spritequeue'])
  g.write('Timer_frames',g.read('Timer_frames',2)+1,2);act('ExecuteObjects');act('OscillateNumDo')
  body=(g.get('v_player2','obX',2),g.get('v_player2','obY',2))
  tail=(g.get('v_player2tails','obX',2),g.get('v_player2tails','obY',2))
  riding+=bool(g.get('v_player2','obStatus')&8);mismatches+=body!=tail
  if previous is not None:moving+=body!=previous
  previous=body
 record('swinging-platform tail follows final body position',mismatches==0 and riding>100 and moving>50,riding_frames=riding,moving_frames=moving,mismatched_frames=mismatches)
 # A wrapped displacement must retain its sign when the camera is below
 # a jumping player. These cases also cross the actual $000/$800 seam.
 for cam,player_y,expected in ((0x4A0,0x490,-1),(0x10,0x7F0,-1),(0x7F0,0x30,0),(0x40,0xD0,1)):
  g.restore(stage);place(g,'v_player',0x100,player_y,True)
  g.write('Camera_Min_Y_pos',-0x100,2);g.write('Camera_Max_Y_pos',0x800,2)
  g.write('Camera_Y_pos',cam<<16,4);g.write('Camera_Y_pos_bias',g.s['Camera_LookCenter'],2)
  g.write('Camera_Max_Y_Pos_Changing',0)
  act('ScrollVertical',g.s['v_player'],{9:g.s['Camera_Y_pos'],10:g.s['Verti_block_crossed_flag'],11:g.s['Scroll_flags'],12:g.s['Camera_Y_pos_diff']})
  delta=(g.read('Camera_Y_pos',2)-cam+0x400)%0x800-0x400
  record('wrapped camera signed displacement '+str((cam,player_y)),(delta>0)-(delta<0)==expected,delta=delta)
 # Exact first solid frame at both edges, extending beyond the former
 # 12px landing window. Rising underside and already-closed sides stay solid.
 g.restore(stage);isolate(g);door=spawn(g,'SMZ_SpinPlatform',576,1196,1)
 g.write('Camera_X_pos',400,2);tbase=g.save()
 bad=[]
 for who in ('v_player','v_player2'):
  for x,direction in ((504,1),(648,-1)):
   for depth in (0,6,12,13,16,20,23):
    g.restore(tbase)
    for f,v,n in [('obRoutine',2,1),('obMap',g.s['Map_SMZ_Trap'],4),('obRender',0x84,1),('obActWid',64,1),('obAnim',1,1),('obPrevAni',1,1),('obFrame',1,1),('obAniFrame',2,1),('obTimeFrame',0,1),('SMZ_spin_timer',1000,2),('SMZ_spin_timelen',60,2)]:g.put(door,f,v,n)
    place(g,who,x,1184-g.get(who,'obHeight')+depth,False)
    speed=direction*0x600;g.put(who,'obVelX',speed,2);g.put(who,'obInertia',speed,2)
    act('SMZ_Spin_Trapdoor',door)
    good=g.get(door,'obFrame')==0 and g.get(who,'obVelX',2)==speed&65535 and g.get(who,'obX',2)==x and bool(g.get(who,'obStatus')&8)
    if not good:bad.append((who,x,depth))
 record('trapdoor closing-frame edge overlaps',not bad,cases=28,failures=bad)
 for who in ('v_player','v_player2'):
  for case in ('closed-side','rising-underside'):
   g.restore(tbase)
   for f,v,n in [('obRoutine',2,1),('obMap',g.s['Map_SMZ_Trap'],4),('obRender',0x84,1),('obActWid',64,1),('obAnim',1,1),('obPrevAni',1,1),('obFrame',0,1),('obAniFrame',3,1),('obTimeFrame',10,1),('SMZ_spin_timer',1,2),('SMZ_spin_timelen',60,2)]:g.put(door,f,v,n)
   if case=='closed-side':
    place(g,who,504,1184-g.get(who,'obHeight')+16,False);g.put(who,'obVelX',0x600,2);g.put(who,'obInertia',0x600,2)
   else:
    place(g,who,576,1196+g.get(who,'obHeight')+6,True);g.put(who,'obVelY',-0x200,2)
   act('SMZ_Spin_Trapdoor',door)
   good=not g.get(who,'obVelX',2) if case=='closed-side' else not g.get(who,'obVelY',2)
   record(who+' trapdoor '+case+' remains solid',good)

 # Reproduce the player's exact duck/release/jump sequence on native SBZ2.
 g.core.retro_reset();g.buttons=g.buttons2=set();boot_level(g,zone=8,act=1,player=1)
 # Initial positioning only: use the real flat SBZ2 floor at $0080,$0400,
 # outside the cramped entrance. Subsequent duck/jump inputs run normally.
 place(g,'v_player',0x80,0x3FF-g.get('v_player','obHeight'),False)
 g.write('Camera_X_pos',0,2);g.write('Camera_Y_pos',0x3FF-19-g.s['Camera_LookCenter'],2)
 g.write('Camera_Y_pos_bias',g.s['Camera_LookCenter'],2);g.run(20)
 g.buttons={5};g.run(200)
 g.buttons=set();g.run(2)  # release Down before pressing Jump, avoiding a spindash
 trace=[];previous=g.read('Camera_Y_pos',2);g.buttons={8}
 for tick in range(24):
  if tick==3:g.buttons=set()
  g.run();cam=g.read('Camera_Y_pos',2);delta=(cam-previous+0x400)%0x800-0x400;previous=cam
  vy=g.get('v_player','obVelY',2);vy=vy-65536 if vy&32768 else vy
  trace.append((delta,vy,g.get('v_player','obY',2)))
 wrong=[r for r in trace if r[1]<0 and r[0]>0]
 record('SBZ2 duck-release-jump camera follows the jump',not wrong and any(r[1]<0 for r in trace),wrong_direction_frames=len(wrong),rising_frames=sum(r[1]<0 for r in trace),first_frames=trace[:4])
 # Live H-int/VBlank and real Start-button pause/unpause, with both players.
 if not a.probe:
  g.core.retro_reset();g.buttons=g.buttons2=set();boot_level(g,zone=4,player=0)
  for who in ('v_player','v_player2'):g.put(who,'obControl',1)
  g.write('Tails_CPU_idle_timer',6000,2)
  for _ in range(90):g.run();assert not g.read('v_errortype')
  live=g.save()
  phases=set()
  for _ in range(180):
   g.run();phases.add(g.get('v_watersurface1','obFrame'))
   assert not g.read('v_errortype') and g.read('v_spritecount')<=80
  assert phases=={0,1,2},phases
  g.buttons={3};g.run(2);g.buttons=set();g.run(3)
  assert g.read('f_pause',2)==1,'Start failed to pause'
  frame=g.get('v_watersurface1','obFrame');assert 3<=frame<=5,frame
  phasepair=((0,1),(1,2),(2,1))[frame-3]
  expected=b''.join(surf[i*256:(i+1)*256] for i in phasepair)
  bank=g.s['ArtTile_Water_Surface']*32
  assert vram(bank,512)==expected,'live paused water art changed'
  g.run(60);assert vram(bank,512)==expected
  g.video.save(a.output/'water-paused.png')
  g.buttons={3};g.run(2);g.buttons=set();g.run(5)
  assert not g.read('f_pause',2) and g.get('v_watersurface1','obFrame')<3
  record('live water pause/unpause and H-int/VBlank continue normally',animation_frames=sorted(phases))
  # Load the real GHZ boss/capsule PLC while this surface is active. Restore
  # its captured CPU state after enqueuing, so normal VBlank runs the loader.
  state=g.save();pc=g.core.m68k_get_reg(16);regs=[g.core.m68k_get_reg(i) for i in range(18)]
  act('LoadPLC',regs={0:g.s['plcid_GHZBoss']})
  # Keep the enqueued PLC, restore only the interrupted CPU context/stack.
  for i,value in enumerate(regs):g.core.m68k_set_reg(i,value)
  for _ in range(180):g.run();assert not g.read('v_errortype')
  assert not g.read('v_plc_buffer',4),'boss PLC did not finish'
  assert g.s['ArtTile_Prison_Capsule']==0x4A7
  assert g.s['ArtTile_Prison_Capsule']>=g.s['ArtTile_Eggman_Exhaust']+17
  assert vram(g.s['ArtTile_Prison_Capsule']*32,32)!=bytes(32)
  g.buttons={3};g.run(2);g.buttons=set();g.run(3)
  frame=g.get('v_watersurface1','obFrame');assert 3<=frame<=5
  expected=b''.join(surf[i*256:(i+1)*256] for i in ((0,1),(1,2),(2,1))[frame-3])
  assert vram(bank,512)==expected,'boss art overwrote water'
  record('water coexists with the loaded boss/exhaust/capsule PLC')
finally:
 g.close()
report={'rom_sha256':hashlib.sha256(rom).hexdigest(),'region':'PAL' if a.pal else 'NTSC','checks':rows,'failures':sum(not r['passed'] for r in rows)}
(a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print('Failures:',report['failures'],flush=True)
