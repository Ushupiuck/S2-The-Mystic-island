# Sound driver and tools

This guide describes **`Mystic-Island-(Experimental)`**. It uses CloneDriver v2
on the Mega Drive main 68000 for FM/PSG music, the retained KeH Z80 worker for
DAC and FM/PSG effects, and the existing Mega-CD decompression service for songs.
PCM sequencing/playback on the CD is future work. `Mystic-Island` retains its
previous complete Z80 driver until this replacement is explicitly promoted.

## Source ownership

| Source | Owns |
| --- | --- |
| `_definitions/Sound Constants.asm` | Clone settings, native metadata format and music capacity |
| `_definitions/s2.constants.asm` | MD audio RAM allocations and public sound IDs |
| `_inc/Sound Interface.asm` | MD queues, song preparation, bus ownership and SFX handoff |
| `sound/CloneDriver/engine/` | Native FM/PSG sequencer, track layout and music import macros |
| `sound/Z80 DAC and SFX.asm` | Z80 DAC streaming and the six FM/PSG effect slots |
| `_definitions/_smps2asm_inc.asm` | Retained KeH **SFX** format |
| `build_tools/sound/KEHmusic/` | Native music assembly, Kosinski+ compression and DAC packing |
| `build_tools/sound/KEHsfx/` | Effect tables, priorities and IDs |

The vendored ASM release is Clownacy's **v2.8.0.1**, commit
[`f9723d683bcc304afb7a1fb5d1278592451fd274`](https://github.com/Clownacy/Sonic-2-Clone-Driver-v2/tree/f9723d683bcc304afb7a1fb5d1278592451fd274).
Later upstream v2.9 uses a precompiled C++ core. This integration keeps the ASM
FM/PSG implementation editable, replaces its DAC/SFX executors with the existing
Z80 worker, and obtains song pointers from prepared MD RAM. Global internal
labels carry the `Clone_` prefix to avoid game/SFX symbol collisions.

The native track's shared loop/call workspace is 20 bytes rather than upstream's
12. Imported arrangements can make three nested calls while loop counters remain
live; 68000 return addresses consume four bytes. The sequence validator checks
every call and loop against the assembled allocation.

## Playback and memory

Music lives in ordinary ROM through full 68000 pointers. There are **no music
banks**, `$8000` placement boundaries, Z80 music buffer, or Z80 music decoder.
`PlayMusic` queues a song ID. Before `WaitForVint`, `Sound_PrepareMusic` copies or
asks the existing CD Kosinski+ service to decode that song into MD RAM. The CD
transport stages cartridge input, runs its existing decoder, and copies the
result to the requested MD destination. No second MD decoder is installed.

A ready flag publishes the pointer only after loading finishes. The interrupt
never starts CD work or reads a buffer being replaced. The two `$4000`-byte MD
buffers separate normal music from 1-up jingles, preserving the previous song's
live sequence/instrument pointers for native restoration. All current songs fit;
future imports exceeding the decoded capacity fail explicitly. Raw storage is
also copied to MD RAM, rather than streamed from a Z80 bank.

See [Mega-CD memory](../../docs/Mega-CD.md#memory-and-ownership) for live allocations. Word RAM
is a transport workspace, not a simultaneous music store for both CPUs: the
engine uses 2M ownership transfers. Songs remain in MD RAM after the transfer.
For future PCM songs, each CPU will need a self-contained channel stream and its
dependencies in its own RAM; splitting and synchronizing those streams is not
implemented here.

`Sound_Update` runs **after** VBlank display work, including on lag frames.
Running music before the VBlank wait can miss that frame's display window.
Raster palette interrupts may preempt sequencing; individual YM register/data
pairs mask interrupts. A running flag rejects recursive audio updates.

Before music touches shared hardware/state, MD takes the Z80 bus, publishes
`MDLock`, and waits for `FMBusy` to clear. The Z80 checks that lock when entering
its effect update and publishes its busy flag before accessing FM/PSG. MD holds
the bus for its music tick and restores the YM `$2A` DAC selector before release.
This protects the address/data latch as well as DAC data writes. DAC streaming
pauses while MD owns the bus, just as it pauses during Z80 effect sequencing.

Actual Z80 effect flags override MD FM3/FM4/FM5 and PSG1/PSG2/PSG3 output. Music
continues sequencing silently on occupied channels. Release restores the music
instrument or PSG noise mode; DAC effects also override DAC/FM6 ownership.
DAC-enable state is mirrored to the Z80. Pause freezes both sequencers and DAC
progress; resume restores the appropriate voices. Tempo changes retain the
game's interval-based speed control and per-song `NoSpeedUp`/PAL flags.

The retained player is the project's **single DAC channel**, with its existing
PCM/DPCM samples and rates. This does not install upstream's two-channel DAC
mixer or per-sample volume support. Native FM/PSG fading remains enabled. DAC
samples and SFX still use the Z80's `$8000` ROM window and bank alignment.

## Rebuilding

The normal `build.bat` / `build.lua` build runs both shipped tools first. Windows
runs the EXEs directly; Linux/BSD require Mono. AS and `p2bin` come from the
matching platform's `build_tools` directory. To rebuild the tools:

```sh
python3 build_tools/sound/build.py --check
```

For a separately installed compiler/reference set:

```sh
python3 build_tools/sound/build.py --compiler /path/to/csc.exe \
	--mono /path/to/mono --framework /path/to/mono/4.0-api --check
```

The script supports Mono `mcs`, .NET Framework `csc`, and Roslyn; it targets
.NET Framework 4 and uses `IniFile.dll`. `CSC` and `MONO` are accepted. Rebuild
the distributed EXEs after source changes. The `Windows sound build` workflow
checks both shipped and rebuilt tools in a project path containing spaces.

## Importing music

Handwritten ASM in `sound/music/` and `music.ini` remain the editable sources.
Keep both source-version arguments when supplied:

```asm
Song_Header:
	smpsHeaderStartSong 3,1
```

The first selects source-driver semantics; the second selects the SMPS2ASM
instrument format. Omission means legacy format 0. Modern AM enables, literal
TL values, five-argument reserved D1R bits and the S3 two-argument FM-volume
command are preserved. Legacy names and enharmonic note aliases remain usable.
S3 PSG envelope aliases retain the project's existing S1/S2 approximations.
Cross-song instruments and universal voice banks fail explicitly: copy required
instruments into the song-local bank. Disabled native extensions require an
explicit driver change, not an unsupported bytecode import.

The destination **music format is CloneDriver**, with big-endian relative
pointers, an eight-byte header and `$FF` coordination flags. KeH music binaries
must be rebuilt from ASM or converted. SFX retain their separate compact KeH
headers and absolute Z80 bank pointers; do not assemble them with music macros.

Raw `.bin` music inputs must already use native Clone bytecode. They are raw by
default; an existing headerless Kosinski+ stream requires:

```ini
[Imported]
Title=Imported song
File=Imported.bin
BinaryFormat=KosinskiPlus
```

For ASM/raw inputs, compression is automatic when its stored size is strictly
smaller; equal-size and incompressible inputs stay raw. Both encodings must fit
the `$4000` **decoded** capacity. Explicit compressed inputs are bounded by their
decoded size, even if the packed stream is larger. Invalid references, truncated
streams, trailing data and output overflow fail the build.

The managed host encoder chooses a minimum bit-cost Kosinski+ parse and checks
each result through a bounded decoder. Its 8-KiB match dictionary is a format
property, not a limit on song length. It handles the full MD allocation without
using `p2bin`'s 8-KiB Z80 compression segment. Runtime decompression still uses
the existing CD decoder. `p2bin` continues converting assembled songs and
compressing the actual Z80 driver.

Repeated phrases may use ordinary calls and counted loops; the independent
validator checks complete loops, local instrument references, and live counter /
return-stack overlap. Preserve duration-only events and inherited durations when
optimizing. Measure both decoded and compressed sizes.

## Generated files and metadata

Generated tables stay in `sound/*.gen.asm`; music bytes stay in
`sound/generated/<ID>_cmp.bin` or `<ID>_raw.bin`. The INI's `OutputFile`, `Size`,
`UncompressedSize`, `IsCompressed` and `MD5` are computed metadata.
`sound/musicdata.gen.asm` includes each stored song in ordinary ROM with word
alignment; it does not emit music-bank wrappers. `musicinfo.gen.asm` owns the
`MusicIndex` entries:

| Offset | Field | Encoding |
| --- | --- | --- |
| 0 | Source | Full ROM long pointer |
| 4 | StoredSize | Big-endian word |
| 6 | DecodedSize | Big-endian word |
| 8 | Flags | Bit 0 compressed, 5 no speed-up, 6 force PAL tempo, 7 restoring jingle |
| 9 | Reserved | Zero |

The compressed-asset generator recognizes packed music includes, so imports
join the existing CD source-span manifest automatically. DAC aggregate/per-bank
includes retain `startBank` / `finishBank` and window-overflow checks. Old music
bank includes, bank-asset hooks and the monolithic Z80 source were removed; the
Sega logo/HUD remain ordinary art includes. Unassembled `sound-NA-Old` material
is preserved.

`.sound-build/music-cache.ini` hashes source/transitive includes, macros, DAC
IDs, native tools and the packer. `KEHmusic /clean` or `--clean` rebuilds all
songs. `--tools-dir PATH` / `KEH_TOOLS_DIR` override native tool selection.
Assembler/converter failures stop both packer and ROM build;
the launcher checks tool exit status and removes stale output before assembly. the failing wrapper
and diagnostics remain in `.sound-build/music.asm` / `music.log`.

## SFX priority

`PlaySound` uses normal priority arbitration; `PlaySound_Special` uses the
immediate effect queue. Named music IDs route to the preparation queue, and
named commands route to Clone's control queue. `PlaySoundStereo` retains the
stereo effect path. Avoid hardcoded command values.

Both bumper callers use `PlaySound`. A `$70` bumper cannot replace the `$7F`
Continue jingle. Priority persists until all six FM/PSG effect slots stop,
including Continue's longer FM4 tail. A PSG effect finishing cannot clear the
remaining FM priority. Equal-priority effects can retrigger.

## Validation

```sh
python3 build_tools/sound/build.py --check
python3 build_tools/check_music_sequences.py --output test-results/audio/sequences.json
python3 build_tools/check_sound_playback.py --core /path/to/genesis_plus_gx_libretro.so \
	--system-directory /path/to/mode1-fixture --effects --jingles --priority --switches --stress
```

Repeat playback with `--pal`. `--songs NAME ...` restricts selection. Reports
and WAV captures stay in ignored output directories. The core must export the
RAM, Z80 register/bus and FM-write interfaces used by the harness.

The host checks cover independent instrument dumps, native music / retained SFX
encoding, dependency invalidation, automatic compression, raw ties, the exact
16-KiB boundary, malformed inputs and independent round trips for every song.
Native sequence validation follows every channel to its repeat or termination,
checking pointers, instruments and shared loop/call storage. Optional reference
ROM/listing/INI arguments compare native streams after source optimization.
Historical KeH comparisons remain supported for KeH ROM pairs; cross-driver
per-frame state equality is not assumed.

Playback enters the real sound test and checks decoded MD bytes, audible
output, all effects, both restoring jingles over several songs, Continue/bumper
priority, and uninterrupted rapid song selection. The DAC trace checks each
actual DPCM write against its previous accumulator and current delta; new samples
explicitly reset to `$80`.

`--stress` enters **Scrap Madness Act 2**. With players held at the starting
floor, the actual level, CD services, rendering and both sound CPUs keep running.
It plays all effects over level music, checks all six channel handoffs and
restored FM patches, then mixes dense normal/stereo/immediate queues, CD music
loads, speed changes and real Start-button pause/resume. A common YM-write trace
checks CPU ownership of selector/data pairs and rejects music writes to active
FM effect channels. This is a focused integration fixture, not a controller-only
playthrough. Use act-launch, plane-streaming and early-water HBlank checks from
[Testing](../../docs/Testing.md) alongside audio checks.

## Source history

- [CloneDriver ASM release](https://github.com/Clownacy/Sonic-2-Clone-Driver-v2/tree/f9723d683bcc304afb7a1fb5d1278592451fd274).
- Retained KeH SFX/DAC and packer origins:
  [MainMemory/s2-sound-driver-plus, `57edda88`](https://github.com/MainMemory/s2-sound-driver-plus/tree/57edda88ae502cbb8c3bb425a00b52ea798e8b76/build_source/KEHmusic).
- Modern instrument syntax:
  [sonicretro/s2disasm, `4ef457c1`](https://github.com/sonicretro/s2disasm/blob/4ef457c18fc4902396c43ab06fabc119ac6ecb64/sound/_smps2asm_inc.asm).
- Runtime Kosinski+ implementation/provenance:
  [`_inc/KosinskiPlus.asm`](../../_inc/KosinskiPlus.asm), executed by the CD
  decompression service. The host's encoder/validator are managed C#; independent
  Python decoding is used by the tests.
