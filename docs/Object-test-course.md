# LZ2 object regression course

The disposable course uses the S3&K manager, real renderer and ordinary
Nemesis/Kosinski/DMA pipelines. The builder copies the checkout to the output
directory, adds test hooks there and assembles that copy. The normal ROM keeps
its existing LZ2 layout, placements, VRAM allocations and level events.

There are 57 sorted S3 placements in sixteen `$400`-pixel sections, over a flat
floor using an existing LZ collision block. Dynamic events switch each section's
art lists. The scripts position the player; collisions, damage, pickups,
animations, spawning and deletion run in the ROM. These are representative
behavior/lifecycle checks, not every subtype combination or a manual playthrough.

| Section | Contents |
| --- | --- |
| `$0000` | Rings, monitors, checkpoint, bubble maker; persistent water/effect art |
| `$0400` | Up/side/diagonal springs, floor/ceiling spikes |
| `$0800` | Morphing platform, vertical/horizontal path switches, spiral |
| `$0C00` | Hanging platform, multipart bridge, descending lift |
| `$1000` | Moving/CPZ/collapsing/tilting platforms |
| `$1400` | Tall waterfall, bridge stump, rock, animated orb |
| `$1800` | Collapsing floor, smashable wall, small door, edge wall |
| `$1C00` | Moto Bug, Crabmeat, both Ball Hog families |
| `$2000` | Buzz Bomber, Newtron, Chopper/Masher |
| `$2400` | Caterkiller, Basaran |
| `$2800` | Buzzer, Snailbot, Splats |
| `$2C00` | BBat, Rhinobot, gator |
| `$3000` | Jaws, Piranha, Aquis |
| `$3400` | Octus, Skyhorse |
| `$3800` | Bumper, seesaw and ball, flapdoor |
| `$3C00` | Hidden bonus, signpost, successive giant rings |

Course-only banks let prototype enemies and the water surface coexist.
The restored S3&K bubbles use their normal `$45C–$493` tile bank, and splash
and numbers stream into the normal player dust banks. Surface art uses
`$294–$2AB`. Aquis/Piranha/Octus use temporary slots; the fixed player, ring,
HUD, explosion and water-effect banks retain their gameplay addresses.

The legacy wall still uses `$590`, inside explosion art. Its isolated structure
section loads wall art there; fresh snapshots restore explosion art for the
enemy/effect tests. This does not validate that wall allocation for a populated
gameplay level.

Two small S1 art files are bundled solely for this test build, with source
commit and hashes in `build_tools/object_course_art/sources.json`. The floor uses
SBZ's four tiles with the shared S1 mappings. Appearance uses LZ's palettes; this
does not certify each zone's intended colors.

## Reproduce

Supply a Genesis Plus GX libretro shared library; the optional Python runner
uses its exported RAM/VRAM and serialization APIs. Python requires NumPy/Pillow.
Build output must be outside the checkout.

```sh
python build_tools/build_object_course.py --output /tmp/mystic-object-course
python build_tools/check_object_course.py --build /tmp/mystic-object-course --core /path/to/genesis_plus_gx_libretro.so --output /tmp/mystic-object-sweep
python build_tools/check_object_interactions.py --build /tmp/mystic-object-course --core /path/to/genesis_plus_gx_libretro.so --output /tmp/mystic-object-contacts
python build_tools/check_object_contexts.py --build /tmp/mystic-object-course --core /path/to/genesis_plus_gx_libretro.so --output /tmp/mystic-stage --case stage
python build_tools/check_object_contexts.py --build /tmp/mystic-object-course --core /path/to/genesis_plus_gx_libretro.so --output /tmp/mystic-warp --case warp --player 2
```

`--pal --player 2` selects primary Tails in PAL for the sweep/contacts. `--bank N`
narrows the sweep; `--filter REGEX` narrows contacts. Reports/screenshots go in
the chosen output directories. Instrumentation records executed IDs in retired
respawn RAM at the actual routine entry points, rather than indexing a
routine pointer as if it were a byte ID. Fixtures use `layout_id` only as a
test-side projection; real SSTs store `code` longwords. Its cost makes this ROM unsuitable for performance profiling.

## Findings and coverage

The course reproduced three bugs, now fixed in gameplay sources:

- The closed SBZ small door fell into animation bytes after `SolidObject`,
  crashing the CPU. It now returns through `MarkObjGone`.
- Collection copied the small-ring clock into the giant ring's mapping frame.
  Its single mapping frame animates through VRAM art replacement; phases 1–7
  could interpret sprite pieces as offsets. Removing that write fixes successive
  entry crashes without another art allocation.
- The prototype warp always restored Sonic's ID. It now restores the primary
  character using `PlayerMode_Tails`.

Native regressions render collected giant rings at all eight small-ring phases,
restore both warp identities, and check unused visibility-helper boundaries.
Existing manager, Debug, bounds, DPLC and VRAM checks also pass. The
[per-file matrix](Object-course-coverage.md) and
[recorded results](Object-course-results.json) show actual coverage.

GHZ/EHZ boss tests use their normal arenas: eight real collision hits, defeat,
animal release and act-clear for both primary players in both regions. One
Tails fixture originally teleported him inside the capsule and correctly
crushed him; waiting beside it fixes the fixture. Screen-specific stage/result
objects use their own mode, including all six emeralds and return to gameplay.
All four active attract demos finish in both regions; intentional desync and
the longer 1,800-frame timer remain as supplied.

The conveyor remains excluded as requested. The gator passes lifecycle checks,
but its known broken gameplay remains. Nine W.I.P/Unused files are not included
in the ROM; seven empty sources have no implementation. The title palette
handler is compiled but unfinished and not spawned: its data setup and update
entry are absent. These are recorded explicitly. Horizontal spike art bank
switching stays on its separate TODO.
