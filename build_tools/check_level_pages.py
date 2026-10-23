#!/usr/bin/env python3
"""Exercise level-select controls, return memory, and every four-act launch."""
from pathlib import Path
import argparse
import ctypes as C
import json
from genesis_test_core import Genesis

p = argparse.ArgumentParser(description=__doc__)
for name in ('rom', 'listing', 'core', 'output'):
	p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--pal', action='store_true')
args = p.parse_args()
g = Genesis(args.core, args.rom, args.listing, args.output, args.pal)
UP, DOWN, LEFT, RIGHT, A, B, C_BUTTON, START = 4, 5, 6, 7, 1, 0, 8, 3
PAGE, BONUS, SOUND = [g.s['LevelSelect_' + name + 'Item'] for name in ('Page', 'Bonus', 'Sound')]
free_start = g.s['Free_RAM_Start'] & 0xFFFF
free_end = g.s['Free_RAM_End'] & 0xFFFF
free_canary = bytes((i * 37 + 19) & 255 for i in range(free_end-free_start))
check_free_ram = False


def step(frames=1):
	for _ in range(frames):
		g.run()
		assert not g.read('v_errortype'), ('CPU exception', g.frame)
		if check_free_ram:
			assert bytes(g.ram[free_start:free_end]) == free_canary, 'Contiguous free RAM was touched'


def press(button):
	g.buttons = {button}
	step()
	g.buttons = set()
	step(2)


def title():
	for _ in range(1800):
		step()
		if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
			return
	raise AssertionError('Title not reached')


def enter_menu():
	g.write('f_levselcheat', 1)
	press(START)
	step(110)


def expect_text(row, column, text):
	address = 0xC000 + row * 128 + column * 2
	actual = [int.from_bytes(bytes(g.vram[(address + i + j) ^ 1] for j in range(2)), 'big') & 0x7FF
		for i in range(0, len(text) * 2, 2)]
	expected = [0 if c == ' ' else 16 + int(c) if c.isdigit() else ord(c) - ord('A') + 30 for c in text]
	assert actual == expected, (row, column, text, actual)


def item(expected):
	assert g.read('v_levselitem', 2) == expected, (g.read('v_levselitem', 2), expected)


def change_page():
	for _ in range(PAGE):
		press(DOWN)
	press(START)
	for _ in range(PAGE):
		press(UP)


def wait_level(zone, act):
	for _ in range(700):
		step()
		if g.read('v_vbla_routine', 2) == g.s['Vint_Level'] and g.read('f_timecount') and g.read('v_gamemode', 2) == g.s['Level']:
			assert g.read('Current_ZoneAndAct', 2) == zone * 256 + act
			return
	raise AssertionError((zone, act, 'Level boot timed out'))


title()
enter_menu()
item(0)
expect_text(1, 1, 'TWILIGHT HILL')
for row, text in ((22, 'NEXT'), (23, 'SPECIAL STAGE'), (24, 'SOUND TEST'), (25, '00 SONIC AND TAILS')):
	expect_text(row, 1, text)
g.ram[free_start:free_end] = free_canary
check_free_ram = True
menu = g.save()

# Up/Down must visit all 32 acts column-first, then each option, on both pages.
for page in (0, 0x100):
	g.restore(menu)
	if page:
		change_page()
		expect_text(1, 1, 'SCRAP MADNESS')
		expect_text(22, 1, 'PREVIOUS')
	item(page)
	for selected in range(1, SOUND + 2):
		press(DOWN)
		item(page | (selected % (SOUND + 1)))
	for selected in range(SOUND, -1, -1):
		press(UP)
		item(page | selected)
	for _ in range(15):
		press(DOWN)
	press(RIGHT); item(page | 31)
	press(LEFT); item(page | 15)
	press(DOWN); item(page | 16)
print('Both pages: vertical cycles, wrap, column boundary and horizontal navigation pass.', flush=True)

# Preserve the existing held-direction repeat cadence.
g.restore(menu)
g.buttons = {DOWN}
step(); item(1)
step(11); item(1)
step(); item(2)
g.buttons = set()
step(2)
g.restore(menu)
for mode, label in ((1, '01 SONIC'), (2, '02 TAILS'), (0, '00 SONIC AND TAILS')):
	press(C_BUTTON)
	assert g.read('Player_mode', 2) == mode
	expect_text(25, 1, label)
	if mode == 2:
		g.video.save(args.output / 'tails-label.png')
for button in (A, B, C_BUTTON, START):
	g.restore(menu)
	for _ in range(PAGE):
		press(DOWN)
	press(button); item(0x100 | PAGE)
	press(button); item(PAGE)

# Test every low-nibble/wrap combination, including F6 -> 06 and FF -> 0F.
g.restore(menu)
press(UP); item(SOUND)
for sound in range(256):
	g.write('v_levselsound', sound, 2)
	press(A)
	assert g.read('v_levselsound', 2) == ((sound + 0x10) & 0xFF), sound
	item(SOUND)
g.write('v_levselsound', 0, 2)
press(LEFT)
assert g.read('v_levselsound', 2) == 0xFF
press(RIGHT)
assert g.read('v_levselsound', 2) == 0
zram = (C.c_uint8 * 8192).in_dll(g.core, 'zram')
playing = g.s['zSongFM1.PlaybackControl']
for button in (B, C_BUTTON, START):
	g.write('v_levselsound', g.s['MusID_Stop'], 2)
	press(B); step(30)
	assert not zram[playing] & 0x80
	g.write('v_levselsound', 0xF6, 2)
	press(A); step(15)
	assert g.read('v_levselsound', 2) == 6
	assert not zram[playing] & 0x80, 'A played the sound instead of only changing its ID'
	g.write('v_levselsound', g.s['MusID_GHZ'], 2)
	press(button); step(30)
	assert zram[playing] & 0x80, ('Sound did not play', button)
	item(SOUND)
	assert g.read('Player_mode', 2) == 0
g.video.save(args.output / 'page-1.png')
print('All 256 A increments, +/-1 wrap, B/C/Start playback and numbered characters pass.', flush=True)

# Exit actual levels through pause+A, then check the rendered menu after return.
returns = []
for zone, act in ((4, 1), (8, 1)):
	g.restore(menu)
	if zone >= 8:
		change_page()
	selected = (zone // 8) * 256 + (zone % 8) * 4 + act
	for _ in range(selected & 0xFF):
		press(DOWN)
	item(selected)
	press(START)
	wait_level(zone, act)
	g.write('f_slomocheat', 1)
	press(START)
	assert g.read('f_pause', 2) == 1
	press(A)
	title()
	enter_menu()
	item(selected)
	returns.append({'zone': zone, 'act': act + 1, 'selection': selected})
	if zone >= 8:
		expect_text(1, 1, 'SCRAP MADNESS')
		g.video.save(args.output / 'page-2-return.png')
print('Level -> title -> menu preserves the selected page and act on both pages.', flush=True)

# The moved special-stage option must still enter the real stage.
g.restore(menu)
press(UP); press(UP); item(BONUS)
press(START)
for _ in range(800):
	step()
	if g.read('v_vbla_routine', 2) == g.s['Vint_S1SS']:
		break
else:
	raise AssertionError('Special stage did not start')
item(BONUS)
checks = []
for zone in range(16):
	for act in range(4):
		g.restore(menu)
		selected = (zone // 8) * 256 + (zone % 8) * 4 + act
		g.write('v_levselitem', selected, 2)
		press(START)
		wait_level(zone, act)
		step(15); item(selected)
		checks.append({'zone': zone, 'act': act + 1, 'passed': True})
	print('Four-act launch checks passed for zone ' + str(zone), flush=True)
print('Menu controls, layout, sound, return memory, special stage and all 64 act boots pass.', flush=True)
print(f'{len(free_canary)} contiguous free bytes remain untouched through all checked scenes.', flush=True)
(args.output / 'report.json').write_text(json.dumps({'pal': args.pal, 'return_memory': returns, 'checks': checks,
    'free_ram': {'start': free_start | 0xFF0000, 'end_exclusive': free_end | 0xFF0000,
                 'bytes': len(free_canary), 'canary_preserved': True}}, indent=2) + '\n')
g.close()
