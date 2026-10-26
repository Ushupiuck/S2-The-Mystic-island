# Objects, loading and Debug

Placement constants live in `_definitions/s2.constants.asm`; shared execution
and rendering live in `md-main.asm`. Mode 1 uses `_inc/Objects Manager.asm`
for MD loading/application and `_inc/Mega CD Objects.asm` for CD placement
selection and working state. The cartridge build uses `md-only/Objects Manager.asm`.
See [Mega-CD](Mega-CD.md#cpu-work-and-ring-jobs) for CPU ownership. The loader
is adapted from S3&K `Load_Sprites`, using skdisasm
`73de97c6b55055bcb8089c1d55d006b02136f163`. `ObjectsManager` and `Load_Sprites`
name the same entry. Execution continues after the primary character dies.

## SST and dispatch

Each object status table (SST) is `$4E` bytes. The pool contains 23 reserved and
90 dynamic slots, bounded by `v_objspace`/`v_objspace_end`; dynamic slots start
at `v_lvlobjspace`. `TempArray_LayerDef` follows the pool in Mode 1; terrain blocks live
in CD PRG RAM, with Word-RAM load staging named `v_16x16`. Absolute addresses
depend on the selected RAM map; see [Mega-CD](Mega-CD.md#memory-and-ownership).
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
| `$22` | 2 | `respawn_addr`: placement-state handle (index + 1), zero for dynamic objects |
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

Snailbot's animation tails push `MarkObjGone(pc)` with `pea`,
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

Both build configurations use three state banks, one for
each era, with one byte per placement. Good and Bad Future share the third
bank. Mode 1 stores three `$300`-byte banks at `MCD_ObjectRespawn_Sub`;
cartridge mode stores three `$180`-byte banks at `Object_Respawn_Table`.
Bit 7 marks loaded/consumed, with seven local-state bits. `respawn_addr` stores
index + 1, and zero means dynamic/Debug-owned. Use `Object_RespawnRead`,
`Object_RespawnConsume`, `Object_RespawnRelease` and `Object_RespawnBump`;
`Object_PlacementX` retrieves the original placement X. Never reinterpret a
handle as an MD pointer. The Mode 1 `MCD_*` labels remain same-address aliases
for existing diagnostics. The [build selection](Mega-CD.md#cartridge-build-dependencies)
changes storage and execution, while preserving the object-facing contract.

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
| GHZ ship | Saved flash color `$2E-$2F`, weapon-ready byte `$30`, breakup clock `$31`, base X/Y longs `$34/$3C`, timer `$40-$41`, flash/bob bytes `$42/$43` |
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
follows the scroll scratch area (`v_ssbg_sines_end`); the Debug snapshot then
immediately precedes
`Object_Display_Lists`. Use the declared boundaries rather than old absolute
addresses. Test-only object-course coverage uses `Free_RAM_Start` with a capacity
check, and is absent from ordinary builds.

## Debug

Only the initialized primary player enters Debug; controller 2/companion AI
retain their ordinary precedence. In level select's SOUND TEST, play `01`, `03`,
`05`, `07` in order using B, C or START. Completing the code plays the ring
jingle and unlocks Debug without changing level select. Wrong sounds reset the
sequence; playing `01` starts another attempt. Moving the selector does not
count. Hold A while launching a normal level or the rotating S1 stage to enable
Debug there. The old title-screen Debug variant is retired; the title's
level-select and slow-motion cheats remain.

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

## Swinging platforms: S1/S2 coverage and S3&K variants

`objects/17 Swinging Platforms.asm` already combines S2's packed-chain movement
with S1-style platform/ball art and collision. This is a comparison of the
current implementation, with the consolidated half-swing and MGZ-style rotation
now implemented. Bits 0–3 select chain length and bits 4–7 select the family.
For family 3, bits 8–15 seed its private starting angle before the constructor
reduces the stored subtype to the family; other families ignore those bits.

| Current family | Behavior | Original counterpart / differences |
| --- | --- | --- |
| `$0n` | Ordinary pendulum | S1 `$15` / S2 `$15`; shared fast oscillator, X-flipped phase, radius `16*n+8` |
| `$1n` | Left/right half-swing with a stop at the bottom | X-flip selects the right half. Pre-reflecting the oscillator before clamping preserves S2 `$10/$30` timing, including the alternating active/waiting intervals. Sound remains optional and must suit the zone/material. |
| `$2n` | Static hanging platform at a chosen length | S2 `$20` uses a special fixed rope mapping and a 136 px drop regardless of the low nibble; ours generalizes length, so raw `$20` now drops only 8 px |
| `$PP3n` | Continuous full rotation | MGZ-style one angle unit/update (256 updates/revolution), with our configurable `16*n+8` radius. `PP` is the starting angle: `$00` right, `$40` down, `$80` left, `$C0` up; X-flip mirrors the starting pose and reverses rotation. |
| `$4n` | Proximity-triggered accelerating trap, 60-update endpoint waits | S2 `$40` motion; the giant-ball art/hurtbox is an intentional placeholder, not a missing OOZ-art requirement. The primary character's X proximity triggers it; companion-only proximity does not. |
| `$5n` | Swinging giant ball with safe platform top and harmful underside/sides | Custom extension of the S1 SLZ-style safe-top ball; its current giant-ball appearance is intentional. The SLZ constructor branch also retains its smaller ball configuration; it is a zone choice, not another family. |
| `$6n` | Detachable normal swing | Re-encodes S2's bit-7 detachment as a separate family, losing its combinations with the other motion families |
| `$7n` | Fully harmful pendulum ball, no platform top | S1 SBZ-style motion/collision, made explicitly selectable; SMZ uses its resident atlas. This hazard role is useful outside SBZ too, including Labyrinth. |

S1's ordinary platform and zone-specific SLZ/SBZ balls use separate SSTs for
links and anchor: a length-`n` ordinary swing needs `n+2` objects in total.
The unused S1 `$1n` flag selects GHZ giant-ball art/a 40-by-40 hurtbox; S1 does
not globally disable platform collision for this flag as it does for SBZ.
Our S2-style packed helper keeps the normal chain at two SSTs total and computes
one sine/cosine pair for all links. Retaining that is already a substantial
improvement over the S1 per-link movement/objects.

The unification is not a complete S2 behavioral superset:

- S2's bit 7 is independent of its `$00/$10/$20/$30/$40` motion selector.
  Thus `$96` can combine left-bouncing with detachment, while our `$6n` can
  only detach a normal swing. `$50/$60/$70` in S2 are normal-motion aliases,
  not the ball/detach/hazard families assigned by our format.
- S2 chooses detached state `$0C` in ARZ: fall to the live water level, float,
  drift and stop against a wall. Our floating handler exists, but the detach
  constructor always chooses state `$0A`; no live transition selects `$0C`.
  The reachable falling state retains S2's level-specific fixed Y `$0720`.
- Original S2 OOZ/MCZ/ARZ visual/size configurations are not all selectable in
  our GHZ/SLZ/SMZ constructor. Keeping each motion concept does not preserve
  every original raw subtype or appearance.

S3&K splits the family into specialized objects instead of one universal
replacement:

| S3&K object | Useful behavior | Difference / cost |
| --- | --- | --- |
| `Obj_SOZSwingingPlatform` | Closest continuation of S2's packed pendulum: vertical as well as horizontal movement mirroring, and a rider-triggered accelerating swing with a rider-dependent pause | Its trigger still tests primary standing bit 3. Its chain geometry/attachment offsets differ from ours, so importing its raw placement values would not preserve our geometry. |
| `Obj_DEZLiftPad` | Closely related packed-segment lift: rider-triggered, eased quarter-turn movement, orientation choices and a rider-dependent 30-update pause | Uses the same sine/cosine/cached-angle approach as SOZ, with a smaller angular sweep. Its trigger also tests primary standing bit 3; it is a reusable additional motion style. |
| `Obj_MGZSwingingPlatform` | Continuous full rotation, independent starting angle, direction and 256-update period | Fixed 80 px radius/four packed links; top-only collision. It supplies another path, rather than replacing S2's movement families. |
| `Obj_ICZSwingingPlatform` | Either rider can impart horizontal momentum; capped angular velocity, a returning pendulum, optional breakaway launch, terrain bounce, slide/friction and chain breakup | Full solidity through separate collision children. Its normal construction uses a controller plus three children; the elaborate ice platform is a different gameplay mechanism from the automatic S1/S2 swing. |
| MGZ/LRZ swinging spikeballs | Further rotating hazard paths and, in MGZ, swing sounds | Hazard siblings rather than ordinary safe-top platforms; not a substitute for all S1/S2 variants. |

A useful future design keeps our existing S1/S2 motion choices and the packed
helper, makes motion/collision/detachment independent within the subtype word,
and adds selected S3&K mechanisms explicitly. SOZ and DEZ Lift Pad are close motion-code
relatives; ICZ offers the richest additional interaction. The existing `$4E`
SST and all universal offsets stay fixed. Sensible link counts remain essential;
this comparison does not propose expanding SSTs or their packed storage.

DEZ's quarter-turn `Obj_DEZLiftPad` should be distinguished from
`Obj_DEZHangCarrier`: the latter attaches players beneath a grip, accelerates
upward until a ceiling probe stops it, then travels horizontally at 2 px/update
for `subtype*4` updates (`subtype*8` pixels). The grip moves through a right-angle
route; Lift Pad moves its rigid segmented arm through a quarter-circle. Both
are lifts by function, but their movement and attachment code differ.

The Mystic Cave half-swings coordinate through the shared oscillator; they do
not exchange pointers or activation signals. One waits at angle `$40` while the
other moves. The unified `$1n` computes `128-max(128-angle,64)` when flipped,
which equals the old right-half `min(angle,64)`, rather than merely mirroring
the left half at the same phase. No authored placement used the former `$3n`;
GHZ Debug's `$35` now previews/places the rotator and its stale `$85` detachable
entry is corrected to `$65`. SonLVL exposes the new rotation phase and draws
all chain links using the engine's sine table. One-link chains keep their anchor
art at the pivot. The `$4E` SST and universal offsets are unchanged.

### Remaining extension direction (not implemented)

Keep sound, appearance and collision choices distinct from the movement path.
The current `$4n/$5n` giant balls are intentional; their artwork does not need
to be replaced to preserve the S2 movement. A half-swing impact sound should
be optional and chosen for the zone/material rather than always playing a
wooden knock.

| Mechanism | Planned treatment |
| --- | --- |
| SOZ swing elevator | Its original rider-triggered path has vertically separated endpoints and horizontal curvature. Add a quarter-turn of the movement angle for horizontally separated endpoints; mirroring selects the side of the arc, including an upward or downward curve. Either live rider must be able to trigger/hold it. |
| DEZ quarter-turn lift | Retain the eased, rider-triggered smaller angular sweep as another motion choice with configurable orientation. |
| ICZ momentum swing | Retain rider-imparted motion, with optional breakaway. Share the detached-body update with the S2-style release where practical; each trigger supplies its own release velocity and chain response. |

The shared detached body should use gravity and the first actual environmental
contact: terrain leads to a bounce and friction/slide; crossing an enabled water
surface from above leads to floating, bobbing and drift. Check the current act's
`Water_flag` and live water height, not its zone ID or S2's fixed `$0720` floor.
A floor above the water must win over the surface below it. Chain retention or
breakup remains a release-style choice; sharing the body controller does not
require identical launch or chain behavior.

S1 Labyrinth's original `SpikeBall` (`$57`, shared with SYZ) is a useful further
hazard reference: it continuously rotates rather than pendulum-swinging, and
its LZ chain is harmless while the tip hurts. A rotating path and a fully
harmful body should therefore be combinable without making every chain link
harmful or forcing the current `$7n` pendulum to change its path.

These are design constraints, not a new subtype bit allocation or implemented
modes. Keep the existing `$4E` SST/universal offsets and sensible packed link
counts throughout the extension.

### Confirmed current boundaries and defects

Native execution against the current Mode 1 ROM reproduced these cases:

- Child records begin at `$18` and occupy six bytes each. Nine raw records
  happen to end exactly at `$4E`, although the declared composite layout and
  fixed helper bounds cover eight. Ten links overwrite six bytes of the next
  SST; `$F` links overwrite 36. The subsprite count field itself is a byte;
  its numeric capacity is not additional record storage. Authored swings use
  at most eight links (17 placements across GHZ2/3 and SMZ2).
- If detached-child allocation fails, the parent still advances to non-solid
  state 8 and clears its standing flags without producing a falling child.
- A successful detached copy inherits the parent's placement handle. Excluding
  packed helpers (whose overlaid `$22` bytes are not handles), two objects own
  the same placement. Unloading the child clears the loaded bit while the
  hanging parent remains live.

These findings are pending fixes. Null-helper motion/deletion, zero-angle
startup and the trap's positive endpoint cache are repaired. The motion runner
checks both half-swings, rotation and these boundaries; the contact runner
checks safe tops and harmful sides/undersides. Neither establishes complete
detachment/allocation coverage.

References: [our implementation](../objects/17%20Swinging%20Platforms.asm),
[S1 `$15`](https://github.com/sonicretro/s1disasm/blob/15dfa3a6ee4c53aeb482233e493755c84b4f3479/_incObj/15%20Swinging%20Platforms.asm),
[S2 Final `$15`](https://github.com/sonicretro/s2disasm/blob/4ef457c18fc4902396c43ab06fabc119ac6ecb64/s2.asm#L22487),
[S3&K MGZ](https://github.com/sonicretro/skdisasm/blob/73de97c6b55055bcb8089c1d55d006b02136f163/sonic3k.asm#L70499),
[SOZ](https://github.com/sonicretro/skdisasm/blob/73de97c6b55055bcb8089c1d55d006b02136f163/sonic3k.asm#L86365),
[DEZ Lift Pad](https://github.com/sonicretro/skdisasm/blob/73de97c6b55055bcb8089c1d55d006b02136f163/sonic3k.asm#L93132),
[DEZ Hang Carrier](https://github.com/sonicretro/skdisasm/blob/73de97c6b55055bcb8089c1d55d006b02136f163/sonic3k.asm#L92885),
[ICZ](https://github.com/sonicretro/skdisasm/blob/73de97c6b55055bcb8089c1d55d006b02136f163/sonic3k.asm#L188968),
and [S1 SYZ/LZ `$57`](https://github.com/sonicretro/s1disasm/blob/15dfa3a6ee4c53aeb482233e493755c84b4f3479/_incObj/57%20SYZ,%20LZ%20Spiked%20Ball%20and%20Chain.asm).

## Ordinary platforms and Flying Battery's hovering platform

`objects/18 Platforms.asm` combines S3&K's ordinary floating-platform movement
core with S1's centred vertical distances and switch rise, the shared S3&K LBZ
fall, and S2's optional full-body solidity. Existing GHZ/EHZ art and mappings
stay in use. `ExecuteObjects` calls the chosen top/full update pointer directly;
the constructor also caches its movement routine pointer. Internal falling and
switch-rise transitions replace that cached pointer without changing settings.

| Movement nibble | Behavior | Origin / profile |
| --- | --- | --- |
| `$0` | Stationary | Placement position |
| `$1/$2` | Horizontal 64/128 px | S3&K endpoint origin and oscillator profiles |
| `$3/$4` | Vertical 64/128 px | S1 centre origin; S3&K oscillator profiles |
| `$5/$6` | Up/down diagonals, 128 by 64 px | S3&K endpoint conventions |
| `$7` | Rider-triggered ceiling trap | Either rider; no sag; S3&K acceleration/ceiling/entrapment behavior |
| `$8/$9/$A/$B` | Squares, 32/96/160/224 px sides | S3&K centre origin, edge stepping and reload phase |
| `$C` | Eased horizontal 256 px | S3&K local acceleration/braking, extended lifetime |
| `$D` | Vertical 96 px | S1 centre origin and the corresponding shared oscillator |
| `$E` | Fall after standing | Either rider starts a 30-update delay; carry 32 updates, then detach both with inherited velocity |
| `$F` | Switch-triggered rise | Selected channel; 60-update delay, rise 512 px at 2 px/update, stop |

The complete subtype word is `CCCC 0PPS FTTT MMMM`:

| Bits | Meaning |
| --- | --- |
| 0–3 | Movement above |
| 4–6 | Shape/frame; the current two-frame mappings expose shapes 0/1; absent shapes fall back to 0 |
| 7 | Full S2 body solidity; clear means a one-way top. Full body uses a 48-pixel vertical radius and both-player side/underside response. |
| 8 | Rider sag: either rider depresses the platform by up to 4 px. Independent of movement; ignored by the ceiling trap. |
| 9–10 | Phase / initial square corner, XOR with placement X/Y flips. Oscillation and long horizontal motion use bit 0; squares use both. |
| 11 | Reserved |
| 12–15 | Switch channel 0–15, used only by movement `$F` |

For example, `$A19F` is switch-A rising, shape 1, full solidity and sag.
Full solidity, shape, sag and channel no longer compete for subtype bits.
The authored word remains intact throughout runtime state transitions. Private
state uses `$2E-$47`; all universal fields and `$4E` SST stride remain fixed.

The selected S3&K oscillator rows already exist in the shared engine table:
64 px uses `$0A`, 128 px uses `$1E`, 96 px uses `$0E`, and square movement uses
`$2A/$2E/$32/$36` relative to `v_oscillate`. Original faster 64/128 px timing
was deliberately replaced. Unrelated oscillator rows and their existing object
consumers are unchanged. Vertical distances and centred travel areas remain S1's.

All 72 original ordinary-platform placements, Debug entries and SonLVL settings
were migrated together. Horizontal placements move their authored origin 64 px
left to retain the same travel area under S3&K's endpoint convention; reversed
phases and formerly ignored placement flips are accounted for in the word.
Existing platforms keep sag enabled. New SonLVL picker presets are rigid until
the separate sag property is enabled. Its guides show endpoint horizontal and
diagonal paths, centred vertical/square paths and both long-path phases.
Falling platforms continue easing their sag back after detaching their riders;
becoming intangible does not snap the displayed height to the unsagged path.

S3&K's `$380` retention interval keeps the long path alive; its retained origin
also accounts for the reversed path's leftward reach. Unloading releases actual
placement ownership for a clean reload. Current shape indexing excludes bit 7,
the full path actually calls `SolidObject`, either player can trigger falling,
and the rider-detach helper returns without entering the switch handler.

The ceiling trap closely matches S1's separate `LabyrinthBlock` rising trap
(`$61`, subtype `$13` followed by `$14`), suggesting reused lineage. Its S3&K
profile activates without S1's 30-update delay and ceases acceleration after
128 px, then cruises. The platform has its own primary-path ceiling sensor;
S3&K's additional rider-entrapment probe samples inside each standing player's
body using that player's L/R/B collision path. It is not a head-only sensor.
The exact S1 delayed/continuously accelerating trap profile is not implemented.

References: [S1 ordinary platforms](https://github.com/sonicretro/s1disasm/blob/15dfa3a6ee4c53aeb482233e493755c84b4f3479/_incObj/18%20Platforms.asm),
[S1 LZ blocks](https://github.com/sonicretro/s1disasm/blob/15dfa3a6ee4c53aeb482233e493755c84b4f3479/_incObj/61%20LZ%20Blocks.asm),
[S2 Final constructor/full solidity](https://github.com/sonicretro/s2disasm/blob/4ef457c18fc4902396c43ab06fabc119ac6ecb64/s2.asm#L23221),
and [S3&K shared movement tables/handlers](https://github.com/sonicretro/skdisasm/blob/73de97c6b55055bcb8089c1d55d006b02136f163/sonic3k.asm#L50198).

FBZ's jet-powered `Obj_FBZFloatingPlatform` (`$71`) has its own five-entry
movement table. Treat it as a specialized relative; it does not replace every
ordinary-platform mode:

| Behavior | Current `$18` platform | S3&K FBZ `$71` |
| --- | --- | --- |
| Resting motion | Rigid or configurable 4 px rider sag | Continuous eight-pixel sine bob above/below its saved Y |
| Repeating travel | Horizontal 64/128/256 px; vertical 64/96/128 px; diagonals and squares | Vertical 64/128 px; circle of radius 64 px with 16 initial phases |
| Activation | Either-player falling/trap; selected-switch delayed 512 px rise | Either player triggers one vertical trip, then bobbing at the destination |
| Solidity | Top-only or S2 full body for both players | `SolidObjectFull_Offset` for both players, with the solid deck offset above its origin |
| Damage/animation | No platform hurtbox; static mapping frame | Separate central 40-by-32-pixel hurtbox (`$8C`); three-frame engine animation |

FBZ's trigger waits for a bob zero crossing before starting the trip. Its
speed increases/decreases by four accumulator units per frame, producing
acceleration and braking rather than our fixed-speed switch rise. X flip
selects upward instead of downward travel. On arrival it saves the new Y and
switches permanently to ordinary bobbing until the object reloads. Leaving
the platform does not cancel or reverse that trip. Our `$19` CPZ platform
already has either-player movement triggers, so rider activation itself is
not a missing engine capability.

FBZ decodes its subtype differently from our word settings above:

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
S3&K table now supplies our diagonal, square and longer horizontal motion.
No FBZ platform code
or assets have been imported.

Reference: skdisasm `73de97c6b55055bcb8089c1d55d006b02136f163`,
[`Obj_FloatingPlatform`, `FloatingPlatformIndex`, `Obj_FBZFloatingPlatform`
and collision helpers](https://github.com/sonicretro/skdisasm/blob/73de97c6b55055bcb8089c1d55d006b02136f163/sonic3k.asm),
plus its [FBZ SonLVL definition](https://github.com/sonicretro/skdisasm/blob/73de97c6b55055bcb8089c1d55d006b02136f163/SonLVL%20INI%20Files/FBZ/FloatingPlatform.cs).

## GHZ boss and boss explosions

`objects/S1/3D Boss - Green Hill.asm` retains the classic ship, faces, eight-hit
fight and escape. Flight follows S1's timed pattern: a 120-frame opening pause,
a quarter-pixel/frame first pass from the center, then one-pixel/frame return
passes separated by the original wait counter. The predecremented `$7F`/`$3F`
movement timers preserve S1's exact subpixel endpoints, rather than reversing
at invented coordinate bounds. Vertical bobbing continues through pauses.

Each of the six weapon pieces drops two pixels/frame to its own stop, then the
root signals readiness. The mount ends 32 pixels below the ship and the ball's
radius remains 96 pixels. The pendulum waits for the first flight pass, then
keeps swinging during subsequent pauses. One sine call positions all links.
The ship and weapon constructors retry insufficient SST capacity; flight waits
at the anchor until the complete weapon is ready, without wrapping its timer.

Defeat immediately makes the attached weapon harmless. After the first boss
burst is created, a shared clock waits 64 boss updates before releasing the
mount, four links and ball together as independent debris. The clock occupies
the ship's previously unused private byte `$31`; no SST or global allocation
grows. If no burst slot becomes available during the defeat phase, recovery
still releases the pieces. Debris uses Sky Sanctuary's indexed launch velocities
and `$38` gravity every frame.
Alternating drawing never gates movement. Detached pieces stop reading their
parent; faces/exhaust validate the ship before following it. Hit flashing saves
and restores the actual palette word, and escape uses `GetLevelMusic`.

`objects/FC, FD & FE Explosions.asm` owns the shared boss burst controller and
its visual object. Both GHZ and EHZ call `BossExplosion_Start` during their
exploding phase. The helper retries a full pool and creates one controller per
boss; byte `$4C` is reserved in both parent SSTs. Bit 0 marks controller creation;
bit 7 is set only after a burst allocation succeeds, so GHZ's breakup clock
does not run while a controller is waiting for a free visual slot. The parameter rows give the
finite counter (bit 7 means continuous), X/Y half-ranges and parent phase.
Spreads must be nonzero powers of two. The controller follows a validated
parent, stops when that phase ends, and emits every three frames. Low/high RNG
words independently place bursts in `[-range,range-1]` on each axis. Animation,
art and timing are described in [Sprites and VRAM](Sprites-and-VRAM.md#boss-explosions).

Deployment, breakup and burst cadence/RNG come from skdisasm
`73de97c6b55055bcb8089c1d55d006b02136f163`, `Obj_SSZGHZBoss`,
`Child_Draw_Sprite_FlickerMove`, `Set_IndexedVelocity` and
`Obj_CreateBossExplosion`. Ship flight and pendulum phase follow s1disasm
`15dfa3a6ee4c53aeb482233e493755c84b4f3479`,
[`3D, 48 Boss - GHZ Main and Wrecking Ball.asm`](https://github.com/sonicretro/s1disasm/blob/15dfa3a6ee4c53aeb482233e493755c84b4f3479/_incObj/3D%2C%2048%20Boss%20-%20GHZ%20Main%20and%20Wrecking%20Ball.asm)
and `15 Swinging Platforms.asm`, rather than Sky Sanctuary's flight logic.

The later breakup follows the HCZ, MGZ drill and CNZ end bosses' defeat sequence:
`BossDefeated` sets a `$3F` counter, `Wait_FadeToLevelMusic` waits 64 updates,
then the callback sets bit 4 of the parent's `$38` flags to release its parts.
CNZ's `sub_6ED4C` separately disables collision on the defeated bit and scatters
on that later flag. Mecha GHZ uses `Child_Draw_Sprite_FlickerMove`'s immediate
defeated-bit test instead. Our clock starts at the first burst allocation so
pool pressure cannot spend this delay before any explosion is created.

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
