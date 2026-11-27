#!/usr/bin/env python3
"""Exercise the assembled shared player geometry against independent planes.

The fixtures use real MD/CD terrain executors. Actor position/shape and the
resident test planes are staged; controller-only playthroughs are separate.
"""
import argparse
import json
from pathlib import Path
import struct

from level_layout import encode
from native_test_core import (Native, UC_M68K_REG_D0, UC_M68K_REG_D1,
	UC_M68K_REG_D2, UC_M68K_REG_D3, UC_M68K_REG_D7)

ROOT = Path(__file__).resolve().parents[1]


def native_checks(rom, listing):
	n = Native(rom, listing)
	n.start()
	s = n.s
	n.resident_terrain = True
	n.sub.mem_write(s['MCD_TerrainLayout_Sub'], encode([[1]*8 for _ in range(8)], [[0]]))
	n.cpu.mem_write(0x3E0000, bytes([255])*s['MCD_TerrainIndexCapacity'])
	n.write('v_colladdr1', 0x3E0000, 4)
	n.write('v_colladdr2', 0x3E0001, 4)
	counts = dict(pairs=0, clearance=0, anchors=0, shafts=0, growth=0)
	# The last two shapes are deliberately outside the character presets.
	shapes = ((19, 9), (15, 9), (14, 7), (10, 5), (8, 5), (12, 3), (23, 11))
	actors = ('v_player', 'v_player2')

	def geometry(cells):
		n.sub.mem_write(s['MCD_ChunkTable_SubStart']+128, struct.pack('>64H', *cells))

	def plane(quadrant, mask=0xF000):
		geometry([mask|1 if ((quadrant == 0 and y >= 4) or
			(quadrant == 1 and x < 4) or (quadrant == 2 and y < 4) or
			(quadrant == 3 and x >= 4)) else 0 for y in range(8) for x in range(8)])

	def center(quadrant, height, gap):
		return ((560, 576-height-1-gap), (576+height+gap, 560),
			(560, 576+height+gap), (576-height-1-gap, 560))[quadrant]

	def actor(who, h, w, x, y, angle=0, path=12, status=0):
		for f, v, z in (('obX', x, 2), ('obY', y, 2), ('obXSub', 0x3579, 2),
			('obYSub', 0x2468, 2), ('obHeight', h, 1), ('obWidth', w, 1),
			('obAngle', angle, 1), ('obTopSolidBit', path, 1),
			('obLRBSolidBit', path+1, 1), ('obStatus', status, 1),
			('obRoutine', 2, 1), ('obControl', 0, 1), ('spindash_flag', 0, 1),
			('jumping', 0, 1), ('obVelX', 0, 2), ('obVelY', 0, 2)):
			n.put(who, f, v, z)

	for q in range(4):
		plane(q)
		for who in actors:
			for h, w in shapes:
				for path in (12, 14):
					for gap in (-3, -1, 0, 1, 3, 7, 14):
						x, y = center(q, h, gap)
						actor(who, h, w, x, y, path=path)
						n.act('sub_13102', who, {UC_M68K_REG_D0: q*64, UC_M68K_REG_D7: 0x24681357})
						assert n.cpu.reg_read(UC_M68K_REG_D1)&65535 == gap&65535, (q, who, h, w, path, gap)
						assert n.cpu.reg_read(UC_M68K_REG_D0)&65535 == gap&65535
						assert n.cpu.reg_read(UC_M68K_REG_D7) == 0x24681357
						assert (n.get(who, 'obX', 2), n.get(who, 'obY', 2)) == (x, y)
						counts['pairs'] += 1
						n.act('Player_ProbeShapeRoom', who, {UC_M68K_REG_D0: h<<8|w,
							UC_M68K_REG_D1: q*64, UC_M68K_REG_D2: y, UC_M68K_REG_D3: x})
						assert n.cpu.reg_read(UC_M68K_REG_D1)&65535 == gap&65535
						counts['clearance'] += 1

	# Top-only terrain must not prevent expansion away from a support, in any
	# orientation. L/R/B and full solidity must obstruct exactly the same shape.
	for q in range(4):
		for mask in (0x5000, 0xA000, 0xF000):
			plane(q, mask)
			for who in actors:
				for h, w in shapes:
					for path in (12, 14):
						x, y = center(q, h, -2)
						actor(who, h, w, x, y, path=path)
						n.act('Player_ProbeShapeRoom', who, {UC_M68K_REG_D0: h<<8|w,
							UC_M68K_REG_D1: q*64, UC_M68K_REG_D2: y, UC_M68K_REG_D3: x})
						blocked = bool(n.cpu.reg_read(UC_M68K_REG_D1)&0x8000)
						assert blocked == (mask != 0x5000), (q, mask, who, h, w, path)
						counts['clearance'] += 1

	# Shrinking/unrolling on either wall and the ceiling keeps the supported
	# world point, both fractional coordinates, velocities and the other axis.
	for angle in range(256):
		q = ((angle+31+((angle>>6)&1))&0xC0)//64
		assert n.sub.mem_read(s['MCD_SubTerrainQuadrants']+angle, 1)[0] == q*64
		for who in actors:
			for old in shapes:
				for new in shapes:
					actor(who, *old, 600, 600, angle=angle)
					x, y = 600, 600
					axis, sign = ((1, 1), (0, -1), (1, -1), (0, 1))[q]
					before = (x, y)[axis] + sign*old[0]
					n.act('Player_Resize', who, {UC_M68K_REG_D0: new[0]<<8|new[1]})
					point = (n.get(who, 'obX', 2), n.get(who, 'obY', 2))
					assert point[axis] + sign*new[0] == before, (q, who, old, new, point)
					assert point[1-axis] == 600
					assert n.get(who, 'obXSub', 2) == 0x3579 and n.get(who, 'obYSub', 2) == 0x2468
					assert n.get(who, 'obHeight', 2) == new[0]<<8|new[1]
					counts['anchors'] += 1

	# A 16-pixel shaft admits mini standing/rolling bodies with margin. A wider
	# actor must still hit the walls; vertical speed must not create lateral pull.
	geometry([0xF001 if x<4 or x>=5 else 0 for y in range(8) for x in range(8)])
	for who in actors:
		for h, w in ((10, 5), (8, 5), (12, 3), (19, 9)):
			for vy in (-0x600, 0x600):
				for path in (12, 14):
					actor(who, h, w, 584, 560, path=path, status=2)
					n.put(who, 'obVelY', vy, 2)
					n.act('Sonic_DoLevelCollision' if who == 'v_player' else 'Tails_DoLevelCollision', who)
					if w <= 5:
						assert (n.get(who, 'obX', 2), n.get(who, 'obY', 2)) == (584, 560)
						assert n.get(who, 'obVelY', 2) == vy&65535
					else:
						assert n.get(who, 'obX', 2) != 584
					counts['shafts'] += 1

	# Probe growth toward a roof/wall from both a fitting compact pose and an
	# oversized proposed pose. No actor mutation is allowed on the rejected query.
	for support in range(4):
		opposite = (support+2)%4
		plane(opposite)
		for who in actors:
			for path in (12, 14):
				for current, new, margin in (((8, 5), (10, 5), 1), ((8, 5), (10, 5), -1),
					((14, 7), (19, 9), 1), ((14, 7), (19, 9), -1)):
					x, y = center(opposite, new[0], margin)
					# Invert the desired support-preserving resize to obtain the old
					# center, then query the independent obstacle at the destination.
					axis, sign = ((1, 1), (0, -1), (1, -1), (0, 1))[support]
					point = [x, y]
					point[axis] -= sign*(current[0]-new[0])
					actor(who, *current, *point, angle=support*64, path=path)
					n.act('Player_ResizeRoom', who, {UC_M68K_REG_D0: new[0]<<8|new[1]})
					assert bool(n.cpu.reg_read(UC_M68K_REG_D1)&0x8000) == (margin<0)
					assert [n.get(who, 'obX', 2), n.get(who, 'obY', 2)] == point
					assert n.get(who, 'obHeight', 2) == current[0]<<8|current[1]
					counts['growth'] += 1
	return counts


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--output', type=Path)
	args = p.parse_args()
	report = native_checks(args.rom, args.listing)
	print(report)
	if args.output:
		args.output.parent.mkdir(parents=True, exist_ok=True)
		args.output.write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
	main()
