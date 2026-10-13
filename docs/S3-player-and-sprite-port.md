# S3&K players and sprite data

Normal Sonic and Tails behavior is adapted from
[skdisasm](https://github.com/sonicretro/skdisasm/tree/73de97c6b55055bcb8089c1d55d006b02136f163),
commit `73de97c6b55055bcb8089c1d55d006b02136f163`. Sonic retains the unfinished
homing hook and deliberate removal of rolling-jump steering lock. Super forms
and the Insta-Shield are separate future work.

Tails uses S&K body, extra and tail art, mappings, DPLCs and animation scripts.
His normal behavior includes flight, swimming, carrying Sonic, CPU following,
catch-up, automatic jumping/spindashing and ten seconds of manual controller-2
override. AI modifies a logical controller copy. `Player_mode` selects Sonic
and Tails, Sonic alone, or primary Tails; the selection UI remains future work.
Each player owns its air/countdown object. Large air bubbles restore the player
who touched them, with music changes reserved for the primary player.

Tails runs his first update during initialization, so body and tail art are
ready together. Level loading retains the initialized position history;
clearing its first X record made the follow AI step left 16 frames later.
The separate tail follows the body's flash decision in `tails_hidden` at
`$40`, without decrementing the damage timer twice. Hurt/death drawing remains
consistent with the body. Flying contacts use S3&K's upward attack sector and
original angle rounding; swimming and contacts outside that sector retain
their normal responses.

Sonic's carried animation reuses this hack's five prototype poses at mapping
frames `$D5–$D9`, with the existing art and DPLCs. Pickup selects and uploads
the centre pose immediately. Carry updates retry deferred uploads, retain the
28-pixel offset, mirror the poses and support jump release. The S3&K carry
frame numbers `$90–$92` select tumble poses in this Sonic mapping set.

Water splash remains object `$08`. Spindash/skid dust is separate object `$0E`,
with one dynamically allocated controller and one 16-tile bank per player.
The original combined splash/dust art remains an unused source asset; the
active dust file contains only its 74 charge and 16 skid tiles.

## Sprite ABI

All ordinary mappings in the root `mappings/sprite` folder, including the
unused tables, use a word piece count and six bytes per piece: signed byte Y,
byte size, tile word and signed word X. Inline spring and boss mappings in
`main.asm` use the same format. Fragment readers advance six bytes. The old
second tile word for 2P interlace is removed.

`height_pixels` is the display half-height byte at `$49`; the SST stride stays
`$4A`. `Render_Sprites` uses bounds initialized by each object; it never scans
mapping geometry to determine an object's size. Collision radii retain their
existing fields. Composite rendering uses its normal path for every composite,
including invincibility stars.
Object `$35` prepares eight packed children per player in `$10–$3F`, stores four orbit
angles and animation indices in `$40–$47`, and uses flags at `$48`. It queues
through `DisplaySprite3` because child data overlaps the ordinary priority
field. Its header covers the padded viewport, with children clipped separately.
The primary uses its reserved SST; the companion uses one dynamic SST while
invincible. Their animation/facing/history and lifetime are independent, with
shared art. Re-pickups reuse the companion object and full-pool allocation
retries occur only while needed.
No star ID check or temporary star buffer remains in `Render_Sprites`;
`height_pixels` at `$49`, the SST stride and neighboring objects stay intact.

### Initializing display bounds

The normal `build.lua` workflow regenerates `_inc/Sprite Bounds.asm` before
assembling the playable ROM. It discovers `Map*_height` and `Map*_width`
references in the included source, then uses an intermediate assembly to
resolve binary mappings, inline tables, aliases and shared frames. No separate
mapping registry or additional runtime dependency is needed. A failed pass
restores the previous generated constants and leaves the playable ROM intact.

For each six-byte piece, its height is `((size & 3) + 1) * 8` and its width is
`((size >> 2) + 1) * 8`. The vertical half-bound is the largest absolute value
of either `Y` or `Y + height`, across every piece in every frame. The horizontal
half-bound similarly covers `X` and `X + width`. These symmetric bounds also
cover flipped frames. They describe the display extent, not collision radii.

For example, `Map_Sonic_height` is `$23`: frame `$26` has a 16-pixel-high piece
at Y = -35, and no frame extends farther from the origin. This is derived data,
not a manually chosen Sonic-specific constant.

An imported ordinary object initializes its mapping and bounds together:

```asm
        move.l  #Map_NewObject,obMap(a0)
        move.b  #Map_NewObject_height,height_pixels(a0)
        move.b  #sprite_bound($18,Map_NewObject_width),width_pixels(a0)
```

The [EHZ boss import](Importing-objects-EHZ-boss.md) is a complete worked
example, including S1/S2/S3 format differences, every child initializer,
generated bounds, packed composites, art lifetimes and arena checks.

`sprite_bound` takes the larger of the legacy width and the mapping width at
assembly time. If no legacy minimum is needed, use `Map_NewObject_width`
directly. A normal build discovers the new references automatically. ASM
mapping pointer tables use `dc.w frame-Map_NewObject`; binary tables may share
or reorder their frames. Fragment constructors copy the parent's bounds when
switching to static pieces. Objects selecting from several mapping sets use
the largest bound in that family. Moving composite groups define the extent
of the whole group rather than the size of one child's mapping. Debug object
selection alone calculates the selected frame's bounds at runtime.

### Rendering

The ordinary and composite mapping loops come from S3&K's `Render_Sprites`.
HUD and ring-manager drawing remain inlined. Mapping groups return to their
queue or child loop by branch, without a BSR/RTS pair per object. Queue counts
are consumed once per priority. The ID-based object manager still needs the
deleted-object guard; the renderer reads the ID and flags together.

SAT links are initialized when the table is cleared. Each render repairs the
previous terminator and writes one new hidden terminator, while retaining
link zero in the final entry. The S1 bonus-stage layout can append to that
same chain. This removes per-piece link writes and the loop clearing every
unused sprite Y. Both paths respect `Sprite_Table_Max = 80`.

The legacy composite header remains compact: half-width at `$0E`, byte child
count at `$0F`, six-byte children at `$10`, and universal half-height at `$49`.
Screen-space objects retain their existing Y field at `$0A`; world-space
objects use `$0C` and support wrapped camera Y.

`Load_DynamicPLC` uses the S3&K word-count/packed-word run format for Sonic,
Tails, tails and dust. It reserves room for every run, including possible
128 KiB splits, before queuing a frame. A full queue leaves the cache unchanged
so the upload can be retried.

The ring manager retains its placement/collision logic and uses dedicated
eight-byte records, as the S3&K manager does. The rotating S1 bonus-stage grid
also keeps a dedicated ABI: byte count and five-byte pieces. Stock S3&K
`Slots_RenderLayout` uses that same S1 format. `BS_ShowLayout` now renders it,
appends valid sprite links and respects the shared 80-sprite limit; the old
duplicate `S1SS_ShowLayout` is removed. Files under `Old` and `Temp` remain
historical/staged sources rather than ordinary runtime mapping tables.

## Shared VRAM

| Address | Use |
| --- | --- |
| `$9880` | Monitor/signpost bank |
| `$ADC0–$AFFF` | Auxiliary shield bank, 18 tiles |
| `$B040–$B7FF` | Normal explosion and shared fiery frames, 62 tiles |
| `$B800–$BBFF` | Additional fiery explosion frames, 32 tiles |
| `$BC00–$BE3F`, `$BE40–$BFFF` | Animal banks 1 and 2, 18 and 14 tiles |
| `$C000`, `$E000` | Two 64 by 32 planes, `$1000` bytes each |
| `$D000` | Sonic body |
| `$D400`, `$D600` | Tails body and separate tail, using stock S3&K's shared allocation |
| `$D720`, `$D7A0`, `$D820` | Ring, lost ring and sparkles, starting at tile `$6B9` |
| `$D8A0–$DE5F` | HUD, shared E, debug coordinates and counters |
| `$DE60–$DE9F`, `$DEA0–$DEDF` | Primary and companion points, two tiles each |
| `$DEE0–$DFFF` | Free, nine contiguous tiles / `$120` bytes |
| `$F000–$F37F` | HScroll |
| `$F380–$F7FF` | Shared level shield/invincibility bank, tile `$79C` |
| `$F600` | S1 bonus-stage/results ring, separate from the level ring |
| `$F800–$FA7F` | Sprite table |
| `$FA80–$FBFF` | Lives art |
| `$FC00–$FDFF`, `$FE00–$FFFF` | Sonic and Tails dust |

Tails body uploads can reuse the start of the tail area, as in the original;
the largest body upload is 24 tiles and the largest tail upload is nine.
They end at `$6B7` and `$6B8`, so the ring group starts at `$6B9`.
This is not an additional independent 32-tile body allocation.
Lower test-zone/NPC allocations remain provisional. No GHZ terrain art
or block/chunk data was repacked during this port.

The shared 94-tile explosion art starts at tile `$582` / `$B040`; both
explosion mappings retain their relative offsets and shared frames. Animals
follow at `$5E0` / `$BC00` and `$5F2` / `$BE40`, ending exactly at Plane A.
The two tiles at `$B000–$B03F` are available during normal level play;
title-card and large boss-explosion art still reuse this area in their own phases.

Both star trails share 34 resident tiles at `$F380`, uploaded once when that
bank changes to stars. Classic shields stream four tiles per small frame or
twelve for the flash through `Load_DynamicPLC`, preserving their original
pixels and flips. With two shields, the primary uses `$F380` and the companion
uses `$ADC0`. When either player remains invincible, the visible shield uses
`$ADC0`, leaving the shared stars intact. Once both timers expire, the primary
shield restores its current frame at `$F380`.

The two reserved shield SSTs cache the physical banks at `$30`; retiring a
shield clears its ID while retaining that cache. Cache zero means empty,
1–6 identify shield DPLC frames, `$80` means stars, and `$FE` reserves the bank
for UI art. A full DMA queue leaves the cache unchanged and defers drawing
until the complete upload fits. No SSTs or RAM regions grow.

Act-clear reserves both banks before bonus digits reuse `$AE00–$AFFF`,
preserving logical shield state while hiding the effects. Game/time-over
lettering replaces the dead primary's bank; its reservation also stops the
companion's stars overwriting it. The old standard/EHZ shield and star PLCs
are removed. The S1 stage reuses part of `$F380–$F7FF` for rings while level
shield/invincibility effects are inactive.

The HUD's 16 letter tiles are followed by two debug-only tiles and 28 counter
tiles. Its six mutable score digits plus the fixed trailing zero support
**9,999,990** points (`Score_Max = 999999` in ten-point units). The two debug
tiles are used; the normal counters are contiguous. Moving the ring group
and removing the old two-tile gap before the HUD consolidates the remaining
free space below Plane B. Lives mappings derive their offsets from the lives
bank, so this move retains their positions, palette and pixels. Regular and
S1-stage results mappings derive the same shared HUD addresses.

Points use `ArtTile_Points = $6F3` and `ArtTile_Points_2 = $6F5`. Their
S3&K DPLCs load at most two tiles from the supplied, unchanged `Points.unc`.
Mappings repeat the existing zero tile for 1000, 10000 and 50000, retaining
all seven original labels' pixels, colors and positions. `Map_Points` bounds
are generated from its new assembly mappings by the normal build.

The attacking player's address is carried through the enemy, explosion,
animal and popup, and saved across the bumper's allocator call. Bank selection
uses the player slot, so primary Tails uses the primary bank. Each player has
one visible popup: a new award replaces only that player's previous popup
after its complete art upload fits. The predecessor gets an empty mapping
and zero vertical speed until its next update deletes it; an already queued
SST cannot be reused and accidentally render another value in that frame.

Unused shield-SST bytes `$31` and `$32–$33` hold each points bank's frame cache
and latest-popup pointer. Cache zero is empty and 1–7 identify the award DPLCs.
Mapping frame 7 is the empty retirement frame. This adds no global RAM or SSTs and is
preserved across shield retirement and re-pickup. Repeated values reuse the
resident pixels. A full DMA queue keeps the old popup/cache intact and retries
the new popup without starting its lifetime. Both points banks end before
the remaining nine free tiles at `$6F7–$6FF` and Plane B at `$E000`.

## Tails palette

All three art files use Mystic Island's runtime `palette/SonicAndTails.bin`.
S&K source indices `$0–$F` become:

```
0 6 5 3 2 4 C D E F A B 7 8 9 1
```

Transparency is preserved. The original green role uses this hack's dark-red
slot. Source skin colors `$08AE/$046A` use the deliberately warmer
`$08CE/$006C`; all other corresponding colors match exactly. SonLVL uses the
runtime palette and its documented `mapver=S3K` / `dplcver=S3K` overrides.

## Validation

Build the ROM with `build.lua`, then run
`python build_tools/check_sprite_bounds.py` and
`python build_tools/check_sprite_assets.py`. The first checks all generated
bounds against the final assembled mappings, including their frame counts.
With a pinned skdisasm checkout, add `--skdisasm /path/to/skdisasm` to verify
all remapped Tails pixels against the original files. The check covers all
79 root binary tables, all 296 Tails body/tail mapping/DPLC frames, and the
art ranges and VRAM bank bounds for Sonic's five activated carry poses.

Native 68000 validation compared 8,007 Sonic cases and 1,152 Tails flight/swim
cases with independently assembled stock S3&K routines. Rendering checks
covered 99 tables, 1,121 frames and 4,484 flip combinations, plus 15 custom
ring cases and 1,024 rotating-layout cases. The real DMA queue passed full
queue/retry and 128 KiB boundary checks. Primary/companion air bubbles,
respawn cleanup, history/SST guards and aligned accesses were checked.

Genesis Plus GX tests under NTSC and PAL covered primary and companion Tails,
manual flight, exhaustion, carrying/jump release, separate dust banks,
swimming and independent air supplies. Forced large camera teleports briefly
slow the existing scrolling path; the settled water stage resumes normal
frame progress. Bonus-stage rendering remains covered separately.

The follow-up fixes passed 720 comparisons of the old and new star sprite
tables, camera movement/Y-wrap checks, sprite-limit/composite guards, 258
body/tail flash-phase cases, 4,225 stock angle comparisons, 1,152 enemy/boss
flight-contact cases, deferred carry uploads and carried-pose cycles in both
directions. Genesis Plus GX checks under NTSC and PAL cover
primary/companion startup in GHZ and SYZ, damage flashing, pickup/carry/release,
flight boss contacts and the shared star lifetime.

The renderer replacement passed 4,572 ordinary flip cases across 102 tables,
1,728 composite edge/flip/budget cases, 1,143 debug-bound cases and 32 static
fragment cases. Integration checks compare 72 HUD configurations, 24 results
screens, 36 ring-manager configurations and 720 visible star frames with the
previous renderer. All 21 scenery setups and 33 constructed fragments retain
their bounds. The 1,024 S1 layout cases still match, and 80 consecutive
render/layout/render cases verify persistent links through empty, partial and
full sprite tables. The normal Lua build handles newly imported reordered
binary frames, aliases and backward shared ASM frames; invalid imports leave
the previous constants and ROM intact, and removed imports leave no stale
constants.

Genesis Plus GX profiling counted emulated 68000 cycles inside the renderer,
including the old separate ring routine, over 180 frames per scene:

| NTSC scene | Previous cycles/call | New cycles/call | Reduction |
| --- | ---: | ---: | ---: |
| GHZ idle | 11,687 | 4,969 | 57.5% |
| GHZ running | 16,118 | 6,234 | 61.3% |
| GHZ invincibility | 15,669 | 8,771 | 44.0% |
| SYZ idle | 13,895 | 5,511 | 60.3% |
| SYZ running | 17,085 | 6,951 | 59.3% |
| SYZ invincibility | 17,859 | 9,262 | 48.1% |

PAL gives equivalent savings. Each of these samples completes one main update
per emulated frame with zero lag frames, as the baseline also did. These
figures measure renderer CPU cost, not an increase in the game's framerate.
NTSC/PAL gameplay checks retain startup, flashing, flight, exhaustion, carrying,
flight attacks, dust, swimming, independent air and star lifetime behavior.

## Monitor and capsule rider cleanup

Monitors use a per-character solidity pass for both players, with separate
standing/pushing bits and the existing ball-attack path. Breaking drops both
riders/pushers and retains the player who broke the monitor as its collector.
Standing transfers clear the departing player's bit on the old object.

On an object's status byte, rider bits 3/4 identify primary/companion players.
On either player's own status byte, the on-object flag is always bit 3. The
capsule previously cleared bit 4 on Tails himself, leaving bit 3 set: he fell,
then skipped terrain following when he landed. The detach path now clears
bit 3 for both players, and sets airborne only on the players.

Native tests cover both-side monitor collisions, simultaneous riders, collector
ownership, standing transfers, both invincibility collectors, repeated pickups,
independent expiry/facing, allocation retry and primary Tails. Genesis Plus GX
checks in NTSC/PAL cover real pickups, both full eight-star trails, monitor
walking/breaking, capsule detachment and subsequent GHZ slope following.
