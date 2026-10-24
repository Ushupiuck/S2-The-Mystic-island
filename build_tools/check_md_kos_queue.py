#!/usr/bin/env python3
"""Interrupt/resume the real cartridge Kosinski+ queue at both VBlank exits.

Construct the 68000 exception/register frame at selected decoder instructions,
then execute the production IRQ exit, RTE, bookmark and queue continuation in
Genesis Plus GX. Expected bytes come from the independent Python decoder.
"""
from pathlib import Path
import argparse
import ctypes as C
import json

from genesis_test_core import Genesis
from check_caterkiller import CpuPrefix
from check_object_course import boot_level
from convert_s1_ss_background import kosinski_plus_decode

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('rom', 'listing', 'core', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--pal', action='store_true')
    a = p.parse_args()
    g = Genesis(a.core, a.rom, a.listing, a.output, a.pal)
    assert not g.s['MegaCDMode1'], 'This runner exercises cartridge-only code'
    boot_level(g, zone=0)
    clean = g.save()
    cpu = CpuPrefix.in_dll(g.core, 'm68k')
    g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
    g.core.m68k_run.argtypes = [C.c_uint]
    reg = g.core.m68k_get_reg
    setreg = g.core.m68k_set_reg
    stop = g.s['Free_RAM_Start'] & 0xFFFFFF
    stack = (g.s['v_systemstack'] & 0xFFFFFF) - 4
    source = (ROOT / 'mappings/128x128/GHZ.kosp').read_bytes()
    expected = kosinski_plus_decode(source)[0]
    rom = a.rom.read_bytes()
    source_address = rom.find(source)
    assert source_address >= 0 and len(expected) == 0x8000
    dest = g.s['Chunk_Table'] & 0xFFFFFF

    def step():
        g.core.m68k_run(cpu.cycles + 1)

    def until(pc, limit=500000):
        for _ in range(limit):
            if reg(16) == pc:
                return
            step()
        raise AssertionError(('CPU did not reach target', hex(pc), hex(reg(16))))

    def start_queue():
        g.write(stack, stop, 4)
        g.write(stop, 0x60FE, 2)
        setreg(17, 0x2700)
        setreg(15, stack)
        setreg(16, g.s['Process_Kos_Queue'])

    report = []
    for exit_name in ('VintRet', 'VInt_0_Water_Cont'):
        g.restore(clean)
        for i in range(len(expected)):
            g.write(dest + i, 0xA5)
        g.write('Kos_decomp_source', source_address, 4)
        g.write('Kos_decomp_destination', dest, 4)
        g.write('Kos_decomp_queue_count', 1, 2)
        interruptions = 0
        for budget in (73, 211, 509, 1021, 2039, 4093):
            start_queue()
            for _ in range(budget):
                if reg(16) == stop:
                    break
                step()
            if reg(16) == stop:
                break
            assert g.read('Kos_decomp_queue_count', 2) == 0x8001
            interrupted_pc, interrupted_sr = reg(16), reg(17)
            saved = [reg(i) for i in range(15)]
            original_sp = reg(15)
            frame = original_sp - 6
            g.write(frame, interrupted_sr, 2)
            g.write(frame + 2, interrupted_pc, 4)
            # V_Int saves d0-a6 before entering either return path.
            saved_frame = frame - 60
            for i, value in enumerate(saved):
                g.write(saved_frame + i * 4, value, 4)
            setreg(15, saved_frame)
            setreg(13, g.s['vdp_control_port'])
            setreg(16, g.s[exit_name])
            until(g.s['Backup_Kos_Registers'])
            assert g.read('Kos_decomp_bookmark', 4) == interrupted_pc
            assert reg(15) == original_sp
            assert [reg(i) for i in range(15)] == saved
            until(stop)
            assert reg(15) == stack + 4
            assert g.read('Kos_decomp_queue_count', 2) == 0x8001
            # Other foreground work may clobber these between queue slices.
            for i in range(15):
                setreg(i, 0xDEAD0000 + i)
            interruptions += 1
        start_queue()
        until(stop)
        assert reg(15) == stack + 4
        assert not g.read('Kos_decomp_queue_count', 2)
        actual = bytes(g.read(dest + i) for i in range(len(expected)))
        assert actual == expected, (exit_name, 'resumed output differs')
        assert interruptions >= 4, (exit_name, interruptions)
        report.append(dict(exit=exit_name, interruptions=interruptions,
                           decompressed_bytes=len(expected), exact_output=True))
    g.close()
    (a.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
