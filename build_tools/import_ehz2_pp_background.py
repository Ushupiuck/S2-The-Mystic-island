#!/usr/bin/env python3
"""Give EHZ2 a private foreground bank and PP Present's upright background.

Source: sonicretro/scddisasm f8cf3f0af7bf419d18182ba98554f09307ad3cc6.
Uses the final upright 512x512 panel (source Y $600), excluding the mirrored
ramp scenery. Retains the complete shared terrain and authored chunk table,
including unplaced tunnels and walls. PP tiles/chunks follow the shared bank.
Regeneration deliberately overwrites the independent EHZ2 editable outputs.
"""
from pathlib import Path
from collections import Counter
import argparse
import json
import struct
import re
from convert_s1_ss_background import kosinski_plus
from level_layout import load, save
from check_sprite_assets import frames
from sprite_palette import remap_pixels
from build_ehz2_waterfall_art import outputs as waterfall_outputs

ROOT = Path(__file__).resolve().parents[1]
SOURCE_REVISION = 'f8cf3f0af7bf419d18182ba98554f09307ad3cc6'
CROP_Y = 0x600


def nemesis(data):
	header = int.from_bytes(data[:2], 'big')
	position, color, table = 2, 0, {}
	while data[position] != 255:
		entry = data[position]; position += 1
		if entry & 128:
			color = entry & 15; entry = data[position]; position += 1
		table[entry & 15, data[position]] = (color, (entry >> 4) + 1)
		position += 1
	position = (position + 1) * 8
	def bits(count):
		nonlocal position
		value = 0
		for _ in range(count):
			value = value * 2 + ((data[position//8] >> (7-position%8)) & 1)
			position += 1
		return value
	pixels, target = [], (header & 0x7FFF) * 64
	while len(pixels) < target:
		code = 0
		for length in range(1, 9):
			code = code * 2 + bits(1)
			if length == 6 and code == 63:
				count, color = bits(3)+1, bits(4); break
			if (length, code) in table:
				color, count = table[length, code]; break
		else:
			raise ValueError('Invalid Nemesis code')
		pixels.extend([color]*count)
	assert len(pixels) == target
	raw = bytes((a << 4) | b for a,b in zip(pixels[::2],pixels[1::2]))
	if header & 0x8000:
		previous, rows = 0, bytearray()
		for row, in struct.iter_unpack('>I',raw):
			previous ^= row; rows.extend(previous.to_bytes(4,'big'))
		raw = bytes(rows)
	return raw


def words(raw, count):
	return [list(struct.unpack_from('>'+str(count)+'H',raw,i))
			for i in range(0,len(raw),count*2)]


def encode_words(rows):
	return b''.join(struct.pack('>'+str(len(row))+'H',*row) for row in rows)


def tile_pixels(data):
	return [v for byte in data for v in (byte >> 4, byte & 15)]


def rgb(value):
	return (value & 14, (value >> 4) & 14, (value >> 8) & 14)


def distance(a,b):
	return sum((x-y)**2 for x,y in zip(rgb(a),rgb(b)))


def midpoint(a, b):
	"""Nearest MD color to the channel mean; resolve equal choices toward PP."""
	channels = []
	for left, right in zip(rgb(a), rgb(b)):
		channels.append(min(range(0,16,2), key=lambda value:
							(abs(value*2-left-right), abs(value-right))))
	return channels[0] | channels[1]<<4 | channels[2]<<8


def write_asset(path, data):
	(ROOT/(path+'.unc')).write_bytes(data)
	(ROOT/(path+'.kosp')).write_bytes(kosinski_plus(data))


def build(source, output):
	constants = (ROOT/'_definitions/s2.constants.asm').read_text()
	def allocation(name):
		match = re.search(r'^'+re.escape(name)+r':\s*equ\s+\$([0-9A-Fa-f]+)\b', constants, re.M)
		assert match, 'Expected literal art allocation '+name
		return int(match[1],16)
	level_base = allocation('ArtTile_Level')
	static_end = allocation('ArtTile_Fireball')
	flower_base = allocation('ArtTile_Art_Flowers1')
	waterfall_base = allocation('ArtTile_EHZ2_BGWaterfall')
	waterfall_count = allocation('ArtTile_EHZ2_BGWaterfall_Count')
	assert level_base == 0 and flower_base == 0x394, 'Review terrain/animation allocation before regenerating'
	assert waterfall_base + waterfall_count <= static_end
	data = source/'src/Level/Palmtree Panic/Data'
	pp_art = nemesis((data/'Tiles (Act 1 Present).nem').read_bytes())
	pp_blocks = words(nemesis((data/'Blocks (Act 1 Present).nem').read_bytes()),4)
	pp_chunks = words((data/'Chunks (Act 1 Present).bin').read_bytes(),256)
	pp_layout = (data/'Background (Act 1 Present).bin').read_bytes()
	assert pp_layout[:2] == bytes((5,7))
	pp_palette = list(struct.unpack('>48H',(data/'Palette (Present).bin').read_bytes()))[32:]
	art = (ROOT/'art/kosinski/level/8x8 - EHZ.unc').read_bytes()
	blocks = words((ROOT/'mappings/16x16/EHZ.unc').read_bytes(),4)
	chunks = words((ROOT/'mappings/128x128/EHZ.unc').read_bytes(),64)
	paths = sorted((ROOT/'level/layout').rglob('EHZ_2.kosp'))
	layouts = {p:load(p)[0] for p in paths}
	fg_chunks = {v for plane in layouts.values() for row in plane for v in row}
	fg_blocks = set(range(6)) | {v & 1023 for cid in fg_chunks for v in chunks[cid]}
	fg_words = {w for bid in fg_blocks for w in blocks[bid]}
	keep_tiles = set(range(len(art)//32))
	common_blocks = {w & 1023 for row in chunks for w in row}
	era_names = ('present','past','good Future','bad future')
	common_collision = {(era): (ROOT/f'collision/{era}/EHZ1.bin').read_bytes() for era in era_names}
	# Obj18 uses terrain pixels with fixed IDs and palette line 2.
	platform_tiles = set()
	for frame in frames((ROOT/'mappings/sprite/18 - EHZ platform mappings.bin').read_bytes()):
		for _,size,tile,_ in frame:
			start = level_base+(tile & 2047)
			platform_tiles.update(range(start,start+((size>>2)+1)*((size&3)+1)))
	keep_tiles |= platform_tiles
	# Consolidate the two close foreground greens with the PP greens already
	# present in this row. A/B then hold fixed cyans for the baked waterfalls.
	green_lookup = list(range(16))
	green_lookup[10], green_lookup[11] = 13, 12
	owners = {}
	for w in (w for row in blocks for w in row):
		owners.setdefault(w & 2047, set()).add(w >> 13 & 3)
	for tid in platform_tiles:
		owners.setdefault(tid, set()).add(2)
	adapted_art = bytearray(art)
	for tid, lines in owners.items():
		if 2 not in lines or tid * 32 >= len(art):
			continue
		raw = art[tid * 32:(tid + 1) * 32]
		adapted = remap_pixels(raw, green_lookup)
		assert lines == {2} or raw == adapted, ('Shared terrain tile needs a palette variant', tid, lines)
		adapted_art[tid * 32:(tid + 1) * 32] = adapted
	art = bytes(adapted_art)
	assert not keep_tiles & set(range(waterfall_base, waterfall_base + waterfall_count))
	original_pal = list(struct.unpack('>48H',(ROOT/'palette/EHZ.bin').read_bytes()))
	palette = original_pal.copy()
	# These five foreground shades differ from PP by one channel step only.
	# Their mathematical midpoint lies between MD colors, so the tie selects
	# the PP endpoint. Pixel indices stay fixed; no character colors change.
	blend_targets = {16+1:0x000, 16+3:0x024, 16+5:0x06A,
						16+7:0x0EE, 16+9:0x042}
	for index, target in blend_targets.items():
		palette[index] = midpoint(original_pal[index], target)
		assert distance(original_pal[index], palette[index]) <= 4
	# Background waterfalls now keep their cliff browns on P2 and animate tiles.
	# P3 1/3/6 cycle; 2/4/5 hold fixed water blues. The flower ramp stays 7-F.
	# Other foreground/object colors and all palette indices remain fixed.
	# Merge the almost-white EEC cloud highlight into fixed white. Its freed
	# slot holds E86, so dark cloud pixels do not borrow the waterfall cycle.
	additions = {10:0xE86, 11:0xEC8,
					16+8:0x0A6, 16+10:0xEEA, 16+11:0xCC6, 16+13:0x064,
					32+1:0xEEA, 32+2:0xE64, 32+3:0xCC6, 32+4:0xEC8, 32+5:0xE86}
	used = set()
	for w in fg_words:
		tid, line = w & 2047, (w >> 13) & 3
		pixels = art[tid*32:(tid+1)*32]
		if 0x394 <= tid < 0x39C:
			number, part = (tid-0x394)//2+1, (tid-0x394)%2
			raw = (ROOT/f'art/uncompressed/EHZ flowers - {number}.bin').read_bytes()
			pixels = b''.join(raw[i+part*32:i+part*32+32] for i in range(0,len(raw),64))
		if line:
			used |= {(line-1)*16+i for i in tile_pixels(pixels) if i}
	for tid in platform_tiles:
		used |= {16+i for i in tile_pixels(art[tid*32:(tid+1)*32]) if i}
	for filename,line in (('EHZ bridge.nem',2),('Waterfall tiles.nem',1)):
		used |= {(line-1)*16+i for i in tile_pixels(nemesis((ROOT/'art/nemesis'/filename).read_bytes())) if i}
	# The shared HUD selects level palette line 1. Its shadow and gray digit
	# highlights are live even when no terrain tile references those slots.
	hud_colors = set()
	for filename in ('art/nemesis/HUD.nem', 'art/uncompressed/HUD Numbers.bin',
						'art/uncompressed/Lives Counter Numbers.bin',
						'art/uncompressed/Points.unc', 'art/uncompressed/Ring.bin',
						'art/nemesis/Tails Life Text.nem'):
		raw = (ROOT/filename).read_bytes()
		if filename.endswith('.nem'):
			raw = nemesis(raw)
		hud_colors.update(tile_pixels(raw))
	hud_colors.update(tile_pixels(nemesis((ROOT/'art/nemesis/Sonic lives counter.nem').read_bytes())[4*32:]))
	used |= hud_colors - {0}
	protected_changes = [(i, hex(original_pal[i]), hex(value)) for i, value in additions.items()
						if i in used and i not in (16+8, 16+13) and original_pal[i] != value]
	assert not protected_changes, ('Palette addition overwrites an EHZ2 foreground/object/HUD color', protected_changes)
	for i,value in additions.items(): palette[i] = value
	for i in (0,16,32): palette[i] = 0xA00  # PP sky backdrop; pixel zero remains transparent.
	(ROOT/'palette/EHZ2 PP.bin').write_bytes(struct.pack('>48H',*palette))
	tiles = [art[i*32:(i+1)*32] for i in range(len(art)//32)]
	tile_ids = {tile:i for i,tile in enumerate(tiles) if i in keep_tiles}
	tile_ids[bytes(32)] = 0
	block_data = [row.copy() for row in blocks]
	block_ids = {tuple(row):i for i,row in enumerate(block_data)}
	block_ids[(0,0,0,0)] = 0
	chunk_data = [row.copy() for row in chunks]
	chunk_ids = {tuple(row):i for i,row in enumerate(chunk_data)}
	reserved_tiles = set(range(waterfall_base, waterfall_base + waterfall_count)) | set(range(flower_base,flower_base+10))
	free_tiles = iter(i for i in range(len(tiles),static_end) if i not in reserved_tiles)
	free_blocks = iter(i for i,row in enumerate(blocks) if not any(row) and i not in common_blocks
		and all(not any(data[i*2:i*2+2]) for data in common_collision.values()))
	free_chunks = iter(range(len(chunks),1024))
	assigned_tiles, assigned_blocks, assigned_chunks = set(keep_tiles),set(range(len(blocks))),set(range(len(chunks)))
	errors = Counter(); tile_cache = {}
	waterfall_tiles, waterfall_ids = [], {}
	def add(rows, index, value, free, assigned):
		value = tuple(value) if isinstance(value,list) else value
		if value not in index:
			slot = next(free)
			while len(rows) <= slot: rows.append(bytes(32) if rows is tiles else [0]*(4 if rows is block_data else 64))
			rows[slot] = value; index[value] = slot; assigned.add(slot)
		return index[value]
	def tile_at(x,y):
		cid = pp_layout[2+(y//256)*6+x//256] & 127
		entry = pp_chunks[cid-1][(y//16 & 15)*16+(x//16 & 15)]
		tx,ty = (x//8 & 1)^bool(entry & 0x800),(y//8 & 1)^bool(entry & 0x1000)
		word = pp_blocks[entry & 1023][ty*2+tx]
		if not word & 2047: return 0
		assert word >> 13 & 3 == 3, hex(word)
		raw = tile_pixels(pp_art[(word & 2047)*32:(word & 2047)*32+32])
		flip_x = bool(word & 0x800)^bool(entry & 0x800)
		flip_y = bool(word & 0x1000)^bool(entry & 0x1000)
		raw = [raw[(py^(7 if flip_y else 0))*8+(px^(7 if flip_x else 0))] for py in range(8) for px in range(8)]
		animated = y < CROP_Y + 384 and any(v in (1, 2, 3) for v in raw)
		water = y >= CROP_Y + 384
		key = (animated, water, tuple(raw))
		if key in tile_cache: return tile_cache[key]
		if animated:
			pixels = bytes((a << 4) | b for a, b in zip(raw[::2], raw[1::2]))
			if pixels not in waterfall_ids:
				waterfall_ids[pixels] = len(waterfall_tiles)
				waterfall_tiles.append(pixels)
			result = (waterfall_base + waterfall_ids[pixels]) | 0x4000
			tile_cache[key] = result
			return result
		counts = Counter(v for v in raw if v)
		candidates = []
		if water:
			# PP's sparse EEC glints join the EEA animation entry. The other
			# fixed blues stay distinct; all three original cycling roles survive.
			lookup = {1:6, 2:1, 3:3, 4:2, 10:1, 11:4, 12:5}
			assert counts.keys() <= lookup.keys(), counts
			candidates.append((0, 2, lookup))
		for line in (() if water else range(3)):
			cycling = ({2,3,4,5},set(),{1,3,6})[line]
			slots = [i for i in range(1,16) if i not in cycling]
			lookup = {v:min(slots,key=lambda i:distance(pp_palette[v],palette[line*16+i])) for v in counts}
			error = sum(counts[v]*distance(pp_palette[v],palette[line*16+lookup[v]]) for v in counts)
			candidates.append((error,line,lookup))
		_,line,lookup = min(candidates,key=lambda v:(v[0],v[1]))
		for v in raw:
			if v: errors[distance(pp_palette[v],palette[line*16+lookup[v]])] += 1
		adapted = [lookup[v] if v else 0 for v in raw]
		pixels = bytes((a<<4)|b for a,b in zip(adapted[::2],adapted[1::2]))
		tid = add(tiles,tile_ids,pixels,free_tiles,assigned_tiles)
		result = tid | (line+1)*0x2000
		tile_cache[key] = result
		return result
	bg_blocks = []
	for by in range(32):
		row = []
		for bx in range(32):
			values = [tile_at(bx*16+px*8,CROP_Y+by*16+py*8) for py in range(2) for px in range(2)]
			row.append(add(block_data,block_ids,values,free_blocks,assigned_blocks))
		bg_blocks.append(row)
	bg = []
	for cy in range(4):
		row = []
		for cx in range(4):
			values = [bg_blocks[cy*8+y][cx*8+x] for y in range(8) for x in range(8)]
			row.append(add(chunk_data,chunk_ids,values,free_chunks,assigned_chunks))
		bg.append(row)
	assert len(waterfall_tiles) == waterfall_count
	waterfall_source = b''.join(waterfall_tiles)
	(ROOT / 'art/uncompressed/EHZ2 Background Waterfall Source.unc').write_bytes(waterfall_source)
	waterfall_assets = waterfall_outputs(waterfall_source)
	for name, raw in waterfall_assets.items():
		(ROOT / name).write_bytes(raw)
	first_frame = waterfall_assets['art/uncompressed/EHZ2 Background Waterfall.unc'][:waterfall_count * 32]
	while len(tiles) < waterfall_base + waterfall_count:
		tiles.append(bytes(32))
	for i in range(waterfall_count):
		tiles[waterfall_base + i] = first_frame[i * 32:(i + 1) * 32]
	while len(tiles) < flower_base + 10:
		tiles.append(bytes(32))
	for i,name in enumerate(('EHZ flowers - 1.bin','EHZ flowers - 2.bin','EHZ flowers - 3.bin','EHZ flowers - 4.bin','EHZ Pulse Ball.bin')):
		frame = (ROOT/'art/uncompressed'/name).read_bytes()[:64]
		tiles[flower_base+i*2:flower_base+i*2+2] = [frame[:32],frame[32:]]
	assigned_tiles |= reserved_tiles
	# Preserve authored definitions, with new PP content in safe blank slots or appended banks.
	tiles = tiles[:max(assigned_tiles)+1];block_data=block_data[:max(assigned_blocks)+1];chunk_data=chunk_data[:max(assigned_chunks)+1]
	assert all(tiles[i] == art[i*32:(i+1)*32] for i in keep_tiles)
	assert all(list(block_data[i]) == blocks[i] for i in fg_blocks)
	assert all(list(block_data[i]) == blocks[i] for i,row in enumerate(blocks) if any(row) or i in common_blocks)
	assert all(list(chunk_data[i]) == row for i,row in enumerate(chunks))
	write_asset('art/kosinski/level/8x8 - EHZ2',b''.join(tiles))
	write_asset('mappings/16x16/EHZ2',encode_words(block_data))
	write_asset('mappings/128x128/EHZ2',encode_words(chunk_data))
	for path,fg in layouts.items(): save(path,fg,bg)
	for era in era_names:
		path=ROOT/f'collision/{era}/EHZ2.bin';original=path.read_bytes()
		indices=bytearray(common_collision[era])
		indices.extend(bytes(max(0,len(block_data)*2-len(indices))))
		for i in fg_blocks:
			if i*2+2<=len(original): indices[i*2:i*2+2]=original[i*2:i*2+2]
		path.write_bytes(indices)
	result=dict(source_revision=SOURCE_REVISION,source_crop=[0,CROP_Y,512,512],tiles=len(tiles),blocks=len(block_data),chunks=len(chunk_data),background_dimensions=[4,4],foreground_and_platform_tile_ids_preserved=True,shared_authored_chunks_preserved=len(chunks),foreground_green_merges={'060':'064','080':'0A0'},background_waterfall_tiles=waterfall_count,background_waterfall_frames=3,hud_palette_slots_preserved=sorted(hud_colors-{0}),foreground_palette_blends=[dict(index=index+16,original=original_pal[index],pp=target,result=palette[index]) for index,target in blend_targets.items()],unique_tile_pixel_error_histogram=dict(sorted(errors.items())))
	output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n')
	print(json.dumps(result,indent=2))


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--source',type=Path,required=True)
	p.add_argument('--output',type=Path,default=ROOT/'test-results/ehz2-pp/import.json')
	a=p.parse_args();build(a.source,a.output)


if __name__ == '__main__': main()
