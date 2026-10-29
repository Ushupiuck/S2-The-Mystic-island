#!/usr/bin/env python3
"""Typed event PLC admission, module ownership, final DMA and exact VRAM pixels."""
from pathlib import Path
import argparse,json,struct
from build_end_art import BANKS
from convert_s1_ss_background import kosinski_plus_decode
ROOT=Path(__file__).resolve().parents[1]
LISTS=('Explode','Boss','MechaSonic','GHZBoss','Capsule','ExplosionWall','Signpost')

def native(a):
    import native_test_core as n
    m=n.Native(a.rom,a.listing);s=m.s;rom=a.rom.read_bytes();checks=[]
    def read(address,size=1):
        return m.read(address,size) if isinstance(address,str) else int.from_bytes(m.cpu.mem_read(address&0xFFFFFF,size),'big')
    def write(address,value,size=1):
        if isinstance(address,str):m.write(address,value,size)
        else:
            m.cpu.mem_write(address&0xFFFFFF,value.to_bytes(size,'big'))
            m.cpu.mem_write((address&65535)|0xFFFF0000,value.to_bytes(size,'big'))
    def entries(name):
        pos=s['PLCKosM_'+name];count=struct.unpack_from('>h',rom,pos)[0]+1
        return [struct.unpack_from('>IH',rom,pos+2+i*6) for i in range(count)]
    for name in LISTS:
        m.cpu.mem_write(0xFF0000,bytes(65536))
        write('v_plc_buffer',0x123456,4)
        m.act('NewPLC',regs={n.UC_M68K_REG_D0:s['plcid_'+name],n.UC_M68K_REG_D1:0x19765432})
        assert read('v_plc_buffer',4)==entries(name)[0][0]|0x80000000
        assert m.cpu.reg_read(n.UC_M68K_REG_D1)==0x19765432
        m.act('ClearPLC')
        m.act('LoadPLC',regs={n.UC_M68K_REG_D0:s['plcid_'+name],n.UC_M68K_REG_D1:0x19765432,n.UC_M68K_REG_D7:0x1234})
        assert m.cpu.reg_read(n.UC_M68K_REG_D1)==0x19765432
        assert m.cpu.reg_read(n.UC_M68K_REG_D7)==0x1234
        for i,(source,dest) in enumerate(entries(name)):
            ptr=s['v_plc_buffer']+6*i
            assert read(ptr,4)==source|0x80000000 and read(ptr+4,2)==dest
            assert not source&1
        # A busy module queue must be left untouched, including its last slot.
        write('Kos_modules_left',1,2)
        before=bytes(m.cpu.mem_read(s['Kos_module_queue']&0xFFFFFF,s['Kos_module_queue_End']-s['Kos_module_queue']))
        m.act('RunPLC_RAM')
        assert read('v_plc_buffer',4)==entries(name)[0][0]|0x80000000
        assert bytes(m.cpu.mem_read(s['Kos_module_queue']&0xFFFFFF,len(before)))==before
        write('Kos_modules_left',0,2);m.act('RunPLC_RAM')
        assert read('v_plc_buffer',4)==entries(name)[0][0]|0xC0000000
        assert read('Kos_module_source',4)==entries(name)[0][0]+2
        # Module decoding/DMA are the boundary here; real frames verify below.
        write('Kos_modules_left',0,2);write('Kos_module_queue',0,4)
        write(s['Timer_frames']+1,31);m.act('RunPLC_RAM')
        head=read('v_plc_buffer',4)
        m.act('RunPLC_RAM');assert read('v_plc_buffer',4)==head
        write(s['Timer_frames']+1,32);m.act('RunPLC_RAM')
        if len(entries(name))==1:assert not read('v_plc_buffer',4)
        else:assert read('v_plc_buffer',4)==entries(name)[1][0]|0xC0000000
        checks.append(name+': typed index, register contract, busy admission, final VInt drain and wrap')
    # Exercise the existing tail-entry ABI used by object-course loaders.
    m.act('ClearPLC')
    shim=struct.pack('>HHHIHI',0x48E7,0x0060,0x43F9,s['PLC_GHZAnimals'],0x4EF9,s['LoadPLC_Raw'])
    m.cpu.mem_write(0x300000,shim);m.s['Test_RawPLC']=0x300000
    m.act('Test_RawPLC',regs={n.UC_M68K_REG_D1:0x19765432,n.UC_M68K_REG_A1:0x11223344,n.UC_M68K_REG_A2:0x55667788})
    assert read('v_plc_buffer',4)==struct.unpack_from('>I',rom,s['PLC_GHZAnimals']+2)[0]
    assert m.cpu.reg_read(n.UC_M68K_REG_D1)==0x19765432
    assert m.cpu.reg_read(n.UC_M68K_REG_A1)==0x11223344
    assert m.cpu.reg_read(n.UC_M68K_REG_A2)==0x55667788
    checks.append('raw untagged tail entry retains its caller-saved A1/A2 and D1 stack ABI')
    for label,name,_ in BANKS:
        raw=(ROOT/f'art/uncompressed/{name}.unc').read_bytes();data=(ROOT/f'art/moduled kosinski/{name}.kospm').read_bytes()
        output=bytearray();pos=2
        while len(output)<len(raw):
            block,used=kosinski_plus_decode(data,pos);output+=block;pos=used
        assert bytes(output)==raw and struct.unpack_from('>H',data)[0]==len(raw)
        assert rom[s['Kospm_'+label]:s['Kospm_'+label]+len(data)]==data
        assert not s['Kospm_'+label]&1
    return checks

def game(a):
    from genesis_test_core import Genesis
    from check_object_course import boot_level
    from check_companion_followup import isolate,place
    g=Genesis(a.core,a.rom,a.listing,a.output/'game',a.pal,system_directory=a.system_directory)
    boot_level(g,zone=0,act=3);isolate(g)
    for actor in ('v_player','v_player2'):
        place(g,actor,0x100,0x300);g.put(actor,'obControl',1)
    for _ in range(180):g.run()
    clean=g.save();s=g.s;rom=a.rom.read_bytes();checks=[]
    source={s['Kospm_'+label]:(ROOT/f'art/uncompressed/{name}.unc').read_bytes() for label,name,_ in BANKS}
    for name in LISTS:
        g.restore(clean);pos=s['PLCKosM_'+name];count=struct.unpack_from('>h',rom,pos)[0]+1
        expected=[struct.unpack_from('>IH',rom,pos+2+i*6) for i in range(count)]
        # Keep the tiny RAM caller inside the inactive reserved title-card SST.
        # Cartridge builds have no spare bytes beyond Free_RAM_Start.
        scratch=(s['v_titlecard']+8)&0xFFFFFF
        code=struct.pack('>HHIHH',0x7000|s['plcid_'+name],0x4EB9,s['LoadPLC'],0x4290,0x4E75)
        for i,b in enumerate(code):g.write(scratch+i,b)
        slot=s['v_lvlobjspace'];g.put(slot,'code',scratch,4)
        seen=False
        for frame in range(400):
            g.run();assert not g.read('v_errortype'),('CPU exception',name,frame,g.read('v_errortype'))
            seen|=bool(g.read('v_plc_buffer',4))
            if seen and not g.read('v_plc_buffer',4):break
        else:raise AssertionError((name,'module PLC did not drain'))
        for address,dest in expected:
            raw=source[address];assert bytes(g.vram[(dest+i)^1] for i in range(len(raw)))==raw,(name,hex(dest))
        checks.append(f'{name}: actual dispatcher -> LoadPLC -> module decoder -> DMA, exact VRAM ({frame+1} frames)')
    return checks

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for x in ('rom','listing','output'):p.add_argument('--'+x,type=Path,required=True)
    p.add_argument('--native',action='store_true');p.add_argument('--core',type=Path);p.add_argument('--system-directory',type=Path);p.add_argument('--pal',action='store_true')
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True);checks=[]
    if a.native:checks+=native(a)
    if a.core:checks+=game(a)
    assert checks
    (a.output/'report.json').write_text(json.dumps(dict(passed=True,checks=checks),indent=2)+'\n');print(f'{len(checks)} end-art groups pass.')
if __name__=='__main__':main()
