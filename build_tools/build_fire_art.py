#!/usr/bin/env python3
"""Pack the editable S1 fireballs and Scrap Madness flame art.

--import-s1 seeds the editable sheets from s1disasm 2c51d46. Normal packing
preserves those sheets, the SMZ mapping layout and all unrelated atlas tiles.
"""
from pathlib import Path
from collections import deque
import argparse
from build_end_art import pack_moduled
from check_sprite_assets import frames
from import_ehz2_pp_background import nemesis
from import_scrap_madness import nemesis_compress

ROOT = Path(__file__).resolve().parents[1]
FIREBALL_RECTS = ((0,2,4),(8,2,4),(16,2,3),(22,4,2),(30,4,2),(38,3,2))
# Original flame/hardware rectangles, identified by their first mapped appearance.
PIPE_RECTS = ((1,0,0,1,2),(3,0,2,2,3),(7,0,8,3,4),(0,0,20,2,2),(11,0,24,2,2))


def rectangle(raw, first, width, height):
	return [[(raw[(first+(x//8)*height+y//8)*32+(y&7)*4+(x&7)//2]
		>> (0 if x&1 else 4)) & 15 for x in range(width*8)] for y in range(height*8)]


def store_rectangle(raw, first, pixels):
	height, width = len(pixels), len(pixels[0])
	for x in range(width):
		for y in range(height):
			at = (first+(x//8)*(height//8)+y//8)*32+(y&7)*4+(x&7)//2
			shift = 0 if x&1 else 4
			raw[at] = (raw[at] & ~(15<<shift)) | pixels[y][x]<<shift


def distances(pixels, inside):
	"""Four-neighbor distance from a color region's boundary, including edges."""
	h, w = len(pixels), len(pixels[0]); distance = [[0]*w for _ in range(h)]; queue = deque()
	for y in range(h):
		for x in range(w):
			if not inside(pixels[y][x]):
				continue
			if any(not (0<=nx<w and 0<=ny<h) or not inside(pixels[ny][nx])
				for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1))):
				distance[y][x] = 1; queue.append((x,y))
	while queue:
		x,y = queue.popleft()
		for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
			if 0<=nx<w and 0<=ny<h and inside(pixels[ny][nx]) and not distance[ny][nx]:
				distance[ny][nx] = distance[y][x]+1; queue.append((nx,ny))
	return distance


def shade_s1(pixels, rim=(13,13,2,3), shadows=(14,14,15)):
	# LRZ's flame/Fireworm reference uses a white core, yellow/orange rim and
	# red edge. Our player line provides four warm slots in place of its yellow.
	# Keep S1's masks and shadow regions; expand the interior's flat fills.
	# Keep broad bright-red tongues and medium-red shadows. Reserve the
	# darkest red for internal folds; the pipe uses a wider body rim.
	edge = distances(pixels, bool)
	core = distances(pixels, lambda c:c in (6,15))
	result = [row[:] for row in pixels]
	for y,row in enumerate(pixels):
		for x,color in enumerate(row):
			assert color in (0,6,12,13,14,15), color
			if color == 12:
				result[y][x] = rim[min(edge[y][x],len(rim))-1]
			elif color in (13,14):
				result[y][x] = shadows[min(edge[y][x],len(shadows))-1]
			elif color == 15:
				result[y][x] = (4,5,6)[min(core[y][x],3)-1]
	return result


def import_s1(source):
	balls = bytearray(nemesis((source/'artnem/Fireballs.nem').read_bytes()))
	pipe = bytearray(nemesis((source/'artnem/SBZ Flaming Pipe.nem').read_bytes()))
	assert len(balls)==44*32 and len(pipe)==28*32
	for first,w,h in FIREBALL_RECTS:
		store_rectangle(balls,first,shade_s1(rectangle(balls,first,w,h)))
	for _,_,first,w,h in PIPE_RECTS:
		if first<20:
			store_rectangle(pipe,first,shade_s1(rectangle(pipe,first,w,h),
				rim=(13,13,13,2,3),shadows=(14,14,15)))
	(ROOT/'art/uncompressed/Fireballs.unc').write_bytes(balls)
	(ROOT/'art/uncompressed/SBZ Flaming Pipe.unc').write_bytes(pipe)


def build():
	balls = (ROOT/'art/uncompressed/Fireballs.unc').read_bytes()
	pipe = (ROOT/'art/uncompressed/SBZ Flaming Pipe.unc').read_bytes()
	assert len(balls)==44*32 and len(pipe)==28*32
	(ROOT/'art/moduled kosinski/Fireballs.kospm').write_bytes(pack_moduled(balls))
	atlas_path = ROOT/'art/uncompressed/SMZ Sprite Atlas.unc'
	before = atlas_path.read_bytes(); atlas = bytearray(before)
	rows = frames((ROOT/'mappings/sprite/SMZ Flame.bin').read_bytes())
	for frame,piece,first,w,h in PIPE_RECTS:
		_,size,word,_ = rows[frame][piece]
		assert size==(w-1)*4+h-1 and not word&0x1800
		assert word>>13&3 == (0 if first<20 else 2)
		at = (word&2047)*32
		atlas[at:at+w*h*32] = pipe[first*32:(first+w*h)*32]
	changed = {i for i in range(len(atlas)//32) if atlas[i*32:(i+1)*32]!=before[i*32:(i+1)*32]}
	for path in (ROOT/'mappings/sprite').glob('SMZ *.bin'):
		if path.name=='SMZ Flame.bin':
			continue
		for row in frames(path.read_bytes()):
			for _,size,word,_ in row:
				tiles = set(range(word&2047,(word&2047)+((size>>2)+1)*((size&3)+1)))
				assert not tiles&changed, ('Flame tiles shared with another object',path,tiles&changed)
	(ROOT/'art/nemesis/S1/SBZ Flaming Pipe.nem').write_bytes(nemesis_compress(pipe))
	atlas_path.write_bytes(atlas)
	(ROOT/'art/nemesis/SMZ Sprite Atlas.nem').write_bytes(nemesis_compress(atlas))
	print(f'44 fireball tiles; {len(changed)} SMZ atlas tiles updated; mappings and hardware retained.')


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--import-s1',type=Path,metavar='CHECKOUT')
	a = p.parse_args()
	if a.import_s1:
		import_s1(a.import_s1)
	build()


if __name__=='__main__':
	main()
