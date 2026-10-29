#!/usr/bin/env python3
"""Time S2 REV01 EHZ 2P and S3&K ALZ background events in Genesis Plus GX.

Runs the original instructions with isolated RAM aliases and disabled interrupts.
Includes deformation, final scroll-buffer writes and vertical-scroll updates;
excludes camera motion, terrain drawing, VBlank and the rest of either engine.
These effects differ: this is an event-cost comparison, not equal-effect proof.
The source checkouts stay read-only. Outputs belong in an ignored directory.
"""
from pathlib import Path
import re, subprocess, struct, json, ctypes as C, argparse, platform, hashlib
from genesis_test_core import Genesis
from check_object_course import boot_level
from check_caterkiller import CpuPrefix
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--s2-source', type=Path, required=True, help='REV01 s2.asm or its checkout directory')
parser.add_argument('--sk-source', type=Path, required=True)
parser.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
parser.add_argument('--listing', type=Path, default=ROOT/'md-main.lst')
parser.add_argument('--core', type=Path, required=True)
parser.add_argument('--system-directory', type=Path)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
OUT = args.output.resolve()
OUT.mkdir(parents=True, exist_ok=True)
s2_path = args.s2_source/'s2.asm' if args.s2_source.is_dir() else args.s2_source
s2 = s2_path.read_text()
assert re.search(r'^gameRevision\s*=\s*1\s*$', s2, re.M), 'This probe uses the REV01 lea_ configuration'
sk = (args.sk_source/'sonic3k.asm').read_text()
events = (args.sk_source/'Lockon S3/Screen Events.asm').read_text()

def section(s,a,b):return s[s.index(a):s.index(b,s.index(a)+len(a))]
code2=section(s2,'SwScrl_EHZ_2P:','; End of function sub_C71A')
code2=re.sub(r'\blea_\s+(\w+),(\w+)',r'lea \1(pc),\2',code2)
ripple=section(s2,'SwScrl_RippleData:','; ===========================================================================')
code3='ALZ_BackgroundEvent:\n\tjsr ALZ_Deformation(pc)\n\tlea ALZ_BGDeformArray(pc),a4\n\tbra.s loc_23A764\n\tds.b 36\n'+section(events,'loc_23A764:','DPZ_BackgroundEvent:')+section(events,'ALZ_Deformation:','BPZ_Deformation:')+section(sk,'ApplyDeformation2:','; End of function ApplyDeformation')+section(sk,'Update_VScrollValueP2:','SpecialEvents:')+section(sk,'AIZ2_ALZ_BGDeformDelta:','; ---------------------------------------------------------------------------')+'ALZ_BGDeformArray:\n\tdc.w $18,8,8,8,8,8,$2E,6,$D,$803F,$7FFF\n'
# Remove comments; ASL accepts the original instruction and local-label forms.
fields={
 'screen_height':224,'Vint_runcount':0xFFFF9140,'TempArray_LayerDef':0xFFFF9500,
 'Camera_BG_Y_pos':0xFFFF9104,'Vscroll_Factor_BG':0xFFFF9202,'Vscroll_Factor':0xFFFF9200,
 'Horiz_Scroll_Buf':0xFFFFA000,'Camera_X_pos':0xFFFF9100,'Camera_X_pos_P2':0xFFFF9108,
 'Camera_Y_pos_P2':0xFFFF910A,'Vscroll_Factor_P2_BG':0xFFFF9206,'Vscroll_Factor_P2_FG':0xFFFF9204,'Vscroll_Factor_P2':0xFFFF9204,
 'Camera_Y_pos_copy':0xFFFF9102,'Camera_Y_pos_P2_copy':0xFFFF910A,
 'Camera_Y_pos_BG_copy':0xFFFF9300,'Camera_Y_pos_P2_BG_copy':0xFFFF9302,
 'Camera_X_pos_copy':0xFFFF9100,'Camera_X_pos_P2_copy':0xFFFF9108,
 'Events_bg':0xFFFF9600,'Events_fg_1':0xFFFF9120,'_unkEEBA':0xFFFF9122,
 'HScroll_table':0xFFFF9800,'H_scroll_buffer':0xFFFFA000,
 'V_scroll_value_P2':0xFFFF9204,'V_scroll_value_BG_P2':0xFFFF9206}
header='\tCPU 68000\n'+'\n'.join(f'{n} equ ${v:X}' for n,v in fields.items())+'\n\torg 0\n\tphase $FF0100\n'
source=header+code2+ripple+code3+'\nProbeEnd:\n\tdephase\n'
source='\n'.join(line.split(';')[0] for line in source.splitlines() if line.strip()!='even')+'\n'
path=OUT/'probe.asm';path.write_text(source)
tools = ROOT/'build_tools'/('Windows-x86' if platform.system()=='Windows' else 'Linux-'+platform.machine())
asm = tools/('asw.exe' if platform.system()=='Windows' else 'asl')
p2bin = tools/('p2bin.exe' if platform.system()=='Windows' else 'p2bin')
r=subprocess.run([str(asm),'-q','-L',str(path)],cwd=ROOT,capture_output=True,text=True);(OUT/'assemble.log').write_text(r.stdout+r.stderr)
if r.returncode or 'error:' in r.stdout+r.stderr:
    raise SystemExit('Probe assembly failed; see '+str(OUT/'assemble.log'))
subprocess.run([str(p2bin),str(path.with_suffix('.p')),str(OUT/'probe.bin')],check=True,capture_output=True)
lst=path.with_suffix('.lst').read_text();symbols={n:int(v,16) for n,v in re.findall(r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',lst)}
g = Genesis(args.core, args.rom, args.listing, OUT/'game',
            system_directory=args.system_directory)
boot_level(g, zone=3, act=1)
assert g.s['MegaCDMode1'] and (g.s['Free_RAM_Start'] & 0xFFFFFF) < 0xFF0100
assert (g.s['Free_RAM_End'] & 0xFFFFFF) > 0xFFAF04
assert len((OUT/'probe.bin').read_bytes()) < 0x1000

for i,b in enumerate((OUT/'probe.bin').read_bytes()):g.write(0xFF0100+i,b)
main=CpuPrefix.in_dll(g.core,'m68k');sub=CpuPrefix.in_dll(g.core,'s68k')
g.core.m68k_set_reg.argtypes=[C.c_int,C.c_uint];g.core.m68k_run.argtypes=[C.c_uint]
stop,stack=0xFF8000,0xFFAF00;g.write(stop,0x60FE,2)
def call(name):
 main.cycles=sub.cycles=0
 main.poll[0]=main.poll[1]=sub.poll[0]=sub.poll[1]=0
 g.write(stack,stop,4)
 for reg,value in [(17,0x2700),(15,stack),(16,symbols[name.upper()])]:g.core.m68k_set_reg(reg,value)
 for _ in range(10000):
  if g.core.m68k_get_reg(16)==stop:return main.cycles//7
  g.core.m68k_run(main.cycles+1)
 raise AssertionError((name,hex(g.core.m68k_get_reg(16))))
rows=[]
for x1,x2 in [(0,0),(512,1024),(2048,4096),(8191,12287)]:
 for y1,y2 in [(0x194-96,0x8C-96),(0x148,0x148),(0x200,0x100)]:
  for phase in (0,7):
   costs={}
   for label in ('SwScrl_EHZ_2P','ALZ_BackgroundEvent'):
    for addr in range(0xFF9100,0xFFAA00):g.write(addr,0)
    for addr,value in [(0xFF9100,x1),(0xFF9102,y1),(0xFF9108,x2),(0xFF910A,y2),(0xFF9120,x1),(0xFF9122,x2)]:g.write(addr,value,2)
    g.write(fields['Vint_runcount']&0xFFFFFF,phase,4)
    costs[label]=call(label)
    assert g.core.m68k_get_reg(15)==stack+4, label
    assert g.read(0xFFA000+224*4,4)==0, 'Scroll-buffer overflow'
   rows.append(dict(cameras=[[x1,y1],[x2,y2]],phase=phase,cycles=costs))
report={'s2_event_sha256':hashlib.sha256(code2.encode()).hexdigest(),'sk_event_sha256':hashlib.sha256(code3.encode()).hexdigest(),'scope':'Actual assembled 2P background events only, including deformation/scroll writes and vertical register updates; excludes camera motion, terrain drawing, VBlank DMA and other frame work. Different artistic workloads are retained. Code executes from MD RAM, no interrupts.','samples':rows, 's2_source':str(s2_path), 'sk_source':str(args.sk_source)}
for label in ('SwScrl_EHZ_2P','ALZ_BackgroundEvent'):
 v=[r['cycles'][label] for r in rows];print(label,'min',min(v),'max',max(v),'mean',sum(v)/len(v))
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n');g.close()
