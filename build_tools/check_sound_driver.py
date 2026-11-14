#!/usr/bin/env python3
"""Exercise word sound IDs, global commands, ONCHI and universal FM voices.

The expanded playlist and probe scores live in a disposable project copy.
The source ROM/catalog are unchanged. Requires Genesis Plus GX for the native
Z80 checks; the live cases execute the real MD/Z80/YM/PSG paths.
"""
from pathlib import Path
import argparse
import configparser
import ctypes as C
import json
import os
import shutil
import subprocess

from check_ehz_boss import symbols
from check_music_sequences import current_music
from check_z80_kosinski_plus import Native
from convert_s1_ss_background import kosinski_plus_decode
from genesis_test_core import Genesis

ROOT = Path(__file__).resolve().parents[1]


def native(core, rom, listing):
	s = symbols(listing)
	image = rom.read_bytes()
	program, _ = kosinski_plus_decode(image[s['Snd_Driver']:s['Snd_Driver_End']])
	m = Native(core, bytes(program), s)
	bank = s['SoundIndex'] & ~0x7FFF
	m.ram[0x8000:0x10000] = image[bank:bank+0x8000]
	m.ram[0x3000] = 0x76

	def call(label, a=0, hl=0x3100, de=0, iy=0):
		C.memset(C.addressof(m.regs), 0, C.sizeof(m.regs))
		m.regs.pc.d = s[label]
		m.regs.sp.d = 0x3F00
		m.ram[0x3F00:0x3F02] = bytes((0, 0x30))
		m.regs.af.d = a << 8
		m.regs.hl.d = hl
		m.regs.de.d = de
		m.regs.iy.d = iy
		m.regs.ix.d = s['zSongFM1']
		while not m.regs.halt and m.regs.cycles < 100000:
			m.core.z80_run(m.regs.cycles+32)
		assert m.regs.halt and m.regs.pc.d == 0x3000, (label, hex(m.regs.pc.d))

	track = s['zSongFM1']
	volume = track+s['zTrack.Volume']
	for psg in (False, True):
		m.ram[track+s['zTrack.VoiceControl']] = 0x80 if psg else 0
		m.ram[track+s['zTrack.PlaybackControl']] = 4
		for value in range(256):
			m.ram[0x3100] = value
			call('zCoordFlag', 0xFB)
			expected = (~(value >> 3)) & 15 if psg else (~value) & 127
			assert m.ram[volume] == expected, (psg, value, m.ram[volume], expected)
			assert m.regs.hl.d == 0x3101
	# Execute the TL writer against a harmless register/data pair. Full
	# attenuation must stay silent even when the patch has nonzero base TL.
	for level in (0, 7, 16, 127):
		m.ram[0x3100:0x3104] = bytes((level | 128,))*4
		for attenuation in range(128):
			call('zSetFMTLs', 0x40, de=(attenuation << 8) | 15, iy=0x3200)
			assert m.ram[0x3201] & 127 == min(127, level+attenuation)
			call('zSetFMTLs', 0x40, de=attenuation << 8, iy=0x3200)
			assert m.ram[0x3201] & 127 == level
	m.ram[s['zPushFlag']] = 255
	call('zCoordFlag', 0xED)
	assert not m.ram[s['zPushFlag']]

	# Resolve every UVB patch through the actual cache/ROM-aware voice helper.
	base = 0x8000+(s['UniversalVoiceBank'] & 0x7FFF)
	m.ram[track+s['zTrack.VoicePtrLow']:track+s['zTrack.VoicePtrLow']+2] = base.to_bytes(2, 'little')
	for voice in range(s['UniversalVoice_Count']):
		m.ram[track+s['zTrack.VoiceIndex']] = voice
		m.ram[s['zMusicSavedBank']+1] = 0
		call('zGetCurrentVoice')
		assert m.regs.hl.d == base+voice*25
		assert bytes(m.ram[m.regs.hl.d:m.regs.hl.d+25]) == image[s['UniversalVoiceBank']+voice*25:s['UniversalVoiceBank']+(voice+1)*25]
		assert m.ram[s['zMusicSavedBank']+1] == bank >> 15

	# Ristar's reachable sequence is eleven entries, shared by music FM tracks.
	offsets = (-1, 5, 4, 2, 6, -2, 3, -1, 4, 1, 3)
	assert m.ram[s['zDistortionGate']+1] == 3
	call('zToggleDistortion')
	assert m.ram[s['zDistortionGate']+1] == 0
	m.ram[track+s['zTrack.Transpose']] = 0
	for effect in (False, True):
		m.ram[s['zDoSFXFlag']] = 0x80 if effect else 0
		for i in range(22):
			call('zFMSetFreq', 0x80+37)
			note = 37+(0 if effect else offsets[i % 11])
			at = s['zFrequencies']+(note % 12)*2
			expected = int.from_bytes(bytes(m.ram[at:at+2]), 'little') | ((note // 12) << 11)
			at = track+s['zTrack.FreqLow']
			assert int.from_bytes(bytes(m.ram[at:at+2]), 'little') == expected
		assert m.ram[s['zDistortionIndex']+1] == 0
	call('zToggleDistortion')
	assert m.ram[s['zDistortionGate']+1] == 3
	return dict(absolute_volume_values=512, carrier_levels=512, unaffected_modulator_levels=512, universal_voices=s['UniversalVoice_Count'],
		onchi_music_notes=22, unaffected_sfx_notes=22, push_flag_reset=True)


def fixture(output, mono):
	d = output/'expanded sound catalog'
	if d.exists():
		shutil.rmtree(d)
	shutil.copytree(ROOT, d, ignore=shutil.ignore_patterns('.git', '.sound-build',
		'test-results', 'Music & SFX from other games', 's2built*', 'md-main.lst', 'sprite-bounds-pass*', '*.pdb'))
	ini = configparser.ConfigParser(interpolation=None)
	ini.optionxform = str
	path = d/'sound/music/music.ini'
	ini.read(path)
	for sound_id in range(len(ini.sections())+1, 0x100):
		ini[f'FixtureReserved{sound_id:03X}'] = dict(Title='Reserved fixture',
			File='Reserved Stage.asm', Reserved='True', NoSpeedUp='True')
	ini['HighGHZ'] = dict(Title='High GHZ', File='GHZ.asm')
	ini['HighLife'] = dict(Title='High 1-up', File='Extra life.asm', ExtraLifeJingle='True', NoSpeedUp='True')
	ini['UVBProbe'] = dict(Title='Universal voice probe', File='UVB probe.asm')
	with path.open('w', newline='\r\n') as f:
		ini.write(f, space_around_delimiters=False)
	probe = '''Probe_Header:
	smpsHeaderStartSong 2
	smpsHeaderVoiceUVB
	smpsHeaderChan 2,1
	smpsHeaderTempo 1,$80
	smpsHeaderDAC Probe_Stop
	smpsHeaderFM Probe_FM,0,0
	smpsHeaderPSG Probe_PSG,0,0,0,0
Probe_Stop:
	smpsStop
Probe_FM:
	smpsSetvoice 0
	smpsSetVol $7F
	dc.b nC4,$18
	smpsSetVol 0
	dc.b nD4,$18
	smpsSetvoice 34
	smpsSetVol $60
	dc.b nE4,$18
	smpsJump Probe_FM
Probe_PSG:
	smpsSetVol $7F
	dc.b nC4,$18
	smpsSetVol 0
	dc.b nD4,$18
	smpsSetVol $60
	dc.b nE4,$18
	smpsJump Probe_PSG
'''
	(d/'sound/music/UVB probe.asm').write_bytes(probe.replace('\n', '\r\n').encode())
	sfx = '''ProbeSFX_Header:
	smpsHeaderStartSong 2
	smpsHeaderVoiceUVB
	smpsHeaderTempoSFX 1
	smpsHeaderChanSFX 1
	smpsHeaderSFXChannel cFM5,ProbeSFX_FM,0,0
ProbeSFX_FM:
	smpsSetvoice 0
	smpsSetVol $7F
	dc.b nC4,$10
	smpsSetvoice 34
	smpsSetVol $60
	dc.b nE4,$10
	smpsStopSpecial
'''
	(d/'sound/SFX/UVBProbe.asm').write_bytes(sfx.replace('\n', '\r\n').encode())
	with (d/'sound/SFX/SFX.ini').open('a', newline='\r\n') as f:
		f.write('\n[UVBProbe]\nTitle=Universal voice probe\nFile=UVBProbe.asm\nPriority=70\n')
	env = os.environ.copy()
	if mono:
		env['PATH'] = str(mono.resolve().parent)+os.pathsep+env['PATH']
	with (output/'fixture-build.log').open('w') as log:
		subprocess.run(['texlua', 'build.lua'], cwd=d, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
	return d


def live(a, d):
	g = Genesis(a.core, d/'s2built.bin', d/'md-main.lst', a.output/'live',
		a.pal, system_directory=a.system_directory)
	z = g.zram
	image = (d/'s2built.bin').read_bytes()
	def zr(name, size=1):
		address = g.s[name] if isinstance(name, str) else name
		return int.from_bytes(bytes(z[address:address+size]), 'little')
	def run(frames=1):
		g.run(frames)
		assert not g.read('v_errortype')
	for _ in range(1800):
		run()
		if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
			break
	else:
		raise AssertionError('Title did not start')
	g.write('f_levselcheat', 1);g.buttons={3};run(2);g.buttons=set();run(100)
	g.write('v_levselitem', g.s['LevelSelect_SoundItem'], 2);run(5)
	def play(sound_id):
		g.write('v_levselsound', sound_id, 2);g.buttons={0};run(2);g.buttons=set();run(3)
	assert g.s['MusID_HighGHZ'] == 0x100 and g.s['SndID_Jump'] == 0x200
	assert g.s['CmdID_Distortion'] == 0x17A and g.s['CmdID_Stop'] == 0x180
	# Cursor wrapping and rendered three-digit hexadecimal through real input.
	for initial, button, expected in ((0, 6, 0x180), (0x180, 7, 0), (0xF8, 1, 0x108)):
		g.write('v_levselsound', initial, 2);g.buttons={button};run();g.buttons=set();run()
		assert g.read('v_levselsound', 2) == expected
		at=g.s['vram_fg']+24*128+2+24
		glyphs=[int.from_bytes(bytes(g.vram[(at+i*2+j)^1] for j in range(2)), 'big') & 0x7FF for i in range(3)]
		wanted=[16+n+(4 if n>=10 else 0) for n in ((expected>>8)&15, (expected>>4)&15, expected&15)]
		assert glyphs == wanted, (glyphs, wanted)
	play(0xA100);run(120)
	assert current_music(g, image, z) == 0x100 and zr('zSongFM1') & 128
	play(0x101);run(450)
	assert current_music(g, image, z) == 0x100 and not zr('zAbsVar.1upPlaying')
	play(0xB200);run(2)
	assert zr('zSFX_PSG1') & 128, 'ID $200 was truncated to zero'
	play(g.s['CmdID_SpeedUp']);assert zr('zAbsVar.SpeedUpFlag')
	play(g.s['CmdID_SlowDown']);assert not zr('zAbsVar.SpeedUpFlag')
	play(g.s['CmdID_Distortion']);assert not zr(g.s['zDistortionGate']+1)
	run(60);assert zr(g.s['zDistortionIndex']+1) < 11
	play(g.s['CmdID_Distortion']);assert zr(g.s['zDistortionGate']+1) == 3
	play(g.s['MusID_UVBProbe']);run(20)
	seen=set()
	for _ in range(220):
		run()
		seen.add((zr('zSongFM1.VoiceIndex'), zr('zSongFM1.Volume'), zr('zSongPSG1.Volume')))
	assert {(0, 0, 0), (0, 127, 15), (34, 31, 3)} <= seen, seen
	assert zr('zSongFM1.VoicePtrLow', 2) == 0x8000+(g.s['UniversalVoiceBank'] & 0x7FFF)
	play(g.s['MusID_HCZ1']);run(90)
	assert zr('zSongFM5') & 128
	play(g.s['SndID_UVBProbe']);seen=set()
	for _ in range(40):
		if zr('zSFX_FM5') & 128:
			seen.add(zr('zSFX_FM5.VoiceIndex'))
		run()
	assert seen == {0, 34} and not zr('zSFX_FM5') & 128
	assert not zr('zSongFM5') & 4, 'Special stop left music overridden'
	play(0x100);run(90);play(g.s['SndID_Ring']);play(g.s['CmdID_StopSFX'])
	assert not any(zr(g.s['zTracksSFXStart']+i*g.s['zTrack.len']) & 128 for i in range(6))
	assert zr('zSongFM1') & 128
	play(g.s['CmdID_FadeOut']);run(180)
	assert not zr('zSongFM1') & 128
	play(g.s['CmdID_SegaSound']);run(180)
	play(0x100);run(90);play(g.s['CmdID_Stop'])
	assert not zr('zSongFM1') & 128 and not zr('zMusicSongRequest', 2)
	# Invalid holes and the maximum 12-bit ID leave stopped playback stopped.
	for sound_id in (0, 0x170, 0x179, 0x181, 0xFFF):
		play(sound_id)
		assert not zr('zSongFM1') & 128
	g.close()
	return dict(high_music=0x100, high_jingle=0x101, high_sfx=0x200,
		reserved_flags=True, command_ids=list(range(0x17A, 0x181)),
		uvb_sfx_voices=sorted(seen), special_stop_restored=True)


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--core', type=Path, required=True)
	p.add_argument('--system-directory', type=Path, required=True)
	p.add_argument('--mono', type=Path)
	p.add_argument('--output', type=Path, required=True)
	p.add_argument('--pal', action='store_true')
	a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(parents=True, exist_ok=True)
	report={'native': native(a.core, ROOT/'s2built.bin', ROOT/'md-main.lst')}
	d=fixture(a.output, a.mono)
	report['live']=live(a,d)
	(a.output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
	print(json.dumps(report), flush=True)


if __name__ == '__main__':
	main()
