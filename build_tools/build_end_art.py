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

ROOT = Path(__file__).resolve().parents[1]
BANKS = (
	('OldEggPod', 'Old Eggpod', 'Nem_OldEggPod'),
	('EggmanFace', 'Eggman face', 'Nem_OldEggPod'),
	('Weapons', 'Boss weapons', 'Nem_Weapons'),
	('Exhaust', 'Boss exhaust', 'Nem_Exhaust'),
	('Prison', 'Prison Capsule', 'Nem_Prison'),
	('EggPod', 'Boss Ship', 'Nem_EggPod'),
	('EHZ_Boss', 'EHZ boss', 'Nem_EHZ_Boss'),
	('EggChopper', 'Chopper blades for EHZ boss', 'Nem_EggChopper'),
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
		if a.import_nemesis and label not in ('OldEggPod','EggmanFace','Exhaust','EggPod','EggChopper'):
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
	if a.report:
		a.report.write_text(json.dumps(report, indent=2)+'\n')
	print(f'{len(report)} resident banks: {sum(x["raw"] for x in report)} raw '
		f'-> {sum(x["packed"] for x in report)} moduled Kosinski+ bytes.')


if __name__ == '__main__':
	main()
