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
| CPZ / Ancient Workbench | `$2FF` | `$319-$31A` |
| HPZ / Crystal Valley | `$2E2-$2FF` | `$2E8-$2FF` |

The CPZ definition is retained even though current chunks do not use it.
HPZ's thirty definitions retain every tile number, palette, priority and flip
bit from the former patch table. Both source `.unc` files and their Kosinski
Plus versions contain the definitions. HPZ's unused gap before the animation
blocks is zero-filled; both mapping files fit the existing `$1800`-byte block
buffer. Block IDs, chunk words, layouts and collision data are unchanged.

The obsolete initialization call, loader, dispatch table, block definitions,
and unused EHZ definitions are removed, along with `begin_animpat`,
`make_block_tile` and the unused `make_block_tile_pair` helper. The removed
runtime code and tables occupied 394 bytes, including the call. This removes
an initialization fixup; the per-frame animation code remains identical.

SonLVL's four CPZ and four HPZ sections reference the same raw first-frame art
and VRAM destinations through `animtiles` entries. The animation blocks are
ordinary editable block data.

## Validation

`Level-animation-results.json` identifies the built ROM and its baseline.
All 32 CPZ/HPZ act/timezone header combinations decompress to the same block
words as the previous load-plus-patch sequence. All referenced chunk blocks
are in range. The eight raw animation art sources, dispatcher and interpreter
are unchanged.

Genesis Plus GX comparisons cover all four CPZ and HPZ acts, plus Emerald Hill
and Scrap Madness, in NTSC and PAL. The twenty cases compare 8,000 animation
frames and counter states against the baseline, with identical results and no
block-RAM writes during animation. The fixtures use solo Sonic; companion AI
is not run or changed. The normal build, shared sprite/VRAM checks and all
119 sprite bounds across 1291 frames pass.
