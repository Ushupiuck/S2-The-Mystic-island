#!/usr/bin/env python3
"""Place and collect actual rotating-stage grid rings through controller Debug."""
from pathlib import Path
import argparse
import json

from genesis_test_core import Genesis

p = argparse.ArgumentParser(description=__doc__)
for name in ('rom', 'listing', 'core', 'output'):
	p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--pal', action='store_true')
p.add_argument('--system-directory', type=Path)
p.add_argument('--player', type=int, choices=(0, 2), default=0)
args = p.parse_args()
g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
			system_directory=args.system_directory)


def step(count=1):
	g.run(count)
	assert not g.read('v_errortype'), ('CPU exception', g.frame)


def press(button):
	g.buttons = {button}
	step(2)
	g.buttons = set()
	step(2)


for _ in range(1800):
	step()
	if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
		break
else:
	raise AssertionError('Title not ready')
g.write('f_levselcheat', 1)
press(3)
step(110)
g.write('Player_mode', args.player, 2)
g.write('v_levselitem', g.s['LevelSelect_BonusItem'], 2)
press(3)
for _ in range(800):
	step()
	if g.read('v_vbla_routine', 2) == g.s['Vint_S1SS']:
		break
else:
	raise AssertionError('Special stage not ready')
step(70)
g.write('Debug_mode_flag', 1)
press(0)
assert g.read('Debug_placement_mode', 2)
step(40)  # Let pre-Debug touch animations finish without changing the layout.


def check_motion():
	"""Every update must center both the cursor and the grid on its final pose."""
	state = g.save()
	frames = moving = 0
	anchor = None
	# Taps, idle, held acceleration, diagonals and immediate reversals.
	sequence = [({button}, 1) for button in (7,6,4,5)]
	sequence += [(set(), 2)]
	sequence += [(buttons, 24) for buttons in ({7},{6},{4},{5},{7,4},{6,5},{7,5},{6,4})]
	sequence += [({7}, 48),({6},48),(set(),3)]
	for buttons, duration in sequence:
		g.buttons = buttons
		for _ in range(duration):
			before = tuple(g.get('v_player', field, 4) for field in ('obX','obY'))
			step()
			x, y = (g.get('v_player', field, 2) for field in ('obX','obY'))
			camera = (g.read('Camera_X_pos',2),g.read('Camera_Y_pos',2))
			assert camera == (x-160,y-112), ('Debug camera uses an older cursor position',buttons,(x,y),camera)
			assert camera == (g.read('Camera_X_pos_copy',2),g.read('Camera_Y_pos_copy',2))
			cursor = (g.read(g.s['Sprite_Table']+6,2)&511,g.read('Sprite_Table',2)&1023)
			if anchor is None:
				anchor = cursor
			assert cursor == anchor, ('Debug cursor jittered on screen',buttons,anchor,cursor)
			after = tuple(g.get('v_player', field, 4) for field in ('obX','obY'))
			moving += after != before
			frames += 1
	assert moving > 250
	g.restore(state)
	return {'frames':frames,'moving_frames':moving,'directions':8,'camera_and_cursor_stable':True}


motion = check_motion()
base = g.s['v_ssblockbuffer']
stride = g.s['S1SS_LayoutStride']


def snapshot():
	return bytes(g.read(base + row * stride + col) for row in range(64) for col in range(64))


def candidate(data, col, row):
	if not 0 <= col < 64 or not 0 <= row < 64:
		raise AssertionError(('Cursor outside authored grid', col, row))
	x, y, dx, dy, length = col, row, 1, 0, 1
	if not data[y * 64 + x]:
		return x, y
	for _ in range(128):
		for _ in range(2):
			for _ in range(length):
				x += dx
				y += dy
				if 0 <= x < 64 and 0 <= y < 64 and not data[y * 64 + x]:
					return x, y
			dx, dy = -dy, dx
		length += 1
	raise AssertionError('No free cell')


placed = []
for _ in range(12):
	before = snapshot()
	x, y = g.get('v_player', 'obX', 4), g.get('v_player', 'obY', 4)
	col = (((x + (32 << 16) - 1) >> 16) // 24) - 32
	row = (((y + (80 << 16) - 1) >> 16) // 24) - 32
	expected = candidate(before, col, row)
	press(8)
	after = snapshot()
	changed = [divmod(i, 64)[::-1] for i, (a, b) in enumerate(zip(before, after)) if a != b]
	assert changed == [expected], (expected, changed)
	assert after[expected[1] * 64 + expected[0]] == g.s['S1SS_RingItem']
	assert (x, y) == (g.get('v_player', 'obX', 4), g.get('v_player', 'obY', 4))
	placed.append(expected)
g.video.save(g.output / 'grid-rings.png')
pool = range(g.s['v_lvlobjspace'] & 65535, g.s['v_lvlobjend'] & 65535, g.s['object_size'])
assert not any(g.get(obj, 'code') == g.s['Ring'] for obj in pool)

# Resume normal play at the first inserted ring and collect it through S1SS.
col, row = placed[0]
g.put('v_player', 'obX', ((col + 32) * 24 - 20) << 16, 4)
g.put('v_player', 'obY', ((row + 32) * 24 - 68) << 16, 4)
rings = g.read('v_rings', 2)
press(0)
assert not g.read('Debug_placement_mode', 2)
step(4)
assert g.read('v_rings', 2) > rings
g.video.save(g.output / 'collected-grid-ring.png')
report = {'region': 'PAL' if args.pal else 'NTSC', 'placed_cells': placed,
			'player': args.player, 'motion': motion,
			'controller_placement': True, 'occupied_cells_preserved': True,
			'no_regular_ring_SST': True, 'collects_after_Debug': True}
(g.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
g.close()
