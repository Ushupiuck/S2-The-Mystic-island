# Scrap Madness, sixteen-zone slots and shared objects

The game now exposes `$10` zones (`$00-$0F`), four acts each. The level select
uses S3&K's font, palette and animated background. Its first page lists zones
00-07; the second lists 08-0F. NEXT/PREVIOUS sits directly above SOUND TEST on
both pages. Left/right changes columns, up/down moves through acts, A/B/START
activates an entry, and C cycles Sonic & Tails, Sonic, and Tails.

## Level content

| ID | Name | Current content |
| --- | --- | --- |
| 00 | Twilight Hill | Existing GHZ-based acts |
| 01 | Rustic Ruins | Existing LZ-based acts |
| 02 | Ancient Workbench | Existing CPZ-based acts |
| 03 | Emerald Hill | Existing EHZ-based acts |
| 04 | Crystal Valley | Existing HPZ-based acts |
| 05 | Egg Mountain | Existing HTZ-based acts |
| 06 | Metropolis | Existing unfinished act 1; safe editable starters for acts 2-4 |
| 07 | Shocking Blizzard | Four editable starter acts; final ice assets/layouts remain to be designed |
| 08 | Scrap Madness | Actual S1 SBZ acts 1/2; editable starter acts 3/4 |
| 09 | Death Egg | Four editable starter acts; final space assets/layouts remain to be designed |
| 0A | LEVEL 0A | Editable starters; act 1 also demonstrates the five imported PP enemy families |
| 0B-0F | LEVEL 0B-0F | Four editable starter acts per unnamed slot |

The starters have valid terrain/collision, starts, rings and goals. They are
templates for further level design, not completed themed zones. All 64 act
entries have headers, layout/object/ring pointers, camera bounds, music,
collision, title/act cards, Debug lists, and level progression. Prepared
timezone headers/layouts remain copies until the existing time-travel TODO is
implemented. SonLVL has all 64 present-day sections with matching assets and
collision arrays.

SBZ1/2 retain their original foreground terrain, industrial background tiles,
collision shapes, hazards and placement positions. S1's 256px chunks are
converted into 249 deduplicated 128px chunks; there are 602 blocks. Ring groups
become 197/153 ordinary ring entries, and the object layouts contain 305/243
placements. Spinner-conveyor groups become individual platform placements.
Smoke and original palette cycles are included. The background currently uses
simple industrial scrolling; full REV01 parallax and a bespoke act-2 ending
remain on the TODO. The current act-2 exit uses the ordinary signpost system.

## Object IDs

| ID | Imported object |
| --- | --- |
| A0 | Rotating junction, independent capture/release for each actor |
| A1 | Running disc, with CNZ-style attachment/ground-speed handling |
| A2 | Conveyor belt |
| A3 | Spinning platform and trapdoor |
| A4 | Saws / pizza cutters |
| A5 | Stomper and horizontal door |
| A6 | Vanishing platform |
| A7 | Flame pipe |
| A8 | Electric beam |
| A9 | Conveyor platform |
| AA | Moving girder |
| AB | Transport pipe, separate travel state for both actors |
| AC | Invisible solid barrier |
| AD | Moving floor / large door |
| AE | Bomb, fuse and shrapnel |
| AF | SBZ button |
| B0 | Independent wheeled carrier |
| B1-B5 | PP Anton, Mosqui, Pata-Bata, Taga-Taga and Tamabboh |
| B6 | Tamabboh missile |

Existing doors, floors, swinging spike balls, Ball Hogs, Caterkillers, springs,
monitors, checkpoints and goals are reused with SMZ art where needed. Imported
objects use long routine pointers, the `$4E` SST layout, six-byte mappings and
S3&K placement/respawn ownership. No high-ID mirror bit is used. Collision
indices are translated by dimensions rather than copied between games.

The SMZ atlas preserves all 135 source frames' original piece counts, sizes,
positions, ordering, flips, adapted indexed pixels, palettes and priority.
Complete sprite rectangles share identical art and overlapping tile sequences;
pieces are never subdivided. All objects share one bank in both acts.

The static atlas occupies 501 tiles at `$2B0-$4A4`. The junction's changing
edge uses a twelve-tile DPLC buffer at `$4A8-$4B3`; its centre and outer ring
stay in the static atlas. Each angle uploads one 4-12-tile run when it changes,
through the existing atomic S3&K loader. Its two placements have disjoint loading
windows. Collision, switch reversal, capture/release and rotation timing remain
independent of the upload. A full DMA queue hides the rotating sprite for that
frame and retries; it never caches or displays a partial upload.

Both acts retain every object family in the same allocation. Terrain art,
blocks, chunks, layouts and collision data are unchanged. The striped barrier
at Final Zone's entrance uses source terrain tiles `$25F-$263`. The wheel bank
remains at `$4B4-$4BB`, and two smoke strips remain at `$4BD-$4D4`.
The plane-A tile-table range `$600-$67F` remains unavailable for sprite art.

Grounded ducking uses the rolling/spindash diameter for solid-object head
clearance (28 pixels for Sonic), without changing the player's stored radius,
feet, landing height or platform ride offset. Standing and airborne contacts
retain their existing bounds, and gaps too small for the compact body still
crush. `check_duck_clearance.py` exercises those boundaries and support points
with Sonic-only 68000 fixtures.

Closed trapdoors try the ordinary top-landing check before full solidity.
This prevents a shallow foot overlap at the closing edge from being resolved
as a side wall that cancels movement. The closed underside still blocks
upward jumps, the ride height stays the same, and opening releases riders.
`check_smz_trapdoor.py` checks both edges, three approach speeds, closure
depths, underside contact and opening release without running companion AI.

## Springs, carrier and Tails

S3&K vertical, horizontal and diagonal art/mappings replace the S2 sets.
Yellow caps are adapted to the common palette instead of depending on a
zone's palette 1. The spring implementation shares direction-specific
callbacks across both actors and retains strengths, twirling, collision-path
changes and transverse-speed options. Airborne horizontal contacts use the
actual side-collision result. GHZ keeps the diagonal bank for Chopper because
its current layouts contain no diagonal springs; a GHZ diagonal-spring design
will need a corresponding art allocation change.

The common diagonal/vertical/horizontal banks start at `$4D5/$4F5/$509`.
Spikes/monitors/checkpoints start at `$519/$529/$565`; the auxiliary shield bank
starts at `$56F`. Title cards and results use per-screen DPLCs at `$581`,
with a maximum of 84 tiles, preserving both shield banks. Existing letters
retain their original S1 pixels (including K and U); new V/W and act 4 match
the original serif letters and orange digits. W uses a 24-pixel-wide sprite
and advance, giving its inner strokes room while keeping the other letters'
metrics. Zero shares the original O.

Normal results load 74 tiles for Sonic or 70 for Tails; special-stage results
load 60-72 tiles for the selected heading. The 150-tile raw font remains in
ROM, so no decompression buffer is needed. Card loading resumes when the DMA
queue is full and waits until the last upload has executed before showing
the card. Bonus mappings derive their offsets from the current bank instead
of assuming a `$580` base.

Tails's HUD portrait refers directly to monitor tiles 56-59 (`$561-$564`).
All twelve monitor frames retain their indexed pixels after moving that
portrait to the end of the bank. Sonic's separate life portrait remains
available for Sonic monitors. The HUD name strip and normal/special results
headings follow the selected solo character. Signpost DPLCs use at most
18 tiles (`$529-$53A`), leaving Tails's portrait intact throughout the spin.

The wheel is its own object. `WheelPayloads` in `objects/B0 Wheel Carrier.asm`
is an editable table of ordinary routine pointer, vertical offset, subtype and
facing. The payload retains its own behavior and solidity. The carrier handles
position, riders, allocation retry, consumed payloads and unload cleanup.

| B0 subtype | Payload |
| --- | --- |
| 0 / 1 | Red / yellow upward spring |
| 2 / 3 | Red / yellow horizontal spring |
| 4 | Red diagonal spring |
| 5 / 6 | Ring / shield monitor |
| 7 | Upward spikes |

Wheel art is loaded in SMZ and LV0A. Other zones must reserve/load it and the
chosen payload's art in their PLCs. The eight presets are available in these
zones' Debug lists and in SonLVL.

The previous generic timed flight fallback stays removed. Companion Tails
keeps ordinary jumps for unreachable targets, bounded collapse pursuit and
grounded slope-slip spindash recovery. The SBZ pass additionally clamps his
follow target inside a shared ridden platform when Sonic is nearly stationary
and discards stale horizontal input there. This prevents chasing Sonic's toe
beyond a ledge while preserving successive normal jumps. Controller 2 retains
precedence.

The five PP families were the last implementation item. Subtype 0 is normal,
1 is damaged; Tamabboh missiles have their own routine/ID. Normal Mosqui dives
and Tamabboh attacks can be triggered by either live actor. Source timings,
patrol/sine/jump motion and damaged behavior are retained. Grounded enemies
reverse once per frame instead of recursively retrying a narrow ledge.
Missiles use fixed gravity without redundant zero horizontal acceleration.
The palette-adapted 246 tiles stay resident at `$32B-$420` in LV0A. Their art,
two variants and editor previews do not require CD's camera PLC swapping.
Timezone-dependent generator suppression remains part of the separate CD
object-placement/time-travel work.

## Sources and reproducibility

- S1 geometry, objects, mappings and art: `sonicretro/s1disasm`,
  `2c51d46a0b0682133834db2093292d41da872ecf`, REV01.
- S3&K springs, level select and running-disc reference:
  `sonicretro/skdisasm`, `73de97c6b55055bcb8089c1d55d006b02136f163`.
- CD wheel and PP enemies: `sonicretro/scddisasm`,
  `f8cf3f0af7bf419d18182ba98554f09307ad3cc6`,
  `src/Level/_Objects/Spring` and `src/Level/Palmtree Panic/Objects`.

Source checkouts are read-only. With a normal built ROM/listing and the native
test harness dependencies installed, regenerate SMZ in this order:

```sh
python build_tools/import_scrap_madness.py --source /path/to/s1disasm --rom s2built.bin --listing main.lst
python build_tools/pack_scrap_sprites.py --source /path/to/s1disasm --rom s2built.bin --listing main.lst
python build_tools/import_palmtree_enemies.py --source /path/to/scddisasm/src --rom s2built.bin --listing main.lst
```

Regenerate the card font, card DPLCs/mappings, signpost DPLCs/mappings and
monitor arrangement with:

```sh
python build_tools/build_card_art.py
python build_tools/build_signpost_art.py
```

The Tails HUD name source is the eight text tiles from the original S2
`Tails life counter.nem` (`sonicretro/s2disasm`, commit
`15e9fd52a65318bec3d5e746ce48dba6db6910db`). The signpost source and original
static mappings remain available for editor previews.

The first SMZ converter writes unpacked source-based assets; the packer then
creates the final atlas/mappings and rebases the smoke blocks. The ROM supplies
unchanged shared mappings and the Nemesis decompressor. PP's converter reads
the CD art/mapping source, adapts opaque colors to the common palette while
keeping transparent pixels transparent, and validates each rectangle against
its art bounds.

## Validation and limits

`Card-art-results.json` records the current card-maintenance build and checks.
Its 108 native 68000 checks cover all 78 DPLC scenes, queue exhaustion/retry,
mapping ranges, bonus tile addresses, character selectors, all six signpost
frames, and the unchanged 64-entry progression table. Genesis Plus GX checks
cover all 64 intro screens, Sonic/Tails normal results for acts 1 and 4,
all three special-stage heading states for each character, both continue
poses, and PAL Tails normal/special results. The shared asset and sprite-bound
checks also pass. These are solo UI/VRAM fixtures, not companion-AI route runs;
Tails's AI code is unchanged by this batch.

`Scrap-Madness-results.json` retains the earlier integration report and ROM
hash. That snapshot was `$1B4430` bytes and generated 119 requested mapping
bounds across 1300 frames. Static checks cover 117 object files, 7182 named SST
operands, 66 ordinary layouts/1830 placements, all 64 act pointers, Debug/RAM,
105 binary mapping files, common VRAM banks and both existing boss/capsule sets.

Actual Genesis Plus GX runs pass in NTSC and PAL:

- Both menu pages, sound-test wrapping/playback, three character selections,
  and all 64 act boots.
- SBZ1/2 slow stops/restarts and faster routes, a ledge wait followed by
  platform-by-platform jumps, every one of the 548 original placements, both
  actors in junction/pipe/disc interactions, all eight wheel payloads, and
  both riders on a moving monitor.
- Red/yellow springs in all five orientations for both actors, including
  airborne side contacts.
- Actual HPZ1 slow-ramp/spindash and successive platform routes.
- Both variants of every PP family, both-actor attack triggers/combat,
  missile damage and unload/reload of all ten LV0A placements.

Opening routes use controller input. Later fixtures position initial actors
at real placements and let normal collision, animation, transport and loader
code run. These are stress/lifecycle tests, not complete controller-only
clears of SBZ1/2. The fast SBZ1 route includes an ordinary pit death; it is
recorded, not treated as an AI pass-through. No unjustified local flight occurs
on the measured slow, fast or successive-platform routes. The PP backtracking
fixture reopens the camera range after entering the normal goal-art preload
area, because normal signpost preloading deliberately prevents backtracking.
SonLVL asset/XML paths are checked; the desktop editor itself was not available
for an interactive UI test.
