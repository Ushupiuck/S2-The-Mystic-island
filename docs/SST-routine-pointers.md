# Routine pointers and the grouped SST

Objects now store the address of their entry routine in the longword `code`,
following S3&K's dispatch approach. `ExecuteObjects` reads that pointer and
calls it directly. Zero means an empty slot. The legacy `obID` symbol aliases
this same longword; it no longer names a numeric byte ID in RAM.

Placements still contain a **byte ID**. The six-byte layout format and the
full `$01–$FF` range are unchanged. `Obj_Index` resolves that byte once when
the manager creates an object. The existing byte `obRoutine` state machines
remain inside the imported object entry routines; this change does not claim
to rewrite every object's internal states into separate pointer routines.

## Shared display header

The SST stride is `$4E` bytes. All ordinary objects share this prefix:

| Offset | Bytes | Field | Meaning |
| --- | ---: | --- | --- |
| `$00` | 4 | `code` | Routine address; zero is empty |
| `$04` | 1 | `obRender` / `render_flags` | Drawing flags |
| `$05` | 1 | `obFrame` / `mapping_frame` | Mapping frame |
| `$06` | 1 | `height_pixels` | Display half-height |
| `$07` | 1 | `width_pixels` / `obActWid` | Display half-width |
| `$08` | 2 | `obPriority` / `priority` | Queue tier, multiples of `$80` |
| `$0A` | 2 | `obGfx` / `art_tile` | Tile base, palette and drawing attributes |
| `$0C` | 4 | `obMap` / `mappings` | Mapping pointer |
| `$10` | 4 | `obX` / `x_pos` | X integer word plus fractional word |
| `$14` | 4 | `obY` / `y_pos` | Y integer word plus fractional word |

Screen-space objects retain their alternate Y convention in `obScreenY`, now
at `$12`. The named fields adapt S1/S2/S3 imports; the complete binary layout
is not identical to stock S3&K. Use symbols rather than copied source offsets.

The former stride was `$4A`. Widening the ID and grouping the header moved
the old private fields forward by four bytes. Tails's last byte now occupies
`$4C`, requiring an even `$4E` stride. Invincibility stores its four angles
and four animation indexes in the eight unused composite padding bytes,
so it needs no larger stride. Clearing/copying handles the final word after
the longwords. The 68000 requires even addresses for word/long operands;
four-byte alignment is not required. Growth from `$4A` costs `$1C4` bytes
across 113 slots; packing the stars saves `$E2` (226) bytes versus `$50`.

## Fields used by many objects

| Offset | Bytes | Field |
| --- | ---: | --- |
| `$18`, `$1A` | 2 each | `obVelX`, `obVelY` |
| `$1C`, `$1D` | 1 each | `obHeight`, `obWidth`: collision radii |
| `$1E`, `$1F` | 1 each | `obTimeFrame`, `obAniFrame` |
| `$20`, `$21` | 1 each | `obAnim`, `obPrevAni` |
| `$22` | 2 | `respawn_addr`: placement-state pointer |
| `$24`, `$25` | 1 each | `obRoutine`, `ob2ndRout` |
| `$26` | 1 | `obAngle` |
| `$28`, `$29` | 1 each | `obColType`, `obColProp` |
| `$2A` | 1 | `obStatus` |
| `$2C`, `$2D` | 1 each | `obSubtype`, `ob2ndSubtype` |

These names do not reserve every byte for every object. Objects may reuse
services/fields they do not need. `objoff_XX` aliases name their actual byte
offsets, and private data can begin wherever an object's active services allow.
For example, the players use `$28–$29` as the word `obInertia`, and composites
use ordinary velocity/animation/state space as child records.

## Player fields

| Offset | Bytes | Field |
| --- | ---: | --- |
| `$27`, `$2B` | 1 each | `flip_angle`, `scroll_delay_counter` |
| `$2C`, `$2D` | 1 each | `air_left`, `flip_turned` |
| `$2E`, `$2F` | 1 each | `obControl`, `obStatusSecondary` |
| `$30`, `$31` | 1 each | `flips_remaining`, `flip_speed` |
| `$32` | 2 | `move_lock` |
| `$34`, `$36`, `$38` | 2 each | `flashtime`, `invtime`, `shoetime` |
| `$3A`, `$3B` | 1 each | `next_tilt`, `tilt` |
| `$3C`, `$3D` | 1 each | `stick_to_convex`, `spindash_flag` |
| `$3E` | 2 | `spindash_counter` / `restart_countdown` |
| `$40`, `$41` | 1 each | `jumping`, `standonobject` |
| `$42`, `$43` | 1 each | `obTopSolidBit`, `obLRBSolidBit` |
| `$44` | 1 | `tails_hidden` |
| `$46` | 2 | `player_dust_ptr` |
| `$48`, `$49` | 1 each | `default_y_radius`, `default_x_radius` |
| `$4A`, `$4B`, `$4C` | 1 each | `character_id`, `tails_flight_flag`, `tails_flight_energy` |

`$45` and `$4D` are available private player scratch. The tail object has
its own overlays, including a full remembered interaction pointer at `$2E`
and the companion's ledge-attempt timer at `$32–$33`.
Two reserved splash slots cache their physical water/dust banks at `$34–$35`.

## Importing and creating objects

```asm
        bsr.w   FindFreeObj
        bne.s   .return
        move.l  #Obj_NewObject,code(a1)
        move.w  obX(a0),obX(a1)
        move.w  obY(a0),obY(a1)
```

For a level placement, add `dc.l Obj_NewObject` to `Obj_Index` and keep the
layout's ID byte. For a scripted child, write the entry pointer directly.
For an S3 object which changes `code` to a state routine, no dispatch-table
entry is needed for each state. Adapt any identity/parent checks to those
states too: existing checks compare the stable entry routine of their object.

Existence tests use `tst.l code(a0)`, deletion clears the longword, and identity
checks use `cmpi.l #Obj_NewObject,code(a0)`. A ROM pointer such as `$00123456`
has a zero high byte on the big-endian 68000. `tst.b code(a0)` would incorrectly
classify it as empty. Test fixtures can project a pointer back to a placement
ID as `layout_id`; the engine does not perform that reverse lookup.

Mappings and DPLCs retain the S3&K format. A normal build derives bounds from
the included mapping tables. See [the EHZ import example](Importing-objects-EHZ-boss.md)
for initializers and composite bounds.

## Composites and RAM

Composites use main frame `$05`, width `$07`, height `$06`, child count `$16`
and eight six-byte child records at `$18–$47`. Each record contains X/Y words,
a padding byte and a mapping-frame byte. Such helpers bypass ordinary state
dispatch and use the shared composite renderer. Invincibility stars keep their
four angles in child-padding bytes `$1C/$22/$28/$2E`, and four animation
indexes in `$34/$3A/$40/$46`; flags reuse priority. Each child writer skips
the padding byte and writes only its frame byte. This remains safe when
offscreen children are omitted and visible children are compacted.

The pool still contains 23 reserved and 90 dynamic slots: `$226E` bytes from
`$FFA000` to `$FFC26D`. The block table starts at `$FFC26E`. Pool slack and
retired state RAM fund the growth; 580 bytes remain in `Free_LegacyObjectState`.
The error buffer moves to `$FFE62E`, while the sprite queue and later RAM keep
their addresses. Assembly guards reject growth beyond this budget.

Debug records are 12 bytes: code long, mapping long, subtype byte, preview-frame
byte and art word. The primary character's own code remains intact in Debug;
the created object receives the selected routine pointer.

The conversion includes objects embedded in `main.asm`, children, fragments,
unused/WIP sources and the test tools. It preserves the dedicated ring records
and S1 special-stage mapping ABI. The two-rider bridge regression caught an old
literal scratch offset overwriting a child pointer; its indexes now use named
offsets. Native tests exercise arbitrary routines outside `Obj_Index`, pointer
state changes, the final slot, deleted sprite queues and full CPU identity.
The [follow-up SST audit](SST-audit.md) records all object sources, packed
overlays and the pointer/stack regressions found after this conversion.
