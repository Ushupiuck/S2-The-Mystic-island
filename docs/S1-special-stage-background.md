# S1 special-stage background

The background uses the normal `v_16x16` block table and the first `$A00`
bytes of `Chunk_Table`. Its 163 blocks contain four VDP tile words each;
its 20 chunks contain 8 by 8 block-index words. Five 4 by 2 chunk layouts
describe the opaque foreground, bird/fish checker arrangements, clouds and
bubbles. No `make_block_tile` mapping patches are used.

Birds and fish share one 64-tile animation bank. `S1SS_AnimateTiles` selects
frames from ordinary `zoneanimdecl` scripts and enters the existing
`Dynamic_Normal` interpreter with a private counter. The original palette
clock still controls the animation, including its long holds. This follows
`Animate_Tiles`'s division between custom zone logic and shared AniPLC scripts.

Foreground maps change only when entering/leaving a checker arrangement.
Background maps and the next family's first animation frame are prepared
under the fully opaque transition. Map construction happens in four block
rows per main-loop iteration; complete maps transfer in VBlank. Background
map and animated-art transfers never share a frame. Pause retains the
displayed frame, and the exit fade uses the existing frozen results VBlank.

## VRAM while playing the S1 stage

All ranges are inclusive. They apply before the results screen loads its PLCs.

| Range | Use |
| --- | --- |
| `$0000–$0A1F` | Clouds, 81 tiles |
| `$0A20–$0B3F` | Opaque transition, 9 tiles |
| `$0B40–$133F` | Shared bird/fish animation bank, 64 tiles |
| `$1340–$293F` | Fixed stage art, from walls through emeralds |
| `$2940–$BFFF` | Free, `$96C0` bytes |
| `$C000–$CFFF` | Live foreground map, 64 by 32 tiles |
| `$D000–$DFFF` | Free, `$1000` bytes |
| `$E000–$EFFF` | Live background map, 64 by 32 tiles |
| `$F000–$F3FF` | Normal Sonic art bank reserved; stage rolling art uses its first `$200` bytes |
| `$F400–$F5FF` | Free, `$200` bytes |
| `$F600–$F67F` | Stage ring art |
| `$F680–$F6FF` | Ring sparkles |
| `$F700–$F7FF` | Free, `$100` bytes |
| `$F800–$FA7F` | Sprite table |
| `$FA80–$FBFF` | Free, `$180` bytes |
| `$FC00–$FF7F` | Horizontal scroll table |
| `$FF80–$FFFF` | Free, `$80` bytes |

The old maps occupied `$9000` bytes after excluding their sprite-art gaps;
the two live maps use `$2000`, freeing `$7000`. Keeping only 9 static transition
tiles plus the 64-tile animation bank replaces 241 resident bird/fish tiles,
freeing another `$1500`. The total gain is **`$8500` bytes / 1064 tiles**.
The resulting free ranges total `$ABC0` bytes with the full Sonic bank reserved.
The uncompressed animation frames cost approximately 9 KiB more ROM in this
build; only one frame is resident in VRAM.

Stage PLCs, mapping bases, the rotating-wall upload and its palette-animation
table use the relocated `ArtTile_SS_*` constants. Emerald art no longer
shares the end of a background map. Special-stage results continue replacing
the stage ring at `$F600` with their palette-0 art; their animation leaves the
normal ring at `$D780` alone for the return to level mode.

## RAM and asset regeneration

The existing rotating-stage overlay begins at `Chunk_Table+$A00`. Its layout,
item-update list, transform grid and scrolling data remain together. Two
`$1000` plane buffers follow the animation state; `v_ssbg_end` is `$FF6A34`,
within the `$FF0000–$FF7FFF` chunk table. Blocks use the normal block table.
The assembler rejects an overlay extending past `Chunk_Table_End`.

Run `python build_tools/convert_s1_ss_background.py` from any directory to
regenerate the compressed blocks/chunks, five layouts, transition art and
six uncompressed animation frames. The original Enigma maps and compressed
cloud/bird/fish art remain conversion sources. The converter bakes each
animated tile's original flips into its art and preserves its palette;
the static maps retain their original tile-word attributes. Its map/art
indices must stay consistent with `ArtTile_SS_Background_*`.

The wider level migration away from `make_block_tile` and the general level
VRAM/HScroll rearrangement are separate future work.

Validation covered the assembled ROM, 4,500 native 68000 background frames,
all six rotating layouts/spawns, all 78 item mappings, the relocated wall
palette table, and the existing ring/HUD/results checks. Genesis Plus GX ran
complete background cycles under NTSC and PAL without added lag, plus movement,
pause, GOAL/emerald results and return-to-level checks across the six stages.
