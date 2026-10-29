#!/usr/bin/env python3
"""Translate editable Mode 1 foregrounds and their placed entities vertically.

Includes every era layout plus shared objects, packed ring groups and starts.
Only binary sources are changed: update camera/events, boss anchors, water and
editor water heights alongside them. Background coordinates stay independent.
Dry-run by default; --write applies only after validating every selected file.
"""
from pathlib import Path
import argparse
import json
import re
import struct
from level_layout import load, encode as encode_layout
from object_layout import decode as objects, encode as encode_objects
from convert_s1_ss_background import kosinski_plus

ROOT = Path(__file__).resolve().parents[1]


def translate(names, dy, start_file=None):
    if not dy or dy % 128:
        raise ValueError('Use a nonzero multiple of 128 pixels')
    changes = {}
    report = []
    if start_file is not None and len(names) != 1:
        raise ValueError('--start-file applies to one selected level')

    def y_position(y):
        value = (y & 0xFFF) + dy
        if not 0 <= value < 0x1000:
            raise ValueError(f'Y ${y & 0xFFF:03X} leaves the 4096-pixel world')
        return (y & 0xF000) | value

    for name in names:
        if not re.fullmatch(r'[A-Z0-9]+_[1-4]', name):
            raise ValueError('Expected a level stem such as EHZ_2')
        paths = sorted((ROOT/'level/layout').rglob(name+'.kosp'))
        if not paths:
            raise ValueError('Missing layouts for '+name)
        for path in paths:
            fg, bg = load(path)
            if dy > 0:
                moved = [[0]*len(fg[0]) for _ in range(dy//128)] + fg
            else:
                if any(any(row) for row in fg[:(-dy)//128]):
                    raise ValueError('Translation would discard foreground terrain')
                moved = fg[(-dy)//128:]
            changes[path] = bytes(kosinski_plus(encode_layout(moved, bg)))
        path = ROOT/f'level/objects/{name}.bin'
        rows = objects(path.read_bytes())
        changes[path] = encode_objects((x,y_position(y),oid,eras,sub) for x,y,oid,eras,sub in rows)
        path = ROOT/f'level/rings/{name}.bin'
        rings = list(struct.iter_unpack('>HH', path.read_bytes()))
        # MTZ1's empty ring source intentionally aliases the following sentinel.
        if rings and rings[-1] != (0xFFFF, 0):
            raise ValueError('Missing ring terminator: '+name)
        moved_rings = []
        for x, y in rings[:-1]:
            # High nibble retains orientation and count-minus-one. Columns
            # expand downward by 24 pixels per ring in RingsManager_Setup.
            last_y = (y & 0xFFF) + (((y >> 12) & 7)*24 if y & 0x8000 else 0)
            if not 0 <= last_y + dy < 0x1000:
                raise ValueError('Expanded ring column leaves the world: '+name)
            moved_rings.append((x, y_position(y)))
        changes[path] = b''.join(struct.pack('>HH', *row) for row in moved_rings + rings[-1:])
        path = ROOT/start_file if start_file is not None else ROOT/f'startpos/{name}.bin'
        x, y = struct.unpack('>HH', path.read_bytes())
        changes[path] = struct.pack('>HH', x, y_position(y))
        report.append(dict(level=name,dy=dy,era_layouts=len(paths),
                           objects=len(rows),ring_groups=max(0,len(rings)-1)))
    return changes, report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('levels', nargs='+')
    p.add_argument('--dy', type=lambda s:int(s,0), required=True)
    p.add_argument('--write', action='store_true')
    p.add_argument('--start-file', type=Path, help='Explicit source for a differently named start file')
    args = p.parse_args()
    changes, report = translate(args.levels, args.dy, args.start_file)
    if args.write:
        for path, data in changes.items():
            path.write_bytes(data)
    print(json.dumps(dict(applied=args.write,files=len(changes),levels=report),indent=2))


if __name__ == '__main__':
    main()
