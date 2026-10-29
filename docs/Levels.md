# Levels, act configuration and assets

The level select exposes zones `$00-$0F`, four acts each, over two pages.
NEXT/PREVIOUS sits above SOUND TEST. Directions select entries, A/B/START
activates, and C cycles Sonic & Tails, Sonic, and Tails. Starter acts have valid
data and goals; they remain level-design templates.

On SOUND TEST, play `01`, `03`, `05`, `07` to unlock Debug with the ring jingle.
See [Debug controls](Objects.md#debug) for level-entry activation.

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

GHZ4 retains its sparse authored object layout for useful object-testing terrain.
Its loop at chunk origin `$1000,$0500` now has Act 3's matching three pathswappers
(`$1080,$0550/$0091`, `$1108,$0540/$0011`, `$1108,$05A0/$0010`), present in
all eras. The act also has four authored platform test stations: detachable
conveyor/grip/button at `$0180,$0520`, moving mixed spring pair at `$0400,$0480`,
ICZ rail/monitor swing at `$0680,$0380`, and square-moving spike platform at
`$0900,$0480`. These are ordinary SonLVL-editable placements; detailed stress
fixtures remain disposable. Act 4's lower camera limit is `$0700`, allowing
the entrance-gap water to be reached before the death plane. Its banks use
spare chunks `$C4-$C7/$E6-$E7` with side collision on the solid fill below the old wall
edge, preventing rafts from entering decorative terrain interiors. All four
era layouts select these copies; existing chunks and their artwork are unchanged.
Its act-specific art kit loads only the swinging platform/ball, vertical and
horizontal springs, the shared handhold/chain bank and the portable button, in addition to common
HUD/monitor/spike/effect/animal/player art. Its module list is explicitly empty;
bridge, rock, wall, ground-explosion and badnik loads from Acts 1–3 are omitted.
`Debug_GHZ4` lists the matching test objects independently of the earlier acts.
Add further art and Debug entries to this act's own lists when extending it.

LZ1's six Ballhog placements were temporary bomb/wall test fixtures and are
removed. The thirteen conveyor/wheel placements retain their original bytes.
All four LZ module lists omit the copied horizontal/vertical Ballhog loads;
the entries remain commented out for convenient act-specific reuse. GHZ1's four
starting Ballhog test placements are also removed, with its Ballhog module,
ground-explosion and shared Debug test entries commented out. Scrap Madness's
ten authored Ballhogs, their code and atlas are unchanged. Those two enemy banks total
71 tiles (`$43D-$483`, 2,272 bytes), available for a future LZ act recipe.

## Foreground vertical placement

All four GHZ acts have moved down `$200` pixels (four 128-pixel rows); all four
EHZ acts have moved down `$300` (six rows). MTZ1 has moved down `$500` (ten rows),
using its existing `startpos/006_1.bin` source. All era foregrounds, object/ring
placements and starts use those authored coordinates. Camera bounds, dynamic
GHZ limits, boss anchors and GHZ4's water basin/editor height move with them.
Foreground top bounds are now `$200` for GHZ and `$300` for EHZ. Background
layouts remain independent; EHZ2's 1/8 vertical parallax exposes up to 96 more pixels
of its PP panorama at the equivalent route position.

`build_tools/shift_level_foreground.py LEVEL... --dy 0x80` previews a relative
translation of binary foreground/placement/ring/start sources; `--write` applies
it after validating the complete selection. It preserves packed Y flags and
ring-group counts, all X coordinates and background cells. Coordinate-dependent
ASM events, water and editor settings must be updated alongside the binary data;
the tool does not infer them. Do not repeat an already-applied shift.
Use `--start-file startpos/006_1.bin` for MTZ1's differently named start source.

All 64 acts were surveyed. LZ, CPZ, HPZ, HTZ and SMZ1/2 already have authored
terrain reaching row 15. The remaining starter acts fill rows 3–15 with solid
terrain chunks; those rows are not empty padding. They retain their coordinates.

Camera seam arithmetic uses `Level_YWrapMask` consistently. A negative top bound
enables the existing `$0800` seam (including SMZ2); ordinary acts clamp at their
authored bounds, even beyond `$0800`. The 32-row Mode 1 layout capacity is
independent of whether a particular act wraps.
The paused cartridge backend retains its frozen layouts and is not the target
of this Mode 1 layout work.

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
Shared HUD, monitors and checkpoints retain their own lifecycle. Resident boss,
capsule, explosion, signpost bonus and Mecha effect art use the named
`PLCKosM_Boss`, `GHZBoss`, `Capsule`, `Explode`, `ExplosionWall`, `Signpost` and
`MechaSonic` lists in the same file. Edit their explicit `plreqKosM` entries.
The old `plcid_*` event IDs still address these lists through typed index entries;
there is one payload per list, with `PLC_*` labels retained as address aliases. The Kosinski module index also has separately named act lists,
including distinct empty recipes ready for later additions.
The Mode 1 build decodes both on the sub-CPU and queues prepared RAM output for
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

LZ and HPZ retain their previous four heights and dynamic routines. GHZ4
enables a stationary target at `$0600` for its entrance-gap raft test. Other
slots start dry, with editable `$600` heights and `DynWater_Null`. Enabling a
slot also enables its water surface, palette split and player water behavior;
choose a suitable underwater palette/art allocation before designing that act.
LZ act 4 selects the SBZ3 underwater character palette. Checkpoints retain
the existing saved water state and height behavior.

GHZ4 loads a full four-line teal underwater palette, generated by
`python build_tools/build_ghz4_water_palette.py` from `SonicAndTails.bin`,
`GHZ.bin` and the waterfall cycle. It blends 25% RGB `(0,6,7)` in the MD
channel range, then quantizes to hardware colors. Its underwater waterfall
uses the matching four phases. SonLVL exposes this palette at the shifted height `$0600`.
The initial full palette and fade destination select the same descriptor.

Dry GHZ acts borrow water-surface VRAM for their smashable walls; relocate that
art before enabling their water, as described below.

## Mode 1 plane engine

Mode 1 uses independent foreground/background rectangles on the existing
128-pixel chunk grid. Each plane can be 1..256 chunks wide and 1..32 high;
the combined decoded file must fit 32 KiB. Chunk IDs are unsigned words,
with 1,024 physical chunks available in CD PRG RAM. Blocks remain a mutable
6-KiB RAM table; neither the renderer nor collision reads block definitions
from ROM during gameplay. Live block edits therefore retain their existing
storage and editing advantages.

`_inc/Level Plane Events.asm` contains one explicit six-long record per act:
FG initialization, BG initialization, FG event, BG event, CD FG source provider,
and CD BG source provider. Edit that act's record to select its behavior.
Camera/deformation events execute on MD; drawing providers execute on CD.
GHZ and SMZ1 retain their banded backgrounds, including GHZ's split hill/water
row (scrolling upper eight pixels, fixed lower eight). Other acts can independently
select or add providers. Art/blocks/chunks still use the ordinary per-act
headers. Shared/act-exclusive art banks and smooth act transitions are separate
resource choices, not prerequisites for this engine.

`level/layout/**/*.kosp` is the authoritative editable Mode 1 layout set,
including all four eras. SonLVL's `Common/LevelLayout.cs` reads and saves the
same format and supports resizing FG and BG independently. Saving generates
relative lookup offsets; it never embeds RAM addresses. The Python codec is
`build_tools/level_layout.py`, and the normal Lua build validates every file
before assembly. Each compressed archive is followed by `even`, keeping
subsequent word tables aligned. Foreground cells outside the authored rectangle select empty
chunk 0; background cells repeat using precomputed row/column tables, including
non-power-of-two dimensions. Runtime coordinates wrap at 256 by 32 chunks.

Old repeated strips and outer padding have been reduced to one complete
background span: GHZ is 64x2 chunks, CPZ 6x6, EHZ 4x2, and HPZ 8x9.
Unique HTZ background cells, including its distant draft arrangements, are
retained. `python build_tools/compact_level_backgrounds.py` reports further
reductions; add `--write` only when deliberately removing old workaround copies
and padding. Normal builds and SonLVL saves preserve authored dimensions and
empty margins. The SMZ importer retains its already compact backgrounds.

Decoded format, all words big-endian:

| Offset | Contents |
| --- | --- |
| `$0000` | Magic `$504C` (`PL`), version 2 |
| `$0004` | FG width/height, BG width/height, four words |
| `$000C` | FG lookup record: 32 row offsets, 256 column offsets |
| `$024C` | BG lookup record, same structure |
| `$048C` | Word chunk cells; FG rows include one empty column and a final empty row |

Offsets are relative to their own plane record. Row plus column lookup directly
addresses a cell; loading requires no relocation, multiplication or in-game
validation. External validation checks dimensions, capacity, IDs and every
precomputed offset. Layout scripts use `Layout_Read`/`Layout_Write` with
`d0.w = row<<8 | column`; reads return `d0.w`, writes take a word ID in `d1.w`.
After changing visible terrain, set `Screen_redraw_flag` to rebuild both planes.
CD drawing tracks rounded source positions per physical 16-pixel row, producing
only newly exposed rows/columns in Word RAM. A stationary scene emits no terrain
records. VBlank consumes the completed records; it does not construct terrain.

The cartridge backend is paused at its former byte layout format. Its frozen
inputs live in `md-only/layout/`; editing a Mode 1 layout does not update them.
The current migration and validation target Mode 1 only.

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
is included in each act's compact terrain sheet; its sprite atlas still starts
at `$2B9`.

Dry acts may reuse the surface slots until water is enabled. GHZ intentionally
loads its smashable wall into `$001-$00C` through the Extra PLCs, using
`ArtTile_GHZ_SLZ_Smashable_Wall = $001`. Relocate that allocation when enabling
water in an affected act. The VRAM check permits this deliberate borrowing;
the boss regression executes the actual water-selection code for all four
GHZ acts to guard the contract.

## Emerald Hill Act 2: Palmtree Panic experiment

Mode 1 EHZ2 has private `8x8 - EHZ2.unc`, `EHZ2.unc` blocks/chunks,
matching Kosinski+ archives, collision indices and `EHZ2 PP.bin` palette.
All four era headers select these assets; Acts 1/3/4 retain the original EHZ bank.
The BG is the upright 512x512 panel at source Y `$600` in Palmtree Panic Act 1
Present. Its mirrored ramp section is excluded. The new background is authored
once as 4x4 ordinary 128-pixel chunks.

The importer retains foreground tile/block/chunk IDs, flips, collision paths,
static pixels and flower animation. Obj18's platform terrain tiles keep their
IDs too. Background-only slots are recycled; unused trailing definitions are
removed. Stable foreground IDs preserve objects that reuse level art without
adding per-act object mappings. The independent source sheets remain editable;
regeneration deliberately rebuilds them from shared EHZ and the pinned CD source.

The importer reserves shared HUD, life-text, points and ring colors in level
palette line 1, including shadow `$1` and digit highlights `$7/$8`; absence from
foreground tiles does not make these slots free. PP uses the remaining free
slots and the nearest available per-tile colors. Five near-matching
foreground shades are blended with PP's equivalents: each changes just one MD
channel by one hardware step. Their midpoint lies between representable colors,
so equal choices select the PP endpoint. This also aligns the wood/grass colors
used by bridges and platforms. All pixel indices remain fixed; other foreground
colors and the character palette stay unchanged. A few imported edge shades
still use the nearest available color per tile. The sky backdrop becomes PP blue.
The importer checks protected palette uses and bounds each deliberate blend.

EHZ2's own initialization/event entries in `_inc/Level Plane Events.asm`
produce four moving cloud bands, 3/16-speed mountains, half-speed bushes and
perspective water. Vertical movement follows at 1/8 speed within the upright
panel's viewing range. CD uses `Plane_SourceFixed`; MD writes horizontal scroll
values, while the shared buffered constructor supplies the fixed 512-pixel rows.
No ramp mirroring or extra RAM allocation is used.

```sh
python build_tools/import_ehz2_pp_background.py --source /path/to/scddisasm --output test-results/ehz2-pp/import.json
```

Use sonicretro/scddisasm `f8cf3f0af7bf419d18182ba98554f09307ad3cc6`.
The source checkout stays read-only. Do not regenerate after hand-editing the
private EHZ2 sheets unless intentionally replacing those edits.

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
Each act has independent editable `8x8 - SMZ1/SMZ2.unc` tiles and
`SMZ1/SMZ2.unc` block/chunk sheets, with matching Kosinski+ archives. Act 1
contains its outside background; Act 2 contains its inside background. Each
bank keeps the foreground and background chunks used by that act in any era,
then compacts their blocks and static tiles. All four era headers and SonLVL
select the corresponding bank. Collision indices are remapped with the blocks;
the shared profiles, chunk flips/solidity and tile palette/priority/flips remain
unchanged. The source sheets remain ordinary editable inputs, not outputs
regenerated during a normal build. Recompress an edited `.unc` sheet alongside
the edit. A full S1 import deliberately rebuilds and splits them again.

| Act | Static tiles, including reserved prefix | Blocks | Chunks | Static upload saved versus the shared 697-tile bank |
| --- | ---: | ---: | ---: | ---: |
| 1 | 469 | 374 | 166 | 228 tiles / 7,296 bytes |
| 2 | 474 | 383 | 175 | 223 tiles / 7,136 bytes |

Tile zero and water slots `$001-$010` retain their fixed positions. External
smoke, junction and sprite banks do not move. The reclaimed space is contiguous
before the resident atlas; object allocations are unchanged. Splitting duplicates
some shared foreground data in ROM, while reducing each act's decode/upload work
and resident terrain. Starter acts 3/4 use Act 1's tiles/blocks and retain their
separate `SMZ Blank.kosp` chunks. Blocks 0..5 keep their IDs: block 0 is empty,
block 1 supplies the starter floor and block 5 supplies the Mecha arena floor.

Act 1 uses the REV01 cloud gradient and three building layers scrolling at
1/4, 3/8 and 1/2 foreground speed. All layers follow vertical movement at 1/8
speed; act 2 uses a uniform 1/4 horizontal and 1/8 vertical speed. Initial draws
and streamed strips share the original row-to-camera table, and checkpoint
reloads retain the saved background cameras. Act 2 uses the Mecha Sonic
trap/fight at its original signpost position
`$1EE0,$05A4` (subtype `$0002`). Camera X locks at `$1E40`, Y at `$0500`.
`build_smz2_mecha_arena.py` makes three private chunk copies: inside
`$1E40..$1F7F`, raised steps above `$05C0` are cleared and existing steel
block 5 supplies a flat, fully solid floor on both collision paths. The
approach before `$1E40`, other acts and the act's blocks/shared profiles are unchanged.
All four time variants receive the floor; the SMZ importer reapplies it.
The last room's pipe backdrop contains high-priority tiles, so its actors,
tails and sign are drawn above that backdrop. The original foreground still
supplies the floor. Defeat restores the stage palette, then the real falling
sign invokes the existing SMZ2 results/next-act route.

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
palette's `$4` golden orange (`$0AE`), distinct from `$5` cream (`$8CE`).
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

Mode 1 already uses word chunk IDs, custom SonLVL layout support and two
collision paths. Mixed-size editor stamping is the remaining future feature;
the runtime still draws uniform 128-pixel chunks. The theoretical word-ID range
is not a promise that all 65,536 chunks fit RAM.

Mode 1 has already expanded physical chunk storage to 128 KiB, first after
the BIOS area. That fits 1,024 distinct 128-pixel chunks, equivalent to 256 complete
256-pixel definitions without reuse; 16-bit IDs do not mean all 65,536 chunks fit.
The plane engine addresses all 128 KiB on CD. Scene overlays retain their
separate 32-KiB view. See [Mega-CD](Mega-CD.md).

## Shared sprite colors in terrain

Terrain borrowing the first two rows follows the [sprite slot contract](Sprites-and-VRAM.md#palette-adaptation).
CPZ adds two tile encodings for mixed palette uses; MTZ recycles unused slots.
Block IDs, chunks and collision tables remain stable. EHZ2 reserves gray slot 9
and uses custom slots 4/5 for PP colors. EHZ's duplicate E86 shade uses slot A,
freeing slot 4 for EHZ2 without changing foreground colors.

CPZ's custom row had replaced its original red/brown terrain colors with blue.
Its custom colors now follow s2disasm `4ef457c18fc4902396c43ab06fabc119ac6ecb64`,
retaining this project's gray ramp and aligned D–F yellow ramp. The displaced
skin shade uses slot 3; duplicate black pixels use slot 1. CPZ acts load no badniks.

`build_underwater_palettes.py` rebuilds character rows from the live default:
25% violet RGB (2,0,7) for HPZ and pink (6,0,6) for LZ4, in 0–7 channel units.
The second sprite row uses the same tint of its current act palette; the lower
two authored underwater rows remain editable. GHZ4 retains its separate
four-row teal generator. Regenerate these after editing character colors.

Rustic Ruins Acts 1–3 use a dedicated full `LZ Underwater.bin`; Act 4 retains
its SBZ3 selection. The generator transfers S1 LZ's per-color normal-to-water
changes to the current foreground and sprite rows, then enforces shared
gray/yellow roles. Tidal Tempest Present's background uses the separately
editable 16-color `palette/LZ Background Underwater.bin` at its existing final
row. Its blue/purple ramps retain distinct red/purple masonry shadows; do not
apply S1's unrelated final-row color deltas to this imported scenery.
Source binaries live in `palette/sources/`:
S1 Sonic blob 5135434b6ab82242a1b4daa19bbc00571f9a97dc,
LZ normal 0c09d23e36ae5dda5f8d11b4cbce5259e7e62edb, underwater
b4b9c1db02663e7ce82f7d9bc7f9d1ad3b212a0e (sonicretro/s1disasm AS).
SonLVL exposes each act's corresponding water palette.
