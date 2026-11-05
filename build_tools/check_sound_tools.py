#!/usr/bin/env python3
"""Check native Clone music, retained Z80 SFX, compression and build failures.

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
	end = 2 + int.from_bytes(data[:2], 'big')
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


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--mono', default=os.environ.get('MONO') or shutil.which('mono'))
	p.add_argument('--tools-dir', type=Path)
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
		shutil.copytree(ROOT / 'sound/CloneDriver', d / 'sound/CloneDriver')
		for name in ['KEHmusic.exe', 'KEHsfx.exe', 'IniFile.dll', '_definitions/s2.macros.asm', 'sound/dacids.gen.asm', '_definitions/_smps2asm_inc.asm', '_definitions/Sound Constants.asm']:
			shutil.copyfile(ROOT / name, d / name)
		(d / 'md-main.asm').write_text('; Temporary packer fixture\n')
		(d / 'sound/DAC/sample.bin').write_bytes(b'\x80')
		(d / 'sound/DAC/DAC.ini').write_text('[dKick]\nFile=sample.bin\nRate=8000\n')
		packer = ([args.mono] if os.name != 'nt' else []) + [d / 'KEHmusic.exe', '--tools-dir', tools]

		def assemble(body, origin=0, music=True, okay=True):
			(d / 'fixture.asm').write_text('\tCPU 68000\n\tpadding off\n' + ('kehmusic = 1\n' if music else '') +
				'allOptimizations = 1\n\tinclude "_definitions/s2.macros.asm"\n' + ('\tinclude "_definitions/Sound Constants.asm"\n\tinclude "sound/CloneDriver/engine/_smps2asm_inc.asm"\n' if music else '\tinclude "_definitions/_smps2asm_inc.asm"\n') + f'\torg ${origin:X}\n' + body)
			(d / 'fixture.p').unlink(missing_ok=True)
			try:
				message = run([asl, '-xx', '-n', '-q', '-A', '-U', '-E', 'fixture.log', '-i', '.', '-o', 'fixture.p', 'fixture.asm'], d, okay)
			except AssertionError as error:
				raise AssertionError((d / 'fixture.log').read_text()) from error
			if not okay:
				return re.sub(r'\s+', ' ', message + (d / 'fixture.log').read_text())
			run([p2bin, 'fixture.p', 'fixture.bin'], d)
			return (d / 'fixture.bin').read_bytes()[origin:]

		# SFX output follows the same sound/ convention as the music packer.
		(d / 'sound/SFX').mkdir()
		(d / 'sound/SFX/SFX.ini').write_text('')
		(d / 'sound/SFX/DACSFX.ini').write_text('')
		run(([args.mono] if os.name != 'nt' else []) + [d / 'KEHsfx.exe'], d)
		for name in ('sfxbank', 'dacsfxlist', 'sfxids', 'sfxnames'):
			assert (d / ('sound/' + name + '.gen.asm')).is_file(), name
		assert not list(d.glob('*.gen.asm')), 'Generated sound tables leaked into project root'

		# Music uses native big-endian relative pointers; SFX retain KeH's compact format.
		header = '\tsmpsHeaderStartSong 2,1\n\tsmpsHeaderVoice Voice\n\tsmpsHeaderChan 1,0\n\tsmpsHeaderTempo 1,$80\n\tsmpsHeaderFM Track,0,0\nTrack:\n\tsmpsFMvoice 0\n\tsmpsCall Sub\n\tsmpsLoop 0,2,Track\n\tsmpsJump Track\nSub:\n\tsmpsReturn\nVoice:\n\tdc.b $12\n'
		data = assemble(header)
		assert data == assemble(header, 0x12340), 'Music pointers depend on their ROM/RAM address'
		assert int.from_bytes(data[:2], 'big') == data.index(b'\x12')
		assert int.from_bytes(data[8:10], 'big') == 12, 'Track pointer is not relative to the header'
		sfx = '\tsmpsHeaderStartSong 2,1\n\tsmpsHeaderVoiceNull\n\tsmpsHeaderTempoSFX 1\n\tsmpsHeaderChanSFX 1\n\tsmpsHeaderSFXChannel cFM5,Track,0,0\nTrack:\n\tsmpsStop\n'
		data = assemble(sfx, 0x18000, music=False)
		assert data[:5] == bytes.fromhex('0000010105') and data[5:7] == bytes.fromhex('0980'), 'Compact SFX header or absolute bank pointer changed'
		commands = '\tsmpsHeaderStartSong 3,1\n\tsmpsNoteFill 3\n\tsmpsFMAlterVol $7F,$FD\n\tsmpsModSet 4,2,3,8\n\tsmpsHeaderStartSong 1\n\tsmpsNoteFill 4\n\tsmpsModSet 4,2,3,8\n\tsmpsDcb nDb4,nCs4,nGs3,nAb3\n'
		assert assemble(commands) == bytes.fromhex('FF1D03FF06FDFF2104020308FF0804FF0E04020308B2B2ADAD'), 'Imported command or note alias differs'
		message = assemble('\tsmpsHeaderStartSong 3,1\n\tsmpsFMvoice 0,2\n', okay=False)
		assert 'copy this instrument locally' in message, message
		assert 'newer version of SMPS2ASM' in assemble('\tsmpsHeaderStartSong 2,2\n', okay=False)
		print('Macros: native relative music, retained Z80 SFX, modern aliases and import diagnostics.')

		# Compare actual instrument bytes to the preserved independent raw dumps.
		for name in ['HTZ', 'GGZ1', 'RRZ1']:
			song = ROOT / 'sound/music' / (name + '.asm')
			text = song.read_text()
			data = assemble('\tinclude "' + song.as_posix() + '"\n')
			voice = int.from_bytes(data[:2], 'big')
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
				# Clone stores TL before AR; bit 7 marks carriers rather than a YM value.
				actual = actual[:5] + actual[9:] + bytes(v & 127 for v in actual[5:9])
				expected[21:25] = bytes(v & 127 for v in expected[21:25])
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
		with (d / 'sound/CloneDriver/engine/_smps2asm_inc.asm').open('a') as f:
			f.write('; Shared macro change\n')
		assert 'Building song' in run(packer, d)
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
				assert row.getint('Size') == len(raw) and (d / 'sound/music' / row['OutputFile']).read_bytes() == raw
			return row
		auto_case(bytes(0x4000), True)
		auto_case(random.Random(0x4B4F53).randbytes(0x4000), False)
		auto_case(bytes(6), False) # Kosinski+ ties six raw zero bytes: keep raw.
		print('Automatic music storage: fits+smaller compresses; incompressible and equal-size inputs stay raw.')

		# Every music entry is an unbanked ROM pointer plus sizes and format flags.
		(d / 'sound/music/raw.bin').write_bytes(random.Random(21).randbytes(0x4000))
		ini.write_text('[Raw]\nTitle=Raw binary\nFile=raw.bin\n')
		run(packer, d)
		for name in ('dacbanks', 'dacinfo', 'dacids', 'musicdata', 'musicinfo', 'musicids', 'musicnames'):
			assert (d / ('sound/' + name + '.gen.asm')).is_file(), name
		assert not list(d.glob('*.gen.asm')), 'Generated tables leaked into project root'
		assert not list((d / 'sound/generated').glob('music-bank-*.gen.asm')), 'Music still uses banks'
		assert 'SoundMusicEntry Mus_Raw,$4000,$4000,$00' in (d / 'sound/musicinfo.gen.asm').read_text()
		layout = (d / 'sound/musicdata.gen.asm').read_text()
		assert 'startBank' not in layout and 'finishBank' not in layout
		(d / 'sound/music/raw.bin').write_bytes(bytes(0x4001))
		assert '$4000' in run(packer, d, False)
		ini.write_text('[Raw]\nTitle=Raw binary\nFile=raw.bin\nBinaryFormat=KosinskiPlus\n')
		(d / 'sound/music/raw.bin').write_bytes(bytes(100))
		assert 'Kosinski+' in run(packer, d, False)
		from convert_s1_ss_background import kosinski_plus as encode_kosinski_plus
		packed = encode_kosinski_plus(bytes(128))
		(d / 'sound/music/raw.bin').write_bytes(packed)
		run(packer, d)
		config = configparser.ConfigParser(interpolation=None); config.read(ini)
		assert config['Raw'].getboolean('IsCompressed')
		assert config['Raw'].getint('UncompressedSize') == 128
		assert config['Raw'].getint('Size') == len(packed)
		# Packed input may be larger than decoded input; only decoded RAM is bounded.
		packed = encode_kosinski_plus(random.Random(9).randbytes(0x4000))
		assert len(packed) > 0x4000
		(d / 'sound/music/raw.bin').write_bytes(packed)
		run(packer, d)
		(d / 'sound/music/raw.bin').write_bytes(encode_kosinski_plus(bytes(0x4001)))
		assert '$4000' in run(packer, d, False)
		ini.write_text('[Raw]\nTitle=Invalid assembly flag\nFile=track.asm\nBinaryFormat=KosinskiPlus\n')
		assert 'precompressed .bin' in run(packer, d, False)
		print('Binary imports: unbanked raw/compressed entries; decoded bounds and malformed inputs checked.')

		# DAC samples keep their independent Z80 windows; ordinary data can lie between.
		layout = '\tdc.b $A5\n\tinclude "sound/generated/dac-bank-1.gen.asm"\n'
		data = assemble(layout)
		assert data[0] == 0xA5 and data[0x8000] == 0x80
		assert 'must fit in $8000' in assemble('\tstartBank\n\tds.b $8001\n\tfinishBank\n', okay=False)
		print('DAC banks: independent alignment and window overflow checks retained.')

		# Check every packed song against a fresh assembly with an independent decoder.
		music = configparser.ConfigParser(interpolation=None)
		music.read(ROOT / 'sound/music/music.ini')
		shutil.copyfile(ROOT / 'sound/dacids.gen.asm', d / 'sound/dacids.gen.asm')
		for name in music.sections():
			if music[name].getboolean('IsCompressed', fallback=False):
				raw = kosinski_plus((ROOT / 'sound/music' / music[name]['OutputFile']).read_bytes())
				assert len(raw) <= 0x4000 and len(raw) == music[name].getint('UncompressedSize')
				assert raw == assemble('\tinclude "' + (ROOT / 'sound/music' / music[name]['File']).as_posix() + '"\n'), name
		print('All compressed project songs match fresh assembly using the independent Kosinski+ decoder.')
	print('Sound tool checks passed.')


if __name__ == '__main__':
	main()
