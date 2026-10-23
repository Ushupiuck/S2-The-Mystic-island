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
python build_tools/check_card_art.py --rom s2built.bin --listing md-main.lst
```

## Runtime checks

The old `check_level_lag.py` GHZ → CPZ → HPZ sequence is a historical
Twizzler investigation, not current decompressor validation. Do not include it
in routine migration checks. [VBlank ownership](Sprites-and-VRAM.md#mapping-and-rendering-abi)
documents the retained wait-latch/nested-interrupt fix.

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
| SMZ backgrounds, solids and hazards | `check_smz_background.py`, `check_scrap_madness.py`, `check_sbz_discs.py`, `check_smz_vanishing.py`, `check_swing_families.py`, `check_sbz_doors.py` | REV01 parallax/streaming, placed-object lifecycle, transport/ride boundaries and harmful spikeball subtypes |
| Compact clearance/closing doors | `check_duck_clearance.py`, `check_smz_trapdoor.py` | Native 68000 collision fixtures |
| Imported enemies/obstacles | `check_palmtree_enemies.py`, `check_propeller.py`, `check_caterkiller.py`, `check_kemusi.py`, `check_terrain_conveyors.py`, `check_wheel_carriers.py` | Both-actor triggers, motion, damage, unload/reload and source-specific regressions |
| Audio | `check_sound_playback.py`, `sound/build.py --check` | Actual sound paths; encoding/macro/packer checks |

`check_level_pages.py` also compares the uploaded menu font pixel-for-pixel
against independently decoded Nemesis art and checks that blank tile zero stays
transparent, on both pages and after returning from a level. Correct text tile
numbers alone do not establish that the font was uploaded to the right place.

`check_smz_background.py` checks the VDP's live horizontal/vertical scroll values
and visible background tile words against the S1 REV01 rates and editable SMZ
geometry. It enters both acts, uses ordinary input, then freezes the lead actor
at successive camera targets to cross plane wraps and layer boundaries in both
directions. It covers pause/resume and saves rendered views. Use `--player 0`
or `--player 2`, `--pal` for PAL, and `--system-directory` for Mode 1. The sweeps
are streaming fixtures, not complete controller-only playthroughs.

`check_companion_sbz.py` has `--probe` for older-ROM failures, but no PAL flag.
Several runners compare with a specific earlier revision; their baseline is
part of the fixture, not automatically the parent commit. Check their CLI/source
before reusing them with an unrelated baseline. Native fixtures use the declared
system stack, map staging and execute CD terrain and placement requests in a second Unicorn
68000. Fixture data is copied to its resident tables at the mailbox boundary;
this tests the assembled algorithms, loading/apply boundary and caller ABI,
not CD bus scheduling. Object fixtures use placement helpers to distinguish CD
index handles/resident state from cartridge pointers. The emulator checks below cover that hardware path.

CD boot needs a supplied system directory. Only runners exposing
`--system-directory` support that setup directly (including level pages, act
music, sound playback, visual follow-up, fast clear, player effects, card screens and swing families).
`check_debug_states.py` also accepts this directory for both primary characters'
HUD and hurt/death Debug checks on Mode 1.
Older water/companion/shared runners lack it and target the ordinary cartridge
ROM. Do not describe all existing fixtures as CD-aware or apply flags universally.

## Boss runtime checks

```sh
python build_tools/check_ghz_boss.py --rom s2built.bin --listing md-main.lst --output test-results/ghz-boss
```

The native pass covers fragmented/full pools and retries, end-of-pool parents,
dry-act water-bank borrowing, staged deployment, continuous patrol, recycled
child slots, actual hit response,
palette restoration, scoring, independent debris physics on every frame, burst
cadence/RNG, animation duration and act-selected escape music. Rendering/audio
boundaries are stubbed only in these native fixtures.
The wall checks cover both PLC banks, four-emitter allocation under a fragmented
pool, movement at the level origin and with a moving camera, finite/continuous
burst counts, the normal burst animation and parent/deletion cleanup.

Add `--core /path/to/genesis_plus_gx_libretro.so` for the real GHZ3 arena. It
uses explicit player positioning, then eight actual rolling collisions with
the boss. It observes breakup, explosions, escape, ordinary-art restoration and
the capsule switch/animal release. `--player 2` selects Tails and `--pal`
selects PAL. Mode 1 accepts `--system-directory /path/to/bios-directory`.
Screenshots and the JSON report belong in the selected output directory.
The native burst tests cover both GHZ/EHZ profiles; this arena run covers GHZ,
not a controller-only playthrough or EHZ's entire fight.

Add `--explosion-wall` with `--core` to run the unused wall entry point instead
of the boss fight. This fixture queues its compiled PLC and allocates the wall
in EHZ1, checks that both effect sizes render with matching art banks, and waits
for the wall, emitters and visuals to finish without producing animals.

## Mega-CD checks

Check out `test/rebuilt-kehmusic` for the CD-specific scripts. Build normally,
then create the emulator identification fixture and use its directory:

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
Timing freezes MD execution and uses fixed jobs; it measures dispatcher overhead,
not complete RPC latency or game-wide performance. Compared with the unrolled
service, ordinary jobs save 12 cycles and former two-register-preserving jobs
save 64; no-op/ping/return-RAM/unknown replies cost 22 more cycles. Idle polling
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
Add `--core /path/to/genesis_plus_gx_libretro.so --system-directory ...`
to the codec runner for actual queued PLC uploads while HPZ's early water
HBlank split is active; it compares VRAM with the old decoder and checks
resident blocks and the entire expanded chunk allocation for changes.

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
