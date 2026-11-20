# KeH sound tools

In the KeH streaming experiment, `KEHmusic.exe` assembles songs and chooses
headerless Kosinski+ or raw storage. It writes a flat music table with 32-bit
ROM pointers and decoded sizes. DAC samples still use `$8000`-byte banks.
`KEHsfx.exe` generates the banked sound-effect tables.

The normal `build.bat`/`build.lua` build runs both tools before assembling the
ROM. The packer uses the AS assembler and `p2bin` in the platform's `build_tools`
directory. The obsolete `win32` toolchain has been removed. Windows runs the
prebuilt EXEs directly; Linux/BSD require Mono. Python and a C# compiler are only needed when
rebuilding or checking the tools themselves.

## Rebuilding

From the project root:

```sh
python3 build_tools/sound/build.py
```

The script supports Mono's `mcs`, the Windows .NET Framework C# compiler, and
Roslyn `csc`. It targets .NET Framework 4 and uses the existing `IniFile.dll`.
The retired KensSharp Saxman/Common DLLs are no longer required.

For a separately installed Roslyn compiler/reference set:

```sh
python3 build_tools/sound/build.py --compiler /path/to/csc.exe \
  --mono /path/to/mono --framework /path/to/mono/4.0-api --check
```

`CSC` and `MONO` environment variables are also accepted. Roslyn builds use
deterministic output and portable PDBs when available. Older compilers use their
supported debug format instead. `--check` runs the bounded Kosinski+ decoder
fixtures and macro/packer checks after compilation.

## Generated files

The packers write playlists, sample tables, ID constants and name tables to
`sound/*.gen.asm`. `musicinfo.gen.asm` indexes `musicdata.gen.asm`.
DAC bank includes and generated compressed scores stay in `sound/generated/`.
Run the tools from the project root so ASM paths resolve. Shared sound macros
live in `_definitions/_smps2asm_inc.asm`.

Rebuild the distributed `KEHmusic.exe` and `KEHsfx.exe` after changing their
source; the build script invokes those binaries. Do not hand-edit generated
outputs or keep duplicate copies at the project root.

## Sound IDs and requests

Global requests use `d0.w`: bits 0-11 select `$000-$FFF`; bits 12-15 are
reserved flags. Queues, deferred requests, stage identities and saved return
identities preserve the full ID. Dispatch masks the reserved nibble. Priority,
DAC sample indices, FM voice indices and coordination bytecode remain bytes.
The 68000 holds the Z80 bus across two byte accesses per word: the Z80 RAM
window does not support ordinary 68000 word transfers. Use `WriteZ80Word` and
`ReadZ80Word`, with little-endian Z80 storage.
Register operands are data registers. Writes preserve every register, use two
temporary stack bytes and restore SP; byte postincrement of A7 advances by two.
Reads replace only the destination's low word and preserve its upper word.
Both macros clobber CCR. Their assembled sizes/base 68000 costs are 16 bytes/52
cycles for writes and 14 bytes/54 cycles for reads, before hardware wait states.
Z80 words remain packed, with no even-address padding requirement.

| IDs (hex) | Current role |
| --- | --- |
| `$000` | No request |
| `$001-$040` | 64 stage-music slots |
| `$041-$05A` | Shared themes, menus and jingles |
| `$05B` | Shadow Dancer stage 1-1 and 3-1 (sound test) |
| `$100-$155` | 86 named SFX |
| `$17A` | `CmdID_Distortion`: toggle Ristar sound-test ONCHI |
| `$17B` | `CmdID_StopSFX` |
| `$17C` | `CmdID_FadeOut` |
| `$17D` | `CmdID_SegaSound` |
| `$17E` | `CmdID_SpeedUp` |
| `$17F` | `CmdID_SlowDown` |
| `$180` | `CmdID_Stop`: stop music and SFX, reset ONCHI |

Sound test displays three hexadecimal digits and wraps at `$180`; A advances
by `$10`. Its 1,3,5,7 code compares complete words. Higher valid IDs can be
queued by game code, while unused holes are ignored. Assembly rejects catalogs
that overlap the reserved command range or exceed 12 bits. Commands are checked
independently of catalog order, including when SFX occupy a higher page.

Edit `sound/music/music.ini` and `sound/SFX/SFX.ini`; generated IDs follow their
entry order. Music uses `MusID_*`, SFX use `SndID_*`, and global commands use
`CmdID_*`. The misleading legacy `bgm_*`/`sfx_*` aliases have been removed.
SFX source files and private labels have descriptive names, not obsolete ID
numbers. SFX begin on the next `$100` boundary after music. A single-page SFX
catalog uses a proven byte-sized relative index internally; the generic word
path remains available when the catalog grows beyond one page.

The first 64 music entries are reserved even when unassigned. `Reserved=True`
labels silent placeholders, which share `Reserved Stage.asm`; repeated source
files share one ROM payload while retaining independent playlist flags.
Replace a placeholder in place to fill its stage slot. Shared themes begin
with `Title` at `$041`; `MusicList` selects songs independently for every act.
Final-release Hydrocity act 1 (`HCZ1`, `$020`) uses the universal bank. The
existing `LBZ1_S3` and `LBZ2_S3` are prototype arrangements and remain separate.
The old waterfall request had no SFX entry; its callers now explicitly queue
`SoundID_None` until an actual effect is supplied.

ONCHI applies Ristar's eleven-note offset sequence to new FM and melodic PSG
music notes. FM and PSG advance independently so introducing PSG offsets
preserves the FM sequence. The toggle retargets the existing PSG pitch jump.
PSG offsets stay inside the tone table. Noise-mode
PSG, DAC drum samples, sound effects and held-note timing follow their ordinary
paths. Toggling or stopping resets both sequences.

## Importing music

Add the song to `sound/music/music.ini`. For modern SMPS2ASM instrument data,
retain **both** arguments, for example:

```asm
Song_Header:
	smpsHeaderStartSong 3,1
```

The first argument identifies the source driver (S1, S2, or S3-family); the
second identifies the SMPS2ASM instrument format. An omitted second argument
means legacy format 0. Format 1 has single-bit AM arguments and literal total
level bytes. Five-argument `smpsVcUnusedBits` also preserves the reserved D1R
bits. Legacy syntax remains supported, alongside names such as `smpsFMvoice`,
`smpsMaxRelRate`, `smpsPSGAlterVolS2`, `smpsDcb`, and enharmonic note aliases.

The destination is **KeH**, not the original song's driver. Its music headers,
jumps, calls, and loops contain relative little-endian pointers. Those pointers
remain valid when a score page moves to another physical Z80 slot. Its SFX channel headers omit the
stock S2 `$80` byte and use absolute bank-window pointers. Do not replace the
macro file with stock S2 macros: those contracts must be preserved.

KeH already has `$FA` for S3-style note fill, including multiplication by the
channel tempo divider. The macro emits that command alone. S1 modulation waits
are adjusted for S2 semantics, and S3's two-argument `smpsFMAlterVol` uses its
second argument. KeH selects carrier operators from the algorithm; it does not
use the generic S3 driver's total-level marker interpretation.

`smpsHeaderVoiceUVB` (a zero voice-table offset) selects the 35 shared patches
in `sound/UniBank.asm`, for music or SFX. `smpsSetvoice` still takes a byte
index. Local nonzero voice offsets retain their original meaning. The shared
bank lives beside SFX in ROM; it consumes no dedicated Z80 RAM and can be read
alongside cached score pages. Cross-song instrument selection remains
unsupported; copy those patches locally or use a matching universal patch.

`smpsSetVol` emits `$FB,value` and implements S3 absolute loudness: zero is
silent and `$7F` is full volume. FM stores `(~value)&$7F`; PSG stores
`(~(value>>3))&$0F`. It shares the existing volume-store tails. An FM track that
uses `$FB` keeps carrier attenuation saturated at `$7F` until the track is
initialized again. Other tracks retain the legacy seven-bit sum. Existing
patches can intentionally wrap that sum, including the bass in Egg Utopia.
`$EC` retains its PSG attenuation-delta meaning. `smpsClearPush` emits `$ED` and clears the
push-effect latch. `smpsStopSpecial` emits `$EE` and uses the normal channel
stop/priority/restoration path. The streaming lookahead parser recognizes all
three commands. Other unsupported imports still fail explicitly.

### Converting a 68k rip

The utilities are in `Music & SFX from other games`. Each rip's `DefDrv.txt`
describes its pointer and tempo formats, and `DefCFlag.txt` describes its
coordination flags. Select the converter mode from those definitions.

| Utility | Input and output |
| --- | --- |
| `Tools/_misc/SMPSConv.exe` | Converts binary scores between driver formats, rebasing pointers and converting tempo and patch order. It reads optional `DACMap.ini` and `PSGMap.ini` from the working directory. Missing maps leave the indices unchanged. |
| `mdtools-v0.2.0.20211206/smps2asm.exe` | Disassembles a binary score into editable ASM. Match `--sonicver` to the binary's driver. The last argument is the label prefix. |
| `Tools/_misc/SMPSOpt.exe` | Optionally optimizes a score within its current format. Compare the expanded events if using it. |
| `Tools/dpcm2pcm/dpcm2pcm.exe` | Decodes a DPCM sample to unsigned 8-bit PCM. Pass one input path to write a sibling file with `.snd` appended. The default accumulator starts at `$80` and uses the standard 16-entry delta table. |

Shadow Dancer stores 68k header pointers as big-endian song offsets, with
relative branches in the track data. Its `$F9` returns from a call and
`$FB` changes transposition. `prepare_shadow_dancer.py` follows the channel
entry points, jumps, loops and calls, rewriting those two opcodes to Sonic 1's
`$E3` and `$E9` while preserving the offsets. The profile reports the offset of
any unhandled command. The converter's `Trs` profile reads a parameter after
`$F4`. Shadow Dancer's `$F4` has no parameter.

Run this example from the repository root in PowerShell. Use a scratch
directory so another import's mapping files cannot change the IDs.

```powershell
$archive = Join-Path $PWD 'Music & SFX from other games'
$rip = Join-Path $archive 'Rips\68k\Shadow Dancer\01 Stage 1-1, 3-1.mmw'
$conv = Join-Path $archive 'Tools\_misc\SMPSConv.exe'
$disasm = Join-Path $archive 'mdtools-v0.2.0.20211206\smps2asm.exe'
$work = Join-Path $PWD 'test-results\shadow-dancer\import'
New-Item -ItemType Directory -Force $work | Out-Null
py -3 build_tools/sound/prepare_shadow_dancer.py $rip (Join-Path $work 'shadow-s1.bin')
Push-Location $work
try {
	'8000', 'Y' | & $conv S1-S2 shadow-s1.bin shadow-s2.bin
	& $disasm --sonicver 2 shadow-s2.bin shadow.asm ShadowDancerStage
}
finally {
	Pop-Location
}
```

At bank address `$8000`, the disassembler uses its default offset of zero
because it masks off the bank-window bit. Check that the disassembly contains
six DAC/FM entries, two PSG entries, loop targets and seven local FM patches.
The converter reports six unreachable bytes for this rip. `S1-S2` converts
tempo divider/modifier `$02,$05` to `$02,$CD`. Keep the result's
`smpsHeaderStartSong 2,1` and the original modulation arguments.

| Channel data | KeH changes for this score |
| --- | --- |
| FM | The 68k driver loads patch TLs directly. Its volume commands set absolute carrier TLs. In this song, each write either equals the patch's carrier TL or is superseded by a patch load before the next note. Use zero FM channel attenuation and omit those volume commands to preserve the levels at note on. |
| PSG | Replace `fTone_07` with `fTone_ShadowDancer`. Envelope 7 comes from `VolEnvPtrs` at `byte_62AE0` in the Shadow Dancer driver disassembly in `SMPS_Research_Pack_v5_DriverDisasm.7z`. Translate its hold byte `$83` to KeH's `$80`. KeH's extended low-note table covers PSG2's low A. |
| DAC | Rename the disassembler's `dKick` and `dSnare` to `dShadowDancerKick` and `dShadowDancerSnare`. Reference the rip's original `DAC_81.bin` and `DAC_82.bin` in `sound/DAC/DAC.ini`. The standard DPCM table matches KeH's. From the rip's `DAC.ini`, use `round(BaseRate / (Rate + RateDiv))` in Hz, giving 11,792 and 7,372 for rates `$08` and `$16`. |

Append the editable score to `sound/music/music.ini` and do a normal build
so the packer assigns the IDs and updates the DAC banks and song data. The
stage import occupies Sound Test `$05B`. Each channel repeats every 2,400
duration ticks after its opening notes. A loop takes about 3,000 NTSC frames
at the converted tempo. The audio check below runs past three wraps. Check the
bass, stereo FM parts, both PSG parts and both drums across each wrap.

```sh
python3 build_tools/check_sound_playback.py --core /path/to/genesis_plus_gx_libretro.so \
  --system-directory /path/to/bios --songs ShadowDancerStage --frames 9200 \
  --output test-results/shadow-dancer/playback
```

### Optimizing music sequences

The handwritten song ASM remains the editable source. Repeated note phrases
use ordinary `smpsCall` / `smpsReturn`; larger repeated sections may call those
phrases. Counted loops use separate indices when nested. KeH shares ten bytes
between loop counters and its downward-growing return stack, so a counter
must stay below the active stack. Do not split a note from its duration or
remove a duration-only event: that event can retrigger the previous note.

An explicit note duration can be omitted only when it inherits the same
computed duration. Labels, calls and divider changes require checking entry
state. Local prototype voice banks retain instrument zero; unused instruments
are removed and selectors compacted, with their original S3 indices noted in
the source. Selected 25-byte YM patches must remain identical.

Measure both assembled and Kosinski+ sizes. A smaller sequence can have a
larger compressed encoding. The packer compares the stored lengths directly,
and music can cross a `$8000` ROM boundary.

### SFX priority and bumpers

`PlaySound` writes the normal priority queue. `PlaySound_Special` / `PlayMusic`
can write the immediate queue directly, bypassing priority arbitration; sound
test also uses that immediate path. Both the level and rotating-stage bumper
callers use `PlaySound`, so a `$70` bumper cannot replace the `$7F` Continue
jingle. SFX priority is released only when all six FM/PSG SFX slots have stopped.
Continue's FM4 lasts seven ticks longer than FM3/FM5; stopping another FM or PSG
channel must preserve its priority. Equal-priority effects may still retrigger.

### Binary inputs

A `.bin` is **raw by default**. It must already use KeH's relative music format.
The packer compresses it if the encoding saves space.
For an already compressed, headerless Kosinski+ file, specify:

```ini
[Imported]
Title=Imported song
File=Imported.bin
BinaryFormat=KosinskiPlus
```

Ordinary ASM and raw inputs can decode to at most `$2000` bytes, the size of
one MD staging slot. An encoding must be strictly smaller than the decoded
score for the packer to choose it automatically.

Explicit `BinaryFormat=KosinskiPlus` inputs must decode to between 1 and
`$2000` bytes. Invalid backreferences, truncated streams, trailing data and
output overflow fail the build. Decode legacy Saxman inputs before importing.
The playlist's compression flag follows the encoding. Generated Kosinski+
output is round-trip checked against the raw song.

Generated compressed songs live in `sound/generated/<music ID>_cmp.bin`;
`OutputFile`, `Size`, `UncompressedSize`, `IsCompressed`, and `MD5` in the INI are
computed metadata. The superseded compressed copies beside the sources have
been removed.

### Experimental score streaming

The main 68000 prepares a requested score in one of three `$2000` MD RAM
slots. The slots protect the live score, a saved 1-up return, and the next
score being prepared. Compressed scores use the existing CD Kosinski+ job
and output copy. Raw scores copy from ROM. The live slot stays immutable
while KeH reads it.

KeH keeps the FM, PSG, DAC and SFX updates on the Z80. Read-only PSG envelopes
live in `sound/PSG Envelopes.asm` in the SFX ROM bank. One bank switch before
the track updates serves envelopes, universal patches and SFX; the DAC path
selects its own bank afterward. This reclaims 454 Z80 bytes without adding a
bank switch to an ordinary tick. ROM envelope reads incur the cartridge's
normal wait states. Larger scores use logical pointers and a 30-slot cache of
64-byte pages. Four slots retain the
first instrument pages across section changes. Scores that fit the cache use
direct reads and invalidate only the slots they overwrite.

When a page misses, the Z80 writes its number to a byte in MD RAM through
its banked window. VBlank exits, frame waits and longer CD operations check
that byte before requesting the Z80 bus. A grant copies the requested page
and clears the mailbox before releasing the Z80. The MD never waits for the
rest of a normal sound tick. PAL can also refill during its existing VBlank
delay. CD decode word copies check for requests between 256-byte blocks.

A held note can leave a branch or page boundary ahead of a track. The Z80
sends a lookahead hint in that case. Only the idle frame wait uses it, and
only if the Z80 has finished its tick with time before the next VBlank or
water-palette split. A hint held near the split remains pending until the
split runs or a new tick replaces it. The MD follows a bounded number of
upcoming commands and can preload up to six missing pages, including an
instrument that crosses a page boundary.
Live modulation and cross-page instrument reads still use local Z80 state.

Fresh starts are asynchronous. KeH retires the outgoing music without muting
active SFX, requests its initial cache, and returns to the ordinary SFX/DAC
update instead of waiting inside the IRQ. The MD batches the header, opening
command spans and selected instruments after KeH has released the old cache.
Header initialization and the first notes use separate music ticks; the new
channels begin together on the next tick. SFX and their spindash counters keep
updating while the cache is pending. Preparing an MD staging slot never writes
over the live Z80 cache. Saved 1-up restoration retains its existing refill path.

Song requests and cache refills share the mailbox. Publishing a staged score
checks the short Z80 slot-change lock, so note playback can keep running
while the MD prepares a different score.

## Reusing bank padding

`_definitions/Sound Bank Assets.asm` supplies the optional `SoundBankAssets
kind,bank` hook after audio and before `finishBank`. Use `DAC` or `SFX` and
a one-based bank number. `finishBank` checks that the audio and hook fit
the aligned bank. Ordinary data may follow a bank directly. The music table
records actual ROM addresses and needs no bank padding. Mecha's two flash
palettes occupy the SFX tail alongside ordinary art, keeping the first bank
from moving when the streaming code grows.

## Cache and failures

`.sound-build/music-cache.ini` hashes the song, literal transitive source/binary
includes, shared macros, DAC IDs, assembler, converter and packer. A changed dependency triggers a rebuild; missing compressed output also
triggers one. The local cache is ignored by Git. `KEHmusic /clean` or
`KEHmusic --clean` rebuilds every song.

`KEHmusic --tools-dir PATH` or `KEH_TOOLS_DIR` overrides native tool selection.
Assembler/converter failures stop the packer and the ROM build with a nonzero
exit status. The failing song wrapper and assembler diagnostics remain in
`.sound-build/music.asm` and `.sound-build/music.log`; compression wrappers and
diagnostics use `.sound-build/music-kos.*`. Invalid or oversized
music/DAC data also fails the build instead of producing a partial playlist.

## Validation

The `Windows sound build` workflow checks the shipped Lua launcher and ROM build
from a directory containing spaces, then rebuilds the tools, runs their checks,
and builds the ROM again on a native Windows runner.

```sh
python3 build_tools/sound/build.py --check
python3 build_tools/check_sound_tools.py --mono /path/to/mono --bus-macros
python3 build_tools/check_sound_playback.py --core /path/to/genesis_plus_gx_libretro.so \
	--effects --jingles --priority --switches --startup
python3 build_tools/check_sound_playback.py --core /path/to/genesis_plus_gx_libretro.so \
  --pal --songs GHZ EHZ GGZ1 RRZ1 HTZ HPZ GRGZ2 LBZ2_S3 EndLevel ExtraLife
```

`check_sound_driver.py --core CORE --system-directory BIOS --mono MONO
--output test-results/sound-driver` exercises the compiled Z80 handlers and a
disposable expanded project in a path containing spaces. It checks all 256
absolute-volume arguments for FM and PSG, both carrier volume modes,
unchanged modulator levels, all 35 UVB patch resolutions, Ristar's offset
sequence and unaffected SFX notes. It also executes the SEGA PCM loop at its
original sample cadence and checks interrupts from either request byte. The
PSG fixture checks the period used for Egg Utopia's transposed noise note. The live fixture assigns
music `$100`, its 1-up `$101` and SFX `$200`, preserves reserved flag bits,
checks three-digit cursor rendering/wrapping, all seven global commands,
UVB music/SFX with the first and last patches, special-stop restoration and
invalid IDs. Its generated scores and ROM stay in the supplied output folder.

The optional playback check uses the existing libretro harness, NumPy, and
Pillow. Genesis Plus GX must expose the `work_ram`, `vram`, and `zram` symbols.
The shared runner also accepts unmodified ClownMDEmu libretro cores, using their
advertised memory maps and actual audio sample rate; enable the CD add-on,
overseas region and selected TV standard through core options. `--switches`
still requires Genesis Plus GX's exported Z80 CPU/bus callbacks. Reports and selected WAVs go under
`.sound-build`. It boots the real game, enters sound test, and plays through the
actual 68000/Z80/YM2612/PSG paths.

For source optimization, retain the preceding ROM, matching listing and
`music.ini`, then compare against the rebuilt checkout:

```sh
python3 build_tools/check_music_sequences.py \
  --reference-rom /path/to/before.bin --reference-listing /path/to/before.lst \
  --reference-ini /path/to/music.ini --output test-results/music-sequences/report.json
```

This independently reads each ROM's playlist and compressed data, expands relative
calls/jumps/counted loops, checks stack/counter overlap, and compares complete
channel streams past their loop boundaries. Headers, playlist behavior flags,
computed note durations, bare duration events, commands and selected instruments
must match. Finite tracks must terminate at the same event.

Add `--core CORE --system-directory BIOS` for real Mode 1 playback comparisons
of every changed song. The default budget covers the introduction and two
complete channel loops; `--pal` repeats in PAL and `--songs` restricts selection.
Use `--include-unchanged` for codec/driver changes whose decoded songs remain
identical. The listing selects the Kosinski+ decoder or the retained historical
Saxman reader for each ROM. Select looping tracks for long runtime comparisons;
use the jingle checks below for finite 1-up tracks that restore another song.
`--frames` is a shorter diagnostic override. Each frame's musical Z80 state,
including tempo, duration, pitch, modulation and the actual instrument patch,
must match after at most eight frames of load-start alignment. Relocated data,
voice/modulation pointers, return addresses and loop counters are excluded.
Audio callbacks must also produce non-silent output. These checks establish
musical equivalence; they do not claim identical sub-frame YM/DAC write timing
or reduced Z80 execution cost. Reports/state captures stay in the supplied
ignored output directory.

`check_sound_playback.py --startup` checks the actual 1,3,5,7 sound-test code,
4/5/6 to entry 7, and a staged return to 7. The confirmation ring must have the
same complete per-frame duration sequence as the ring played alone (36 SFX
updates). The startup must finish and the Z80 IRQ must not remain busy across
an output-frame boundary in the opening window. WAV headers use the core's
reported sample rate. These frame checks complement cycle-level diagnostics;
they do not establish a worst-case IRQ budget for every score and gameplay load.
The NTSC check also runs on stock ClownMDEmu 1.6.12. When that core exposes a
cache wait across a frame boundary, it also queues a cached 1-up via B during
that wait and requires restoration of initialized FM tracks in the new score.
Later music requests wait for header initialization before a jingle can back up
the current tracks.

ClownMDEmu 1.6.12 PAL Mode 1 boot cannot reach sound test because the pre-existing PAL wait polls the unimplemented CD
stopwatch register; use Genesis Plus GX for PAL validation.

`check_sound_playback.py --priority` checks the compiled bumper callers, normal
queue arbitration throughout Continue, its staggered final channel stops, an
unrelated PSG effect finishing, equal-priority retriggering, and priority release.
Its `--jingles` cases exercise Extra Life and Double Life with GHZ, Launch
Base 2 and S3 Menu, checking the restored score, voice and data.

`check_sound_playback.py --switches` selects every song through the actual
level-select input path in four uninterrupted playlist passes, at
2/5/12/24-frame intervals. It traces real Z80 DAC writes and checks each DPCM delta against the
previous accumulator, with explicit `$80` resets for new samples. It exercises
compressed/raw transitions and interrupted 1-ups, then checks that music settles.
This trace also requires the core's exported `Z80` registers and `z80_writemem`
bus callback. Reports include discontinuities and a local audio capture.

The tool fixtures check original instrument dumps, relative music pointers,
compact SFX headers, modern command conversions, dependency invalidation,
flat music placement, remaining SFX and DAC bank limits, unsupported imports
and invalid or oversized input. Automatic storage fixtures cover an exact
`$2000` fit, `$2001` overflow, incompressible data and a compressed/raw size tie. Every compressed project
song is compared with fresh assembly through an independent Python decoder.
`--bus-macros` also requires Unicorn. It executes the actual 68000 word-transfer
macros across all data registers and odd/even Z80 addresses, exhausts all 65536
word values on D0/even and D7/odd, and checks exact byte accesses, byte order,
source/upper-word preservation, other registers and stack guards. This is a CPU
and access-width check; it does not emulate Z80 bus arbitration or wait states.

The historical `check_z80_kosinski_plus.py` fixture can still execute an older
Z80 decoder given its source, ROM, listing and INI. Run it with
`--driver-source` pointing to that checkout's `s2.sounddriver.asm`.
For the streaming path, use the CD codec checks and live playback checks.

Scheduling validation also needs active gameplay. Queue dense scores such as
`GRGZ2`, `DDZ2`, `S3Menu`, `LBZ2_S3` and `Credits` in Scrap Madness acts 1/2,
then exercise water entry, the air countdown and resurfacing in GHZ4/HPZ.
Trace actual page requests and sound-tick completion, including song reloads
after death. A resident score should make no `Music_Service` calls once loaded.
Measure complete service calls through their return, including any interrupt
work, and account for the emulator's cycle counter wrapping between frames.

Cold starts deliberately separate preparation/initialization from their first
notes. The focused sound-test checks do not cover every heavy level reload or
water-music restore. Compare those transitions separately from established
playback; the regular music-state comparison allows startup alignment and
cannot prove first-note latency. The MD has no note-playing fallback.

These are playback and encoding checks, not a claim that every imported song
now duplicates its source game's sound. PSG envelope approximations inherited
from KeH remain, and the macro corrections intentionally change some output.

## Source history

- Packer/SFX source and the enhanced driver contract:
  [MainMemory/s2-sound-driver-plus, `57edda88`](https://github.com/MainMemory/s2-sound-driver-plus/tree/57edda88ae502cbb8c3bb425a00b52ea798e8b76/build_source/KEHmusic).
  The earlier test-branch commit verified that recompiling its packer source
  reproduced the original managed method code, generated ROM, and track audio.
- Final Hydrocity act 1 and S3 absolute-volume reference:
  [sonicretro/skdisasm, `73de97c6`](https://github.com/sonicretro/skdisasm/tree/73de97c6b55055bcb8089c1d55d006b02136f163).
  Final Launch Base 1 references its local shared Launch Base bank; none of its
  four used patches duplicates the current UVB. Local `$03` is closest to UVB
  `$06`, but differs in one detune value and two TL values, even ignoring TL
  marker bits. Hydrocity 1 explicitly selects the UVB. KeH retains its cache-aware voice resolver; S3&K's
  repeated-add instrument indexing is not a faster replacement.
- Ristar ONCHI reference: `SMPS_FMExtraKeyDelta` / `FMKeyDeltaArray` in
  [the annotated disassembly, `8165556e`](https://github.com/Ushupiuck/ristar/blob/8165556e3b9fe082b9065d293d6676e52369d273/Ristar%20(UE)%20%5B!%5D%2020240228.asm).
- Modern macro formats/names:
  [sonicretro/s2disasm, `4ef457c1`](https://github.com/sonicretro/s2disasm/blob/4ef457c18fc4902396c43ab06fabc119ac6ecb64/sound/_smps2asm_inc.asm).
- Kosinski+ format and 68000 reference:
  [`_inc/KosinskiPlus.asm`](../../_inc/KosinskiPlus.asm) and its internal include,
  originally by Flamewing/vladikcomper with Clownacy's improvements. The Z80
  implementation ports that format with sentinel-bit parsing and a
  self-modified displacement; it does not embed 68000 machine code.
- Host compression uses the project's bundled
  [Clownacy/p2bin](https://github.com/Clownacy/p2bin). The C# and Python readers
  independently validate its streams.

The runtime retains the fix for restoring uncompressed music after a 1-up.
Its multi-channel SFX priority lifetime is described above.
