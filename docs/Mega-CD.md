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
occupy its beginning. This does not load Sega's BIOS. Stack starts at `$80000`;
PCM and sub-CPU interrupts start disabled. Disc, CDDA, backup RAM and graphics
jobs remain future work; Z80 sound remains on its existing storage.

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
| 256 KiB Word RAM, 2M mode | `$600000-$63FFFF` while owned | `$080000-$0BFFFF` while owned |
| Communication registers | `$A12010-$A1202F` | `$FF8010-$FF802F` |

Chunks are the first allocation after the BIOS area. `Chunk_Table_End=$42E000`
is the active 32 KiB end used by existing clears and scene overlays;
`MCD_ChunkTable_SubEnd=$26000` ends the entire physical buffer. The expanded
allocation is not a contiguous main-CPU pointer, and jobs cannot use its tail.
[The planned mixed-size layout](Levels.md#planned-layout-format) is not implemented.

MD work RAM is packed against the top of its 64 KiB address space. The single
free allocation is `Free_RAM_Start` through `Free_RAM_End` (end exclusive):
`$FF0000-$FF7503`, **`$7504` bytes (29,956)**. This includes the former 580-byte
object-state reservation, 98 bytes of tail padding and the retired two-byte
CPU-object pointer slot. One byte remains for word alignment. The current live ranges are:

| Allocation | MD address, inclusive | Size |
| --- | --- | --- |
| Ring event queue/control | `$FF7504-$FF7707` | `$204` |
| [Decompressed player art](Sprites-and-VRAM.md#mode-1-ram-art) | `$FF7708-$FF82A7` | `$BA0` |
| Engine variables and work buffers | `$FF82A8-$FFFFFF` | `$7D58` |

`_definitions/s2.constants.asm` derives the engine's start from its own declared
size, then places CD work/art immediately below it. Allocation changes move the
boundary automatically; there is no address-preserving free hole. Assembly
checks keep short-addressed engine storage in `$FF8000-$FFFFFF`. CD event/art
accesses use long addressing. The Kosinski module and Nemesis buffers, scroll
spill area and `$140`-byte system stack remain live allocations; they are not
free RAM. The stack has explicit `System_Stack_Start`/`v_systemstack` bounds.
The rotating S1 stage uses its separate CD chunk-table overlay.

The main CPU owns PRG bank 0 during game work. `WaitForVint` releases the
sub-CPU; `V_Int` reacquires the bus/selects bank 0 before chunk readers or queued
DMA. Synchronous commands mask interrupts, run with the bus released and restore
bank 0 before returning. Bank-1 copies also mask interrupts and restore bank 0.
Retain the bus/bank through PRG DMA consumption; splitting DMA does not switch banks.

## CPU work and ring jobs

The sub-CPU actually executes `MCD_SubRingTick`, owning resident animation
timers and a compact active list. The main CPU records unique pickups, submits
events after scrolling, and overlaps the job with tile animation, palette,
PLC/module and oscillator work. `MCD_FinishRingJob` waits/copies active status
words before rendering. Collision, rewards, sound and rendering stay on MD.
No job is submitted without events or active animations; no idle 255-slot scan runs.

VBlank may pause the job for bank 0; finishing releases it again before waiting.
Pause freezes animation, and restart drains/resets job state before level clears.
Normal sparse work benefits from offload; a synthetic 255-simultaneous-animation
case can cost more because of copying/waits. The runner measures the whole
post-scroll section, including overhead, rather than claiming a game-wide speedup.

`ObjectsManager`/`Load_Sprites`, `ExecuteObjects`, player physics and companion
AI still run on MD. Future migrations must move working state **and the executor
that owns it** together; moving RAM alone is not a CPU offload.

## Commands and Word RAM

`MCD_Command`: command word in `d0`, argument in `d1`, result in `d0`; carry
signals absent/busy/failure, `d2-d3` are clobbered. A complemented token serializes
requests; request/result data precede token/ack publication. Bootstrap publishes
its complete first request before starting the sub-CPU, avoiding warm-reset races.

| Command | Result |
| --- | --- |
| `0` | No-op, zero |
| `MCD_CommandPing` (1) | Echo argument |
| `MCD_CommandReturnRAM` (2) | Return 2M Word RAM to MD, zero |
| `MCD_CommandRingTick` (3) | Active animation count |
| `MCD_CommandRingReset` (4) | Clear animation state, zero |
| Other | `$FFFF` |

`MCD_AcquireWordRAM` supports 2M mode, clobbers `d0-d3` and reports failure in
carry. Acquire before accessing/queuing Word RAM, outside VBlank; retain it until
`ProcessDMAQueue` consumes transfers. `MCD_ReleaseWordRAM` rejects a handoff with
CD DMA pending and masks interrupts across the check/handoff.

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
