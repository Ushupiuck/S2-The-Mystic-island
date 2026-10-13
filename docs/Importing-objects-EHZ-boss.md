# Importing objects: the Sonic 2 final EHZ boss

Placement ownership and the word `respawn_addr` interface are covered in
[S3&K object loading and Debug](S3-object-manager-and-debug.md).

The final EHZ boss is in `objects/55 EHZ Boss.asm`, adapted from
[s2disasm](https://github.com/sonicretro/s2disasm/tree/15e9fd52a65318bec3d5e746ce48dba6db6910db)
commit `15e9fd52a65318bec3d5e746ce48dba6db6910db`. It replaces the prototype
implementation previously spread across IDs `$55–$58` in `main.asm`.

## What changes when adding an object

1. Include its code and mappings through the normal `main.asm` include tree,
   and connect its entry point to the ID-based `Obj_Index`. Update placements
   or the event that creates it, as appropriate. Objects still have a `$4A`
   SST stride; use this project's named fields rather than source offsets.
2. Use S3&K mappings: word piece count, then six bytes per piece: signed byte
   Y, byte size, tile word, signed word X. S1 imports need their byte counts
   and five-byte pieces converted. S2 imports lose the second tile word used
   for 2P interlace. Ordinary S3&K mappings already have the correct format.
3. Initialize display bounds whenever selecting a mapping set, including in
   child constructors. Collision radii are separate and retain their original
   meaning. Use a word priority, with each priority tier spaced by `$80`.
4. Adapt allocation, animation, collision and deletion calls to this engine.
   Load static art through the normal PLCs. An object using dynamic art needs
   S3&K-format DPLCs and the corresponding loader; adding static mappings alone
   does not require a DPLC.

The boss's main ship provides a concrete initializer:

```asm
        move.l  #Map_EHZBoss_Vehicle,obMap(a0)
        move.b  #Map_EHZBoss_Vehicle_height,height_pixels(a0)
        move.b  #sprite_bound($20,Map_EHZBoss_Vehicle_width),width_pixels(a0)
        move.b  #$14,obHeight(a0)     ; stock collision radius: 20 pixels
        move.w  #$200,obPriority(a0) ; priority tier 4
```

`sprite_bound` evaluates the larger of the retained legacy half-width and the
mapping half-width at assembly time. It emits an immediate constant; there is
no function call. A newly authored object without a legacy minimum can assign
`Map_NewObject_width` directly. Set `height_pixels` at `$49` on the same object
whose mappings you set: child constructors using `a1` must initialize `a1`.
If an object switches between several mapping tables, update its bounds too
or use the maximum bounds across those tables.

## Where `Map_Object_height` comes from

Run the ordinary `build.lua`. Its `build_tools/lua/sprite_bounds.lua` pass walks
the included ASM sources, discovers `Map*_height`, `Map*_width` and
`Map*_frames` references, and assembles an intermediate image to resolve the
mapping pointers. It then reads the assembled pieces and regenerates
`_inc/Sprite Bounds.asm` before assembling the playable ROM.

**There is no mapping registration list.** Including the file and referring
to its bounds in the object initializer is sufficient. The convention is a
`Map`-prefixed label with `_height`, `_width` and `_frames` suffixes. ASM frame
tables use `dc.w FrameLabel-Map_Object`; binary tables may reorder or share
frames. Import conversion happens before this pass: it does not convert S1
or S2 files for you. A failed bounds pass restores the previous generated
file and does not replace the playable ROM.

For a piece with size byte `s`, its dimensions are:

```
width  = ((s >> 2) + 1) * 8
height = ((s & 3) + 1) * 8
```

The generated half-height is the maximum of `abs(Y)` and `abs(Y + height)`
over every piece in every frame. The half-width uses `X` and `X + width` the
same way. Symmetric extents also cover flipped sprites. No geometry scan runs
in `Render_Sprites`; each object stores the resulting byte once in its setup.

| Mapping | Frames | Half-width | Half-height |
| --- | ---: | ---: | ---: |
| `Map_EHZBoss_Vehicle` | 7 | `$20` / 32 | `$28` / 40 |
| `Map_EHZBoss_Ground` | 8 | `$30` / 48 | `$10` / 16 |
| `Map_EHZBoss_Propeller` | 7 | `$52` / 82 | `$28` / 40 |
| `Map_BossExplosion` | 7 | `$10` / 16 | `$10` / 16 |

For example, the propeller has pieces at Y = -40, giving a 40-pixel vertical
extent. Frame 1 includes a piece at X = 50 with size `$0D`: it is 32 pixels
wide, so its right edge reaches 82. That exceeds the old `$40` half-width;
`sprite_bound($40,Map_EHZBoss_Propeller_width)` automatically becomes `$52`.
Editing that mapping and rebuilding updates the value without editing an
object-specific size table. The ship's 40-pixel display extent similarly
remains independent of its 20-pixel collision radius.

## Children and packed subsprites

Sonic 2 final's EHZ boss uses **eight linked ordinary SST slots**, all with
the same boss ID: ship bottom (controller), cockpit, car, three wheels, drill
and propeller. Their routine selects the role; `objoff_34` links them to their
parent, with a reciprocal controller/cockpit link. Each child receives its own
mappings, art, bounds and priority and queues through `DisplaySprite`.
The port retries initialization until all seven child slots are available.
It preserves the stock eight-hit fight, hurt/laughter/escape animations,
terrain-following wheels and drill separation.

This differs from a packed composite such as the bridge or invincibility
stars. Those use a header containing main frame, group half-width at `$0E`,
byte child count at `$0F`, six-byte child records from `$10`, and group
half-height at `$49`. The header's bounds must cover the positions of the
moving children, not just the geometry of one child frame. Derive that extent
from the movement range or update it when building the group. A mapping-only
constant cannot infer runtime child positions. Use `DisplaySprite3` when packed
records occupy the ordinary priority field, as the star object does.

No renderer special case or ID check is needed for either arrangement. The
rotating S1 special-stage grid keeps its existing dedicated S1-format loader;
these ordinary object imports do not change its ABI.

## Arena and art lifetime

EHZ2 locks the camera X range to `$28F0–$2940` and Y to `$390`. Both vertical
approaches settle through normal row streaming before the boss spawns. The
limits remain enforced after debug entry/exit and are mirrored for Tails.
After defeat, the stock escape extends the right limit to `$2AB0`; the level
continues to the capsule rather than returning to the Sega screen.

| VRAM interval, end exclusive | Art |
| --- | --- |
| `$7400–$8000` | Ship, 96 tiles |
| `$8000–$9000` | Car, wheels and drill, 128 tiles |
| `$9000–$9280` | Propeller, 20 tiles |
| `$A100–$ABA0` | Capsule, 85 tiles; queued at defeat |
| `$B000–$BC80` | Large boss explosion, 100 tiles |

These banks coexist with the shared shield/star bank at `$F380`, the auxiliary
shield bank at `$ADC0`, the planes, players and HUD. General level-object
art, including monitors, spikes and springs, can be overwritten during the
boss/capsule phases. Animals and normal explosion art replace the
large-explosion bank only after the defeat timer finishes. Regular explosion
art starts at `$B040`, with animal banks at `$BC00` and `$BE40`. The existing S1
capsule needs separate body/button placement records, now present in EHZ2.
The boss can also use the existing MZ placeholder's position: origin deltas at
`$40/$42` translate the stock movement/escape coordinates without growing SSTs.

Final Zone's look-up strip was a separate initialization error in the shared
streamer. Fixed `$1010` crossing flags assumed an origin aligned to that bit;
at its nonzero start Y, the first upward row update was skipped. Initialization
now derives the opposite of bit 4 from each actual starting camera coordinate.

## Checks

After building, run:

```sh
python build_tools/check_sprite_bounds.py
python build_tools/check_sprite_assets.py
python build_tools/check_ehz_boss.py
# Optional: build the pinned Sonic 2 checkout first, then compare its mappings.
python build_tools/check_ehz_boss.py --s2disasm /path/to/s2disasm
```

The boss check validates all converted frame geometry and art indices, protects
simultaneous VRAM banks, and checks the capsule's six-byte placement records.
Native 68000 comparison covered 4,276 frames against unmodified Sonic 2 final,
including flat/stepped ground, both facing directions, eight hits, defeat and
escape, plus allocation pressure and relocated origins. Genesis Plus GX tests
under NTSC and PAL covered the fight, escape, capsule button collision, animals
and act clear. Debug entry from above/below and Final Zone look up/down/return
also checked visible foreground VRAM against the live block/chunk data.
