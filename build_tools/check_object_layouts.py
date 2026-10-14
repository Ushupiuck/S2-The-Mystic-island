#!/usr/bin/env python3
"""Check S3&K placements, their assembled pointers, and manager/Debug RAM."""
import argparse
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parent.parent
SENTINEL = bytes.fromhex('FFFF00000000')
ZONES = ('GHZ', 'LZ', 'CPZ', 'EHZ', 'HPZ', 'HTZ', 'MTZ')


def placements(path, capacity):
    data = path.read_bytes()
    assert len(data) >= 6 and len(data) % 6 == 0, f'{path.name}: incomplete record'
    assert data[-6:] == SENTINEL, f'{path.name}: missing terminator'
    rows = list(struct.iter_unpack('>HHBB', data[:-6]))
    assert len(rows) <= capacity, f'{path.name}: respawn table overflow'
    last_x = 0
    for x, y, object_id, subtype in rows:
        assert last_x <= x < 0xFFFF, f'{path.name}: unordered X or interior terminator'
        assert not y & 0x1000, f'{path.name}: reserved Y flag set'
        assert object_id != 0, f'{path.name}: empty object ID'
        last_x = x
    return data, len(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', type=Path, default=ROOT / 's2built.bin')
    parser.add_argument('--listing', type=Path, default=ROOT / 'main.lst')
    args = parser.parse_args()
    listing = args.listing.read_text()
    assert 'Symbol Table' in listing, 'Build must finish before checking its listing'
    symbols = {name: int(value, 16) & 0xFFFFFF for name, value in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', listing)}
    capacity = symbols['Object_Respawn_Table_end'] - symbols['Object_Respawn_Table']
    assert capacity == 0x300
    layouts = {path.name: placements(path, capacity)
               for path in sorted((ROOT / 'level/objects').glob('*.bin'))}
    rom = args.rom.read_bytes()
    index = symbols['ObjPos_Index']
    debug = symbols['DebugList']
    for zone, name in enumerate(ZONES):
        for act in range(4):
            offset = zone * 8 + act * 2
            address = index + struct.unpack_from('>h', rom, index + offset)[0]
            data, _ = layouts[f'{name}_{act + 1}.bin']
            assert address == symbols[f'ObjPos_{name}{act + 1}']
            assert rom[address - 6:address] == SENTINEL, 'Missing backward boundary'
            assert rom[address:address + len(data)] == data
            debug_address = debug + struct.unpack_from('>h', rom, debug + offset)[0]
            count = struct.unpack_from('>H', rom, debug_address)[0]
            assert 0 < count <= 255, 'Debug list must fit Debug_object'
            for entry in range(count):
                code, mapping = struct.unpack_from('>II', rom,
                    debug_address + 2 + entry * symbols['DebugEntry_size'])
                assert code and not code & 1 and code < len(rom), 'Bad Debug code pointer'
                assert mapping < len(rom), 'Bad Debug mapping address'
    assert symbols['omSize'] == 6
    assert symbols['respawn_addr'] == 0x22
    assert symbols['code'] == 0 and symbols['object_size'] == 0x50
    assert symbols['height_pixels'] == 6 and symbols['DebugEntry_size'] == 12
    assert symbols['v_lvlobjend'] - symbols['v_lvlobjspace'] == 90 * 0x50
    assert symbols['v_16x16'] == 0xFFC350
    assert symbols['Error_Handler_Buffer'] == symbols['v_regbuffer'] == 0xFFE710
    assert symbols['Object_Display_Lists'] == 0xFFE8C0
    assert symbols['Free_LegacyObjectState_end'] == symbols['Object_Display_Lists']
    assert symbols['Free_LegacyObjectState_end'] - symbols['Free_LegacyObjectState'] == 0x162
    assert not symbols['Debug_saved_mappings'] & 1
    assert symbols['Debug_saved_height'] + 1 == symbols['Free_LegacyObjectState']
    assert symbols['Debug_placement_type'] == symbols['Debug_placement_routine'] + 1
    assert symbols['Debug_placement_mode'] == symbols['Debug_placement_routine']
    print(f'Checked {len(layouts)} S3&K layouts / {sum(n for _, n in layouts.values())} '
          f'placements, all 28 act pointers and Debug lists, and manager/Debug RAM.')


if __name__ == '__main__':
    main()
