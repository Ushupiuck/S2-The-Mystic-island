# Mystic Island SonLVL definitions

Open `SonLVL.ini` with a current Sonic Retro SonLVL build that supports
Kosinski Plus and moduled Kosinski Plus. This project uses S3&K six-byte
object placements and sprite mappings. Its object IDs come from `Obj_Index`
in `md-main.asm`, rather than an original game's table.

`obj.ini` supplies shared objects and imported enemies. The zone lists override
objects whose art or mappings depend on the zone: bridges, Chopper/Masher,
platforms, rocks, and the Scrap Madness sprite atlas. All 64 act sections name
an object list and placement file. HTZ acts 2–4 are included.

Definitions use the game's current graphics and mappings. Nemesis and moduled
Kosinski Plus art have explicit compression settings. The signpost's streamed
preview applies its current DPLCs; those use the S2/player-style cue encoding,
even though its mappings use S3&K format. Inline mappings for BBat, Gator,
Aquis/Skyhorse and Eggman are read from `md-main.asm`.

## Editing subtypes

Select an object to see its named settings in the property grid. The raw
**Subtype** field remains available. Settings preserve unrelated subtype bits
and placement flags. Path switchers use SonLVL's S3&K numbered, directional
marker art, repeated across the full trigger length. Its 0/1 labels show the
primary/secondary path on each side. Other invisible objects have outlined bounds;
moving platforms, saws and lifts have debug travel guides. Transport pipes show
their route when debug overlays are enabled.

| ID | Object | Subtype settings |
|---|---|---|
| `$03` | Path / priority switcher | Bits 0–1: length 64/128/256/512 px; bit 2: horizontal trigger; bits 3/4: right-down/left-up collision path; bits 5/6: corresponding priority; bit 7: grounded only. Placement flips do not enable a priority-only mode in this handler. |
| `$0B` | Tilting platform | High nibble: duration; low nibble: initial phase, both in 16-frame units. |
| `$0C` | Flapping door | Full byte: interval in seconds. |
| `$16` | Diagonal lift | Full byte: duration in 8-frame units. Travels twice as far horizontally as vertically, then falls. |
| `$17` | Swinging platform / ball | Low nibble: chain length. High nibble: normal, bounce left, static, bounce right, trap, giant ball, detachable. |
| `$18` | GHZ/EHZ platform | Low nibble: movement, including 128/64/96 px oscillations, delayed falling and switch-triggered rising. High nibble: shape. |
| `$19`, `$AD` | CPZ platform / SMZ moving block | Low nibble: movement, wall stop/fall, switch-2 raft, vertical motion or triggered fast slide. High nibble: shape. |
| `$1A`, `$3C` | Collapsing ledge / breakable wall | Full byte: mapping frame. |
| `$1C` | Scenery | Low nibble: appearance; high nibble: animation. Zone lists supply suitable defaults. |
| `$1D` | Bridge | Full byte: number of 16-pixel logs. Preview includes every log. |
| `$1E` | HPZ waterfall | Full byte: height; `$10` and above add a second stream. |
| `$1F` | LZ conveyor | `$80-$87`: complete relative groups; `$C0-$C7`: the same groups with harmful undersides. `$00-$7E`: individual route/corner; `$7F`: wheel. X flip reverses travel; switch E reverses normal/spiked groups permanently. The property grid exposes mode, route/group, spikes and individual corner. Previews/route overlays read the live ASM tables. |
| `$21` | Ballhog | `$00–0F`: horizontal; `$10`: timed vertical; `$11–1E` and `$9F–FF`: moving vertical; `$1F–9E`: stationary vertical. Bomb lifetime is editable, including extended timers. `$1F` underflows to 255 seconds. The extended moving range comes from the handler's byte comparison / signed branch. |
| `$2B` | Chopper / Masher | Eight jump velocities, `$00–07`. |
| `$2C` | Jaws | Full byte: turning interval in 64-frame units. |
| `$3E` | Capsule | `$00`: body; `$01`: button. |
| `$42` | Newtron | Blue runner, green missile, custom green hybrid. |
| `$44` | Edge wall | Low nibble: appearance; bit 4: non-solid. Cap art comes from the level tiles. |
| `$50`, `$51` | Aquis / Skyhorse | Patrol interval; Aquis also has a firing interval in the high nibble. |
| `$52` | Piranha | Low nibble: patrol interval; high nibble: jump interval. |
| `$5E` | Seesaw | Zero: spawn ball; any nonzero subtype: omit ball. |
| `$60` | Caterkiller / Kemusi | `$00`: Caterkiller; `$01`: intact Kemusi; `$02`: damaged Kemusi, with a vulnerable body and half speed. SMZ Act 1 loads Caterkiller; Act 2 keeps Caterkiller and adds Kemusi in the unused smoke banks. All three have four-piece previews; Act 2's picker defaults to Kemusi. |
| `$79` | Checkpoint | Full byte: checkpoint number. |
| `$7D` | Hidden bonus | `$01`: 10000; `$02`: 1000; `$03`: 100 points. |
| `$A0` | Junction | Low nibble: reversing switch number. |
| `$A1` | Running disc | Low nibble: radius; signed high nibble: rotation speed. |
| `$A2` | Terrain conveyor | Low nibble: full width / 16 minus one (16–256 px); bits 4–6: speed magnitude (0–7 px/frame); bit 7: 48/112 px height. X flip selects leftward travel. The rectangle extends upward from its origin; adjacent rectangles can cover uneven terrain. |
| `$A3` | Spinning platform / trapdoor | Bit 7: object type; low nibble: spin phase / trapdoor delay; bits 4–6: spin synchronization period. |
| `$A4` | Saw | Stationary, horizontal/vertical cutter, speeding from left/right. |
| `$A5` | Stomper / door | Bits 4–6: shape; bit 7: switch control; low nibble: movement / switch number. |
| `$A6` | Vanishing platform | Low nibble: duration; high nibble: phase. |
| `$A7` | Flamethrower | Low/high nibbles: off/on duration; Y flip selects valve art. |
| `$A8` | Electrocuter | Full byte: synchronization mask; regular intervals use powers of two. |
| `$A9` | Conveyor platform group | Bit 7: group spawner; low seven bits: one of six groups. Preview reads all eight members at their absolute runtime coordinates. |
| `$AB` | Transport pipe | Low three bits: route; route 7 requires 50 rings. Route points are read from the ASM table. |
| `$AC` | Invisible solid | High/low nibbles: width/height in 16-pixel units, minus one. |
| `$AF` | Button | Low nibble: switch number. |
| `$B0` | Wheel carrier | Low nibble: one of eight mounts. Preview includes the spring, monitor or spikes with the runtime offset/facing. |
| `$B1–B5` | Palmtree Panic badniks | Bit 0: normal/damaged variant. |
| `$B7` | Metallic Madness propeller obstacle | Subtype unused. X flip reverses the initial patrol; Y flip is ignored. Preview includes the mast and both blade assemblies. |

Movement distances are determined by the selected runtime routine, rather than
an independent distance field. The current `$18` mapping sets have two frames;
`$19` has one. Shape selectors and presets offer those actual frames. Raw bytes
are preserved, including unsupported values. The six existing HTZ `$71`
placements are labeled **Unused placement $71 (ObjNull)**: their runtime table
entry has no object handler.

The shared enemy definitions make imported art inspectable in every act. Adding
an enemy to a new stage may also require its game-side pattern load cue; editor
previews do not alter runtime art loading.

Terrain conveyors (`$A2`) are available in every zone. Cover the characters'
centers over the entire surface with their rectangles, using adjacent areas at
different heights for longer slopes. Grounded players receive one belt push per
frame, even at joins or overlaps; jumping leaves the belt's influence, and walls
limit the push using each player's collision path. The migrated Scrap Madness
Act 2 placements retain their original widths, heights, speeds and directions.

## Validation

`build_tools/check_sonlvl_objects.cs` uses the real SonLVL API to load every act,
compile definitions, render all advertised subtypes and all placed objects with
all four flips, check property round trips and verify byte-exact placement
serialization. It also rejects duplicate C# cache names and fallback definitions,
checks property-grid value conversion, and checks the path switcher's bit
preservation, sizes and numbered markers.
Optional contact sheets show each zone's object picker previews.

Compile the checker beside `SonLVLAPI.dll` and its dependencies, then run:

```text
csc /r:SonLVLAPI.dll /r:System.Drawing.dll /out:check_sonlvl_objects.exe path/to/build_tools/check_sonlvl_objects.cs
check_sonlvl_objects.exe "path/to/SonLVL INI Files/SonLVL.ini" "optional-preview-directory"
```

Keep the API DLL and codec dependencies beside the checker executable. On Linux,
run it with Mono, libgdiplus and an X display. Test with a distributed Release
build and a fresh `dllcache` directory: Release builds compile object definitions
in parallel, unlike Debug builds. Each C# object ID deliberately has its own
`codetype` wrapper in `Common/RuntimeObject.cs` so concurrent compiles write to
different cache files. Zone overrides reuse their ID's type after list merging.
The marker art in `Common/pathswapper-art.nem` comes from SonLVL's S3&K INIs;
it is editor-only and does not change the game's graphics.

The saved `Emerald Hill Zone Act 1.sls` section and `EHZ/AnimatedBlocks.bin` are
still used by SonLVL. Stale definitions and private copies of runtime maps/chunks
have been removed.

After building the ROM, the terrain-conveyor regression runs the real player
and object code in Genesis Plus GX:

```text
python build_tools/check_terrain_conveyors.py --core path/to/genesis_plus_gx_libretro.so --output path/to/conveyor-results
```

It checks both players, every subtype and flip, rectangle boundaries, joins,
both collision paths, standing and spin-dash wall contact, jumping/landing,
bumps, slopes through 45 degrees, stepped rectangles, and all 20 actual Scrap
Madness Act 2 placements. Traversal tests compare each moving-belt frame with an
otherwise identical zero-speed frame and require complete rectangle coverage.
Use `--before-ref <commit-before-migration>` to also verify the layout conversion.

Caterkiller and both Kemusi variants have real-core regression fixtures:

```text
python build_tools/check_caterkiller.py --core path/to/genesis_plus_gx_libretro.so --output path/to/caterkiller-results
python build_tools/check_kemusi.py --core path/to/genesis_plus_gx_libretro.so --output path/to/kemusi-results
```

Both support `--pal`. The first checks the 16-entry encoded trail, independent
landing, slopes/curves/steps/gaps, chain lifetimes, the original `$40`-byte private
state limit, and measured 68000 cycles. `--baseline --rom <old-ROM> --listing
<old-listing>` records the older Caterkiller for comparison. The second checks
the native placements, both players' attacks on every piece, art surviving the
indoor animation update, and controller-driven Debug placement of all three
variants together. The engine's shared `$4E`-byte object stride is unchanged.

`python build_tools/check_wheel_carriers.py --core path/to/genesis_plus_gx_libretro.so --output path/to/wheel-results`
checks all eight carrier payloads against walls in both directions, low/high
overhangs, airborne contact, both monitor riders, consumed-payload clearance,
and native bumps/slopes/curves. Add `--pal` for PAL or `--probe` to record an older
ROM's failures. Payload wall bounds are configured in `WheelPayloads` alongside
the mount offset, subtype and facing flags.

`python build_tools/check_propeller.py --core path/to/genesis_plus_gx_libretro.so --output path/to/propeller-results`
checks the propeller's original CD timing/frame sequence, both players' standing
and rolling contacts, invincibility, real Debug placement, loading/reloading,
pool exhaustion/reused slots, and native bumps/slopes/curves. Add `--pal` for PAL.
The 49-tile art bank is resident alongside the PP enemies in LV0A; Act 1 has a
sample placement at X `$0640`. Other levels need the corresponding PLC entry
before using the obstacle. Its three SSTs keep private state within `$40` bytes.

`build_tools/import_propeller.py --source path/to/scddisasm` reproduces its art
and mappings from the pinned test-branch source. Three copies of the shaft tile
reduce the mast from nine hardware sprites to four, with an indexed-pixel
equality check against both original base frames. The blade phase table replaces
CD's nine-state dispatch while retaining every original frame and damage toggle.
