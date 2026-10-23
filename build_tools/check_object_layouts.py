#!/usr/bin/env python3
"""Check S3&K placements, their assembled pointers, and manager/Debug RAM."""
import argparse
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parent.parent
SENTINEL = bytes.fromhex('FFFF00000000')
ZONES = ('GHZ', 'LZ', 'CPZ', 'EHZ', 'HPZ', 'HTZ', 'MTZ', 'LV07', 'SMZ', 'LV09', 'LV0A', 'LV0B',
         'LV0C', 'LV0D', 'LV0E', 'LV0F')


def check_named_sst_fields(symbols):
    """Check literal named SST operands; indexed/packed records need review.

    This is not register dataflow analysis. In particular, a pointer to an
    interior cache can legitimately use an odd displacement to reach an even
    word, as Points does. Only bare field(aN) operands are checked here.
    """
    constants = (ROOT / '_definitions/s2.constants.asm').read_text().split('; Animation flags')[0]
    names = set(re.findall(r'^\s*(\w+)\s*:?\s*(?:equ|=)\s*(?:\$[0-9A-Fa-f]+|\w+)',
                           constants, re.M))
    fields = {name: offset for name, offset in symbols.items()
              if name in names and 0 <= offset <= symbols['object_size']}
    count = 0
    sources = [ROOT / 'md-main.asm', *sorted((ROOT / 'objects').rglob('*.asm'))]
    for source in sources:
        text = source.read_text(encoding='latin1')
        local = fields.copy()
        aliases = re.findall(r'^\s*(\w+)\s*:?\s*(?:equ|=)\s*(\w+)\s*(?:;.*)?$', text, re.M)
        for _ in range(3):
            for name, value in aliases:
                if value in local:
                    local[name] = local[value]
        for line, text in enumerate(text.splitlines(), 1):
            instruction = re.match(r'\s*(?:\w+:\s*)?(?:[-+]\s*)?([a-zA-Z_]+)\.([bwl])\s+(.*)',
                                   text.split(';')[0])
            if not instruction:
                continue
            size = {'b': 1, 'w': 2, 'l': 4}[instruction[2]]
            for name in re.findall(r'(?<![\w+\-])\b(\w+)\(a[0-6]\)', instruction[3]):
                if name not in local:
                    continue
                count += 1
                offset = local[name]
                if instruction[1].lower() in ('lea', 'pea'):
                    continue
                assert offset + size <= symbols['object_size'], f'{source}:{line}: {name} crosses SST boundary'
                assert size == 1 or not offset & 1, f'{source}:{line}: odd word/long SST field {name}'
    print(f'Checked {count} named SST operands in all {len(sources)-1} object files and md-main.asm.')


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
    parser.add_argument('--listing', type=Path, default=ROOT / 'md-main.lst')
    args = parser.parse_args()
    listing = args.listing.read_text()
    assert 'Symbol Table' in listing, 'Build must finish before checking its listing'
    symbols = {name: int(value, 16) & 0xFFFFFF for name, value in re.findall(
        r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]', listing)}
    capacity = symbols['MCD_ObjectPlacementCount'] if 'MCD_SubObjects' in symbols else symbols['Object_Respawn_Table_end'] - symbols['Object_Respawn_Table']
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
    assert symbols['code'] == 0 and symbols['object_size'] == 0x4E
    # Legacy code sometimes addressed an SST base directly instead of obID.
    # Cover those absolute references as well as symbolic code(aN) accesses.
    constants = (ROOT / '_definitions/s2.constants.asm').read_text()
    slots = re.findall(r'^(v_\w+)\s*=\s*v_objspace(?:\+object_size\*\d+)?\b', constants, re.M)
    slots += ['v_objspace', 'v_lvlobjspace']
    # Include reserved-slot aliases, such as the seven result-card children.
    for _ in range(2):
        bases = '|'.join(map(re.escape, slots))
        slots += re.findall(r'^(v_\w+)\s*=\s*(?:' + bases + r')\+object_size\*\d+\b', constants, re.M)
        slots = sorted(set(slots))
    absolute = '|'.join(map(re.escape, slots))
    pointer = r'(?:\((?:' + absolute + r')(?:\+code)?\)|(?:code|obID)\(a[0-6]\))'
    narrow = re.compile(r'\b_?(?:movea?|cmpa?|cmpi|clr|tst|andi|ori|eori)\.[bw]\b[^;\n]*' + pointer)
    numeric_id = re.compile(r'\b_?(?:move|cmpi)\.l\s+#id_\w+\s*,\s*' + pointer)
    for source in [ROOT / 'md-main.asm', *(ROOT / 'objects').rglob('*.asm'), *(ROOT / '_inc').rglob('*.asm')]:
        for line, text in enumerate(source.read_text(errors='replace').splitlines(), 1):
            active = text.split(';')[0]
            assert not narrow.search(active), f'{source}:{line}: byte/word access to code pointer'
            assert not numeric_id.search(active), f'{source}:{line}: numeric placement ID used as a routine pointer'
    assert symbols['height_pixels'] == 6 and symbols['DebugEntry_size'] == 12
    assert symbols['v_lvlobjend'] - symbols['v_lvlobjspace'] == 90 * 0x4E
    assert symbols['TempArray_LayerDef' if symbols.get('MegaCDMode1') else 'v_16x16'] == symbols['v_objspace_end']
    assert symbols['v_16x16_End'] - symbols['v_16x16'] == 0x1800
    assert symbols['System_Stack_Start'] == symbols['Sprite_Table_end']
    assert symbols['v_systemstack'] - symbols['System_Stack_Start'] == 0x200
    scroll_end=symbols.get('v_ssbg_sines_end',symbols.get('v_ngfx_buffer_end'))
    assert symbols['Error_Handler_Buffer'] == symbols['v_regbuffer'] == scroll_end
    if 'v_ssbg_sines' in symbols:
        assert symbols['v_ssbg_sines_end']-symbols['v_ssbg_sines']==10*4
    assert symbols['Object_Display_Lists'] == symbols['Debug_saved_height'] + 1
    assert not symbols['Debug_saved_mappings'] & 1
    if symbols.get('MegaCDMode1'):
        assert symbols['Free_RAM_Start'] == symbols['RAM_Start']
        assert symbols['Free_RAM_End'] == symbols['MCD_MainWorkStart']
        assert symbols['Player_Art_Buffer_End'] == symbols['Main_RAM_Start']
        assert symbols['Main_RAM_Start'] & 0xFFFFFF >= 0xFF8000
        assert symbols['Main_RAM_End'] == 0
    assert symbols['Debug_placement_type'] == symbols['Debug_placement_routine'] + 1
    assert symbols['Debug_placement_mode'] == symbols['Debug_placement_routine']
    check_named_sst_fields(symbols)
    print(f'Checked {len(layouts)} S3&K layouts / {sum(n for _, n in layouts.values())} '
          f'placements, all 64 act pointers and Debug lists, and manager/Debug RAM.')


if __name__ == '__main__':
    main()
