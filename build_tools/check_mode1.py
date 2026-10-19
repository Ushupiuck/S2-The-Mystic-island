#!/usr/bin/env python3
"""Check real Mode 1 startup, handshakes, RAM ownership and DMA in Genesis Plus GX.

The all-zero identification fixture enables the CD hardware model; it contains
no Sega BIOS code. CPU probes run assembled instructions in MD RAM, with IRQs
masked. Production routines are called in the ROM, not reimplemented in Python.
"""
from pathlib import Path
import argparse
import ctypes as C
import json
import platform
import re
import subprocess
from genesis_test_core import Genesis

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
for name in ('core', 'rom', 'listing', 'output'):
	p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--pal', action='store_true')
p.add_argument('--assembler', type=Path)
p.add_argument('--p2bin', type=Path)
a = p.parse_args()
a.output = a.output.resolve()
win = platform.system() == 'Windows'
tools = ROOT / 'build_tools' / ('Windows-x86' if win else 'Linux-' + platform.machine())
assembler = a.assembler or tools / ('asw.exe' if win else 'asl')
p2bin = a.p2bin or tools / ('p2bin.exe' if win else 'p2bin')
bios = a.output / 'identification-fixture'
bios.mkdir(parents=True, exist_ok=True)
data = bytearray(0x20000); data[0x100:0x104] = b'SEGA'
for region in 'UEJ':
	(bios / f'bios_CD_{region}.bin').write_bytes(data)
g = Genesis(a.core, a.rom, a.listing, a.output, a.pal, system_directory=bios)
g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
g.core.s68k_get_reg.argtypes = [C.c_int]
g.core.s68k_get_reg.restype = C.c_uint
checks = []


def passed(name):
	checks.append(name)
	print(name + ': passed', flush=True)


def title():
	for _ in range(1600):
		g.run()
		assert not g.read('v_errortype')
		if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
			return
	raise AssertionError('Title timeout')


title()
assert C.c_uint8.in_dll(g.core, 'system_hw').value == 0x84
assert g.read('MCD_status') == 1
assert g.s['MCD_SubEntry'] <= g.core.s68k_get_reg(16) < g.s['MCD_SubProgramEnd'] - g.s['MCD_SubProgram']
g.video.save(a.output / 'mode1-title.png')
base = g.save()
passed('Upload verification, fresh sub-CPU reply and title')
names = ('MegaCDMode1', 'vdp_control_port', 'VDP_control_port', 'vdp_data_port', 'v_dma_thunk',
	'VDP_Command_Buffer', 'VDP_Command_Buffer_Slot', 'MCD_dma_pending', 'InitDMAQueue',
	'ProcessDMAQueue', 'QueueDMATransfer', 'MCD_Init', 'MCD_Command', 'MCD_AcquireWordRAM', 'MCD_ReleaseWordRAM')
prefix = '\tCPU 68000\n\tinclude "s2.macrosetup.asm"\n\tinclude "s2.macros.asm"\n'
for k in names:
	v = g.s[k] & 0xFFFFFFFF
	prefix += f'{k} equ {v - 0x100000000 if v >= 0x80000000 else v}\n'
prefix += (ROOT / '_inc/DMA Queue.asm').read_text().split('; sub_144E:')[0]


def probe(body, restore=True, safe=True):
	if restore:
		g.restore(base)
	source = prefix if safe else prefix.replace('MegaCDMode1 equ 1', 'MegaCDMode1 equ 0')
	source += '\n\tphase $FF0000\n\tmove.w #$2700,sr\n\tmove.w #$8114,($C00004).l\n\tmove.w #$8F02,($C00004).l\n'
	source += body + '\nTestDone:\n\tbra.s *\n\tEND\n'
	asm = a.output / 'probe.asm'; asm.write_text(source)
	for cmd in ([str(assembler), '-xx', '-n', '-q', '-A', '-L', '-U', '-i', str(ROOT), str(asm)],
		[str(p2bin), '-p=FF', str(asm.with_suffix('.p')), str(asm.with_suffix('.bin'))]):
		r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
		assert r.returncode == 0, r.stdout + r.stderr
	done = int(re.search(r'TestDone\s*:\s*([0-9A-F]+)\s+C', asm.with_suffix('.lst').read_text()).group(1), 16)
	code = asm.with_suffix('.bin').read_bytes()
	assert len(code) < 0x7000
	for i, v in enumerate(code):
		g.ram[i ^ 1] = v
	for reg, value in ((17, 0x2700), (15, 0xFFE400), (16, 0xFF0000)):
		g.core.m68k_set_reg(reg, value)
	for _ in range(100):
		g.run()
		if g.core.m68k_get_reg(16) == done:
			return g.core.m68k_get_reg(0) & 65535, g.core.m68k_get_reg(17) & 1
	raise AssertionError(('Probe stalled', hex(g.core.m68k_get_reg(16))))


def fill(source, words):
	return f'\tlea (${source:X}).l,a0\n\tmove.w #$1234,d0\n\tmove.w #${words-1:X},d7\n.fill:\n\tmove.w d0,(a0)+\n\taddi.w #$1F3D,d0\n\tdbf d7,.fill\n'


def pattern(words):
	return b''.join(((0x1234 + i * 0x1F3D) & 65535).to_bytes(2, 'big') for i in range(words))


def queue(source, dest, words):
	return f'\tmove.l #${source:X},d1\n\tmove.w #${dest:X},d2\n\tmove.w #${words & 65535:X},d3\n\tjsr (QueueDMATransfer).l\n'


def vram():
	return bytearray(g.vram[i ^ 1] for i in range(65536))


def written(before, dest, data):
	out = bytearray(before)
	for i, v in enumerate(data):
		out[(dest+i) & 65535] = v
	return out


body = ''
for i, value in enumerate((0, 65535, 0x1357, 0xABCD)):
	body += f'\tmoveq #1,d0\n\tmove.w #${value:X},d1\n\tjsr (MCD_Command).l\n\tmove.w d0,(${0xFF7000+i*2:X}).l\n'
probe(body)
assert [g.read(0x7000+i*2, 2) for i in range(4)] == [0, 65535, 0x1357, 0xABCD]
assert probe('\tmove.w #$7777,d0\n\tjsr (MCD_Command).l') == (65535, 0)
probe('\tjsr (MCD_Init).l'); assert g.read('MCD_status') == 1
assert probe('\tjsr (MCD_ReleaseWordRAM).l')[1] == 0
assert probe('\tjsr (MCD_AcquireWordRAM).l', restore=False)[1] == 0
# Fault injection only after genuine boot: replace the test instance's idle
# loop with a nonresponsive subprogram, then require a bounded timeout.
assert probe(f'\tmove.b #3,($A12001).l\n\tmove.w #$60FE,(${0x420000+g.s["MCD_SubEntry.wait"]:X}).l\n\tmove.b #1,($A12001).l\n\tmoveq #1,d0\n\tjsr (MCD_Command).l')[1] == 1
passed('Repeated commands, warm reset, ownership round trip and service timeout')

for method in ('queued', 'immediate'):
	for source, words, dest in ((0x600000,1,0x1000),(0x600000,2,0x1000),(0x600080,17,0x3FFA),
		(0x61FFFE,1,0xFFFE),(0x61FFFE,17,0xFFFA),(0x63FFFE,17,0x1000),
		(0x600000,256,0x1000),(0x600000,32768,0),(0x600000,32769,0),(0x600000,65536,0)):
		g.restore(base); before = vram()
		body = fill(source, words)
		if method == 'queued':
			body += '\tjsr (InitDMAQueue).l\n' + queue(source,dest,words) + '\tjsr (ProcessDMAQueue).l\n'
		else:
			body += f'\tdma68kToVDP ${source:X},${dest:X},${words*2:X},VRAM\n'
		probe(body + '\tmove.w #$BEEF,($C00000).l', restore=False)
		assert vram() == written(before,dest,pattern(words)+b'\xBE\xEF'), (method,hex(source),words)
		assert not g.read('MCD_dma_pending')
	passed(method + ' Word RAM: single words, bank edges, VRAM wrap and 64/128 KB')
probe(fill(0x600000,4)+'\tdma68kToVDP $600000,$1000,8,VRAM',safe=False)
assert vram()[0x1000:0x1008] != pattern(4)
passed('Negative control reproduces first-word delay')
for words in (1,32768,65536):
	g.restore(base); before=vram()
	probe(fill(0x600000,words)+'\tjsr (InitDMAQueue).l\n'+f'\tQueueStaticDMA $600000,${words*2:X},$1000\n\tjsr (ProcessDMAQueue).l',restore=False)
	assert vram() == written(before,0x1000,pattern(words))
passed('Static queue 1-word/64 KB/128 KB counts')
g.restore(base); before=vram(); rom=a.rom.read_bytes()
body=fill(0x600000,8)+'\tjsr (InitDMAQueue).l\n'+queue(0x10000,0x800,8)+queue(0x600000,0x1000,8)+queue(0x10100,0x1800,8)
body+='\tjsr (MCD_ReleaseWordRAM).l\n\tmove.w sr,($FF7010).l\n'
values=(0x12345678,0x23456789,0x3456789A,0x456789AB,0x56789ABC,0x6789ABCD)
for reg,value in zip(('d0','d1','d2','d3','a0','a2'),values): body+=f'\tmove.l #${value:X},{reg}\n'
body+='\tjsr (ProcessDMAQueue).l\n\tmovem.l d0-d3/a0/a2,($FF7020).l'
probe(body,restore=False)
assert g.read(0x7010,2)&1
assert [g.read(0x7020+i*4,4) for i in range(6)] == list(values)
expected=written(before,0x800,rom[0x10000:0x10010]);expected=written(expected,0x1000,pattern(8));expected=written(expected,0x1800,rom[0x10100:0x10110])
assert vram() == expected
assert probe('\tjsr (MCD_ReleaseWordRAM).l',restore=False)[1] == 0
probe('\tjsr (InitDMAQueue).l\n'+queue(0x10000,0x1000,1)*18+queue(0x600000,0x1000,1))
assert not g.read('MCD_dma_pending')
passed('Mixed/full queues, register contract and pending-DMA ownership lock')
for method in ('queued','immediate'):
	g.restore(base);before=vram()
	body='\tmove.b #3,($A12001).l\n.bus:\n\tbtst #1,($A12001).l\n\tbeq.s .bus\n\tmove.b #$41,($A12003).l\n'+fill(0x420000,17)
	body+=('\tjsr (InitDMAQueue).l\n'+queue(0x420000,0x1000,17)+'\tjsr (ProcessDMAQueue).l\n') if method=='queued' else '\tdma68kToVDP $420000,$1000,34,VRAM\n'
	probe(body+'\tmove.b #1,($A12003).l\n\tmove.b #1,($A12001).l',restore=False)
	assert vram() == written(before,0x1000,pattern(17))
passed('Banked PRG-RAM DMA under bus request')
for kind,command,values,mask in (('CRAM',0x20,[0,0x222,0x444,0xEEE],0xEEE),('VSRAM',0x10,[0x123,0x234,0x345,0x456],0x7FF)):
	body=''.join(f'\tmove.w #${v:X},(${0x600000+i*2:X}).l\n' for i,v in enumerate(values))
	body+=f'\tdma68kToVDP $600000,0,8,{kind}\n\tmove.l #${command:X},($C00004).l\n\tlea ($FF7000).l,a0\n'+'\tmove.w ($C00000).l,(a0)+\n'*4
	probe(body);assert [g.read(0x7000+i*2,2)&mask for i in range(4)] == values
passed('Word-RAM palette/vertical-scroll DMA')
g.restore(base);before=vram();probe('\tdma68kToVDP $1FFFA,$FFFA,32,VRAM',restore=False)
assert vram() == written(before,0xFFFA,rom[0x1FFFA:0x2001A])
passed('Ordinary ROM boundary split')
g.close()
g=Genesis(a.core,a.rom,a.listing,a.output/'no-cd',a.pal,core_options={b'genesis_plus_gx_add_on':b'none'})
for _ in range(120):
    g.run()
    if g.core.m68k_get_reg(16) == g.s['MCD_Unavailable.halt']:
        break
else:
    raise AssertionError('Missing-CD guard not reached')
assert C.c_uint8.in_dll(g.core,'system_hw').value != 0x84
assert g.read('MCD_status') == 0 and not g.read('v_errortype')
g.run(2)
g.video.save(a.output/'no-cd'/'required.png')
g.close();passed('Missing CD hardware shows requirement screen before accessing CD RAM')
(a.output/'report.json').write_text(json.dumps({'pal':a.pal,'checks':checks,'bios':'Zero-filled identification fixture, no Sega BIOS code executed','limits':'Emulation only; physical hardware/BIOS revisions untested'},indent=2)+'\n')
