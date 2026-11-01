#!/usr/bin/env python3
"""Check terrain sensors and foreground drawing across the authored Y seam.

Native checks run the MD level-load request and CD lookup/probe/draw code.
The optional game check stages falls, upward contacts and entries into all
eight authored SMZ2 tunnels, then uses normal frames. Visible VDP tiles are
checked throughout each journey. --probe records an older ROM's failures
without treating them as a pass.
"""
from pathlib import Path
from functools import lru_cache
import argparse
import ctypes as C
import json
import struct

from check_plane_engine import Drawing
from convert_s1_ss_background import kosinski_plus_decode
from level_layout import load
from native_test_core import (UC_M68K_REG_D0, UC_M68K_REG_D1, UC_M68K_REG_D2,
                              UC_M68K_REG_D3, UC_M68K_REG_D5,
                              UC_M68K_REG_D6, UC_M68K_REG_A1,
                              UC_M68K_REG_A2, UC_M68K_REG_A3,
                              UC_M68K_REG_A4)

ROOT = Path(__file__).resolve().parents[1]


def native_checks(args):
    d = Drawing(args.rom, args.listing)
    m, s, cpu = d.m, d.s, d.cpu
    rom = args.rom.read_bytes()
    failures, lookups, probes, edits, levels = [], 0, 0, 0, []

    def require(ok, **detail):
        if not ok and len(failures) < 32:
            failures.append(detail)

    def probe(routine, x, y, path, direction):
        d.put('MCD_TerrainPath_Sub', s['MCD_TerrainIndex_Sub']+path, 4)
        d.put('MCD_TerrainPrimary_Sub', 3, 1)
        solidity=12+path*2+int(routine.endswith('Wall') or direction<0)
        for reg, value in ((UC_M68K_REG_D2,y & 65535),
                           (UC_M68K_REG_D3,x), (UC_M68K_REG_D5,solidity),
                           (UC_M68K_REG_D6,(0x800 if routine.endswith('Floor') else 0x400) if direction < 0 else 0),
                           (UC_M68K_REG_A3,direction*16 & 0xFFFFFFFF),
                           (UC_M68K_REG_A4,s['MCD_TerrainPrimary_Sub'])):
            cpu.reg_write(reg, value)
        d.call(routine)
        return cpu.reg_read(UC_M68K_REG_D1)&65535, bytes(cpu.mem_read(s['MCD_TerrainPrimary_Sub'],1))[0]

    for name, zone in (('HTZ',5), ('SMZ',8)):
        for era, folder in enumerate(('', 'past/', 'good future/', 'bad future/')):
            m.start()
            m.write('Current_ZoneAndAct', zone*256+1, 2)
            m.write('Current_Timezone', era)
            m.act('GetLevelArtHeader')
            header = m.cpu.reg_read(UC_M68K_REG_A2)
            blocks, chunks = [kosinski_plus_decode(rom[struct.unpack_from('>I',rom,header+offset)[0]&0xFFFFFF:])[0]
                              for offset in (4,8)]
            fg, bg = load(ROOT/f'level/layout/{folder}{name}_2.kosp')
            d.install(fg,bg,chunks,blocks)
            minimum = struct.unpack_from('>H',rom,s['LevelSizeArray']+(zone*4+1)*8+4)[0]
            assert minimum & 0x8000, (name,'Expected an authored wrapping act')
            m.write('Camera_Min_Y_pos',minimum,2)
            m.write('MCD_TerrainIndexBytes',len(blocks)//4,2)
            m.act('LoadCollisionIndexes')
            # Use the real main-CPU transport and CD level-load entry, including
            # the top boundary. Supplying a mask directly would hide an ABI bug.
            m.act('MCD_LoadTerrain')
            d.wrap_foreground = True
            levels.append(f'{name}2/era{era}')
            for x in (0x20,0x180,0x280,0x830,len(fg[0])*128-16):
                for y in (-32,-1,0,15,0x7E0,0x7FF,0x800,0x810,0xFE0,0xFFF0):
                    cy = y & s['Level_YWrapMask']
                    cid = fg[cy//128][x//128]
                    expected = s['MCD_ChunkTable_SubStart']+cid*128+(cy//16&7)*16+(x//16&7)*2
                    cpu.reg_write(UC_M68K_REG_D2,y&65535)
                    cpu.reg_write(UC_M68K_REG_D3,x)
                    d.call('MCD_SubFindTerrainBlock')
                    require(cpu.reg_read(UC_M68K_REG_A1)==expected,case='chunk',level=levels[-1],x=x,y=y)
                    lookups += 1
                for routine in ('MCD_SubFindFloor','MCD_SubFindWall'):
                    for path in (0,1):
                        for direction in (-1,1):
                            for y in (-1,0,15,0x7F0,0x7FF,0x800,0x810,0xFFF0):
                                actual = probe(routine,x,y,path,direction)
                                expected = probe(routine,x,y&s['Level_YWrapMask'],path,direction)
                                require(actual==expected,case='distance/angle',level=levels[-1],routine=routine,
                                        path=path,direction=direction,x=x,y=y,actual=actual,expected=expected)
                                probes += 1
            # A script edit through the wrapped row must also change the
            # canonical row and the subsequently drawn terrain, without a copy.
            value=(fg[0][3]+1)%(len(chunks)//128)
            m.act('Layout_Write',regs={UC_M68K_REG_D0:0x1003,UC_M68K_REG_D1:value})
            m.act('Layout_Read',regs={UC_M68K_REG_D0:3})
            require(m.cpu.reg_read(UC_M68K_REG_D0)==value,case='wrapped layout edit',level=levels[-1])
            fg[0][3]=value
            edits += 1
            for y in (0x6E0,0x700,0x7E0,0x7F0,0,0xFFF0,0xFFE0):
                try:
                    d.draw(0x180,y,0x80,(y&2047)//8)
                except AssertionError as error:
                    require(False,case='foreground tiles',level=levels[-1],y=y,error=str(error))

    # A normal act keeps distinct terrain above $800, even with 32 authored rows.
    m.start()
    fg = [[row+1]*4 for row in range(32)]
    d.install(fg,[[0]],bytes(33*128),bytes(8))
    d.wrap_foreground = False
    m.write('Camera_Min_Y_pos',0x300,2)
    m.write('v_colladdr1',s['Col_SMZ2'],4)
    m.write('MCD_TerrainIndexBytes',2,2)
    m.act('MCD_LoadTerrain')
    for y in (0,0x7FF,0x800,0x9FF,0xFFF):
        cpu.reg_write(UC_M68K_REG_D2,y)
        cpu.reg_write(UC_M68K_REG_D3,0)
        d.call('MCD_SubFindTerrainBlock')
        expected=s['MCD_ChunkTable_SubStart']+(y//128+1)*128+(y//16&7)*16
        require(cpu.reg_read(UC_M68K_REG_A1)==expected,case='non-wrapping height',y=y)
        lookups += 1
    return dict(levels=levels,chunk_lookups=lookups,distance_angle_pairs=probes,layout_edits=edits,
                tile_samples=d.samples,failures=failures)


def game_checks(args):
    from genesis_test_core import Genesis
    from check_object_course import boot_level
    from check_companion_followup import place, isolate
    g=Genesis(args.core,args.rom,args.listing,args.output/'game',args.pal,
              system_directory=args.system_directory)
    boot_level(g,zone=8,act=1,player=args.player)
    base=g.save()
    rows=[]
    actors=('v_player','v_player2') if args.player==0 else ('v_player',)
    for actor in actors:
        for case,x,y,vy,frames in ([('floor',x,0x7C0,vy,48)
                                   for x in (0x180,0x280,0x400) for vy in (0x300,0xC00)]
                                  +[('ceiling',0x830,0x30,0xFA00,12)]):
            g.restore(base)
            isolate(g)
            other='v_player2' if actor=='v_player' else 'v_player'
            place(g,other,x,y,False)
            g.put(other,'obControl',0x81)
            place(g,actor,x,y)
            g.put(actor,'obVelY',vy,2)
            g.put(actor,'obStatusSecondary',2)
            g.put(actor,'invtime',6000,2)
            g.buttons2={4}
            g.write('Tails_CPU_idle_timer',600,2)
            g.write('Camera_X_pos',max(0,x-160),2)
            g.write('Camera_Y_pos',0x700 if case=='floor' else 0,2)
            g.write('Screen_redraw_flag',1)
            trace=[]
            for tick in range(frames):
                g.run()
                assert not g.read('v_errortype'),(case,actor,'ROM exception')
                trace.append([g.get(actor,'obY',2),g.get(actor,'obVelY',2),g.get(actor,'obStatus')])
            if case=='floor':
                expected=0x800-g.get(actor,'obHeight')-1
                passed=(g.get(actor,'obY',2)==expected and not g.get(actor,'obStatus')&2
                        and g.get(actor,'obVelY',2)==0)
            else:
                passed=all(y<0x100 for y,_,_ in trace) and any(vy<0x8000 for _,vy,_ in trace)
            label=f'{case}-{actor}-{x:x}-{vy:x}'
            rows.append(dict(case=label,passed=passed,trace=trace))
            g.video.save(args.output/'game'/(label+'.png'))
    rows.extend(pipe_checks(g,args,base))
    g.close()
    return dict(player=args.player,pal=args.pal,rows=rows,failures=[r for r in rows if not r['passed']])


def pipe_checks(g,args,base):
    from check_object_course import objects
    from check_companion_followup import place, reset_cpu
    from object_layout import decode
    fg,bg=load(ROOT/'level/layout/SMZ_2.kosp')
    rom=args.rom.read_bytes()
    header=g.s['LevelArtPointers']+(8*4+1)*12
    blocks,chunks=[kosinski_plus_decode(rom[struct.unpack_from('>I',rom,header+offset)[0]&0xFFFFFF:])[0]
                   for offset in (4,8)]
    vsram=(C.c_uint8*128).in_dll(g.core,'vsram')

    @lru_cache(None)
    def tile(plane,tx,ty):
        x,y=tx*8,ty*8
        cells=(fg,bg)[plane]
        cx,cy=(x&0x7FFF)//128,(y&(0xFFF if plane else g.s['Level_YWrapMask']))//128
        cid=(cells[cy%len(cells)][cx%len(cells[0])] if plane else
             cells[cy][cx] if cy<len(cells) and cx<len(cells[0]) else 0)
        entry=struct.unpack_from('>H',chunks,cid*128+(y//16&7)*16+(x//16&7)*2)[0]
        bx,by=(x//8&1)^bool(entry&0x400),(y//8&1)^bool(entry&0x800)
        return (struct.unpack_from('>H',blocks,(entry&1023)*8+(by*2+bx)*2)[0]
                ^(0x800 if entry&0x400 else 0)^(0x1000 if entry&0x800 else 0))

    def word(memory,address):
        return memory[address^1]*256+memory[(address+1)^1]

    rows=[]
    placements=[r for r in decode((ROOT/'level/objects/SMZ_2.bin').read_bytes()) if r[2]==0xAB]
    for x,packed_y,_,_,subtype in sorted(placements,key=lambda row:row[4]):
        g.restore(base)
        y=packed_y&0xFFF
        actors=('v_player','v_player2') if args.player==0 else ('v_player',)
        for actor in actors:
            place(g,actor,x-8 if packed_y&0x2000 else x+8,y,False)
            g.put(actor,'obControl',0x81)
            g.put(actor,'obStatusSecondary',2);g.put(actor,'invtime',6000,2)
        g.write('v_rings',99,2)
        g.buttons=g.buttons2=set();reset_cpu(g)
        g.buttons2={4};g.write('Tails_CPU_idle_timer',6000,2)
        camera_y=(y-96)&g.s['Level_YWrapMask']
        g.write('Camera_X_pos',max(0,x-160),2);g.write('Camera_Y_pos',camera_y,2)
        g.write('Camera_BG_X_pos',max(0,x-160)//4,2)
        g.write('Camera_BG_Y_pos',camera_y//8+1,2)
        g.write('Screen_redraw_flag',1);g.run(16)
        gate=next(a for a in objects(g,0xAB) if g.get(a,'obSubtype',2)==subtype)
        for actor in actors:g.put(actor,'obControl',0)
        errors=[];samples=0;trace=[];frames=[];camera_seams=0;previous=g.read('Camera_Y_pos',2)
        captured=False
        for tick in range(400):
            g.run()
            assert not g.read('v_errortype'),('pipe',subtype,tick)
            captured |= all(g.get(actor,'obControl')==0x81 for actor in actors)
            cy=g.read('Camera_Y_pos',2)
            crossed=abs(cy-previous)>0x400
            camera_seams+=crossed;previous=cy
            trace.append([g.get('v_player','obX',2),g.get('v_player','obY',2),cy])
            # Read the VDP's actual scroll and tile words every displayed frame;
            # the oracle uses authored cells, never constructor/cache contents.
            for plane in (0,1):
                py=word(vsram,plane*2)&0x7FF
                for sy in range(0,224,8):
                    wy=py+sy
                    scroll=word(g.vram,g.s['vram_hscroll']+sy*4+plane*2)
                    if scroll&0x8000:scroll-=65536
                    for sx in range(0,320,8):
                        wx=(sx-scroll)&65535
                        address=(0xE000 if plane else 0xC000)+(wy//8&31)*128+(wx//8&63)*2
                        actual=word(g.vram,address);expected=tile(plane,wx//8,wy//8)
                        if actual!=expected and len(errors)<4:
                            errors.append(dict(tick=tick,plane=plane,screen=[sx,sy],source=[wx,wy],actual=actual,expected=expected))
                        samples+=1
            if subtype in (0,6) and tick%2==0:frames.append(g.video.copy())
            if tick in (64,80,96) or crossed:
                g.video.save(args.output/'game'/f'pipe-{subtype}-{tick}.png')
            if tick>3 and captured and all(not g.get(actor,'obControl') for actor in actors):break
        completed=captured and all(not g.get(actor,'obControl') for actor in actors)
        rows.append(dict(case=f'pipe-{subtype}',passed=completed and not errors,frames=tick+1,
                         completed=completed,camera_seams=camera_seams,tile_samples=samples,
                         graphics_errors=errors,trace=trace))
        if frames:
            frames[0].save(args.output/'game'/f'pipe-{subtype}.gif',save_all=True,append_images=frames[1:],
                           duration=40 if args.pal else 34,loop=0)
        g.video.save(args.output/'game'/f'pipe-{subtype}-exit.png')
    return rows


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--core',type=Path)
    p.add_argument('--system-directory',type=Path)
    p.add_argument('--player',type=int,choices=(0,2),default=0)
    p.add_argument('--pal',action='store_true')
    p.add_argument('--probe',action='store_true')
    args=p.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    report=dict(native=native_checks(args))
    if args.core:report['game']=game_checks(args)
    (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n',newline='\r\n')
    print(json.dumps({key:{k:v for k,v in value.items() if k!='rows'} for key,value in report.items()},indent=2))
    if not args.probe:
        assert not any(value['failures'] for value in report.values())


if __name__=='__main__':main()
