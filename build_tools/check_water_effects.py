#!/usr/bin/env python3
"""Check actual water crossings, streamed art and number cleanup in Genesis Plus GX."""
from pathlib import Path
import argparse,json,struct
from genesis_test_core import Genesis
from check_object_course import boot_level
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--rom',type=Path,required=True);p.add_argument('--listing',type=Path,required=True)
p.add_argument('--core',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--pal',action='store_true');p.add_argument('--player',type=int,choices=(0,2),default=0)
p.add_argument('--course',action='store_true');p.add_argument('--companion',action='store_true')
p.add_argument('--system-directory',type=Path,help='Optional BIOS directory for Mode 1 checks')
args=p.parse_args();pal=args.pal;mode=args.player;course=args.course
assert not args.companion or mode==0
player='v_player2' if args.companion else 'v_player'
splash='v_tsplash' if args.companion else 'v_splash'
breath='v_tailsbubbles' if args.companion else 'v_sonicbubbles'
bank=0xFE00 if args.companion else 0xFC00
label='Companion Tails' if args.companion else ('Tails' if mode else 'Sonic')
g=Genesis(args.core,args.rom,args.listing,args.output,pal,system_directory=args.system_directory)
boot_level(g,item=10 if course else 6,player=mode)
if not args.companion:g.put('v_player2','layout_id',0)
rom=args.rom.read_bytes()
def vram(a,n):return bytes(g.vram[(a+i)^1] for i in range(n))
def bank_sprites():
    return [i for i in range(g.read('v_spritecount')) if bank//32<=g.read(g.s['Sprite_Table']+i*8+4,2)&0x7FF<bank//32+16]
def actor(a):return {f:g.get(a,f,n) for f,n in [('code',4),('obFrame',1),('obRoutine',1),('obX',2),('obY',2),('obGfx',2),('obStatus',1)]}
def number_actors():return [a for a in range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']) if g.get(a,'code')==g.s['Obj0A'] and 9<=g.get(a,'obFrame')<19]
def fixture(a,x,y,vy=0,status=2):
    for f,v,n in [('obX',x,2),('obY',y,2),('obVelX',0,2),('obVelY',vy,2),('obInertia',0,2),('obControl',0,1),('obStatus',status,1),('obAnim',0,1),('obRoutine',2,1),('obStatusSecondary',2,1),('invtime',6000,2),('flashtime',0,2)]:g.put(a,f,v,n)
    g.write('Camera_X_pos',x-160,2);g.write('Camera_Y_pos',y-100,2)
water=g.read('v_waterpos1',2);test_x=0x280 if course else 0xE00
if args.companion:
    fixture('v_player',test_x,water+64);g.put('v_player','obControl',1)
    g.write('Tails_CPU_idle_timer',600,2)
fixture(player,test_x,water-2,0x600)
for tick in range(20):
    g.run()
    if g.get(splash,'code')==g.s['Splash']:break
else:raise AssertionError(('no entry splash',actor(player),water,g.read('v_waterpos1',2)))
frames=set();uploaded=set();rendered_splash=False
for tick in range(50):
    g.put(player,'obControl',1)
    g.put(player,'obY',g.read('v_waterpos1',2)+64,2)
    g.write('Camera_Y_pos',g.read('v_waterpos1',2)-100,2)
    g.run()
    if g.get(splash,'code'):
        rendered_splash|=bool(bank_sprites())
        frame=g.get(splash,'obFrame');frames.add(frame)
        p=g.s['DPLC_Splash'];off=struct.unpack_from('>h',rom,p+frame*2)[0]
        count=struct.unpack_from('>H',rom,p+off)[0]
        if count:
            run=struct.unpack_from('>H',rom,p+off+2)[0];length=((run>>12)+1)*32
            source=g.s['Art_WaterSplash']+(run&0xFFF)*32
            if vram(bank,length)==rom[source:source+length]:uploaded.add(frame)
        if frame==3:g.video.save(g.output/'entry-splash.png')
assert frames==set(range(1,10)),frames
assert uploaded==frames,('splash uploads',uploaded,frames)
assert rendered_splash,'splash never reached the sprite table'
assert not g.get(splash,'code'),'splash did not finish'

# The real air controller emits and transforms its own number objects.
if args.companion:g.put(player,'air_left',11)
else:g.write('v_air',11,2)
g.put(breath,'objoff_3C',0,2)
seen_numbers=set();number_uploads=set();captured_number=False;rendered_number=False
for tick in range(180):
    g.put(player,'obControl',1);g.put(player,'obY',g.read('v_waterpos1',2)+64,2)
    g.write('Camera_Y_pos',g.read('v_waterpos1',2)-100,2)
    g.run()
    for a in number_actors():
        rendered_number|=bool(bank_sprites())
        frame=g.get(a,'obFrame');seen_numbers.add(frame)
        source=g.s['Art_AirCountdown']+(frame-9)*6*32
        if vram(bank,6*32)==rom[source:source+6*32]:
            number_uploads.add(frame)
            if not captured_number:
                g.video.save(g.output/'countdown.png');captured_number=True
assert seen_numbers and number_uploads,('no numbers',seen_numbers,actor(breath),g.read('v_air',2))
assert rendered_number,'countdown never reached the sprite table'

# Surface exit/refilling air clears existing screen-space numbers.
fixture(player,test_x,g.read('v_waterpos1',2)+2,0xFA00,0x42)
for tick in range(20):
    g.run()
    if not g.get(player,'obStatus')&64:break
else:raise AssertionError('did not leave water')
assert (g.get(player,'air_left') if args.companion else g.read('v_air',2))==30
g.run(4)
assert not number_actors(),'number remained after resurfacing'
assert g.get(splash,'code')==g.s['Splash'],'missing exit splash'
g.video.save(g.output/'exit-splash.png')
report={'region':'PAL' if pal else 'NTSC','player':label,'bank':hex(bank),'entry_splash_frames':sorted(frames),'entry_uploads':sorted(uploaded),'number_frames':sorted(seen_numbers),'number_uploads':sorted(number_uploads),'resurfacing_clears_numbers':True,'exit_splash':True}
if 'ObjectTest_Executed' in g.s:
    report['executed_ids']=[f'{i:02X}' for i in range(1,256) if g.read(g.s['ObjectTest_Executed']+i)]
(g.output/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True)
