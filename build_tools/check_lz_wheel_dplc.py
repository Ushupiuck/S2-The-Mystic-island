#!/usr/bin/env python3
"""Execute the shared conveyor-wheel clock/DPLCs, including DMA backpressure."""
import argparse
import json
from pathlib import Path

import native_test_core as c
from convert_s1_ss_background import kosinski_plus_decode

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--rom', type=Path)
p.add_argument('--listing', type=Path)
p.add_argument('--output', type=Path)
args = p.parse_args()
m = c.Manager(args.rom, args.listing)
sheet = (c.ROOT / 'art/moduled kosinski/LZ conveyor.unc').read_bytes()
resident = kosinski_plus_decode((c.ROOT / 'art/moduled kosinski/LZ conveyor.kospm').read_bytes(), 2)[0]
assert resident == sheet[:512] + sheet[2048:]
assert len(resident) == 32 * 32
assert m.s['ArtTile_LZ_Conveyor_Belt_End'] - m.s['ArtTile_LZ_Conveyor_Belt'] == 32
assert bytes(m.cpu.mem_read(m.s['Art_LConWheels'], 2048)) == sheet[:2048]
destination = m.s['ArtTile_LZ_Conveyor_Belt'] * 32
checks = []


def uploads():
    # Source is a long; the queue ABI consumes destination/length words.
    return [(source, dest & 65535, length & 65535) for source, dest, length in m.uploads]


def fixture(count):
    m.start()
    objects = list(m.pool())[:count]
    m.write('Camera_X_pos_coarse_back', 0xF00, 2)
    for i, obj in enumerate(objects):
        m.put(obj, 'code', m.s['LabyrinthConvey'])
        m.put(obj, 'obSubtype', 0x7F)
        m.put(obj, 'obX', 0x1000 + (i % 10) * 16, 2)
        m.put(obj, 'obY', 0x200 + (i // 10) * 24, 2)
        m.act('LabyrinthConvey', obj)
    m.act('LCon_ResetWheels')
    m.uploads.clear()
    return objects


for count in (1, 70):
    objects = fixture(count)
    expected = 0
    total = 0
    for tick in range(32):
        m.write('v_framecount', tick, 2)
        m.write('f_conveyrev', int(tick >= 16))
        m.uploads.clear()
        if tick % 4 == 0:
            expected = (expected + (-1 if tick >= 16 else 1)) & 3
        for obj in objects:
            m.act('LCon_Wheel', obj, {c.UC_M68K_REG_D7: 0x12345678})
            assert m.cpu.reg_read(c.UC_M68K_REG_D7) == 0x12345678
            assert m.cpu.reg_read(c.UC_M68K_REG_A0) & 0xFFFFFF == obj & 0xFFFFFF
            assert m.get(obj, 'obFrame') == 0
        assert m.read('v_lcon_wheel_frame') == expected
        assert m.read('v_lcon_wheel_artframe') == expected
        expected_upload = [(m.s['Art_LConWheels'] + expected * 512, destination, 256)] if tick % 4 == 0 else []
        assert uploads() == expected_upload, (count, tick, uploads(), expected_upload)
        total += len(m.uploads)
    assert total == 8
    checks.append([count, 'wheels', total, 'uploads over 32 frames, including reversal'])

# Full/near-full queues must cache no partial frame. Even after space becomes
# available, another wheel in this same object pass must not retry the upload.
objects = fixture(70)
end = m.s['VDP_Command_Buffer_Slot'] & 65535
m.write('v_framecount', 1, 2)
m.write('VDP_Command_Buffer_Slot', end - m.s['DMAEntry.len'], 2)
for obj in objects:
    m.act('LCon_Wheel', obj)
assert not m.uploads and m.read('v_lcon_wheel_artframe') == 255
m.write('VDP_Command_Buffer_Slot', 0, 2)
m.act('LCon_Wheel', objects[0])
assert not m.uploads
m.write('v_framecount', 2, 2)
m.act('LCon_Wheel', objects[0])
assert uploads() == [(m.s['Art_LConWheels'], destination, 256)]
assert m.read('v_lcon_wheel_artframe') == 0
checks.append(['DMA pressure', 'atomic failure, once-per-frame gate, next-frame retry'])

# The timestamp is a word and must distinguish the first frame after wrapping.
objects = fixture(1)
for tick in (0xFFFC, 0xFFFD, 0xFFFE, 0xFFFF, 0, 1, 2, 3):
    m.write('v_framecount', tick, 2)
    m.act('LCon_Wheel', objects[0])
assert len(m.uploads) == 2 and m.read('v_lcon_wheel_frame') == 2
m.act('LCon_ResetWheels')
assert m.read('v_lcon_wheel_frame') == 0
assert m.read('v_lcon_wheel_artframe') == 255
assert m.read('v_lcon_wheel_updated') == 0
checks.append(['frame wrap and level-entry cache reset'])

report = {'resident_tiles': 32, 'saved_tiles': 48, 'saved_vram_bytes': 1536, 'checks': checks}
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
print(report)
