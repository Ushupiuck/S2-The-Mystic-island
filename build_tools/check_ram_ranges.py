#!/usr/bin/env python3
"""Execute clearRAM boundary cases and verify the packed work-RAM map."""
from pathlib import Path
import argparse
import platform
import re
import subprocess

from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN
from unicorn.m68k_const import (UC_CPU_M68K_M68000, UC_M68K_REG_A1,
                               UC_M68K_REG_PC)

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
    p.add_argument('--output', type=Path, default=ROOT / 'test-results/ram-ranges')
    args = p.parse_args()
    symbols = {name: int(value, 16) for name, value in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', args.listing.read_text())}
    address = lambda name: symbols[name] & 0xFFFFFF
    if symbols['MegaCDMode1']:
        assert address('Free_RAM_Start') == 0xFF0000
        assert address('Free_RAM_End') == address('MCD_MainWorkStart')
        assert address('MCD_MainWorkEnd') == address('Player_Art_Buffer_Start')
        assert address('Player_Art_Buffer_End') == address('Main_RAM_Start')
        assert address('Main_RAM_Start') >= 0xFF8000
        assert address('Main_RAM_End') == 0
    if 'MCD_SubDecompress' in symbols:
        assert address('Kos_decomp_buffer') == symbols['MCD_DecompOutput']
        assert address('v_objspace') == address('Main_RAM_Start')
    else:
        assert address('Kos_decomp_buffer_End') == address('v_objspace')
    assert address('v_objspace_end') == address('TempArray_LayerDef' if symbols['MegaCDMode1'] else 'v_16x16')
    if symbols['MegaCDMode1']:
        assert address('v_16x16') == symbols['MCD_TerrainBlockStage']
        assert address('Level_Layout') == symbols['MCD_TerrainLayoutStage']
        assert symbols['MCD_Terrain_SubEnd'] <= symbols['MCD_SubStack_Start']
        assert symbols['MCD_SubStack_Top'] < 0x80000
    assert address('Debug_saved_height') + 1 == address('Object_Display_Lists')
    for palette in ('v_palette', 'v_palette_fading', 'v_palette_water', 'v_palette_water_fading'):
        for line in (2, 3, 4):
            assert address(f'{palette}_line_{line}') == address(palette) + (line-1)*32

    # Assemble the real macro with typed declarations; test both addressing
    # forms, odd starts, small tails, and the complete 64-KiB RAM clear.
    win = platform.system() == 'Windows'
    tools = ROOT / 'build_tools' / ('Windows-x86' if win else 'Linux-' + platform.machine())
    assembler = tools / ('asw.exe' if win else 'asl')
    p2bin = tools / ('p2bin.exe' if win else 'p2bin')
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    cases = [(base+odd, size) for base in (0xFF0100, 0xFF8100)
             for odd in (0, 1) for size in range(1, 10)]
    cases += [(0xFF0000, 0x10000), (0xFF0001, 0xFFFF)]
    source = ['\tCPU 68000', '\tinclude "_definitions/s2.macrosetup.asm"',
              '\tinclude "_definitions/s2.macros.asm"']
    for index, (start, size) in enumerate(cases):
        source += [f'\tphase ramaddr(${start | 0xFF000000:X})',
                   f'Range{index}:\tds.b ${size:X}', f'Range{index}_End:', '\tdephase']
    source += ['\t!org 0']
    for index in range(len(cases)):
        source += [f'Case{index}:', f'\tclearRAM Range{index},Range{index}_End',
                   f'Done{index}:', '\tnop']
    asm = out / 'clear-ranges.asm'
    asm.write_text('\n'.join(source) + '\n')
    for command in ([str(assembler), '-xx', '-n', '-q', '-A', '-L', '-U', '-i', str(ROOT), str(asm)],
                    [str(p2bin), '-p=FF', str(asm.with_suffix('.p')), str(asm.with_suffix('.bin'))]):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr
    labels = {name: int(value, 16) for name, value in re.findall(
        r'\*?((?:Case|Done)\d+)\s*:\s*([0-9A-F]+)\s+[C-]', asm.with_suffix('.lst').read_text())}
    cpu = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
    cpu.ctl_set_cpu_model(UC_CPU_M68K_M68000)
    cpu.mem_map(0, 0x10000)
    cpu.mem_map(0xFF0000, 0x10000)
    cpu.mem_map(0xFFFF0000, 0x10000)
    cpu.mem_write(0, asm.with_suffix('.bin').read_bytes())
    for index, (start, size) in enumerate(cases):
        cpu.mem_write(0xFF0000, b'\xA5' * 0x10000)
        cpu.mem_write(0xFFFF0000, b'\xA5' * 0x10000)
        cpu.emu_start(labels[f'Case{index}'], labels[f'Done{index}'], count=100000)
        assert cpu.reg_read(UC_M68K_REG_PC) == labels[f'Done{index}'], (start, size, 'loop overran')
        expected = bytearray(b'\xA5' * 0x10000)
        offset = start & 0xFFFF
        expected[offset:offset+size] = bytes(size)
        # ramaddr emits sign-extended addresses in both operand forms.
        assert bytes(cpu.mem_read(0xFFFF0000, 0x10000)) == expected, (start, size, 'boundary write')
        assert cpu.reg_read(UC_M68K_REG_A1) & 0xFFFFFF == (start+size) & 0xFFFFFF
    print(f'Packed RAM boundaries, palette aliases and {len(cases)} native clearRAM cases pass.')


if __name__ == '__main__':
    main()
