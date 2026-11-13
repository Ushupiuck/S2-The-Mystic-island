#!/usr/bin/env python3
"""Execute scattered-ring allocation, pickup, emitter and cage regressions.

The launch reference evaluates the original fixed-point sine algorithm, rather
than copying the new velocity table. The water fixture checks both player flags.
"""
from pathlib import Path
import argparse
import json
import struct

from native_test_core import (Native, UC_M68K_REG_A1)

ROOT = Path(__file__).resolve().parents[1]


def check(args):
	m = Native(args.rom, args.listing)
	pool = list(range(m.s['v_lvlobjspace'], m.s['v_lvlobjend'], m.s['object_size']))
	wave = struct.unpack('>320h', bytes(m.cpu.mem_read(m.s['Sine_Data'], 640)))
	velocities = []
	for power in (2, 1):
		for angle in range(0x88, 0x100, 0x10):
			vx, vy = wave[angle] << power, wave[angle+64] << power
			velocities.extend(((vx & 65535, vy & 65535), (-vx & 65535, vy & 65535)))
	assert len(velocities) == 32
	cases = 0
	for owner_index in (0, 7, 45, 89):
		for available in (1, 9, 90):
			for count in (0, 1, 2, 16, 17, 31, 32, 99, 999):
				for water in (0, 64):
					m.start()
					owner = pool[owner_index]
					free = [owner] + [a for a in pool if a != owner][:available-1]
					for a in pool:
						if a not in free:
							m.put(a, 'code', m.s['ObjNull'])
					m.put(owner, 'code', m.s['LostRings'])
					m.put(owner, 'obX', 160, 2)
					m.put(owner, 'obY', 300, 2)
					m.put('v_player', 'obStatus', water)
					m.write('v_rings', count, 2)
					m.write('Camera_Max_Y_pos', 0x720, 2)
					m.act('LostRings', owner)
					expected = free[:min(count, 32, available)]
					actual = [a for a in pool if m.get(a, 'code') == m.s['LostRing_Move']]
					assert set(actual) == set(expected), (owner_index, available, count, actual)
					for i, a in enumerate(expected):
						vx, vy = velocities[i]
						assert m.get(a, 'obVelX', 2) == vx
						assert m.get(a, 'obVelY', 2) == (vy + (24 if a == owner else 0)) & 65535
						assert m.get(a, 'obDelayAni') == (254 if a == owner else 255)
						assert m.get(a, 'obColType') == 0x47
						assert m.get(a, 'obHeight', 2) == 0x0808
					assert m.read('v_rings', 2) == 0
					cases += 1

	# Every ordinary act resolves to explicit monitor presets, and Debug's
	# actual placement command instantiates the selected reward subtype.
	debug_cases = 0
	for zone in range(16):
		for act in range(4):
			base = m.s['DebugList']
			delta = int.from_bytes(m.cpu.mem_read(base+(zone*4+act)*2, 2), 'big', signed=True)
			address = base+delta
			count = int.from_bytes(m.cpu.mem_read(address, 2), 'big')
			entries = [struct.unpack('>IIHBBH', bytes(m.cpu.mem_read(address+2+i*14, 14))) for i in range(count)]
			for subtype in (1, 2, 7, 6):
				index = next(i for i, entry in enumerate(entries) if entry[0] == m.s['Monitor'] and entry[2] == subtype)
				assert entries[index][3] == subtype+1
				m.start()
				m.write('Current_ZoneAndAct', zone*256+act, 2)
				m.write('Debug_placement_mode', 1, 2)
				m.act('DebugMode', m.s['v_player'])
				m.write('Debug_object', index)
				m.write('v_jpadpress1', m.s['btnC'])
				m.act('DebugMode', m.s['v_player'])
				placed = [a for a in pool if m.get(a, 'code') == m.s['Monitor']]
				assert len(placed) == 1 and m.get(placed[0], 'obSubtype', 2) == subtype
				debug_cases += 1

	# Two players may touch the same ring before its object update. Reward once.
	pickups = 0
	for lost in (False, True):
		for primary in (1, 2):
			m.start()
			a = pool[0]
			for actor in ('v_player', 'v_player2'):
				m.put(actor, 'obX', 160, 2)
				m.put(actor, 'obY', 300, 2)
				m.put(actor, 'flashtime', 0, 2)
			m.put('v_player', 'layout_id', primary)
			m.put(a, 'obX', 160, 2)
			m.put(a, 'obY', 300, 2)
			if lost:
				m.cpu.reg_write(UC_M68K_REG_A1, a)
				m.act('LostRing_Init', regs={UC_M68K_REG_A1: a})
			else:
				m.put(a, 'code', m.s['Ring'])
				m.act('Ring', a)
			m.act('Add_SpriteToCollisionResponseList', a)
			for actor in ('v_player', 'v_player2'):
				m.act('TouchResponse', m.s[actor])
			entry = 'LostRing_Collect' if lost else 'Ring_Collect'
			assert m.get(a, 'code') == m.s[entry]
			m.act(entry, a)
			assert m.read('v_rings', 2) == 1 and not m.get(a, 'obColType')
			frames = [m.get(a, 'obFrame')]
			for tick in range(1, 25):
				m.act('Ring_Sparkle', a)
				frames.append(m.get(a, 'obFrame'))
			assert frames == [1]*6 + [2]*6 + [3]*6 + [4]*7, frames
			assert m.get(a, 'code') == m.s['DeleteObject']
			m.act('DeleteObject', a)
			assert not m.get(a, 'code') and m.read('v_rings', 2) == 1
			pickups += 1

	# Trigger includes both negative and positive halves of its proximity box.
	proximity = 0
	for dx in (-17, -16, -1, 0, 15, 16):
		for dy in (-33, -32, -1, 0, 31, 32):
			m.start()
			a = pool[0]
			m.put(a, 'code', m.s['GoddessRings'])
			m.put(a, 'obX', 200, 2)
			m.put(a, 'obY', 300, 2)
			m.put('v_player', 'obX', 200+dx, 2)
			m.put('v_player', 'obY', 300+dy, 2)
			m.act('GoddessRings', a)
			assert (m.get(a, 'code') == m.s['GoddessRings_Emit']) == (-16 <= dx < 16 and -32 <= dy < 32)
			proximity += 1
	m.start()
	a = pool[0]
	for f, v, n in (('code', m.s['GoddessRings'], 4), ('obX', 200, 2), ('obY', 300, 2)):
		m.put(a, f, v, n)
	m.put('v_player', 'obX', 200, 2)
	m.put('v_player', 'obY', 300, 2)
	m.act('GoddessRings', a)
	emission_ticks = []
	previous = 0
	for tick in range(1, 541):
		m.act('GoddessRings_Emit', a)
		live = [b for b in pool if m.get(b, 'code') == m.s['LostRing_Move']]
		if len(live) != previous:
			emission_ticks.append(tick)
			previous = len(live)
	assert emission_ticks == list(range(1, 541, 11))
	assert len(live) == 50 and m.get(a, 'code') == m.s['MarkObjGone2']
	for b in live:
		assert (m.get(b, 'obX', 2), m.get(b, 'obY', 2)) == (224, 284)
		assert m.get(b, 'obVelY', 2) == 0xFE00 and m.get(b, 'obDelayAni') == 255
		assert m.get(b, 'obVelX', 2) in (0xFF00, 0xFF80, 0, 0x80, 0x100, 0x180, 0x200, 0x280)
	m.start()
	for b in pool:
		m.put(b, 'code', m.s['ObjNull'])
	m.put(a, 'code', m.s['GoddessRings_Emit'])
	m.put(a, 'goddess_remaining', 50)
	for _ in range(22):
		m.act('GoddessRings_Emit', a)
	assert m.get(a, 'goddess_remaining') == 50
	m.put(pool[1], 'code', 0)
	m.act('GoddessRings_Emit', a)
	assert m.get(a, 'goddess_remaining') == 49

	# Both characters complete a 64-phase FBZ/MTZ orbit, including short radii.
	m.start()
	for field, value, size in (('code', m.s['TwistingPathway'], 4), ('obX', 200, 2),
			('obY', 300, 2), ('obSubtype', 0x98, 2)):
		m.put(a, field, value, size)
	for actor, height in (('v_player', 19), ('v_player2', 15)):
		m.put(actor, 'obX', 200, 2)
		m.put(actor, 'obY', 359-height, 2)
		m.put(actor, 'obHeight', height)
		m.put(actor, 'obInertia', 0x600, 2)
	m.act('TwistingPathway', a)
	assert m.get(a, 'obStatus') & 0x18 == 0x18
	for angle in range(0, 256, 4):
		m.act('TwistingPathway_Cage', a)
		for actor, height in (('v_player', 19), ('v_player2', 15)):
			expected = 300 + ((wave[angle+64]*0x2800) >> 16) - (height-19)
			assert m.get(actor, 'obY', 2) == expected, (actor, angle, expected)
			assert m.get(actor, 'flip_angle') == angle
	for actor in ('v_player', 'v_player2'):
		m.put(actor, 'obStatus', m.get(actor, 'obStatus') | 2)
		m.put(actor, 'obVelY', 0xFC00, 2)
	m.act('TwistingPathway_Cage', a)
	assert not m.get(a, 'obStatus') & 0x18
	return dict(allocation_cases=cases, debug_monitor_placements=debug_cases, simultaneous_player_pickups=pickups,
		proximity_cases=proximity, goddess_rings=50, goddess_interval=11,
		cage_character_phases=128)


def game_checks(args):
	from argparse import Namespace
	import shutil
	from check_caterkiller import Fixture
	from check_companion_followup import isolate, place, spawn
	out = args.output.parent/('game-pal' if args.pal else 'game-ntsc')
	out.mkdir(parents=True, exist_ok=True)
	for bios in args.system_directory.glob('bios_*.bin'):
		shutil.copyfile(bios, out/bios.name)
	f = Fixture(Namespace(core=args.core, rom=args.rom, listing=args.listing,
		output=out, pal=args.pal, baseline=False))
	g = f.g
	isolate(g)
	for _ in range(120):
		g.run()
		if not g.get('v_player', 'obStatus') & 2 and g.get('v_player', 'obRoutine') == 2:
			break
	else:
		raise AssertionError('GHZ fixture did not reach solid ground')
	origin_x = g.get('v_player', 'obX', 2)
	floor = g.get('v_player', 'obY', 2) + g.get('v_player', 'obHeight')
	isolate(g)
	for actor in ('v_player', 'v_player2'):
		place(g, actor, origin_x if actor == 'v_player' else origin_x+8, floor-19, False)
		g.put(actor, 'invtime', 0, 2)
		g.put(actor, 'obStatusSecondary', 0)
		g.put(actor, 'obControl', 0)
	g.write('v_rings', 32, 2)
	g.write('Ring_Positions', 0, 0x600)
	spawn(g, 'LostRings', origin_x, floor-19)
	peak = 0
	for tick in range(90):
		# Keep Sonic in the no-pickup interval: every recovered ring is Tails's.
		g.put('v_player', 'flashtime', 120, 2)
		g.run()
		assert not g.read('v_errortype')
		assert g.get('v_player', 'obRoutine') < 4, ('primary left normal play', tick)
		peak = max(peak, sum(g.get(a, 'layout_id') == 0x10 for a in f.pool()))
		if tick in (1, 8, 20):
			g.video.save(out/('tails-pickups-%02d.png' % tick))
	picked = g.read('v_rings', 2)
	assert peak >= 24 and picked >= 4, (peak, picked, floor)
	# Render the four actual monitor reward icons using the level's loaded art.
	isolate(g)
	icons = []
	for i, subtype in enumerate((1, 2, 7, 6)):
		a = spawn(g, 'Monitor', origin_x-48+i*40, floor-15, subtype)
		icons.append((a, subtype))
	seen = set()
	for tick in range(18):
		g.run()
		for a, subtype in icons:
			if g.get(a, 'obFrame') == subtype+1:
				seen.add(subtype)
		if all(g.get(a, 'obFrame') == subtype+1 for a, subtype in icons):
			g.video.save(out/'monitor-icons.png')
	assert seen == {1, 2, 7, 6}, seen
	assert all(g.get(a, 'obRender') & 128 for a, _ in icons), 'monitor icon left the visible scene'
	g.close()
	return dict(peak_scattered_rings=peak, tails_only_recoveries=picked,
		monitor_icons=sorted(seen), ground_y=floor, region='PAL' if args.pal else 'NTSC')


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--output', type=Path)
	p.add_argument('--core', type=Path)
	p.add_argument('--system-directory', type=Path)
	p.add_argument('--pal', action='store_true')
	args = p.parse_args()
	report = dict(native=check(args))
	if args.core:
		if not args.output or not args.system_directory:
			p.error('--core requires --output and --system-directory')
		report['game'] = game_checks(args)
	if args.output:
		args.output.parent.mkdir(parents=True, exist_ok=True)
		args.output.write_text(json.dumps(report, indent=2)+'\n')
	print(report)


if __name__ == '__main__':
	main()
