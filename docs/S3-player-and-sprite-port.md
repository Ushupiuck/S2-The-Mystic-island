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
Object `$35` prepares eight packed children in `$10–$3F`, stores four orbit
angles and animation indices in `$40–$47`, and uses flags at `$48`. It queues
through `DisplaySprite3` because child data overlaps the ordinary priority
field. Its header covers the padded viewport, with children clipped separately.
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
| `$C000`, `$E000` | Two 64 by 32 planes, `$1000` bytes each |
| `$D000` | Sonic body |
| `$D400`, `$D600` | Tails body and separate tail, using stock S3&K's shared allocation |
| `$D780`, `$D800`, `$D880` | Ring, lost ring and sparkles |
| `$D940` | HUD, shared E and digits |
| `$F000–$F37F` | HScroll |
| `$F600` | S1 bonus-stage/results ring, separate from the level ring |
| `$F800–$FA7F` | Sprite table |
| `$FA80–$FBFF` | Lives art |
| `$FC00–$FDFF`, `$FE00–$FFFF` | Sonic and Tails dust |

Tails body uploads can reuse the start of the tail area, as in the original;
every imported body frame fits below the ring, and every tail upload fits its
12-tile area. This is not an additional independent 32-tile body allocation.
Lower test-zone/NPC/effect allocations remain provisional. No GHZ terrain art
or block/chunk data was repacked during this port.

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
