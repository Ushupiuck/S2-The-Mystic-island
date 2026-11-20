#!/usr/bin/env python3
"""Check KeH macro encoding, real voice dumps, bank layout, and build failures.

Run after rebuilding the sound tools and ROM. Fixtures use a temporary project;
the working music, configuration, generated banks, and ROM are never modified.
"""
import argparse
import configparser
import os
from pathlib import Path
import re
import random
import shutil
import struct
import subprocess
import tempfile
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]


def saxman(data):
	"""Independent decoder, including the zero dictionary used by the Z80 driver."""
	assert len(data) >= 2
	end = 2 + int.from_bytes(data[:2], 'little')
	assert end == len(data), 'Invalid Saxman payload length'
	result = bytearray()
	i = 2
	while i < end:
		flags = data[i]
		i += 1
		for bit in range(8):
			if i == end:
				break
			if flags & (1 << bit):
				result.append(data[i])
				i += 1
			else:
				assert i + 2 <= end, 'Truncated dictionary reference'
				low, high = data[i:i + 2]
				i += 2
				source = ((low | (high & 0xF0) << 4) + 0x12) & 0xFFF
				source |= len(result) & ~0xFFF
				if source >= len(result):
					source -= 0x1000
				for offset in range((high & 15) + 3):
					result.append(0 if source < 0 else result[source + offset])
	return bytes(result)


def kosinski_plus(data):
	raw,consumed=kosinski_plus_decode(data)
	assert consumed==len(data),'Trailing data after Kosinski+ stream'
	return bytes(raw)


def check_bus_macros(assemble):
	"""Execute the actual 68000 macros with guarded byte-wide Z80 RAM."""
	from unicorn import (Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN,
		UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_READ, UC_MEM_WRITE)
	from unicorn import m68k_const as reg
	cpu = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
	cpu.ctl_set_cpu_model(reg.UC_CPU_M68K_M68000)
	cpu.mem_map(0x1000, 0x10000)
	cpu.mem_map(0xA00000, 0x2000)
	cpu.reg_write(reg.UC_M68K_REG_SR, 0x2700)
	registers = [getattr(reg, 'UC_M68K_REG_' + name + str(i))
		for name, count in (('D', 8), ('A', 7)) for i in range(count)]
	stack = 0x10000
	accesses = []
	def bus(cpu, access, address, size, value, unused):
		assert size == 1, f'Non-byte Z80 access at {address:X}: {size}'
		accesses.append((access, address, value if access == UC_MEM_WRITE else None))
	cpu.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, bus, begin=0xA00000, end=0xA01FFF)
	edges = (0, 1, 0x7F, 0x80, 0xFF, 0x100, 0x17A, 0x180,
		0x200, 0xFFF, 0x1000, 0x8000, 0xA180, 0xFFFF)
	tests = 0
	for number in range(8):
		for offset in (0x100, 0x103):
			base = 0x1000 + number*0x100 + (offset & 1)*0x80
			prefix = 'Z80_RAM = $A00000\n'
			write = assemble(prefix + f'\tWriteZ80Word d{number},${offset:X}\n')
			read = assemble(prefix + f'\tReadZ80Word ${offset:X},d{number}\n')
			cpu.mem_write(base, write)
			cpu.mem_write(base+0x40, read)
			initial = [0xA5000000 | (i+1)*0x10203 for i in range(len(registers))]
			for register, value in zip(registers, initial):
				cpu.reg_write(register, value)
			cpu.reg_write(reg.UC_M68K_REG_A7, stack)
			cpu.mem_write(stack-16, bytes([0xC3])*32)
			address = 0xA00000+offset
			values = range(0x10000) if (number, offset) in ((0, 0x100), (7, 0x103)) else edges
			for value in values:
				original = ((value*0x9E37 & 0xFFFF) << 16) | value
				cpu.reg_write(registers[number], original)
				cpu.mem_write(address-1, bytes((0x5A, 0xCC, 0xDD, 0xA5)))
				accesses.clear()
				cpu.emu_start(base, base+len(write), count=16)
				assert accesses == [(UC_MEM_WRITE, address, value & 255), (UC_MEM_WRITE, address+1, value >> 8)]
				assert bytes(cpu.mem_read(address-1, 4)) == b'\x5A'+value.to_bytes(2, 'little')+b'\xA5'
				assert cpu.reg_read(registers[number]) == original, 'Write clobbered its source'
				assert cpu.reg_read(reg.UC_M68K_REG_A7) == stack, 'Write unbalanced the stack'
				cpu.reg_write(registers[number], original ^ 0xFFFF)
				accesses.clear()
				cpu.emu_start(base+0x40, base+0x40+len(read), count=16)
				assert accesses == [(UC_MEM_READ, address+1, None), (UC_MEM_READ, address, None)]
				assert cpu.reg_read(registers[number]) == original, 'Read lost bits or kept stale destination bits'
				assert cpu.reg_read(reg.UC_M68K_REG_A7) == stack, 'Read unbalanced the stack'
				for i, register in enumerate(registers):
					if i != number:
						assert cpu.reg_read(register) == initial[i], 'Clobbered an unrelated register'
				assert bytes(cpu.mem_read(stack-16, 14)) == bytes([0xC3])*14
				assert bytes(cpu.mem_read(stack, 16)) == bytes([0xC3])*16
				tests += 1
	print(f'Z80 bus macros: {tests} word round trips; all Dn, odd/even addresses, byte accesses, registers and stack guards.')


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--mono', default=os.environ.get('MONO') or shutil.which('mono'))
	p.add_argument('--tools-dir', type=Path)
	p.add_argument('--bus-macros', action='store_true', help='Execute 68000/Z80 word macros with Unicorn as well')
	args = p.parse_args()
	if os.name != 'nt' and not args.mono:
		p.error('Mono is required; use --mono /path/to/mono.')
	if args.tools_dir:
		tools = args.tools_dir.resolve()
	elif os.name == 'nt':
		tools = ROOT / 'build_tools/Windows-x86'
	else:
		machine = os.uname().machine
		machine = {'amd64': 'x86_64', 'arm64': 'aarch64'}.get(machine, machine)
		tools = ROOT / 'build_tools' / (('BSD' if os.uname().sysname.endswith('BSD') else os.uname().sysname) + '-' + machine)
	asl, p2bin = [tools / (n + '.exe' if os.name == 'nt' else n) for n in (('asw' if os.name == 'nt' else 'asl'), 'p2bin')]
	env = os.environ.copy()
	env.update(AS_MSGPATH=str(tools), USEANSI='n')

	def run(command, cwd, okay=True):
		result = subprocess.run([str(c) for c in command], cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
		assert (result.returncode == 0) == okay, result.stdout
		return result.stdout

	with tempfile.TemporaryDirectory(prefix='keh sound ') as temporary:
		d = Path(temporary)
		(d / 'sound/music').mkdir(parents=True)
		(d / 'sound/DAC').mkdir()
		(d / '_definitions').mkdir()
		for name in ['KEHmusic.exe', 'KEHsfx.exe', 'IniFile.dll', '_definitions/s2.macros.asm', 'sound/dacids.gen.asm', '_definitions/_smps2asm_inc.asm']:
			shutil.copyfile(ROOT / name, d / name)
		(d / 'md-main.asm').write_text('; Temporary packer fixture\n')
		(d / 'sound/DAC/sample.bin').write_bytes(b'\x80')
		(d / 'sound/DAC/DAC.ini').write_text('[dKick]\nFile=sample.bin\nRate=8000\n')
		packer = ([args.mono] if os.name != 'nt' else []) + [d / 'KEHmusic.exe', '--tools-dir', tools]

		def assemble(body, origin=0, music=True, okay=True):
			(d / 'fixture.asm').write_text('\tCPU 68000\n\tpadding off\n' + ('kehmusic = 1\n' if music else '') +
				'allOptimizations = 1\n\tinclude "_definitions/s2.macros.asm"\n\tinclude "_definitions/_smps2asm_inc.asm"\n' + f'\torg ${origin:X}\n' + body)
			(d / 'fixture.p').unlink(missing_ok=True)
			try:
				message = run([asl, '-xx', '-n', '-q', '-A', '-U', '-E', '-i', '.', '-o', 'fixture.p', 'fixture.asm'], d, okay)
			except AssertionError as error:
				raise AssertionError((d / 'fixture.log').read_text()) from error
			if not okay:
				return re.sub(r'\s+', ' ', message + (d / 'fixture.log').read_text())
			run([p2bin, 'fixture.p', 'fixture.bin'], d)
			return (d / 'fixture.bin').read_bytes()[origin:]

		if args.bus_macros:
			check_bus_macros(assemble)

		# SFX output follows the same sound/ convention as the music packer.
		(d / 'sound/SFX').mkdir()
		(d / 'sound/SFX/SFX.ini').write_text('')
		(d / 'sound/SFX/DACSFX.ini').write_text('')
		run(([args.mono] if os.name != 'nt' else []) + [d / 'KEHsfx.exe'], d)
		for name in ('sfxbank', 'dacsfxlist', 'sfxids', 'sfxnames'):
			assert (d / ('sound/' + name + '.gen.asm')).is_file(), name
		assert not list(d.glob('*.gen.asm')), 'Generated sound tables leaked into project root'

		# Old and new syntax must retain KeH's relocatable pointer format.
		header = '\tsmpsHeaderStartSong 2,1\n\tsmpsHeaderVoice Voice\n\tsmpsHeaderChan 1,0\n\tsmpsHeaderTempo 1,$80\n\tsmpsHeaderFM Track,0,0\nTrack:\n\tsmpsFMvoice 0\n\tsmpsCall Sub\n\tsmpsLoop 0,2,Track\n\tsmpsJump Track\nSub:\n\tsmpsReturn\nVoice:\n\tdc.b $12\n'
		data = assemble(header)
		assert data == assemble(header, 0x12340), 'Music pointers depend on their ROM/RAM address'
		assert int.from_bytes(data[:2], 'little') == data.index(b'\x12')
		assert int.from_bytes(data[6:8], 'little') == 2, 'FM pointer is not relative to its end'
		sfx = '\tsmpsHeaderStartSong 2,1\n\tsmpsHeaderVoiceNull\n\tsmpsHeaderTempoSFX 1\n\tsmpsHeaderChanSFX 1\n\tsmpsHeaderSFXChannel cFM5,Track,0,0\nTrack:\n\tsmpsStop\n'
		data = assemble(sfx, 0x18000, music=False)
		assert data[:5] == bytes.fromhex('0000010105') and data[5:7] == bytes.fromhex('0980'), 'Compact SFX header or absolute bank pointer changed'
		commands = '\tsmpsHeaderStartSong 3,1\n\tsmpsNoteFill 3\n\tsmpsFMAlterVol $7F,$FD\n\tsmpsModSet 4,2,3,8\n\tsmpsHeaderStartSong 1\n\tsmpsNoteFill 4\n\tsmpsModSet 4,2,3,8\n\tsmpsDcb nDb4,nCs4,nGs3,nAb3\n'
		assert assemble(commands) == bytes.fromhex('FA03E6FDF003020303E804F005020308B2B2ADAD'), 'Imported command or note alias differs'
		assert assemble('\tsmpsHeaderStartSong 2\n\tsmpsHeaderVoiceUVB\n\tsmpsSetVol $7F\n\tsmpsClearPush\n\tsmpsStopSpecial\n') == bytes.fromhex('0000FB7FEDEE'), 'Universal header or implemented coordination commands changed'
		message = assemble('\tsmpsHeaderStartSong 3,1\n\tsmpsFMvoice 0,2\n', okay=False)
		assert 'copy this instrument locally' in message, message
		assert 'newer SMPS2ASM' in assemble('\tsmpsHeaderStartSong 2,2\n', okay=False)
		print('Macros: relative music, compact absolute SFX, modern aliases, note fill, modulation, and import diagnostics.')

		# Compare actual instrument bytes to the preserved independent raw dumps.
		for name in ['HTZ', 'GGZ1', 'RRZ1']:
			song = ROOT / 'sound/music' / (name + '.asm')
			text = song.read_text()
			data = assemble('\tinclude "' + song.as_posix() + '"\n')
			voice = int.from_bytes(data[:2], 'little')
			blocks = re.split(r'^;\s*Voice \$[0-9A-Fa-f]+\s*$', text, flags=re.M)[1:]
			assert blocks, 'No reference voices in ' + name
			for index, block in enumerate(blocks):
				comments = '\n'.join(line for line in block.splitlines() if line.startswith(';'))
				expected = bytearray(int(h, 16) for h in re.findall(r'\$([0-9A-Fa-f]{2})\b', comments))
				assert len(expected) == 25, (name, index, len(expected))
				# Source dumps list operators in 1,2,3,4 order. S2/KeH writes
				# sequential YM registers, whose operator order is 1,3,2,4.
				for group in range(1, 25, 4):
					expected[group + 1], expected[group + 2] = expected[group + 2], expected[group + 1]
				actual = data[voice + index * 25:voice + (index + 1) * 25]
				assert actual == expected, (name, index, actual.hex(), expected.hex())
			print(f'{name}: {len(blocks)} instruments match their original 25-byte dumps.')

		# A warm build skips assembly, but nested includes and macro changes invalidate it.
		(d / 'sound/music/track.asm').write_text('\tinclude "sound/music/shared.inc"\n')
		(d / 'sound/music/shared.inc').write_text('\tinclude "sound/music/notes.inc"\n')
		(d / 'sound/music/notes.inc').write_text(header)
		ini = d / 'sound/music/music.ini'
		ini.write_text('[Track]\nTitle=Fixture\nFile=track.asm\n')
		assert 'Building song' in run(packer, d)
		assert 'Building song' not in run(packer, d)
		with (d / 'sound/music/notes.inc').open('a') as f:
			f.write('; Nested dependency change\n')
		assert 'Building song' in run(packer, d)
		with (d / '_definitions/_smps2asm_inc.asm').open('a') as f:
			f.write('; Shared macro change\n')
		assert 'Building song' in run(packer, d)
		# Repeated source entries share a ROM payload while keeping individual flags.
		ini.write_text('[Track]\nTitle=Fixture\nFile=track.asm\n[Alias]\nTitle=Shared fixture\nFile=track.asm\nNoSpeedUp=True\nReserved=True\n')
		run(packer, d)
		assert 'Mus_Alias = Mus_Track' in (d / 'sound/musicdata.gen.asm').read_text()
		data = assemble('even macro\n\talign 2\n\tendm\nMusicPacked macro filename\n\tbinclude filename\n\tendm\n\tinclude "sound/musicdata.gen.asm"\n\tdc.l Mus_Track,Mus_Alias\n')
		assert data[-8:-4] == data[-4:], 'Shared song source was stored twice'
		assert 'musprop_nospeedup' in (d / 'sound/musicinfo.gen.asm').read_text()
		(d / 'sound/music/notes.inc').write_text('\tINVALID_SOUND_INSTRUCTION\n')
		assert 'failed' in run(packer, d, False)
		print('Cache: warm reuse; nested includes and shared macros rebuild; invalid sources stop the packer.')

		# Compression is automatic: decoded size must fit and stored size must win.
		def auto_case(raw, expected):
			(d / 'sound/music/auto.bin').write_bytes(raw)
			ini.write_text('[Auto]\nTitle=Automatic fixture\nFile=auto.bin\n')
			run(packer, d)
			config = configparser.ConfigParser(interpolation=None); config.read(ini)
			row = config['Auto']
			assert row.getboolean('IsCompressed', fallback=False) == expected
			assert row.getint('UncompressedSize') == len(raw)
			if expected:
				assert row.getint('Size') < len(raw)
				assert kosinski_plus((d / 'sound/music' / row['OutputFile']).read_bytes()) == raw
			else:
				assert row.getint('Size') == len(raw) and not row.get('OutputFile')
			return row
		auto_case(bytes(0x2000), True)
		auto_case(random.Random(0x4B4F53).randbytes(0x2000), False)
		auto_case(bytes(6), False) # Kosinski+ ties six raw zero bytes: keep raw.
		print('Automatic music storage: smaller streams compress; incompressible and equal-size inputs stay raw.')

		# Raw binaries must not silently acquire the compressed playlist flag.
		(d / 'sound/music/raw.bin').write_bytes(random.Random(0x4B4F53).randbytes(0x2000))
		ini.write_text('[Raw]\nTitle=Raw binary\nFile=raw.bin\n')
		run(packer, d)
		for name in ('dacbanks', 'dacinfo', 'dacids', 'musicdata', 'musicinfo', 'musicids', 'musicnames'):
			assert (d / ('sound/' + name + '.gen.asm')).is_file(), name
		assert not list(d.glob('*.gen.asm')), 'Generated sound tables leaked into project root'
		assert 'musprop_uncompressed' in (d / 'sound/musicinfo.gen.asm').read_text()
		assert '$2000 bytes' in (d / 'sound/musicdata.gen.asm').read_text()
		(d / 'sound/music/raw.bin').write_bytes(bytes(0x2001))
		assert '$2000' in run(packer, d, False)
		(d / 'sound/music/raw.bin').write_bytes(b'\x80')
		ini.write_text('[Raw]\nTitle=Raw binary\nFile=raw.bin\nBinaryFormat=KosinskiPlus\n')
		assert 'Kosinski+' in run(packer, d, False)
		# Explicit precompressed imports retain their encoding and decoded metadata.
		from convert_s1_ss_background import kosinski_plus as encode_kosinski_plus
		packed = encode_kosinski_plus(bytes(128))
		(d / 'sound/music/raw.bin').write_bytes(packed)
		run(packer, d)
		config = configparser.ConfigParser(interpolation=None); config.read(ini)
		assert config['Raw'].getboolean('IsCompressed')
		assert config['Raw'].getint('UncompressedSize') == 128
		assert config['Raw'].getint('Size') == len(packed)
		assert 'musprop_uncompressed' not in (d / 'sound/musicinfo.gen.asm').read_text()
		assert 'MusicPacked' in (d / 'sound/musicdata.gen.asm').read_text()
		ini.write_text('[Raw]\nTitle=Invalid assembly flag\nFile=track.asm\nBinaryFormat=KosinskiPlus\n')
		assert 'precompressed .bin' in run(packer, d, False)
		ini.write_text('[Raw]\nTitle=Oversized decoded input\nFile=raw.bin\nBinaryFormat=KosinskiPlus\n')
		# A literal followed by overlapping 256-byte copies exceeds $2000.
		(d / 'sound/music/raw.bin').write_bytes(encode_kosinski_plus(bytes(0x2001)))
		assert '$2000' in run(packer, d, False)
		print('Binary imports: raw $2000 accepted; malformed streams and MD stage overflow rejected.')

		# The music include crosses a Z80 boundary; DAC keeps its size check.
		(d / 'sound/music/raw.bin').write_bytes(random.Random(0x4B4F53).randbytes(0x2000))
		ini.write_text('[Raw]\nTitle=Raw binary\nFile=raw.bin\n')
		run(packer, d)
		layout = 'even macro\n\talign 2\n\tendm\n\tinclude "_definitions/Sound Bank Assets.asm"\n\tdc.b $5A\n\torg $7FF0\n\tinclude "sound/musicdata.gen.asm"\n\tdc.b $A5\n\tinclude "sound/generated/dac-bank-1.gen.asm"\n'
		(d / '_definitions/Sound Bank Assets.asm').write_text('SoundBankAssets macro kind,bank,{GLOBALSYMBOLS}\n\tendm\n')
		data = assemble(layout)
		assert data[0x7FF0:0x9FF0] == (d / 'sound/music/raw.bin').read_bytes()
		assert data[0x9FF0] == 0xA5 and data[0x10000] == 0x80
		(d / 'sound/DAC/sample.bin').write_bytes(bytes([0x80]) * 0x8000)
		run(packer, d)
		(d / '_definitions/Sound Bank Assets.asm').write_text('SoundBankAssets macro kind,bank,{GLOBALSYMBOLS}\n\tdc.b 0\n\tendm\n')
		assert 'must fit in $8000' in assemble(layout, okay=False)
		print('Music spans ROM boundaries; DAC overflow is caught by finishBank.')

		(d / 'sound/DAC/sample.bin').write_bytes(bytes(3))
		dac_ini = d / 'sound/DAC/DAC.ini'
		dac_entries = '[dKick]\nFile=sample.bin\nRate=8000\n[Trimmed]\nFile=sample.bin\nRate=8000\nPriority=True\n'
		dac_ini.write_text(dac_entries + 'StartOffset=1\n')
		run(packer, d)
		(d / '_definitions/Sound Bank Assets.asm').write_text('SoundBankAssets macro kind,bank,{GLOBALSYMBOLS}\n\tendm\n')
		bank = d / 'sound/generated/dac-bank-1.gen.asm'
		assert bank.read_text().count('BINCLUDE') == 1, 'Shared DAC file was stored twice'
		dac_macro = re.search(r'^DACSample\tmacro\b.*?^\tendm$', (ROOT / 'md-main.asm').read_text(), re.M | re.S)[0]
		data = assemble(dac_macro + '\n\tinclude "_definitions/Sound Bank Assets.asm"\n'
			'\tinclude "sound/dacinfo.gen.asm"\n\tinclude "sound/generated/dac-bank-1.gen.asm"\n')
		assert data[:5] == bytes.fromhex('0100800300') and data[7:12] == bytes.fromhex('0101800200')
		assert data[5] == data[12] and (data[6], data[13]) == (0, 2), 'DAC delay or priority changed'
		for invalid in (-1, 3):
			dac_ini.write_text(dac_entries + f'StartOffset={invalid}\n')
			assert 'DAC StartOffset must be inside the sample file: Trimmed' in run(packer, d, False)
		print('DAC aliases share storage; trimmed play ranges preserve delay and flags and reject invalid offsets.')

		# Check every packed song against a fresh assembly with an independent decoder.
		music = configparser.ConfigParser(interpolation=None)
		music.read(ROOT / 'sound/music/music.ini')
		shutil.copyfile(ROOT / 'sound/dacids.gen.asm', d / 'sound/dacids.gen.asm')
		for name in music.sections():
			if music[name].getboolean('IsCompressed', fallback=False):
				raw = kosinski_plus((ROOT / 'sound/music' / music[name]['OutputFile']).read_bytes())
				assert len(raw) <= 0x2000 and len(raw) == music[name].getint('UncompressedSize')
				assert raw == assemble('\tinclude "' + (ROOT / 'sound/music' / music[name]['File']).as_posix() + '"\n'), name
		print('All compressed project songs match fresh assembly using the independent Kosinski+ decoder.')
	print('Sound tool checks passed.')


if __name__ == '__main__':
	main()
