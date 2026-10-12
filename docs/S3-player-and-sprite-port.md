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
`$4A`. The normal renderer conservatively expands legacy bounds from mapping
geometry. Collision radii retain their existing fields. Composite rendering
uses its separate path, including the shared invincibility-star stack header.

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

Build the ROM, then run `python build_tools/check_sprite_assets.py`.
With a pinned skdisasm checkout, add `--skdisasm /path/to/skdisasm` to verify
all remapped Tails pixels against the original files. The check covers all
79 root binary tables and all 296 Tails body/tail mapping/DPLC frames.

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
