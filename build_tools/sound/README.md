# KeH sound tools

`KEHmusic.exe` assembles songs, automatically chooses compressed or raw storage,
sorts by stored size, and packs music and DAC samples into
`$8000`-byte banks. `KEHsfx.exe` generates the sound-effect tables. Their source
lives here. `Mystic-Island-(Experimental)` uses headerless Kosinski+ music and a
Z80 Kosinski+ decoder; this replaces the previous Saxman music format.

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

The packers write aggregate bank lists, playlists/sample tables, ID constants
and name tables to `sound/*.gen.asm`. Per-bank includes stay in
`sound/generated/`. Run the tools from the project root; all ASM include paths
are relative to that root. Shared sound macros live in
`_definitions/_smps2asm_inc.asm`, alongside the other shared definitions.

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
jumps, calls, and loops contain relative little-endian pointers, so the same
song works in ROM or decompressed Z80 RAM. Its SFX channel headers omit the
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

Measure both assembled and Kosinski+ sizes. A smaller sequence can have a slightly
larger compressed encoding; crossing the `$A40` RAM limit can instead save much
more by enabling compression. Each bank starts on an `$8000` boundary; its
audio must stay within that window. Ordinary ROM data can use the remaining
tail before the next aligned bank, so saved song bytes can reduce ROM size
without reducing the number of music banks.

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
The packer may compress it if it is small enough and compression saves space.
For an already compressed, headerless Kosinski+ file, specify:

```ini
[Imported]
Title=Imported song
File=Imported.bin
BinaryFormat=KosinskiPlus
```

For ordinary ASM and raw binary inputs, compression is selected only when the
**decoded** song fits `$A40` bytes and the compressed stream is strictly smaller.
Oversized, incompressible and equal-size songs stay raw in ROM automatically.
Raw songs must fit one `$8000` bank. No per-song compression switch is needed.

Explicit `BinaryFormat=KosinskiPlus` inputs are validated before packing: they
must decode to between 1 and `$A40` bytes. Invalid backreferences, truncated
streams, trailing data and output overflow fail the build. Legacy Saxman inputs
must be decoded before importing. The playlist's existing compression flag comes
from the chosen encoding, not the filename extension. Generated compressed
output is round-trip checked against the raw song.

Generated compressed songs live in `sound/generated/<music ID>_cmp.bin`;
`OutputFile`, `Size`, `UncompressedSize`, `IsCompressed`, and `MD5` in the INI are
computed metadata. The superseded compressed copies beside the sources have
been removed.

### Experimental Z80 decoder

`KEHmusic` wraps raw song bytes in a temporary AS Z80 segment, then invokes the
bundled `p2bin` Kosinski+ encoder. Streams have MSB-first descriptors and a long
zero-count end marker, without a size header or module framing. Both ordinary
song loading and the post-1-up restoration path call `zKosinskiPlusDec`.

The Z80 routine occupies 105 bytes, replacing the 136-byte Saxman routine. It
ends at `$122A`, leaving 44 bytes before the unchanged `zMusicData` at `$1256`.
The `$A40` music allocation and following state/backup areas have not moved.
`HL` supplies the banked source; output starts at `zMusicData`. On return `HL`
and `DE` point past the input and output. `IX`/`IY` and `AF'` are preserved;
`AF` and `BC` are scratch. The DAC player keeps its running DPCM accumulator
in `AF'`, including across song loads. Long-token parsing saves the descriptor
on the stack so an old drum can finish without a corrupted accumulator. A signed
match displacement patches one immediate word in the decoder, so no new RAM
variable is needed. It runs inside the sound
interrupt and is not reentrant. Host validation enforces the output bound; the
compact runtime trusts those validated streams.

## Reusing bank padding

Edit `_definitions/Sound Bank Assets.asm`. `SoundBankAssets kind,bank` is expanded after
each bank's sound data and before `finishBank` checks its size. `kind` is
`Music`, `DAC`, or `SFX`; `bank` is one-based within that category. The macro uses
`GLOBALSYMBOLS` so ordinary asset labels remain accessible from the game.

Music bank 3 holds `Nem_SegaLogo` and `Nem_HUD`: 1,294 bytes of existing art.
Remove the original include when moving an asset here; keep word/DMA alignment
appropriate to that asset.

The hook file is handwritten and is never regenerated. Music packing remains
automatic. If a later song import consumes the chosen bank's free tail,
`finishBank` reports an overflow; move those assets to another bank's hook or
back to ordinary ROM space. Assets are not silently overwritten or discarded.

Each generated bank also has an independent include:

```asm
	include "sound/generated/music-bank-1.gen.asm"
	include "sound/generated/music-bank-2.gen.asm"
	include "sound/generated/music-bank-3.gen.asm"
```

`sound/musicbanks.gen.asm` and `sound/dacbanks.gen.asm` list the individual files
for a consecutive layout. The experimental ROM uses the individual music
includes in `md-main.asm`: title and early-zone art precede music bank 3, then
HPZ/HTZ/Mecha art fills its tail before the nearly full banks 1 and 2. Morphing
platform and vertical Ballhog art also use the gap after SFX and the Sega
sample. DAC banks still use their aggregate include; ordinary art follows the
last bank directly.

`finishBank` checks the audio and any `SoundBankAssets` hook before the following
ordinary data. That later data may extend beyond the window; it is not read by
the Z80. Each next bank aligns itself, while playlist and DAC entries use actual
ROM addresses. The runtime requires neither consecutive banks nor numerical
bank order. Keep per-bank includes synchronized with the generated aggregate
list if an import changes the bank count, and rebuild to measure the new
alignment gaps. The packer still selects storage and assigns songs to banks
automatically. Do not hand-edit its generated files.

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
Its `--jingles` cases include RAM-loaded GHZ, ROM-streamed Launch Base 2 and the
large RAM-loaded S3 Menu track, checking bank/voice and decompressed-data restore.

`check_sound_playback.py --switches` selects every song through the actual
level-select input path in three uninterrupted playlist passes, at 5/12/24-frame
intervals. It traces real Z80 DAC writes and checks each DPCM delta against the
previous accumulator, with explicit `$80` resets for new samples. It exercises
compressed/raw transitions and interrupted 1-ups, then checks that music settles.
This trace also requires the core's exported `Z80` registers and `z80_writemem`
bus callback. Reports include discontinuities and a local audio capture.

The tool fixtures check original instrument dumps, relative music pointers,
compact SFX headers, modern command conversions, dependency invalidation,
separate bank placement, unsupported imports and invalid/oversized input.
Automatic storage fixtures cover an exact `$A40` fit, `$A41` overflow,
incompressible data and a compressed/raw size tie. Every compressed project
song is compared with fresh assembly through an independent Python decoder.

For direct execution of the assembled Z80 routine:

```sh
python3 build_tools/check_z80_kosinski_plus.py \
  --core /path/to/genesis_plus_gx_libretro.so \
  --output test-results/z80-kosinski-plus/native
```

This requires a core exporting its native Z80 registers, memory maps and bus
callbacks. It relocates the unchanged decoder into guarded flat fixture memory,
then checks all descriptor alignments, short/long/extended counts, overlap,
8-KiB distances, current songs and seeded encoder fixtures. Output/input guards,
source/destination cursors, stack balance and `IX`/`IY`/`AF'` preservation are
checked; only the copy displacement may modify code. This proves instruction-level
format behavior, not Mega Drive bus or interrupt timing. The full-game playback
checks cover the real banked load and restoration paths.

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
