# Building and testing

Run commands from the repository root. Windows uses `build.bat`; Linux/BSD use
`lua build.lua`, the matching bundled native tools and Mono for the sound
packers. The sole target is Mega-CD Mode 1. A successful build produces
`s2built.bin`, `md-main.lst` and generated sprite bounds. Keep each ROM with its
matching listing. See [AGENTS.md](../AGENTS.md) for Windows compatibility checks
and [the sound guide](../build_tools/sound/README.md) for packer builds.

## Dependencies and fixture boundaries

Python checks require Python 3. Native 68000 fixtures need Unicorn. Emulator
runners need NumPy, Pillow and a Genesis Plus GX libretro library exporting the
RAM/VRAM and CPU symbols used by `genesis_test_core.py`; ordinary distributed
cores may omit them. No graphical frontend is needed.

The shared libretro runner also reads stock ClownMDEmu's advertised RAM maps.
Sound-test `--startup` runs there in NTSC; CPU/bus tracing still requires Genesis
Plus GX exports. This does not make every existing fixture core-independent:
ClownMDEmu 1.6.12 cannot complete this project's PAL stopwatch wait, and the
full Mecha fixture's final-portrait VRAM check fails on both the preceding and
current ROM before it reaches the fight. Use Genesis Plus GX for that full
fight assertion. See the sound guide for audio-specific boundaries.

Use a fresh process for each ROM/region: this core cannot reliably unload and
reload different cartridges in one process. Give every run its own output
folder. Runners have different interfaces; inspect `--help` before copying
options. Most use `--player 0`/`2` for Sonic/Tails, while card and rotating-stage
player checks use `1`/`2`. Only pass `--pal` or `--system-directory` where offered.

`native_test_core.py` owns reusable `Native`/`Manager` fixtures without executing
a test suite on import. Its second Unicorn CPU executes CD terrain/placement
requests at the mailbox boundary. This checks algorithms and caller ABI, not
bus scheduling. Native sound, allocation or DMA stubs are documented in each
runner. Whole-frame measurements must advance both emulated CPUs and include
mailbox waits, registration, reset and transfer work.

RAM writes usually establish scenes, initial state or fault injection; movement,
collision and rendering then execute the built game. Such fixtures are not
complete controller-only level playthroughs. A Git/ROM reference must match the
operation being compared, not merely be the parent commit. Historical migration
comparisons cannot forbid later intentional art, palette or layout edits.

## Source and asset checks

After a normal build, the common checks are:

```sh
python build_tools/check_ram_ranges.py
python build_tools/check_object_layouts.py
python build_tools/check_word_subtypes.py
python build_tools/check_sprite_bounds.py
python build_tools/check_sprite_assets.py
python build_tools/check_ghz_vram.py
python build_tools/check_ehz_boss.py
python build_tools/check_object_manager.py
```

| Runner in `build_tools/` | What it checks / special inputs |
| --- | --- |
| `check_ram_ranges.py` | Packed RAM boundaries, palette aliases and actual `clearRAM` instructions, including odd starts, short tails, DBF counts and canaries |
| `check_object_layouts.py`, `check_word_subtypes.py` | Eight-byte records, word settings, era masks, MD/CD loaders and Debug; optional `--before-ref`/`--before-listing` audit a specific migration |
| `check_object_manager.py` | Loading/dispatch/deletion, all 768 placements per era, indices above 255, Debug, collision and effect-bank behavior |
| `check_scattered_rings.py` | Original sine reference versus 216 allocation/count/water cases, both-player single rewards and exact sparkle timing, goddess proximity/fifty-emission/full-pool behavior and both-character cage phases |
| `check_sprite_bounds.py`, `check_sprite_assets.py` | Compiled mapping geometry, initialization bounds, SST operands and art/DPLC ranges; static scans cannot prove register aliases/runtime indices |
| `check_ghz_vram.py` | All 64 act PLC selections, sprite-bank overlap, spring/support/spike order, seesaws, boss banks and optional mounted-button art |
| `check_sprite_palettes.py` | Shared slots, spring attributes, underwater regeneration, private stage/results art and emeralds; `--reference REV` is a migration-specific RGB comparison |
| `check_card_art.py` | Card/signpost glyphs and DPLCs, queue backpressure, all 600 finish times, secret-bonus tally and Mecha's masked palette load |
| `check_end_art.py` | Typed resident PLC admission, codec tags, register preservation, yield/retry and final-DMA ownership; `--native` or `--core CORE` |
| `check_fire_art.py` | Source masks, warm slots, six mappings, pipe/atlas isolation and eight EHZ/HTZ module lists; optional `--s1disasm SOURCE` and `--reference REV` |

Regenerate assets with their owning `build_*`/`import_*` tool, then check the
diff and reproduce it a second time. An unreferenced importer may still be the
authoritative producer of checked-in art. Source ownership and palette/VRAM
contracts belong in [Sprites and VRAM](Sprites-and-VRAM.md); level import
commands and pinned revisions belong in [Levels](Levels.md#sources-and-regeneration).

Useful non-writing generator checks include:

```sh
python build_tools/build_player_effect_art.py --check
python build_tools/build_spring_art.py --check
python build_tools/build_seesaw_art.py --check
python build_tools/build_ehz_waterfall_art.py --check
python build_tools/build_ehz_reflection_art.py --check
python build_tools/build_ehz2_waterfall_art.py --check
python build_tools/pack_scrap_sprites.py --check
```

The atlas check uses a host Nemesis decoder. `build_seesaw_art.py --source
/path/to/s1disasm --check` additionally compares original art/mappings. The
life-portrait producer is `build_life_art.py`; shared UI regeneration runs
`build_hud_art.py`, then `build_card_art.py` and `build_special_results_art.py`.
These write outputs; do not invoke them just to inspect source.

#For the ring-spill/monitor scene, run `check_scattered_rings.py` with `--core`,
`--system-directory` and `--output test-results/rings/report.json`, then add
`--pal` for PAL. Sonic's no-pickup flashing interval stays active while Tails
recovers a real 32-ring spill. The scene also checks all four loaded monitor
icons. Native cases execute all 256 act/preset Debug placements.

`python build_tools/check_monitor_art.py --output test-results/monitor-art.json`
checks every four-kind combination in both allocation orders for each loaded
HUD portrait (4,032 cache cases), hits/reuse, queue refusal, prior-pass pins,
16-bit wrap, unchanged one/two-life awards and authored viewport demand for both
selections. It also checks all 60 slot/HUD poses against the editor geometry,
shared frame records and the loader's recorded identity after a `Player_mode` change.
Add `--core CORE --system-directory BIOS_DIR`
for all four eras of the selected act in Sonic-and-Tails and solo-Tails modes,
plus solo Sonic. It checks actual SAT tile/position output, simultaneous cached
contents and both life portraits, and ball-breaks both life monitors to verify
their floating images and distinct rewards. A VRAM marker confirms that the
reclaimed four tiles remain untouched. It defaults to Scrap Madness 1; `--zone N --act N`
selects another zero-based act. Add `--pal` for PAL. These are staged rendering and
interaction fixtures, not a level playthrough.

## Terrain and independent planes

```sh
python build_tools/check_terrain_collision.py --reference OLD_REF --output test-results/terrain
python build_tools/check_smz_art.py --reference OLD_REF --rom s2built.bin --listing md-main.lst --output test-results/smz-art/report.json
python build_tools/check_plane_engine.py --rom s2built.bin --listing md-main.lst --output test-results/planes/report.json
python build_tools/check_plane_streaming.py --rom s2built.bin --listing md-main.lst --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/planes/game
```

The terrain audit compares reusable chunks, tile pixels/attributes, both
collision paths and all act/era selections through remapped IDs. Protected
`$FB-$FF` solids and cells beyond available source block definitions must remain
verbatim. Angle tolerance defaults to zero; supply `--max-angle-change N` only
for an intentional reviewed normalization. `--zones GHZ --reference-ghz-bank S1`
supports a pre-switch GHZ bank. `--previous-rom`/`--previous-listing` add actual
old/new floor/wall execution around distinct affected orientations, both paths,
scan directions and tile edges; distances and odd-angle marker semantics must
match. SMZ comparisons pair chunks through every layout position in all four
eras and check source/archive, SonLVL and compiled header selection independently.

The plane audit executes 256 layout and 64 plane-record selections, compressed
span/loaded-bank checks and an independent tile oracle. Cases include word IDs
through 1023, unequal/non-power-of-two planes, flips, reverse traversal, camera
jumps, 512-pixel bands, blank FG borders, cache reuse, live edits and Y clamps/seams.
The ordinary build also runs the Lua file/offset validator. SonLVL's released-API
checker separately round-trips word IDs 768/1023 and unequal plane dimensions.

The streaming runner checks actual visible FG/BG tile words across eight terrain
sets. `--zone 3 --act 2` selects EHZ2/PP; camera excursions obey authored bounds.
After a terrain repack also run `check_y_wrap_terrain.py`, `check_mecha_sonic.py`
and the affected EHZ/platform checks: successful decompression alone cannot
certify collision seams, object mappings or the Mecha arena.

## Touch-response checks

```sh
python build_tools/check_collision_response.py --rom s2built.bin --listing md-main.lst --previous-rom /path/to/before.bin --previous-listing /path/to/before.lst --output test-results/collision/native.json
python build_tools/check_collision_response_game.py --rom s2built.bin --listing md-main.lst --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/collision/game
```

Native checks cover insertion ordering/duplicates, overflow, all 90 candidates,
both actors, invisible hitboxes, composite/deleted/disabled rejection and late
children. A matching previous pair compares every size at inside/touching/outside
boundaries, rolling/ducking and response categories in list/dense modes; sound
and DMA are stubbed. The game fixture checks dispatcher capacity/lifetime,
final-slot ring collection and live hitbox changes in GHZ4. Mounted objects,
monitors, enemies and boss suites exercise the same collision path in context.

## Runtime checks

`check_object_lifetimes.py` covers complete SMZ1 conveyor loops, all-or-nothing
helper allocation, late parent slots, vertical camera excursions, horizontal
reloads, translated origins, and all eight individual phases with a full pool.
`--previous-rom OLD --previous-listing OLD_LISTING` additionally compares all six
original S1 loops in both directions for 600 frames each, including full fixed
point positions, velocities, animation and contact flags. `--core CORE` adds
actual camera travel through GHZ/SMZ; its game cases use separate processes.

Most game runners take `--rom ROM --listing LISTING --core CORE --output OUTPUT`
and `--system-directory BIOS`. Exceptions and useful scene selectors are below.
For implementation settings, follow the owning guide rather than reproducing
its subtype/VRAM tables here.

| Area | Runners in `build_tools/` | Distinct coverage / options |
| --- | --- | --- |
| Menus and act data | `check_level_pages.py`, `check_act_music.py` | All 64 launches, 90 live frames without death per act, uploaded menu font/blank tile, act music selection and restoration priorities |
| HUD, portraits, smoke and flash | `check_debug_states.py`, `check_visual_followup.py` | Debug HUD/clock restoration; both smoke banks through eight frames with neighboring-bank guards; lives/monitor colors and EHZ flash restoration |
| Monitors | `check_monitor_state.py`, `check_monitor_edges.py`, `check_monitor_art.py` | Rider/collector ownership, held charge, contact boundaries, 4,032 four-slot cache cases, queue deferral, timestamp wrap, selected HUD/opposite cached portraits and real SAT/VRAM checks |
| Player interactions | `check_player_interactions.py` | All ground angles/held-frame delays for pushing, character tumble ranges and independent wall speeds/contacts; `--core` adds EHZ corkscrews and controller-2 Tails wall breaks in both acts |
| Top-only platforms | `check_smz_vanishing.py` | Rise/side pass-through, landing/ride height, disappearing support and adjacent-platform transfers for Sonic, primary Tails and sidekick Tails. Both slot orders/directions and rolling radii; shared flat/alternate/sloped support entries. `--core` checks actual foot and camera Y through the seam; repeat with `--pal`. |
| Companion | `check_companion_followup.py`, `check_companion_hpz.py`, `check_companion_sbz.py` | Ledges/bridges/collapse, manual takeover, real HPZ routes, SMZ carrier transfer/captured catch-up; see fixture limits below |
| Carrying Sonic | `check_tails_carry.py` | Real electrocuter hurt/death, carried-player release/landing, movement locks `$01/$03/$81` and resumed gravity; `--probe` records old failures |
| Shields, stars and water | `check_player_effects.py`, `check_water_effects.py`, `check_shared_followup.py` | Exact RAM/VRAM sources, regular/lost-ring frames, effect transitions, splashes/countdown cleanup, water DMA sharing/retry/pause, disc/spring/trapdoor contacts and carrier/tail alignment |
| Late effect positions | `check_tunnel_shields.py` | Shared automatic-path math across nine speeds/all signs and both actors; `--previous-rom/--previous-listing` compares all eight full routes, staggered entry and death cancellation. Exactly one update for all 113 slots, final-owner shields/stars and live SMZ2 tunnels; `--stars`, `--player 2`, `--tunnel 2` (horizontal route; default crosses Y wrap) |
| Lifetime and giant ring | `check_object_lifetimes.py`, `check_giant_ring_entry.py` | Unload/delete, complete conveyor groups and actual giant-ring contact through the last flash frame |
| Debug unlock and pause | `check_debug_cheat.py` | Native title sequence/restarts and optional real button entry; both players, hold/step/resume, A/Start exit and unlock persistence |
| Input locks | `check_over_screen_input.py`, `check_drowning_input.py` | Real monitor deaths/drowning, Debug lock/unlock and rendered GAME/TIME OVER V pixels |
| Imported enemies | `check_palmtree_enemies.py`, `check_caterkiller.py`, `check_kemusi.py` | Both-actor damage, terrain, construction/lifetime, art isolation and actual Debug spawning |
| Propeller and carriers | `check_propeller.py`, `check_terrain_conveyors.py`, `check_wheel_carriers.py` | Triggers, terrain motion, riders/payloads and unload/reload |
| SMZ route/objects | `check_scrap_madness.py`, `check_sbz_discs.py`, `check_smz_vanishing.py`, `check_sbz_doors.py` | Real placements, hazards and transport/ride boundaries; `--companion-only` on the SMZ runner holds both players on the disc for 750 updates before controller-2 release |
| Clearance/trapdoors | `check_duck_clearance.py`, `check_smz_trapdoor.py` | Native solid-object head clearance and first-closed-frame overlaps |
| SMZ backgrounds | `check_smz_background.py` | Both acts, REV01 parallax rates, actual VDP scroll/tile words, camera wraps, pause and PAL timing |
| GHZ flowers | `check_ghz_flowers.py` | Native exact DMA cadence; `--core` adds live uploads, neighboring-bank guards and pause; `--act 1` through `4`, optional pre-flower `--reference` |
| EHZ terrain | `check_ehz_terrain.py` | Both acts' S-tunnels on both paths, five platform landings/all flips, actual Debug wall placement and breaks, return loading, S1 seesaw tilts/landings/launches in EHZ/HTZ |
| EHZ waterfalls | `check_ehz_waterfalls.py` | Baked PP/reflection pixels, queue deferral, independent palette clocks and SAT pressure; `--core`, `--act 0`/`1`, optional `--before-rom`/`--before-listing` |
| S1 fireballs | `check_s1_fireballs.py` | Mirrored fixed-point arcs, independent settings/flips, maker offsets/intervals, offscreen/full/end-of-pool behavior, placement release, real CD impacts and both-player damage and all six controller-selected maker/projectile Debug presets |
| Flame rendering | `check_fire_art.py --core CORE` | Eight EHZ/HTZ loads, six poses/four flips, both launcher orientations/four flips with exact SAT pieces, springs/spikes/monitors intact; both emitters through all 22 SMZ frames in both acts and original harmful-frame gating |

`check_debug_states.py --zone 3 --act 2` covers EHZ2's private palette and HUD.
`check_water_effects.py --player 2` selects primary Tails; `--companion` selects
following Tails. `check_shared_followup.py` checks the current ROM without a
fixed historical art snapshot. `--probe` records failures, not passes.

For EHZ2 mountain smoothness, hold Right from the start and inspect distant
cliffs; their VDP horizontal offset should be `floor(3 * camera_X / 16)`. Live
waterfall/reflection checks compare actual VRAM against hardware CRAM through
both palette clocks, catching cloud pulses that CPU palette-buffer checks miss.
When counting sprites use the linked SAT through its terminator, not stale
entries after it. Also inspect spring colors, flips and diagonal support motion.

### Platforms, swings and hanging surfaces

```sh
python build_tools/check_floating_platforms.py --rom s2built.bin --listing md-main.lst --output test-results/platforms/native
python build_tools/check_floating_platforms_game.py --rom s2built.bin --listing md-main.lst --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/platforms/game
python build_tools/check_swing_motion.py --output test-results/swings/native --s3-source /path/to/skdisasm/sonic3k.asm
python build_tools/check_swing_motion.py --output test-results/swings/game --core /path/to/core.so --system-directory /path/to/mode1-fixture
python build_tools/check_hanging.py --output test-results/hanging/native
python build_tools/check_hanging_game.py --rom s2built.bin --listing md-main.lst --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/hanging/game
```

| Runner | Coverage / additional selectors |
| --- | --- |
| `check_floating_platforms.py` | Word settings, all movements, riders/solidity, falling/switch timers, all channels, crushing/ceiling correction, long paths, falling-after-arrival and no-rider safety |
| `check_floating_platforms_game.py` | Normal executor, all movement families, sag/riders and rendered output; `--placements --zone Z --act A` sweeps real converted placements |
| `check_swing_motion.py` | Twelve interaction profiles, exact SOZ/DEZ/rotator motion, ICZ input/return, full-pool/retry, same-SST release, relay, orphan/reused-slot protection and terrain/water behavior |
| `check_swing_families.py` | Both-actor top/side/underside hazards, flashing/stars, switches and harmless Debug entry/exit; choose the explicit artwork constructor for ICZ rails |
| `check_hanging.py`, `check_hanging_game.py` | D9 grips and DA chain/lift: both players, grab/release, clipped mapping coordinates, pool/ownership/retry, standing/hanging combinations, terrain and moving support, live art/DMA |
| `check_platform_mounts.py`, `check_platform_mounts_game.py` | Six platform constructors, 64 mount values, eras/flags, both allocation orders, partial/full pools, rider/payload rewards, persistent broken monitors, button channels and detach |
| `check_lz_conveyor.py`, `check_lz_conveyor_game.py` | All eight routes, reversal, construction/unload/reload, fragmented pools, both riders and live wheels/platforms; `--spiked` uses an output-only ROM fixture |
| `check_lz_wheel_dplc.py` | One/70 wheels, exact DMA records and registers, reversal, queue pressure/retry, timestamp wrap and level-entry invalidation |
| `check_ghz4_loops.py` | Act-3 loop recipe/pathswappers, controller traversal through all quadrants and both paths to grounded exit |
| `check_ghz4_playtest.py` | Authored entrance route, carried button into water; positioned visits to placed springs, monitor, spikes and both-player detach; water palettes/cycle |

Optional upstream motion oracles use skdisasm
`73de97c6b55055bcb8089c1d55d006b02136f163`; ordinary platforms verify source blob
`0f10a373ff0e3d5c0033ed7d13c678bcb927c7b0`. These assemble unchanged source
instructions and compare motion/flags/RNG, with explicit fixture boundaries.
The ordinary-platform oracle currently uses bundled Linux x86-64 tools.
Swing `--before-rom`/`--before-listing` requires the specific pre-body-split
build; platform `--before-ref` audits the preceding placement encoding.

Late reversal cannot cancel already-queued wheel DMA. Regenerate rails with
`build_swing_rails.py` and the mounted button with `build_platform_button.py`;
repeat shared platform/hanging/wheel tests after changing payload handlers.
SonLVL checks property/layout round trips independently of runtime behavior.

### Water and the Y seam

```sh
python build_tools/check_water_tables.py --rom s2built.bin --listing md-main.lst --output test-results/water/native.json
python build_tools/check_y_wrap_terrain.py --rom s2built.bin --listing md-main.lst --output test-results/y-terrain
python build_tools/check_y_wrap.py --rom s2built.bin --listing md-main.lst --output test-results/y-actors
```

The table check executes water enable/height/routine selection for all 64 acts
and temporarily enables the final slot to catch hardcoded limits. Terrain seam
checks load HTZ2/SMZ2 in all eras and compare addresses, floor/wall distances,
angles and foreground output across negative Y/`$800`, both paths/directions,
live edits and a non-wrapping 32-row control.

Add `--core CORE --system-directory BIOS` to the seam runners for real SMZ2
pit/ceiling contacts, all eight transporters, actual camera seams/visible planes,
companion recovery/death/flight and 32-ring scatter/expiry. The secret-route
fixture checks 49 rings rejected/50 admitted. Ring native checks also cover
signed trajectories, independent lifetimes, all timers, collection and ordinary
non-wrapping bottom culling. `--pal` changes region; `--probe` records old failures.

## Cards and rotating stage

| Runner | Useful cases / scope |
| --- | --- |
| `check_card_screens.py` | `--case normal`, `--case special`, solo `--player 1`/`2`; actual glyph VRAM/rendering, heading/oval centers, CONTINUE spacing and both portrait poses |
| `check_fast_clear.py` | Controller shoes-monitor to signpost/results/next-act path |
| `check_special_stage_players.py` | Real menu entry, cloud/transition uploads before display enable, compact Sonic/Tails body/tail, live palette/SAT, four tail directions, Debug modes and goal exit |
| `check_seventh_emerald.py` | Native seven awards/duplicates/896 selection cases and result positions/blink; `--core` adds real pickups/results with `--player 1`/`2`, `--pickup-count 1` or `--fail` |
| `check_special_stage_overlap.py` | Real bumper/DOWN/GOAL callbacks and movement against an independent wall oracle; cyan is passable |
| `check_ss_debug.py`, `check_ss_debug_game.py` | Native fixed-point ties, free/full-grid bounds, padding and collection; game checks twelve placements, occupied-cell skips and cursor/camera alignment on taps, acceleration, stops and reversals |
| `check_signpost.py`, `check_signpost_game.py` | Both entry modes, crossing/landing, hit boundaries, cooldown, full pools, popups, sparkles and results; native terrain/sound/DMA boundaries are stubbed |

Special-results reproduction examples:

```sh
python build_tools/check_card_screens.py --case special --emeralds 6 --rings 50 --player 1 --rom s2built.bin --listing md-main.lst --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/cards/partial
python build_tools/check_card_screens.py --case special --emeralds 7 --collected --rings 999 --record-transition --player 2 --rom s2built.bin --listing md-main.lst --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/cards/super
```

With six emeralds, no `--collected` gives SPECIAL STAGE; the flag selects the
successful character heading. Seven plus the flag exercises GOT THEM ALL and
the delayed Super announcement. Test `--rings 0`, `50` and `999` for no Continue,
Continue and a long tally. The fixture resets tally inputs after stage exit so
incidental pickups do not alter the requested case. `--record-transition`
captures both opposed entry/exit halves, fixed oval and full announcement hold.
Native card checks pin S3&K's 120/270/240-update delays and reject the announcement
on failed/partial results; this does not implement transformation gameplay.
`--case normal --time-seconds 599` checks the five-digit 100,000 secret bonus.

The signpost game runner's short fast-crossing scene stops the clock to disable
unrelated end-art approach work. Use `check_card_screens.py --case normal` for
the classic slow finish. Stage goal/direction states and most pickup scenes are
positioned fixtures, not full-stage controller routes.

## Boss runtime checks

```sh
python build_tools/check_ghz_boss.py --rom s2built.bin --listing md-main.lst --output test-results/ghz-boss/native
python build_tools/check_boss_shared_art.py --ghz-faces-only --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/ghz-boss/faces
python build_tools/check_ghz_boss.py --rom s2built.bin --listing md-main.lst --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/ghz-boss/game
python build_tools/check_ehz_s1_pod.py --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/ehz-boss
python build_tools/check_mecha_sonic.py --rom s2built.bin --listing md-main.lst --native --skdisasm /path/to/skdisasm --output test-results/mecha/native
python build_tools/check_mecha_sonic.py --rom s2built.bin --listing md-main.lst --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/mecha/game
```

| Runner | Distinct checks / options |
| --- | --- |
| `check_boss_shared_art.py` | Shared constructors, expressions/facings, pod/head/exhaust pixels, persistent exhaust, cleanup and unchanged palettes; optional pre-sharing `--reference-rom`/`--reference-listing` (`21c233e`) |
| `check_ehz_boss.py`, `check_ehz_boss_palette.py` | Compiled simultaneous mappings/banks; optional `--s2disasm SOURCE` for all original chassis tiles/frames, one-word masked load, pool retry and palette-clock preservation |
| `check_ehz_s1_pod.py` | Both act loaders, docking, seven expressions/facings, live palette/CRAM and foreground priority; Act 2 fight/hits, breakup, lift/ignition clearance, escape cleanup and capsule release |
| `check_ghz_boss.py` | Native pool/retry, deployment, timed flight, hits, breakup clock/debris, explosions, palette/music cleanup; `--core` adds the actual GHZ3 arena fight/results/capsule |
| `check_mecha_sonic.py` | Native floor/facing/counters, both actors, pool failures and projectiles; real SMZ2 trap/attacks, three uninterrupted head bounces, sixteen actual hits, fade/signpost/results and current-act music restoration on `Mystic-Island` |

`check_boss_shared_art.py --ghz-faces-only` enters GHZ3's real arena and lets
its normal boss/music transition run. It compares all 40 pilot tiles and all
six boss PLC banks with their source data, then exposes the pilot in a fixture
without the waterfall and checks seven expressions in both directions, including
rendered head pixels. Add `--pal` for PAL. This focused check does not run the
full fight or the EHZ suites; ClownEmu remains a separate manual retest.

EHZ `--act 0`/`1` narrows the run. Act 1 suppresses its ordinary signpost loader
with the clock and ends after docking/rendering because it has no authored boss
arena. Act 2 uses the real arena. Positions establish attacks; HP is changed by
actual collision. Palette tests compare environment pixels with/without the
masked load and observe fixed entries, both clocks and escape restoration.

GHZ `--s1disasm SOURCE` assembles the original movement, sine and pendulum code
from the pinned source in [Objects](Objects.md#ghz-boss-and-boss-explosions).
Allocation/hits and deliberately changed deployment are reference boundaries.
The native burst tests cover GHZ/EHZ profiles; `--explosion-wall --core CORE`
instead stages the unused wall in EHZ1 and checks finite emitter/visual cleanup
without animals. A full-pool case must not advance the breakup clock early.

Mecha's optional skdisasm oracle compares original attack states/animation/RNG;
local grounded/dive flags and sound/children/flat-floor boundaries are excluded.
The source jet constructor at `loc_7C902` also plays Roll. Native cases check
one start per maintained pair, kind changes, pool recovery and no maintenance
retrigger. The real fight checks that the Roll voice reaches the FM4 SFX track
and produces PCM, with actual YM2612 key-on writes on Genesis Plus GX.
Game `--approach above`/`below` exercises camera entry, `--companion` selects
second-actor hits, and `--player 2 --pal` selects primary Tails/PAL. Counter
scenes retain real charges and contact; the repeated-bounce sequence repairs
neither position nor cooldown after its initial setup.

## Mega-CD checks

```sh
python build_tools/check_mode1.py --core /path/to/core.so --rom s2built.bin --listing md-main.lst --art-cache-gameplay --output test-results/mode1
python build_tools/check_cd_dispatch.py --rom s2built.bin --listing md-main.lst
python build_tools/check_cd_terrain.py --core /path/to/core.so --system-directory test-results/mode1/identification-fixture --output test-results/cd-terrain
python build_tools/check_cd_ring_jobs.py --core /path/to/core.so --system-directory test-results/mode1/identification-fixture --rom s2built.bin --listing md-main.lst --output test-results/cd-rings
```

`check_mode1.py` creates a zero-filled `SEGA` identification fixture enabling the
core's CD model; it contains/executes no Sega BIOS code. The cartridge still
performs its own upload/handshake. This runner checks required-hardware handling,
commands/timeouts, ownership, queued/immediate Word/PRG-RAM DMA, negative control,
bank edges, wrap, full/mixed queues, registers and palette/vertical-scroll DMA.
`--assembler`/`--p2bin` override bundled probe tools.

`--art-cache-gameplay` preserves free-RAM canaries through 600 controller frames,
poisons the player-art cache, enters the rotating stage, verifies its private ring
source and live VRAM frame, then stages an exit and checks ordinary results/level
return reloads shield/star/regular-ring sources. `--stack-gameplay` independently
watermarks unused MD stack during HPZ loading, both player modes and water HBlank,
keeping live return frames and a 32-byte lower guard. Depth samples do not prove
a worst case on every call path.

The dispatch check runs every command/high-byte/request combination with job
stubs destroying all registers except SP/result. Optional `--core CORE
--system-directory BIOS --output report.json` measures isolated sub-CPU overhead;
`--baseline-rom`/`--baseline-listing` compare a prior dispatcher. Frozen MD/fixed
jobs do not measure full RPC or game performance.

For old/new terrain execution, run `check_cd_terrain.py --baseline --rom OLD
--listing OLD_LISTING`, then pass its `report.json` as `--reference` to the new
run. Keep collision assets equal; shape-remap comparison belongs to the terrain
audit above. `--zone 0`/`1`/`2` covers GHZ/LZ/CPZ. Calls and complete planes include
mailbox waits; full frames also check jumping and free-RAM canaries without
requiring random/NPC phases to match. Prepared art DMA drains through VBlank
before a plane probe takes Word RAM.

Current-ROM runs also execute 5,120 native ground-attachment boundaries: both
actors/radii and collision paths, all four surface orientations, signed X/Y
speeds, penetration limits, exact attachment thresholds and the running-disc
override. `--zone 4` adds the HPZ1 cliff at `$C00,$300`: Sonic and manually
controlled sidekick Tails walk left off its edge, fall onto the lower slope and
turn right for 240 frames each. The check rejects stepping down with a flat angle,
missing landing angles and false uphill pushing. Run with and without `--pal`;
the fixture stages initial positions, then uses ordinary controller input.

Ring-job tests cover sparse/all-active timers, staggered collection, bank pauses,
reset and guards in HPZ/SMZ with both player modes. Their `--baseline` is a boolean
recording mode, not a path. Use the current word-ID plane audit for exhaustive
chunk/stream behavior.

```sh
python build_tools/check_cd_decompression.py --baseline /path/to/old.bin --baseline-listing /path/to/old.lst --output test-results/cd-codecs
```

The codec comparison needs a matching ROM/listing from before CD offload. It
executes every compressed span with the former MD decoder and current CD code,
including Kosinski modules, Nemesis XOR and Enigma attributes, with input/output
guards. Resumed PLC batches interleave unrelated decodes and yield across timer
wrap. Add `--core CORE --system-directory BIOS` for real PLC uploads under HPZ
water HBlank, exact VRAM output and resident block/chunk guards. Native results
do not certify hardware scheduling.

Audio macro/codec/stream/playback commands and branch-specific streaming tests
have one home: [sound validation](../build_tools/sound/README.md#validation).
Its `--priority` case checks bumper/Continue arbitration and `--switches` checks
rapid-switch DPCM continuity. After ROM bank-layout changes compare payloads and
playlist flags against the preceding ROM, then run audio, all act launches,
plane streaming in both acts and compiled VRAM checks in both regions.

## Disposable object course

The course remains useful for broad lifecycle/contact and instrumented execution
coverage. Its builder copies the checkout, substitutes a flat LZ2 course and
switches diagnostic art banks; output must be **outside the checkout**. Object
bodies remain unmodified. Hooks preserve registers/CCR and record actual routine
execution using a per-slot last-code cache. The image is not a performance
reference or proof of art coexistence in populated levels.

```sh
python build_tools/build_object_course.py --output /tmp/mystic-object-course
python build_tools/check_object_course.py --build /tmp/mystic-object-course --core /path/to/core.so --output test-results/course/sweep
python build_tools/check_object_interactions.py --build /tmp/mystic-object-course --core /path/to/core.so --output test-results/course/contacts
python build_tools/check_object_contexts.py --build /tmp/mystic-object-course --core /path/to/core.so --system-directory /path/to/mode1-fixture --output test-results/course/stage --case stage
```

The builder currently invokes Linux x86-64 tools and `texlua`; its host tool
selection needs adaptation for native Windows. Sweep/contacts support `--pal
--player 2`, `--bank N` narrows the sweep, and `--filter REGEX` narrows contacts.
Contexts also offers `--case warp --player 2`; stage success/ownership is staged,
while real emerald pickup is covered by `check_seventh_emerald.py`.

Test-only floor/door art provenance is in `build_tools/object_course_art/sources.json`.
Prototype banks move only in the copied image; the legacy wall's `$590` overlap
is isolated and snapshots restore explosion art. LZ palettes do not certify
zone colors. Later SMZ/PP imports need their native-level checks. `layout_id` is
a test-side routine-pointer projection, not the SST dispatch format.

## Reports and evidence

Keep JSON, screenshots, WAVs, ROM hashes and matrices in explicit output folders;
`test-results/` is ignored. Retain matching ROM/listing, source/core identity and
region/player options with evidence. Do not commit generated snapshots to docs.

```sh
python build_tools/summarize_object_course.py --run Sonic-NTSC=test-results/course/sweep/report.json --output test-results/course/coverage
```

The summarizer inventories current source against supplied reports; it neither
runs the game nor verifies that old reports match the current ROM. Repeat
`--run name=path`, `--boss GHZ-name=path`/`EHZ-name=path`, `--demo name=path` and
`--conveyor name=path` (live LZ `$1F` report) as needed. Missing required coverage
fails; helper IDs infer no certification and W.I.P. remains inventoried only.

Known limits:

- Two older companion fixtures need refresh: the first GHZ ledge scene in
  `check_companion_followup.py` predates the `$200` foreground shift;
  `check_companion_sbz.py` can miss all platforms at its three-frame conveyor
  assertion. Both fail on the unchanged baseline. The latter's `--scene flight`
  remains useful; it offers `--probe` but no PAL flag.
- Full revised-AI low/normal/high routes and the rare solo-Tails/backtracking
  monitor route remain incomplete. Focused tests do not establish those outcomes.
- Gator lifecycle/rendering does not certify its broken gameplay. The title
  palette handler is unfinished/unspawned. Multi-body chains, controller handover
  and custom released-body recipes are not implemented/covered by platform tests.
- Source/editor API checks do not certify an interactive SonLVL desktop run.
  Emulation does not establish physical Mega-CD or commercial-BIOS compatibility.
