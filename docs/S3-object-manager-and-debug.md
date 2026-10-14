# S3&K object loading and Debug

The level loader follows `Load_Sprites` from
[skdisasm, commit 73de97c6](https://github.com/sonicretro/skdisasm/tree/73de97c6b55055bcb8089c1d55d006b02136f163),
adapted to Mystic Island's routine-pointer SST dispatch. Placement byte IDs
resolve through Obj_Index only when an object is created. MoDule's Sonic 2
guide, Selbi's Sonic 1 guide, and
[ProjectFM's S1 port in S1Fixed](https://github.com/RetroKoH/S1Fixed/tree/d29550bd43e4259cd43efca86642bfba0d8bf741)
were checked alongside the original implementation.

The implementation lives in `_inc/Objects Manager.asm`. `ObjectsManager` and
`Load_Sprites` name the same entry point. Objects deliberately continue to run
after the main character dies. The separate ring manager and rotating S1
bonus-stage grid retain their existing data formats.

## Placement files

All 30 top-level files in `level/objects` use six-byte S3&K records. This includes
the ending and archived Japanese layout, with 1,406 placements in total. The
four-act table still selects `Zone*8 + Act*2`; conveyor path files beneath
`level/objects/S1` are auxiliary data and were not converted.

| Offset | Size | Meaning |
| --- | --- | --- |
| `$00` | Word | X position; records sorted by X |
| `$02` | Word | Y in bits 0–11; X flip in bit 13; Y flip in bit 14; ignore Y loading range in bit 15 |
| `$04` | Byte | Full object ID |
| `$05` | Byte | Subtype |

Each file ends with `FFFF 0000 0000`. `ObjectLayoutBoundary` supplies a matching
backward boundary before its ROM label; do not put that boundary inside the
editable file. Empty acts still need the trailing record. SonLVL now uses
`objectfmt=S3K` and monitors no longer request S1's ID-bit remember flag.

Bit 7 of the ID is no longer a remember flag. Every placement has a respawn
entry. Tall waterfalls, hanging platforms, the descending lift and path
switchers bypass the Y loading range so their distant origins remain usable.
Set bit 15 for new objects whose origin can be far from their visible or
interactive parts.

## Loading and object ownership

The camera is rounded down to `$80`-pixel bands. Objects preload from one band
behind the camera to `$280` pixels ahead, and from `$80` pixels above to `$200`
below. The right X edge is exclusive; the Y edges are inclusive. Wrapped
levels retain the engine's `$800`-pixel Y period.

Front/back layout pointers advance together with their respawn pointers.
Vertical movement scans the retained X band. A single Y step scans its entering
strip; larger jumps scan the complete Y interval. Horizontal teleports first
discard skipped records. A full pool sets a retry flag, so missed eligible
placements can load even after the camera stops. Slot searches continue from
the previous result instead of starting over for every placement.

`respawn_addr` occupies the word at SST offset `$22`. It contains the low word
of a RAM address, used with `movea.w`; zero identifies an object without a
placement entry. `Object_Respawn_Table` has 768 bytes: bit 7 means loaded or
consumed, and the other seven bits belong to the object.

For an imported or new object:

- Preserve its placement pointer during initialization. Do not clear bit 7
  there, or the manager can load another copy during vertical movement.
- Use `UnloadObject` when a reusable object leaves its lifetime range. It
  clears bit 7 and deletes the SST, preserving the object's other state bits.
- Use `DeleteObject` when destruction or collection should consume the
  placement. This leaves bit 7 set until the level's respawn table resets.
- Read or update local state through the word pointer, checking for zero first.
  Debug and scripted objects must not write to the respawn table.
- Keep dynamically allocated children independent of the parent's respawn
  entry. The parent releases it after its child cleanup. Composite children
  reuse `$22` as subsprite data, so delete those children directly.

Monitors, checkpoints, bumpers and Caterkiller use the word interface.
Collapsing scenery releases its original slot when the fragments retire.
Bridges, tall waterfalls and Aquis retry failed helper allocation safely;
partially allocated bridge/waterfall helpers are rolled back. Caterkiller
retains its existing partial-chain retirement path.

Ordinary objects retain their existing X-based lifetime checks. The Y filter
controls spawning; it does not introduce Y-based deletion for every object.
Normal and hurt player states wrap their own Y coordinates, camera wrap seams
request a row redraw, and hidden water above `$7FF` stays hidden. Dead players
retain their existing frozen-camera behavior.

## RAM

The SST is `$50` bytes, with the longword routine pointer and display fields
grouped in its shared header. The pool retains 23 reserved and 90 dynamic
slots. The block table now begins at `$FFC350`; the 768-byte respawn table
remains at `$FFF6BE`. See [the field map](SST-routine-pointers.md).

Growth uses the old pool slack and part of the retired state buffer. Its
error-handler overlay moves to `$FFE710`, while the sprite queue and later
RAM remain at `$FFE8C0` and their previous addresses. Debug saves its mappings,
art and display bounds in eight bytes; 354 bytes remain explicitly free.

`Respawn_table_keep` can preserve state when reinitializing the same live
layout. Normal level initialization clears the table. Timezone-aware object
placement is separate future work.

## Debug controls

Only the primary player can enter Debug. Sonic and primary Tails use
controller 1; companion Tails keeps his controller/AI behavior.
Entry is checked before the ordinary player-state dispatch, after character
initialization, so B also works during hurt recoil and the death animation.
This follows S3&K's checks in its normal, hurt and dying handlers without
duplicating the same check in each state. C+B remains available in those
states too. Frame cycling pauses the current state; placement exit restores
normal movement.

| Input | Action |
| --- | --- |
| B during play | Enter object placement |
| Hold C and press B during play | Enter mapping-frame cycling |
| Directions during placement | Move, with S3&K's acceleration and speed cap |
| A during placement | Select the next object |
| Hold A and press C during placement | Select the previous object |
| C during placement | Place the selected object |
| B during either Debug mode | Resume play |

Frame cycling uses generated `Map_Sonic_frames` / `Map_Tails_frames` and the
matching DPLC loader. Placement saves and restores the active mappings, art
and display bounds, restores each character's standing collision radii, and
clears stale velocity, standing, carry, flight, spin and camera-delay state.
The HUD writer may clobber `d0`; reset code explicitly clears it afterward.
Power-up flags remain intact. Placement retains the preview's facing flags. The existing full-height placement travel range
is retained for testing arena entry from above or below, then restored on exit.

Debug lists have four pointers per zone, presently sharing each zone's list.
Each entry is now 12 bytes: routine pointer, mapping pointer, subtype byte,
preview-frame byte and art word. Debug places the routine pointer directly. The HPZ waterfall entry
now places object `$1E` rather than a lost ring.

The S1 bonus stage has a ring-only preview list using its loaded `$2940` bank.
Its camera also updates the X lifetime reference for Debug-placed SSTs. Debug
keeps the return zone/act and restores the stage's rolling radii and rotation
on exit. Start+A still fades to results, while Start+A on results still returns
to the title screen. The maze itself continues using its required S1 mapping
format.

S3&K's gravity-reversal cheat needs inverse-gravity physics/collision support,
which this engine does not yet have; it is recorded separately in `TODO.txt`.
The horizontal spike DMA bank-switching task also remains separate.

## Validation

After `texlua build.lua`:

```sh
python build_tools/check_object_layouts.py
python build_tools/check_sprite_bounds.py
python build_tools/check_sprite_assets.py --skdisasm /path/to/skdisasm
python build_tools/check_ghz_vram.py
python build_tools/check_ehz_boss.py
```

`build_tools/check_object_manager.py` is an optional ROM execution test requiring
the Unicorn Python package. It checks all 28 act pointers, X/Y boundaries and
flips, backtracking, wrap seams, all 768 respawn entries, full-pool stationary
retry, persistent/consumed state, partial child allocation, both primary
characters' Debug modes and restoration, and the stage ring bank. DMA and HUD
stubs deliberately clobber registers to catch unintended dependencies.

Genesis Plus GX tests covered 11 level selections in both NTSC and PAL,
primary Sonic/Tails placement and frame cycling, forward/backward movement,
companion exclusion and continued object updates after death. Both regions
passed normal and Debug Special Stage fades to results and return to gameplay;
the results-to-title shortcut also passed. The results ring displayed all eight
palette-0 frames while preserving the normal level ring bank.

The follow-up [LZ2 object course](Object-test-course.md) checks the complete
object-folder inventory, including context-dependent effects/screens and the
normal boss encounters. Its [coverage matrix](Object-course-coverage.md) lists
inactive, empty, unfinished and deliberately excluded entries explicitly.

The SST follow-up repeats the course's 57 lifecycles and 46 contacts with
Sonic in NTSC and primary Tails in PAL. `check_debug_states.py` also uses
real harmful-monitor collisions to enter placement/frame cycling during
recoil and death, then exercises exit, for both characters in both regions.
See [the complete source audit and focused regressions](SST-audit.md).
