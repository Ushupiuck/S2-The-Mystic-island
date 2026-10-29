#!/usr/bin/env python3
"""Compare every linked compressed asset with the previous native MD codecs.

Executes the real CD job and original 68000 decoder in Unicorn. Libretro checks
cover startup, bus ownership, queue consumption and actual VRAM separately.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import struct
from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN, UC_HOOK_MEM_WRITE, UC_HOOK_MEM_READ
from unicorn.m68k_const import *

ROOT = Path(__file__).resolve().parents[1]

def symbols(path):
    return {n:int(v,16) for n,v in re.findall(r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',path.read_text())}

def cpu():
    c=Uc(UC_ARCH_M68K,UC_MODE_BIG_ENDIAN)
    c.ctl_set_cpu_model(UC_CPU_M68K_M68000)
    return c

def runtime(a, outputs):
    """Run the real foreground/IRQ/DMA path while a water split is active."""
    from genesis_test_core import Genesis
    from check_object_course import boot_level
    g=Genesis(a.core,a.rom,a.listing,a.output/'runtime',a.pal,
              system_directory=a.system_directory)
    boot_level(g,zone=4,act=0)
    water=g.read('v_waterpos1',2)
    for f,v in (('obX',0xE00),('obY',water+64),('obVelX',0),('obVelY',0)):
        g.put('v_player',f,v,2)
    g.put('v_player','obControl',1)
    for field in ('Camera_Y_pos','Camera_Min_Y_pos','Camera_Max_Y_pos','Camera_Max_Y_pos_target'):
        g.write(field,water-64,2)
    g.run(30)
    assert g.read('Water_flag') and 0<g.read('v_hbla_line')<92
    clean=g.save()
    prg=g.memory_domains['PRGRAM']
    def resident(start,size):return bytes(prg[(start+i)^1] for i in range(size))
    terrain=resident(g.s['MCD_ChunkTable_SubStart'],g.s['MCD_ChunkTable_Size'])
    blocks=resident(g.s['MCD_TerrainBlocks_Sub'],0x1800)
    cases=[]
    for label in ('Nem_MM_Propeller','Nem_Monitors','Nem_HUD'):
        g.restore(clean)
        for _ in range(120):
            if not g.read('v_plc_buffer',4) and not g.read('v_plc_patternsleft',2):break
            g.run()
        else:raise AssertionError('Initial PLC queue never drained')
        # Replace only fixture input: the production loader, CD decoder,
        # shared job, VBlank and DMA queue must perform the complete upload.
        g.write('v_plc_buffer',g.s[label],4)
        g.write(g.s['v_plc_buffer']+4,0x6000,2)
        batches=[]
        for frame in range(400):
            g.run()
            assert not g.read('v_errortype') and g.read('MCD_status')==1
            assert g.read('Water_flag') and 0<g.read('v_hbla_line')<92
            queued=g.read('v_plc_framepatternsleft',2)
            if queued:batches.append(queued)
            if not g.read('v_plc_buffer',4) and not g.read('v_plc_patternsleft',2):break
        else:raise AssertionError((label,'Runtime PLC did not finish'))
        expected=outputs[label]
        actual=bytes(g.vram[(0x6000+i)^1] for i in range(len(expected)))
        assert actual==expected,(label,'Queued VRAM differs from original decoder')
        assert resident(g.s['MCD_ChunkTable_SubStart'],g.s['MCD_ChunkTable_Size'])==terrain
        assert resident(g.s['MCD_TerrainBlocks_Sub'],0x1800)==blocks
        cases.append(dict(asset=label,frames=frame+1,observed_batches=batches))
    g.restore(clean);g.run(2);g.video.save(a.output/'runtime'/'hpz-water.png')
    g.close()
    return dict(water_hblank_line=64,cases=cases)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom',type=Path,default=ROOT/'s2built.bin')
    p.add_argument('--listing',type=Path,default=ROOT/'md-main.lst')
    p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--baseline-listing',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--core',type=Path,help='Also exercise actual HPZ water/PLC/DMA scheduling')
    p.add_argument('--system-directory',type=Path)
    p.add_argument('--pal',action='store_true')
    a=p.parse_args(); s,b=symbols(a.listing),symbols(a.baseline_listing)
    if a.core and not a.system_directory:p.error('--core requires --system-directory')
    rom=a.rom.read_bytes(); old=cpu(); sub=cpu()
    old.mem_map(0,0x400000); old.mem_write(0,a.baseline.read_bytes())
    old.mem_map(0x500000,0x20000)
    old.mem_map(0xFF0000,0x10000);old.mem_map(0xFFFF0000,0x10000)
    sub.mem_map(0,0xC0000);sub.mem_map(0xFF0000,0x10000)
    sub.mem_write(0,rom[s['MCD_SubProgram']:s['MCD_SubProgramEnd']])
    greatest=[0]
    def wrote(c,access,address,size,value,u):
        if 0x500000<=address<0x520000: greatest[0]=max(greatest[0],address+size-0x500000)
    old.hook_add(UC_HOOK_MEM_WRITE,wrote)
    def call(c,pc,stack,stop,regs):
        c.reg_write(UC_M68K_REG_SR,0x2700)
        c.reg_write(UC_M68K_REG_A7,stack)
        c.mem_write(stack,struct.pack('>I',stop))
        for r,v in regs.items():c.reg_write(r,v&0xFFFFFFFF)
        c.emu_start(pc,stop,count=4000000)
        assert c.reg_read(UC_M68K_REG_PC)==stop,(hex(pc),hex(c.reg_read(UC_M68K_REG_PC)))
        assert c.reg_read(UC_M68K_REG_A7)==stack+4,hex(pc)
    report=[]; seen=set(); linked=0; plc_batches=0; timed_batches=0; outputs={}
    clock=[None,0]
    def stopwatch(c,access,address,size,value,u):
        if clock[0] is not None:
            c.mem_write(address,struct.pack('>H',clock[0]&0xFFF))
            clock[0]+=clock[1]
    sub.hook_add(UC_HOOK_MEM_READ,stopwatch,begin=s['MCD_SubStopwatch'],end=s['MCD_SubStopwatch']+1)
    files={label:Path(file) for label,file in re.findall(r'dc.l (\w+),[^;\r\n]+; ([^\r\n]+)',(ROOT/'_definitions/Compressed Assets.asm').read_text())}
    for pos in range(s['MCD_CompressedAssets'],s['MCD_CompressedAssets_End'],8):
        begin,end=struct.unpack_from('>II',rom,pos);blob=rom[begin:end];linked+=1
        label=next((k for k,v in s.items() if v==begin and k in files),'Snd_Driver')
        path=files.get(label)
        if path:
            assert path.read_bytes()==blob,(label,'span differs from source')
        kind={'.nem':15,'.eni':16}.get(path.suffix if path else '',14)
        key=(kind,blob)
        if key in seen:continue
        seen.add(key)
        moduled=path and path.suffix=='.kospm'
        offset=2 if moduled else 0
        expected_total=int.from_bytes(blob[:2],'big') if moduled else None
        produced=0;modules=0
        for base in ((0,0x6180) if kind==16 else (0,)):
            offset=2 if moduled else 0;produced=0;modules=0
            while True:
                old.mem_write(0x300000,blob+bytes(16));sub.mem_write(s['MCD_DecompInput_Sub'],blob+bytes(16))
                old.mem_write(0x500000,b'\xA5'*0x10000);sub.mem_write(s['MCD_DecompOutput_Sub'],b'\xA5'*0x10000)
                greatest[0]=0
                regs={UC_M68K_REG_A0:0x300000+offset,UC_M68K_REG_A1:0x500000,
                      UC_M68K_REG_A4:0x500000,UC_M68K_REG_D0:base}
                routine={14:'KosPlusDec',15:'NemDecToRAM',16:'EniDec'}[kind]
                call(old,b[routine],0xFF7FF0,0x3FFF00,regs)
                length=greatest[0]; assert 0<length<=s['MCD_DecompOutputSize'],(label,length)
                sub.mem_write(s['MCD_SubMainCommand'],struct.pack('>H',kind))
                sub.mem_write(s['MCD_SubMainArgument'],struct.pack('>IHH',s['MCD_DecompOutput_Sub'],base,offset))
                call(sub,s['MCD_SubDecompress'],s['MCD_SubStack_Top']-4,0x7FBF0,{UC_M68K_REG_D0:kind})
                result=int.from_bytes(sub.mem_read(s['MCD_SubOwnResult']+4,4),'big')
                consumed=int.from_bytes(sub.mem_read(s['MCD_SubOwnResult']+8,4),'big')
                assert result==length,(label,'output length',result,length)
                assert sub.mem_read(s['MCD_DecompOutput_Sub'],length)==old.mem_read(0x500000,length),(label,offset,base,'output differs')
                assert sub.mem_read(s['MCD_DecompOutput_Sub']+length,16)==b'\xA5'*16,(label,'output overrun')
                assert consumed==old.reg_read(UC_M68K_REG_A0)-(0x300000+offset),(label,'input consumption')
                produced+=length;modules+=1
                if not moduled or produced>=expected_total:break
                assert length==0x1000,(label,modules,length)
                offset+=consumed
            if moduled:assert produced==expected_total,(label,produced,expected_total)
        if kind==15:
            expected=bytes(old.mem_read(0x500000,produced))
            if label in ('Nem_MM_Propeller','Nem_Monitors','Nem_HUD'):outputs[label]=expected
            sub.mem_write(s['MCD_DecompInput_Sub'],blob+bytes(16))
            sub.mem_write(s['MCD_SubMainCommand'],struct.pack('>H',17))
            sub.mem_write(s['MCD_SubMainArgument'],struct.pack('>IHHH',s['MCD_DecompPLC_Sub'],0,0,len(blob)))
            call(sub,s['MCD_SubDecompress'],s['MCD_SubStack_Top']-4,0x7FBF0,{UC_M68K_REG_D0:17})
            output=bytearray(); frame=0
            # A different tiny Nemesis asset overwrites the generic input/table
            # between batches. PLC's resident archive and code table must survive.
            alternatives=[ROOT/f for f in files.values() if f.suffix=='.nem' and (ROOT/f).read_bytes()!=blob]
            alternate=min((q.read_bytes() for q in alternatives),key=len)
            while len(output)<produced:
                budget=(3,9,18,48,96)[frame%5]
                sub.mem_write(s['MCD_PLCBudget_Sub'],bytes((budget,)))
                # Each alternate timed job crosses the real 12-bit counter's
                # wrap, exhausting its allowance after one complete tile.
                timed=frame%2==1
                clock[:]=[0xFF8,16] if timed else [None,0]
                sub.mem_write(s['MCD_PLCTimeLimit_Sub'],struct.pack('>H',8 if timed else 0))
                call(sub,s['MCD_SubArtFrame'],s['MCD_SubStack_Top']-4,0x7FBF0,{})
                n=int.from_bytes(sub.mem_read(s['MCD_SubOwnResult']+4,2),'big')
                assert 0<n<=budget,(label,frame,n,budget)
                if timed:
                    assert n==1,(label,frame,'timed PLC did not yield',n)
                    timed_batches+=1
                output.extend(sub.mem_read(s['MCD_DecompPLC_Sub'],n*32))
                sub.mem_write(s['MCD_DecompInput_Sub'],alternate+bytes(16))
                sub.mem_write(s['MCD_SubMainCommand'],struct.pack('>H',15))
                sub.mem_write(s['MCD_SubMainArgument'],struct.pack('>IHH',s['MCD_DecompOutput_Sub'],0,0))
                call(sub,s['MCD_SubDecompress'],s['MCD_SubStack_Top']-4,0x7FBF0,{UC_M68K_REG_D0:15})
                frame+=1;plc_batches+=1
            assert output==expected,(label,'incremental PLC output differs')
        report.append(dict(label=label,codec=kind,output_bytes=produced,modules=modules))
    a.output.mkdir(parents=True,exist_ok=True)
    result=dict(linked_spans=linked,unique_payloads=len(report),plc_batches=plc_batches,timed_batches=timed_batches,assets=report,rom_sha256=hashlib.sha256(rom).hexdigest())
    if a.core:result['runtime']=runtime(a,outputs)
    (a.output/'report.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'{linked} linked spans and {len(report)} unique compressed payloads match the original MD codecs, including every module and Enigma attributes; {plc_batches} PLC batches preserve separate input/table state, including {timed_batches} timed yields across stopwatch wrap.')

if __name__=='__main__':main()
