#!/usr/bin/env python3
"""Check Kemusi art, native SMZ placements, collisions and real Debug spawning.

Uses Genesis Plus GX and the assembled game. Player positioning is fixture
setup; loading, Debug entry/selection/spawning and collision use normal frames.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct

from check_caterkiller import Fixture, ROOT
from check_companion_followup import isolate, place, spawn
from check_object_course import boot_level
from check_sprite_assets import frames


def vram(g, tile, size):
	return bytes(g.vram[(tile*32+i)^1] for i in range(size))


def group(g, head):
	return [head] + [g.get(head, 'cat_start_children', 2)] + [
		g.read(head + g.s['cat_start_children'] + i, 2) for i in (2, 4)]


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--core', type=Path, required=True)
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--pal', action='store_true')
	args = p.parse_args()
	args.baseline = False
	f = Fixture(args)
	g = f.g
	raw = (ROOT/'art/uncompressed/Enemy Kemusi.unc').read_bytes()
	atlas = (ROOT/'art/uncompressed/SMZ Sprite Atlas.unc').read_bytes()
	assert len(raw) == 22*32
	assert g.s['ArtTile_SMZ_Kemusi'] + 22 <= g.s['ArtTile_SMZ_Smoke2'] + 12
	assert frames((ROOT/'mappings/sprite/Kemusi.bin').read_bytes()) == [
		[(-12, 6, 0, -8)], [(-12, 6, 6, -8)],
		[(-12, 6, 12, -8)], [(-8, 5, 18, -8)]]
	try:
		stages = {}
		for act in (1, 2):
			g.core.retro_reset()
			g.buttons = g.buttons2 = set()
			boot_level(g, zone=8, act=act-1, player=0)
			assert g.read('Current_ZoneAndAct', 2) == 0x800+act-1
			assert vram(g, g.s['ArtTile_SMZ_Atlas'], len(atlas)) == atlas
			if act == 2:
				assert vram(g, g.s['ArtTile_SMZ_Kemusi'], len(raw)) == raw
				g.run(360)
				assert vram(g, g.s['ArtTile_SMZ_Kemusi'], len(raw)) == raw, 'smoke overwrote Kemusi'
			stages[act] = g.save()
			f.finish(f'act-{act}-resident-art', kemusi_tiles=22 if act == 2 else 0)

		# All native Caterkiller/Kemusi placements must initialize and crawl.
		for act in (1, 2):
			rows = list(struct.iter_unpack('>HHBB', (ROOT/f'level/objects/SMZ_{act}.bin').read_bytes()))
			variants = set()
			for index, (x, y, oid, subtype) in enumerate(rows):
				if oid != 0x60:
					continue
				assert subtype == 0 if act == 1 else subtype in (1, 2)
				variants.add(subtype)
				g.restore(stages[act])
				py = y & 0xFFF
				place(g, 'v_player', x-80, max(32, py-64))
				g.put('v_player', 'obControl', 0x81)
				g.put('v_player', 'flashtime', 6000, 2)
				g.put('v_player2', 'code', 0)
				camera = max(0, x-160)
				g.write('Camera_X_pos', camera, 2)
				g.write('Camera_X_pos_coarse_back', (camera-128) & 0xFF80, 2)
				g.write('Camera_Y_pos', max(0, min(0x720, py-112)), 2)
				tag = g.placement_handle(index)
				head = None
				for _ in range(180):
					g.run()
					head = next((a for a in f.pool() if g.get(a, 'code') == g.s['Caterkiller'] and g.get(a, 'respawn_addr', 2) == tag), None)
					if head is not None and g.get(head, 'ob2ndRout') in (2, 4):
						break
				else:
					raise AssertionError((act, index, x, py, 'did not crawl', head))
				parts = group(g, head)
				assert len(set(parts)) == 4
				assert all(g.get(a, 'code') == g.s['Caterkiller'] and g.get(a, 'obSubtype') == subtype for a in parts)
				f.finish(f'act-{act}-placement-{index}', subtype=subtype)
			assert variants == ({0} if act == 1 else {1, 2})

		# Read the actual Debug records, then use controller inputs to select
		# and place all three in the indoor act. Both art banks stay resident.
		rom = args.rom.read_bytes()
		base = g.s['Debug_SMZIndoor']
		count = struct.unpack_from('>H', rom, base)[0]
		records = list(struct.iter_unpack('>IIBBH', rom[base+2:base+2+count*12]))
		entries = {row[2]: (i, row) for i, row in enumerate(records) if row[0] == g.s['Caterkiller']}
		assert set(entries) == {0, 1, 2}
		g.restore(stages[2])
		isolate(g)
		g.put('v_player2', 'code', 0)
		place(g, 'v_player', 0x580, 0x680)
		g.write('Camera_X_pos', 0x4E0, 2)
		g.write('Camera_X_pos_coarse_back', 0x460, 2)
		g.write('Camera_Y_pos', 0x600, 2)
		g.write('Debug_mode_flag', 1)
		g.buttons = {0}; g.run(); g.buttons = set(); g.run(2)
		assert g.read('Debug_placement_type') == 1
		heads = []
		for subtype, x in ((0, 0x520), (1, 0x580), (2, 0x5E0)):
			index, entry = entries[subtype]
			g.put('v_player', 'obX', x, 2)
			g.put('v_player', 'obY', 0x680, 2)
			g.write('Debug_object', (index-1) % count)
			g.buttons = {1}; g.run(); g.buttons = set(); g.run()
			assert g.read('Debug_object') == index
			assert g.get('v_player', 'obMap', 4) == entry[1]
			before = {a for a in f.pool() if g.get(a, 'code')}
			g.buttons = {8}; g.run(); g.buttons = set(); g.run()
			new = [a for a in f.pool() if a not in before and g.get(a, 'code') == g.s['Caterkiller'] and g.get(a, 'obRoutine') == 2]
			assert len(new) == 1 and g.get(new[0], 'obSubtype') == subtype, (subtype, new)
			heads.append(new[0])
		g.put('v_player', 'obX', 0x580, 2)
		g.run(180)
		for subtype, head in enumerate(heads):
			parts = group(g, head)
			assert all(g.get(a, 'code') == g.s['Caterkiller'] for a in parts), ('Debug coexistence', subtype)
			assert g.get(head, 'ob2ndRout') in (2, 4)
		assert vram(g, g.s['ArtTile_SMZ_Kemusi'], len(raw)) == raw
		assert vram(g, g.s['ArtTile_SMZ_Atlas'], len(atlas)) == atlas
		g.video.save(args.output/'debug-cousins.png')
		f.finish('real-debug-spawns-and-coexistence', subtypes=[0, 1, 2])

		# Attack every weak point with either player. Real touch response
		# must consume all four pieces, including when a damaged tail dies.
		for subtype in (1, 2):
			for actor in ('v_player', 'v_player2'):
				for target in ('head', 'body-1', 'body-2', 'body-3'):
					g.restore(stages[2]); isolate(g)
					# Native placements are checked above. Keep their spawn flags
					# set here so the manager cannot reuse a defeated fixture's
					# slots for a different, freshly loaded Kemusi.
					length = g.placement_capacity()
					g.placement_write(0, int.from_bytes(b'\x80'*length, 'big'), length)
					for other in ('v_player', 'v_player2'):
						place(g, other, 0x500, 0x640); g.put(other, 'obControl', 0x81)
					g.write('Camera_X_pos', 0x4A0, 2)
					g.write('Camera_X_pos_coarse_back', 0x400, 2)
					g.write('Camera_Y_pos', 0x600, 2)
					g.buttons2 = {4}
					head = spawn(g, 'Caterkiller', 0x580, 0x680, subtype)
					g.run(100)
					parts = group(g, head)
					assert all(g.get(a, 'code') == g.s['Caterkiller'] for a in parts)
					victim = head if target == 'head' else parts[int(target[-1])]
					# Approach the far edge of a body piece; its neighbor's
					# larger head hitbox must not take this attack first.
					place(g, actor, g.get(victim, 'obX', 2) + (0 if target == 'head' else 14), g.get(victim, 'obY', 2)-8)
					for field, value, size in (
						('obControl', 0, 1), ('obAnim', 2, 1), ('obStatus', 6, 1),
						('obHeight', 9, 1), ('obWidth', 7, 1), ('jumping', 1, 1), ('obVelY', 0x100, 2)):
						g.put(actor, field, value, size)
					g.write('v_rings', 99, 2)
					for _ in range(8):
						g.run()
						if g.get(victim, 'code') == g.s['Explosion'] or g.get(actor, 'obRoutine') == 4:
							break
					if subtype == 1 and target != 'head':
						assert g.get(actor, 'obRoutine') == 4, (subtype, actor, target)
						assert all(g.get(a, 'code') == g.s['Caterkiller'] for a in parts), 'intact spike hit fragmented Kemusi'
					else:
						assert g.get(victim, 'code') == g.s['Explosion'], (subtype, actor, target)
						g.run(2)
						assert not any(g.get(a, 'code') == g.s['Caterkiller'] for a in parts), ('defeated Kemusi left live pieces', subtype, actor, target)
					f.finish(f'variant-{subtype}-{actor}-hits-{target}')
		(args.output/'report.json').write_text(json.dumps(dict(
			rom_sha256=hashlib.sha256(args.rom.read_bytes()).hexdigest(),
			region='PAL' if args.pal else 'NTSC', cases=f.report), indent=2)+'\n')
	finally:
		g.close()
	print('Kemusi checks passed', flush=True)


if __name__ == '__main__':
	main()
