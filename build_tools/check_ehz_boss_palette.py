#!/usr/bin/env python3
"""Verify EHZ's one-word palette load, original chassis colors and live cycles.

The gameplay runner imports the VDP/environment checks. Native checks execute
the assembled constructor, real palette cycles and escape cleanup.
"""
from pathlib import Path
import argparse
import ctypes as C
import json
import struct

from check_boss_shared_art import raster, unpack
from check_ehz_boss import symbols, pieces
from import_ehz2_pp_background import nemesis

ROOT = Path(__file__).resolve().parents[1]


def source_pixels(rom, s, source):
	original = nemesis((source/'art/nemesis/EHZ boss.nem').read_bytes())
	actual = unpack(rom, s['Kospm_EHZ_Boss'])
	assert actual == (ROOT/'art/uncompressed/EHZ boss.unc').read_bytes()
	assert len(actual) == len(original) == 128*32
	stock = (source/'s2built.bin').read_bytes()
	ss = symbols(source/'s2.lst')
	oldrows = pieces(stock, ss['Obj56_MapUnc_2FA58'], 8, 8)
	newrows = pieces(rom, s['Map_EHZBoss_Ground'], 8)
	palettes = [struct.unpack('>16H', (source/'art/palettes/SonicAndTails.bin').read_bytes()),
		struct.unpack('>48H', (source/'art/palettes/EHZ.bin').read_bytes())[:16]]
	# Independent RGB oracle: retain all six original metal tones, tinted to
	# Mystic Island's fixed ramp. Only S2's extra $666 needs boss-owned $A88.
	colors = {0:0x222, 0xEEE:0xEEE, 0xAAA:0xECC, 0x888:0xCAA,
		0x666:0xA88, 0x444:0x866, 0x00E:0x00E, 0x008:0x008,
		0x8AE:0x8CE, 0x46A:0x06C, 0x0AE:0x0AE, 0x08E:0x08E}
	palette = list(struct.unpack('>16H', (ROOT/'palette/SonicAndTails.bin').read_bytes()))
	palette += list(struct.unpack('>48H', (ROOT/'palette/EHZ.bin').read_bytes())[:16])
	palette[28] = s['EHZBoss_MetalColor']
	total = 0
	for frame, (old, new) in enumerate(zip(oldrows, newrows)):
		assert old == new
		role = int(frame != 0)
		expected = {p:colors[palettes[role][index]] for p, (_, index) in raster(old, [(0, original)]).items()}
		pixels = raster(new, [(0, actual)])
		assert {p:palette[role*16+index] for p, (_, index) in pixels.items()} == expected, frame
		if role:
			assert not {index for _, index in pixels.values()} & {2,3,4,5,10,11}
		total += len(pixels)
	return {'source_tiles':128, 'source_mapping_frames':8, 'visible_rgb_pixels':total}


def native(a):
	from native_test_core import Native
	m = Native(a.rom, a.listing)
	s = m.s
	pool = list(range(s['v_lvlobjspace'], s['v_lvlobjend'], s['object_size']))
	body = pool[0]
	base = s['v_palette'] & 0xFFFFFF
	offset = s['EHZBoss_MetalPaletteOffset']
	assert offset == 0x38
	for act in (0,1):
		m.start()
		m.write('Current_ZoneAndAct', 0x300+act, 2)
		before = bytes(range(128))
		m.cpu.mem_write(base, before)
		m.put(body, 'code', s['EHZBoss'])
		m.put(body, 'obX', s['EHZBoss_LandingX'], 2)
		m.put(body, 'obY', s['EHZBoss_LandingY']+8, 2)
		# Six available children must not acquire or alter any palette word.
		for p in pool[7:]:
			m.put(p, 'code', s['DisplaySprite'])
		m.act('EHZBoss', body)
		assert m.get(body, 'obRoutine') == 0
		assert bytes(m.cpu.mem_read(base, 128)) == before
		m.put(pool[7], 'code', 0)
		m.act('EHZBoss', body)
		expected = bytearray(before)
		expected[offset:offset+2] = struct.pack('>H', s['EHZBoss_MetalColor'])
		assert bytes(m.cpu.mem_read(base, 128)) == expected
		assert m.get(body, 'EHZBoss_saved_metal_color', 2) == int.from_bytes(before[offset:offset+2], 'big')
		# Cleanup must restore the saved word, not a hardcoded act color.
		m.put(body, 'ob2ndRout', 10)
		m.put(body, 'objoff_30', 4)
		m.put(body, 'obRender', 4)
		m.write('Camera_Max_X_pos', s['EHZBoss_CameraExitRight'], 2)
		m.act('EHZBoss_Escape', body)
		assert not m.get(body, 'code')
		assert bytes(m.cpu.mem_read(base, 128)) == before
		# Execute both real clocks with the loaded metal word present.
		palette = (ROOT/'palette/SonicAndTails.bin').read_bytes()+(ROOT/f'palette/{"EHZ2 PP" if act else "EHZ"}.bin').read_bytes()
		m.cpu.mem_write(base, palette)
		m.cpu.mem_write(base+offset, struct.pack('>H', s['EHZBoss_MetalColor']))
		initial = bytes(m.cpu.mem_read(base, 128))
		allowed = set(range(0x24, 0x2C)) | ({0x62,0x63,0x66,0x67,0x6C,0x6D} if act else set())
		phases = set()
		for tick in range(72):
			m.write('VDP_Command_Buffer_Slot', s['VDP_Command_Buffer'] & 65535, 2)
			m.act('PalCycle_Load')
			current = bytes(m.cpu.mem_read(base, 128))
			assert all(current[i] == initial[i] for i in range(128) if i not in allowed)
			phases.add(current[0x24:0x2C])
		assert len(phases) == 4
	return {'masked_constructor_acts':2, 'allocation_retry_acts':2, 'exact_restore_acts':2, 'cycling_updates_per_act':72}


def environment(g):
	"""Compare real rendered terrain/player/HUD with and without the mask."""
	from check_companion_followup import place
	initial = g.save()
	positions = (g.s['EHZBoss_CameraLeft'], g.s['EHZBoss_CameraFightRight'], g.s['EHZBoss_CameraExitRight'])
	for x in positions:
		g.restore(initial)
		g.write('Dynamic_Resize_Routine', 0)
		g.write('f_timecount', 0)
		for name in ('Camera_X_pos','Camera_Min_X_pos','Camera_Max_X_pos','Camera_Max_X_pos_target'):
			g.write(name, x, 2)
		place(g, 'v_player', x+160, g.s['EHZBoss_LandingY']-30, False)
		g.put('v_player', 'obControl', 0x81)
		g.write('Screen_redraw_flag', 1)
		g.run(30)
		state = g.save()
		before = []
		for _ in range(36):
			g.run()
			before.append(g.video.tobytes())
		g.restore(state)
		g.write(g.s['v_palette']+g.s['EHZBoss_MetalPaletteOffset'], g.s['EHZBoss_MetalColor'], 2)
		for frame in before:
			g.run()
			assert g.video.tobytes() == frame, ('Mask changes terrain/player/HUD pixels', x)
	g.restore(initial)
	return {'camera_positions':list(positions), 'frames_per_position':36, 'changed_environment_pixels':0}


class LivePalette:
	def __init__(self, g, body, act):
		self.g, self.body, self.act = g, body, act
		self.original = tuple(g.read(g.s['v_palette']+i*2,2) for i in range(64))
		self.cram = (C.c_uint16*64).in_dll(g.core, 'cram')
		self.foreground, self.background = set(), set()
		self.samples = 0
		self.metal_samples = 0
		self.restored = False

	def sample(self):
		g = self.g
		palette = tuple(g.read(g.s['v_palette']+i*2,2) for i in range(64))
		hardware = tuple(((v&7)<<1)|((v&0x38)<<2)|((v&0x1C0)<<3) for v in self.cram)
		allowed = {17,18,19,20,21,28} | ({49,51,54} if self.act else set())
		for i in range(64):
			if i not in allowed:
				assert palette[i] == hardware[i] == self.original[i], ('Fixed palette entry changed',i)
		active = g.get(self.body,'code') == g.s['EHZBoss']
		expected = g.s['EHZBoss_MetalColor'] if active else self.original[28]
		assert palette[28] == expected
		# CRAM trails the MD palette by VBlank; either transition value is valid.
		assert hardware[28] in (self.original[28], g.s['EHZBoss_MetalColor'])
		self.metal_samples += int(active and hardware[28] == g.s['EHZBoss_MetalColor'])
		self.restored |= not active and hardware[28] == self.original[28]
		self.foreground.add(hardware[18:22])
		self.background.add(tuple(hardware[i] for i in (49,51,54)))
		self.samples += 1

	def report(self):
		assert self.metal_samples > 100
		assert self.restored or not self.act
		assert len(self.foreground) == 4
		assert len(self.background) == (3 if self.act else 1)
		return {'palette_and_cram_samples':self.samples, 'foreground_phases':len(self.foreground), 'background_phases':len(self.background), 'metal_cram_samples':self.metal_samples, 'restored_after_escape':self.restored}


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
	p.add_argument('--s2disasm', type=Path, required=True)
	p.add_argument('--output', type=Path, required=True)
	a = p.parse_args()
	s = symbols(a.listing)
	report = {'art':source_pixels(a.rom.read_bytes(),s,a.s2disasm), 'native':native(a)}
	a.output.mkdir(parents=True, exist_ok=True)
	(a.output/'report.json').write_bytes((json.dumps(report,indent=2)+'\n').replace('\n','\r\n').encode())
	print(json.dumps(report))


if __name__ == '__main__':
	main()
