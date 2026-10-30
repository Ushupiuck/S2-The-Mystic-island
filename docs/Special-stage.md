# Rotating S1 special stage

The Sonic 2 half-pipe stage, its private RAM/VRAM definitions, VBlank path and
exclusive assets have been removed. The rotating Sonic 1 stage remains the
available special stage; no replacement stage is implemented.

This mode retains its own item/update records and byte-count, five-byte-piece
S1 mappings. Ordinary [SST objects](Objects.md) use a different ABI. Its rings,
background, overlays and free VRAM must not be treated as ordinary-level allocations.

## Background pipeline

The background uses 163 ordinary `v_16x16` blocks (four tile words each) and
20 chunks in the first `$A00` bytes of `Chunk_Table`. Each chunk is an 8x8 array
of block-index words. Five 4x2 chunk layouts describe opaque foreground,
bird/fish checkers, clouds and bubbles. No runtime block-definition patch runs.

`S1SS_AnimateTiles` enters `Dynamic_Normal` with ordinary `zoneanimdecl` scripts
and a private counter. Birds/fish share one 64-tile bank; the original palette
clock determines frame timing and long holds. Foreground maps change only when
entering/leaving checker arrangements. New background maps and the next family's
first art frame are prepared under the opaque transition.

Entry drains the queued background modules and their final DMA while the
display is blank, before the white fade. `QuickPLC` only queues those modules;
enabling display immediately can expose incomplete black-filled clouds before
the opaque transition tiles arrive.

The main loop constructs four block rows per iteration; completed maps transfer
in VBlank. Background-map and animated-art uploads never share a frame. Pause
retains the displayed frame; exit fades use the frozen results VBlank.
In Mode 1, `v_ssbg_sines` holds the ten offset/phase word pairs used by
the sine scroll. It occupies 40 bytes of MD RAM, independently of the CD decoder
tables; the former 512-byte Nemesis scratch allocation is no longer needed.

## VRAM

Ranges are **end exclusive**, during stage play before results PLCs load.

| Bytes | Use |
| --- | --- |
| `$0000-$0A20` | Clouds, 81 tiles |
| `$0A20-$0B40` | Opaque transition, nine tiles |
| `$0B40-$1340` | Shared bird/fish animation, 64 tiles |
| `$1340-$2940` | Fixed stage art, walls through emeralds |
| `$2940-$29C0` | Rotating-stage rings |
| `$29C0-$2A40` | Ring sparkles |
| `$2A40-$C000` | Free in this mode |
| `$C000-$D000` | Live foreground map, 64x32 tiles |
| `$D000-$D400` | Sonic allocation; rolling art uses its first `$200` bytes |
| `$D400-$D600` | Tails rolling body, 16 tiles; unused with Sonic |
| `$D600-$D6C0` | Tails directional tails, six tiles; unused with Sonic |
| `$D6C0-$E000` | Free in this mode |
| `$E000-$F000` | Live background map, 64x32 tiles |
| `$F000-$F380` | Horizontal scroll table |
| `$F380-$F800` | Free in this mode |
| `$F800-$FA80` | Hardware sprite table |
| `$FA80-$10000` | Free in this mode; lives/dust inactive |

Stage PLCs, rotating-wall uploads and palette animation use `ArtTile_SS_*`.
Emerald art is separate from the live maps. Results use the shared HUD's
RINGS lettering; no results-only ring copy or ring-frame animation is loaded.

## RAM and regeneration

The rotating-stage overlay begins at `Chunk_Table+$A00`, keeping item updates,
transform grid, layout and scroll state together. Two `$1000` plane buffers
follow the animation state. `v_ssbg_end` is `Chunk_Table+$6A34`:

| Build | `Chunk_Table` | Overlay end, exclusive |
| --- | --- | --- |
| Cartridge (`MegaCDMode1 = 0`) | `$FF0000` | `$FF6A34` |
| Mode 1 (`MegaCDMode1 = 1`) | `$426000` | `$42CA34` |

Assembly guards the active `Chunk_Table_End`, which remains a 32 KiB working
range even though [CD physical storage](Mega-CD.md) is larger.

Run `python build_tools/convert_s1_ss_background.py` to regenerate compressed
blocks/chunks, layouts, transition art and six raw animation frames. Original
Enigma maps and compressed cloud/bird/fish art remain conversion sources. The
converter bakes original animated flips into pixels, preserves palette, and
retains static tile-word attributes. Keep these indices aligned with constants.

## Debug and movement

Solo Tails selects his own body mappings/animation and spawns the separate
`Obj05` tail, following S3&K's rotating slot-bonus player setup. Sonic selections
retain Sonic; no companion AI is spawned. Movement, collision radii and item
callbacks retain the S1 stage behavior. The tail follows velocity in all four
directional animation families and stays through the accelerating goal exit.
Placement and frame-cycle Debug hide it without deleting it. Stage frame-cycle
Debug stays within Sonic's `$3D-$41` or Tails's `$96-$98` compact rolling poses.

Stage Debug selects its own list without replacing the return level's zone.
C places a real stage ring (`$3A`) in the layout, without allocating an ordinary
SST. The cursor snaps to the nearest 24-pixel cell using its full fixed-point
position; exact horizontal/vertical ties prefer left/up. If that cell is
occupied, a clockwise spiral starting to its right finds the next free cell.
Repeated presses continue filling the spiral without moving the cursor.

Placement is restricted to the authored 64x64 cells inside the padded layout.
Occupied cells and row padding are preserved; a full grid or a cursor outside
that grid makes placement a no-op. The bounded search needs no persistent RAM
and preserves the object dispatch counter. The list currently offers only a
ring; other stage items need their own entries and matching previews.

Start+A follows the normal fade/results path. Results VBlank advances the fade
even with wall rotation stopped; clearing objects also clears Debug placement
state. Start+A on results retains the existing title shortcut. Normal movement's
quantization and bumper collision contracts are in
[Players and effects](Players-and-effects.md#input-locks-and-stage-exits).
Background cycles, pause, item callbacks and returns have dedicated checks in
[Testing](Testing.md); arbitrary Debug placement can still put the player in walls.

The rotating stage retains its original palette positions and private
original-index Sonic rolling, bumper, ring and sparkle sources. Results have
independent palette/emerald art; see
[ownership](Sprites-and-VRAM.md#palette-adaptation).
The first row's shared warm colors are hand-editable in
`palette/Special Stage.bin`: B = `$26C` (orange-brown), F = `$0AE` (gold),
A = `$8CE` (cream). Tails's original fur shades 2/3/4 map to B/F/A, preserving
three distinct shades; his cream shares A. This also warms Sonic's skin and
the first-row bumper/item details. The other 61 colors, including the rings,
walls and cycling background rows, retain their original values. No extra
palette line or runtime recoloring is needed.
