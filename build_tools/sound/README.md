# KeH sound tools

`KEHmusic.exe` still assembles songs, tries Saxman compression when the song fits
the Z80 buffer, sorts by stored size, and packs music and DAC samples into
`$8000`-byte banks. `KEHsfx.exe` generates the sound-effect tables. Their source
now lives here; rebuilding the tools no longer depends on an unavailable project.

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
Roslyn `csc`. It targets .NET Framework 4. It also rebuilds the patched Saxman
DLL against the existing `SonicRetro.KensSharp.Common.dll`.

For a separately installed Roslyn compiler/reference set:

```sh
python3 build_tools/sound/build.py --compiler /path/to/csc.exe \
  --mono /path/to/mono --framework /path/to/mono/4.0-api --check
```

`CSC` and `MONO` environment variables are also accepted. Roslyn builds use
deterministic output and portable PDBs when available. Older compilers use their
supported debug format instead. `--check` runs the compressor and macro/packer
checks after compilation.

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

### Binary inputs

A `.bin` is **raw by default**. It must already use KeH's relative music format.
The packer may compress it if it is small enough and compression saves space.
For an already compressed, size-prefixed Saxman file, specify:

```ini
[Imported]
Title=Imported song
File=Imported.bin
BinaryFormat=Saxman
```

The actual decompressed size must fit `$A40` bytes, the buffer reserved in
`s2.sounddriver.asm`. Larger songs remain uncompressed in ROM and must fit one
`$8000` bank. The playlist's compression flag comes from the chosen encoding,
not from the filename extension. Compressed output is round-trip checked.

Generated compressed songs live in `sound/generated/<music ID>_cmp.bin`;
`OutputFile`, `Size`, `UncompressedSize`, `IsCompressed`, and `MD5` in the INI are
computed metadata. The superseded compressed copies beside the sources have
been removed.

## Reusing bank padding

Edit `_definitions/Sound Bank Assets.asm`. `SoundBankAssets kind,bank` is expanded after
each bank's sound data and before `finishBank` checks its size. `kind` is
`Music`, `DAC`, or `SFX`; `bank` is one-based within that category. The macro uses
`GLOBALSYMBOLS` so ordinary asset labels remain accessible from the game.

Music bank 3 currently holds `Nem_SegaLogo` and `Nem_HUD`: 1,294 bytes of existing
art, with its pixels unchanged. The resulting ROM is 1,280 bytes smaller after
the project's other alignment requirements. Remove the original include when
moving an asset here; keep word/DMA alignment appropriate to that asset.

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

`sound/musicbanks.gen.asm` and `sound/dacbanks.gen.asm` include the individual files for the
default layout. For a custom layout, replace the corresponding aggregate include
in `main.asm` with individual includes and place other data between them. Every
bank aligns itself; playlist and DAC table entries use the labels' actual ROM
addresses. The runtime does not require consecutive music/DAC banks. Do not edit
the generated files themselves.

## Cache and failures

`.sound-build/music-cache.ini` hashes the song, literal transitive source/binary
includes, shared macros, DAC IDs, assembler, converter, packer, and compression
DLLs. A changed dependency triggers a rebuild; missing compressed output also
triggers one. The local cache is ignored by Git. `KEHmusic /clean` or
`KEHmusic --clean` rebuilds every song.

`KEHmusic --tools-dir PATH` or `KEH_TOOLS_DIR` overrides native tool selection.
Assembler/converter failures stop the packer and the ROM build with a nonzero
exit status. The failing song wrapper and assembler diagnostics remain in
`.sound-build/music.asm` and `.sound-build/music.log`. Invalid or oversized
music/DAC data also fails the build instead of producing a partial playlist.

## Validation

The `Windows sound build` workflow checks the shipped Lua launcher and ROM build
from a directory containing spaces, then rebuilds the tools, runs their checks,
and builds the ROM again on a native Windows runner.

```sh
python3 build_tools/sound/build.py --check
python3 build_tools/check_sound_playback.py --core /path/to/genesis_plus_gx_libretro.so \
  --effects --jingles
python3 build_tools/check_sound_playback.py --core /path/to/genesis_plus_gx_libretro.so \
  --pal --songs GHZ EHZ GGZ1 RRZ1 HTZ HPZ GRGZ2 LBZ2_S3 EndLevel ExtraLife
```

The optional playback check uses the existing libretro harness, NumPy, and
Pillow. Its core must expose the `work_ram`, `vram`, and `zram` symbols, as the
tested Genesis Plus GX build does. Reports and selected WAVs go under
`.sound-build`. It boots the real game, enters sound test, and plays through the
actual 68000/Z80/YM2612/PSG paths.

Checked on this update:

- All 19 instruments in HTZ, Gene Gadget 1, and Rusty Ruin 1 match the source's
  preserved raw dumps, converted to S2's operator order.
- Every compressed project song matches fresh assembly with an independent
  Python Saxman decoder.
- 123 compressor cases cover zero-length data, trailing zeros, dictionary wrap,
  and nonzero output stream positions.
- Macro fixtures check relative music pointers, compact absolute SFX headers,
  modern command conversions, and unsupported-import diagnostics.
- Packer fixtures cover dependency invalidation, failed assembly, raw binary
  flags, `$8000` limits, decompressed buffer overflow, separate bank placement,
  and asset overflow detection.
- 57 tracks played for 600 frames each in NTSC; 10 representative tracks passed
  the equivalent PAL check. 83 sound effects produced audio. The 1-up jingle
  restored both RAM-loaded GHZ and ROM-streamed Launch Base 2, including the
  original compressed song's RAM data and each song's bank/instrument pointer.

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
- Bundled Saxman source baseline:
  [sonicretro/KENSSharp, `a2cf5d1`](https://github.com/sonicretro/KENSSharp/tree/a2cf5d1c24558e190b6de4ddcc359cb80bac5cba/Saxman).
  The local copy bounds the zero-fill search at EOF, keeps dictionary searches
  nonnegative, handles decode wrap/empty input, and fixes size headers for output
  streams with a nonzero starting position. It retains the legacy matching
  strategy rather than switching compressors. Its LGPLv3/GPLv3 texts accompany
  the source in `KensSharp.Saxman`; the DLL remains dynamically replaceable.

The runtime driver is unchanged by this tooling update, including its existing
fix for restoring uncompressed music after a 1-up.
