#!/usr/bin/env python3
"""Check real ring timer jobs, gameplay, memory isolation and frame-section cost.

Run --baseline on the previous CD ROM for the same measured post-scroll work.
Native probes execute assembled code on both actual emulated 68000s. Complete
frames always resume from genuine frame-boundary states, never probe stacks.
"""
from pathlib import Path
import argparse
import ctypes as C
import hashlib
import json
from genesis_test_core import Genesis
from check_caterkiller import CpuPrefix
from check_object_course import boot_level

ROOT = Path(__file__).resolve().parents[1]


def tick(word):
    timer, frame = word >> 8, word & 255
    if timer in (0, 255):
        return word
    timer -= 1
    if not timer:
        timer = 6
        frame += 1
        if frame == 5:
            return 65535
    return timer * 256 + frame


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('core', 'output', 'system-directory'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--rom', type=Path, default=ROOT/'s2built.bin')
    p.add_argument('--listing', type=Path, default=ROOT/'main.lst')
    p.add_argument('--pal', action='store_true')
    p.add_argument('--baseline', action='store_true')
    args = p.parse_args()
    g = Genesis(args.core, args.rom, args.listing, args.output, args.pal,
                system_directory=args.system_directory)
    cpu = CpuPrefix.in_dll(g.core, 'm68k')
    subcpu = CpuPrefix.in_dll(g.core, 's68k')
    g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
    g.core.m68k_run.argtypes = [C.c_uint]
    g.core.s68k_get_reg.argtypes = [C.c_int]
    g.core.s68k_get_reg.restype = C.c_uint
    checks, costs, courses = [], [], []

    probe_stop = g.s['Free_RAM_Start'] & 0xFFFFFF
    probe_stack = (g.s['v_systemstack'] & 0xFFFFFF) - 4

    def act(label, regs=None, stop=None):
        g.core.m68k_set_reg(17, 0x2700)
        for reg, value in (regs or {}).items():
            g.core.m68k_set_reg(reg, value & 0xFFFFFFFF)
        g.write(probe_stack, probe_stop, 4)
        g.write(probe_stop, 0x60FE, 2)
        g.core.m68k_set_reg(15, probe_stack)
        g.core.m68k_set_reg(16, g.s[label])
        start = cpu.cycles
        for _ in range(200000):
            pc = g.core.m68k_get_reg(16)
            if pc == (g.s[stop] if stop else probe_stop):
                return (cpu.cycles-start)//7
            g.core.m68k_run(cpu.cycles+1)
        raise AssertionError((label, hex(g.core.m68k_get_reg(16))))

    def next_slice():
        # Direct probes bypass the core's end-of-frame scheduler. Keep the
        # two clock origins bounded per slice: its 32-bit clock-conversion
        # multiplication otherwise overflows after many synthetic frames.
        # No emulated timers are enabled. Never resume full frames from here.
        for c in (cpu, subcpu):
            c.cycles = 0
            c.poll[0] = 0
            c.poll[1] = 0

    def passed(name):
        checks.append(name)
        print(name + ': passed', flush=True)

    boot_level(g, zone=4, act=0)
    base = g.save()
    rings = g.s['Ring_Positions']
    prg = g.memory_domains['PRGRAM']
    assert len(prg) == 0x80000
    tail = bytes((i*37+19) & 255 for i in range(0xE000, 0x26000))
    guard = bytes(range(64))

    def canaries():
        prg[0xE000:0x26000] = tail
        if not args.baseline:
            end = g.s['MCD_RingJob_SubEnd']
            prg[end:end+64] = guard

    def intact():
        assert bytes(prg[0xE000:0x26000]) == tail, 'Expanded chunk tail was overwritten'
        if not args.baseline:
            end = g.s['MCD_RingJob_SubEnd']
            assert bytes(prg[end:end+64]) == guard, 'Ring job wrote past its allocation'

    def prepare():
        g.restore(base)
        if not args.baseline:
            act('MCD_ResetRingAnimations')
        for slot in range(255):
            g.write(rings+slot*6, 0, 2)
        canaries()

    def collect(slot):
        address = rings+slot*6
        g.write(address, 0x601, 2)
        return 0 if args.baseline else act('MCD_RecordRingCollection', {9: address})

    def animate():
        next_slice()
        if args.baseline:
            return act('RingsManager')
        before = [g.read(rings+i*6, 2) for i in range(255)]
        cost = act('MCD_BeginRingJob')
        # Publishing a job must not prematurely change the visible state.
        assert [g.read(rings+i*6, 2) for i in range(255)] == before
        cost += act('MCD_FinishRingJob')
        assert not g.read('MCD_RingJobPending', 2)
        return cost

    # All offsets, including the last original timer slot, plus dense expiry.
    for count in (0, 1, 3, 32, 255):
        prepare()
        reference = [0]*255
        event_cost = 0
        slots = list(range(255-count, 255))
        for slot in slots:
            event_cost += collect(slot)
            reference[slot] = 0x601
        animate()
        reference = [tick(w) for w in reference]
        assert [g.read(rings+i*6, 2) for i in range(255)] == reference
        # Include all the real work between submission and Render_Sprites,
        # including both transfers and any wait, on the second active frame.
        next_slice()
        cost = act('Level_SkipScroll', stop='Render_Sprites')
        reference = [tick(w) for w in reference]
        assert [g.read(rings+i*6, 2) for i in range(255)] == reference
        costs.append(dict(active=count, post_scroll_cpu_cycles=cost,
                          collection_queue_cpu_cycles=event_cost))
        for iteration in range(24):
            animate()
            reference = [tick(w) for w in reference]
            assert [g.read(rings+i*6, 2) for i in range(255)] == reference
            intact()
        assert all(reference[i] == 65535 for i in slots)
    passed('0/1/3/32/255 rings match the original byte timers through expiration')

    prepare()
    reference = [0]*255
    for frame in range(55):
        for slot in {0: [1, 2, 254], 1: [120], 5: [37, 38], 23: [200]}.get(frame, []):
            collect(slot)
            reference[slot] = 0x601
        if not args.baseline:
            next_slice()
            act('MCD_BeginRingJob')
            # Model the PRG-bus pause that VBlank performs mid-job.
            act('MCD_AcquireProgramRAM')
            act('MCD_FinishRingJob')
        else:
            animate()
        reference = [tick(w) for w in reference]
        assert [g.read(rings+i*6, 2) for i in range(255)] == reference
        intact()
    passed('Staggered lifetimes and intervening PRG bus acquisition')

    if not args.baseline:
        collect(17)
        act('MCD_BeginRingJob')
        act('RingsManager_Setup')
        assert g.read('MCD_RingEventCount', 2) == 0
        assert g.read('MCD_RingActiveCount', 2) == 0
        assert g.read('MCD_RingJobPending', 2) == 0
        assert g.read(rings+17*6, 2) == 0
        intact()
        passed('Level setup drains a pending job before clearing animation state')

    # Whole-frame tests of both character modes and animated-tile stages.
    # Save/restore here only uses real frame boundaries.
    g.restore(base)
    for zone, act_number in ((4, 0), (8, 0), (8, 1)):
        for player in (0, 2):
            if courses:
                g.write('v_gamemode', g.s['SegaScreen'], 2)
                g.run()
                boot_level(g, zone=zone, act=act_number, player=player)
            elif player != 0:
                raise AssertionError('First boot must match the fixture')
            # Place a real collectible at the live character position. The
            # object physics/collision path records it; no event is injected.
            # Keep the sorted array and move the character to a visible ring.
            start = g.read('Ring_start_addr', 2)
            end = g.read('Ring_end_addr', 2)
            address = 0xFF0000 | start
            while address < (0xFF0000 | end) and (g.read(address, 2) or not g.read(address+2, 2)):
                address += 6
            assert address < (0xFF0000 | end), (zone, act_number, 'No visible ring')
            x, y = g.read(address+2, 2), g.read(address+4, 2)
            for field, value, size in (('obX', x, 2), ('obY', y, 2), ('obVelX', 0, 2),
                                       ('obVelY', 0, 2), ('obInertia', 0, 2), ('flashtime', 0, 2)):
                g.put('v_player', field, value, size)
            g.put('v_player', 'obRoutine', 2)
            g.put('v_player', 'obControl', 0)
            canaries()
            initial_rings = g.read('v_rings', 2)
            observed = []
            active_frame = None
            for frame in range(28):
                g.run()
                assert not g.read('v_errortype')
                assert g.read('MCD_status') == 1
                intact()
                observed.append(g.read(address, 2))
                if observed[-1] == 0x501:
                    active_frame = g.save()
            assert 0x501 in observed and 65535 in observed, (zone, act_number, player, observed)
            nonzero = [w for w in observed if w]
            assert nonzero[:24] == [tick_n for tick_n in timer_sequence()], observed
            assert g.read('v_rings', 2) > initial_rings
            # Pausing freezes an active animation in the full game loop.
            assert active_frame is not None
            g.restore(active_frame)
            canaries()
            g.buttons = {3}; g.run(); g.buttons = set(); g.run(2)
            assert g.read('f_pause', 2) == 1
            frozen = bytes(g.ram[(rings & 65535):(rings & 65535)+0x600])
            g.run(30)
            assert bytes(g.ram[(rings & 65535):(rings & 65535)+0x600]) == frozen
            g.buttons = {3}; g.run(); g.buttons = set(); g.run(3)
            assert g.read('f_pause', 2) == 0
            for frame in range(360):
                g.buttons = {7} | ({0} if frame%120 < 20 else set())
                g.run()
                assert not g.read('v_errortype')
                assert g.read('MCD_status') == 1
                intact()
            g.video.save(args.output/f'zone-{zone}-act-{act_number}-player-{player}.png')
            courses.append(dict(zone=zone, act=act_number+1, player=player,
                                ring_timer_sequence=nonzero[:24]))
    passed('Both character modes collect/render rings, pause and play in HPZ/SMZ1/SMZ2')
    g.close()
    report = dict(region='PAL' if args.pal else 'NTSC', baseline=args.baseline,
                  rom_sha256=hashlib.sha256(args.rom.read_bytes()).hexdigest(),
                  checks=checks, costs=costs, courses=courses)
    (args.output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(costs, flush=True)


def timer_sequence():
    word = 0x601
    result = []
    for _ in range(24):
        word = tick(word)
        result.append(word)
    return result


if __name__ == '__main__':
    main()
