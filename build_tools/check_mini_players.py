#!/usr/bin/env python3
"""Check real miniature walking, charging, rolling, flight and streamed feet.

Initial actors/camera are staged on GHZ1's flat ground. The real size beam,
controller inputs, movement, animation, object pass and VDP DMA then run.
"""
import argparse
import json
from pathlib import Path

from check_companion_followup import isolate, place, spawn
from check_object_course import boot_level
from check_signpost_game import park_fixture_camera
from genesis_test_core import Genesis

ROOT = Path(__file__).resolve().parents[1]


def body_pixels(g, actor):
	"""Read the actual hardware sprite entries and uploaded body pixels.

	CPU mappings/DPLC cache can already describe the *next* frame while the
	VDP still displays its preceding coherent art/SAT pair. Read that live pair.
	"""
	base = g.get(actor, 'obGfx', 2)&0x7FF
	result = []
	def byte(address):
		return g.vram[address^1]
	def word(address):
		return byte(address)<<8|byte(address+1)
	index = 0
	for _ in range(80):
		ptr = g.s['vram_sprites']+index*8
		y, size, link, tile, x = word(ptr), byte(ptr+2), byte(ptr+3), word(ptr+4), word(ptr+6)
		w, h = ((size>>2)&3)+1, (size&3)+1
		if base <= tile&0x7FF < base+16 and x&0x1FF:
			for py in range(h*8):
				for px in range(w*8):
					tx = w*8-1-px if tile&0x800 else px
					ty = h*8-1-py if tile&0x1000 else py
					address = (((tile&0x7FF)+(tx//8)*h+ty//8)&0x7FF)*32 + (ty&7)*4 + (tx&7)//2
					value = byte(address)
					if (value&15 if tx&1 else value>>4):
						result.append(((x&511)-128+px+g.read('Camera_X_pos', 2),
							(y&1023)-128+py+g.read('Camera_Y_pos', 2)))
		if not link:
			break
		index = link
	return result


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--core', type=Path, required=True)
	p.add_argument('--system-directory', type=Path, required=True)
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--pal', action='store_true')
	args = p.parse_args()
	g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
		system_directory=args.system_directory)
	initial = g.save()
	rows = []
	for player, actor in ((0, 'v_player'), (0, 'v_player2'), (2, 'v_player')):
		g.restore(initial)
		boot_level(g, zone=0, player=player)
		isolate(g)
		park_fixture_camera(g)
		other = 'v_player2' if actor == 'v_player' else 'v_player'
		place(g, other, 40, 0x5BF-g.get(other, 'default_y_radius'), False)
		g.put(other, 'obControl', 0x81)
		place(g, actor, 160, 0x5BF-g.get(actor, 'default_y_radius'), False)
		g.put(actor, 'obAngle', 0)
		g.write('Tails_CPU_idle_timer', 6000, 2)
		spawn(g, 'MMZ_Laser', 160, 1240)
		for _ in range(120):
			g.run()
			assert not g.read('v_errortype')
			if g.get(actor, 'default_y_radius') == 10:
				break
		else:
			raise AssertionError((player, actor, 'beam did not shrink'))
		isolate(g)
		g.write('Tails_CPU_idle_timer', 6000, 2)
		place(g, actor, 160, 1461, False)
		g.put(actor, 'obAngle', 0)
		form = g.save()
		stem = f'player-{player}-{actor}'
		tails = g.get(actor, 'character_id') == g.s['CharacterID_Tails']

		def run(buttons, frames=1):
			if actor == 'v_player':
				g.buttons, g.buttons2 = buttons, set()
			else:
				g.buttons, g.buttons2 = set(), buttons
			g.run(frames)
			assert not g.read('v_errortype')
			assert g.get(actor, 'obRoutine') == 2
			assert g.get(actor, 'default_y_radius') == 10

		def feet(label, expected):
			pixels = body_pixels(g, actor)
			assert pixels, (stem, label, 'no streamed body')
			bottom = max(y for _, y in pixels)
			assert bottom == 1471, (stem, label, g.get(actor, 'obFrame'), bottom, 'feet left terrain')
			assert g.get(actor, 'obHeight') == expected
			return True

		run(set(), 12)
		assert feet('standing', 10)
		g.video.save(args.output/f'{stem}-standing.png')
		walk = set()
		for _ in range(24):
			run({7})
			if not g.get(actor, 'obAngle') and feet('walking', 10):
				walk.add(g.get(actor, 'obFrame'))
		assert len(walk) >= 3, (stem, 'walking poses not exercised', walk)
		g.video.save(args.output/f'{stem}-walking.png')
		g.restore(form)
		run({5}, 4)
		run({5, 0}, 2)
		run({5}, 4)
		assert g.get(actor, 'spindash_flag') == 1
		assert feet('charging', 10)
		dust = g.get(actor, 'player_dust_ptr', 2)
		assert dust and g.get(dust, 'obAnim') == 0, (stem, 'giant dust still active')
		g.video.save(args.output/f'{stem}-charging.png')
		rolled = False
		for _ in range(10):
			run(set())
			assert g.get(actor, 'obHeight') == 8 and g.get(actor, 'obWidth') == 5
			if not g.get(actor, 'obAngle'):
				rolled |= feet('rolling', 8)
		assert rolled
		g.video.save(args.output/f'{stem}-rolling.png')
		g.restore(form)
		run({0}, 3)
		run(set(), 5)
		assert g.get(actor, 'obStatus')&6 == 6 and g.get(actor, 'obHeight') == 8
		if tails:
			run({0}, 3)
			run(set(), 6)
			assert g.get(actor, 'tails_flight_flag')
			assert g.get(actor, 'obHeight') == 10 and g.get(actor, 'obWidth') == 5
			frames = set()
			for _ in range(16):
				run({0})
				frames.add(g.get(actor, 'obFrame'))
			assert frames == {0xEE, 0xEF}, (stem, 'rotor not animating', frames)
			g.video.save(args.output/f'{stem}-flying.png')
			g.put(actor, 'tails_flight_energy', 0)
			tired = set()
			for _ in range(36):
				run(set())
				tired.add(g.get(actor, 'obFrame'))
			assert tired == {0xF2, 0xF3, 0xF4, 0xF5}, (stem, tired)
			g.video.save(args.output/f'{stem}-tired.png')
		if player == 0:
			# Try each mixed pairing and both-mini. Use real pickup and jump
			# input so the old full-sized jump-off overwrite cannot hide.
			for both in ((False, True) if actor == 'v_player' else (False,)):
				g.restore(form)
				if both:
					place(g, 'v_player2', 240, 0x5BF-g.get('v_player2', 'default_y_radius'), False)
					g.put('v_player2', 'obControl', 0)
					spawn(g, 'MMZ_Laser', 240, 1240)
					for _ in range(100):
						g.run()
						if g.get('v_player2', 'default_y_radius') == 10:
							break
					else:
						raise AssertionError('Companion beam did not shrink')
					isolate(g)
				gap = g.get('v_player', 'default_y_radius')+g.get('v_player2', 'default_y_radius')-6
				place(g, 'v_player2', 160, 600)
				place(g, 'v_player', 160, 600+gap+8)
				g.put('v_player', 'obAngle', 0)
				g.put('v_player2', 'obAngle', 0)
				g.put('v_player2', 'tails_flight_flag', 1)
				g.put('v_player2', 'tails_flight_energy', g.s['Tails_FlightBudget'])
				g.write('Tails_CPU_idle_timer', 6000, 2)
				g.buttons = g.buttons2 = set()
				g.run(3)
				assert g.read('Flying_carrying_Sonic_flag'), (stem, both, 'no pickup')
				g.run(8)
				assert g.get('v_player', 'obY', 2)-g.get('v_player2', 'obY', 2) == gap
				g.video.save(args.output/f'{stem}-carry-both{int(both)}.png')
				g.buttons = {0}
				g.run(2)
				small = g.get('v_player', 'default_y_radius') == 10
				assert not g.read('Flying_carrying_Sonic_flag')
				assert not g.get('v_player', 'obControl') and g.get('v_player', 'jumping')
				assert g.get('v_player', 'obHeight') == (8 if small else 14)
				assert g.get('v_player', 'obWidth') == (5 if small else 7)
				assert g.get('v_player', 'default_y_radius') == (10 if small else 19)
		rows.append(dict(player=player, actor=actor, walk_frames=sorted(walk), feet=True,
			dust_hidden=True, roll_and_jump=True, flight=tails))
		print(rows[-1], flush=True)
	g.close()
	(args.output/'report.json').write_text(json.dumps(rows, indent=2)+'\n')


if __name__ == '__main__':
	main()
