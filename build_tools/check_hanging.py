#!/usr/bin/env python3
"""Exercise D9's real 68000 grab, traversal, support and spawned-child paths."""
import argparse
import json
import struct
from pathlib import Path
import native_test_core as c


def native(args):
    m = c.Manager(args.rom, args.listing)
    o = next(iter(m.pool()))
    rows = []

    def fixture(subtype=0, actor='v_player', x=0x800, y=0x200):
        m.start()
        m.write('Camera_X_pos_coarse_back', x-0x100, 2)
        m.write('Camera_X_pos', x-0x80, 2)
        m.put(o, 'code', m.s['HangingSurface'])
        m.put(o, 'obX', x, 2); m.put(o, 'obY', y, 2)
        m.put(o, 'obSubtype', subtype)
        m.act('HangingSurface', o)
        m.put(actor, 'obMap', m.s['Map_Tails' if actor == 'v_player2' else 'Map_Sonic'], 4)
        m.put(actor, 'obStatus', 2)
        m.put(actor, 'obX', x, 2)
        m.put(actor, 'obY', y+(12 if subtype & 0x80 else 30), 2)
        m.put(actor, 'character_id', int(actor == 'v_player2'))
        m.act('HangingSurface', o)
        assert m.get(actor, 'obControl') == 3, ('grab', subtype, actor)
        return actor

    def tick(control=0, actor='v_player', count=1):
        m.write('v_jpadholdlogical' + ('2' if actor == 'v_player2' else ''), control, 2)
        for _ in range(count):
            m.act('HangingSurface', o)

    for who, record in [('v_player', 'Hang_p1'), ('v_player2', 'Hang_p2')]:
        for settings in (0, 0x80, 0x84, 0xC4, 0x200, 0xF880):
            fixture(settings, who)
            assert m.get(o, 'obSubtype') == settings
            assert not m.get(who, 'obStatus') & 8
            assert m.get(who, 'obY', 2) == 0x200+(18 if settings & 128 else 36)
            tick(actor=who, count=40)
            assert m.get(who, 'obControl') == 3
            tick(0x10, who)
            assert not m.get(who, 'obControl')
            assert m.get(who, 'obVelY', 2) == 0xFC80
            assert m.get(who, 'jumping') == 1
            assert m.get(who, 'obStatus') & 6 == 6
            assert m.get(o+m.s[record], 'Hang_active') == 0
            assert m.get(who, 'obMap', 4) == m.s['Map_Tails' if who == 'v_player2' else 'Map_Sonic']
        rows.append(who + ': word settings, classic/traversable grab, neutral rolling jump, map restoration')

        # Every alternating FBZ step follows the exact original offset sequence.
        fixture(0x84, who)
        m.put(who, 'obX', 0x800-48, 2)
        start = m.get(who, 'obX', 2)
        expected=start
        for step,offsets,poses in [(0,(6,10,12,4),(5,0,1,6)),(1,(4,12,12,4),(2,3,4,6))]:
            for frame in range(25):
                tick(0x800,who)
                if frame%8==0:
                    expected+=offsets[frame//8]
                    pose=poses[frame//8]
                    if who=='v_player2':pose=(0x80,0x81,0x82,0x83,0x84,0x85,0x91)[pose]
                    assert m.get(who,'obFrame')==pose,(who,step,frame,'pose')
                assert m.get(who,'obX',2)==expected,(who,step,frame,'step offset')
        assert m.get(who, 'obX', 2) == start+64, (who, 'two right steps')
        assert m.get(who, 'obControl') == 3
        tick(0x400, who, 96)
        assert m.get(who, 'obX', 2) == 0x800-48
        assert m.get(who, 'obControl') == 3
        rows.append(who + ': alternating 32-pixel steps, both directions and retained endpoints')

        fixture(0, who)
        tick(0x810, who)
        assert m.get(who, 'obVelX', 2) == 0x200
        assert m.get(o+m.s[record], 'Hang_cooldown') == 60
        fixture(0, who)
        m.put(who, 'obRoutine', 4)
        tick(actor=who)
        assert not m.get(who, 'obControl')
        assert not m.get(o+m.s[record], 'Hang_active')
        rows.append(who + ': directional release and hurt cleanup')

        # An actual one-way or full-solid landing invokes the shared callback.
        for full in (False, True):
            for gap in (40, 1, 0, -2):
                fixture(0, who)
                foot = m.get(who, 'obY', 2)+19
                platform = o+m.s['object_size']
                m.put(platform, 'code', m.s['Obj18'])
                m.put(platform, 'obX', 0x800, 2)
                m.put(platform, 'obY', foot+gap+(49 if full else 9), 2)
                m.put(platform, 'obSubtype', 0x100 if full else 0)
                m.act('Obj18', platform)
                if full:
                    # Full-body radius is 48, while the constructor defaults to
                    # 8 for a top-only platform. Use the actual top surface.
                    m.put(platform, 'obY', foot+gap+49, 2)
                    m.put(platform, 'Plat_rawY', foot+gap+49, 2)
                m.put(platform, 'obRender', 0x84)
                m.act('Plat_Full' if full else 'Plat_Top', platform)
                assert bool(m.get(who, 'obControl')) == (gap > 3), (who, full, gap, 'support')
                if gap <= 3:
                    assert m.get(who, 'obStatus') & 8
                    assert not m.get(who, 'obStatus') & 2
        rows.append(who + ': real top/full-solid landings; distant objects leave grip alone')

    # Parent ownership, pool failure/retry, both simultaneous actor arrangements,
    # parent movement including sag and cleanup on cull or external deletion.
    for bottom, top in [('v_player', 'v_player2'), ('v_player2', 'v_player')]:
        m.start();m.write('Camera_X_pos_coarse_back',0x700,2)
        m.write('Camera_Max_Y_pos',0x1000,2)
        for f,v,n in [('code',m.s['Obj18'],4),('obSubtype',0x681,2),('obX',0x800,2),('obY',0x200,2)]:m.put(o,f,v,n)
        m.act('Obj18',o)
        child=m.get(o,'Plat_hanger',2)|0xFFFF0000
        assert child & 65535
        assert m.get(child,'respawn_addr',2)==0
        assert m.get(child,'Hang_parent',2)==o&65535
        m.put(bottom,'obStatus',2);m.put(bottom,'obX',m.get(child,'obX',2),2)
        m.put(bottom,'obY',m.get(child,'obY',2)+30,2)
        m.put(top,'obStatus',2);m.put(top,'obX',m.get(o,'obX',2),2)
        m.put(top,'obY',m.get(o,'obY',2)-8-19+2,2)
        m.put(top,'obVelY',0x100,2)
        for _ in range(20):m.act('Plat_Top',o)
        assert m.get(bottom,'obControl')==3
        assert m.get(top,'obStatus')&8
        m.act('Plat_Unload',o)
        assert not m.get(child,'code') and not m.get(bottom,'obControl')
        rows.append(bottom+': child follows moving/sagging platform while other actor rides above; cull releases both')
    m.start();m.write('Camera_X_pos_coarse_back',0x700,2)
    for obj in m.pool():m.put(obj,'code',m.s['ObjNull'])
    m.put(o,'code',m.s['Obj18']);m.put(o,'obX',0x800,2);m.put(o,'obY',0x200,2);m.put(o,'obSubtype',0x600)
    m.act('Obj18',o);assert not m.get(o,'Plat_hanger',2)
    free=o+m.s['object_size'];m.put(free,'code',0)
    m.act('Plat_Top',o);assert m.get(o,'Plat_hanger',2)==free&65535
    rows.append('full pool leaves parent working; later free slot spawns exactly one child')

    for zone,mapname,table_index in [(0,'Map_Obj18_GHZ',0),(3,'Map_Obj18_EHZ',2)]:
        for shape in (0,1):
            for full in (False,True):
                m.start();m.write('Current_Zone',zone);m.write('Camera_X_pos_coarse_back',0x700,2)
                m.put(o,'code',m.s['Obj18']);m.put(o,'obX',0x800,2);m.put(o,'obY',0x200,2)
                m.put(o,'obSubtype',(0x700 if full else 0x600)|(shape<<4))
                m.act('Obj18',o);child=m.get(o,'Plat_hanger',2)|0xFFFF0000
                from check_sprite_assets import frames
                rom=(args.rom or c.ROOT/'s2built.bin').read_bytes()
                pieces=frames(rom,m.s[mapname])[shape]
                bottom=max(y+((size&3)+1)*8 for y,size,_,_ in pieces)
                authored=int.from_bytes(m.cpu.mem_read(m.s['Plat_HangingBottoms']+(table_index+shape)*2,2),'big')
                assert authored==bottom
                assert m.get(child,'Hang_yoffset',2)==max(bottom,48 if full else 8)-10
    rows.append('GHZ/EHZ shape bottoms match mappings; spawned hands clear both visible art and full solidity')

    # An owner removed outside its normal unload path cannot leave a live grip.
    m.start();m.write('Camera_X_pos_coarse_back',0x700,2)
    m.put(o,'code',m.s['Obj18']);m.put(o,'obX',0x800,2);m.put(o,'obY',0x200,2);m.put(o,'obSubtype',0x600)
    m.act('Obj18',o);child=m.get(o,'Plat_hanger',2)|0xFFFF0000
    m.put('v_player','obStatus',2);m.put('v_player','obX',0x800,2)
    m.put('v_player','obY',m.get(child,'obY',2)+30,2)
    m.act('Plat_Top',o);assert m.get('v_player','obControl')==3
    m.act('DeleteObject',o);m.act('Hanging_Child',child)
    assert not m.get(child,'code') and not m.get('v_player','obControl')
    rows.append('externally deleted parent retires its orphan and releases the hanging player')

    from check_sprite_assets import frames
    rom=(args.rom or c.ROOT/'s2built.bin').read_bytes()
    for zone,index,mapping,rail in [(0,0,'Map_Obj17','Map_SwingRail'),(6,1,'Map_Obj17_SLZ','Map_SwingRail_SLZ'),(8,2,'Map_SMZ_Swing','Map_SwingRail_SMZ')]:
        # Use engine zone constants rather than assuming the classic SLZ ID.
        if index==1:zone=m.s['id_SLZ']
        if index==2:zone=m.s['id_SMZ']
        bottom=int.from_bytes(m.cpu.mem_read(m.s['SwingingPtfm_HangingBottoms']+index,1),'big')
        for label in (mapping,rail):
            assert bottom==max(y+((size&3)+1)*8 for y,size,_,_ in frames(rom,m.s[label])[0]),label
        m.start();m.write('Current_Zone',zone);m.write('Camera_X_pos_coarse_back',0x700,2)
        for f,v,n in [('code',m.s['SwingingPtfm'],4),('obX',0x800,2),('obY',0x180,2),('obSubtype',0x625,2)]:m.put(o,f,v,n)
        m.act('SwingingPtfm',o);m.act('SwingingPtfm_Interact',o)
        child=m.get(o,'swing_hanger',2)|0xFFFF0000
        assert m.get(child,'Hang_yoffset',2)==(bottom-10)&65535
    rows.append('GHZ/SLZ/SMZ grip heights match body and ICZ-rail mapping bottoms')

    # Swinging grip profiles keep packed links and an independent two-player
    # controller. The same child follows the released physical body.
    for profile in (6,7,8,9):
        for bottom,top in [('v_player','v_player2'),('v_player2','v_player')]:
            m.start();m.write('Camera_X_pos_coarse_back',0x700,2)
            for f,v,n in [('code',m.s['SwingingPtfm'],4),('obX',0x800,2),('obY',0x180,2),('obSubtype',(profile<<8)|0x1025,2)]:m.put(o,f,v,n)
            m.act('SwingingPtfm',o);m.act('SwingingPtfm_Interact',o)
            child=m.get(o,'swing_hanger',2)|0xFFFF0000
            assert child&65535
            m.put(bottom,'obStatus',2);m.put(bottom,'obX',m.get(child,'obX',2),2);m.put(bottom,'obY',m.get(child,'obY',2)+30,2)
            m.put(top,'obStatus',2);m.put(top,'obX',m.get(o,'obX',2),2);m.put(top,'obY',m.get(o,'obY',2)-m.get(o,'obHeight')-19+2,2);m.put(top,'obVelY',0x100,2)
            m.put(o,'obRender',0x94);m.act('SwingingPtfm_Interact',o)
            assert m.get(bottom,'obControl')==3 and m.get(top,'obStatus')&8,(profile,bottom,'swing grab')
            m.put(o,'swing_mode_timer',29,2);m.act('SwingingPtfm_DetachCheck',o)
            body=m.get(o,'swing_relative',2)|0xFFFF0000
            assert body&65535 and m.get(body,'code')==m.s['SwingingPtfm']
            assert not m.get(o,'swing_hanger',2) and m.get(body,'swing_hanger',2)==child&65535
            assert m.get(child,'Hang_parent',2)==body&65535
            assert m.get(child,'Hang_parentlink',2)==(body+m.s['swing_hanger'])&65535
            m.put(body,'obY',m.get(body,'obY',2)+12,2);m.act('SwingingPtfm_UpdateHanging',body)
            assert m.get(bottom,'obControl')==3 and m.get(bottom,'obY',2)==m.get(child,'obY',2)+36
            m.act('SwingingPtfm_DelAll',o)
            assert not m.get(child,'code') and not m.get(bottom,'obControl')
    rows.append('swing top/full/conveyor grips: both rider arrangements, detach transfers one child, group deletion releases it')
    m.start();m.write('Camera_X_pos_coarse_back',0x700,2)
    for obj in m.pool():m.put(obj,'code',m.s['ObjNull'])
    for f,v,n in [('code',m.s['SwingingPtfm'],4),('obX',0x800,2),('obY',0x180,2),('obSubtype',0x625,2)]:m.put(o,f,v,n)
    m.act('SwingingPtfm',o);m.act('SwingingPtfm_Interact',o);assert not m.get(o,'swing_hanger',2)
    free=o+m.s['object_size'];m.put(free,'code',0);m.act('SwingingPtfm_Interact',o)
    assert m.get(o,'swing_hanger',2)==free&65535
    m.act('DeleteObject',o);m.act('Hanging_Child',free);assert not m.get(free,'code')
    rows.append('swing grip allocation retries with a full pool; external parent deletion retires orphan')

    for profile in (8,9):
        m.start();m.write('Camera_X_pos_coarse_back',0x700,2);m.write('Camera_Max_Y_pos',0x1000,2)
        for f,v,n in [('code',m.s['Obj18'],4),('obX',0x800,2),('obY',0x200,2),('obSubtype',(profile<<8)|0x1080,2)]:m.put(o,f,v,n)
        m.act('Obj18',o);child=m.get(o,'Plat_hanger',2)|0xFFFF0000
        for who,y in [('v_player',m.get(o,'obY',2)-m.get(o,'obHeight')-19+2),('v_player2',m.get(child,'obY',2)+30)]:
            m.put(who,'obX',m.get(o,'obX',2),2);m.put(who,'obY',y,2);m.put(who,'obStatus',2);m.put(who,'obVelY',0x100,2)
        m.put(o,'obRender',0x94);m.act('Plat_Top',o)
        assert m.get('v_player','obStatus')&8 and m.get('v_player2','obControl')==3
        for frame in range(80):
            for who in ('v_player','v_player2'):m.put(who,'conveyor_applied',0)
            m.act('Plat_Top',o)
            if m.get(o,'code')==m.s['Plat_FallingIntangible']:break
            assert m.get('v_player2','obControl')==3,(profile,frame,'early grip release')
            # Keep the upper rider on the belt for this isolated falling test.
            m.put('v_player','obX',m.get(o,'obX',2),2)
        assert m.get(o,'code')==m.s['Plat_FallingIntangible'] and not m.get(child,'code')
        assert not m.get('v_player2','obControl') and not m.get('v_player','obStatus')&8
    rows.append('falling conveyor with underside grip: both solidity variants carry standing/hanging players, then release at intangible transition')

    for who, record in [('v_player', 'Hang_p1'), ('v_player2', 'Hang_p2')]:
        for flip in (0, 1):
            fixture(0xC4, who)
            m.put(o, 'obStatus', flip)
            m.put(who, 'obX', 0x800+(48 if flip else -48), 2)
            tick(0x400 if flip else 0x800, who, 80)
            assert not m.get(who, 'obControl'), ('final grip', who, flip)
            m.put(o+m.s[record], 'Hang_cooldown', 0)
            tick(actor=who)
            assert not m.get(who, 'obControl'), 'release end must not immediately recapture'
        fixture(0x100, who)
        platform=o+m.s['object_size']
        for f,v,n in [('code',m.s['Obj18'],4),('obX',0x800,2),('obY',0x240,2)]:m.put(platform,f,v,n)
        m.act('Obj18',platform);m.put(platform,'obRender',0x84)
        m.act('Plat_Top',platform)
        assert m.get(who,'obControl')==3, 'disabled object support release'
        fixture(0, who)
        m.put(who,'obControl',0);m.put(who,'obRoutine',4)
        m.put(who,'obFrame',0x4E if who=='v_player' else 0xA5)
        tick(actor=who)
        assert not m.get(o+m.s[record],'Hang_active')
        assert not m.get(who,'obControl')
        if who=='v_player':assert m.get(who,'obMap',4)==m.s['Map_Sonic']
    rows.append('both endpoint directions, excluded final grabs, disabled support and externally cleared hurt control')

    # Preserve the old visible pose when the complete requested DMA cannot fit.
    fixture(0)
    old=m.get('v_player','obFrame')
    m.put(o+m.s['Hang_p1'],'Hang_frame',1)
    regs={c.UC_M68K_REG_A1:m.s['v_player']&0xFFFFFFFF,
          c.UC_M68K_REG_A2:(o+m.s['Hang_p1'])&0xFFFFFFFF}
    m.write('VDP_Command_Buffer_Slot',m.s['VDP_Command_Buffer_Slot']&65535,2)
    m.act('Hanging_DrawPlayer',o,regs=regs)
    assert m.get('v_player','obFrame')==old
    m.write('VDP_Command_Buffer_Slot',0,2)
    m.act('Hanging_DrawPlayer',o,regs=regs)
    assert m.get('v_player','obFrame')==1
    rows.append('atomic hanging-pose DMA failure and retry')

    # Actual GHZ4 terrain, through the real MD or CD paired-foot executor.
    from convert_s1_ss_background import kosinski_plus_decode
    for disabled in (False, True):
        for who in ('v_player','v_player2'):
            fixture(0x100 if disabled else 0,who,x=0x400,y=0x2F0)
            for symbol,file in [('Chunk_Table','mappings/128x128/GHZ.kosp'),
                                ('v_lvllayout','level/layout/GHZ_4.kosp')]:
                m.cpu.mem_write(m.s[symbol]&0xFFFFFF,kosinski_plus_decode((c.ROOT/file).read_bytes())[0])
            for label,value in [('v_colladdr1',m.s['Col_GHZ4']),('v_colladdr2',m.s['Col_GHZ4']+1),('Collision_addr',m.s['Col_GHZ4'])]:m.write(label,value,4)
            tick(actor=who)
            assert m.get(who,'obControl')==3,'distant terrain released grip'
            m.act('loc_13146',who)
            distance=m.cpu.reg_read(c.UC_M68K_REG_D1)&65535
            assert 0<distance<32,distance
            m.put(o,'obY',m.get(o,'obY',2)+distance+1,2)
            tick(actor=who)
            assert bool(m.get(who,'obControl'))==disabled,('terrain',who,disabled)
            if not disabled:assert not m.get(who,'obStatus')&2
    rows.append('both players: actual terrain distance, contact correction and disabled-support option')

    # All new mappings/DPLC ranges stay within Sonic's existing 32-tile bank.
    from check_sprite_assets import frames
    rom=(args.rom or c.ROOT/'s2built.bin').read_bytes()
    table=m.s['DPLC_HangingSonic']
    art_size=(c.ROOT/'art/uncompressed/Sonic hanging.unc').stat().st_size
    for i,pieces in enumerate(frames(rom,m.s['Map_HangingSonic'],7)):
        start=table+struct.unpack_from('>h',rom,table+i*2)[0]
        count=struct.unpack_from('>H',rom,start)[0];loaded=0
        for j in range(count):
            run=struct.unpack_from('>H',rom,start+2+j*2)[0]
            n=(run>>12)+1;assert ((run&4095)+n)*32<=art_size;loaded+=n
        assert loaded<=32
        for _,size,tile,_ in pieces:assert (tile&2047)+((size>>2)+1)*((size&3)+1)<=loaded
    assert m.s['Art_HangingSonic']%2==0
    rows.append('seven Sonic poses: complete DPLC sources, mapping bounds and unchanged 32-tile destination')

    # One helper renders a viewport-sized subset of the full authored row.
    # Exercise every count, edge alignments and a camera far from the origin.
    grip_maps=frames(rom,m.s['Map_HangingSurface'],11)
    for n,pieces in enumerate(grip_maps,1):
        assert len(pieces)==n*2
        assert [(x+8,y,size,tile) for y,size,tile,x in pieces] == [
            (16-n*16+i*32,y,size,tile) for i in range(n)
            for y,size,tile in ((-20,5,0),(-4,6,4))]
    for count in range(64):
        n=count or 1
        centres=[0x1000-n*16+16+i*32 for i in range(n)]
        for camera in (centres[0]-328,centres[0]-327,centres[0]-160,
                       centres[0]+7,centres[0]+8,0x1000,centres[-1]+8):
            m.start();m.write('Camera_X_pos',camera,2)
            m.write('Camera_X_pos_coarse_back',camera&0xFF80,2)
            m.put(o,'code',m.s['HangingSurface']);m.put(o,'obX',0x1000,2)
            m.put(o,'obY',0x200,2);m.put(o,'obSubtype',0x80|count)
            # Views intentionally outside the retained loading interval still
            # exercise Display directly, independently of lifetime culling.
            m.act('HangingSurface',o)
            if not m.get(o,'code'):
                m.put(o,'code',m.s['HangingSurface']);m.put(o,'obSubtype',0x80|count)
                m.put(o,'obX',0x1000,2);m.put(o,'obY',0x200,2)
                m.put(o,'Hang_halfwidth',n*16,2)
            m.act('Hanging_Display',o)
            visible=[x for x in centres if camera-7<=x<=camera+327]
            if visible:
                helper=m.get(o,'Hang_display',2)|0xFFFF0000
                assert m.get(helper,'code')==m.s['Hanging_DisplayHelper']
                assert m.get(helper,'obFrame')==len(visible)-1,(count,camera,visible)
                assert m.get(helper,'obX',2)==(visible[0]+visible[-1])//2
                assert m.get(helper,'obY',2)==0x200-20
                assert m.get(o,'obX',2)==0x1000
                assert sum(bool(m.get(obj,'code')) for obj in m.pool())==2
                m.put(o,'obSubtype',0x480|count);m.act('Hanging_Display',o)
                assert not m.get(o,'Hang_display',2) and not m.get(helper,'code')
    rows.append('all 64 count encodings: repeated mappings, viewport clipping and hidden-art cleanup; two SSTs total')

    m.start();m.write('Camera_X_pos',0xF80,2);m.write('Camera_X_pos_coarse_back',0xF00,2)
    for obj in m.pool():m.put(obj,'code',m.s['ObjNull'])
    m.put(o,'code',m.s['HangingSurface']);m.put(o,'obX',0x1000,2)
    m.put(o,'obY',0x200,2);m.put(o,'obSubtype',0x88)
    m.act('HangingSurface',o);assert not m.get(o,'Hang_display',2)
    free=o+m.s['object_size'];m.put(free,'code',0)
    m.act('HangingSurface',o);assert m.get(o,'Hang_display',2)==free&65535
    m.act('DeleteObject',o);m.act('Hanging_DisplayHelper',free)
    assert not m.get(free,'code')
    # A reused helper slot belongs to its new object and must survive cleanup.
    fixture(0x88);helper=m.get(o,'Hang_display',2)|0xFFFF0000
    m.put(helper,'code',m.s['ObjNull']);m.act('Hanging_ReleaseAll',o)
    assert m.get(helper,'code')==m.s['ObjNull']
    rows.append('display pool failure/retry, orphan deletion and reused-slot protection')

    bank=m.s['ArtTile_HangingSurface']*32
    assert struct.unpack_from('>H',rom,m.s['Nem_HangingSurface'])[0]&0x7FFF==12
    def loads(label,module=False):
        pos=m.s[label]
        for i in range(struct.unpack_from('>h',rom,pos)[0]+1):
            src,dest=struct.unpack_from('>IH',rom,pos+2+i*6)
            size=struct.unpack_from('>H',rom,src)[0]
            if not module:size=(size&0x7FFF)*32
            yield src,dest,dest+size
    for zone,act,module in [('GHZ',4,'THZ')]+[('LZ',a,'RRZ') for a in range(1,5)]:
        loaded=list(loads('PLC_'+zone+str(act)+'_Main'))+list(loads('PLC_'+zone+str(act)+'_Extra'))+list(loads('PLCKosM_'+module+str(act),True))
        assert sum(src==m.s['Nem_HangingSurface'] and dest==bank for src,dest,end in loaded)==1
        for src,start,end in loaded:
            assert src==m.s['Nem_HangingSurface'] or end<=bank or start>=bank+384,(zone,act,hex(src))
    rows.append('GHZ4 and four LZ acts: resident handhold PLC and non-overlapping live object banks')

    def chain_fixture(subtype=0x410, grab=True):
        m.start();m.write('Camera_X_pos',0x780,2);m.write('Camera_X_pos_coarse_back',0x700,2)
        m.write('Camera_Y_pos',0x180,2)
        m.put(o,'code',m.s['PullChain']);m.put(o,'obX',0x800,2)
        m.put(o,'obY',0x200,2);m.put(o,'obSubtype',subtype)
        m.act('PullChain',o)
        child=m.get(o,'Pull_hanger',2)|0xFFFF0000
        assert m.get(child,'code')==m.s['Hanging_Child']
        assert m.get(child,'Hang_snapX')==1
        if grab:
            for actor,dx in [('v_player',-8),('v_player2',8)]:
                m.put(actor,'obMap',m.s['Map_Tails' if actor=='v_player2' else 'Map_Sonic'],4)
                m.put(actor,'character_id',int(actor=='v_player2'))
                m.put(actor,'obStatus',2);m.put(actor,'obX',0x800+dx,2)
                m.put(actor,'obY',m.get(child,'obY',2)+30,2)
            m.act('PullChain',o)
            assert all(m.get(actor,'obControl')==3 and m.get(actor,'obX',2)==0x800 for actor in ('v_player','v_player2'))
        return child

    for reverse in (False,True):
        child=chain_fixture(0x410|(0x80 if reverse else 0))
        assert m.get(o,'Pull_extension',2)==(128 if reverse else 0)
        for frame in range(1,13):
            m.act('PullChain',o)
            assert m.get(o,'Pull_extension',2)==(128-frame*2 if reverse else frame*2)
            for actor in ('v_player','v_player2'):
                assert m.get(actor,'obY',2)==0x200+64+m.get(o,'Pull_extension',2)+60
        m.write('v_jpadholdlogical',0x10,2);m.act('PullChain',o);m.write('v_jpadholdlogical',0,2)
        assert not m.get('v_player','obControl') and m.get('v_player2','obControl')==3
        before=m.get(o,'Pull_extension',2)
        for _ in range(8):m.act('PullChain',o)
        assert m.get(o,'Pull_extension',2)==before+(-16 if reverse else 16)
        m.write('v_jpadholdlogical2',0x10,2);m.act('PullChain',o);m.write('v_jpadholdlogical2',0,2)
        for actor in ('v_player','v_player2'):m.put(actor,'obX',0x900,2)
        before=m.get(o,'Pull_extension',2);m.act('PullChain',o)
        assert m.get(o,'Pull_extension',2)==before+(2 if reverse else -2)
        for _ in range(80):m.act('PullChain',o)
        assert m.get(o,'Pull_extension',2)==(128 if reverse else 0)
        assert m.get(o,'Pull_anchorY',2)==0x200
    rows.append('DA: centred two-player grabs, exact 2px lowering/raising, one-player release and return only after both leave')

    for sub in (0,0xF490):
        child=chain_fixture(sub)
        assert m.get(o,'obSubtype')==sub
        assert m.get(child,'obSubtype')==(0x300 if sub else 0)
        m.act('PullChain_Unload',o)
        assert not m.get(o,'code') and not m.get(child,'code')
        assert all(not m.get(actor,'obControl') for actor in ('v_player','v_player2'))
    child=chain_fixture();m.act('DeleteObject',o);m.act('Hanging_Child',child)
    assert not m.get(child,'code') and not m.get('v_player','obControl')
    m.start();m.write('Camera_X_pos_coarse_back',0x700,2)
    for obj in m.pool():m.put(obj,'code',m.s['ObjNull'])
    m.put(o,'code',m.s['PullChain']);m.put(o,'obX',0x800,2);m.put(o,'obY',0x200,2);m.put(o,'obSubtype',0x410)
    m.act('PullChain',o);assert not m.get(o,'Pull_hanger',2)
    m.put(o+m.s['object_size'],'code',0);m.act('PullChain',o)
    assert m.get(o,'Pull_hanger',2)==(o+m.s['object_size'])&65535
    rows.append('DA: stationary grip, word flags, full-pool retry, cull and externally deleted parent cleanup')

    chain_maps=frames(rom,m.s['Map_PullChain'],30)
    for length in (0,2,16,18,64,128,240,1016,1256):
        for camera in (0x160,0x1FF,0x200,0x201,0x280,0x380,0x600):
            m.start();m.write('Camera_Y_pos',camera,2)
            m.put(o,'code',m.s['PullChain']);m.put(o,'obX',0x800,2)
            m.put(o,'obPriority',0x80,2)
            m.put(o,'Pull_anchorY',0x200,2);m.put(o,'Pull_extension',length,2)
            m.act('PullChain_Draw',o)
            top=0x200+length;total=(length+15)//16
            expected=[top-total*16+i*16 for i in range(total) if camera-15<=top-total*16+i*16<=camera+223]
            grip=camera-39<=top<=camera+223
            queued=int.from_bytes(m.cpu.mem_read((m.s['v_spritequeue']+0x80)&0xFFFFFF,2),'big')
            assert bool(queued)==bool(expected or grip),(length,camera,'visibility')
            if queued:
                pieces=chain_maps[m.get(o,'obFrame')];cy=m.get(o,'obY',2)
                actual=[cy+y for y,size,tile,x in pieces if tile==10]
                assert actual==expected,(length,camera,actual,expected)
                assert [(cy+y,tile) for y,size,tile,x in pieces if tile!=10]==([(top,0),(top+16,4)] if grip else [])
                assert len(pieces)<=17
    rows.append('DA: exact chain/grip mappings and viewport clipping through the maximum 1256px chain')
    return rows


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom',type=Path);p.add_argument('--listing',type=Path)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    checks=native(args)
    (args.output/'native.json').write_text(json.dumps(checks,indent=2)+'\n')
    print('\n'.join('PASS '+row for row in checks))


if __name__=='__main__':main()
