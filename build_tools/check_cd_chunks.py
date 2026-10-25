#!/usr/bin/env python3
"""Exercise CD chunks, cached player art and the remaining free MD RAM.

Runs assembled renderer/collision routines in Genesis Plus GX, including every
chunk/block combination. The controller sequence and bonus stage execute whole
frames; fixtures only set initial positions, scratch code and RAM canaries.
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
p = argparse.ArgumentParser(description=__doc__)
for name in ('core', 'output', 'system-directory'):
    p.add_argument('--' + name, type=Path, required=True)
p.add_argument('--pal', action='store_true')
a = p.parse_args()
g = Genesis(a.core, ROOT/'s2built.bin', ROOT/'md-main.lst', a.output,
            a.pal, system_directory=a.system_directory)
assert g.s['Chunk_Table'] == g.s['MCD_ProgramRAM'] + g.s['MCD_BIOS_RAM_End'] == 0x426000
assert g.s['Chunk_Table_End'] - g.s['Chunk_Table'] == 0x8000
assert g.s['MCD_ChunkTable_SubStart'] == 0x6000
assert g.s['MCD_ChunkTable_SubEnd'] == 0x26000
assert g.s['MCD_ChunkTable_Size'] == 0x20000
free_start = g.s['Free_RAM_Start'] & 0xFFFF
free_end = g.s['Free_RAM_End'] & 0xFFFF
assert g.s['Free_RAM_End'] == g.s['MCD_MainWorkStart']
assert g.s['MCD_MainWorkEnd'] == g.s['Player_Art_Buffer_Start']
assert g.s['Player_Art_Buffer_End'] == g.s['Main_RAM_Start']
assert g.s['v_ssbg_end'] <= g.s['Chunk_Table_End']
boot_level(g, zone=0, act=0)
assert g.read('MCD_status') == 1
stage = g.save()
checks = []

def passed(name, **detail):
    checks.append(dict(case=name, **detail))
    print(name + ': passed', flush=True)

cpu = CpuPrefix.in_dll(g.core, 'm68k')
g.core.m68k_set_reg.argtypes = [C.c_int, C.c_uint]
g.core.m68k_run.argtypes = [C.c_uint]

probe_stop = g.s['Free_RAM_Start'] & 0xFFFFFF
probe_stack = (g.s['v_systemstack'] & 0xFFFFFF) - 4

def act(label, regs=None):
    g.core.m68k_set_reg(17, 0x2700)
    for reg, value in (regs or {}).items():
        g.core.m68k_set_reg(reg, value & 0xFFFFFFFF)
    g.write(probe_stack, probe_stop, 4)
    g.write(probe_stop, 0x60FE, 2)
    g.core.m68k_set_reg(15, probe_stack)
    g.core.m68k_set_reg(16, g.s[label])
    for _ in range(20000):
        if g.core.m68k_get_reg(16) == probe_stop:
            assert g.core.m68k_get_reg(15) == probe_stack + 4, label
            return
        g.core.m68k_run(cpu.cycles + 1)
    raise AssertionError((label, hex(g.core.m68k_get_reg(16))))

# Execute the relocated lookup/stream routines on the emulated CD CPU. The
# full-frame tests below resume a clean machine snapshot with the real service.
subcpu = CpuPrefix.in_dll(g.core, 's68k')
for name in ('set_reg', 'get_reg'):
    getattr(g.core, 's68k_' + name).argtypes = [C.c_int, C.c_uint] if name == 'set_reg' else [C.c_int]
g.core.s68k_get_reg.restype = C.c_uint
g.core.s68k_run.argtypes = [C.c_uint]
prg = g.memory_domains['PRGRAM']
# The core declares both 1M banks before the 2M allocation, immediately after
# PRG RAM. Use the exported memory-map pointer rather than guessing struct size.
word = (C.c_uint8 * 0x40000).from_address(C.addressof(prg) + 0xC0000)

def subwrite(address, value, size=1):
    address = g.s[address] if isinstance(address, str) else address
    memory, offset = (prg, address) if address < 0x80000 else (word, address - 0x80000)
    for i, byte in enumerate(value.to_bytes(size, 'big')):
        memory[(offset+i)^1] = byte

def subread(address, size=1):
    memory, offset = (prg, address) if address < 0x80000 else (word, address - 0x80000)
    return int.from_bytes(bytes(memory[(offset+i)^1] for i in range(size)), 'big')

def subact(label, regs=None):
    g.core.s68k_pulse_reset()
    subcpu.cycles = 0
    subcpu.poll[0] = subcpu.poll[1] = 0
    stop, stack = 0x7FBF0, g.s['MCD_SubStack_Top']-4
    subwrite(stack, stop, 4)
    for reg, value in {17:0x2700, 15:stack, **(regs or {})}.items():
        g.core.s68k_set_reg(reg, value & 0xFFFFFFFF)
    g.core.s68k_set_reg(16, g.s[label])
    for _ in range(30000):
        if g.core.s68k_get_reg(16) == stop:
            assert g.core.s68k_get_reg(15) == stack+4, label
            return
        g.core.s68k_run(subcpu.cycles+1)
    raise AssertionError((label, [hex(g.core.s68k_get_reg(i)) for i in (0,1,9,15,16,17)], subcpu.cycles, hex(subread(stack,4)), hex(g.s[label])))

subwrite('MCD_TerrainCamera_Sub', 0, 8)
count = 0
for chunk in range(256):
    subwrite('MCD_TerrainLayout_Sub', chunk)
    for block in range(64):
        x, y = (block & 7)*16, (block >> 3)*16
        expected = g.s['MCD_ChunkTable_SubStart'] + chunk*128 + block*2
        subact('MCD_SubFindTerrainBlock', {2:y, 3:x})
        assert g.core.s68k_get_reg(9) == expected, ('collision', chunk, block)
        subact('MCD_SubGetBlockData', {4:y, 5:x, 11:g.s['MCD_TerrainCamera_Sub'],
                                     12:g.s['MCD_TerrainLayout_Sub']})
        assert g.core.s68k_get_reg(8) == expected, ('render', chunk, block)
        assert g.core.s68k_get_reg(9) == g.s['MCD_TerrainBlocks_Sub'] + (subread(expected,2)&0x3FF)*8
        count += 1
passed('All 256 chunks x 64 blocks use resident CD collision and rendering', addresses=count)

# Give CD Word RAM and inspect every ordered stream record. Actual MD VDP
# consumption is covered separately by check_cd_terrain.
g.restore(stage)
if 'MCD_FlushDecodeDMA' in g.s:
    # A frame snapshot may have a decoded-art DMA queued for the next VBlank.
    # Let the real scheduler consume it before taking Word RAM for a probe.
    for _ in range(1200):
        if not g.read('MCD_dma_pending'):
            break
        g.run()
    else:
        raise AssertionError('Prepared-art DMA never drained')
    act('MCD_FinishTerrainJob')
    act('MCD_FinishRingJob')
act('MCD_ReleaseWordRAM')
assert not g.core.m68k_get_reg(17) & 1, 'Fixture failed to hand Word RAM to CD'
tiles = (0x0123, 0x2456, 0x4789, 0x6ABC)
subwrite('MCD_TerrainCamera_Sub', 0, 8)
subwrite(g.s['MCD_TerrainBlocks_Sub']+8, int.from_bytes(b''.join(t.to_bytes(2,'big') for t in tiles),'big'),8)
for chunk in range(256):
    for cell in (0,1,256,257):
        subwrite(g.s['MCD_TerrainLayout_Sub']+cell, chunk)
    for flip in (0,0x400,0x800,0xC00):
        for block in (0,1,7,8,15,56,57,63):
            subwrite(g.s['MCD_ChunkTable_SubStart']+chunk*128+block*2, 1|flip,2)
        expected = list(tiles)
        if flip & 0x400:
            expected = [expected[i]^0x800 for i in (1,0,3,2)]
        if flip & 0x800:
            expected = [expected[i]^0x1000 for i in (2,3,0,1)]
        for label,vertical in (('MCD_SubDrawBlocks_LR_2',False),('MCD_SubDrawBlocks_TB_2',True)):
            start = g.s['MCD_TerrainStream_Sub']
            subact(label,{0:0x3071C,2:0x4000,4:112,5:112,6:2,
                          11:g.s['MCD_TerrainCamera_Sub'],12:g.s['MCD_TerrainLayout_Sub'],14:start})
            end = g.core.s68k_get_reg(14)
            actual_tiles = {}
            while start < end:
                command, n = subread(start,4), subread(start+4,2)
                dest = ((command >> 16)&0x3FFF) | ((command&3)<<14)
                for i in range(n*2):
                    actual_tiles[(dest+i*2)&65535] = subread(start+6+i*2,2)
                start += 6+n*4
            assert start == end
            for i in range(3):
                dest = 0xC71C+i*(0x100 if vertical else 4)
                actual = [actual_tiles[dest+off] for off in (0,2,0x80,0x82)]
                assert actual == expected,(label,chunk,flip,i,actual,expected)
passed('CD row and column streams cover every chunk ID, flip and boundary', transfers=256*4*2)

canary = bytes((i * 37 + 19) & 255 for i in range(free_end-free_start))
g.restore(stage)
g.ram[free_start:free_end] = canary
for tick in range(600):
    g.buttons = {7} | ({0} if tick % 120 < 20 else set())
    g.run()
    assert not g.read('v_errortype')
    assert g.read('MCD_status') == 1
    assert bytes(g.ram[free_start:free_end]) == canary, tick
passed('600 controller-driven level frames preserve all freed MD RAM')
g.video.save(a.output/'level.png')
g.close()

# Menu -> rotating bonus stage uses the same storage for its live buffers.
g = Genesis(a.core, ROOT/'s2built.bin', ROOT/'md-main.lst', a.output/'bonus',
            a.pal, system_directory=a.system_directory)
for _ in range(1800):
    g.run()
    if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
        break
else:
    raise AssertionError('Title timeout')
g.ram[free_start:free_end] = canary
# Poison the level art to verify independent stage entry. The rotating stage
# must restore its ring source independently of a preceding ordinary level.
art_start = g.s['Player_Art_Buffer_Start'] & 0xFFFF
art_end = g.s['Player_Art_Buffer_End'] & 0xFFFF
g.ram[art_start:art_end] = bytes([0xA5]) * (art_end-art_start)
g.write('f_levselcheat', 1)
g.buttons = {3}; g.run(2); g.buttons = set(); g.run(100)
g.write('v_levselitem', g.s['LevelSelect_BonusItem'], 2)
g.run(3); g.buttons = {3}; g.run(2); g.buttons = set()
for _ in range(800):
    g.run()
    if g.read('v_vbla_routine', 2) == g.s['Vint_S1SS']:
        break
else:
    raise AssertionError('Bonus-stage timeout')
first_angle = g.read('v_ssangle', 2)
ring_art = (ROOT/'art/uncompressed/Ring.bin').read_bytes()
assert bytes(g.read(g.s['Art_Ring']+i) for i in range(len(ring_art))) == ring_art
for _ in range(180):
    g.run()
    assert not g.read('v_errortype')
    assert bytes(g.ram[free_start:free_end]) == canary
assert g.read('v_ssangle', 2) != first_angle
assert any(g.vram)
frame = g.read('v_ani1_prev')
bank = g.s['ArtTile_SS_Rings'] * 32
assert bytes(g.vram[(bank+i)^1] for i in range(128)) == ring_art[frame*128:(frame+1)*128]
g.video.save(a.output/'bonus'/'stage.png')
passed('Bonus stage restores its RAM ring source and streams to its own VRAM bank')

# Exit through the real results path and return to the level. The poisoned
# shield/star source regions must be rebuilt rather than treated as resident.
g.write('v_gamemode', g.s['Level'], 2)
for _ in range(2400):
    g.run()
    assert not g.read('v_errortype')
    if (g.read('v_vbla_routine', 2) == g.s['Vint_Level']
            and g.read('v_gamemode', 2) == g.s['Level'] and g.read('f_timecount')):
        break
else:
    raise AssertionError('Special-stage results did not return to a level')
for label, source in [('Art_Shield', 'Shield.unc'), ('Art_Invincibility', 'Invincibility.unc'),
                      ('Art_Ring', 'Ring.bin')]:
    expected = (ROOT/'art/uncompressed'/source).read_bytes()
    assert bytes(g.read(g.s[label]+i) for i in range(len(expected))) == expected, label
assert bytes(g.ram[free_start:free_end]) == canary
passed('Special-stage results return rebuilds every level art source; free RAM stays intact')
g.close()
a.output.mkdir(parents=True, exist_ok=True)
(a.output/'report.json').write_text(json.dumps(dict(
    pal=a.pal, rom_sha256=hashlib.sha256((ROOT/'s2built.bin').read_bytes()).hexdigest(),
    checks=checks), indent=2)+'\n')
