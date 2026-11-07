# Building and testing

Run commands from the repository root. Windows is the primary environment:
`build.bat` runs the bundled Lua launcher. Linux/BSD use `lua build.lua` with
the matching bundled native tools and Mono for the sound packers. Sound-tool
rebuilds and native Windows checks are covered by
[the sound guide](../build_tools/sound/README.md) and [AGENTS.md](../AGENTS.md).
The build produces `s2built.bin`, `md-main.lst` and generated sprite bounds.

Python checks require Python 3. Native 68000 fixtures additionally need Unicorn;
emulator runners need NumPy, Pillow and a Genesis Plus GX libretro shared
library exporting the RAM/VRAM and CPU symbols used by `genesis_test_core.py`.
A normal distributed core is not guaranteed to expose these test interfaces.
Core-based fixtures do not require a graphical frontend.

## Touch-response checks

```sh
python build_tools/check_collision_response.py --rom s2built.bin --listing md-main.lst --previous-rom /path/to/before.bin --previous-listing /path/to/before.lst --output test-results/collision-list/native.json
python build_tools/check_collision_response_game.py --rom s2built.bin --listing md-main.lst --core /path/to/genesis_plus_gx_libretro.so --system-directory /path/to/mode1-fixture --output test-results/collision-list/game
```

The native pass covers duplicate/sorted insertion, queue overflow without
truncation, all 90 slots, both player slots before reset, invisible hitboxes,
composite/deleted/disabled rejection, late earlier children and dense re-probes.
With previous ROM/listing inputs it compares every existing size at inside,
touching and outside boundaries, ducking/rolling and both actors, plus ordinary
response categories, in both list and dense modes. Sound/DMA boundaries are
stubbed. Existing upper-RAM symbols are checked against the previous build;
only `Free_RAM_Start` changes because the queue consumes formerly free memory.

The game runner establishes focused scenes in GHZ4, then runs the actual
object dispatcher, primary/companion collision, final-slot ring collection,
invisible hazards and hitbox enable/disable transitions. Add `--player 2 --pal`
for primary Tails/PAL.
These are RAM-established fixtures, not controller-only level playthroughs.
`check_platform_mounts_game.py`, `check_palmtree_enemies.py`,
`check_monitor_edges.py` and `check_ghz_boss.py --core ...` cover real mounted
monitors, enemies/projectiles, rewards and boss hits through the shared path.

Keep emitted JSON/logs in `test-results/`. Whole-frame performance comparisons
must advance both CPUs and include registration, reset and collision work.

## Source and asset checks

Signpost checks use matching ROM/listing pairs:

```sh
python build_tools/check_signpost.py --rom s2built.bin --listing md-main.lst --output test-results/signpost/native.json
python build_tools/check_signpost_game.py --rom s2built.bin --listing md-main.lst --core /path/to/genesis_plus_gx_libretro.so --system-directory /path/to/mode1-fixture --output test-results/signpost/game
```

The native pass covers both entry modes, skipped-window/threshold crossings,
both players' hit boundaries and simultaneous awards, popup ownership,
32-update cooldown, exhausted object pools, camera/terrain wall reflections,
landing exclusions/timing, character portraits and orbit sparkle lifetime,
map-frame bounds and depth. Terrain distances, sound and DMA are stubbed.
The emulator pass boots GHZ1 and establishes focused scenes in RAM, then runs
real actor movement, hits, terrain landing, sparkle rendering, DPLC uploads and
results. The short near-start fast-crossing fixture disables the unrelated
end-of-act art-approach service by stopping the clock before crossing; this is
not an authored-level playthrough. Add `--player 2 --pal` for primary Tails/PAL.
`check_card_screens.py
--case normal` retains the slow, classic finish/results regression.

`check_card_art.py` additionally executes all eleven signpost DPLC frames with
queue backpressure, checks their source pixels and palette attributes, and
calls the real palette loader to confirm Mecha's palette changes only line two.
The signpost game fixture displays animation 5 with that palette as an explicit
scene setup, then returns to the ordinary portraits to check art-cache changes.

Resident end-of-act codecs and their typed PLC path use:

```sh
python build_tools/build_end_art.py
python build_tools/check_end_art.py --rom s2built.bin --listing md-main.lst --output test-results/end-art/native --native
python build_tools/check_end_art.py --rom s2built.bin --listing md-main.lst --output test-results/end-art/game --core /path/to/genesis_plus_gx_libretro.so --system-directory /path/to/mode1-fixture
```

The native pass checks codec tags, D1/D7 preservation, busy module admission,
repeated same-frame calls, final-DMA VInt ownership and counter wrap. Every bank
must match its editable pixels and have an even ROM address. Its decompression
completion is a fixture boundary; the game pass invokes `LoadPLC` through the
actual object dispatcher and checks all seven lists against exact VRAM output.
Use `--pal` for PAL. Importing the old
Nemesis banks is optional and requires an older matching ROM/listing; normal
regeneration uses only the checked-in `.unc` sources. GHZ's native KosM expected
bytes come from the independent Python decoder; its game pass verifies the
owning CPU's actual upload and fight/recovery path.

Mecha's standard fight and SMZ2 trap use:

```sh
python build_tools/check_mecha_sonic.py --rom s2built.bin --listing md-main.lst --output test-results/mecha/native --native --skdisasm /path/to/skdisasm
python build_tools/check_mecha_sonic.py --rom s2built.bin --listing md-main.lst --output test-results/mecha/game --core /path/to/genesis_plus_gx_libretro.so --system-directory /path/to/mode1-fixture
```

Native and emulator entry checks compare frame 2's actual foot baseline with
the floor sensor and the authored SMZ2 floor at `$5C0`.

The optional source oracle assembles the original attack states, raw-animation
interpreter and callbacks, comparing 8,400 updates of positions, velocities,
frames, timers, original flags and RNG when no counter is triggered. The local
grounded/dive flag bits are excluded from original flag equality. Sound/child
effects and a flat floor are fixture boundaries. Native checks also exhaust the
pool at construction, reward and the third-hit shot, exercise both actors and
landing footprint boundaries, reject released/moving/air/dead/solo candidates,
and check harmful rolling collision through touchdown and the fixed foot height.
Head-hit cases run the real touch-damage handler and reject ground/side/rising
contacts; projectile movement and defeat cleanup are executed, not inferred.
Twenty post-counter landings cover both arena halves, landing choices and old
facings through the next jump, checking inward rendered stance throughout the
windup and the counter-specific dash velocity. Shared touch tests check full X/Y/ground-speed
reversal for both actors and all three bosses. Camera cases approach from six
heights, including odd coordinates immediately beside the target. All three
boss defeat entries must request the music fade.

The emulator uses the real SMZ2 placement; controller input crosses the trap.
It verifies the final portrait in VRAM and at least two seconds of warning
before entry on NTSC/PAL, then all attacks run on the authored arena. Use
`--approach above` for a diagonal falling crossing or `--approach below` for
the low-camera approach. Both require bounded camera movement, entry feet on
the floor and the on-screen right boundary. Entering with invincibility and
expiring it must leave Boss 3 playing, checked against the actual Z80 song.
`--companion` uses the second actor for hits; `--player 2 --pal` uses primary
Tails/PAL. These are focused
gameplay fixtures, not a controller-only full-level playthrough.

Eight counter scenes position ordinary landings over actual down+B charges at
both arena edges, with both landing choices and both player facings. They check
player damage without boss damage, floor alignment, inward stance through the
windup and inward follow-up dash velocity through the next jump. A long ground wait supplies
three uninterrupted head bounces: only the first approach is staged, and real
character physics supplies subsequent contacts without position, velocity, HP,
cooldown or streak repairs. It checks the upward shot's VRAM, hardware sprites
and screen exit. The original fight snapshot is restored before sixteen
separately positioned jumping hits through touch collision; no boss HP is
edited. The lifecycle checks the score, real driver fade, defeat/collapse,
exactly one falling sign and the retained body through results and transition.

Hanging-surface checks use the assembled D9 code, player art and shared solidity:

```sh
python build_tools/check_hanging.py --output test-results/hanging/native
python build_tools/check_hanging_game.py --rom s2built.bin --listing md-main.lst --core /path/to/genesis_plus_gx_libretro.so --system-directory /path/to/mode1-fixture --output test-results/hanging/game
```

The native runner exercises both actors, word settings, exact FBZ step offsets,
grab/release, shared solid-object landing, parent ownership and pool retry.
It also checks all 64 grip-count encodings against visible mapping placement,
camera-edge clipping, helper allocation retry, orphan cleanup and reused slots.
DA checks exercise both movement directions and both players together, centred
grabs, exact two-pixel movement, return after the final release, stationary
chains, word settings, pool retry/unload/orphan cleanup, and precise clipped
mapping coordinates through the 1256-pixel maximum chain.
The game runner boots GHZ4 and tests real neutral-jump/regrab physics, traversal
and uploaded poses, terrain and rising-object support, and both simultaneous
standing/hanging arrangements on moving/sagging platforms. It verifies the actual handhold PLC upload,
SAT piece counts/spacing for 1/2/3/8 grips, and camera views across a 63-grip row.
The game pass also checks DA's uploaded chain pixels, both lift directions with
independent releases, and three camera views through the longest chain.
Add `--pal` or `--player 2` for PAL or primary Tails. RAM writes construct disposable scenes;
these are not a controller-only playthrough of authored placements. Current
builds require Mode 1 hardware and its fixture. Use separate processes when
changing ROMs/regions.
Source references are skdisasm `73de97c6b55055bcb8089c1d55d006b02136f163`,
the LBZ unused bar, FBZ chain/array controller and SOZ light switch. This import
adds the lowering/raising chain through DA and LBZ's reversible movement, but
does not add SOZ lighting or controller-to-controller handover.

After a normal build:

```sh
python build_tools/check_ram_ranges.py
python build_tools/check_object_layouts.py
python build_tools/check_sprite_bounds.py
python build_tools/check_sprite_assets.py
python build_tools/check_ghz_vram.py
python build_tools/check_ehz_boss.py
```

To compare terrain edits against a Git revision before the change:

```sh
python build_tools/check_terrain_collision.py --reference OLD_REF --max-angle-change 6 --output test-results/terrain-collision
```

It checks all eight editable terrain sets with four flips, both height/width
silhouettes, all sixteen act/timezone indices per set and every available chunk
cell's tile words, including the starter chunk sets. Both paths must share one
block orientation across all variants. Pre-existing chunk cells beyond a source block sheet must remain
verbatim; they cannot be reconstructed visually from absent definitions and
are counted separately. Protected `$FB-$FF` solids must remain unchanged, and no
shared index may reference an empty row. Legacy S1 banks are read from the Git baseline when
needed; current files must use the single shared bank. The default angle
tolerance is zero; use a larger value only for an intentional, reviewed angle
normalization. The report records actual angle differences separately from
geometry preservation. Add `--previous-rom ... --previous-listing ...` to
compare the actual old/new floor and wall routines around each distinct affected
placed block orientation, with both paths, scan directions and solidity bits.

SMZ's independent act banks use `check_smz_art.py` through the same terrain
checker. It pairs old/new chunks through every layout position in all four eras,
then checks each retained cell's pixels, palette/flips/priority, chunk flags and
both collision indices. It also checks archive/source equality, the water prefix,
starter banks and SonLVL selections. This supports a baseline with the former
shared bank or the independent banks. The split requires an unchanged shared
collision-profile bank. To check the assembled act/era selector as well:

```sh
python build_tools/check_smz_art.py --reference OLD_REF --rom s2built.bin --listing md-main.lst --output test-results/smz-art/report.json
```

The optional native floor/wall comparison pairs SMZ chunks through the actual
layouts and probes both act banks despite their different numeric IDs.

Add `--core ...` and, for Mode 1, `--system-directory ...` to launch all four
GHZ acts, both imported Scrap Madness acts and act 1 of the other terrain sets
with Sonic/Tails, then run both characters through GHZ's loop to a grounded exit. `--pal` selects PAL.
Matching `.unc`/Kosinski+ sources and GHZ/LZ/SMZ SonLVL bank/act selection are
also checked. `--zones GHZ --reference-ghz-bank S1` supports comparison with a
revision before GHZ switched banks; its reviewed angle tolerance must be
supplied separately. Entrance/loop routes do not exercise every level segment.

With a matching pre-edit build, add `--previous-rom ... --previous-listing ...`
to execute both ROMs' real floor/wall routines around each affected chunk cell.
The native comparison covers both paths, both scan directions and positions
inside and across tile boundaries. Distances must match exactly; effective
angles use the explicitly supplied tolerance and must preserve odd-marker
semantics. CD calls execute the real sub-CPU executor through the native
fixture; full hardware scheduling remains the libretro check's responsibility.

The Mode 1 plane engine has a dedicated native audit:

```sh
python build_tools/check_plane_engine.py --rom s2built.bin --listing md-main.lst --output test-results/planes/report.json
```

It executes all 256 real act/era layout selections and 64 plane-record selections,
checks compressed source spans against the built ROM and checks the selected
chunk banks. The assembled CD constructor is compared with an independent
world-coordinate tile oracle, covering unequal/non-power-of-two planes, word
IDs across the entire PRG chunk allocation, all block flips/attributes, row and
column reversals, large camera jumps, fixed 512-pixel bands, blank FG borders,
cache reuse and live block/layout edits. It also executes both camera seams and
ordinary upper/lower clamps beyond `$800`, independently of the tile constructor.
Collision's lookup is checked separately.
Normal builds independently run the Lua file/offset validator.
The SonLVL checker round-trips real layout bytes and probes unequal dimensions
and IDs 768/1023 through the released editor API. `check_plane_streaming.py` checks live visible FG/BG tile words across all eight
authored terrain sets during horizontal/vertical camera excursions, including
GHZ's split hill/water row. It takes the same ROM/listing/core/system-directory/
output options as the SMZ runner. The focused SMZ sweeps check exact parallax
rates, both acts, pause and PAL timing. Native tests do not model those buses.
The plane migration passes Linux/Mono and the Windows CI build in its
`Windows build check` path containing spaces.

The optional 2P scroll-event comparison uses read-only S2 REV01 and skdisasm
sources and the same Genesis Plus GX core:

```sh
python build_tools/compare_ehz_alz_scroll.py --s2-source /path/to/s2disasm --sk-source /path/to/skdisasm --rom s2built.bin --listing md-main.lst --core /path/to/genesis_plus_gx_libretro.so --system-directory /path/to/mode1-fixture --output test-results/scroll-comparison
```

The probe assembles `SwScrl_EHZ_2P` and `ALZ_BackgroundEvent`, including their
actual deformation helpers, scroll-buffer writes and vertical-scroll updates.
It preserves S2 REV01's PC-relative `lea_` configuration and samples both camera
positions/phases. Instructions run in isolated MD RAM with interrupts disabled;
the core's guest cycle counter measures CPU cost, not host execution time.
Camera motion, terrain drawing, DMA and the rest of either engine are excluded.
The two effects have different workloads, so this does not measure whole-game
performance or prove that either algorithm is globally optimal. Source pins
are recorded in [Levels](Levels.md#sources-and-regeneration); reports stay in
the selected output directory.

`check_ram_ranges.py` checks the packed RAM boundaries and palette aliases, then
assembles the real `clearRAM` macro and executes 38 cases in Unicorn: both
addressing forms, odd starts, one-to-nine-byte tails and whole-RAM clears.
Canaries outside each range must remain unchanged. DBF memory counts use declared
start/end labels and their transfer stride; algorithmic/timing counts retain
their own meaning. An empty longword section must not enter a DBF loop with `-1`.

The other checks cover named SST operands/pointer access, mapping geometry,
art/DPLC ranges and compiled PLC allocations. The SST scan cannot prove register aliases
or runtime array indices. `check_object_manager.py` adds native execution of
loading, dispatch/deletion, packed records, Debug, collisions and effect-bank logic.
Use a matching ROM/listing pair; options/defaults differ, so inspect `--help`.
Reusable `Native`/`Manager` fixtures live in `build_tools/native_test_core.py`.
Pass ROM/listing paths explicitly; importing that module neither parses CLI
arguments nor runs the manager regression suite.

`check_word_subtypes.py` executes the eight-byte loader in both CPUs, all era
mask combinations, independent era state, word-valued handler parameters and
Debug spawning. It also rejects byte subtype operands in every live/W.I.P.
object and verifies that moved raw-art labels agree with the ROM. Run it after
a fresh build; a newer listing beside an older ROM is not a valid test pair.
Optional `--before-listing` compares every existing MD RAM symbol/SST field
with a pre-migration build, and `--before-ref` checks the six-to-eight-byte
conversion against a Git revision. Those optional checks are migration evidence,
not a rule preventing later level edits.

```sh
python build_tools/check_word_subtypes.py
```

The released SonLVL checker exercises the custom layout class, 16-bit hex
property converter, all presence masks, full-byte IDs, and property round trips
with both zero and nonzero upper subtype bits. `check_wheel_carriers.py` accepts
`--system-directory` for its Mode 1 payload-table checks.
Card data and queue backpressure also have a native check (requires Unicorn):

```sh
python build_tools/check_card_art.py --rom s2built.bin --listing md-main.lst
```

`check_ss_debug.py` executes rotating-stage placement with exact fixed-point
ties, repeated presses, all grid corners, a sole distant free cell, a full grid,
and cursors outside the authored cells. It checks padding and existing cells,
preserves the dispatch counter, places with a full ordinary SST pool, and
collects the inserted ring through the real item handler.

```sh
python build_tools/check_ss_debug.py
```

## Mode 1 build checks

The standard build always targets Mega-CD Mode 1. Keep each ROM with its
matching listing and use separate output folders. After assembly, run
`check_ram_ranges.py`, `check_word_subtypes.py` and `check_object_manager.py`.
The manager exercises all 768 placement entries per era, including entries
above 255. `check_level_pages.py` enters all 64 acts and the rotating special
stage; run NTSC and PAL with the CD identification-fixture directory.

`check_mode1.py` verifies startup, the required-hardware screen, handshakes,
mailboxes, ownership and corrected Word-RAM DMA. Its optional stack gameplay
fixture checks Sonic/Tails gameplay and water HBlank. `check_smz_background.py`,
`check_player_effects.py`, `check_water_effects.py` and `check_ss_debug_game.py`
exercise their live Mode 1 paths. Effect-upload checks allow bounded scheduling
latency before comparing actual VRAM pixels.

`check_cd_decompression.py` and `check_cd_terrain.py` accept optional external
reference ROMs/reports for historical comparisons. A reference does not add a
second build target. Terrain full-plane fixtures drain prepared CD art DMA
through VBlank before taking Word RAM. Keep both CPUs advancing when measuring
whole-game behavior; main-CPU-only probes cannot service a CD terrain request.

These are emulator/native checks, not real-console verification.

`check_debug_cheat.py --output test-results/debug-cheat` checks the played-ID
sequence, restarts, repeated confirmation, exact ring-jingle requests and every
retired title variant in both regional paths. Add `--core ...` and optionally
`--system-directory ...` / `--pal` to enter level select through the actual title
code, play the sequence with all three playback buttons, verify held-button and
page-switch behavior, then launch directly into Debug with Sonic and Tails.
The checker also verifies the companion pause-control flag, locked controls,
held-B slow motion, press-only C stepping, ordinary Start resume, paused-A
and simultaneous A+Start exits, and zero-lives behavior. Live checks use real
buttons to exercise both primary characters and the rotating stage, then
verify that the complete unlock survives title/level-select returns.
Pause-control references are sonicretro/s2disasm `4ef457c18fc4902396c43ab06fabc119ac6ecb64`
(`PauseGame`) and sonicretro/skdisasm `73de97c6b55055bcb8089c1d55d006b02136f163`
(`Pause_Game`); simultaneous A+Start also retains A when both edges arrive together.

## Runtime checks

The historical Twizzler lag harness has been removed: it patched a retired
block renderer and did not exercise the live independent-plane path. Use
`check_plane_engine.py`, `check_plane_streaming.py` and the CD checks for the
current renderer. [VBlank ownership](Sprites-and-VRAM.md#mapping-and-rendering-abi)
retains the wait-latch/nested-interrupt fix and its cause.

Example for the shared visual regressions (life art, SMZ smoke/flame and boss flash):

```sh
python build_tools/check_visual_followup.py --core /path/to/genesis_plus_gx_libretro.so --rom s2built.bin --listing md-main.lst --output test-results/visual
```

Use distinct output directories per ROM/region/player. Add `--pal` only to runners
that offer it. Most primary-player selectors use `--player 0` (Sonic) or `2`
(Tails), but card-screen fixtures use `1`/`2`; do not assume one interface.

| Area | Runners in `build_tools/` | Scope |
| --- | --- | --- |
| Act data, menus, animation, music | `check_level_pages.py`, `check_act_music.py` | Actual act launches/loaded data; all 64 music selections/restores, expiry priorities and live EHZ/SMZ invincibility restoration |
| Cards, progression and scene transitions | `check_card_screens.py`, `check_fast_clear.py` | Intro/results art; real shoes-monitor to signpost/results/next-act path |
| Player effects and water | `check_player_effects.py`, `check_water_effects.py`, `check_shared_followup.py` | Shields/stars, splash/countdown, normal/paused surface, DMA retries and shared art |
| Monitor state and primary Debug | `check_monitor_state.py`, `check_monitor_edges.py`, `check_debug_states.py` | Rider/collector ownership, contact boundaries, Debug HUD switching, stopped/running clock restoration and Time Over |
| Object lifetime and stage entry | `check_object_lifetimes.py`, `check_giant_ring_entry.py`, `check_object_contexts.py` | Unload/deletion, giant rings and mode-specific objects |
| Companion | `check_companion_followup.py`, `check_companion_hpz.py`, `check_companion_sbz.py` | Ledges, collapse/bridge/manual takeover; actual HPZ routes; 64-phase SMZ transfer and captured catch-up |
| Input locks and rotating stage | `check_over_screen_input.py`, `check_drowning_input.py`, `check_special_stage_overlap.py` | Real deaths/drowning; normal bumper/item callbacks and embedding regressions |
| Rotating-stage Debug | `check_ss_debug_game.py` | Actual controller placement, occupied-cell skipping, ring rendering and collection after leaving Debug in NTSC/PAL |
| SMZ backgrounds, solids and hazards | `check_smz_background.py`, `check_scrap_madness.py`, `check_sbz_discs.py`, `check_smz_vanishing.py`, `check_swing_families.py`, `check_sbz_doors.py` | REV01 parallax/streaming, placed-object lifecycle, transport/ride boundaries and harmful spikeball subtypes |
| Compact clearance/closing doors | `check_duck_clearance.py`, `check_smz_trapdoor.py` | Native 68000 collision fixtures |
| Imported enemies/obstacles | `check_palmtree_enemies.py`, `check_propeller.py`, `check_caterkiller.py`, `check_kemusi.py`, `check_terrain_conveyors.py`, `check_wheel_carriers.py` | Both-actor triggers, motion, damage, unload/reload and source-specific regressions |
| Audio | `check_sound_playback.py`, `sound/build.py --check` | Actual sound paths; encoding/macro/packer checks |

`check_plane_streaming.py --zone 3 --act 2` checks the private EHZ2/PP bank
through actual Mode 1 rendering. Use `--pal` for PAL; the default act remains 1.
Camera excursions respect the selected act's authored vertical bounds, including
the relocated GHZ/EHZ foregrounds. The importer verifies foreground/platform
tile bytes, block/chunk definitions, flower frames and protected object/HUD
palette uses, bounds the five deliberate foreground palette blends to one MD
channel step each, and reports imported background color error. Run it twice
to verify regeneration is byte-stable. The SonLVL checker loads the private Act-2
art and palette with all 64 editor sections. Neither the camera excursions nor
entrance visits are complete controller-only Act-2 playthroughs.
For EHZ2 mountain smoothness, enter Act 2 and hold Right from the start;
check that the distant cliffs follow the camera without three-pixel stair-stepping.
Their VDP horizontal offset must equal `floor(3 * camera_X / 16)`.

`check_ghz_flowers.py --rom ROM --listing LISTING --output OUTPUT --native
--reference COMMIT` executes 640 updates of the actual zone DMA scripts,
checking exact poses/durations, destinations, and the static stalk refresh.
It verifies retired Ballhog loads/placements are absent in all four GHZ acts,
and compares block relocation flags plus unchanged terrain/chunks with the
pre-flower commit. Add `--core CORE --system-directory BIOS --act 1` through
`--act 4` for live frame uploads, neighboring-bank preservation, pause/resume
and positioned flower-cluster captures. `--player 2 --pal` covers primary Tails
in PAL. These captures use diagnostic camera/actor positions, not a complete
controller-only playthrough. `check_ghz_vram.py` checks loaded sprite banks
against the flower allocation, including the contiguous spring/support/spike allocation and boss banks.

`check_level_pages.py` also compares the uploaded menu font pixel-for-pixel
against independently decoded Nemesis art and checks that blank tile zero stays
transparent, on both pages and after returning from a level. Correct text tile
numbers alone do not establish that the font was uploaded to the right place.
Every one of its 64 act launches also runs 90 idle gameplay frames and rejects
a primary-player death, catching terrain/start/death-boundary mismatches.

`check_smz_background.py` checks the VDP's live horizontal/vertical scroll values
and visible background tile words against the S1 REV01 rates and editable SMZ
geometry. It enters both acts, uses ordinary input, then freezes the lead actor
at successive camera targets to cross plane wraps and layer boundaries in both
directions. It covers pause/resume and saves rendered views. Use `--player 0`
or `--player 2`, `--pal` for PAL, and `--system-directory` for Mode 1. The sweeps
are streaming fixtures, not complete controller-only playthroughs.

`check_companion_sbz.py` has `--probe` for older-ROM failures, but no PAL flag.
`check_scrap_madness.py --companion-only` runs both players around the Act 2
running disc for 750 updates, then jumps off with controller 2. Its ledge fixture
starts Tails on the floor under the actual center ledge and requires both
landings with CPU following throughout. `check_swing_families.py` distinguishes
empty spikeball corners from real side and diagonal hits for both players.
`check_swing_motion.py` owns the current Obj17 word settings and twelve shared platform interaction
profiles. It checks full-pool/missing-helper safety, reserved lengths/interactions,
word preservation, both players' solid/damaging contacts under stars and full-word
flashing immunity, speed-scaled ICZ rail input/return, physical-body allocation retry/sole placement
ownership/same-SST release, packed ICZ breakup and contact relay through a static
member. `--before-rom`/`--before-listing` accept the immediately previous unified
single-body swing build for 4,644 exact parent-position comparisons. Quarter orientations,
both placement mirrors and lengths 0–8 produce 37,008 exact rotator pose samples.

```sh
python build_tools/check_swing_motion.py --output test-results/swings/native --s3-source /path/to/skdisasm/sonic3k.asm
python build_tools/check_swing_motion.py --output test-results/swings/game --core /path/to/genesis_plus_gx_libretro.so --system-directory /path/to/mode1-fixture
```

The optional pinned upstream source assembles unchanged SOZ/DEZ integrators and
compares 8,400 angle/velocity/direction/activation/pause samples, adapting the
reference's primary-rider flag to each selected live rider. `--core` adds paired
half-swings, both-player rotator rides, SOZ/DEZ boarding/held pauses/return in all
four orientations for either rider, weak/full-speed ICZ rides, an outward swing stopped by GHZ4's actual arch wall until momentum dissipates, and real GHZ4
terrain bounce/slide versus enabled live-water floating. A floor above water is
checked separately. RAM writes establish disposable fixtures; these are not
controller-only complete level playthroughs. Terrain services and object code
are unmodified in emulator fixtures. Use `--pal` and select a cartridge ROM/listing
for the second build. Each emulator suite starts a fresh process because this
core cannot reliably unload/reload a cartridge in one process.
`check_swing_families.py` checks the same twelve profiles under the live core
in GHZ/SMZ contexts, with both players and flashing immunity, plus actual
momentary-switch press/release checks. It also checks direct underside/body
hazards in both Debug modes for both actors, then uses real button entry,
sixty frames of spikeball overlap in SMZ2 and exit-to-damage checks. It uses
the current word encoding.

The rail mapping generator `build_swing_rails.py` reuses each zone's existing
platform/link mappings. Re-running it must reproduce the three checked-in rail
maps. Sprite bounds checks include them; the SonLVL pass covers all 64 acts and
word-property round trips. No multi-body assembly or carried-object behavior is
claimed by these checks.

Several runners compare with a specific earlier revision; their baseline is
part of the fixture, not automatically the parent commit. Check their CLI/source
before reusing them with an unrelated baseline. Native fixtures use the declared
system stack, map staging and execute CD terrain and placement requests in a second Unicorn
68000. Fixture data is copied to its resident tables at the mailbox boundary;
this tests the assembled algorithms, loading/apply boundary and caller ABI,
not CD bus scheduling. Object fixtures use placement helpers for index handles in the Mode 1 build,
selecting the active era bank on CD or MD. Older cartridge pointer fixtures
remain readable for historical comparisons. The emulator checks below cover that hardware path.

CD boot needs a supplied system directory. Only runners exposing
`--system-directory` support that setup directly (including level pages, act
music, sound playback, visual follow-up, fast clear, player effects, card screens and swing families).
`check_debug_states.py` also accepts this directory for both primary characters'
HUD and hurt/death Debug checks on Mode 1.
Use `--zone 3 --act 2` to exercise the private EHZ2/PP palette: this checks
the live HUD shadow/highlight colors as well as score/time/ring tile uploads,
Debug entry/exit and stopped/running clock restoration. `--player 2 --pal`
selects primary Tails in PAL.
`check_ss_debug_game.py` accepts `--rom`, `--listing`, `--core`, `--output`,
`--system-directory` and `--pal`. It launches the rotating stage through level
select, places twelve rings without moving the cursor, compares every authored
cell after each press, and resumes normal play to collect an inserted ring.
`check_water_effects.py` also accepts `--system-directory`; it covers actual
entry/exit splashes, countdown uploads/rendering and air/number cleanup. Use
`--player 2` for primary Tails, or `--companion` for following Tails, and `--pal`
for PAL. Both roles have passed in NTSC and PAL on Mode 1's HPZ water.
Older companion/shared runners lack the directory option and target the ordinary
cartridge ROM. Do not apply flags universally.

`check_water_tables.py` executes the assembled water-enable, initial-height and
dynamic-routine selection for every zone/act, including all dry slots. It also
enables the final slot with a distinct height in its disposable ROM fixture to
catch residual hardcoded zone/act assumptions. For example:

```sh
python build_tools/check_water_tables.py --rom s2built.bin --listing md-main.lst --output test-results/water-tables/native.json
```

`check_lz_conveyor.py` executes all eight constructors, two circuits per route,
relative translation, allocation retries in fragmented/full pools, whole-path
unload/reload, both riders, switch reversal for normal/spiked groups, per-member
settings, and safe-top/side versus underside-damage/invulnerability cases.

`check_lz_conveyor_game.py` boots the restored LZ1 placements and checks real
boarding/carrying, controller jumping, switch reversal, unload/reload and the
complete live VRAM sheet. It accepts `--player 2`, `--pal` and
`--system-directory`. `--spiked` changes the first group's subtype in an
output-only ROM fixture; gameplay sources and the normal level remain normal.
Its underside contact fixture checks damage/harmlessness for the selected mode.
Reversal waits for the actual latch and observes any already-queued wheel DMA
before checking the reversed frame sequence; a switch press cannot cancel an
upload submitted by the previous foreground pass.
These use scripted positioning around real placements, not a complete route.

`check_lz_wheel_dplc.py` compares one and 70 wheels through forward/reverse
animation, checks their exact queued source/destination/length and register
preservation, then exercises queue pressure, next-frame retry, timestamp wrap
and level-entry invalidation. It checks the compact resident bank and all four
raw source frames against the editable sheet. The live conveyor runner verifies
all four wheel phases in VRAM, their reversed order, and both resident platforms.

## Ordinary platforms and GHZ4 loops

```sh
python build_tools/check_floating_platforms.py --rom s2built.bin --listing md-main.lst --output test-results/platforms/native
python build_tools/check_floating_platforms_game.py --rom s2built.bin --listing md-main.lst --core /path/to/genesis_plus_gx_libretro.so --output test-results/platforms/game
python build_tools/check_ghz4_loops.py --rom s2built.bin --listing md-main.lst --core /path/to/genesis_plus_gx_libretro.so --output test-results/platforms/loops
```

The native platform pass checks independent word settings, absent-frame bounds,
both collision modes/riders, sag on each applicable movement, exact fall and
switch timers, all 16 switch channels, rising-trap acceleration/crushing/ceiling
correction against actual GHZ4 terrain, and long-path ownership/unload/reload.
`--before-ref` additionally audits the placement conversion against Git history.
`--s3-source /path/to/skdisasm/sonic3k.asm` verifies upstream blob
`0f10a373ff0e3d5c0033ed7d13c678bcb927c7b0` from skdisasm `73de97c6`, then
assembles its unchanged horizontal, vertical, diagonal, square and oscillator
code into an isolated fixture region. It compares 45,056 motion samples and
the seven used shared oscillator profiles. This optional reference assembler
step currently uses the bundled Linux x86-64 tools. Other oscillator rows are
outside this object's migration and are not replaced.

The game runner defaults to GHZ4 and checks all 16 movement families plus full
solidity/full falling/reversed long motion through normal object execution,
both-player boarding/carrying, switch rise and rendered output. `--placements`
with `--zone`/`--act` instead sweeps the selected real object layout; all 72
converted platforms across GHZ1–3, EHZ1–2 and HTZ1 were visited. It uses scripted
fixture positioning, rather than a complete controller-only level playthrough.
The SonLVL checker separately verifies that platform flags/channels preserve
shape, placement flags and each other, including unsupported-frame fallback.
The companion follow-up fixture starts its moving ledge through the cached
movement pointer, and waits for actual collection/boarding transitions instead
of assuming that one video frame always includes an object update. Its platform,
bridge, bonus, signpost and 72 real GHZ1 double-ledge runs pass on the cartridge
build.

Both game runners accept `--pal`, `--player 2` and `--system-directory` for
Mode 1's identification fixture. Native checks and the 19 platform fixtures
pass in Mode 1/NTSC and cartridge/PAL. The loop runner verifies GHZ4's matching
Act-3 terrain/pathswapper recipe, then runs controller-driven Sonic/Tails
through all four angle quadrants, both collision paths and a grounded exit.
Screenshots and trajectories remain in the supplied ignored output directory.

## Boss runtime checks

```sh
python build_tools/check_ghz_boss.py --rom s2built.bin --listing md-main.lst --output test-results/ghz-boss
```

`check_boss_shared_art.py --output test-results/boss-shared` executes both
constructors, all five expressions in both facings, persistent exhaust ownership,
S1 flame startup/loop, unchanged palette buffers and recycled-parent cleanup.
Optional `--reference-rom` / `--reference-listing` from pre-sharing revision
`21c233e` compare every S1 hull/pilot/flame pixel, allowing only the selected
seat and lens color changes. EHZ's complete pod must equal GHZ's at Y=-4.

`check_ehz_s1_pod.py --core CORE --system-directory BIOS --output OUTPUT`
boots the real EHZ palettes/planes, loads the compiled boss PLC and verifies
resident S1 pod/head, S2 chassis and common flame bytes. Both acts check entry,
docking, all seven expressions in both facings through the VDP, blue lenses
and continued palette animation. The Act-1 scene suppresses its normal
signpost loader with the act clock; it has no authored boss arena, so its
fixture ends after docking/rendering rather than driving into its ordinary
level geometry.

Act 2 runs the fight in its authored arena: both turnarounds, eight actual
rolling collisions, hit-palette restoration, score, breakup, the complete
48-pixel flame-off lift with no horizontal movement, a stationary chassis and
at least 16 clear pixels beneath the pod at ignition. It also checks the burnt
face through the lift, panic at ignition, departure,
parent cleanup, capsule switch and
animal release. Players are positioned for each attack; damage is produced
by the real collision code. These are staged gameplay checks, not full
controller-only routes.

A frozen chassis is also placed over a real foreground flower in both
facings. A low-priority control must be covered by the flower; the initialized
chassis must draw its opaque white pixel in front. All boss parts must retain
high VDP priority. `--pal` selects PAL; `--player 2` selects primary Tails;
`--act 0` / `--act 1` restrict the run. Captures stay in the supplied ignored
output directory. The shared-art runner's `--core` mode uses the same checks.

`check_ehz_boss_palette.py --s2disasm SOURCE --output OUTPUT` compares all
128 chassis tiles/eight frames with an independently built Sonic 2 final
checkout, preserving the source geometry and intended RGB roles. Native
constructor tests allow exactly one changed palette word, include a failed
allocation/retry, restore an arbitrary saved color at escape cleanup, and run
both palette clocks with the metal shade loaded.

The S1-pod gameplay runner also compares 36 actual VDP frames with/without
the one-word load at each of the entry/fight/escape camera positions. Terrain,
background, player and HUD pixels must match exactly. During the boss, its
palette/CRAM monitor checks all fixed entries, all four foreground phases,
Act 2's three background phases, the resident metal shade and its restoration
after escape. The shared S1 pod/head/exhaust banks are not recolored.

The native pass covers fragmented/full pools and retries, end-of-pool parents,
dry-act water-bank borrowing, staged deployment, the original opening delay,
quarter-speed first pass and timed return sweeps, recycled
child slots, actual hit response,
palette restoration, scoring, independent debris physics on every frame, burst
cadence/RNG, animation duration and act-selected escape music. Rendering/audio
boundaries are stubbed only in these native fixtures.
Breakup checks require a harmless attached chain before any burst, a shared
64-update release after the first burst allocation, and independent debris
afterward. A full-pool case separately delays controller creation and visual
allocation; neither may advance the breakup clock. Recovery cleanup also works
when no explosion could be allocated.
Add `--s1disasm /path/to/s1disasm` for an independent 2,400-frame comparison
against assembled S1 instructions. Use the revision cited in
[Objects](Objects.md#ghz-boss-and-boss-explosions). It reads the original GHZ
boss, swinging-platform, `BossMove` and `CalcSine` sources under `_incObj`,
assembles a small reference fixture with this project's assembler, and checks
ship positions/subpixels, velocities, timers, facing and bobbing every frame.
It also checks the pendulum state and every chain piece after deployment.
Only allocation and hit handling are omitted from that reference; the original
movement instructions and sine table remain intact. The reference's slower
deployment is deliberately excluded from chain-position equality.
The wall checks cover both PLC banks, four-emitter allocation under a fragmented
pool, movement at the level origin and with a moving camera, finite/continuous
burst counts, the normal burst animation and parent/deletion cleanup.

Add `--core /path/to/genesis_plus_gx_libretro.so` for the real GHZ3 arena. It
uses explicit player positioning, observes the original opening pass and eight
timed return sweeps with exact subpixel deltas, then lands eight actual rolling
collisions with the boss. It observes breakup, explosions, escape, ordinary-art restoration and
the capsule switch/animal release. `--player 2` selects Tails and `--pal`
selects PAL. Mode 1 accepts `--system-directory /path/to/bios-directory`.
The report records the first burst and breakup ticks; all pieces must stay
attached and harmless during the wait and release in the same frame. The first
burst-to-release interval is 63-64 rendered frames depending on SST update order,
with exactly 64 parent-clock updates before release.
Screenshots and the JSON report belong in the selected output directory.
The native burst tests cover both GHZ/EHZ profiles; this arena run covers GHZ,
not a controller-only playthrough or EHZ's entire fight.

Add `--explosion-wall` with `--core` to run the unused wall entry point instead
of the boss fight. This fixture queues its compiled PLC and allocates the wall
in EHZ1, checks that both effect sizes render with matching art banks, and waits
for the wall, emitters and visuals to finish without producing animals.

## Mega-CD checks

Build the Mode 1 image with the standard build command, then create the
emulator identification fixture and use its directory:

```sh
python build_tools/check_mode1.py --core /path/to/genesis_plus_gx_libretro.so --rom s2built.bin --listing md-main.lst --output test-results/mode1
python build_tools/check_cd_terrain.py --core /path/to/genesis_plus_gx_libretro.so --system-directory test-results/mode1/identification-fixture --output test-results/cd-terrain
python build_tools/check_cd_chunks.py --core /path/to/genesis_plus_gx_libretro.so --system-directory test-results/mode1/identification-fixture --output test-results/cd-chunks
python build_tools/check_cd_ring_jobs.py --core /path/to/genesis_plus_gx_libretro.so --system-directory test-results/mode1/identification-fixture --rom s2built.bin --listing md-main.lst --output test-results/cd-rings
```

`check_cd_dispatch.py --rom s2built.bin --listing md-main.lst` executes the real
service loop in Unicorn with job stubs that destroy all registers except SP
and their result. It covers 1,536 requests: every command byte with three high
bytes, immediate and delayed requests, token complements, result/flag publication,
stack balance and guards. Add `--core ... --system-directory ... --output report.json`
for isolated sub-CPU timing, optionally with `--baseline-rom ... --baseline-listing ...`.
The native fixture mirrors sign-extended absolute-short mailbox accesses onto
their physical 24-bit addresses, as the real sub-CPU bus does.
Timing freezes MD execution and uses fixed jobs; it measures dispatcher overhead,
not complete RPC latency or game-wide performance. Compared with the unrolled
service with long mailbox operands, ordinary jobs save 32 cycles and former
two-register-preserving jobs save 84; no-op/ping/return-RAM/unknown replies cost
2 more cycles. The short mailbox operands save 20 cycles per serviced command
against the previous compact loop. Idle polling
retains its read/compare/conditional-branch loop.

Add `--stack-gameplay` to `check_mode1.py` to watermark unused MD stack space
without overwriting live return frames. It covers HPZ loading, Sonic+Tails and
solo Tails gameplay, and underwater HBlank in the selected region, preserving
a lower 32-byte guard. These written-depth samples and frame-boundary SP checks
are fixture coverage, not a proof of worst-case depth on every path.

The four emulator runners in the command block offer `--pal`. For an old/new
terrain comparison, run the previous ROM
with `check_cd_terrain.py --baseline --rom ... --listing ...`, then pass its
`report.json` as `--reference` to the current build. Use separate output folders.
`--zone 1` exercises LZ and `--zone 0` or `2` GHZ/CPZ; all use the shared bank. Use
a reference with the same collision assets for executor comparisons; the GHZ
remap uses the shape comparison above. The terrain runner compares
1,216 full actor/sensor calls, six complete plane constructions and controller
walking against the reference. It also checks 600 jumping frames and free-RAM
canaries; these are not asserted frame-identical to the previous engine because
scene scheduling can shift NPC/random phases. Reported CPU costs include the
mailbox wait, not just the CD routine.

 `check_cd_chunks.py` uses the root `s2built.bin`/`md-main.lst`
directly; it has no ROM/listing flags. It checks all 256x64 chunk/block addresses,
CD row/column stream records/flips/edges, ordinary frames and a rotating stage, with
remaining-free-MD-RAM canaries. It also poisons the player-art cache before
entering the rotating stage, checks that stage's RAM-to-VRAM ring upload, then
returns through results and verifies all three level sources are rebuilt.
`check_player_effects.py` compares RAM sources and actual VRAM against editable
art, including all eight regular/lost-ring frames and shield/star transitions.
`check_tunnel_shields.py --output test-results/tunnel-effects` executes the real
dispatcher, both shields, both star composites and a tunnel: all 113 object
slots must update exactly once in normal and dense collision modes. Native
checks compare final owner/shield positions and both leading orbit coordinates.
Add `--core /path/to/core.so --system-directory /path/to/mode1-fixture` for the
authored SMZ2 route with real players and rendering; `--stars` selects stars,
and `--player 2` selects primary Tails. `--tunnel 2` selects the curved route
with a visible horizontal corridor; the default route 0 crosses the Y wrap.
`--before-rom/--before-listing` can
demonstrate the old movement-frame lag, rather than merely testing a stationary
effect. Orbit history/phase and hardware art transitions have separate checks.
Run `python build_tools/build_player_effect_art.py --check` after source-art edits.
Ring tests cover sparse/all-active lifetimes, staggered
collection, bank pauses, reset, expanded-tail guards and HPZ/SMZ gameplay in both
character modes. To measure the previous CD implementation, pass its ROM/listing
with `--baseline` to the ring runner; it is a boolean mode, not a path argument.

The identification fixture contains only the `SEGA` marker, not BIOS code.
See [Mega-CD](Mega-CD.md) for ownership contracts and hardware-test limits.

For codec equivalence, retain a ROM/listing pair from before CD decompression
offload, then run:

```sh
python build_tools/check_cd_decompression.py --baseline /path/to/old.bin --baseline-listing /path/to/old.lst --output test-results/cd-codecs
```

This executes every linked compressed span with the original MD decoder and
the new CD executor in Unicorn, including every Kosinski module, Nemesis XOR,
and Enigma base-tile attributes. It checks source spans, lengths, consumed input
and output guards. Resumed PLC batches also run an unrelated general decode
between steps and force time-budget yields across stopwatch wrap. This proves
codec/state behavior, not hardware bus scheduling. Pair it with Mode 1, act
launch, ring and player-effect checks. `check_sound_playback.py` accepts
`--system-directory` to validate the CD-decoded Z80 driver through actual music,
effects and jingle restoration.
For complete music-stream equivalence and per-frame Z80 state comparisons,
see the [sound validation guide](../build_tools/sound/README.md#validation).
When comparing streaming code against the previous ROM, use
`--include-unchanged` to compare playback of the same decoded score bytes.
Exercise both resident uploads and paged scores in NTSC and PAL.
Run dense tracks in Scrap Madness and GHZ4 to exercise VBlank refills alongside
ordinary stage updates and the water split. Check the countdown and the current
act's track after resurfacing. The `--priority` playback case covers bumper/Continue arbitration; `--switches`
traces DPCM accumulator continuity during rapid level-select song changes.
Add `--core /path/to/genesis_plus_gx_libretro.so --system-directory ...`
to the codec runner for actual queued PLC uploads while HPZ's early water
HBlank split is active; it compares VRAM with the old decoder and checks
resident blocks and the entire expanded chunk allocation for changes.

After ROM bank-layout changes, compare stored song payloads and playlist flags
with the preceding ROM, run the playback checks in both regions, and exercise
`check_level_pages.py` plus both-act `check_plane_streaming.py` checks. These
cover relocated pointers, all act launches and live foreground/background words;
`check_ghz_vram.py` checks the compiled sprite-art sources and mapping ranges.

## Disposable object course

The builder copies the checkout, replaces LZ2 with an instrumented flat course,
switches art banks by section, and builds that copy. **Build output must be outside
the checkout.** Fixtures position actors; real collision, animation, spawning,
renderer, PLC and DMA code executes. This instrumented ROM is unsuitable for
performance profiling, and later SMZ/PP imports need their focused native-level tests.

```sh
python build_tools/build_object_course.py --output /tmp/mystic-object-course
python build_tools/check_object_course.py --build /tmp/mystic-object-course --core /path/to/genesis_plus_gx_libretro.so --output test-results/course-sweep
python build_tools/check_object_interactions.py --build /tmp/mystic-object-course --core /path/to/genesis_plus_gx_libretro.so --output test-results/course-contacts
python build_tools/check_object_contexts.py --build /tmp/mystic-object-course --core /path/to/genesis_plus_gx_libretro.so --system-directory /path/to/mode1-fixture --output test-results/course-stage --case stage
python build_tools/check_object_contexts.py --build /tmp/mystic-object-course --core /path/to/genesis_plus_gx_libretro.so --system-directory /path/to/mode1-fixture --output test-results/course-warp --case warp --player 2
```

On Windows use equivalent absolute external output paths. Sweep/contacts support
`--pal --player 2`; `--bank N` narrows the sweep and `--filter REGEX` contacts.
Instrumentation records actual entry-point execution; `layout_id` is only a
test-side projection of routine pointers, not the SST dispatch format.

The diagnostic course keeps the ordinary water-surface bank at `$001`; only
prototype enemy banks move. A legacy wall uses `$590`, overlapping normal
explosion art, only in its isolated section. Fresh snapshots restore explosion
art for enemy/effect cases. This cannot certify that allocation in a populated
level. Bundled test-only S1 floor/door art has provenance in
`build_tools/object_course_art/sources.json`; LZ palettes do not certify zone colors.

The stage-context runner uses the current level-select entry, seven results
objects and an explicitly staged successful-attempt flag. `--player 2` selects
Tails in the stage as well as in the return level. Real emerald pickups are
covered separately by `check_seventh_emerald.py`; this course runner checks
instrumented object execution and the return transition. Coverage uses a hook
at the ordinary/touch dispatchers, with a last-code cache per slot in the
already reserved free test RAM. Object bodies keep their original instruction
layout, avoiding short-branch and PC-indexed-table range failures caused by
per-entry stamps. The hook preserves registers and CCR. This instrumented
image is not a performance reference.
Generated test sources and metadata retain CRLF.
`check_special_stage_overlap.py` accepts `--system-directory` and treats cyan
as passable in its independent wall oracle. It retains real bumper, DOWN and
GOAL callbacks and ordinary-movement embedding coverage.

## Reports and evidence

Keep generated JSON, screenshots, WAVs, ROM hashes and per-file matrices in
explicit output directories, never `docs/`. `/test-results/` is ignored. Preserve
ROM/listing, source revision, core identity, region/player options and report
together when retaining evidence. Git history contains the removed historical
snapshots; their source counts and ROM hashes did not certify the current build.

The coverage summarizer inventories the **current source** and checks the
supplied reports; it does not run the game or prove that old reports match the
current ROM. Supply matching runs/bosses/demos covering the live IDs it requires:

```sh
python build_tools/summarize_object_course.py --run Sonic-NTSC=test-results/course-sweep/report.json --output test-results/object-course
```

This minimal example fails if the supplied reports leave live implementations
uncovered. Repeat `--run name=path`, `--boss GHZ-name=path` / `EHZ-name=path`, and
`--demo name=path` as needed. Include `--conveyor name=path` with a matching
`check_lz_conveyor_game.py` report for `$1F`. Successful output is `report.json` and `coverage.md`
in the selected directory. Helpers receive no inferred runtime certification
from object IDs; inactive/W.I.P. sources are inventoried, not gameplay-tested.

Known limits remain explicit: Gator lifecycle/rendering does not certify its
broken gameplay; the compiled title
palette handler is unfinished/unspawned. Representative subtypes and positioned
fixtures are not exhaustive/controller-only playthroughs. Rare monitor-route
reproduction and full revised companion routes remain incomplete. SonLVL paths
and previews can be checked without certifying an interactive desktop-editor run.
Emulator checks do not establish physical Mega-CD compatibility.

The platform-parity checks exercise both `$17` and `$18` through the shared
collision code: all twelve profiles, both players, upward/top/side contact,
full-word flashing immunity and stars, and one conveyor push per update in both
directions. Hanging fixtures cover each top/full/conveyor grip, simultaneous
standing/hanging, allocation retry, parent cleanup and unchanged body/grip
ownership across release. Native fixtures also test an earlier body slot, paused
body movement with active sag, full-pool release without allocation or rider-index
changes, reused body/helper protection, orphan cleanup before/after release,
and all three new body appearances against GHZ/SLZ/SMZ mapping bottoms.
The falling-conveyor/grip fixture checks the ordinary platform's
stationary 30-update delay, rider carry and eventual grip release. Migration comparison
uses `check_floating_platforms.py --before-ref` against the preceding platform
encoding; coordinates, placement flags, eras and unrelated objects must match.
The live GHZ4 floor tests also compare safe top-only passage with full-solid
crushing for either hanging player, with and without a conveyor. Stars do not
prevent crushing. Both Mode 1/NTSC and cartridge/PAL run these fixtures.

`check_floating_platforms.py` also checks 174 falling-after-arrival combinations:
all movements, phases/corners and either/both riders, no-rider safety, the latched
request after a rider leaves, oscillator-rate/corner/long-path endpoints, all
sixteen switch channels and a real ceiling stop. `check_floating_platforms_game.py`
combines the bit-12 option with stationary, horizontal, vertical, diagonal,
square, long eased and switch-rise motion under the normal object executor.

The ordinary-platform core fixtures include standalone body, rail and ball
shapes with top/full solidity. The swing comparison accepts a matching
`--before-rom`/`--before-listing` pair from before the suspension/body split.
Attached body execution is parent-driven; released body execution is autonomous
with the retained ballistic/terrain/water controller. Custom post-release motion
recipes and multi-body chain arrangements are not covered or implemented.

Use the full-frame swing suites above for Mode 1 hardware scheduling and
the native motion fixtures for isolated object behavior. Keep reports in
`test-results/`; native fixtures do not model real hardware timing.

## Platform-mounted objects

Use matching completed Mode 1 ROM/listing pairs. Core runs need
`--system-directory /path/to/BIOS-fixture`.

```sh
python build_tools/check_platform_mounts.py --rom s2built.bin --listing md-main.lst --output test-results/platform-mounts/native
python build_tools/check_platform_mounts_game.py --rom s2built.bin --listing md-main.lst --core /path/to/genesis_plus_gx_test_libretro.so --output test-results/platform-mounts/game
```

The native pass exercises all six platform constructor IDs, all 64 mount values,
all eras and existing placement flags; every independent swing artwork/interaction/
payload constructor; full and partial pools; reused slots and orphans; either
player riding a payload, spring strengths, falling/sag, no-allocation detach,
button-channel cleanup and persistent broken monitors. The core pass boots GHZ4,
checks the portable button's actual PLC bytes, then runs moving regular/swing
payloads with either SST allocation order and both-character button landings, monitor breaks/collector rewards and spike damage.
It saves scene captures for visual inspection. Fixtures position actors/objects
in RAM; this is not a controller-only playthrough of authored levels.

`check_sonlvl_objects.cs` verifies mount selection and era/flip/any-Y/full-word
preservation through properties and layout I/O, including reserved codes and
independent artwork IDs. `check_ghz_vram.py` covers the optional GHZ4 button bank
and mappings. `build_platform_button.py` must reproduce its three outputs from
the resident SMZ source atlas/mappings. Repeat the swing, floating-platform,
hanging and wheel-carrier regressions when changing shared payload handlers.
The ICZ swing fixtures explicitly choose the rail-art constructor: movement no
longer silently selects artwork. Relay tests preserve the executor's D7 counter
on every active exit.

## GHZ4 water playtest

`check_ghz4_playtest.py` boots the authored Act-4 placements and water tables.
Its entrance route uses controller inputs only after boot: jump over the two
existing monitors, land/brake on the carried button, detach and ride the same
body into the entrance-gap water, where its terrain bank stops the drift. Focused visits position actors in RAM to
exercise the actual placed red/yellow springs, momentum-platform monitor,
moving spikes, and Sonic-above/Tails-below detachment into water. Those visits
retain the live placement manager, collision and object executor.

```sh
python build_tools/check_ghz4_playtest.py --rom s2built.bin --listing md-main.lst --core /path/to/genesis_plus_gx_test_libretro.so --output test-results/ghz4-water/play
```

Mode 1 needs `--system-directory /path/to/BIOS-fixture`. Use `--player 2` for
primary Tails, or `--pal` for PAL timing. The runner checks all four underwater
palette lines and all four waterfall phases, and saves route/station captures
and a controller-route trace. `check_swing_motion.py` additionally runs 1,024
real oscillator updates to catch float-position/rate confusion and sign-wrap
jumps. Re-running `build_ghz4_water_palette.py` must reproduce both palette files.
GHZ4 reserves the normal water-surface bank; its lower camera limit allows the
water to be reached before death. GHZ1-3 remain dry and keep their wall borrowing.

## Terrain collision across the Y seam

`check_y_wrap_terrain.py --rom ROM --listing LISTING --output OUTPUT` executes
the real MD level-load request and CD terrain setup for HTZ2 and SMZ2 in all
four eras. It checks chunk addresses, floor/wall distances and angles in both
directions and collision paths, including negative Y and sensors past `$800`.
The plane constructor's foreground tiles are compared with a wrapped world
oracle, including live script edits through the seam. A separate 32-row
non-wrapping fixture must retain terrain above `$800`.
This uses the optional Unicorn package.

Add `--core CORE --system-directory BIOS` to drop Sonic and following Tails
onto SMZ2's actual starting-pit floor at two speeds, and to hit an authored
ceiling while moving upward through the top seam. `--player 2` tests primary
Tails instead; `--pal` selects PAL. Positioning is staged, while subsequent
movement/contact uses ordinary game frames without terrain edits. `--probe`
records an old ROM's failures without treating them as a pass.
The same game pass enters all eight authored SMZ2 transporters, supplies the
secret route's required rings and follows each path through release. Every
frame's visible FG/BG tile words are compared against authored geometry using
the VDP's actual scroll values. This includes both upward and downward camera
seams. It saves stills and GIF captures of the two seam-crossing tunnel routes.

## Companion recovery and lost rings at the Y seam

`check_y_wrap.py --rom ROM --listing LISTING --output OUTPUT` runs the real
68000 pursuit code with 72 wrapping/non-wrapping source/target pairs. It checks
ten signed-velocity ring trajectories, canonical wrapped positions, independent
255-update expiry/blinking, all 32 scatter timers, collection/sparkle cleanup
and ordinary non-wrapping bottom culling. It needs the optional Unicorn package.

Add `--core CORE --system-directory BIOS` for the live Mode 1 fixture. It uses
SMZ2's actual subtype-7 transporter: 49 rings must fail, 50 must enter the secret
route. It first rejoins Tails from below, then repeats direct recovery,
offscreen-flight timeout, staged death and another recovery. This retains game
scheduling and AI, while explicitly staging the offscreen/death states. It also
scatters 32 rings at both sides of the seam with real terrain probes, suppressing
collection afterward to isolate movement/expiry. `--pal` selects PAL;
`--probe` records an old build's failures without treating them as a pass.

`check_over_screen_input.py` also checks the shared V's actual loaded VRAM
pixels and opaque on-screen pixels in both GAME OVER and TIME OVER. Its
`--system-directory` option selects the Mode 1 BIOS directory. The palette
validator rejects red slots in the editable V quartet. `check_ss_debug_game.py`
checks all eight movement directions, single-frame taps, held acceleration,
stops and immediate reversals: the live/copied camera must match the cursor's
final position, and its rendered sprite anchor must stay fixed. Run `--player 2`
for Tails and `--pal` for PAL; the same run retains the grid-placement/collection
checks. These are controller-driven Debug checks after entering the real stage.

## Shared palette migration

For the shared small UI font, run `build_hud_art.py`, then
`build_card_art.py` and `build_special_results_art.py` before building.
`check_card_screens.py --case special --rings 50` checks both distinct continue
poses against their six-tile VRAM payloads; run Sonic and Tails selections.
It also checks that the CONTINUE lettering resolves to yellow independently
of the portrait's palette selection.
The normal-results and Debug-HUD checks also cover the shared counters.
`check_seventh_emerald.py --output test-results/cyan/native` checks seven
awards, duplicate rejection, the following RAM word, seven result objects,
color-specific 4-over-3 positions, both draw/hidden blink phases, and all 896
ownership/next-stage combinations against the seven real layout pointers.
Add `--core /path/to/core.so --system-directory /path/to/mode1-fixture` for the
real stage pickup/goal/results fixture; run `--player 1` and `--player 2`. It
enters the actual Stage 7 from level select with six owned emeralds and verifies
its cyan layout and reset attempt flag. It cycles all eight Debug entries in
both directions, then stages cyan/gray for a normal collision-driven double
pickup and real goal exit. `--pickup-count 1` covers partial success; `--fail`
uses a real GOAL with six previously held emeralds. These are positioned
fixtures, not controller-only full-stage routes.
`check_card_screens.py` also checks settled heading pixels against their mapping
positions: single-line headings start at screen Y=52 and two-line blocks at
Y=40/64, all centered on the oval at `(160,60)`. With at least 50 rings, it
checks the one-pixel T-I gap in CONTINUE from loaded VRAM and rendered gold ink,
including both character portraits and both animation poses. Sonic's source
dark-red shoe pixels must load and render as the third red, never orange.
All-seven success also checks the timed Super announcement, its rendered Y=40/64 lines, both
headings' centers against the oval, initial two-sided assembly, completed
tally before the post-tally/Continue delays, the full announcement hold, opposed
exit/entry speeds, both old halves offscreen before the swap, the fixed oval
and the unchanged resident glyph bank. Moving white pixels are checked against
clipped VRAM glyph positions, including the screen edges. Add
`--record-transition` to capture the opening assembly and complete announcement
as an emulator GIF through the end of its display window. The fixture resets
ring/score inputs after the stage exits and before the results constructor, so
incidental stage pickups cannot change the requested case. Use `--rings 0`
for the no-Continue route and `--rings 999` to catch an announcement that races
a large bonus tally. Native checks pin the S3&K post-tally timers to
120/270/240 updates, reject the announcement for failed or partial results and
verify that it does not enable transformation gameplay.
`check_card_screens.py --case special --emeralds 6` must show SPECIAL STAGE;
add `--collected` for the character-specific successful heading, or use seven
with that flag for GOT THEM ALL. `check_card_art.py` executes all 600 displayed
finish times and a full secret-bonus tally. `check_card_screens.py --case normal
--time-seconds 599` checks the actual 100,000 display and five-digit VRAM strip.
The compact HUD uses one-tile numeric glyphs. Debug switching must preserve
the reclaimed thirteen-tile range between `ArtTile_HUD_End` and the points
bank; `check_debug_states.py` compares it throughout its redraw cases.
`check_sprite_assets.py` checks the ten-letter resident subset and every HUD
piece's tile range. Both results screens must render RINGS lettering, with
no special-results ring loader or source; rotating-stage ring assets remain.
For LZ water colors, inspect the same background above and below the waterline:
correct palette bytes alone do not establish that imported shading ramps work.

Run `python build_tools/check_sprite_palettes.py --output test-results/palettes/report.json`
for current level rows, spring attributes, underwater regeneration and results
emeralds. Its optional `--reference REV` mode was written for the shared-palette
migration and also compares decoded terrain RGB, with CPZ's intentional
red/brown restoration. This is a historical, baseline-specific comparison:
later EHZ flower/PP remaps cannot be assumed RGB-identical to an unrelated old
revision. Use the current EHZ waterfall/reflection checks for those assets and
their live palette phases instead of treating a migration baseline as a
whole-project golden image. Rotating-stage private source pixels,
including all five Sonic rolling poses, remain exact. Its palette comparison
allows the three documented first-row warm colors and P1's four cyan-ramp
entries, including the dark blue in F; it also rejects a collapsed Tails fur ramp.

`check_special_stage_players.py --rom ROM --listing LISTING --core CORE
--system-directory BIOS --output OUTPUT --player 2` enters through the real
menu, verifies complete cloud/opaque-transition uploads before display enable,
and samples 180 ordinary gameplay frames. It compares compact body/tail VRAM,
parent following, live sprite-table presence and the authored stage palette.
Run `--player 1` for Sonic and add `--pal` for PAL. Eight velocity fixtures in
an unchanged empty layout area exercise all four tail directions; both Debug
modes and the real goal-exit routine are checked too. Direction and goal states
are explicitly staged; this is not a controller-only stage completion.

Regenerate life, spring, player-effect, hanging, conveyor, signpost, card,
special-results and underwater outputs with their owning build tools. Verify
matching ROM/listing pairs with sprite assets/bounds, card art, end art and
Mecha native checks, plus GX HUD, cards, effects and plane streaming checks.
Positioned camera/actor screenshots are diagnostic captures, not controller-only
playthroughs. RGB preservation alone cannot detect a preserved historical bug.

## EHZ waterfall animation and sprite pressure

`build_ehz_waterfall_art.py --check` verifies the packed object bank.
`build_ehz_reflection_art.py --check` verifies the inverse reflection frames
against the two original terrain spans and checks the packed terrain bank.
The spring packer/palette check rejects per-act
color indices in the packed spring atlas. `check_ghz_vram.py` verifies the
vertical/horizontal/diagonal/support order, adjacent spikes and all 64 act
PLC selections. Check both colors, both diagonal directions and X flips in
real emulation: the support must remain stationary while all three plate/coil
poses animate. Check the linked SAT, rather than stale entries beyond its
terminator, when counting those hardware sprites.

`build_seesaw_art.py --check` verifies the full-height 62-tile S1 seesaw atlas.
Use its optional `--source /path/to/s1disasm --check` to compare against the
pinned original art and converted mappings. `check_ghz_vram.py` additionally
rejects EHZ/HTZ object PLCs overlapping their actual terrain or each other,
and checks every seesaw mapping against the loaded bank in all eight acts.

```sh
python build_tools/check_ehz_terrain.py --rom s2built.bin --listing md-main.lst --core /path/to/genesis_plus_gx_libretro.so --system-directory /path/to/mode1-fixture --output test-results/ehz-terrain
```

This runner checks real resident terrain pixels as well as tilemap words,
excluding the named water/flower/reflection animation banks. It stages the
otherwise-unplaced restored S-tunnel in both acts, then runs complete Sonic
and Tails traversals on both collision paths without position/velocity repairs.
All five platform bodies receive real landings; both terrain shapes also
exercise all four placement flips and verify mapping tile bytes. The wall check
places the actual Debug entry in each act, compares the cursor and placed
pixels to the four authored quarters, and breaks it by rolling from either
side. It also re-enters Act 1 from Act 2 and checks the cleared VRAM gap. The shared
S1 seesaw is checked in both EHZ acts and HTZ: complete resident art, all three
tilts, player landings and spikeball launches in both orientations. Add `--pal`
for PAL. These are disposable gameplay fixtures, not full controller-only
playthroughs of the authored levels.

`check_player_interactions.py --output test-results/player-interactions` covers
all 256 ground angles and held-frame delays for both pushing animations, the
character-specific tumble ranges, independent wall impact speeds/contacts, and
owned/stale rider release. `--probe` records an older ROM's failures. Add the
same `--core` and `--system-directory` arguments as above for real authored EHZ
corkscrews in both directions, visible sloped-wall pushing, and controller-driven
spindash wall breaks by Sonic, solo Tails and controller-2 sidekick Tails in both
acts. Add `--pal` for PAL. Only scene/initial-state setup uses RAM writes; the
spindash charge, release, contact and fragmentation use ordinary game code.
The older S-tunnel runner starts in a rolling ball, so it does not validate the
walking/running corkscrew animation.

Terrain repacks must preserve every reusable authoring chunk, including those
not placed in any era. Compare old/new chunk pixels, tile attributes and both
collision paths; then compare every foreground/background layout cell through
its remapped chunk ID. SMZ acts share their full foreground collection and
exclude only the opposite background. Keep the custom Mecha floor and starter
blocks 0..5. Run `check_y_wrap_terrain.py`, `check_mecha_sonic.py` and the plane
streaming sweeps after repacking; a successful decode alone does not test the
collision seam or arena. EHZ wall/platform object mappings must also follow
the relocated terrain art.
`build_ehz2_waterfall_art.py --check` verifies the baked PP animation and its
water palette script. The PP importer reproduces the private terrain bank and
source waterfall tiles from the pinned CD source documented in [Levels](Levels.md).

`python build_tools/check_ehz_waterfalls.py --rom s2built.bin --listing md-main.lst --output test-results/ehz-waterfalls`
checks every baked pixel against the original PP colors, verifies all 4,352
reflection-pose pixels keep their RGB colors through the grouped cyan cycle,
checks both reflection DMA destinations and deferral with fewer than three
free queue entries, executes both independent Act-2 palette clocks (four
foreground phases every eight active updates and three PP water phases every
nine), then palette/DMA
updates, and renders a native scene using the authored four-column Act-2
waterfalls, separated players, an approaching snail and 32 rings. This is a
controlled pressure fixture, not a controller-only route. Optional
`--before-rom ROM --before-listing LISTING` confirms the old snail starvation
and compares visible mapping pieces at 80 edge/flip cases. Add `--core CORE
--system-directory BIOS` to boot Act 2 in the emulator, verify complete DMA
poses and three live palette phases, and save an animation. Add `--act 0`
for Act 1: it checks the actual VRAM tile bytes against hardware CRAM through
all four phases, so a flashing cloud reflection fails even if the CPU-side
palette buffer looks valid. Native checks use the optional Unicorn dependency.
The Act-2 live pass also samples the real VRAM cloud tiles against hardware
CRAM throughout both independent palette clocks; fixed cloud pixels must not
pulse with either waterfall or water phases.
