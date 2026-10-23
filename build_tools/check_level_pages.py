#!/usr/bin/env python3
"""Exercise level-select controls, return memory, and every four-act launch."""
from pathlib import Path
import argparse
import ctypes as C
import json
import struct
from convert_s1_ss_background import kosinski_plus_decode
from genesis_test_core import Genesis

p = argparse.ArgumentParser(description=__doc__)
for name in ('rom', 'listing', 'core', 'output'):
	p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--pal', action='store_true')
p.add_argument('--system-directory', type=Path, help='Optional BIOS directory for Mode 1 checks')
args = p.parse_args()
g = Genesis(args.core, args.rom, args.listing, args.output, args.pal, system_directory=args.system_directory)
UP, DOWN, LEFT, RIGHT, A, B, C_BUTTON, START = 4, 5, 6, 7, 1, 0, 8, 3
PAGE, BONUS, SOUND = [g.s['LevelSelect_' + name + 'Item'] for name in ('Page', 'Bonus', 'Sound')]


def step(frames=1):
	for _ in range(frames):
		g.run()
		assert not g.read('v_errortype'), ('CPU exception', g.frame)


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
	expect_menu_art()


def nemesis_art(data):
	"""Decode reference pixels independently of the game's upload path."""
	header = int.from_bytes(data[:2], 'big')
	position, color, table = 2, 0, {}
	while data[position] != 0xFF:
		entry = data[position]
		position += 1
		if entry & 0x80:
			color = entry & 15
			entry = data[position]
			position += 1
		table[entry & 15, data[position]] = (color, (entry >> 4) + 1)
		position += 1
	position = (position + 1) * 8

	def bits(count):
		nonlocal position
		value = 0
		for _ in range(count):
			value = (value << 1) | ((data[position // 8] >> (7 - position % 8)) & 1)
			position += 1
		return value

	pixels, target = [], (header & 0x7FFF) * 64
	while len(pixels) < target:
		code = 0
		for length in range(1, 9):
			code = (code << 1) | bits(1)
			if length == 6 and code == 63:
				count, color = bits(3) + 1, bits(4)
				break
			if (length, code) in table:
				color, count = table[length, code]
				break
		else:
			raise AssertionError('Invalid Nemesis code')
		pixels.extend([color] * count)
	assert len(pixels) == target
	raw = bytes((a << 4) | b for a, b in zip(pixels[::2], pixels[1::2]))
	if header & 0x8000:
		previous, rows = 0, bytearray()
		for row, in struct.iter_unpack('>I', raw):
			previous ^= row
			rows.extend(previous.to_bytes(4, 'big'))
		raw = bytes(rows)
	return raw


def expect_menu_art():
	font = nemesis_art(args.rom.read_bytes()[g.s['Nem_S3LevelSelect']:])
	assert bytes(g.vram[:32]) == bytes(32), 'Level-select blank tile was overwritten'
	actual = bytes(g.vram[(0x200 + i) ^ 1] for i in range(len(font)))
	assert actual == font, 'Level-select font pixels differ or use the wrong VRAM destination'


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
cd_status = g.read("MCD_status")
if args.system_directory:
	assert cd_status == 1, "Mode 1 bootstrap failed"
enter_menu()
item(0)
expect_text(1, 1, 'TWILIGHT HILL')
for row, text in ((22, 'NEXT'), (23, 'SPECIAL STAGE'), (24, 'SOUND TEST'), (25, '00 SONIC AND TAILS')):
	expect_text(row, 1, text)
menu = g.save()

# Up/Down must visit all 32 acts column-first, then each option, on both pages.
for page in (0, 0x100):
	g.restore(menu)
	if page:
		change_page()
		expect_text(1, 1, 'SCRAP MADNESS')
		expect_text(22, 1, 'PREVIOUS')
	expect_menu_art()
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
rom = args.rom.read_bytes()
cd_chunks = g.s['Chunk_Table'] == 0x426000
free_start = g.s.get('Free_RAM_Start', 0) & 0xFFFF
free_end = g.s['Free_RAM_End'] & 0xFFFF
free_canary = bytes((i * 37 + 19) & 255 for i in range(free_end-free_start))
for zone in range(16):
	for act in range(4):
		g.restore(menu)
		if cd_chunks:
			g.ram[free_start:free_end] = free_canary
			if 'Player_Art_Buffer_Start' in g.s:
				start = g.s['Player_Art_Buffer_Start'] & 0xFFFF
				end = g.s['Player_Art_Buffer_End'] & 0xFFFF
				g.ram[start:end] = bytes([0xA5]) * (end-start)
		selected = (zone // 8) * 256 + (zone % 8) * 4 + act
		g.write('v_levselitem', selected, 2)
		press(START)
		wait_level(zone, act)
		step(15); item(selected)
		if cd_chunks:
			header = g.s['LevelArtPointers'] + (zone * 4 + act) * 12
			source = struct.unpack_from('>I', rom, header + 8)[0] & 0xFFFFFF
			expected = kosinski_plus_decode(rom[source:])[0]
			actual = bytes(g.read(g.s['Chunk_Table'] + i) for i in range(len(expected)))
			assert actual == expected, (zone, act, 'CD chunks differ from decompressed ROM')
			assert bytes(g.ram[free_start:free_end]) == free_canary, (zone, act, 'freed MD RAM was touched')
			if 'Player_Art_Buffer_Start' in g.s:
				for label, name in [('Art_Shield', 'Shield.unc'), ('Art_Invincibility', 'Invincibility.unc'), ('Art_Ring', 'Ring.bin')]:
					data = (Path(__file__).resolve().parents[1] / 'art/uncompressed' / name).read_bytes()
					assert bytes(g.read(g.s[label]+i) for i in range(len(data))) == data, (zone, act, label)
		assert g.read("MCD_status") == cd_status
		checks.append({'zone': zone, 'act': act + 1, 'passed': True})
	print('Four-act launch checks passed for zone ' + str(zone), flush=True)
print('Menu controls, layout, sound, return memory, special stage and all 64 act boots pass.', flush=True)
(args.output / 'report.json').write_text(json.dumps({'pal': args.pal, 'return_memory': returns, 'checks': checks}, indent=2) + '\n')
g.close()
