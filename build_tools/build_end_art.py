#!/usr/bin/env python3
"""Pack editable resident end-of-act banks as padding-free moduled Kosinski+.

--import-nemesis imports untouched legacy banks; shared boss art comes from
build_boss_shared_art.py. Ordinary packing reads the editable .unc files.
"""
from pathlib import Path
import argparse
import json
import struct
from convert_s1_ss_background import kosinski_plus, kosinski_plus_decode
from import_ehz2_pp_background import nemesis
from sprite_palette import PLAYER_FROM_S1, PLAYER_FROM_LEGACY, remap_pixels

ROOT = Path(__file__).resolve().parents[1]
BANKS = (
	('OldEggPod', 'Old Eggpod', 'Nem_OldEggPod'),
	('EggmanFace', 'Eggman face', 'Nem_OldEggPod'),
	('Weapons', 'Boss weapons', 'Nem_Weapons'),
	('Exhaust', 'Boss exhaust', 'Nem_Exhaust'),
	('Prison', 'Prison Capsule', 'Nem_Prison'),
	('EHZ_Boss', 'EHZ boss', 'Nem_EHZ_Boss'),
	('BossExplosion', 'Large explosion', 'Nem_BossExplosion'),
	('MechaEffects', 'Mecha Sonic effects', 'Nem_MechaEffects'),
	('Bonus', 'Hidden bonus', 'Nem_Bonus'),
	('Explosion', 'Explosion', 'Nem_Explosion'),
)


def pack_moduled(raw):
	assert 0 < len(raw) <= 0xFFFF and not len(raw) % 32
	packed = bytearray(struct.pack('>H', len(raw)))
	for start in range(0, len(raw), 0x1000):
		module = raw[start:start+0x1000]
		stream = bytes(kosinski_plus(module))
		assert kosinski_plus_decode(stream)[0] == module
		packed += stream
	return bytes(packed)


def pack_fz_damaged_eggmobile():
	# S1's FZ Damaged Eggmobile and FZ Eggmobile Legs mappings own these ranges.
	# The two damaged cockpit poses use P1. Legs and lower metal use P2.
	source = ROOT / 'art/nemesis/S1/Boss - Eggman after FZ Fight.nem'
	raw = nemesis(source.read_bytes())
	assert len(raw) == 0x4C * 32
	cockpit_start, cockpit_end = 0x20 * 32, 0x3A * 32
	# This Nemesis source already uses the earlier PLAYER_FROM_LEGACY remap.
	# Translate from those slots rather than applying the S1 conversion twice.
	lookup = tuple(PLAYER_FROM_S1[PLAYER_FROM_LEGACY.index(slot)] for slot in range(16))
	cockpit = remap_pixels(raw[cockpit_start:cockpit_end], lookup)
	packed = pack_moduled(raw[:cockpit_start] + cockpit + raw[cockpit_end:])
	source.with_suffix('.kospm').write_bytes(packed)
	return dict(label='Kospm_FzEggman', raw=len(raw), packed=len(packed), odd=bool(len(packed) & 1))


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--import-nemesis', action='store_true')
	p.add_argument('--rom', type=Path)
	p.add_argument('--listing', type=Path)
	p.add_argument('--report', type=Path)
	a = p.parse_args()
	cache = {}
	if a.import_nemesis:
		assert a.rom and a.listing
		import native_test_core as n
		m = n.Native(a.rom, a.listing)
		rom = a.rom.read_bytes()

	def decode(original):
		if original not in cache:
			count = struct.unpack_from('>H', rom, m.s[original])[0] & 0x7FFF
			m.act('NemDecToRAM', regs={n.UC_M68K_REG_A0:m.s[original],
				n.UC_M68K_REG_A4:0xFF0000}, limit=2000000)
			cache[original] = bytes(m.cpu.mem_read(0xFF0000, count*32))
		return cache[original]

	report = []
	for label, name, original in BANKS:
		source = ROOT / f'art/uncompressed/{name}.unc'
		if a.import_nemesis and label not in ('OldEggPod','EggmanFace','Exhaust'):
			raw = decode(original)
			if source.exists():
				assert source.read_bytes() == raw, source
			else:
				source.write_bytes(raw)
		raw = source.read_bytes()
		packed = pack_moduled(raw)
		(ROOT / f'art/moduled kosinski/{name}.kospm').write_bytes(packed)
		report.append(dict(label='Kospm_'+label, raw=len(raw),
			packed=len(packed), odd=bool(len(packed) & 1)))
	report.append(pack_fz_damaged_eggmobile())
	if a.report:
		a.report.write_text(json.dumps(report, indent=2)+'\n')
	print(f'{len(report)} resident banks: {sum(x["raw"] for x in report)} raw '
		f'-> {sum(x["packed"] for x in report)} moduled Kosinski+ bytes.')


if __name__ == '__main__':
	main()
