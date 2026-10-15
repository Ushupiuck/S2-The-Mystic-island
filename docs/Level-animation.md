# Level tile animation

`LoadZone` loads complete 16x16 block definitions from the ordinary level
mapping files. Blocks refer directly to the VRAM slots updated by
`Animate_Tiles`; no second block-table patch runs during level initialization.

The animation pixels remain uncompressed in ROM. `Dynamic_Normal` reads the
existing frame/duration scripts and queues DMA from those raw pixels. Neither
the dispatcher nor the interpreter changed, and no decompression was added
to the animation or VBlank path. Handwritten zone routines remain supported
by the same dispatcher, alongside the shared script interpreter, as in S3&K.

## Block data

| Level assets | Animation block IDs | Animation tile slots |
| --- | --- | --- |
| CPZ / Ancient Workbench | `$1B7` | `$319-$31A` |
| HPZ / Crystal Valley | `$2BC-$2D9` | `$2E8-$2FF` |

CPZ uses its existing block `$1B7` for the animated background. The unused
duplicate at `$2FF` and all trailing blocks above the highest referenced ID,
`$277`, are removed. Its ordinary block file now contains 632 blocks instead
of 768; its chunks are unchanged.

HPZ's thirty definitions retain every tile number, palette, priority and flip
bit from the former patch table. They follow the 700 original blocks directly,
closing the unused 38-block gap. The block file now contains 730 blocks instead
of 768. Its 136 affected chunk references move from `$2E2-$2FF` to
`$2BC-$2D9`, retaining their upper flag bits. Both collision paths have the
same values at the old and new IDs in every act and timezone, so the collision
files need no edits. Layouts and animated VRAM tile destinations are unchanged.

Both source `.unc` files and their Kosinski Plus versions contain the ordinary
block definitions. The streams write 1,088 fewer bytes for CPZ and 304 fewer
bytes for HPZ during loading; the fixed `$1800`-byte RAM allocation remains.
The three edited compressed assets save 30 bytes in total per set, or 120
bytes in the built ROM across the four timezone copies.

The obsolete initialization call, loader, dispatch table, block definitions,
and unused EHZ definitions are removed, along with `begin_animpat`,
`make_block_tile` and the unused `make_block_tile_pair` helper. The removed
runtime code and tables occupied 394 bytes, including the call. This removes
an initialization fixup; the per-frame animation code remains identical.

SonLVL's four CPZ and four HPZ sections reference the same raw first-frame art
and VRAM destinations through `animtiles` entries. The animation blocks are
ordinary editable block data.

## Validation

`Level-animation-results.json` identifies the built ROM and the baseline before
block compaction. All 32 CPZ/HPZ act/timezone header combinations resolve to
identical tile words, chunk flags, and primary/secondary collision values.
All referenced block IDs are in range. The eight raw animation art sources,
dispatcher and interpreter are unchanged.

Genesis Plus GX comparisons cover all four CPZ and HPZ acts in NTSC and PAL.
The sixteen cases compare 6,400 animation frames and counter states against
the baseline, along with resolved chunk words and sample screenshots, with
identical results and no block-RAM writes during animation. The fixtures use
solo Sonic; companion AI is not run or changed. The normal build and all
119 sprite bounds across 1291 frames pass.
