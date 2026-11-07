#!/usr/bin/env python3
"""Execute the real Z80 Kosinski+ decoder on songs and format-edge fixtures.

Requires a Genesis Plus GX core exporting its Z80 CPU and memory-map symbols.
Only the standalone CPU is run: its bus maps to guarded fixture memory. The
decoder source is extracted from s2.sounddriver.asm and assembled unchanged,
apart from relocation and a test output address that allows 8-KiB matches.
"""
from pathlib import Path
import argparse
import ctypes as C
import json
import os
import platform
import random
import subprocess
from check_ehz_boss import symbols
from check_music_sequences import music
from check_sound_tools import kosinski_plus

ROOT=Path(__file__).resolve().parents[1]


class Pair(C.Union):
	_fields_=[('d',C.c_uint32),('w',C.c_uint16*2),('b',C.c_uint8*4)]


class Registers(C.Structure):
	_fields_=[(name,Pair) for name in ('pc','sp','af','bc','de','hl','ix','iy','wz','af2','bc2','de2','hl2')]+[
		(name,C.c_uint8) for name in ('r','r2','iff1','iff2','halt','im','i','nmi_state','nmi_pending','irq_state','after_ei')]+[
		('cycles',C.c_uint32),('daisy',C.c_void_p),('irq_callback',C.c_void_p)]


class Native:
	def __init__(self,core,program,s):
		self.core=C.CDLL(str(core));self.core.z80_init.argtypes=[C.c_void_p,C.c_void_p]
		self.core.z80_run.argtypes=[C.c_uint];self.core.z80_init(None,None);self.core.z80_reset()
		self.regs=Registers.in_dll(self.core,'Z80');self.ram=(C.c_uint8*65536)()
		for name in ('z80_readmap','z80_writemap'):
			mapping=(C.c_void_p*64).in_dll(self.core,name)
			for i in range(64):mapping[i]=C.addressof(self.ram)+i*1024
		Read=C.CFUNCTYPE(C.c_uint8,C.c_uint);Write=C.CFUNCTYPE(None,C.c_uint,C.c_uint8)
		self.reader=Read(lambda addr:self.ram[addr&65535])
		self.writer=Write(lambda addr,value:self.ram.__setitem__(addr&65535,value))
		C.c_void_p.in_dll(self.core,'z80_readmem').value=C.cast(self.reader,C.c_void_p).value
		C.c_void_p.in_dll(self.core,'z80_writemem').value=C.cast(self.writer,C.c_void_p).value
		self.ram[:len(program)]=program;self.program=program;self.s=s;self.ram[0x8000]=0x76

	def decode(self,packed,raw):
		ram,regs,s=self.ram,self.regs,self.s
		assert len(packed)<0x5F00 and len(raw)<0x3FF0
		ram[0x3FF0:0x8000]=bytes([0xCC])*0x4010
		ram[0xA000:0xA000+len(packed)]=packed;ram[0xFF00:0xFF02]=[0,0x80]
		C.memset(C.addressof(regs),0,C.sizeof(regs))
		regs.pc.d=s['zKosinskiPlusDec'];regs.sp.d=0xFF00;regs.hl.d=0xA000
		regs.ix.d=0xBEEF;regs.iy.d=0xCAFE;regs.af2.d=0xA55A
		while not regs.halt and regs.cycles<200000000:self.core.z80_run(regs.cycles+4096)
		assert regs.halt and regs.pc.d==0x8000,('Decoder failed to return',hex(regs.pc.d))
		assert bytes(ram[0x4000:0x4000+len(raw)])==raw,'Wrong decompressed output'
		assert bytes(ram[0x3FF0:0x4000])==bytes([0xCC])*16,'Underwrote output guard'
		assert bytes(ram[0x4000+len(raw):0x4010+len(raw)])==bytes([0xCC])*16,'Overwrote output guard'
		assert bytes(ram[0xA000:0xA000+len(packed)])==packed,'Modified compressed input'
		assert regs.hl.d==0xA000+len(packed) and regs.de.d==0x4000+len(raw),'Wrong final cursors'
		assert regs.sp.d==0xFF02 and regs.ix.d==0xBEEF and regs.iy.d==0xCAFE,'Clobbered stack or index registers'
		assert regs.af2.d==0xA55A,('Clobbered DPCM accumulator AF′',hex(regs.af2.d))
		actual=bytearray(ram[:len(self.program)]);expected=bytearray(self.program)
		at=s['zKosPlusCopyOffset']+1
		actual[at:at+2]=expected[at:at+2]
		assert actual==expected,'Modified code outside the displacement immediate'
		return regs.cycles


class Stream:
	def __init__(self):self.data=bytearray();self.raw=bytearray();self.used=8;self.descriptor=0
	def bit(self,value):
		if self.used==8:self.descriptor=len(self.data);self.data.append(0);self.used=0
		self.data[self.descriptor]|=value<<(7-self.used);self.used+=1
	def literal(self,value):self.bit(1);self.data.append(value);self.raw.append(value)
	def match(self,distance,count,short=False):
		assert 1<=distance<=len(self.raw)
		self.bit(0);self.bit(0 if short else 1)
		if short:
			assert distance<=256 and 2<=count<=5
			self.data.append((-distance)&255);self.bit((count-2)>>1);self.bit((count-2)&1)
		else:
			assert distance<=8192 and 3<=count<=264
			offset=(-distance)&8191;self.data.extend(((offset>>8)<<3|(10-count if count<=9 else 0),offset&255))
			if count>=10:self.data.append(count-9)
		for _ in range(count):self.raw.append(self.raw[-distance])
	def finish(self):self.bit(0);self.bit(1);self.data.extend((0,0,0));return bytes(self.data),bytes(self.raw)


def main():
	p=argparse.ArgumentParser(description=__doc__)
	p.add_argument('--core',type=Path,required=True)
	p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
	p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
	p.add_argument('--ini',type=Path,default=ROOT/'sound/music/music.ini')
	p.add_argument('--tools-dir',type=Path)
	p.add_argument('--driver-source',type=Path,default=ROOT/'s2.sounddriver.asm')
	p.add_argument('--output',type=Path,required=True)
	a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
	tools=a.tools_dir or ROOT/'build_tools'/('Windows-x86' if os.name=='nt' else platform.system()+'-'+{'amd64':'x86_64','arm64':'aarch64'}.get(platform.machine(),platform.machine()))
	asl=tools/('asw.exe' if os.name=='nt' else 'asl');p2bin=tools/('p2bin.exe' if os.name=='nt' else 'p2bin')
	env=os.environ.copy();env.update(AS_MSGPATH=str(tools),USEANSI='n')
	def run(args):
		r=subprocess.run([str(x) for x in args],cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
		assert r.returncode==0,r.stdout
	def assemble(name,body):
		(out/(name+'.asm')).write_bytes(body.replace('\n','\r\n').encode())
		run([asl,'-xx','-n','-q','-A','-L','-U','-E','-i','.', '-o',out/(name+'.p'),out/(name+'.asm')])
	source=a.driver_source.read_text()
	if 'zKosinskiPlusDec:' not in source:
		p.error('Supply --driver-source from a checkout with the Z80 Kosinski+ decoder.')
	code='zKosinskiPlusDec:'+source.split('zKosinskiPlusDec:',1)[1].split('zKosinskiPlusDec_End:',1)[0]+'zKosinskiPlusDec_End:\n'
	assemble('decoder','\tcpu Z80\n\torg 100h\nzMusicData = 4000h\n'+code)
	run([p2bin,out/'decoder.p',out/'decoder.bin'])
	s=symbols(out/'decoder.lst');program=(out/'decoder.bin').read_bytes();native=Native(a.core,program,s)
	report=[]
	def check(name,packed,raw):
		assert kosinski_plus(packed)==raw,(name,'Independent decoder mismatch')
		try:clocks=native.decode(packed,raw)
		except AssertionError as error:raise AssertionError((name,*error.args)) from error
		report.append({'case':name,'raw':len(raw),'packed':len(packed),'master_clocks_upper_bound':clocks})
	for count in range(33):
		stream=Stream()
		for i in range(count):stream.literal((i*71)&255)
		check('literal-'+str(count),*stream.finish())
	for phase in range(8):
		for short,lengths,distances in ((True,range(2,6),(1,256)),(False,(3,4,5,6,7,8,9,10,255,256,264),(1,257,4096,8192))):
			for distance in distances:
				for count in lengths:
					stream=Stream()
					for i in range(distance+phase):stream.literal((i*37)&255)
					stream.match(distance,count,short)
					check(f'{"short" if short else "long"}-{distance}-{count}-phase{phase}',*stream.finish())
	def compress(raw):
		(out/'input.bin').write_bytes(raw)
		assemble('input','\tcpu Z80\n\torg 0\n\tbinclude "'+(out/'input.bin').as_posix()+'"\n')
		run([p2bin,'-z=0,kosinskiplus,CompressedSize,after',out/'input.p',out/'packed.bin',out/'packed.h'])
		return (out/'packed.bin').read_bytes()
	songs=music(a.rom,a.listing,a.ini)
	for name,(raw,_,_) in songs.items():check('song-'+name,compress(raw),raw)
	rng=random.Random(0x4B4F532B)
	for length in (1,2,7,8,9,31,256,0xA40,0xA41,8192):
		for raw in (bytes(length),rng.randbytes(length)):
			check('encoder-'+str(length)+'-'+str(raw[:1]),compress(raw),raw)
	result={'decoder_bytes':s['zKosinskiPlusDec_End']-s['zKosinskiPlusDec'],'songs':len(songs),'cases':len(report),'checks':report}
	(out/'report.json').write_text(json.dumps(result,indent=2)+'\n')
	print(f"Z80 Kosinski+: {result['decoder_bytes']} bytes; {len(report)} guarded native executions, including {len(songs)} songs.")


if __name__=='__main__':main()
