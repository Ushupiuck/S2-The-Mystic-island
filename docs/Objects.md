# Objects, loading and Debug

The layout constants and aliases live in `_definitions/s2.constants.asm`; loading lives in
`_inc/Objects Manager.asm`, and execution/rendering in `main.asm`. The loader
is adapted from S3&K `Load_Sprites`, using skdisasm
`73de97c6b55055bcb8089c1d55d006b02136f163`. `ObjectsManager` and `Load_Sprites`
name the same entry. Execution continues after the primary character dies.

## SST and dispatch

Each object status table (SST) is `$4E` bytes. The pool contains 23 reserved and
90 dynamic slots, `$FFA000-$FFC26D`; dynamic slots start at `$FFA702`.
`v_16x16` follows at `$FFC26E`. Use `object_size` for pointer arithmetic;
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
| `$22` | 2 | `respawn_addr`: placement-state pointer |
| `$24`, `$25` | 1 each | `obRoutine`, `ob2ndRout` |
| `$26` | 1 | `obAngle` |
| `$28`, `$29` | 1 each | `obColType`, `obColProp` for NPCs |
| `$2A` | 1 | `obStatus` |
| `$2C`, `$2D` | 1 each | `obSubtype`, `ob2ndSubtype` |

Screen-space Y uses `obScreenY` at `$12`. Display bounds are independent of
collision radii. Fields are conventions, not separately allocated storage:
private overlays may reuse services an object does not use.

`ExecuteObjects` calls the longword `code` directly. Placement IDs remain bytes;
`Obj_Index` resolves them only when spawning. Internal `obRoutine` state machines
remain valid. Existence/deletion checks must access the full longword: the high
byte of a live ROM pointer is usually zero. Test helpers' `layout_id` is only a
reverse projection for fixtures.

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

## Placement format and ownership

The `om*` offsets describe the six-byte ROM placement record, not an SST.
They remain explicit `equ` offsets. Separately, `ObjectLayout_YCoordinateMask`
(`$0FFF`) extracts bits 0-11 of the word at `omY`;
`ObjectLayout_LoadAtAnyYMask` (`$8000`) selects its vertical-load-bypass bit 15.
These masks are neither offsets nor record sizes. Debug has its own record.

Top-level `level/objects/*.bin` files use six-byte S3&K records:

| Offset | Bytes | Meaning |
| --- | ---: | --- |
| `$00` | 2 | X, sorted ascending |
| `$02` | 2 | Y in bits 0-11; X flip bit 13, Y flip bit 14, any-Y loading bit 15 |
| `$04` | 1 | Full `$01-$FF` object ID; bit 7 is not a remember flag |
| `$05` | 1 | Subtype |

End each file with `FFFF 0000 0000`. `ObjectLayoutBoundary` adds a backward
boundary outside the editable data. Empty acts still require the end record.
Act selection uses four pointers per zone. SonLVL uses `objectfmt=S3K`.

The camera is rounded into `$80`-pixel loading bands. The retained X interval
runs from one band behind to `$280` ahead; the Y range is `$80` above through
`$200` below. The X right edge is exclusive, Y edges inclusive. Any-Y objects
bypass the vertical test; use this for origins far from their visible parts.
The existing vertical wrap period is `$800`.

Horizontal/vertical movement and large camera jumps advance matching layout
and respawn pointers. A full pool schedules a stationary retry. Normal object
lifetime checks remain X-based: vertical filtering does not add automatic
Y-based deletion to every object.

`Object_Respawn_Table` has `$300` bytes at `$FFF6BE`. Every placement has one
entry; bit 7 marks loaded/consumed, with seven local-state bits. `respawn_addr`
is its low-word pointer, loaded with `movea.w`; zero means dynamic/Debug-owned.

- Preserve the pointer on initialization and leave its loaded bit set.
- `UnloadObject` releases the loaded bit and deletes a reusable out-of-range SST.
- `DeleteObject` consumes a destroyed/collected placement until the table resets.
- Check the pointer for zero before accessing state; Debug objects have no entry.
- Children do not share the parent's respawn ownership. Delete packed helper SSTs
  directly: their overlaid `$22` bytes are child data, not a placement pointer.

Normal level entry clears placement state. `Respawn_table_keep` supports
reinitializing the same live layout. Timezone-specific object placement remains
future work. Constructors must handle helper-allocation failure without leaking
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

Caterkiller's packed parent high byte holds a segment index, relying on 68000
24-bit addressing. Combined animation/velocity writes and private records are
intentional overlays; the named-field scan cannot prove their runtime indices.

`Ring_Positions` is a separate `$600`-byte array of **six-byte** records:
timer/frame word, X word, Y word; the animation pass covers 255 slots. It does
not use the SST ABI. The S1 special stage's item/update records and mapping
format are separate too (stage update entries are eight bytes).
CD ring-animation ownership is in [Mega-CD](Mega-CD.md).

The retired state-buffer remainder is `Free_LegacyObjectState` (580 bytes).
`Error_Handler_Buffer` is `$FFE62E`, display lists start at `$FFE8C0`; assembly
checks protect their allocation. Do not infer free RAM from an old pool size.

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

A Debug entry is 12 bytes: routine long, mappings long, subtype byte, frame byte,
art word. Lists have four pointers per zone; acts may share a list. Placement
writes a routine pointer, saves/restores mappings/art/bounds, restores standing
radii, and clears stale motion/ride/carry/flight state while preserving powerups.
Frame cycling resumes the paused state. The stage-specific ring preview and
return shortcuts are covered in [Special stage](Special-stage.md).

Reverse-gravity Debug support is not implemented. For object imports, start
with [the worked example](Importing-objects.md); for checks, use [Testing](Testing.md).
