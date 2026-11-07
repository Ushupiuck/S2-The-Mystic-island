#!/usr/bin/env python3
"""Compare complete KeH music streams before and after source optimization.

Calls, relative jumps and counted loops are interpreted independently of the
source macros. All musical commands, explicit/implicit durations, headers and
instrument bytes must match. Infinite tracks are compared beyond both loop
boundaries; finite tracks must stop at the same event.
"""
from pathlib import Path
import argparse
import configparser
import itertools
import json
import math
from check_ehz_boss import symbols
from check_sound_tools import saxman,kosinski_plus

ROOT=Path(__file__).resolve().parents[1]
LENGTHS=(2,2,2,1,1,2,2,1,2,2,2,2,2,1,1,2,5,1,1,2,1,2,3,5,3,1,2)


def music(rom,listing,ini):
	s=symbols(listing);data=rom.read_bytes()
	config=configparser.ConfigParser(interpolation=None);config.read(ini)
	result={}
	for index,name in enumerate(config.sections()):
		row=config[name];start=s['Mus_'+name];size=row.getint('Size')
		if 'Music_Index' in s:
			entry=s['Music_Index']+index*8
			assert int.from_bytes(data[entry:entry+4],'big')==start
			assert int.from_bytes(data[entry+4:entry+6],'big')==row.getint('UncompressedSize')
			flags=data[entry+6]
		else:
			flags=data[s['zMasterPlaylist']+index*4+3]
		raw=data[start:start+size]
		if not flags&0x10:raw=(kosinski_plus if 'zKosinskiPlusDec' in s or 'Music_Index' in s else saxman)(raw)
		assert len(raw)==row.getint('UncompressedSize'),(name,'Raw song size')
		result[name]=(raw,size,flags&~0x10)
	return result


def current_music(g, rom, zram):
	if 'Music_Index' in g.s:
		slot = zram[g.s['zAbsVar.MusicSlot']]
		return g.read(g.s['Music_StageSongs'] + slot - 1) if slot else 0
	bank = zram[g.s['zBGMLoad_BankLoadInstruction'] + 1]
	address = g.s['zBGMLoad_AddressLoadInstruction'] + 1
	entry = bytes((bank, zram[address], zram[address+1]))
	first = g.s['MusID__First']
	for song_id in range(first, g.s['MusID__End']):
		offset = g.s['zMasterPlaylist'] + (song_id - first) * 4
		if rom[offset:offset+3] == entry:
			return song_id
	return 0


def word(data,at):
	assert 0<=at<len(data)-1,('Pointer outside song',at,len(data))
	return int.from_bytes(data[at:at+2],'little',signed=True)


def header(data):
	voice=int.from_bytes(data[:2],'little');fm,psg=data[2:4]
	assert fm<=7 and psg<=3,(fm,psg)
	tracks=[];at=6
	for name,stride in [(('DAC' if i==0 else 'FM'+str(i)),4) for i in range(fm)]+[('PSG'+str(i+1),6) for i in range(psg)]:
		tracks.append((name,at+2+word(data,at),data[at+2:at+stride]))
		at+=stride
	assert voice==0 or at<=voice<=len(data),('Invalid instrument pointer',voice)
	return data[2:6],tracks,data[voice:] if voice else b''


def trace(data,start):
	pc=start;stack=[];loops=[0]*10;events=[];seen={};controls=0;depth=0;indices=set()
	for _ in range(1000000):
		state=(pc,tuple(stack),tuple(loops))
		if state in seen:
			prefix=seen[state];assert len(events)>prefix,'Control-only infinite loop'
			return {'events':events,'prefix':prefix,'period':len(events)-prefix,'controls':controls,'depth':depth,'indices':sorted(indices)}
		seen[state]=len(events)
		assert 0<=pc<len(data),('Track ran outside song',pc,len(data))
		op=data[pc];pc+=1
		if op<0xE0:
			if op>=0x80:
				duration=data[pc] if pc<len(data) and data[pc]<0x80 else None
				if duration is not None:pc+=1
				events.append(('note',op,duration))
			else:events.append(('duration',op))
			continue
		assert op<=0xFA,('Unsupported KeH command',hex(op),pc-1)
		size=LENGTHS[op-0xE0];end=pc+size-1
		assert end<=len(data),('Truncated command',op,pc)
		if op==0xF6:
			pc=pc+1+word(data,pc);controls+=1
		elif op==0xF7:
			index,count=data[pc:pc+2]
			assert index<10-2*len(stack),('Loop counter overlaps call stack',index,len(stack))
			indices.add(index)
			loops[index]=((loops[index] or count)-1)&255
			pc=pc+3+word(data,pc+2) if loops[index] else end
			controls+=1
		elif op==0xF8:
			stack.append(end);depth=max(depth,len(stack))
			assert len(stack)<=5 and not any(loops[10-2*len(stack):]),'Call stack overwrites loop counters'
			pc=pc+2+word(data,pc);controls+=1
		elif op==0xE3:
			assert stack,'Return without a call'
			pc=stack.pop();controls+=1
		else:
			events.append(('command',bytes(data[pc-1:end]).hex()));pc=end
			if op in (0xE4,0xEE,0xF2):
				return {'events':events,'prefix':len(events),'period':0,'controls':controls,'depth':depth,'indices':sorted(indices)}
	raise AssertionError('Track did not terminate or repeat within one million instructions')


def expanded(result):
	yield from result['events'][:result['prefix']]
	if result['period']:yield from itertools.cycle(result['events'][result['prefix']:])


def musical_events(result,divider):
	# An omitted duration inherits the last computed duration, including the
	# divider in force when it was set. A bare duration remains a new event.
	duration=0
	for event in expanded(result):
		if event[0]=='command':
			cmd=bytes.fromhex(event[1])
			if cmd[0]==0xE5:divider=cmd[1]
			yield event
		elif event[0]=='note':
			if event[2] is not None:duration=(event[2]*divider)&255
			yield ('note',event[1],duration)
		elif event[0]=='duration':
			duration=(event[1]*divider)&255
			yield ('duration',duration)
		else:yield event


def compare(before,after):
	bh,bt,bv=header(before);ah,at,av=header(after)
	assert bh==ah and bv[:25]==av[:25],'Header or initial instrument changed'
	assert [(n,p) for n,_,p in bt]==[(n,p) for n,_,p in at],'Channel header changed'
	report=[]
	for (name,bp,_),(_,ap,_) in zip(bt,at):
		b,a=trace(before,bp),trace(after,ap)
		# Voice numbers may be compacted; compare the actual selected YM patch.
		for result,voices in ((b,bv),(a,av)):
			for i,event in enumerate(result['events']):
				if event[0]=='command' and event[1].startswith('ef'):
					index=int(event[1][2:4],16);voice=voices[index*25:(index+1)*25]
					assert len(voice)==25,('Instrument outside bank',name,index)
					result['events'][i]=('voice',voice.hex())
		assert bool(b['period'])==bool(a['period']),(name,'Track termination changed')
		# Past both introductions, p+q events cover the common periodic tail.
		# This also covers differently factored repetitions of the same phrase.
		count=max(b['prefix'],a['prefix'])+b['period']+a['period']
		left,right=musical_events(b,before[4]),musical_events(a,after[4])
		for index in range(count):
			x,y=next(left,None),next(right,None)
			assert x==y,(name,'Musical event changed',index,x,y)
		if not b['period']:assert next(left,None)==next(right,None)==None
		report.append({'channel':name,'compared_events':count,'loop_events':b['period'],'call_depth':a['depth'],'loop_indices':a['indices'],'control_commands_before':b['controls'],'control_commands_after':a['controls']})
	return report


def playback_frames(data):
	"""Conservative NTSC/PAL budget for introductions and two channel loops."""
	times=[]
	for _,pc,_ in header(data)[1]:
		result=trace(data,pc);events=result['events']
		if result['period']:events=events[:result['prefix']]+events[result['prefix']:]*2
		divider=data[4];duration=256;ticks=0;tempo=data[5] or 1
		for event in events:
			if event[0]=='command':
				cmd=bytes.fromhex(event[1])
				if cmd[0]==0xE5:divider=cmd[1]
				if cmd[0]==0xEA:tempo=min(tempo,cmd[1] or 1)
				continue
			value=event[2] if event[0]=='note' else event[1]
			if value is not None:duration=((value*divider)&255) or 256
			ticks+=duration
		times.append(math.ceil(ticks*256/tempo))
	return max(times)+120


def playback(a,before,after):
	"""Compare real Z80 musical state each frame, normalizing relocated pointers."""
	import ctypes as C
	import hashlib
	import numpy as np
	import zlib
	from genesis_test_core import Genesis
	selected=[name for name in before if (not a.songs or name in a.songs) and (a.include_unchanged or before[name][0]!=after[name][0])]
	assert selected,'No songs selected for runtime comparison; use --include-unchanged for codec/driver changes'
	out=a.output.parent/('playback-pal' if a.pal else 'playback-ntsc');out.mkdir(parents=True,exist_ok=True)
	fields=('PlaybackControl','VoiceControl','TempoDivider','Transpose','Volume','AMSFMSPan','VolFlutter',
		'DurationTimeout','SavedDuration','FreqLow','FreqHigh','NoteFillTimeout','NoteFillMaster',
		'ModulationWait','ModulationSpeed','ModulationDelta','ModulationSteps','ModulationValLow',
		'ModulationValHigh','Detune','VolTLMask','PSGNoise')
	track_names=['zSongDAC']+['zSongFM'+str(i) for i in range(1,7)]+['zSongPSG'+str(i) for i in range(1,4)]
	reports=[]
	for reference in (True,False):
		g=Genesis(a.core,a.reference_rom if reference else a.rom,a.reference_listing if reference else a.listing,
			out,a.pal,system_directory=a.system_directory)
		# Pixel conversion is unnecessary for audio/state validation.
		Video=C.CFUNCTYPE(None,C.c_void_p,C.c_uint,C.c_uint,C.c_size_t)
		video=Video(lambda *args:None);g.core.retro_set_video_refresh(video)
		energy=0;nonzero=0;samples=0
		def audio(data,frames):
			nonlocal energy,nonzero,samples
			values=np.frombuffer(C.string_at(data,frames*4),dtype='<i2').astype(np.int64)
			energy+=int(values@values);nonzero+=int(np.count_nonzero(values));samples+=len(values)
			return frames
		Batch=C.CFUNCTYPE(C.c_size_t,C.c_void_p,C.c_size_t)
		audio_callback=Batch(audio);g.core.retro_set_audio_sample_batch(audio_callback)
		for _ in range(1800):
			g.run()
			if g.read('v_vbla_routine',2)==g.s['Vint_Title'] and g.read('v_generictimer',2)==375:break
		else:raise AssertionError('Title did not start')
		g.write('f_levselcheat',1);g.buttons={3};g.run(2);g.buttons=set();g.run(100)
		g.write('v_levselitem',g.s['LevelSelect_SoundItem'],2);g.run(5);menu=g.save()
		zram=(C.c_uint8*8192).in_dll(g.core,'zram')
		tracks=[g.s[name] for name in track_names];offsets=[g.s['zTrack.'+name] for name in fields]
		globals=[g.s['zAbsVar.'+name] for name in ('TempoTimeout','CurrentTempo','StopMusic')]
		for name in selected:
			g.restore(menu);g.write('v_levselsound',list(before).index(name)+1,2);g.run(2)
			g.buttons={0};g.run(2);g.buttons=set();g.run(1)
			raw=(before if reference else after)[name][0];voices=header(raw)[2]
			patches=[hashlib.sha256(voices[i:i+25]).digest()[:4] for i in range(0,len(voices),25)]
			frames=playback_frames(before[name][0]);frames=a.frames or frames
			states=bytearray();energy=nonzero=samples=0
			for frame in range(frames+8):
				g.run();record=bytearray(zram[p] for p in globals)
				for index,track in enumerate(tracks):
					record.extend(zram[track+offset] for offset in offsets)
					voice=zram[track+g.s['zTrack.VoiceIndex']]
					if 1<=index<=6 and before[name][0]!=after[name][0]:
						assert voice<len(patches),(name,'Bad runtime instrument index',voice)
						record.extend(patches[voice])
					else:record.extend((voice,0,0,0))
				states.extend(record)
				assert not g.read('v_errortype'),(name,'CPU exception',frame)
			assert nonzero>1000 and samples>0,(name,'Silent playback')
			width=len(record);path=out/(name+'.state.zlib')
			if reference:path.write_bytes(zlib.compress(states))
			else:
				original=zlib.decompress(path.read_bytes());assert len(original)==len(states)
				# Loading into RAM can change startup latency; musical frames must
				# subsequently match exactly, including the tempo accumulator.
				alignment=None
				for left in range(9):
					for right in range(9):
						if original[left*width:(left+64)*width]==states[right*width:(right+64)*width]:
							alignment=(left,right);break
					if alignment is not None:break
				assert alignment is not None,(name,'Initial musical state differs')
				left,right=alignment;x=original[left*width:(left+frames)*width];y=states[right*width:(right+frames)*width]
				if x!=y:
					index=next(i for i,(u,v) in enumerate(zip(x,y)) if u!=v)
					raise AssertionError((name,'Runtime musical state differs',index//width,'record byte',index%width,x[index],y[index]))
				reports.append({'song':name,'frames':frames,'startup_alignment':alignment,'musical_state_sha256':hashlib.sha256(x).hexdigest(),'rms':math.sqrt(energy/samples),'nonzero_samples':nonzero})
			print(('Reference' if reference else 'Optimized')+f' {name}: {frames} real playback frames.',flush=True)
		g.close()
	(out/'report.json').write_text(json.dumps(reports,indent=2)+'\n')
	return reports


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
	p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--ini',type=Path,default=ROOT/'sound/music/music.ini')
	p.add_argument('--reference-rom',type=Path,required=True)
	p.add_argument('--reference-listing',type=Path,required=True)
	p.add_argument('--reference-ini',type=Path,required=True)
	p.add_argument('--output',type=Path,required=True)
	p.add_argument('--core',type=Path)
	p.add_argument('--system-directory',type=Path)
	p.add_argument('--pal',action='store_true')
	p.add_argument('--songs',nargs='*')
	p.add_argument('--include-unchanged',action='store_true',help='Compare unchanged decoded songs for driver/codec changes.')
	p.add_argument('--frames',type=int,help='Override the two-loop runtime budget for a short diagnostic.')
	a=p.parse_args()
	before=music(a.reference_rom,a.reference_listing,a.reference_ini)
	after=music(a.rom,a.listing,a.ini)
	assert list(before)==list(after),'Song order/IDs changed'
	report=[]
	for name,(raw,size,flags) in after.items():
		original,old_size,old_flags=before[name]
		assert flags==old_flags,(name,'Playlist behavior flags changed')
		try:channels=compare(original,raw)
		except AssertionError as error:raise AssertionError((name,*error.args)) from error
		row={'song':name,'sequence_before':len(original),'sequence_after':len(raw),'stored_before':old_size,'stored_after':size,'channels':channels}
		report.append(row)
		print(f'{name}: {len(original)} -> {len(raw)} sequence bytes, {old_size} -> {size} stored; {len(channels)} complete channel streams match.',flush=True)
	a.output.parent.mkdir(parents=True,exist_ok=True)
	a.output.write_text(json.dumps(report,indent=2)+'\n')
	if a.core:playback(a,before,after)


if __name__=='__main__':
	main()
