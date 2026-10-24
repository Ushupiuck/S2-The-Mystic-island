# Levels, act configuration and assets

The level select exposes zones `$00-$0F`, four acts each, over two pages.
NEXT/PREVIOUS sits above SOUND TEST. Directions select entries, A/B/START
activates, and C cycles Sonic & Tails, Sonic, and Tails. Starter acts have valid
data and goals; they remain level-design templates.

| ID | Name | Current content |
| --- | --- | --- |
| 00 | Twilight Hill | GHZ-based acts |
| 01 | Rustic Ruins | LZ-based acts |
| 02 | Ancient Workbench | CPZ-based acts |
| 03 | Emerald Hill | EHZ-based acts |
| 04 | Crystal Valley | HPZ-based acts |
| 05 | Egg Mountain | HTZ-based acts |
| 06 | Metropolis | Unfinished act 1, starters 2-4 |
| 07 | Shocking Blizzard | Starters; final ice assets/layouts unfinished |
| 08 | Scrap Madness | S1 SBZ acts 1/2, starters 3/4 |
| 09 | Death Egg | Starters; final space assets/layouts unfinished |
| 0A | LEVEL 0A | Starters; act 1 tests PP enemies, wheel and propeller |
| 0B-0F | LEVEL 0B-0F | Starters |

All 64 act entries have headers, placements, starts, bounds, collision,
cards, Debug lists and progression. SonLVL has matching present-day sections.
Timezone headers/layouts are prepared copies. Object placements have Sonic CD
era-presence masks and per-era state; time travel and generator/Good Future
suppression remain unfinished. See [placement ownership](Objects.md#placement-format-and-ownership).

## Per-act art

`_inc/Pattern Load Cues.asm` contains the pointer table, IDs, and separate
Nemesis Main/Extra lists for all 64 acts, including starter slots.
Each has an independent **unsigned-byte** ID; IDs above `$7F` are valid.
The four `LevelHeaders*.asm` tables choose act IDs independently.

Edit the desired act's `plcm ArtLabel, ArtTile_Destination` entries directly.
Each list follows the ordinary count/entries/end-label format; `plccheck`
checks its queue budget. Empty lists use `dc.w -1`; when adding their first
entry, use the computed count header shown by the populated lists.
Art, mappings and [VRAM lifetimes](Sprites-and-VRAM.md) must agree.
SMZ act 2's Kemusi load is an example of a differing act list.

Main loads during the title card; Extra loads after terrain. Main reserves
five of the 16 request slots for shared requests, leaving 11 for its act list.
Extra has 16 slots. Assembly rejects overflow; an empty list has count `-1`.
Shared HUD, monitors, checkpoints, life art and boss PLCs retain their own
lifecycle. The Kosinski module index also has separately named act lists,
including distinct empty recipes ready for later additions.
The CD branch decodes both on the sub-CPU and queues prepared RAM output for
DMA. Its resumable PLC and module ownership contracts live in
[Mega-CD](Mega-CD.md#asset-decompression-and-plcs); the editable lists keep their
existing format.

Objects still select named art bases in their own code. A per-act logical
asset-to-tile binding/allocation system was discussed but is not implemented;
these PLCs do not dynamically allocate object VRAM or encode allocation in mappings.

## Per-act music

Edit `MusicList` in `md-main.asm`: each zone row holds four independent IDs in act
1-4 order. Use existing `MusID_*` names or `bgm_*` aliases. For example:

```asm
        dc.b MusID_GHZ, MusID_EHZ, MusID_GRGZ1, MusID_GRGZ2 ; GHZ
```

Defaults repeat each zone's existing song. Assembly checks all 64 entries
against `LevelActCount` (`LevelCount * ActsPerZone`). Level entry, drowning
recovery, invincibility expiry and GHZ/EHZ boss cleanup share `GetLevelMusic`,
preserving act selection. Invincibility/boss music retains
priority; one-up jingles restore the driver's saved context. Sound formats
and importing belong in [the sound guide](../build_tools/sound/README.md).

## Water configuration

`_inc/WaterFeatures.asm` owns three explicit tables covering all 64 acts:
`WaterFlags` enables water, `WaterHeight` supplies the initial surface Y, and
`DynWater_Index` selects the target-height routine. Each zone has four entries
in act order. This provides the full-table coverage of s2disasm's
`useFullWaterTables`, adapted to this project's sixteen four-act zones; there
is no reduced-table build mode. Level entry, height initialization and dynamic
dispatch all use the same zone/act index. Assembly checks every table's length.

LZ and HPZ retain their previous four heights and dynamic routines. Other
slots start dry, with editable `$600` heights and `DynWater_Null`. Enabling a
slot also enables its water surface, palette split and player water behavior;
choose a suitable underwater palette/art allocation before designing that act.
LZ act 4 selects the SBZ3 underwater character palette. Checkpoints retain
the existing saved water state and height behavior.

Dry GHZ acts borrow water-surface VRAM for their smashable walls; relocate that
art before enabling their water, as described below.

## Terrain and tile animation

All ordinary levels share one 256-entry height/width/angle bank in
`collision/`. LZ and Scrap Madness use that bank too; there is no runtime S1
bank or zone-dependent bank selector. The two byte indices per block retain
the S3K collision-index format. SonLVL inherits the shared bank and uses each
act's corresponding collision-index file, matching runtime.

Profiles were consolidated under X/Y flips, retaining every shape referenced
by the committed block definitions, including unplaced editor blocks. A changed
profile orientation is cancelled in block art and chunk flags: displayed tiles
and both collision silhouettes are preserved. Both paths of a block must share
one compensating orientation across every act/timezone. The bank has 16 empty,
unreferenced slots: `$CC-$D0`, `$D8-$DC` and `$F5-$FA`. Unreferenced shapes from
the original full-game banks are not part of this runtime catalog.

Retained S2 profiles keep their data and angles. The four CPZ blocks
`$192/$196/$19D/$1A1` normalize their effective even angles by 6/6/2/2 units;
reused LZ/SMZ curves differ by at most 4 units (one unit is 1/256 turn).
Odd angles retain their generic-angle marker semantics. `$FB-$FE` retain their
full-solid geometry and distinct directional angles; `$FF` retains its generic
full solid. Matching silhouettes alone is not permission to discard these roles.

Source `.unc` blocks/chunks and uncompressed collision `.bin` files are editable
inputs. Recompress changed block/chunk sources with Kosinski+ alongside their
source edits. The Scrap Madness importer translates S1 source profiles into the
existing shared bank, updates all four acts/timezones, and writes matching raw
geometry sources. It rejects missing shapes rather than silently allocating a
new bank. Add a deliberate shared-bank definition before importing new terrain.

Collision references include S1, S2, CD and standalone S3; S3&K provides an
additional engine/table comparison. Identical silhouettes can carry different
angles even within one game, so compare the intended curve, both height/width
maps and angle-marker semantics before merging profiles. CD's floor probe also
has direction-dependent negative-height handling, while S3&K combines optional
foreground/background probes and gravity-aware response. Importing their
profiles does not install those engine behaviors.
CD's SSZ cylinders toggle global `stage_layer`; its block lookup substitutes
whole 256-pixel chunks for the alternate path. That mechanism is separate from
this engine's two collision indices per block.

Importing all desired tunnel/curve families remains future work. The complete
four-game table union contains 562 distinct height/width geometries
under X/Y flips, before preserving angle variants and shared-path orientation
constraints. It cannot fit the current byte-index format unchanged. Selective
imports can use the available slots; a complete union requires wider indices
and coordinated runtime/SonLVL support. No collision-index format change is
implemented by this consolidation.

`LoadZone` loads complete ordinary 16x16 block definitions. Animation blocks
already reference their final VRAM slots; there is no initialization patch
table. Raw animation pixels remain uncompressed in ROM. `Dynamic_Normal`
interprets frame/duration scripts and queues DMA; the dispatcher also supports
handwritten zone routines. No animation decompression runs in VBlank.

| Assets | Animated block IDs | Animated tile slots | Current block count |
| --- | --- | --- | ---: |
| CPZ / Ancient Workbench | `$1B7` | `$319-$31A` | 632 |
| HPZ / Crystal Valley | `$2BC-$2D9` | `$2E8-$2FF` | 730 |

Source `.unc` and Kosinski Plus block files contain these definitions. SonLVL's
`animtiles` entries provide first-frame art at the same slots. Both collision
paths and upper chunk flags must be preserved when rebasing block references.

All terrain sets start with transparent tile `$000`, the 16 shared water-surface
slots `$001-$010`, then editable terrain at `$011` onward. No reservation cuts
through the middle of the sheet. Static relocation preserves block pixels,
palette and flips; ledges and platforms keep sharing terrain art. GHZ reclaims
ten unused interior slots into terrain, leaving ten more tiles of contiguous
capacity before its object bank at `$32B`. SMZ's former atlas-hosted terrain tile
is back in the terrain set at `$2B8`.

Dry acts may reuse the surface slots until water is enabled. GHZ intentionally
loads its smashable wall into `$001-$00C` through the Extra PLCs, using
`ArtTile_GHZ_SLZ_Smashable_Wall = $001`. Relocate that allocation when enabling
water in an affected act. The VRAM check permits this deliberate borrowing;
the boss regression executes the actual water-selection code for all four
GHZ acts to guard the contract.

## Labyrinth art

Rustic Ruins/LZ uses a Tidal Tempest background with its edited LZ terrain art.
Many tiles removed from the end of S1's original sheet belonged to the enormous
LZ4/SBZ3 lift. Restoring its original object would also need the missing art;
the current sheet is not a complete stock-S1 bank. The restored LZ1 conveyors
use their separate object-art bank and preserve this terrain/background work.

S1's ancient lift (`ScrapStomp`, object `$6B`, `.bigdoor` mapping) references
104 tile slots at offsets `$00-$67`, reused across 216 drawn tile positions in
14 sprite pieces. Its `$1F0` base places it at VRAM `$3E00-$4AFF`: the final
tile starts at `$4AE0`, and `$4B00` is the exclusive end. That is `$D00` bytes
(3.25 KiB), about 5.1% of all VRAM. These figures come from s1disasm
`15dfa3a6ee4c53aeb482233e493755c84b4f3479`, `_maps/SBZ Stomper and Door.asm`
and `_incObj/6B SBZ Stomper and Sliding Door.asm`; they count referenced slots,
not a claim that every tile's pixels are unique.

## Scrap Madness

Acts 1/2 retain S1 SBZ foreground, industrial backgrounds, collision and hazards.
The S1 converter deduplicates 256-pixel chunks into the current 128-pixel format.
Act 1 uses the REV01 cloud gradient and three building layers scrolling at
1/4, 3/8 and 1/2 foreground speed. All layers follow vertical movement at 1/8
speed; act 2 uses a uniform 1/4 horizontal and 1/8 vertical speed. Initial draws
and streamed strips share the original row-to-camera table, and checkpoint
reloads retain the saved background cameras. A bespoke act-2 ending remains
unfinished; act 2 currently uses the normal signpost.

Imported families `$A0-$AF` cover the junction, disc,
belts, trapdoors, saws, stompers, vanishing platforms, flames, electricity,
conveyor groups, girders, transport pipes, barriers, floors, bombs and button.
Their IDs/subtypes/editor definitions are maintained in
[SonLVL](../SonLVL%20INI%20Files/README.md).

All twelve act-2 swinging spikeballs use `$76/$77`: family `$7x` hurts on every
side with no standing surface. Family `$5x` retains solid-top/harmful-underside
behavior for future levels. The wheel (`$B0`) has no SMZ placements, PLC or Debug
entry; its eight payload presets remain in LV0A. PP enemies `$B1-$B5`, missile
`$B6` and MM propeller `$B7` remain separate imports, also demonstrated in LV0A.

The live button uses only gray/blue up/down frames; its unused red tiles/mappings
are omitted by both importer and packer. The separate user-authored draft
`objects/W.I.P Objects/32 Button.asm`, standalone `art/nemesis/Button.nem`,
`Nem_Button` and `ArtTile_Button` placeholder are preserved. That draft is not
assembled into the running game.

Flame-core pixels map S1's palette-0 index `$F` yellow (`$0EE`) to the shared
palette's `$E` golden orange (`$0AE`), replacing the former `$A` cream (`$8CE`).
Pipe ends, red/dark-red outlines and global palette colors remain intact.

The static sprite atlas shares whole identical/overlapping rectangles, retaining
piece sizes, ordering, geometry, flips, adapted pixels, palette and priority.
It never subdivides pieces or changes the renderer. Its 497 used tiles start at
`$2B9`; six padding tiles bring the allocation through `$4AF`.
The junction's rotating edge streams 4-12 tiles into `$4B0-$4BB`; center/outer
ring stay resident. Its placements have disjoint load windows. Failed queue
reservation hides the rotating sprite and retries without displaying partial art.

`$4BC-$4C4` is the wheel bank used in LV0A. SMZ act 1's two 12-tile smoke strips
occupy `$4C5-$4D0` and `$4D1-$4DC`. Act 2 reuses that space for 22 Kemusi tiles
at `$4C5-$4DA` and does not run smoke uploads there. Act 1 uses Caterkiller;
act 2 adds Kemusi. These lifetimes must remain exclusive.

## Sources and regeneration

| Source | Pinned revision | Use |
| --- | --- | --- |
| sonicretro/s1disasm | `2c51d46a0b0682133834db2093292d41da872ecf` (REV01) | SBZ geometry/art/objects and S1 arrangements |
| sonicretro/skdisasm | `73de97c6b55055bcb8089c1d55d006b02136f163` | S3/S3&K collision and player response, effects, springs, loading and menus |
| sonicretro/scddisasm | `f8cf3f0af7bf419d18182ba98554f09307ad3cc6` | Wheel and PP enemies |
| sonicretro/scddisasm | `791253ba1922d7c4142a40975860d1b3bb37b9f7` (test) | MM propeller, shared collision tables and SSZ path-swap reference |
| sonicretro/s2disasm | `15e9fd52a65318bec3d5e746ce48dba6db6910db` | EHZ boss and Tails HUD-name source |
| sonicretro/s1disasm | `15dfa3a6ee4c53aeb482233e493755c84b4f3479` | Collision-table and contact-routine reference |
| sonicretro/s2disasm | `4ef457c18fc4902396c43ab06fabc119ac6ecb64` | Collision-table and contact-routine reference |
| AlexField442/scddisasm | `eaf7424a61204fc5bd8592e7b23e7f2f3c43b936` | Collision tables, chunk lookup and floor/wall probes |

Use read-only source checkouts and a normal built ROM/listing. The full SMZ
import writes source-derived geometry and placements, overwriting editor changes;
run it only when deliberately regenerating those assets. The atlas packer follows
the importer. PP's converter validates rectangles and adapts opaque colors.

```sh
python build_tools/import_scrap_madness.py --source /path/to/s1disasm --rom s2built.bin --listing md-main.lst
python build_tools/pack_scrap_sprites.py --source /path/to/s1disasm --rom s2built.bin --listing md-main.lst
python build_tools/import_palmtree_enemies.py --source /path/to/scddisasm/src --rom s2built.bin --listing md-main.lst
python build_tools/import_propeller.py --source /path/to/scddisasm --rom s2built.bin --listing md-main.lst
python build_tools/build_card_art.py
python build_tools/build_signpost_art.py
```

Card/signpost generators own their art, mappings and DPLCs; do not edit generated
copies independently. Checks and their scope are in [Testing](Testing.md).

## Planned layout format

This is agreed future work, not the current format. SonLVL should allow mixed
128x128 and 256x256 editing on a 128-pixel grid. A 256-pixel definition stamps
four constituent cells, including at an odd starting cell on either axis;
individual 128-pixel placements can replace any quadrant. Saving bakes a uniform
128-pixel runtime layout while retaining reusable editor-side 256-pixel definitions.

Runtime chunk IDs become words (`$0000-$FFFF` theoretical range), the old looping
flag disappears, and two collision paths are required. The current engine already
has two collision paths; the new format must preserve them. Custom SonLVL format
support is needed; whether a fork is required remains undecided.

The CD branch has already expanded physical chunk storage to 128 KiB, first after
the BIOS area. That fits 1,024 distinct 128-pixel chunks, equivalent to 256 complete
256-pixel definitions without reuse; 16-bit IDs do not mean all 65,536 chunks fit.
Only the first 32 KiB is used by the current format. See [Mega-CD](Mega-CD.md).
