#!/usr/bin/env python3
"""Execute word-subtype, era-mask and fixed-SST regressions in both 68000s."""
import argparse
import json
from pathlib import Path
import re
import struct
import subprocess

from native_test_core import Manager, UC_M68K_REG_A2
from object_layout import decode, convert_s3k

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
parser.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
parser.add_argument('--before-listing', type=Path, help='Optional matching listing from before migration')
parser.add_argument('--before-ref', help='Optional original six-byte layout revision for conversion verification')
args = parser.parse_args()
m = Manager(args.rom, args.listing)
fixed = []
if args.before_listing:
    before = {n: int(v, 16) for n, v in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', args.before_listing.read_text())}
    # Every preexisting MD RAM symbol keeps its address. CD-owned storage may grow.
    fixed = [n for n, v in before.items() if 0xFF8000 <= (v & 0xFFFFFF) <= 0xFFFFFF and n in m.s]
    assert len(fixed) > 100, len(fixed)
    for name in fixed + ['object_size', 'code', 'obRender', 'obFrame', 'height_pixels',
                          'width_pixels', 'obPriority', 'obGfx', 'obMap', 'obX', 'obY',
                          'obVelX', 'obVelY', 'obHeight', 'obWidth', 'obTimeFrame',
                          'obAniFrame', 'obAnim', 'obPrevAni', 'respawn_addr',
                          'obRoutine', 'ob2ndRout', 'obAngle', 'obColType', 'obColProp',
                          'obStatus', 'obSubtype', 'obControl', 'obStatusSecondary']:
        assert m.s[name] == before[name], (name, hex(before[name]), hex(m.s[name]))
assert m.s['object_size'] == 0x4E and m.s['obSubtype'] == 0x2C
if m.s['MegaCDMode1']:
    assert m.s['MCD_ObjectSpawnSize'] == 12
rom = args.rom.read_bytes()
for label, filename in [('Art_WaterSplash', 'art/uncompressed/Water splash.unc'),
                        ('Art_LConWheels', 'art/uncompressed/LZ conveyor wheels.unc')]:
    raw = (ROOT / filename).read_bytes()
    assert rom[m.s[label]:m.s[label] + len(raw)] == raw, 'ROM/listing mismatch: ' + label

converted = 0
for path in sorted((ROOT / 'level/objects').glob('*.bin')):
    if args.before_ref:
        old = subprocess.check_output(['git', 'show', args.before_ref + ':level/objects/' + path.name], cwd=ROOT)
        assert path.read_bytes() == convert_s3k(old), path.name
    converted += len(decode(path.read_bytes()))

time_cases = 0
for zone, mask in enumerate((0x40, 0x20, 0x80, 0x80)):
    rows = [(128 + i * 8, 0x6100, 0xFC, eras, (0x1234 + i * 0x1111) & 65535)
            for i, eras in enumerate(range(0, 0x100, 0x20))]
    base = m.fixture(rows)
    m.write('Current_Timezone', zone)
    m.cam(0, 0)
    m.act('ObjectsManager')
    live = m.verify(rows, base)
    assert {handle - 1 for handle in live} == {i for i, row in enumerate(rows) if row[3] & mask}
    m.act('ObjectsManager')
    assert live == m.verify(rows, base)
    time_cases += len(rows)

# Consumed state is independent per era; Future's two variants share a bank.
rows = [(256, 128, 0xFC, 0xE0, 0xBEEF)]
m.fixture(rows)
m.cam(0, 0)
for zone, expected in ((0, True), (1, True), (0, False), (2, True), (3, False)):
    for obj in m.pool():
        m.cpu.mem_write(obj & 0xFFFFFF, bytes(m.s['object_size']))
    m.write('Current_Timezone', zone)
    m.act('ObjectsManager')
    assert bool(m.live()) == expected, (zone, expected, m.live())
    if expected:
        obj = next(iter(m.live().values()))
        assert m.get(obj, 'obSubtype') == 0xBEEF
        m.act('DeleteObject', obj)

# Word arithmetic in real handlers, including bit 8 of actual parameters.
for routine, subtype, field, expected in (
        ('FlapDoor', 0x101, 'flap_time', 0x101 * 60),
        ('Obj2C', 0x101, 'jaws_timedelay', 0x101 * 64 - 1)):
    m.start()
    obj = next(iter(m.pool()))
    m.put(obj, 'code', m.s[routine], 4)
    m.put(obj, 'obSubtype', subtype)
    m.put(obj, 'obX', 256, 2)
    m.put(obj, 'obY', 128, 2)
    m.act(routine, obj)
    assert m.get(obj, field, 2) == expected, (routine, m.get(obj, field, 2), expected)

# Debug records carry the same complete word, without touching adjacent fields.
m.start()
index = m.s['DebugList']
entry = index + struct.unpack('>h', bytes(m.cpu.mem_read(index, 2)))[0] + 2
m.cpu.mem_write(entry + m.s['DebugEntry_subtype'], struct.pack('>H', 0xCAFE))
m.write('v_jpadpress1', 1 << m.s['bitC'])
m.act('Debug_SpawnObject', 'v_player', {UC_M68K_REG_A2: entry})
spawned = [obj for obj in m.pool() if m.get(obj, 'code')]
assert len(spawned) == 1 and m.get(spawned[0], 'obSubtype') == 0xCAFE
assert not m.get(spawned[0], 'respawn_addr', 2)

# No live or WIP handler may silently access only one byte of the shared word.
for path in [ROOT / 'md-main.asm', *(ROOT / 'objects').rglob('*.asm'), *(ROOT / '_inc').rglob('*.asm')]:
    for number, line in enumerate(path.read_text(encoding='latin1').splitlines(), 1):
        code = line.split(';')[0]
        if 'obSubtype' in code:
            assert not re.search(r'\b\w+\.b\b|\b(?:btst|bset|bclr|bchg)\b', code), (path, number, code)

print(json.dumps({'fixed_MD_symbols': len(fixed), 'converted_placements': converted,
                  'era_mask_cases': time_cases, 'per_era_state': True,
                  'word_handler_parameters': True, 'word_debug_spawn': True,
                  'all_handler_accesses_are_words': True}, indent=2))
