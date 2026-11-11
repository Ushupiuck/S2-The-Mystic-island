#!/usr/bin/env python3
"""Check flame masks, atlas isolation and real per-act fireball uploads/rendering."""
from pathlib import Path
import argparse,json,struct,subprocess
from check_sprite_assets import frames
from check_ehz_boss import symbols
from import_ehz2_pp_background import nemesis
from import_scrap_madness import mapping
from check_boss_shared_art import unpack

ROOT = Path(__file__).resolve().parents[1]
WARM = {0,2,3,4,5,6,13,14,15}


def assets(a):
	rom = a.rom.read_bytes(); s = symbols(a.listing)
	balls = (ROOT/'art/uncompressed/Fireballs.unc').read_bytes()
	pipe = (ROOT/'art/uncompressed/SBZ Flaming Pipe.unc').read_bytes()
	atlas = (ROOT/'art/uncompressed/SMZ Sprite Atlas.unc').read_bytes()
	assert unpack(rom,s['Kospm_Fireballs'])==balls
	assert len(balls)==44*32 and len(pipe)==28*32
	assert nemesis((ROOT/'art/nemesis/S1/SBZ Flaming Pipe.nem').read_bytes())==pipe
	assert nemesis((ROOT/'art/nemesis/SMZ Sprite Atlas.nem').read_bytes())==atlas
	for data in (balls,pipe[:20*32]):
		assert {n for b in data for n in (b>>4,b&15)}==WARM
	assert s['ArtTile_Fireball']+len(balls)//32<=s['ArtTile_Springs']
	assert s['ArtTile_EHZ_Seesaw']+62<=s['ArtTile_Fireball']
	rows = frames(rom,s['Map_Fireballs'],6)
	assert all(len(row)==1 and row[0][2]&0xF800==0 for row in rows)
	if a.s1disasm:
		for name,data in (('Fireballs',balls),('SBZ Flaming Pipe',pipe)):
			original = nemesis((a.s1disasm/f'artnem/{name}.nem').read_bytes())
			assert [bool(n) for b in original for n in (b>>4,b&15)]==[bool(n) for b in data for n in (b>>4,b&15)],name
			if name=='SBZ Flaming Pipe':assert original[20*32:]==pipe[20*32:]
		assert rows==frames(mapping((a.s1disasm/'_maps/Fireballs.asm').read_text()))
	if a.reference:
		def old(path):return subprocess.check_output(['git','show',a.reference+':'+path],cwd=ROOT)
		before = old('art/uncompressed/SMZ Sprite Atlas.unc')
		changed = {i for i in range(len(atlas)//32) if atlas[i*32:(i+1)*32]!=before[i*32:(i+1)*32]}
		assert changed
		for path in (ROOT/'mappings/sprite').glob('SMZ *.bin'):
			assert path.read_bytes()==old(str(path.relative_to(ROOT))),path
			if path.name=='SMZ Flame.bin':continue
			for row in frames(path.read_bytes()):
				for _,size,word,_ in row:
					assert not changed & set(range(word&2047,(word&2047)+((size>>2)+1)*((size&3)+1)))
		for path in (ROOT/'palette').glob('*.bin'):
			assert path.read_bytes()==old(str(path.relative_to(ROOT))),path
	for zone in ('EHZ','HTZ'):
		for act in range(1,5):
			pos=s[f'PLCKosM_{zone}{act}'];assert struct.unpack_from('>H',rom,pos)[0]==0
			assert struct.unpack_from('>IH',rom,pos+2)==(s['Kospm_Fireballs'],s['ArtTile_Fireball']*32)
	return ['source silhouettes, all warm slots, six S1 mappings, isolated atlas edit and eight module lists']


def game(a):
	from genesis_test_core import Genesis
	from check_object_course import boot_level,objects
	from check_companion_followup import place
	from object_layout import decode
	checks=[];rom=a.rom.read_bytes();balls=(ROOT/'art/uncompressed/Fireballs.unc').read_bytes()
	springs=nemesis((ROOT/'art/nemesis/Springs.nem').read_bytes())
	for zone in (3,5,8):
		for act in range(4 if zone!=8 else 2):
			out=a.output/f'{zone}-{act+1}';g=Genesis(a.core,a.rom,a.listing,out,a.pal,system_directory=a.system_directory)
			boot_level(g,zone=zone,act=act);s=g.s
			def vram(at,size):return bytes(g.vram[(at+i)^1] for i in range(size))
			if zone!=8:
				assert vram(s['ArtTile_Fireball']*32,len(balls))==balls,(zone,act,'fireball upload')
				assert vram(s['ArtTile_Springs']*32,len(springs))==springs,(zone,act,'spring overlap')
				if act==0:
					pool=[p for p in range(s['v_lvlobjspace'],s['v_lvlobjend'],s['object_size']) if not g.get(p,'code')][-6:]
					assert len(pool)==6
					for actor in ('v_player','v_player2'):g.put(actor,'obControl',0x81)
					for flip in range(4):
						for i,obj in enumerate(pool):
							for field,value,n in (('code',s['DisplaySprite'],4),('obMap',s['Map_Fireballs'],4),('obGfx',s['ArtTile_Fireball']|0x8000,2),('obRender',4|flip,1),('obPriority',0x80,2),('height_pixels',32,1),('obActWid',32,1),('obFrame',i,1),('obX',g.read('Camera_X_pos',2)+32+i*48,2),('obY',g.read('Camera_Y_pos',2)+60,2)):
								g.put(obj,field,value,n)
						g.run(3)
						found=set()
						for i in range(g.read('v_spritecount')):
							word=g.read(s['Sprite_Table']+i*8+4,2)
							if s['ArtTile_Fireball']<=word&2047<s['ArtTile_Fireball']+44:
								assert word&0x6000==0 and word&0x1800==flip<<11
								found.add((word&2047)-s['ArtTile_Fireball'])
						assert found=={0,8,16,22,30,38},(zone,flip,found)
						g.video.save(out/f'fireballs-{flip}.png')
				checks.append(f'zone {zone} act {act+1}: real module upload and intact springs' + ('; six rendered poses, four flips' if act==0 else ''))
			else:
				x,y,_,_,sub=next(row for row in decode((ROOT/f'level/objects/SMZ_{act+1}.bin').read_bytes()) if row[2]==0xA7)
				y&=0xFFF
				for actor in ('v_player','v_player2'):
					place(g,actor,x-80,max(64,y-80));g.put(actor,'obControl',0x81)
				g.write('Camera_X_pos',max(0,x-160),2);g.write('Camera_Y_pos',max(0,y-112),2)
				for _ in range(60):g.run()
				body=next(p for p in objects(g,0xA7) if g.get(p,'obX',2)==x)
				for flip in (0,2):
					g.put(body,'obStatus',flip);g.put(body,'obRoutine',0);g.put(body,'obAnim',0);g.put(body,'obPrevAni',255)
					seen=set();colors=set();hits=0
					for tick in range(500):
						g.run();frame=g.get(body,'obFrame');seen.add(frame)
						assert not g.read('v_errortype')
						assert bool(g.get(body,'obColType'))==(frame==(21 if flip else 10))
						hits+=bool(g.get(body,'obColType'))
						for _,size,word,_ in frames(rom,s['Map_SMZ_Flame'],22)[frame]:
							total=(word+g.get(body,'obGfx',2))&65535
							if total&0x6000:continue
							data=vram((total&2047)*32,((size>>2)+1)*((size&3)+1)*32)
							colors.update(n for b in data for n in (b>>4,b&15))
						if tick==80:g.video.save(out/f'flame-{flip}.png')
					assert seen==set(range(11,22) if flip else range(11)),(act,flip,seen)
					assert colors==WARM and hits>50,(act,flip,colors,hits)
				checks.append(f'SMZ{act+1}: both emitters, all 22 frames and original harmful-frame gating')
			g.close()
	return checks


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin');p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--output',type=Path,required=True);p.add_argument('--s1disasm',type=Path);p.add_argument('--reference')
	p.add_argument('--core',type=Path);p.add_argument('--system-directory',type=Path);p.add_argument('--pal',action='store_true')
	a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True);checks=assets(a)
	if a.core:checks+=game(a)
	(a.output/'report.json').write_text(json.dumps(dict(passed=True,checks=checks),indent=2)+'\n')
	print('\n'.join(checks),flush=True)


if __name__=='__main__':main()
