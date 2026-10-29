#!/usr/bin/env python3
"""Stress real level rendering with guest CPU delay; watch blocks/chunks/layout.

The disposable ROM inserts a balanced DBF delay into the existing horizontal
block renderer. IRQs, VDP timing, CD jobs and level transitions still execute
through the normal emulator frame scheduler. This amplifies a timing window;
it does not claim to reproduce an owner's intermittent case at normal speed.
"""
from pathlib import Path
import argparse
import json
import re
import struct

from genesis_test_core import Genesis
from convert_s1_ss_background import kosinski_plus_decode

p = argparse.ArgumentParser(description=__doc__)
for key in ('rom', 'listing', 'core', 'output'):
    p.add_argument('--' + key, type=Path, required=True)
p.add_argument('--system-directory', type=Path)
p.add_argument('--pal', action='store_true')
p.add_argument('--zone', type=int, choices=(0, 2, 4), default=4)
p.add_argument('--delay', type=int, default=127, help='DBF counter; 0 uses the unmodified ROM')
a = p.parse_args()
assert 0 <= a.delay <= 65535
symbols = {key: int(value, 16) for key, value in re.findall(
    r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', a.listing.read_text())}
rom = a.rom.read_bytes()
a.output.mkdir(parents=True, exist_ok=True)
test_rom = a.rom
sub_patch = None
if a.delay:
    on_cd = 'MCD_Subloc_6DB2' in symbols
    target = symbols['MCD_Subloc_6DB2' if on_cd else 'loc_6DB2']
    rom_target = target + (symbols['MCD_SubProgram'] if on_cd else 0)
    displaced = rom[rom_target:rom_target + 8]
    assert displaced.hex() == '3610024303ffe74b', 'Review the displaced block-index instructions'
    cave = symbols['MCD_SubStack_Start'] - 0x100 if on_cd else (len(rom) + 0xFFF) & ~0xFFF
    # Save CCR/D7, burn real 68000 cycles, restore, execute displaced code,
    # then jump back. No test RAM flag or source-data write is introduced.
    delay = (bytes.fromhex('40e72f073e3c') + struct.pack('>H', a.delay)
             + bytes.fromhex('51cffffe2e1f44df') + displaced
             + bytes.fromhex('4ef9') + struct.pack('>I', target + 8))
    jump = bytes.fromhex('4ef9') + struct.pack('>I', cave) + bytes.fromhex('4e71')
    if on_cd:
        # Install after the genuine upload/verification. Burn CD cycles in the
        # relocated renderer without changing its data or mailbox algorithm.
        sub_patch = ((cave, delay), (target, jump))
    else:
        patched = bytearray(rom)
        patched.extend(b'\xFF' * (cave + len(delay) - len(patched)))
        patched[cave:] = delay
        patched[target:target + 8] = jump
        struct.pack_into('>I', patched, 0x1A4, len(patched) - 1)
        checksum = sum(struct.unpack('>' + str((len(patched) - 0x200) // 2) + 'H', patched[0x200:])) & 0xFFFF
        struct.pack_into('>H', patched, 0x18E, checksum)
        test_rom = a.output / 'lag-fixture.bin'
        test_rom.write_bytes(patched)

g = Genesis(a.core, test_rom, a.listing, a.output, a.pal, system_directory=a.system_directory)
watch = []
frames_checked = 0
min_sp = g.s['v_systemstack'] & 0xFFFFFF


def data_at(base, count):
    address = base & 0xFFFFFF
    if 'MCD_TerrainData_Sub' in g.s and address < 0x80000:
        memory, offset = g.memory_domains['PRGRAM'], address
    elif 0x420000 <= address < 0x440000:
        memory, offset = g.memory(base)
    else:
        memory, offset = g.ram, address & 0xFFFF
    return bytes(memoryview(memory).cast('B')[offset:offset + count])


def bus_order(raw):
    assert len(raw) % 2 == 0
    result = bytearray(len(raw))
    result[0::2], result[1::2] = raw[1::2], raw[0::2]
    return bytes(result)


def run(count=1):
    global frames_checked, min_sp
    for _ in range(count):
        g.run()
        assert not g.read('v_errortype'), ('CPU exception', g.frame)
        if not watch:
            continue
        frames_checked += 1
        min_sp = min(min_sp, g.core.m68k_get_reg(15) & 0xFFFFFF)
        for name, base, expected in watch:
            actual = data_at(base, len(expected))
            if actual != expected:
                # Convert the first differing byte back to a CPU bus address.
                first = next(i for i, pair in enumerate(zip(actual, expected)) if pair[0] != pair[1]) ^ 1
                g.video.save(a.output / ('bad-' + name + '.png'))
                (a.output / ('bad-' + name + '.bin')).write_bytes(bus_order(actual))
                raise AssertionError((name, 'changed', frames_checked, hex((base + first) & 0xFFFFFF),
                                      'PC', hex(g.core.m68k_get_reg(16)), 'SP', hex(g.core.m68k_get_reg(15))))


def press(button):
    g.buttons = {button}
    run(2)
    g.buttons = set()
    run(2)


def title():
    for _ in range(2400):
        run()
        if g.read('v_vbla_routine', 2) == g.s['Vint_Title'] and g.read('v_generictimer', 2) == 375:
            return
    raise AssertionError('Title did not start')


def menu():
    g.write('f_levselcheat', 1)
    press(3)
    run(110)


def decode(pointer):
    return kosinski_plus_decode(rom[pointer:])[0]


title()
if sub_patch:
    prg = g.memory_domains['PRGRAM']
    for address, data in sub_patch:
        for i, byte in enumerate(data):
            prg[(address+i)^1] = byte
menu()
for zone in (0, 2, 4):
    g.write('v_levselitem', zone * 4, 2)
    press(3)
    for _ in range(1800):
        run()
        if (g.read('v_vbla_routine', 2) == g.s['Vint_Level'] and g.read('f_timecount')
                and g.read('v_gamemode', 2) == g.s['Level']):
            break
    else:
        raise AssertionError(('Level did not start', zone))
    run(120)
    header = g.s['LevelArtPointers'] + zone * 4 * 12
    loaded = []
    for name, offset, label in (('blocks', 4, 'v_16x16'), ('chunks', 8, 'Chunk_Table')):
        pointer = struct.unpack_from('>I', rom, header + offset)[0] & 0xFFFFFF
        expected = bus_order(decode(pointer))
        base = g.s[{'v_16x16':'MCD_TerrainBlocks_Sub', 'Chunk_Table':'MCD_ChunkTable_SubStart'}[label]] if 'MCD_TerrainData_Sub' in g.s else g.s[label]
        assert data_at(base, len(expected)) == expected, (zone, name, 'incorrect load')
        loaded.append((name, base, expected))
    run(250 if a.pal else 300)
    if zone == a.zone:
        base = g.s['MCD_TerrainLayout_Sub'] if 'MCD_TerrainData_Sub' in g.s else g.s['Level_Layout']
        layout_bytes = g.s.get('PlaneLayout_Capacity', 0x1000) if g.s['MegaCDMode1'] else 0x1000
        watch = loaded + [('layout', base, data_at(base, layout_bytes))]
        break
    g.write('f_slomocheat', 1)
    press(3)
    assert g.read('f_pause', 2) == 1
    press(1)
    title()
    menu()

g.write('Debug_mode_flag', 1)
press(0)
assert g.read('Debug_placement_mode', 2), 'Debug did not activate'
for segment, button in enumerate((7, 5, 7, 7, 4, 6)):
    g.buttons = {button}
    for tick in range(240):
        run()
        if tick % 60 == 0:
            g.video.save(a.output / f'travel-{segment}-{tick:03}.png')
    g.buttons = set()
    run(2)
run(120)
g.video.save(a.output / 'settled.png')
report = dict(zone=a.zone, pal=a.pal, injected_delay=a.delay, frames_checked=frames_checked,
              minimum_sampled_sp=hex(min_sp), chunks_blocks_layout_unchanged=True)
(a.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(report, flush=True)
g.close()
