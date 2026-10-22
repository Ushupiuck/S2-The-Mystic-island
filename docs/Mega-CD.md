# Mega-CD Mode 1

This guide applies to **`test/rebuilt-kehmusic`**. `Mystic-Island` remains the
ordinary cartridge branch. The CD branch's `MegaCDMode1 = 1` and `JC` header
enable cartridge boot, raw subprogram upload, verification and a fresh handshake.
Its chunk storage requires the add-on; absence/failure reaches `MEGA CD REQUIRED`
before CD RAM access. Detection and waits are bounded. `MCD_status` is zero for
absent, one for ready, `$FF` for failed initialization. ROM must fit below `$400000`.

The application initializes the Gate Array and owns the sub-CPU directly.
It calls no BIOS routines and needs no disc or MMD modules. The conventional
`$000000-$005FFF` BIOS area is reserved; the raw subprogram and its 64 vectors
occupy its beginning. This does not load Sega's BIOS. Stack top is `$7FFF0`, with a 16-byte bus-read guard below Word RAM;
PCM and sub-CPU interrupts start disabled. Disc, CDDA, backup RAM and graphics
jobs remain future work; Z80 sound remains on its existing storage.

## CPU source boundary

`md-main.asm` contains the Mega Drive vectors, entry point and game. It includes
`_inc/Mega CD.asm`, `_inc/Mega CD Ring Jobs.asm`,
`_inc/Mega CD Terrain Jobs.asm`, `_inc/Mega CD Decompression Jobs.asm` and
`_inc/Objects Manager.asm`: despite their CD-related
names, these are **main-CPU** loaders, bus/DMA helpers and mailbox callers.

`mcd-main.asm` contains the **sub-CPU** vectors, `MCD_SubEntry`, command service
and ring/terrain/object-loading/decompression executors. The MD entry point embeds it between `MCD_SubProgram` and
`MCD_SubProgramEnd`, using `phase 0` to assemble its CD execution addresses.
The existing bootstrap uploads those bytes to PRG RAM. This is one cartridge
build, not two separately linked ROMs. Shared hardware/RAM definitions remain
in `_definitions/`; subsystem includes inherit their entry point's CPU owner.
Normal-level terrain lookup, collision scans, ground attachment, airborne
collision resolution, tilemap construction, and Kosinski+/Nemesis/Enigma decoding
execute on CD. Camera motion,
object control, VDP output and sound still execute on MD.

## Memory and ownership

Ranges below are inclusive. `_definitions/Mega CD RAM.asm` declares physical
allocations with `phase`/`dephase` and typed `ds.*` fields. Hardware boundaries
and buffer capacities live in `_definitions/Mega CD Constants.asm`. Bank-window
aliases translate physical addresses; they do not allocate another copy.

| Resource | Main CPU | Sub-CPU / physical PRG RAM |
| --- | --- | --- |
| Cartridge | `$000000-$3FFFFF` | No direct cartridge mapping |
| BIOS window | `$400000` | No BIOS services used |
| 512 KiB PRG RAM | Banked 128 KiB window `$420000-$43FFFF`, while bus held | `$000000-$07FFFF` |
| Reserved BIOS area | `$420000-$425FFF`, bank 0 | `$000000-$005FFF` |
| Expanded chunk buffer | Crosses banks 0/1 | `$006000-$025FFF`, 128 KiB |
| Currently used chunks/scene overlays | `$426000-$42DFFF`, bank 0 | `$006000-$00DFFF`, 32 KiB |
| Ring job storage | `$426000-$426E0F`, bank 1 | `$026000-$026E0F` |
| Resident terrain and work state | No normal-frame PRG access | `$026E10-$02BE17` |
| Resident object placements and loader state | No normal-frame PRG access | `$02BE18-$02D3FB` |
| Decoder tables, resident PLC input and resumable state | No normal-frame PRG access | `$02D3FC-$035823` |
| 256 KiB Word RAM, 2M mode | `$600000-$63FFFF` while owned | `$080000-$0BFFFF` while owned |
| Communication registers | `$A12010-$A1202F` | `$FF8010-$FF802F` |

Chunks are the first allocation after the BIOS area. `Chunk_Table_End=$42E000`
is the active 32 KiB end used by existing clears and scene overlays;
`MCD_ChunkTable_SubEnd=$26000` ends the entire physical buffer. The expanded
allocation is not a contiguous main-CPU pointer, and jobs cannot use its tail.
[The planned mixed-size layout](Levels.md#planned-layout-format) is not implemented.

MD work RAM is packed against the top of its 64 KiB address space. The single
free allocation is `Free_RAM_Start` through `Free_RAM_End` (end exclusive):
`$FF0000-$FFB2AF`, **`$B2B0` bytes (45,744)**. Terrain, placement loading and
decompression work storage live with their CD executors. Current live ranges:

| Allocation | MD address, inclusive | Size |
| --- | --- | --- |
| Ring/terrain events and CD job controls | `$FFB2B0-$FFB4CB` | `$21C` |
| [Decompressed player art](Sprites-and-VRAM.md#mode-1-ram-art) | `$FFB4CC-$FFC06B` | `$BA0` |
| Engine variables and work buffers | `$FFC06C-$FFFFFF` | `$3F94` |

`_definitions/s2.constants.asm` derives the engine's start from its own declared
size, then places CD work/art immediately below it. Allocation changes move the
boundary automatically; there is no address-preserving free hole. Assembly
checks keep short-addressed engine storage in `$FF8000-$FFFFFF`. CD event/art
accesses use long addressing. The old MD Kosinski module buffer, Nemesis code
table and decoder bookmarks are gone; queued requests and DMA controls remain.
The scroll spill area and `$140`-byte system stack are live allocations. The
stack has explicit `System_Stack_Start`/`v_systemstack` bounds.
The rotating S1 stage uses its separate CD chunk-table overlay.

Active levels leave PRG RAM with CD. Terrain calls transfer compact mailbox
arguments, never stop CD for a chunk read. Ring updates briefly acquire bank 1,
copy sparse changes, restore bank 0 and release CD again. Loading and non-level
scenes explicitly acquire bank 0 for their existing scratch and PRG DMA paths.
Retain that bus/bank through PRG DMA consumption.

Word RAM has these disjoint regions; add `$80000-$600000` to translate an MD
address to the CD view:

| MD range, inclusive | Use |
| --- | --- |
| `$600000-$60003F` | Frame snapshot, free object slots, PLC tile/time budgets |
| `$600040-$60DFFF` | Terrain VDP records |
| `$60E000-$60E43B` | Object reply header and up to 90 spawn records |
| `$610000-$614EFF` | Level collision-bank staging / non-level overlays |
| `$618000-$61FFFF` | Compressed cartridge input cache |
| `$620000-$62FFFF` | General decoded output / Kosinski module DMA source |
| `$630000-$63FFFF` | PLC decoded output, retained until DMA consumption |

`v_16x16` and `Level_Layout` name staging aliases; gameplay uses resident CD
data. CD decodes blocks, layout and chunks directly into their PRG allocations.
`MCD_LoadTerrain` installs collision indices and the single shared
height/width/angle bank once on level entry.
The rotating S1 stage retains its separate MD renderer and staging/PRG overlays.

After scrolling, CD constructs changed tile strips while MD renders sprites
and finishes other work. Foreground `MCD_FinishTerrainJob` waits before requesting
a full VBlank. The VDP handler only drains stable, MD-owned records; it never
waits for the terrain executor. Each record is a VDP command long, a count word
of data longs, then those data. Word RAM remains MD-owned until consumption.
Restarts and scene changes drain jobs before clearing their controls.

Paired sensors and the complete Sonic/Tails airborne collision pass execute
on CD. MD sends only the required coordinates, radii, velocity and flags, then
applies the result and any character-specific landing callback. Ground attachment
also executes on CD; object behavior and motion remain MD-owned. Small single
probes pay mailbox overhead: clock speed alone does not guarantee a gain.
The terrain runner measures complete calls, including waits.

## CPU work and ring jobs

The sub-CPU actually executes `MCD_SubRingTick`, owning resident animation
timers and a compact active list. The main CPU records unique pickups, submits
events after scrolling, and overlaps the job with tile animation, palette,
PLC/module and oscillator work. `MCD_FinishRingJob` waits/copies active status
words before rendering. Collision, rewards, sound and rendering stay on MD.
No job is submitted without events or active animations; no idle 255-slot scan runs.

Non-level VBlank may pause the job for bank 0; finishing releases it again before waiting.
Pause freezes animation, and restart drains/resets job state before level clears.
Normal sparse work benefits from offload; a synthetic 255-simultaneous-animation
case can cost more because of copying/waits. The runner measures the whole
post-scroll section, including overhead, rather than claiming a game-wide speedup.

`ObjectsManager`/`Load_Sprites` is now an MD transport/application boundary.
The actual placement manager and loader execute in `_inc/Mega CD Objects.asm`,
with resident placements, front/back cursors, loading bands and respawn state.
MD copies each act's placement list once. On a band change or a full-pool retry,
it supplies twelve free-slot bytes through the existing terrain frame job.
CD selects placements and emits twelve-byte records: SST handle, X, Y, render
flags/subtype, object ID, and placement handle. MD resolves its own routine
pointers and writes the SSTs after the reply. Idle frames do not scan/copy SSTs.

`respawn_addr` now holds placement index + 1; zero still denotes a dynamic or
Debug object. Rare state changes and original-X lifetime queries use the
mailbox. There is no MD respawn-table mirror. The MD coarse-camera values are
request caches/lifetime inputs, not duplicate CD cursors.

`ExecuteObjects`, ordinary object state machines, player motion and companion
AI still execute on MD. This port moves the placement manager/loader, not all
object behavior. Future migrations must move working state and its executor
together.

## Commands and Word RAM

`MCD_Command`: command word in `d0`, argument in `d1`, result in `d0`; carry
signals absent/busy/failure, `d2-d3` are clobbered. A complemented token serializes
requests; request/result data precede token/ack publication. The low command
byte selects the handler; terrain operations use its high byte for compact
inputs. The sub-CPU flags byte carries ready/error and airborne-result flags.
Result word `$22` is available to terrain, rather than a permanent ready marker. Bootstrap publishes
its complete first request before starting the sub-CPU, avoiding warm-reset races.

| Command | Result |
| --- | --- |
| `0` | No-op, zero |
| `MCD_CommandPing` (1) | Echo argument |
| `MCD_CommandReturnRAM` (2) | Return 2M Word RAM to MD, zero |
| `MCD_CommandRingTick` (3) | Active animation count |
| `MCD_CommandRingReset` (4) | Clear animation state, zero |
| `MCD_CommandTerrainLoad` (5) | Install resident level data, return Word RAM |
| `MCD_CommandTerrainDraw` (6) | Construct changed strips / initial planes |
| `MCD_CommandTerrainFloor/Wall` (7/8) | Complete explicit-coordinate sensor scan |
| `MCD_CommandLayoutRead/Write` (9/10) | Level-script byte access |
| `MCD_CommandTerrainAir` (11) | Whole airborne collision pass |
| `MCD_CommandObjectsLoad` (12) | Install an act placement list, return Word RAM |
| `MCD_CommandObjectState` (13) | Persistent state / original placement X |
| `MCD_CommandKosPlus` (14) | Decode Kosinski+ / one moduled archive member |
| `MCD_CommandNemesis` (15) | Decode Nemesis to RAM |
| `MCD_CommandEnigma` (16) | Decode Enigma with a base-tile argument |
| `MCD_CommandPLCInit` (17) | Install resident compressed PLC input and initialize its decoder |
| `MCD_CommandArtFrame` (18) | Decode a bounded PLC batch without a terrain scene |
| `$20-$2D` | Ground attachment and complete object/sensor operations |
| Other | `$FFFF` |

`MCD_AcquireWordRAM` supports 2M mode, clobbers `d0-d3` and reports failure in
carry. Acquire before accessing/queuing Word RAM, outside VBlank; retain it until
`ProcessDMAQueue` consumes transfers. `MCD_ReleaseWordRAM` rejects a handoff with
CD DMA pending and masks interrupts across the check/handoff.

## Asset decompression and PLCs

`_inc/Mega CD Decompression.asm` owns the three CD codecs and resumable PLC
state. MD public wrappers preserve their original callers' register contracts.
CD cannot read cartridge ROM: `build_tools/lua/compressed_assets.lua` derives
exact compressed spans from the include graph, generating
`_definitions/Compressed Assets.asm`. Adding a linked compressed `binclude`
requires no second hand-maintained asset list. A span must fit the 32 KiB input
cache. Interior Kosinski module pointers reuse that cache until another asset
replaces it. The compressed Z80 driver has its own explicit start/end span.

Terrain decodes straight into resident CD PRG RAM. General MD destinations use
the Word-RAM output bank followed by a result copy; Z80 destinations require
byte writes. This moves startup driver decompression, not sound sequencing:
the current sound driver, music and Saxman handling remain on Z80/MD.

PLCs keep a separate compressed archive and code table in PRG RAM, so general
decodes cannot damage a suspended PLC. Frame commands combine terrain, placement
loading and PLC work in one Word-RAM handoff. Non-level scenes use command 18.
The loader yields at a complete tile using the free-running CD stopwatch; it
does not reset that timer. Current limits are about 2 ms/48 tiles for gameplay
and about 8 ms/96 tiles for title/loading/fade/results handlers. Both limits
apply; one final tile can exceed the time allowance. Counts vary with asset
complexity, instead of inheriting the MD loader's fixed 3/9-tile limit.

`WaitForVint` finishes the CD job and publishes prepared art into the ordinary
DMA queue before requesting VBlank. A prepared or queued batch prevents the
next PLC write; a full queue retries without advancing the cue. VBlank only
consumes DMA and updates queue bookkeeping, with no decoder or CD wait.
Kosinski modules use a separate stable output bank and the same publication
boundary. Direct scene loaders use a DMA-only VBlank before reusing output.

Active-level waits permit palette interrupts. Before handing Word RAM to CD,
the transport completes any previous deferred HBlank terrain writes; those
writes may not read the stream while CD owns it. Non-level callers retain their
explicit bank-0 PRG-bus contract after a decode. Scene teardown drains jobs and
DMA before clearing their controls.

## DMA

Direct macros and the queue recognize Word-RAM sources. For more than one word,
advance the DMA source one word and repair the first destination word by CPU.
Single-word transfers are CPU-only. Oversize transfers that overwrite the first
destination word themselves must not restore that word from the original source.
Direct macros handle CRAM/VSRAM too; the queue retains its VRAM interface.

Split actual 128 KiB source crossings; blanket asset alignment is unnecessary.
Sources/lengths must be even, lengths positive, VDP increment two, and the final
DMA command word must come from MD RAM. Queue lengths retain all 16 counter bits.
Ordinary queues keep the unrolled processor; only queues containing Word RAM use
the repair processor, preserving the existing `a1/a5` clobber contract.

## Validation and references

[Testing](Testing.md#mega-cd-checks) owns executable commands. Mode 1 tests create
a zero-filled `SEGA` identification fixture that enables Genesis Plus GX's CD
model; it contains/executes no Sega BIOS code. The cartridge must still perform
its own real upload/handshake. Checks cover both emulated CPUs, DMA negative
controls, chunk collision/streaming, freed-MD-RAM canaries and ring-job lifetimes,
pause/reset/bank ownership. Physical hardware and commercial BIOS revision
compatibility have not been tested.

Implementation references retained from the port:

- [Plutiedev's Mode 1 initialization](https://plutiedev.com/subcpu-in-mode1).
- [Genesis Plus GX source](https://github.com/ekeeke/Genesis-Plus-GX):
  `core/loadrom.c`, `core/mem68k.c`, `core/cd_hw/scd.c`, `core/vdp_ctrl.c`.
- [Word-RAM DMA discussion](https://gendev.spritesmind.net/forum/viewtopic.php?start=15&t=1645).
- [Sonic CD's PLC routines](https://github.com/AlexField442/scddisasm/blob/main/src/Level/Functions%20%28General%29.asm):
  `ProcessPLCs`, `DecompPLCFast` (18 tiles), and `DecompPLCSlow` (3, or 18 with
  scrolling locked). Those decode directly to the VDP on MD; our CD/RAM/DMA
  pipeline uses independent CPU-time and tile limits.
- [Sega's Mega-CD hardware manual](https://segaretro.org/images/5/51/Mega-CD_Hardware_Manual.pdf):
  the 12-bit stopwatch advances every 30.72 microseconds and wraps at 4096.
