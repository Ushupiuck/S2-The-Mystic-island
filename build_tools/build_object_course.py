#!/usr/bin/env python3
"""Build a disposable LZ2 object course without changing the gameplay sources.

The course uses real S3 placements, the real manager, renderer and PLC queues.
Only this copied build gets a flat floor, the course placements/art banks, and
an object execution coverage array in retired respawn RAM. No object code is
stubbed. Run with --output /absolute/path, then check_object_course.py.
"""
from pathlib import Path
import argparse
import json
import re
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
COURSE = ROOT / 'build_tools/object_course.json'


def replace_once(text, before, after):
    if text.count(before) != 1:
        raise ValueError(f'Course hook changed: {before[:100]!r}')
    return text.replace(before, after, 1)


def instrument_entries(root):
    """Stamp real routine entries without adding an ID lookup to RunObject."""
    main = root / 'main.asm'
    text = main.read_text()
    entries = {}
    for oid, label in re.findall(r'^ptr_Obj([0-9A-F]{2}):\s*dc\.l\s+(\w+)', text, re.M):
        if label != 'ObjNull':
            entries.setdefault(label, []).append(int(oid, 16))
    files = [main] + [root / name for name in re.findall(
        r'^\s*include\s+"(objects/[^"]+\.asm)"', text, re.M)]
    seen = set()
    for path in files:
        text = path.read_text(encoding='latin1')
        for label, ids in entries.items():
            pattern = r'^' + re.escape(label) + r':[ \t]*([^\n]*)\n'
            def hook(match):
                seen.add(label)
                stamps = ''.join('\tmove.b #1,(ObjectTest_Executed+$%02X).w\n' % oid
                                 for oid in ids)
                suffix = match[1]
                return label + ':\n' + stamps + ('\t' + suffix + '\n' if suffix else '')
            text, count = re.subn(pattern, hook, text, flags=re.M)
            assert count <= 1, (path, label)
        path.write_text(text, encoding='latin1')
    assert seen == entries.keys(), ('Missing coverage entry', entries.keys()-seen)


def generate(root, banks):
    records = []
    asm = ["; Generated test-only LZ2 course. Not included by normal builds.",
           "ObjectTest_Executed = Free_LegacyObjectState",
           "ObjectTest_Bank = ObjectTest_Executed+$100",
           "ObjectTest_Active = ObjectTest_Bank+1",
           "ObjectTest_Enable = ObjectTest_Bank+2",
           "\tif ObjectTest_Enable+1>Free_LegacyObjectState_end",
           "\t\tfatal \"Object course coverage exceeds the free RAM area.\"",
           "\tendif",
           "ObjectTest_FloorY = $500",
           "ObjectTest_Initialize:",
           "\tmove.b #1,(ObjectTest_Active).w",
           "\tmove.b #1,(ObjectTest_Enable).w",
           "\tmove.b #$FF,(ObjectTest_Bank).w",
           "\tlea (v_lvllayout).w,a1",
           "\tmove.w #$1000/4-1,d0",
           ".clear_layout: clr.l (a1)+",
           "\tdbf d0,.clear_layout",
           "\tlea (v_128x128).l,a1",
           "\tmoveq #$80/4-1,d0",
           ".clear_chunk: clr.l (a1)+",
           "\tdbf d0,.clear_chunk",
           "\tlea (v_128x128+$FF*$80).l,a1",
           "\tmoveq #$80/2-1,d0",
           ".floor_chunk: move.w #$F001,(a1)+ ; existing LZ flat block, both paths solid",
           "\tdbf d0,.floor_chunk",
           "\tlea (v_lvllayout+(ObjectTest_FloorY/$80)*$100).w,a1",
           "\tmoveq #16-(ObjectTest_FloorY/$80)-1,d1",
           ".row: moveq #$80/4-1,d0",
           ".fill: move.l #$FFFFFFFF,(a1)+",
           "\tdbf d0,.fill",
           "\tlea $80(a1),a1 ; skip background half-row",
           "\tdbf d1,.row",
           "\trts",
           "ObjectTest_Dynamic:",
           "\ttst.b (ObjectTest_Enable).w",
           "\tbeq.s .return",
           "\tmove.w (Camera_X_pos).w,d0",
           "\tlsr.w #8,d0",
           "\tlsr.w #2,d0 ; $400 bytes of horizontal course per art bank",
           "\tandi.w #$F,d0",
           "\tcmp.b (ObjectTest_Bank).w,d0",
           "\tbeq.s .return",
           "\tmove.b d0,(ObjectTest_Bank).w",
           "\tlsl.w #2,d0",
           "\tmove.l d0,-(sp)",
           "\tjsr (ClearPLC).l",
           "\tmove.l (sp),d0 ; ClearPLC's DBF leaves d0.w = $FFFF",
           "\tlea ObjectTest_NemLists(pc),a1",
           "\tmovea.l (a1,d0.w),a1",
           "\tbsr.w ObjectTest_LoadNem",
           "\tmove.l (sp)+,d0",
           "\tlea ObjectTest_KosLists(pc),a1",
           "\tmovea.l (a1,d0.w),a6",
           "\tjsr (QuickKosPLC).l",
           "\tmoveq #0,d0",
           "\tmove.b (ObjectTest_Bank).w,d0",
           "\tlsl.w #2,d0",
           "\tlea ObjectTest_RawLists(pc),a1",
           "\tmovea.l (a1,d0.w),a4",
           ".raw: move.l (a4)+,d1",
           "\tbeq.s .return",
           "\tmove.w (a4)+,d2",
           "\tmove.w (a4)+,d3",
           "\tjsr (QueueDMATransfer).l",
           "\tbra.s .raw",
           ".return: rts",
           "ObjectTest_LoadNem:",
           "\tmovem.l a1-a2,-(sp) ; Raw is the tail entry after LoadPLC's save",
           "\tjmp (LoadPLC_Raw).l"]
    for fmt in ('Nem', 'Kos', 'Raw'):
        asm.append(f'ObjectTest_{fmt}Lists:')
        asm.extend(f'\tdc.l ObjectTest_{fmt}{i}' for i in range(16))
    for i, bank in enumerate(banks):
        base = i * 0x400
        for obj in bank['objects']:
            y = obj.get('y', 0x4C0) | obj.get('flags', 0)
            x = base + obj['x']
            records.append((x, y, int(obj['id'], 16), obj.get('subtype', 0)))
            obj.update(bank=i, world_x=x, world_y=y & 0xFFF, index=len(records)-1)
        for fmt in ('Nem', 'Kos', 'Raw'):
            entries = [a for a in bank.get('art', []) if a[0] == fmt.lower()]
            asm.append(f'ObjectTest_{fmt}{i}:')
            if fmt == 'Nem':
                asm.append(f'\tdc.w {len(entries)-1}')
                asm.extend(f'\tplcm {a[1]},{a[2]}' for a in entries)
            elif fmt == 'Kos':
                asm.append(f'\tdc.w {len(entries)-1}')
                asm.extend(f'\tdc.l {a[1]}\n\tdc.w ({a[2]})*32' for a in entries)
            else:
                asm.extend(f'\tdc.l {a[1]}\n\tdc.w ({a[2]})*32,{a[3]}/2' for a in entries)
                asm.append('\tdc.l 0')
    placements = ['ObjectTest_Placements:']
    placements.extend(f'\tdc.w ${x:04X},${y:04X}\n\tdc.b ${oid:02X},${sub:02X}'
                      for x,y,oid,sub in sorted(records))
    placements.append('\tdc.w $FFFF,0,0')
    (root / '_inc/Object Test Placements.asm').write_text('\n'.join(placements)+'\n')
    asm.extend([
                'ObjectTest_DoorArt: binclude "build_tools/object_course_art/door.nem"',
                '\teven',
                'ObjectTest_FloorArt: binclude "build_tools/object_course_art/floor.nem"',
                '\teven',
                'ObjectTest_LZArt: binclude "art/kosinski/level/8x8 - LZ.unc"',
                'ObjectTest_GHZArt: binclude "art/kosinski/level/8x8 - GHZ.unc"',
                'ObjectTest_CPZArt: binclude "art/kosinski/level/8x8 - CPZ.unc"',
                '\teven'])
    (root / '_inc/Object Test Course.asm').write_text('\n'.join(asm)+'\n')
    return banks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error('--output must be outside the checkout (the builder copies it)')
    output.mkdir(parents=True, exist_ok=True)
    root = output / 'source'
    if root.exists():
        shutil.rmtree(root)
    shutil.copytree(ROOT, root, ignore=shutil.ignore_patterns(
        '.git', '*.lst', 's2built*.bin', '*-pass.bin', '__pycache__'))
    banks = generate(root, json.loads(COURSE.read_text())['banks'])
    mainfile = root/'main.asm'
    source = mainfile.read_text()
    source = replace_once(source, 'LevelLayoutLoad:\n', 'LevelLayoutLoad:\n'
        '\t\tcmpi.w #$0101,(Current_ZoneAndAct).w\n'
        '\t\tbne.s +\n\t\tjmp (ObjectTest_Initialize).l\n+\n')
    source = replace_once(source, 'DynResize_LZ2:\n\t\trts',
                          'DynResize_LZ2:\n\t\tjmp (ObjectTest_Dynamic).l')
    source = replace_once(source, 'ObjPos_LZ2:\tbinclude\t"level/objects/LZ_2.bin"',
                          'ObjPos_LZ2:\tinclude "_inc/Object Test Placements.asm"')
    source = replace_once(source, 'RingPos_LZ2:\tbinclude\t"level/rings/LZ_2.bin"',
                          'RingPos_LZ2:\tdc.w $FFFF,0')
    source = replace_once(source, '\t\tbinclude\t"startpos/LZ_2.bin"\t; LZ2',
                          '\t\tdc.w $80,$4ED\t; test-course LZ2')
    source = replace_once(source, 'EndOfRom:\n',
                          '\t\tinclude "_inc/Object Test Course.asm"\nEndOfRom:\n')
    mainfile.write_text(source)
    instrument_entries(root)
    # These prototype water enemies still use old banks which overlap today's
    # universal assets. Relocate their art only in the disposable course ROM.
    constants = root/'_definitions/s2.constants.asm'
    text = constants.read_text()
    for symbol, value in [('ArtTile_BFish', '$400'), ('ArtTile_Aquis', '$350'),
                          ('ArtTile_Aquis_Child', '$390'), ('ArtTile_Octus','$440'),
                          ('ArtTile_Water_Surface','$294'),
                          ('ArtTile_Splats','$418')]:
        text, count = re.subn(r'('+symbol+r':\s*equ\s+)[^;\n]+',r'\g<1>'+value+' ',text)
        assert count == 1, symbol
    constants.write_text(text)
    # Give the diagnostic image its own output names, and never accept an old
    # gameplay ROM paired with fresh placement metadata/listing.
    build=root/'build.lua'
    script=build.read_text().replace('"s2built"','"object-course"').replace('"s2built.bin"','"object-course.bin"')
    script=script.replace('common.build_rom("main", "object-course", "",',
                          'common.build_rom("main", "object-course", "-OLIST object-course.lst",')
    build.write_text(script)
    for name in ('object-course.bin','object-course.lst'):
        (root/name).unlink(missing_ok=True)
    # Run executable copies outside the checkout. This also avoids changing
    # tracked binary modes or having a workspace sync reset them between passes.
    with tempfile.TemporaryDirectory(prefix='mystic-object-tools-') as directory:
        tools = Path(directory)
        shutil.copytree(root/'build_tools/Linux-x86_64', tools, dirs_exist_ok=True)
        for name in ('asl', 'p2bin'):
            (tools/name).chmod(0o755)
        common = root/'build_tools/lua/common.lua'
        script = common.read_text()
        hook = '\tlocal platform_directory, executable_suffix = get_platform_specific_info_memoised()\n'
        script = replace_once(script, hook, hook + '\tplatform_directory = "' + tools.as_posix() + '/"\n')
        common.write_text(script)
        result = subprocess.run(['texlua','build.lua'],cwd=root,capture_output=True,text=True)
    (output/'build.log').write_text(result.stdout+result.stderr)
    if result.returncode or not (root/'object-course.lst').exists() or 'Symbol Table' not in (root/'object-course.lst').read_text():
        raise SystemExit(f'Build failed; see {output}/build.log')
    symbols={n:int(v,16) for n,v in re.findall(r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',(root/'object-course.lst').read_text())}
    image=(root/'object-course.bin').read_bytes()
    expected=b''.join(struct.pack('>HHBB',o['world_x'],o.get('y',0x4C0)|o.get('flags',0),
                       int(o['id'],16),o.get('subtype',0)) for b in banks for o in b['objects'])+bytes.fromhex('FFFF00000000')
    base=symbols['ObjPos_LZ2']
    assert image[base:base+len(expected)]==expected,'Built ROM does not match course placements'
    assert len(image)>=symbols['EndOfRom'],'Built ROM does not match its listing extent'
    for name in ('object-course.bin','object-course.lst'):
        shutil.copyfile(root/name,output/name)
    (output/'course.json').write_text(json.dumps({'banks':banks},indent=2)+'\n')
    print(f'Object course: {output}/object-course.bin ({sum(len(b["objects"]) for b in banks)} placements)')


if __name__ == '__main__':
    main()
