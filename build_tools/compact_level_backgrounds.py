#!/usr/bin/env python3
"""Reduce old workaround backgrounds to one complete span; report unless --write.

Trims outer empty padding, then redundant copies of the remaining rectangle.
Use deliberately: authored empty margins can be meaningful in a new design.
SonLVL and normal builds retain the dimensions the author saves.
"""
from pathlib import Path
import argparse
from level_layout import load, save, compact_background

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('paths', nargs='*', type=Path, help='Defaults to all current level/layout/*.kosp, including eras')
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    paths = args.paths or sorted((ROOT/'level/layout').rglob('*.kosp'))
    files = saved = 0
    for path in paths:
        fg, bg = load(path)
        compact = compact_background(bg)
        if compact == bg:
            continue
        old, new = (len(bg[0]), len(bg)), (len(compact[0]), len(compact))
        print(f'{path.relative_to(ROOT) if path.is_absolute() else path}: {old} -> {new}')
        if args.write:
            save(path, fg, compact)
        files += 1
        saved += (old[0]*old[1]-new[0]*new[1])*2
    print(f'{files} backgrounds; {saved:,} decoded cell bytes removed' + ('.' if args.write else ' (dry run).'))


if __name__ == '__main__':
    main()
