#!/usr/bin/env python3
"""Execute the CD mailbox loop with adversarial job register clobbers.

All 256 command bytes run with three high-byte values, both back-to-back and
after idle polling. Job executors are stubs; boot, dispatch, result publication,
acknowledgements and stack operations are the actual assembled subprogram.
Full hardware scheduling remains check_mode1.py's responsibility.
"""
from pathlib import Path
import argparse
import json
import re
import struct
from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN, UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn import m68k_const as reg

ROOT = Path(__file__).resolve().parents[1]
JOBS = ('MCD_SubRingTick', 'MCD_SubRingReset', 'MCD_SubTerrainLoad',
        'MCD_SubTerrainDraw', 'MCD_SubTerrainProbe', 'MCD_SubTerrainLayout',
        'MCD_SubTerrainAir', 'MCD_SubObjectsLoad', 'MCD_SubObjectState',
        'MCD_SubDecompress', 'MCD_SubArtFrame', 'MCD_SubTerrainObject')
ROUTES = {3: 0, 4: 1, 5: 2, 6: 3, 7: 4, 8: 4, 9: 5, 10: 5,
          11: 6, 12: 7, 13: 8, 14: 9, 15: 9, 16: 9, 17: 9, 18: 10,
          **{i: 11 for i in range(0x20, 0x2E)}}


def timing(core, rom, listing, directory, output):
    """Measure wait-entry to ack on the real emulated sub-CPU, with fixed jobs.

    Main-CPU execution is frozen during these isolated slices. This measures
    dispatcher cost, not complete mailbox latency or a game-wide speedup.
    """
    import ctypes as C
    from genesis_test_core import Genesis
    from check_caterkiller import CpuPrefix
    g = Genesis(core, rom, listing, output, system_directory=directory)
    for _ in range(1600):
        g.run()
        assert not g.read('v_errortype')
        if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
            break
    else:
        raise AssertionError('Timing fixture did not reach the real Mode 1 title')
    assert g.read('MCD_status') == 1
    prg = g.memory_domains['PRGRAM']
    # Public cd_hw_t layout: PRG, both Word-RAM views, backup RAM, ASIC registers.
    gate = (C.c_uint8 * 512).from_address(C.addressof(prg) + 0x102000)
    main = CpuPrefix.in_dll(g.core, 'm68k')
    sub = CpuPrefix.in_dll(g.core, 's68k')
    g.core.s68k_set_reg.argtypes = [C.c_int, C.c_uint]
    g.core.s68k_get_reg.argtypes = [C.c_int]
    g.core.s68k_get_reg.restype = C.c_uint
    g.core.s68k_run.argtypes = [C.c_uint]
    for i, name in enumerate(JOBS):
        code = (bytes.fromhex('7C817E42') if i in (3, 4, 6, 9, 10, 11) else b'')
        code += bytes.fromhex('70004E75')
        for j, byte in enumerate(code):
            prg[(g.s[name] + j) ^ 1] = byte

    def gateword(offset, value):
        gate[offset ^ 1] = value >> 8
        gate[(offset + 1) ^ 1] = value & 255

    costs = {}
    for command in (*range(19), *range(0x20, 0x2E), 255):
        g.core.s68k_pulse_reset()
        main.cycles = sub.cycles = 0
        main.end = 0xFFFFFFFF  # prohibit recursive main-CPU execution from Gate Array writes
        for cpu in (main, sub):
            for i in range(3):
                cpu.poll[i] = 0
        gateword(0x10, command)
        gateword(0x12, 0x1357)
        gateword(0x1E, 65535)
        gateword(0x2E, 0)
        for register, value in ((17, 0x2700), (15, g.s['MCD_SubStack_Top']),
                                (7, 0), (16, g.s['MCD_SubEntry.wait'])):
            g.core.s68k_set_reg(register, value)
        for _ in range(200):
            if gate[0x2E] == gate[0x2F] == 255:
                break
            g.core.s68k_run(sub.cycles + 1)
        else:
            raise AssertionError(('Timing command stalled', command))
        assert g.core.s68k_get_reg(15) == g.s['MCD_SubStack_Top']
        assert not sub.cycles % 4  # four 50-MHz master clocks per sub-68000 cycle
        costs[f'{command:02X}'] = sub.cycles // 4
    g.close()
    return costs


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
    p.add_argument('--output', type=Path)
    p.add_argument('--core', type=Path, help='Also measure isolated dispatcher cycles in Genesis Plus GX')
    p.add_argument('--system-directory', type=Path)
    p.add_argument('--baseline-rom', type=Path)
    p.add_argument('--baseline-listing', type=Path)
    a = p.parse_args()
    if a.core and (not a.system_directory or not a.output):
        p.error('--core requires --system-directory and --output')
    if bool(a.baseline_rom) != bool(a.baseline_listing):
        p.error('Provide both baseline paths')
    if a.baseline_rom and not a.core:
        p.error('Baseline timing requires --core')
    listing = a.listing.read_text()
    assert 'Symbol Table' in listing, 'Build must finish before testing its listing'
    s = {n: int(v, 16) for n, v in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', listing)}
    rom = a.rom.read_bytes()
    program = rom[s['MCD_SubProgram']:s['MCD_SubProgramEnd']]
    assert len(program) == s['MCD_SubProgramEnd'] - s['MCD_SubProgram']
    commands = [h * 256 + b for h in (0, 0x55, 0xFF) for b in range(256)]
    checks = []
    for delay in (0, 3):
        cpu = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
        cpu.ctl_set_cpu_model(reg.UC_CPU_M68K_M68000)
        cpu.mem_map(0, 0xC0000)
        cpu.mem_map(0xFF0000, 0x10000)
        cpu.mem_write(0, program)
        job_return = s['MCD_SubStack_Start'] - 0x100
        cpu.mem_write(job_return, bytes.fromhex('4E75'))
        bottom, top = s['MCD_SubStack_Start'], s['MCD_SubStack_Top']
        guard = bytes(range(16))
        cpu.mem_write(bottom - 16, guard)
        cpu.mem_write(top, guard)
        jobs = {s[name]: i for i, name in enumerate(JOBS)}
        state = dict(index=0, token=0, acks=0, result=False, pending=False,
                     waits=0, calls=[], finished=False, minimum_sp=top)

        def word(name, value):
            cpu.mem_write(s[name], struct.pack('>H', value & 65535))

        def publish():
            cmd = commands[state['index']]
            word('MCD_SubMainCommand', cmd)
            word('MCD_SubMainArgument', cmd ^ 0x1357)
            word('MCD_SubMainToken', state['token'])
            state.update(pending=False, result=False, calls=[])

        def code(c, pc, size, unused):
            if state['finished']:
                c.emu_stop()
                return
            sp = c.reg_read(reg.UC_M68K_REG_A7)
            state['minimum_sp'] = min(state['minimum_sp'], sp)
            assert bottom <= sp <= top, ('CD stack outside allocation', hex(sp))
            if pc == s['MCD_SubEntry.wait'] and state['pending']:
                state['waits'] += 1
                if state['waits'] == delay:
                    publish()
            if pc not in jobs:
                return
            job = jobs[pc]
            assert c.reg_read(reg.UC_M68K_REG_D0) & 65535 == commands[state['index']]
            assert c.mem_read(s['MCD_SubOwnFlags'], 1) == b'\x80'
            state['calls'].append(job)
            # Every job may destroy every register except SP and its result.
            for name in [*(f'D{i}' for i in range(1, 8)), *(f'A{i}' for i in range(7))]:
                c.reg_write(getattr(reg, 'UC_M68K_REG_' + name), 0xDEADBA00 + ord(name[-1]))
            c.reg_write(reg.UC_M68K_REG_D0, 0x4000 + job)
            if job == 6:
                c.mem_write(s['MCD_SubOwnFlags'], b'\x83')
            c.reg_write(reg.UC_M68K_REG_PC, job_return)

        def wrote(c, access, address, size, value, unused):
            if address == s['MCD_SubOwnResult']:
                state['result'] = True
            if address != s['MCD_SubOwnAck']:
                return
            cmd = commands[state['index']]
            low, route = cmd & 255, ROUTES.get(cmd & 255)
            expected = (0x4000 + route if route is not None else cmd if low == 0 else
                        cmd ^ 0x1357 if low == 1 else 0 if low == 2 else 65535)
            assert state['result'], ('ack before result', cmd)
            assert int.from_bytes(c.mem_read(s['MCD_SubOwnResult'], 2), 'big') == expected, cmd
            assert value == state['token'], ('wrong request acknowledged', cmd)
            assert c.reg_read(reg.UC_M68K_REG_A7) == top, ('unbalanced CD stack', cmd)
            assert state['calls'] == ([] if route is None else [route]), ('wrong executor', cmd)
            flags = b'\x83' if route == 6 else b'\x80'
            assert c.mem_read(s['MCD_SubOwnFlags'], 1) == flags, ('result flags lost', cmd)
            state['acks'] += 1
            state['index'] += 1
            if state['index'] == len(commands):
                state['finished'] = True
                return
            state['token'] ^= 65535
            if delay:
                state.update(pending=True, waits=0)
            else:
                publish()

        publish()
        cpu.hook_add(UC_HOOK_CODE, code)
        cpu.hook_add(UC_HOOK_MEM_WRITE, wrote)
        cpu.reg_write(reg.UC_M68K_REG_SR, 0x2700)
        cpu.reg_write(reg.UC_M68K_REG_A7, top)
        cpu.emu_start(s['MCD_SubEntry'], job_return - 0x10, count=500000)
        assert state['finished'] and state['acks'] == len(commands), state
        assert cpu.mem_read(bottom - 16, 16) == guard
        assert cpu.mem_read(top, 16) == guard
        checks.append(dict(idle_polls=delay, requests=state['acks'],
                           maximum_dispatch_stack_bytes=top - state['minimum_sp']))
    report = dict(passed=True, checks=checks, job_executors_stubbed=True,
                  full_hardware_scheduling_tested=False)
    if a.core:
        report['sub_cpu_cycles'] = timing(a.core, a.rom, a.listing, a.system_directory,
                                          a.output.parent / 'timing-current')
        if a.baseline_rom:
            report['baseline_sub_cpu_cycles'] = timing(
                a.core, a.baseline_rom, a.baseline_listing, a.system_directory,
                a.output.parent / 'timing-baseline')
            report['cycles_saved'] = {
                k: v - report['sub_cpu_cycles'][k]
                for k, v in report['baseline_sub_cpu_cycles'].items()}
            print('Sub-CPU cycles saved per command:', report['cycles_saved'])
    if a.output:
        a.output.parent.mkdir(parents=True, exist_ok=True)
        a.output.write_text(json.dumps(report, indent=2) + '\n')
    print('1,536 CD dispatch requests passed: routing, tokens, flags, clobbers and stack guards.')


if __name__ == '__main__':
    main()
