#!/usr/bin/env python3
"""Check the complete Debug unlock and live pause, step and exit controls."""
from pathlib import Path
import argparse
import json

from native_test_core import Native, UC_M68K_REG_D0, UC_M68K_REG_PC

ROOT = Path(__file__).resolve().parents[1]


def native(rom, listing):
	m = Native(rom, listing)
	sounds = []
	original_hook = m.hook

	def hook(cpu, address, size, unused):
		if address == m.s['PlaySound_Special']:
			sounds.append(cpu.reg_read(UC_M68K_REG_D0) & 255)
		original_hook(cpu, address, size, unused)

	m.hook = hook
	cases = ((1, 3, 5, 7), (1, 1, 3, 5, 7), (1, 3, 1, 3, 5, 7),
				(1, 3, 5, 6), (1, 3, 7, 5), (1, 3, 0, 5, 7), (0x11, 3, 5, 7))
	for sequence in cases:
		m.start()
		sounds.clear()
		m.write('f_levselcheat', 1)
		m.write('f_slomocheat', 0x3C)
		m.write('Debug_mode_flag', 0x5A)
		for sound in sequence:
			m.write('v_levselsound', sound, 2)
			m.act('LevelSelect_PlaySound')
		unlocked = sequence[-4:] == (1, 3, 5, 7)
		assert bool(m.read('f_debugcheat')) == unlocked, sequence
		assert sounds == list(sequence) + ([m.s['sfx_Ring']] if unlocked else []), (sequence, sounds)
		assert m.read('f_levselcheat') == 1
		assert m.read('f_slomocheat') == (1 if unlocked else 0x3C)
		assert m.read('Debug_mode_flag') == 0x5A
	# Repeating the complete code confirms again; mistakes cannot revoke it.
	m.start()
	sounds.clear()
	for sound in (1, 3, 5, 7, 9, 1, 3, 5, 7):
		m.write('v_levselsound', sound, 2)
		m.act('LevelSelect_PlaySound')
	assert m.read('f_debugcheat') and m.read('f_slomocheat') and sounds.count(m.s['sfx_Ring']) == 2

	# Every old title C-count variant, in both regional code paths, leaves
	# Debug locked while retaining level-select and slow-motion unlocks.
	for region in (0, 0x80):
		for count in range(8):
			m.start()
			m.write('v_megadrive', region)
			m.write('v_title_ccount', count, 2)
			m.cpu.emu_start(m.s['Title_Cheat_Unlock'], m.s['Title_Cheat_CountC'], count=1000)
			assert m.cpu.reg_read(UC_M68K_REG_PC) == m.s['Title_Cheat_CountC']
			code = count // 2
			assert not m.read('f_debugcheat'), (region, count)
			assert bool(m.read('f_levselcheat')) == (code == 0)
			assert bool(m.read('f_slomocheat')) == (code == 1 or region == 0x80 and code != 0)
	return dict(sound_sequences=len(cases), exact_ring_requests=True,
		repeated_confirmation=True, deprecated_title_variants=16,
		pause_controls=native_pause(rom,listing))


def native_pause(rom,listing):
	m=Native(rom,listing)
	for label in ('WaitForVint','PauseSoundDriver','UnpauseSoundDriver'):
		m.cpu.mem_write(m.s[label],bytes.fromhex('4E75'))
	inputs=[]
	events=[]
	original=m.hook

	def hook(cpu,address,size,unused):
		if address==m.s['WaitForVint']:
			assert inputs,'Pause loop consumed all fixture input'
			held,pressed=inputs.pop(0)
			m.write('v_jpadhold1',held);m.write('v_jpadpress1',pressed)
		elif address==m.s['PauseSoundDriver']:
			events.append('pause')
		elif address==m.s['UnpauseSoundDriver']:
			events.append('resume')
		original(cpu,address,size,unused)

	m.hook=hook
	A,B,C,START=(m.s[name] for name in ('btnA','btnB','btnC','btnStart'))

	def reset(enabled=1):
		m.start();inputs.clear();events.clear()
		m.write('v_lives',3);m.write('f_pause',1,2)
		m.write('f_slomocheat',enabled)

	checks=[]
	reset(0)
	inputs.extend(((A,A),(B,B),(C,C),(START,START)))
	m.act('PauseGame')
	assert not inputs and not m.read('f_pause',2) and m.read('v_gamemode',2)==m.s['Level']
	checks.append('locked controls ignore A/B/C and retain ordinary Start resume')
	reset();inputs.extend(((B,B),(B,0),(0,0),(START,START)))
	for _ in range(2):
		m.act('PauseGame');assert m.read('f_pause',2)==1
	m.act('PauseGame')
	assert not inputs and not m.read('f_pause',2) and events==['pause','resume']*3
	checks.append('held B returns successive game steps and release stays paused')
	reset();inputs.extend(((C,C),(C,0),(C,0),(START,START)))
	m.act('PauseGame');assert m.read('f_pause',2)==1
	m.act('PauseGame');assert not inputs and not m.read('f_pause',2)
	checks.append('C advances on a press, not while held')
	reset();inputs.append((A,A));m.act('PauseGame')
	assert m.read('v_gamemode',2)==m.s['TitleScreen'] and not m.read('f_pause',2)
	checks.append('paused A exits to title and resumes the sound driver')
	reset();m.write('f_pause',0,2)
	m.write('v_jpadhold1',A|START);m.write('v_jpadpress1',A|START)
	m.act('PauseGame')
	assert m.read('v_gamemode',2)==m.s['TitleScreen'] and not m.read('f_pause',2)
	assert not inputs and events==['pause','resume']
	checks.append('simultaneous A+Start exits without losing the A edge')
	reset();m.write('v_lives',0);m.act('PauseGame')
	assert not m.read('f_pause',2) and not events
	checks.append('zero lives retain the ordinary no-pause path')
	return checks


def runtime(a):
	from genesis_test_core import Genesis
	g = Genesis(a.core, a.rom, a.listing, a.output / 'runtime', a.pal,
				system_directory=a.system_directory)
	UP, DOWN, LEFT, RIGHT, A, B, C, START = 4, 5, 6, 7, 1, 0, 8, 3

	def step(count=1):
		g.run(count)
		assert not g.read('v_errortype'), ('CPU exception', g.frame)

	def press(button):
		g.buttons = {button}
		step(2)
		g.buttons = set()
		step(2)

	def pause_controls(label,metric='Timer_frames',increment=1):
		press(START);step(6)
		assert g.read('f_pause',2)==1,(label,'Start did not pause')
		before=g.read(metric,2);step(8)
		assert g.read(metric,2)==before,(label,'Paused game advanced')
		g.buttons={C};step(10)
		c_steps=(g.read(metric,2)-before)&65535
		assert c_steps==increment,(label,'C did not advance exactly once',c_steps,increment)
		g.buttons=set();step(6)
		before=g.read(metric,2);g.buttons={B};step(12)
		b_steps=(g.read(metric,2)-before)&65535
		assert increment<b_steps<12*increment,(label,'B slow motion failed',b_steps,increment)
		g.buttons=set();step(6)
		before=g.read(metric,2);step(8)
		assert g.read(metric,2)==before and g.read('f_pause',2)==1,(label,'B release did not stay paused')
		g.video.save(a.output/'runtime'/(label+'-paused.png'))
		press(START);step(8)
		assert not g.read('f_pause',2) and g.read(metric,2)!=before,(label,'Start did not resume')
		return dict(case=label,c_advances=c_steps//increment,b_advances=b_steps//increment,
			pause_freezes=True,b_release_pauses=True,start_resumes=True)

	def title_ready():
		g.buttons=set()
		for _ in range(600):
			step()
			if g.read('v_vbla_routine',2)==g.s['Vint_Title'] and g.read('v_generictimer',2)==375:
				break
		else:
			raise AssertionError('Debug exit did not reach title')
		assert not g.read('f_pause',2) and not g.read('Debug_mode_flag')
		assert all(g.read(flag) for flag in ('f_levselcheat','f_slomocheat','f_debugcheat'))

	for _ in range(1800):
		step()
		if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
			break
	else:
		raise AssertionError('Title not ready')
	for button in (UP, DOWN, DOWN, DOWN, DOWN, UP):
		press(button)
	assert g.read('f_levselcheat') and not g.read('f_debugcheat')
	press(START)
	step(110)
	menu = g.save()

	def select(sound):
		for _ in range(256):
			current = g.read('v_levselsound', 2)
			if current == sound:
				return
			press(RIGHT if (sound-current) & 255 < 128 else LEFT)
		raise AssertionError(('Could not select sound', sound))

	for playback in (B, C, START):
		g.restore(menu)
		press(UP)
		for i, sound in enumerate((1, 3, 5, 7)):
			select(sound)
			step(8)
			assert not g.read('f_debugcheat')
			assert g.read('v_debugcheat_count') == i
			press(playback)
		assert g.read('f_debugcheat') and g.read('f_levselcheat') and g.read('f_slomocheat')
		assert not g.read('v_debugcheat_count')
	# Holding playback is one request; changing page keeps the partial code.
	g.restore(menu)
	press(UP)
	select(1)
	g.buttons = {B}
	step(30)
	assert g.read('v_debugcheat_count') == 1 and not g.read('f_debugcheat')
	g.buttons = set()
	step(2)
	press(UP)
	press(UP)
	press(START)
	press(DOWN)
	press(DOWN)
	assert g.read('v_levselitem', 2) == 0x100 + g.s['LevelSelect_SoundItem']
	for sound in (3, 5, 7):
		select(sound)
		press(B)
	assert g.read('f_debugcheat')

	players = []
	pause_cases=[]
	for player in (0, 2):
		g.restore(menu)
		for _ in range(player):
			press(C)
		assert g.read('Player_mode', 2) == player
		press(UP)
		for sound in (1, 3, 5, 7):
			select(sound)
			press(B)
		press(DOWN)
		g.buttons = {A, START}
		for _ in range(800):
			step()
			if g.read('v_gamemode', 2) == g.s['Level'] and g.read('f_timecount'):
				break
		else:
			raise AssertionError(('Level entry failed', player))
		g.buttons = set()
		step(3)
		assert g.read('f_levselcheat') and g.read('f_debugcheat') and g.read('Debug_mode_flag')
		press(B)
		assert g.read('Debug_placement_mode', 2), player
		press(B)
		assert not g.read('Debug_placement_mode', 2), player
		level=g.save()
		pause_cases.append(pause_controls(f'level-player-{player}'))
		g.restore(level);g.buttons=set();step(3)
		press(START);step(6);assert g.read('f_pause',2)==1
		press(A)
		title_ready()
		press(START);step(110)
		assert not g.get('v_titlesonic','code') and all(g.read(flag) for flag in ('f_slomocheat','f_debugcheat'))
		pause_cases.append(dict(case=f'paused-A-player-{player}',title_and_menu_return=True,unlock_persists=True))
		g.restore(level);g.buttons={A,START};step(8)
		title_ready()
		pause_cases.append(dict(case=f'A-Start-player-{player}',title_return=True,unlock_persists=True))
		players.append(player)
	# The rotating S1 stage keeps its existing fade/results exit. Its pause
	# controls must still unlock with the same code, without requiring A entry.
	press(START);step(110);press(UP);press(UP)
	assert (g.read('v_levselitem',2)&255)==g.s['LevelSelect_BonusItem']
	g.buttons={START}
	for _ in range(1000):
		step()
		if (g.read('v_gamemode',2)==g.s['BonusStage'] and
			g.read('v_vbla_routine',2)==g.s['Vint_S1SS'] and g.get('v_player','obRoutine')==2):
			break
	else:
		raise AssertionError('Special stage entry failed')
	g.buttons=set();step(8)
	assert not g.read('Debug_mode_flag') and g.read('f_slomocheat')
	pause_cases.append(pause_controls('rotating-stage','v_ssangle',g.read('v_ssrotate',2)))
	press(START);step(6);assert g.read('f_pause',2)==1
	press(A)
	for _ in range(1000):
		step()
		if g.get('v_endcard','code')==g.s['BonusGotThrough'] and g.get('v_endcard','obRoutine'):
			break
	else:
		raise AssertionError('Rotating-stage pause exit lost its normal results path')
	pause_cases.append(dict(case='rotating-stage-A',normal_results_exit=True))
	g.video.save(a.output / 'runtime' / 'debug-return.png')
	g.close()
	return dict(controller_playback_buttons=3, held_button_single_request=True,
		cross_page_sequence=True, direct_debug_level_entry=players,pause_controls=pause_cases)


def main():
	p = argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
	p.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
	p.add_argument('--core', type=Path)
	p.add_argument('--system-directory', type=Path)
	p.add_argument('--pal', action='store_true')
	p.add_argument('--output', type=Path, required=True)
	a = p.parse_args()
	a.output.mkdir(parents=True, exist_ok=True)
	report = dict(native=native(a.rom, a.listing))
	if a.core:
		report['runtime'] = runtime(a)
	(a.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
	print(json.dumps(report), flush=True)


if __name__ == '__main__':
	main()
