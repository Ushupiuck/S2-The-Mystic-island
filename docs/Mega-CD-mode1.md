# Mega-CD Mode 1 test branch

`test/rebuilt-kehmusic` boots from the cartridge, uploads a real sub-CPU
program, verifies the upload and requires a fresh command reply before marking
the CD ready. `MegaCDMode1 = 1` in `main.asm` enables the bootstrap and the
`JC` cartridge header. The default build now requires the CD add-on: chunk
storage and the scratch maps that share it reside in PRG RAM. Missing/failed hardware shows
`MEGA CD REQUIRED` before any CD RAM access. Set `MegaCDMode1 = 0` for
a separately built ordinary-Mega-Drive version with its original RAM table.
The ROM must fit below `$400000`; assembly rejects an overlap with CD space.

The application initializes the Gate Array and owns the sub-CPU directly.
It executes no BIOS routines and needs no disc or MMD modules. The conventional
`$000000-$005FFF` BIOS area is now reserved in the PRG-RAM layout; the current
raw subprogram still occupies its initial 384 bytes. Reserving this area does
not load or initialize Sega's BIOS. Its 64 vectors are part of that raw
subprogram. Its stack starts at the top of 512 KB PRG RAM. PCM channels and interrupts start
disabled. Disc access, CDDA, backup-RAM services and graphics jobs are separate
future work. The Z80 sound driver retains its current storage.

The chunk table is the first user allocation at sub-CPU `$006000-$00DFFF`, visible to the main CPU
at `$426000-$42DFFF` in PRG-RAM bank 0. Its startup/title/menu scratch and
Sonic 1 bonus-stage overlays move with it. `_inc/Mega CD RAM.asm` owns this
layout. The former MD range `$FF0000-$FF7FFF` is free for reuse; all other
engine variables retain their addresses. New allocations in that lower half
must use long addressing.

Hardware detection and every startup/command wait are bounded.
Absent hardware gives `MCD_status = 0`,
a verified running service gives `1`, and failed initialization gives `$FF`.
The default CD build cannot fall back after reclaiming its MD chunk buffer;
initialization failure reaches the requirement screen instead.
The status and pending-DMA bytes reuse two unused former global-power-up
bytes. There is no increase in the existing work-RAM allocation.

## Memory and commands

| Resource | Main CPU in Mode 1 | Sub-CPU |
| --- | --- | --- |
| Cartridge | `$000000-$3FFFFF` | No direct cartridge mapping |
| CD BIOS window | `$400000` | No BIOS services used |
| 512 KB PRG RAM | Banked 128 KB window at `$420000-$43FFFF`; hold sub-CPU bus request | `$000000-$07FFFF` |
| Reserved BIOS area | `$420000-$425FFF` (bank 0) | `$000000-$005FFF` |
| Chunk table / scene overlays | `$426000-$42DFFF` (bank 0) | `$006000-$00DFFF` |
| 256 KB Word RAM, 2M mode | `$600000-$63FFFF` while owned; mirrors through `$7FFFFF` | `$080000-$0BFFFF` while owned |
| Communication registers | `$A12010-$A1202F` | `$FF8010-$FF802F` |

`MCD_Command` takes a command word in `d0` and argument word in `d1`. It
returns the result in `d0`, with carry set for absent/busy/failed service.
It clobbers `d2-d3`. Requests are serialized by a complemented token; each
side publishes its token/acknowledgement after the command/result. Bootstrap
publishes the entire first request **before** starting the sub-CPU, avoiding
a warm-reset race with an initial empty acknowledgement.

| Command | Result |
| --- | --- |
| `0` | No operation, result `0` |
| `MCD_CommandPing` (`1`) | Echo `d1` |
| `MCD_CommandReturnRAM` (`2`) | Return 2M Word RAM to main CPU, result `0` |
| Other values | `$FFFF` |

Call `MCD_AcquireWordRAM` before accessing or queuing Word RAM. It can clobber
`d0-d3`; carry reports failure. Keep ownership until `ProcessDMAQueue` consumes
the transfers. `MCD_ReleaseWordRAM` rejects a handoff while CD DMA is queued,
and masks interrupts around that check and handoff. These helpers currently
support 2M mode. Word-RAM acquisition is never performed in VBlank.

The main CPU owns PRG-RAM bank 0 while doing game work. `WaitForVint`
releases the sub-CPU; `V_Int` reacquires the bus and selects bank 0 before
any chunk readers or queued DMA execute. `MCD_Command` masks interrupts,
runs the request with the bus released, then reacquires bank 0 before returning.
This gives the service CPU the frame-wait intervals without allowing VBlank
to interrupt a request and steal its bus. Future background jobs must respect
this scheduling and leave the chunk allocation intact.

For PRG-RAM DMA, retain the bus request and selected bank through queue
consumption. Splitting a DMA does not switch the PRG-RAM window's bank.

## DMA

The direct macros and queue recognize Mode 1 Word-RAM sources. For transfers
of more than one word, the DMA source advances one word and the CPU supplies
the first destination word afterward. A single-word copy uses the CPU alone.
A transfer larger than the destination's address window overwrites the bad
first word itself, so it must not patch that word with the original source.
The direct macros also handle CRAM/VSRAM; the queue retains its VRAM API.

Actual source crossings at 128 KB are split. Assets need no blanket 128 KB
alignment. The final DMA command word still comes from MD RAM. Sources must
be even, lengths even and positive, and VDP autoincrement must be two.
The static queue length mask now retains all 16 counter bits: a 64 KB request
must not turn into a 128 KB transfer.

Ordinary queues retain their unrolled VBlank processor, with one 20-cycle
pending check. Runtime enqueueing adds 46 cycles for ordinary sources, 56 for
Word RAM. Only a queue containing Word RAM uses the repair processor, which
preserves the original register contract (only `a1/a5` trashed).

## Validation

`check_cd_chunks.py --core <core> --system-directory <fixture> --output <dir>`
checks every one of the 256 x 64 chunk/block addresses through both assembled
collision and rendering routines. It also runs 600 controller-driven level
frames and a rotating bonus stage while checking a canary across all freed
MD RAM. Add `--pal` for PAL. `check_level_pages.py` additionally compares each
act's CD-resident chunk bytes to its decompressed ROM data and checks that the
freed MD RAM survives all 64 launches.

`build_tools/check_mode1.py` creates a zero-filled identification fixture with
only the `SEGA` identifier. Genesis Plus GX uses it to enable its CD hardware
model; **no Sega BIOS code is provided or executed**. The ROM must perform
its own actual upload and handshake. The probes exercise both CPUs and the
VDP, including a negative control that reproduces the unfixed DMA delay.

```
python build_tools/check_mode1.py --core /path/to/genesis_plus_gx_libretro.so --rom s2built.bin --listing main.lst --output /path/to/mode1-check
```

Add `--pal` for PAL. The output includes the identification-fixture directory,
which can be passed as `--system-directory` to `check_level_pages.py` or
`check_fast_clear.py`. The former checks sound/menu behavior and all 64 act
launches. The latter places a temporary shoes monitor in `$0B`, then uses
controller input for the break, run, real signpost, full results and next act.
It verifies result-card VRAM, audible output and the scene's music-speed reset.
No permanent test monitor is added to the layouts.

The short-stage test found an existing tempo leak without CD hardware too:
new-song loading preserves speed shoes deliberately, but player-RAM clearing
on a scene change did not clear the audio flag. Scene setup now clears both
the live and saved-jingle tempo contexts, retaining normal in-level restores.

These are emulator checks. Physical Mega-CD hardware and commercial BIOS
revision compatibility have not been tested.

## Implementation references

- [Plutiedev: sub-CPU initialization in Mode 1](https://plutiedev.com/subcpu-in-mode1): hardware detection, reset and upload sequence.
- [Genesis Plus GX](https://github.com/ekeeke/Genesis-Plus-GX): `core/loadrom.c`, `core/mem68k.c`, `core/cd_hw/scd.c` and `core/vdp_ctrl.c` for Mode 1 mapping, ownership and the delayed Word-RAM DMA model.
- [Hardware DMA discussion](https://gendev.spritesmind.net/forum/viewtopic.php?start=15&t=1645): offset-source DMA with CPU repair of the first word.
