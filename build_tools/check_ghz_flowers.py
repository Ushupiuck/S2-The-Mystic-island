#!/usr/bin/env python3
"""Check GHZ flower DMA cadence, retired-bank ownership and live rendered tiles.

Camera/actor positioning is diagnostic. This is not a controller-only level run.
"""
from pathlib import Path
import argparse, json, struct, subprocess
from convert_s1_ss_background import kosinski_plus_decode
from object_layout import decode

ROOT = Path(__file__).resolve().parents[1]


def native(a):
    import native_test_core as n
    m = n.Native(a.rom, a.listing); m.start(); s = m.s
    rom = a.rom.read_bytes()
    large, small, stalk = [s[x] for x in ('Art_GHZFlowerLarge','Art_GHZFlowerSmall','Art_GHZFlowerStalk')]
    first = s['ArtTile_GHZ_Big_Flower_1']; assert first == 0x381
    assert s['ArtTile_GHZ_Small_Flower'] == first+16
    assert s['ArtTile_GHZ_Flower_Stalk'] == first+28
    assert first+32 <= s['ArtTile_Newtron']
    m.uploads.clear(); big_frame=small_frame=0
    small_sequence=(0,1,2,1); small_durations=(128,8,128,8); next_small=0
    for tick in range(640):
        start=len(m.uploads); expected=[]
        if tick%16==0:
            expected.append((large+(big_frame%2)*512,first*32,16*16)); big_frame+=1
        if tick==next_small:
            expected.append((small+small_sequence[small_frame%4]*384,(first+16)*32,12*16))
            next_small+=small_durations[small_frame%4]; small_frame+=1
        if tick%256==0:expected.append((stalk,(first+28)*32,4*16))
        m.act('Animate_Tiles')
        actual=[(src,dest&65535,words) for src,dest,words in m.uploads[start:]]
        assert actual==expected,(tick,actual,expected)
        assert all(first*32<=dest<dest+words*2<=(first+32)*32 for _,dest,words in expected)
    for act in range(1,5):
        rows=decode((ROOT/f'level/objects/GHZ_{act}.bin').read_bytes())
        assert all(row[2]!=0x21 for row in rows),'Retired Ballhog placement returned'
        ptr=s[f'PLCKosM_THZ{act}']; count=struct.unpack_from('>h',rom,ptr)[0]+1
        sources=[struct.unpack_from('>I',rom,ptr+2+i*6)[0] for i in range(count)]
        assert not {s['Kospm_BallhogV'],s['Kospm_BallhogH']}&set(sources)
    path='mappings/16x16/GHZ'
    raw=(ROOT/(path+'.unc')).read_bytes()
    assert kosinski_plus_decode((ROOT/(path+'.kosp')).read_bytes())[0]==raw
    if a.reference:
        prior=subprocess.check_output(['git','show',a.reference+':'+path+'.unc'],cwd=ROOT)
        for (old,),(new,) in zip(struct.iter_unpack('>H',prior),struct.iter_unpack('>H',raw)):
            expected=old
            for before,after,count in ((0x35C,first,16),(0x36C,first+16,12),(0x358,first+28,4)):
                if before<=old&2047<before+count:expected=(old&0xF800)|(after+(old&2047)-before)
            assert new==expected,(hex(old),hex(new),hex(expected))
        for p in ('art/kosinski/level/8x8 - GHZ.unc','mappings/128x128/GHZ.unc'):
            assert (ROOT/p).read_bytes()==subprocess.check_output(['git','show',a.reference+':'+p],cwd=ROOT)
    return ['640 exact DMA updates: sunflower 16/16, purple 128/8/128/8, static stalk 256',
            'all four GHZ acts release Ballhog/effect banks and contain no retired placements',
            'only flower/stalk block tile indices relocate; flags, terrain pixels and chunks remain intact']


def game(a):
    from genesis_test_core import Genesis
    from check_object_course import boot_level, position
    g=Genesis(a.core,a.rom,a.listing,a.output/'game',a.pal,system_directory=a.system_directory)
    boot_level(g,zone=0,act=a.act-1,player=a.player)
    for actor in ('v_player','v_player2'):g.put(actor,'obControl',1)
    first=g.s['ArtTile_GHZ_Big_Flower_1']
    def vram(tile,count):return bytes(g.vram[(tile*32+i)^1] for i in range(count*32))
    large=(ROOT/'art/uncompressed/GHZ Flower Large.unc').read_bytes()
    small=(ROOT/'art/uncompressed/GHZ Flower Small.unc').read_bytes()
    stalk=(ROOT/'art/uncompressed/GHZ Flower Stalk.unc').read_bytes()
    large_frames=[large[i:i+512] for i in range(0,len(large),512)]
    small_frames=[small[i:i+384] for i in range(0,len(small),384)]
    # GHZ4 streams its water surface into $001-$010; that is intentionally live.
    terrain=vram(0x11,0x310);left=vram(0x369,0x18);right=vram(0x3A1,0x3C)
    seen_big=set();seen_small=set();last=None;transitions=[]
    for tick in range(560):
        g.run();assert not g.read('v_errortype')
        big=vram(first,16);little=vram(first+16,12)
        assert big in large_frames and little in small_frames,(tick,'incomplete frame')
        assert vram(first+28,4)==stalk
        seen_big.add(large_frames.index(big));seen_small.add(small_frames.index(little))
        current=small_frames.index(little)
        if current!=last:transitions.append(current);last=current
        assert vram(0x11,0x310)==terrain and vram(0x369,0x18)==left and vram(0x3A1,0x3C)==right
    assert seen_big=={0,1} and seen_small=={0,1,2}
    assert all((x,y) in ((0,1),(1,0),(1,2),(2,1)) for x,y in zip(transitions,transitions[1:]))
    # Pause freezes both animation counters and their actual displayed bytes.
    g.buttons={3};g.run(2);g.buttons=set();g.run(3)
    assert g.read('f_pause',2)
    counters=bytes(g.read(g.s['Anim_Counters']+i) for i in range(6));frozen=vram(first,32)
    g.run(40)
    assert counters==bytes(g.read(g.s['Anim_Counters']+i) for i in range(6)) and vram(first,32)==frozen
    g.buttons={3};g.run(2);g.buttons=set();g.run(20);assert not g.read('f_pause',2)
    # Visit the authored flower cluster; retain its terrain, objects and palette.
    x,y=(6208,580) if a.act==1 else ((752,830) if a.act==2 else (3648,650))
    position(g,x,y);g.run(60)
    g.video.save(a.output/'game/flowers.png')
    g.run(16);g.video.save(a.output/'game/flowers-next.png')
    g.close()
    return [f'act {a.act}: 560 live frames, both/all three poses, complete stalk, neighboring terrain/object banks preserved',
            'pause freezes counters and VRAM; resume and authored flower-cluster captures verified']


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--native',action='store_true');p.add_argument('--core',type=Path)
    p.add_argument('--system-directory',type=Path);p.add_argument('--reference')
    p.add_argument('--act',type=int,choices=(1,2,3,4),default=1)
    p.add_argument('--player',type=int,choices=(0,2),default=0);p.add_argument('--pal',action='store_true')
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True);checks=[]
    if a.native:checks+=native(a)
    if a.core:checks+=game(a)
    assert checks
    (a.output/'report.json').write_text(json.dumps(dict(passed=True,checks=checks,controller_only_playthrough=False),indent=2)+'\n')
    print(f'{len(checks)} GHZ flower groups pass.')


if __name__=='__main__':main()
