# Objects, loading and Debug

The layout constants and aliases live in `_definitions/s2.constants.asm`; the MD loading boundary lives in
`_inc/Objects Manager.asm`, and execution/rendering in `md-main.asm`. On the CD
branch, `_inc/Mega CD Objects.asm` owns placement selection and its working
state; see [Mega-CD](Mega-CD.md#cpu-work-and-ring-jobs). The loader
is adapted from S3&K `Load_Sprites`, using skdisasm
`73de97c6b55055bcb8089c1d55d006b02136f163`. `ObjectsManager` and `Load_Sprites`
name the same entry. Execution continues after the primary character dies.

## SST and dispatch

Each object status table (SST) is `$4E` bytes. The pool contains 23 reserved and
90 dynamic slots, bounded by `v_objspace`/`v_objspace_end`; dynamic slots start
at `v_lvlobjspace`. `TempArray_LayerDef` follows the pool on the CD branch; terrain blocks live
in CD PRG RAM, with Word-RAM load staging named `v_16x16`. Absolute addresses
depend on the branch's RAM map; see [Mega-CD](Mega-CD.md#memory-and-ownership).
Use `object_size` for pointer arithmetic;
`object_size_bits` describes allocator buckets, not the actual slot stride.

| Offset | Bytes | Shared field |
| --- | ---: | --- |
| `$00` | 4 | `code` / `obID`: routine pointer, zero for an empty slot |
| `$04` | 1 | `obRender` / `render_flags` |
| `$05` | 1 | `obFrame` / `mapping_frame` |
| `$06` | 1 | `height_pixels`: display half-height |
| `$07` | 1 | `width_pixels` / `obActWid`: display half-width |
| `$08` | 2 | `obPriority`: queue tier in multiples of `$80` |
| `$0A` | 2 | `obGfx`: tile base and VDP attributes |
| `$0C` | 4 | `obMap`: mapping pointer |
| `$10` | 4 | `obX`: integer and fractional X words |
| `$14` | 4 | `obY`: integer and fractional Y words |
| `$18`, `$1A` | 2 each | `obVelX`, `obVelY` |
| `$1C`, `$1D` | 1 each | `obHeight`, `obWidth`: collision radii |
| `$1E`, `$1F` | 1 each | `obTimeFrame`, `obAniFrame` |
| `$20`, `$21` | 1 each | `obAnim`, `obPrevAni` |
| `$22` | 2 | `respawn_addr`: placement-state handle (CD), pointer (cartridge) |
| `$24`, `$25` | 1 each | `obRoutine`, `ob2ndRout` |
| `$26` | 1 | `obAngle` |
| `$28`, `$29` | 1 each | `obColType`, `obColProp` for NPCs |
| `$2A` | 1 | `obStatus` |
| `$2C` | 2 | `obSubtype`: complete word; no universal secondary-subtype byte |

Screen-space Y uses `obScreenY` at `$12`. Display bounds are independent of
collision radii. Fields are conventions, not separately allocated storage:
private overlays may reuse services an object does not use.

`ExecuteObjects` calls the longword `code` directly. Placement IDs remain bytes;
`Obj_Index` resolves them only when spawning. Internal `obRoutine` state machines
remain valid. Existence/deletion checks must access the full longword: the high
byte of a live ROM pointer is usually zero. Test helpers' `layout_id` is only a
reverse projection for fixtures.

On the CD branch, Snailbot's animation tails push `MarkObjGone(pc)` with `pea`,
then branch to `AnimateSprite`; animation returns into the lifetime/display service.
Both helpers consume ordinary return frames. Do not use that continuation form
with a helper that discards or rewrites its caller's frame.

Player meanings overlay the same SST. The complete player map is in the constants;
notable shared-service fields are:

| Offset | Bytes | Player meaning |
| --- | ---: | --- |
| `$28` | 2 | `obInertia`, replacing NPC collision type/property |
| `$2B` | 1 | `scroll_delay_counter` |
| `$2C` | 1 | `air_left` for companion Tails |
| `$2E`, `$2F` | 1 each | `obControl`, `obStatusSecondary` |
| `$32` | 2 | `move_lock` |
| `$34`, `$36`, `$38` | 2 each | `flashtime`, `invtime`, `shoetime` |
| `$3D`, `$3E` | 1, 2 | `spindash_flag`, `spindash_counter` |
| `$40`, `$41` | 1 each | `jumping`, `standonobject` slot index |
| `$42`, `$43` | 1 each | `obTopSolidBit`, `obLRBSolidBit` |
| `$44` | 1 | `tails_hidden` blink decision |
| `$46` | 2 | `player_dust_ptr` |
| `$48`, `$49` | 1 each | `default_y_radius`, `default_x_radius` |
| `$4A-$4C` | 1 each | `character_id`, `tails_flight_flag`, `tails_flight_energy` |
| `$4D` | 1 | `conveyor_applied`; not free scratch |

Word/long operands must be even and fit within `$4E`. Object-private `objoff_XX`
aliases name actual offsets; check the services using them before adding state.
Clearing/copying must include the final word after the longwords.

All object subtype reads, writes, comparisons, updates and child copies use
words. The word occupies the former `$2C-$2D` pair without moving other fields
or changing the slot size. A handler may define primary/secondary settings
inside that word; its masks and shifts belong to that object. Existing packed
bit-7 flags are tested explicitly after a word load, rather than relying on
the word sign bit. Animation/frame bytes remain byte fields: load the subtype
word into a register before selecting such a field. The W.I.P. button's external
override is also a word, at its private `$3C`; its `$38` validity and `$3A` used
flags retain their positions.

## Placement format and ownership

The `om*` offsets describe the eight-byte ROM placement record, not an SST.
They remain explicit `equ` offsets. Separately, `ObjectLayout_YCoordinateMask`
(`$0FFF`) extracts bits 0-11 of the word at `omY`;
`ObjectLayout_LoadAtAnyYMask` (`$8000`) selects its vertical-load-bypass bit 15.
These masks are neither offsets nor record sizes. Debug has its own record.

Top-level `level/objects/*.bin` files use the custom Mystic Island format:

| Offset | Bytes | Meaning |
| --- | ---: | --- |
| `$00` | 2 | X, sorted ascending |
| `$02` | 2 | Y in bits 0-11; X flip bit 13, Y flip bit 14, any-Y loading bit 15 |
| `$04` | 1 | Full `$01-$FF` object ID; bit 7 is not a remember flag |
| `$05` | 1 | Sonic CD presence mask: Past `$20`, Present `$40`, Future `$80` |
| `$06` | 2 | Big-endian subtype word |

End each file with `FFFF 0000 0000 0000`. `ObjectLayoutBoundary` adds a backward
boundary outside the editable data. Empty acts still require the end record.
Act selection uses four pointers per zone. All converted placements use `$E0`,
appearing in every era. Zero presence bits disable a placement. Good and Bad
Future share the Future bit, as in Sonic CD. Project `Current_Timezone` values
remain Present=0, Past=1, Good Future=2, Bad Future=3.
The mask and three-bank ownership follow scddisasm
[`CheckObjTimeZone` and `SpawnObject`](https://github.com/sonicretro/scddisasm/blob/f8cf3f0af7bf419d18182ba98554f09307ad3cc6/src/Level/Object%20Spawner.asm);
our full IDs and Y flags retain their S3&K meanings.

SonLVL uses `objectfmt=Custom` with `Common/ObjectLayout.cs`. It preserves
full-byte IDs, our Y flags, the complete subtype and timezone mask. Its raw
Subtype field is a 16-bit hex value; named object properties operate on their
own fields without discarding other bits. See the [editor guide](../SonLVL%20INI%20Files/README.md).
`build_tools/object_layout.py` owns the tools' binary codec and an explicit
`--from-s3k` conversion command. Original-game importers decode their original
source format and emit the new format; do not reinterpret original S1/S2 data
as already converted records. Debug's separate records are now 14 bytes and
also carry a word subtype, including the bonus-stage ring entry.

The camera is rounded into `$80`-pixel loading bands. The retained X interval
runs from one band behind to `$280` ahead; the Y range is `$80` above through
`$200` below. The X right edge is exclusive, Y edges inclusive. Any-Y objects
bypass the vertical test; use this for origins far from their visible parts.
The existing vertical wrap period is `$800`.

Horizontal/vertical movement and large camera jumps advance matching layout
and respawn pointers. A full pool schedules a stationary retry. Normal object
lifetime checks remain X-based: vertical filtering does not add automatic
Y-based deletion to every object.

On the CD branch, `MCD_ObjectRespawn_Sub` has three `$300`-byte banks, one for
each era, with one byte per placement. Good and Bad Future share the third
bank. Bit 7 marks loaded/consumed, with seven local-state bits. `respawn_addr` stores
index + 1, and zero means dynamic/Debug-owned. Use `MCD_RespawnRead`,
`MCD_RespawnConsume`, `MCD_RespawnRelease` and `MCD_RespawnBump`; never convert
a CD placement handle to an MD pointer. The cartridge branch retains its
low-word pointer into `Object_Respawn_Table`.

- Preserve the handle on initialization and leave its loaded bit set.
- `UnloadObject` releases the loaded bit and deletes a reusable out-of-range SST.
- `DeleteObject` consumes a destroyed/collected placement until the table resets.
- Check for zero before using persistent state; Debug objects have no entry.
- Children do not share the parent's respawn ownership. Delete packed helper SSTs
  directly: their overlaid `$22` bytes are child data, not a placement handle.

Normal level entry clears all era banks. `Respawn_table_keep` supports
reinitializing the same live layout. Era changes select the corresponding bank
and rescan the loading window, even with a stationary camera. Time-warp cleanup
of already active objects and generator/Good Future suppression remain future
work; the placement filter does not implement a time-travel transition.
Constructors must handle helper-allocation failure without leaking
partial parents or loaded bits.

## Composites and other records

A composite has main frame `$05`, group bounds `$06/$07`, child count `$16`,
and eight six-byte records at `$18-$47`: X word, Y word, padding byte, frame byte.
Bounds must cover moving children. `DisplaySprite3` takes explicit priority when
an object overlays `obPriority`. Child writers must preserve the padding byte.

Invincibility uses padding `$1C/$22/$28/$2E` for four orbit angles and
`$34/$3A/$40/$46` for four animation indexes. No ordinary state fields coexist
with those packed records. The separate tail's remembered interaction longword
at `$2E-$31`, approach word `$32-$33`, art cache and parent fields are independent.

Reserved shield SSTs hold physical effect-bank cache `$34`, points-frame cache
`$35`, and latest-popup word `$36-$37`. Reserved splash SSTs hold water-art kind
and frame at `$34/$35`. These are private layouts of different object types.
See [Sprites and VRAM](Sprites-and-VRAM.md) for bank ownership.

Other packed layouts require their own audit when changing fields:

| Owner | Private layout |
| --- | --- |
| Separate tail | Art cache `$38`, parent word `$42-$43`; remembered code/approach fields above |
| Shield | Parent word `$42-$43`, disjoint from bank caches |
| Caterkiller | Trail `$30-$3B`, packed parent long `$3C-$3F`, inertia `$40-$41`, distance `$42-$43` |
| W.I.P. staircase | Timer `$30-$31`, slot/touch `$32-$33`, origins `$34-$37`, four offset words `$38-$3F`, parent `$40-$43` |
| GHZ ship | Saved flash color `$2E-$2F`, weapon-ready byte `$30`, base X/Y longs `$34/$3C`, timer `$40-$41`, flash/bob bytes `$42/$43` |
| GHZ chain root | Five word child pointers `$2E-$37`, ship long `$38`, drop/radius words `$3C/$3E`, acceleration/flicker bytes `$40/$41`, angular velocity `$42-$43`, piece index `$44` |
| GHZ chain children | Root word `$2E`, ship long `$38`, drop/radius words `$3C/$3E`, flicker byte `$41`, piece index `$44` |
| Boss burst controller | Parameter bytes `$2E-$31`, countdown/main-routine bytes `$32/$33`, expected parent code long `$34`, parent long `$38`; parent reserves started byte `$4C` |

Caterkiller's packed parent high byte holds a segment index, relying on 68000
24-bit addressing. Combined animation/velocity writes and private records are
intentional overlays; the named-field scan cannot prove their runtime indices.

`Ring_Positions` is a separate `$600`-byte array of **six-byte** records:
timer/frame word, X word, Y word; the animation pass covers 255 slots. It does
not use the SST ABI. The S1 special stage's item/update records and mapping
format are separate too (stage update entries are eight bytes).
CD ring-animation ownership is in [Mega-CD](Mega-CD.md).

The retired state-buffer reservation has been reclaimed. `Error_Handler_Buffer`
follows the scroll scratch area (`v_ssbg_sines_end` on the CD branch); the Debug snapshot then immediately precedes
`Object_Display_Lists`. Use the declared boundaries rather than old absolute
addresses. Test-only object-course coverage uses `Free_RAM_Start` with a capacity
check, and is absent from ordinary builds.

## Debug

Only the initialized primary player enters Debug; controller 2/companion AI
retain their ordinary precedence. Enable the existing debug cheat first.
Entry is checked before player state dispatch, including hurt/death, subject
to the input locks in [Players and effects](Players-and-effects.md#input-locks-and-stage-exits).

| Input | Action |
| --- | --- |
| B | Enter placement; B in either Debug mode resumes play |
| Hold C, press B | Enter mapping-frame cycling |
| Directions | Move placement cursor with acceleration and speed cap |
| A | Next object |
| Hold A, press C | Previous object |
| C | Place selected object |

In the rotating S1 stage, C writes to its own item grid. See the snapping and
free-cell search rules in [Special stage](Special-stage.md#debug-and-movement).
Normal levels continue spawning ordinary objects with word subtypes.

Enabling the cheat leaves the ordinary HUD and timer rules active. Only
placement replaces the score with player/camera coordinates and the seconds
with the sprite count, and lets the internal clock advance without Time Over.
Leaving placement redraws the current score, rings and time immediately,
preserving whether the clock was running or stopped. Frame cycling keeps the
ordinary HUD and timer rules.

A Debug entry is 14 bytes: routine long, mappings long, subtype word, frame byte,
padding byte, art word. Lists have four pointers per zone; acts may share a list. Placement
writes a routine pointer, saves/restores mappings/art/bounds, restores standing
radii, and clears stale motion/ride/carry/flight state while preserving powerups.
Frame cycling resumes the paused state. The stage-specific ring preview and
return shortcuts are covered in [Special stage](Special-stage.md).

Reverse-gravity Debug support is not implemented. For object imports, start
with [the worked example](Importing-objects.md); for checks, use [Testing](Testing.md).

## Labyrinth conveyor

`objects/S1/1F LZ Conveyor.asm` implements placement `$1F` using S1 `$63`'s
six LZ shapes/wheel, S2 `$6C`'s relative origins, and S3&K Lava Reef's corner
movement and full solidity. Both actors can land, ride and jump off. X flip
reverses travel without mirroring the route. Switch `$E` reverses both normal
and spiked members once; its latch survives release and unload/reload, as in S1.
All decorative wheels share one DPLC-driven animation/bank; their number does
not multiply art uploads. The switch latch reverses this shared clock too.

| Subtype | Meaning |
| --- | --- |
| `$00-$7E` | Individual: high nibble = route, low nibble = initial corner |
| `$7F` | Decorative wheel, following the switch latch |
| `$80-$87` | Complete group 0-7 at the placement origin |
| `$C0-$C7` | The same groups, with safe tops and harmful spiked undersides |

`LCon_Data` is the editable relative route table: point-byte count, leftmost
and rightmost X, then signed X/Y pairs. `LCon_Placements` supplies a count minus
one and six-byte members: signed X, signed Y, settings/subtype word. Its low
byte selects route/corner; upper-byte bit 0 adds spikes to an individual member.
The parent passes settings to its children, following the W.I.P. button's
parent-supplied-settings approach. Groups 0-5 preserve S1 spacing; 6-7 are the
short/long rounded Lava Reef loops. Invalid corners use 0; invalid groups unload.

One placement owns a group. Allocation preflights all helpers and retries
unchanged when full. Children have no respawn handle; all members retain the
complete horizontal path, including wide LZ3 shapes. Use any-Y group loading.
LZ1 restores its two conveyor groups and eleven wheels, retaining unrelated
placements. Group Y values now name their true relative origins. Other LZ
object restoration remains separate.

Private fields: origin X/Y `$30/$32`, target X/Y `$34/$36`, corner/count bytes
`$38/$39`, signed step/reversal bytes `$3A/$3B`, path long `$3C`, rightmost X
and retention-width words `$40/$42`, member/settings bytes `$44/$45`.
Underside damage shares `Spike_HurtCharacter`, including both-player hit masks,
invincibility and the full-word flashing timer. Tops and sides stay harmless.
See [Sprites and VRAM](Sprites-and-VRAM.md) for its sheet and mapping sources.

Comparisons use s1disasm `15dfa3a6ee4c53aeb482233e493755c84b4f3479`, s2disasm
`4ef457c18fc4902396c43ab06fabc119ac6ecb64`, and skdisasm
`73de97c6b55055bcb8089c1d55d006b02136f163` (`Obj_LRZChainedPlatforms`). FBZ's
yellow orbs, `Obj_FBZSnakePlatform` (`$75`), use a separate delayed-train
waypoint runner, rather than this relative-path constructor.

## Ordinary platforms and Flying Battery's hovering platform

Our `objects/18 Platforms.asm` is the S1 ordinary-platform family with S2
additions. S3&K still has a separate ordinary `Obj_FloatingPlatform` for
AIZ/HCZ/MGZ: it retains the four-pixel rider sag and uses the shared
`FloatingPlatformIndex` movement table. FBZ's jet-powered platform,
`Obj_FBZFloatingPlatform` (`$71`), has its own five-entry movement table.
Treat it as a specialized relative; it does not replace every existing mode.

| Behavior | Current `$18` platform | S3&K FBZ `$71` |
| --- | --- | --- |
| Resting motion | Stationary, sagging up to 4 px under either rider | Continuous eight-pixel sine bob above/below its saved Y |
| Repeating travel | Horizontal 128 px; vertical 64/96/128 px; reversed variants | Vertical 64/128 px; circle of radius 64 px with 16 initial phases |
| Activation | Primary-player fall trigger; switch-0 delayed 512 px rise | Either player triggers one vertical trip, then bobbing at the destination |
| Solidity | Top-only `PlatformObject`; both players can ride/jump off | `SolidObjectFull_Offset` for both players, with the solid deck offset above its origin |
| Damage/animation | No platform hurtbox; static mapping frame | Separate central 40-by-32-pixel hurtbox (`$8C`); three-frame engine animation |

FBZ's trigger waits for a bob zero crossing before starting the trip. Its
speed increases/decreases by four accumulator units per frame, producing
acceleration and braking rather than our fixed-speed switch rise. X flip
selects upward instead of downward travel. On arrival it saves the new Y and
switches permanently to ordinary bobbing until the object reloads. Leaving
the platform does not cancel or reverse that trip. Our `$19` CPZ platform
already has either-player movement triggers, so rider activation itself is
not a missing engine capability.

FBZ decodes its subtype differently from our shape/high-nibble and
movement/low-nibble convention:

| FBZ subtype | Movement | Low nibble / X flip |
| --- | --- | --- |
| `$00-$0F` | Idle bob, 256-frame period | Low nibble unused |
| `$10-$1F` | Vertical, 64 px total travel | X flip reverses oscillator displacement |
| `$20-$2F` | Vertical, 128 px total travel | X flip reverses oscillator displacement |
| `$30-$3F` | Circle, 64 px radius | Low nibble selects phase in sixteenths; X flip reverses direction |
| `$40-$4F` | Rider-triggered vertical trip | Low nibble selects distance; X flip selects upward travel |

The sixteen actual trip distances are 315, 324, 342, 361, 380, 390, 410, 420,
441, 451, 473, 484, 506, 517, 540 and 552 pixels. These are integer-motion
results, also recorded by the reference SonLVL definition, rather than a
uniform distance step. Movement bits `$50-$70` index beyond the five-entry
table and are invalid. Runtime masks out subtype bit 7; the editor's `$B0`
clockwise choice is a property value that sets X flip, not a runtime bit-7
direction flag.

Useful reuse candidates are the circle and the eased, one-shot relocation,
with harmless/harmful engine behavior made explicit. Preserve our existing
sag, falling and switch modes when extending ordinary platforms. The generic
S3&K table also supplies diagonal, square and longer horizontal motion; it is
the closer comparison for a general platform upgrade. No FBZ platform code
or assets have been imported.

Reference: skdisasm `73de97c6b55055bcb8089c1d55d006b02136f163`,
[`Obj_FloatingPlatform`, `FloatingPlatformIndex`, `Obj_FBZFloatingPlatform`
and collision helpers](https://github.com/sonicretro/skdisasm/blob/73de97c6b55055bcb8089c1d55d006b02136f163/sonic3k.asm),
plus its [FBZ SonLVL definition](https://github.com/sonicretro/skdisasm/blob/73de97c6b55055bcb8089c1d55d006b02136f163/SonLVL%20INI%20Files/FBZ/FloatingPlatform.cs).

## GHZ boss and boss explosions

`objects/S1/3D Boss - Green Hill.asm` retains the classic ship, faces, eight-hit
fight and escape. Its active patrol travels one pixel/frame between the center
X ±32, reversing immediately while the ball keeps swinging. Only initial weapon
deployment waits: each of the six pieces drops two pixels/frame to its own stop,
then the root signals readiness. The mount ends 32 pixels below the ship and the
ball's radius remains 96 pixels. The S1 weighted pendulum uses one sine call for
all links. The ship and weapon constructors retry insufficient SST capacity.

On defeat, the mount, four links and ball become independent harmless debris,
using Sky Sanctuary's indexed launch velocities and `$38` gravity every frame.
Alternating drawing never gates movement. Detached pieces stop reading their
parent; faces/exhaust validate the ship before following it. Hit flashing saves
and restores the actual palette word, and escape uses `GetLevelMusic`.

`objects/FC, FD & FE Explosions.asm` owns the shared boss burst controller and
its visual object. Both GHZ and EHZ call `BossExplosion_Start` during their
exploding phase. The helper retries a full pool and creates one controller per
boss; byte `$4C` is reserved in both parent SSTs. The parameter rows give the
finite counter (bit 7 means continuous), X/Y half-ranges and parent phase.
Spreads must be nonzero powers of two. The controller follows a validated
parent, stops when that phase ends, and emits every three frames. Low/high RNG
words independently place bursts in `[-range,range-1]` on each axis. Animation,
art and timing are described in [Sprites and VRAM](Sprites-and-VRAM.md#boss-explosions).

Deployment, breakup and burst cadence/RNG come from skdisasm
`73de97c6b55055bcb8089c1d55d006b02136f163`, `Obj_SSZGHZBoss`,
`Child_Draw_Sprite_FlickerMove`, `Set_IndexedVelocity` and
`Obj_CreateBossExplosion`. The Sky Sanctuary stop-and-wait flight pattern is
not used.

The same module includes the assembled, currently unplaced `BossExplosion_Wall`
entry point. Queue `plcid_ExplosionWall`, wait for the PLC queue to finish, then
allocate a normal SST and set its `code` to `BossExplosion_Wall`. The constructor
retries until four emitter slots are available. Its anchor starts at camera
X −128 / Y +128 and advances two pixels/frame until it passes camera X +128.
The two large and two normal emitters follow it, each emitting every three
frames within ±128 pixels. These retain DEZ3's `$16/$18` profiles: large emitters
run continuously; normal emitters count down to 127 bursts, or end with the wall
sooner. The wall deletes itself and its emitters stop; already spawned visuals
finish independently. The DEZ ending transition is left to the invoking level.
Art requirements are in [Sprites and VRAM](Sprites-and-VRAM.md#boss-explosions).
