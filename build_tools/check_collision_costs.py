#!/usr/bin/env python3
"""Measure whole dispatch + one/two player touch costs in Genesis Plus GX.

Use cartridge builds and identical --compare cases in separate processes.
Includes list construction/reset, not just the shortened consumer loop.
"""
import argparse
import ctypes as C
import json
import struct
from pathlib import Path
from genesis_test_core import Genesis
from check_caterkiller import CpuPrefix
from check_object_course import boot_level
from check_companion_followup import isolate


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('rom','listing','core','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--compare',type=Path)
    args=p.parse_args();g=Genesis(args.core,args.rom,args.listing,args.output)
    assert not g.s['MegaCDMode1'],'Isolated CPU timing requires the cartridge backend'
    boot_level(g,zone=0,act=0,player=0);isolate(g);base=g.save()
    cpu=CpuPrefix.in_dll(g.core,'m68k');g.core.m68k_set_reg.argtypes=[C.c_int,C.c_uint];g.core.m68k_run.argtypes=[C.c_uint]
    code=0xFF7000;playercode=0xFF7020;stop=0xFF7F00;stack=0xFF7E00
    slots=list(range(g.s['v_lvlobjspace']&65535,g.s['v_lvlobjend']&65535,g.s['object_size']))
    def act(label):
        g.core.m68k_set_reg(17,0x2700);g.core.m68k_set_reg(15,stack)
        g.write(stack,stop,4);g.write(stop,0x60FE,2)
        g.core.m68k_set_reg(16,g.s[label]);begin=cpu.cycles
        for _ in range(300000):
            if g.core.m68k_get_reg(16)==stop:
                assert g.core.m68k_get_reg(15)==stack+4
                return (cpu.cycles-begin)//7
            g.core.m68k_run(cpu.cycles+1)
        raise AssertionError(('timing did not return',hex(g.core.m68k_get_reg(16))))
    rows=[]
    for players in (1,2):
        for active in (0,4,16,32,63,90):
            for occupied in sorted({active,min(90,active+24)}):
                g.restore(base)
                g.write(g.s['v_objspace'],0,g.s['v_objend']-g.s['v_objspace'])
                g.write(code,0x4E75,2)
                g.write(playercode,0x4EB9,2);g.write(playercode+2,g.s['TouchResponse'],4);g.write(playercode+6,0x4E75,2)
                for who in ('v_player','v_player2')[:players]:
                    for f,v,n in [('code',playercode,4),('obX',600,2),('obY',116,2),('obHeight',19,1),('obRoutine',2,1)]:g.put(who,f,v,n)
                for i,a in enumerate(slots[:occupied]):
                    for f,v,n in [('code',code,4),('obX',1600,2),('obY',116,2),('obColType',9 if i<active else 0,1)]:g.put(a,f,v,n)
                act('ExecuteObjects') # seed the previous pass's list
                g.write('Timer_frames',1,2);elapsed=act('ExecuteObjects')
                g.write('Timer_frames',16,2);probe=act('ExecuteObjects')
                rows.append({'players':players,'active':active,'occupied':occupied,'cycles':elapsed,'probe_cycles':probe})
    if args.compare:
        before=json.loads(args.compare.read_text())['cases'];assert len(before)==len(rows)
        for old,new in zip(before,rows):
            assert tuple(old[k] for k in ('players','active','occupied'))==tuple(new[k] for k in ('players','active','occupied'))
            new['previous_cycles']=old['cycles'];new['saved_cycles']=old['cycles']-new['cycles']
            new['saved_probe_cycles']=old['cycles']-new['probe_cycles']
    args.output.joinpath('costs.json').write_text(json.dumps({'cases':rows,'includes_dispatch_and_registration':True,'hardware_console_measurement':False},indent=2)+'\n')
    print(json.dumps(rows,indent=2))
    g.close()

if __name__=='__main__':main()
