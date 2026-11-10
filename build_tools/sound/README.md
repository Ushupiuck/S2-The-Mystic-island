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

This is not an implementation of every S3 coordination command. Cross-song
instrument selection and universal voice banks fail explicitly: copy the
needed instruments into a song-local voice bank. Unsupported commands still
require conversion to KeH-supported behavior or a separate driver change.

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

KeH keeps the FM, PSG, DAC and SFX updates on the Z80. Larger scores use
logical pointers and a 30-slot cache of 64-byte pages. Four slots retain the
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
python3 build_tools/check_sound_playback.py --core /path/to/genesis_plus_gx_libretro.so \
	--effects --jingles --priority --switches
python3 build_tools/check_sound_playback.py --core /path/to/genesis_plus_gx_libretro.so \
  --pal --songs GHZ EHZ GGZ1 RRZ1 HTZ HPZ GRGZ2 LBZ2_S3 EndLevel ExtraLife
```

The optional playback check uses the existing libretro harness, NumPy, and
Pillow. Its core must expose the `work_ram`, `vram`, and `zram` symbols, as the
tested Genesis Plus GX build does. Reports and selected WAVs go under
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

The historical `check_z80_kosinski_plus.py` fixture can still execute an older
Z80 decoder given its source, ROM, listing and INI. Run it with
`--driver-source` pointing to that checkout's `s2.sounddriver.asm`.
For the streaming path, use the CD codec checks and live playback checks.

Scheduling validation also needs active gameplay. Queue dense scores such as
`GRGZ2`, `DDZ2`, `Test6`, `LBZ2_S3` and `Credits` in Scrap Madness acts 1/2,
then exercise water entry, the air countdown and resurfacing in GHZ4/HPZ.
Trace actual page requests and sound-tick completion, including song reloads
after death. A resident score should make no `Music_Service` calls once loaded.
Measure complete service calls through their return, including any interrupt
work, and account for the emulator's cycle counter wrapping between frames.

Cold song starts during a heavy level reload or a water-music restore can
still take an extra tick in this experiment, as in its preceding driver.
Compare those transitions separately from established playback; the regular
sound-test state comparison allows startup alignment and cannot prove their
first-tick latency. The MD has no note-playing fallback.

These are playback and encoding checks, not a claim that every imported song
now duplicates its source game's sound. PSG envelope approximations inherited
from KeH remain, and the macro corrections intentionally change some output.

## Source history

- Packer/SFX source and the enhanced driver contract:
  [MainMemory/s2-sound-driver-plus, `57edda88`](https://github.com/MainMemory/s2-sound-driver-plus/tree/57edda88ae502cbb8c3bb425a00b52ea798e8b76/build_source/KEHmusic).
  The earlier test-branch commit verified that recompiling its packer source
  reproduced the original managed method code, generated ROM, and track audio.
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
