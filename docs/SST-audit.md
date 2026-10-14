# SST follow-up audit

The audit covers all 93 assembly files under `objects`, including unused,
WIP, empty and auxiliary sources, plus objects embedded in `main.asm`.
The latter include `Obj49` (waterfall), `Obj50`/`Obj51` (Aquis), `Obj4C`
(BBat) and `Obj4E` (Gator). The prior runtime coverage matrix is separate:
[Object-course-coverage.md](Object-course-coverage.md).

## Findings fixed

| Path | Finding | Correction |
| --- | --- | --- |
| Giant-ring flash | Its last frame cleared only the high word of the new routine pointer, then discarded a return address belonging to the direct object dispatcher. | Clear the full player pointer and return normally. |
| Signpost/results | Two byte-sized existence checks classified live ROM pointers as absent. | Test the full player/result-card pointer. |
| Unused Snailbot draft | A child initializer still wrote `id_Snailbot` into `code`. | Write the draft's `Snailbot` entry address. |
| Blank/Eggman monitor rewards | `a0` still identified the floating icon when damage ran. | Damage the collector through `Touch_Hurt`, then restore the icon pointer. |
| Held-charge monitor collision | Solidity skipped the spindash animation, while attack collision only accepted rolling. | Keep held charges solid on monitors. |
| Primary Tails dust | Initialization set private air, but left the shared primary-player air counter at zero in dry levels. | Initialize both primary air counters. |
| Streamed effect art | The 2,007-byte bubble file left Points, Shield and Invincibility at odd ROM addresses. DMA's word source began one byte early. | Add `even` before raw streamed art and check all 14 streamed art sources. |
| Player Debug entry | The check lived only in normal-control handlers. | Check before state dispatch, preserving initialization and primary-player ownership. |

The final named-field scan found no remaining odd word/long operands or
operands extending beyond `$4E`. `check_object_layouts.py` now checks
byte/word accesses to routine pointers (including absolute reserved slots),
numeric `id_*` values used as code pointers, and 6,261 bare named SST operands.
This checker does not trace register aliases or prove runtime array indexes.
Those cases were reviewed separately below; duplicate field meanings across
different object types are intentional, not conflicts.

## Packed records and indirect accesses

| Record or service | Reviewed layout / exception |
| --- | --- |
| Invincibility composite | Eight six-byte children occupy `$18–$47`; angles use padding `$1C/$22/$28/$2E`, animation indexes use padding `$34/$3A/$40/$46`. Child writers skip the padding, including when clipped children are compacted. Flags reuse priority because `DisplaySprite3` supplies queue priority explicitly. No ordinary state/respawn fields coexist with these records. |
| Bridge / swinging helpers | Children use the common composite ABI. Ordinary parent state and helper pointers remain in their own SSTs. Child helpers delete directly rather than interpreting the overlaid respawn word. Bridge's two-rider selectors use named scratch offsets. |
| Shield / points caches | Reserved shield SSTs retain effect-frame cache `$34`, points-frame cache `$35`, latest-points pointer `$36–$37` and shield-parent word `$42–$43`. Points uses a pointer already advanced to `$35`, then displacement `+1` reaches the even word at `$36`. |
| Water bank caches | The two reserved splash SSTs use unused scratch bytes `$34–$35`. Dust, splash and countdown share the bank/cache service; initialization and DMA retries were exercised. |
| Tails / separate tail | Player flight energy ends at `$4C`. The separate tail's CPU remembered-code longword `$2E–$31` and ledge-attempt timer `$32–$33` are disjoint from its art-frame cache `$38` and parent word `$42–$43`. |
| Caterkiller | Twelve-byte trail `$30–$3B`, packed parent longword `$3C–$3F`, inertia `$40–$41`, distance credit `$42–$43`. Parent's high byte remains a segment index, handled through the 68000's 24-bit address behavior. |
| EHZ / GHZ bosses and other multipart objects | Parent/child fields, identity tests, slot strides and fragment copying use the moved symbols/full routine pointers. Real collisions and defeat/capsule/results sequences were exercised. |
| WIP staircase | Timer `$30–$31`, touch/slot bytes `$32–$33`, origins `$34–$37`, four-word offsets `$38–$3F`, parent `$40–$43`. Stored table selectors use the named offset constants; stale comments were corrected. |
| Ring manager / S1 stage | Their six-byte ring records and eight-byte special-stage update records are separate ABIs. Bare word/byte reads in these records remain appropriate. Special-stage layout row offsets refer to the grid, not an SST. |
| Dispatch / allocation / deletion | Actual slot stride is `object_size`; `object_size_bits` describes allocator lookup buckets. Clearing/copying covers all `$4E` bytes, including the final word, without touching the next slot. Invincibility preserves the dispatcher loop counter when building children. Other stack skips remain within their own nested calls. |

Combined writes were checked where byte fields are deliberately accessed as
words/longwords: animation/previous-animation pairs, angular words and paired
X/Y velocities retain contiguous layouts. Raw offsets in `main.asm` belong
to the special-stage grid/VDP update buffers. Indexed mappings, animation
scripts, history records and composite children retain their own formats.

## Runtime checks

The current gameplay and packed-state follow-up is documented in
[Gameplay-followup.md](Gameplay-followup.md), including normal special-stage
bumper embedding, companion ledge/bridge cases and Over-screen input locks.

- Normal ROM builds both passes and generates 94 mapping bounds / 1,118 frames.
- Native 68000 regression tests cover pointer dispatch/deletion, all 28 acts,
  full-pool retries, multipart ownership, monitor collisions, 48 harmful-reward
  combinations, complete giant-ring flash, Debug entry/initialization and water banks.
- Rebuilt LZ2 course: 57 placement lifecycles and 46 interactions pass for
  Sonic/NTSC and primary Tails/PAL. The known broken conveyor stays excluded;
  Gator remains the documented unfinished object.
- Harmful monitor rewards and held-charge landings pass in real Genesis Plus GX;
  shields, zero rings, invincibility and hurt flashing are covered.
- Actual VBlank uploads match all 34 invincibility tiles and all three visible
  classic-shield DPLC frames, in both physical shield banks and after stars.
- Debug placement/frame cycling during real recoil/death and exit restoration
  pass for Sonic and primary Tails in both NTSC and PAL. Frame-cycle exit resumes
  the paused state; placement exit restores routine 2 and standing radii.
- Giant-ring contacts pass singly and in groups of three, upward/downward;
  the signpost/results route reaches the S1 stage with both primary characters
  in both regions.

Inactive/WIP sources receive source review, not claims of complete gameplay
validation. Runtime tests use explicit positioning fixtures and execute the
real object/collision/renderer/DMA code; they do not cover every subtype or
arbitrary player input sequence.

## Complete source inventory

Counts include bare named field operands in data and address instructions.
Indexed/compound addressing is covered by the separate review above.

| Source | Named operands checked |
| --- | ---: |
| `main.asm` | 802 |
| `objects/01 Sonic.asm` | 423 |
| `objects/02 Tails.asm` | 567 |
| `objects/03 Collision Switcher.asm` | 52 |
| `objects/05 Tails' Tails.asm` | 32 |
| `objects/06 EHZ Spiral.asm` | 26 |
| `objects/07 Water Surface.asm` | 19 |
| `objects/08 Water Splash.asm` | 23 |
| `objects/09 Bubbles.asm` | 81 |
| `objects/0A Drowning Countdown.asm` | 97 |
| `objects/0B Tilting platform.asm` | 25 |
| `objects/0C Labyrinth Flapdoor.asm` | 15 |
| `objects/0D Animals.asm` | 134 |
| `objects/0E Spindash Dust.asm` | 88 |
| `objects/12 & 13 Rings.asm` | 45 |
| `objects/16 HTZ Descending lift.asm` | 36 |
| `objects/17 Swinging Platforms.asm` | 179 |
| `objects/18 Platforms.asm` | 103 |
| `objects/19 CPZ Platform.asm` | 53 |
| `objects/1A Collapsing Platforms.asm` | 31 |
| `objects/1C Scenery.asm` | 13 |
| `objects/1D Bridge.asm` | 95 |
| `objects/1E HPZ Waterfall.asm` | 63 |
| `objects/20 Morphing Platform.asm` | 28 |
| `objects/26 Monitor.asm` | 48 |
| `objects/29 Monitor Content Power-Up.asm` | 34 |
| `objects/35 Invincibility Stars.asm` | 23 |
| `objects/36 Spikes.asm` | 63 |
| `objects/38 Shield.asm` | 25 |
| `objects/3E Prison Capsule.asm` | 53 |
| `objects/41 Springs.asm` | 200 |
| `objects/47 Bumper.asm` | 30 |
| `objects/55 EHZ Boss.asm` | 423 |
| `objects/79 Lamppost.asm` | 22 |
| `objects/7E Signpost.asm` | 33 |
| `objects/91 Title Sonic And Tails.asm` | 12 |
| `objects/92 Title screen palette handler.asm` | 9 |
| `objects/93 Press Start Button.asm` | 6 |
| `objects/94 Title Cards.asm` | 25 |
| `objects/95 Got Through Card.asm` | 30 |
| `objects/98 Game Over.asm` | 14 |
| `objects/Bonus & Special Stages/04 Player in Bonus Stage.asm` | 96 |
| `objects/Bonus & Special Stages/7A Special Stage Entry.asm` | 14 |
| `objects/Bonus & Special Stages/7B Giant Ring.asm` | 19 |
| `objects/Bonus & Special Stages/7C Ring Flash.asm` | 17 |
| `objects/Bonus & Special Stages/96 Special Stage Results.asm` | 28 |
| `objects/Bonus & Special Stages/97 SS Result Chaos Emeralds.asm` | 14 |
| `objects/Empty Slots/14.asm` | 2 |
| `objects/Empty Slots/15.asm` | 2 |
| `objects/Empty Slots/24.asm` | 2 |
| `objects/Empty Slots/25.asm` | 2 |
| `objects/Empty Slots/27.asm` | 2 |
| `objects/Empty Slots/28.asm` | 2 |
| `objects/Empty Slots/2A.asm` | 2 |
| `objects/Empty Slots/53.asm` | 2 |
| `objects/Enemies/21 Ball Hog.asm` | 184 |
| `objects/Enemies/22 Buzz Bomber.asm` | 47 |
| `objects/Enemies/23 Buzz Bomber Missile.asm` | 19 |
| `objects/Enemies/2B Chopper.asm` | 26 |
| `objects/Enemies/2C Jaws.asm` | 19 |
| `objects/Enemies/40 Moto Bug.asm` | 36 |
| `objects/Enemies/42 Newtron.asm` | 67 |
| `objects/Enemies/4B Buzzer.asm` | 79 |
| `objects/Enemies/4D Rhinobot.asm` | 36 |
| `objects/Enemies/4F Splats.asm` | 25 |
| `objects/Enemies/52 Piranha.asm` | 66 |
| `objects/Enemies/54 Snailbot.asm` | 79 |
| `objects/Enemies/60 Caterkiller.asm` | 153 |
| `objects/Enemies/61 Crabmeat.asm` | 61 |
| `objects/Enemies/62 Basaran.asm` | 33 |
| `objects/Enemies/63 Octus.asm` | 59 |
| `objects/FC, FD & FE Explosions.asm` | 47 |
| `objects/FF Points.asm` | 21 |
| `objects/S1/1B Collapsing Floors.asm` | 25 |
| `objects/S1/1F LZ Conveyor.asm` | 71 |
| `objects/S1/30 SBZ Small Door.asm` | 15 |
| `objects/S1/3B Purple Rock.asm` | 15 |
| `objects/S1/3C Smashable Wall.asm` | 24 |
| `objects/S1/3D Boss - Green Hill.asm` | 114 |
| `objects/S1/44 GHZ Edge Walls.asm` | 12 |
| `objects/S1/48 Eggman's Swinging Ball.asm` | 95 |
| `objects/S1/5E See-Saw.asm` | 98 |
| `objects/S1/7D Hidden Bonuses.asm` | 18 |
| `objects/S1/sub ChkObjectVisible.asm` | 5 |
| `objects/S1/sub SmashObject.asm` | 22 |
| `objects/Unused Objects/XX Potential Snailbot rewrite.asm` | 42 |
| `objects/Unused Objects/XX Redz & Motobug Variant 2.asm` | 40 |
| `objects/Unused Objects/XX Redz & Motobug.asm` | 45 |
| `objects/Unused Objects/XX Redz.asm` | 23 |
| `objects/Unused Objects/XX Spiked Pole Helix.asm` | 33 |
| `objects/W.I.P Objects/28 Animals.asm` | 131 |
| `objects/W.I.P Objects/32 Button.asm` | 25 |
| `objects/W.I.P Objects/5D Fan (S1).asm` | 23 |
| `objects/W.I.P Objects/SLZ CPZ DEZ Staircase.asm` | 44 |
