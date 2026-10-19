# Water surface and shared fixes

The water surface uses the existing atomic `Load_DynamicPLC` loader and one
16-tile bank at `$2A8-$2B7`. Both reserved surface objects share its cache.
Gameplay uses eight tiles; the existing paused display needs two eight-tile
phases. All six mappings retain their original piece sizes, positions and
pixels. This replaces the previous 24 resident tiles at `$400-$417` and
removes the HPZ-only water PLC requirement. No decompression runs in VBlank.

A changed gameplay phase queues 256 bytes once for both objects: 61 uploads
per 64-frame animation cycle. Entering pause queues 512 bytes; the frozen
surface needs no repeated transfers. A full DMA queue leaves the cache
unchanged and retries a complete frame. Live Start-button pause/unpause is
covered by the emulator checks.

All current terrain sets reserve this range. Static tile references were
relocated without changing any block's pixels, palette or flip flags, including
unplaced blocks. GHZ's terrain-based platform/ledge rectangles were packed from
170 to 148 tiles, retaining every original mapping piece and the wall cap at
`$C1`. This avoids mistaking sprite-only terrain for spare tiles. EHZ's platform
art is retained too. CPZ/HPZ/EHZ append displaced tiles below their next live
banks; GHZ/MTZ reuse genuinely unused slots.

SMZ shifts its complete shared sprite allocation by eight tiles. Its last
terrain tile now occupies static atlas padding at `$4AF`, with the same tile
available to SonLVL through a second compressed tiles file. Both acts retain
all sprite families together. Smoke/Kemusi end at `$4DD`, before the common
springs. `ArtTile_Splats` remains explicitly `$418`.

The capsule starts at `$4A7`, immediately after the boss's 17 exhaust tiles.
The surface bank is clear of the boss, weapons, exhaust, capsule and fixed
player/HUD/effect banks. This allocation addresses the surface; resident bubble
art still has a separate, older overlap with the boss weapon bank.

Additional fixes:

- Tail animation/position copying runs after all other objects, so transports
  and moving solids cannot leave the tail one carrier update behind its body.
- Running discs retain their quick rectangular reject, then test the actual
  circular capture radius. The former square corners no longer force speed.
- Horizontal springs use 15 for landing and 16 for standing, putting both
  contact paths on the visible top rather than one pixel below it.
- Hidden bonuses use the current blue/red slots and brightest palette-0 orange
  for the badge's old gold, preserving their mappings and VRAM footprint.
- Main receives its scene-entry music-tempo reset in a separate commit;
  the KEH branch already has the equivalent live/saved speed-state reset.
- Wrapped camera tracking sign-extends the 11-bit player/camera distance. The
  former unsigned mask interpreted a player above the camera as far below it.
- A trapdoor's first closed frame resolves shallow foot overlaps upward across
  its physical 24-pixel thickness. The ordinary landing tolerance remains
  unchanged, and already-closed sides/rising underside contacts remain solid.

## Validation

`check_shared_followup.py --core <Genesis-Plus-GX-core> --output <directory>`
checks all 4,439 blocks against commit `fb61a2e`, the terrain-based platform
rectangles, normal/paused water VRAM, queue-full retry, live pause/VBlank, boss
PLC coexistence, disc boundaries, spring support and both moving-carrier tail
cases. It also checks signed camera distances across the wrap seam, the native
SBZ2 duck/release/jump sequence and closing-frame trapdoor overlaps. `--probe`
records the old ROM's failures as negative controls. `--pal` selects PAL.

`check_sbz_discs.py` retains sustained standing/rolling rides and jump release
for both characters on all eight native discs. `check_fast_clear.py` breaks a
temporary shoes monitor in `$0B` and completes the level/results/next-act
transition through controller input. The sprite/boss asset checks and SonLVL
level loading cover the changed allocations and editor previews.
