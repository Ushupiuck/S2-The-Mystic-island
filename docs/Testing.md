# Building and testing

Run commands from the repository root. Windows is the primary environment:
`build.bat` runs the bundled Lua launcher. Linux/BSD use `lua build.lua` with
the matching bundled native tools and Mono for the sound packers. Sound-tool
rebuilds and native Windows checks are covered by
[the sound guide](../build_tools/sound/README.md) and [AGENTS.md](../AGENTS.md).
The build produces `s2built.bin`, `main.lst` and generated sprite bounds.

Python checks require Python 3. Native 68000 fixtures additionally need Unicorn;
emulator runners need NumPy, Pillow and a Genesis Plus GX libretro shared
library exporting the RAM/VRAM and CPU symbols used by `genesis_test_core.py`.
A normal distributed core is not guaranteed to expose these test interfaces.
Core-based fixtures do not require a graphical frontend.

## Source and asset checks

After a normal build:

```sh
python build_tools/check_ram_ranges.py
python build_tools/check_object_layouts.py
python build_tools/check_sprite_bounds.py
python build_tools/check_sprite_assets.py
python build_tools/check_ghz_vram.py
python build_tools/check_ehz_boss.py
```

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
Card data and queue backpressure also have a native check (requires Unicorn):

```sh
python build_tools/check_card_art.py --rom s2built.bin --listing main.lst
```

## Runtime checks

`check_level_lag.py` loads GHZ, CPZ and HPZ in order, waits at least five seconds
in each, and uses Debug Start+A between levels. It then traverses HPZ in Debug
while comparing the loaded block definitions, chunks and complete layout every
frame. `--zone 2` stops in dry CPZ instead. `--delay 0` uses the unmodified ROM;
the default inserts a register/CCR-preserving guest CPU delay into block drawing
in a disposable ROM under the output directory. This deliberately amplifies lag
while retaining normal IRQ/VDP/CD scheduling. It is a deterministic stress check,
not proof that every intermittent corruption report has the same cause.

```sh
python build_tools/check_level_lag.py --core /path/to/genesis_plus_gx_libretro.so --rom s2built.bin --listing main.lst --output test-results/level-lag
```

Add `--system-directory /path/to/bios` for CD builds, or `--pal` for PAL. See
[VBlank ownership](Sprites-and-VRAM.md#mapping-and-rendering-abi) for the wait
latch and nested-interrupt contract. The pre-fix handler can recursively consume
the stack under this load and overwrite the last loaded block definitions;
correct decompression on entry does not rule that out.

Example for the shared visual regressions (life art, SMZ smoke/flame and boss flash):

```sh
python build_tools/check_visual_followup.py --core /path/to/genesis_plus_gx_libretro.so --rom s2built.bin --listing main.lst --output test-results/visual
```

Use distinct output directories per ROM/region/player. Add `--pal` only to runners
that offer it. Most primary-player selectors use `--player 0` (Sonic) or `2`
(Tails), but card-screen fixtures use `1`/`2`; do not assume one interface.

| Area | Runners in `build_tools/` | Scope |
| --- | --- | --- |
| Act data, menus, animation, music | `check_level_pages.py`, `check_act_music.py` | Actual act launches/loaded data; disposable song differentiation and drowning restore priorities |
| Cards, progression and scene transitions | `check_card_screens.py`, `check_fast_clear.py` | Intro/results art; real shoes-monitor to signpost/results/next-act path |
| Player effects and water | `check_player_effects.py`, `check_water_effects.py`, `check_shared_followup.py` | Shields/stars, splash/countdown, normal/paused surface, DMA retries and shared art |
| Monitor state and primary Debug | `check_monitor_state.py`, `check_monitor_edges.py`, `check_debug_states.py` | Rider/collector ownership, contact boundaries and Debug restoration |
| Object lifetime and stage entry | `check_object_lifetimes.py`, `check_giant_ring_entry.py`, `check_object_contexts.py` | Unload/deletion, giant rings and mode-specific objects |
| Companion | `check_companion_followup.py`, `check_companion_hpz.py`, `check_companion_sbz.py` | Ledges, collapse/bridge/manual takeover; actual HPZ routes; 64-phase SMZ transfer and captured catch-up |
| Input locks and rotating stage | `check_over_screen_input.py`, `check_drowning_input.py`, `check_special_stage_overlap.py` | Real deaths/drowning; normal bumper/item callbacks and embedding regressions |
| SMZ solids and hazards | `check_scrap_madness.py`, `check_sbz_discs.py`, `check_smz_vanishing.py`, `check_swing_families.py`, `check_sbz_doors.py` | Placed-object lifecycle, transport/ride boundaries and harmful spikeball subtypes |
| Compact clearance/closing doors | `check_duck_clearance.py`, `check_smz_trapdoor.py` | Native 68000 collision fixtures |
| Imported enemies/obstacles | `check_palmtree_enemies.py`, `check_propeller.py`, `check_caterkiller.py`, `check_kemusi.py`, `check_terrain_conveyors.py`, `check_wheel_carriers.py` | Both-actor triggers, motion, damage, unload/reload and source-specific regressions |
| Audio | `check_sound_playback.py`, `sound/build.py --check` | Actual sound paths; encoding/macro/packer checks |

`check_companion_sbz.py` has `--probe` for older-ROM failures, but no PAL flag.
Several runners compare with a specific earlier revision; their baseline is
part of the fixture, not automatically the parent commit. Check their CLI/source
before reusing them with an unrelated baseline. Native fixtures use the declared
system stack and map the CD bank-0 chunk/scene window on Mode 1 builds; they do
not emulate CD ownership. The emulator checks below cover that hardware path.

CD boot needs a supplied system directory. Only runners exposing
`--system-directory` support that setup directly (including level pages, act
music, visual follow-up, fast clear, player effects, card screens and swing families).
Older water/companion/shared runners lack it and target the ordinary cartridge
ROM. Do not describe all existing fixtures as CD-aware or apply flags universally.

## Mega-CD checks

Check out `test/rebuilt-kehmusic` for the CD-specific scripts. Build normally,
then create the emulator identification fixture and use its directory:

```sh
python build_tools/check_mode1.py --core /path/to/genesis_plus_gx_libretro.so --rom s2built.bin --listing main.lst --output test-results/mode1
python build_tools/check_cd_chunks.py --core /path/to/genesis_plus_gx_libretro.so --system-directory test-results/mode1/identification-fixture --output test-results/cd-chunks
python build_tools/check_cd_ring_jobs.py --core /path/to/genesis_plus_gx_libretro.so --system-directory test-results/mode1/identification-fixture --rom s2built.bin --listing main.lst --output test-results/cd-rings
```

Each offers `--pal`. `check_cd_chunks.py` uses the root `s2built.bin`/`main.lst`
directly; it has no ROM/listing flags. It checks all 256x64 chunk/block addresses,
row/column plane writes/flips/edges, ordinary frames and a rotating stage, with
remaining-free-MD-RAM canaries. It also poisons the player-art cache before
entering the rotating stage, checks that stage's RAM-to-VRAM ring upload, then
returns through results and verifies all three level sources are rebuilt.
`check_player_effects.py` compares RAM sources and actual VRAM against editable
art, including all eight regular/lost-ring frames and shield/star transitions.
Run `python build_tools/build_player_effect_art.py --check` after source-art edits.
Ring tests cover sparse/all-active lifetimes, staggered
collection, bank pauses, reset, expanded-tail guards and HPZ/SMZ gameplay in both
character modes. To measure the previous CD implementation, pass its ROM/listing
with `--baseline` to the ring runner; it is a boolean mode, not a path argument.

The identification fixture contains only the `SEGA` marker, not BIOS code.
See [Mega-CD](Mega-CD.md) for ownership contracts and hardware-test limits.

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
python build_tools/check_object_contexts.py --build /tmp/mystic-object-course --core /path/to/genesis_plus_gx_libretro.so --output test-results/course-stage --case stage
python build_tools/check_object_contexts.py --build /tmp/mystic-object-course --core /path/to/genesis_plus_gx_libretro.so --output test-results/course-warp --case warp --player 2
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
`--demo name=path` as needed. Successful output is `report.json` and `coverage.md`
in the selected directory. Helpers receive no inferred runtime certification
from object IDs; inactive/W.I.P. sources are inventoried, not gameplay-tested.

Known limits remain explicit: the excluded LZ conveyor is unfinished; Gator
lifecycle/rendering does not certify its broken gameplay; the compiled title
palette handler is unfinished/unspawned. Representative subtypes and positioned
fixtures are not exhaustive/controller-only playthroughs. Rare monitor-route
reproduction and full revised companion routes remain incomplete. SonLVL paths
and previews can be checked without certifying an interactive desktop-editor run.
Emulator checks do not establish physical Mega-CD compatibility.
