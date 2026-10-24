# Developer documentation

These guides describe the current implementation. Source definitions in
`_definitions/s2.constants.asm`, the relevant ASM module, and generated sprite bounds take
precedence when changing allocations or formats. Run commands from the repository
root. Windows is the primary development environment; see [AGENTS.md](../AGENTS.md).

| Guide | Owns |
| --- | --- |
| [Objects](Objects.md) | SST fields, placement/loading ownership, composites and Debug |
| [Importing objects](Importing-objects.md) | Import workflow and the EHZ boss example |
| [Sprites and VRAM](Sprites-and-VRAM.md) | Mapping/DPLC formats, renderer, shared art allocations and caches |
| [Players and effects](Players-and-effects.md) | Character behavior, companion AI, monitors, water and input locks |
| [Levels](Levels.md) | Zone status, per-act PLCs/music, tile animation, SMZ and asset regeneration |
| [Special stage](Special-stage.md) | Rotating S1 stage, its separate ABI, overlays and screen-specific VRAM |
| [Mega-CD](Mega-CD.md) | Mode 1 branch, CPU ownership, banked RAM, jobs and DMA |
| [Testing](Testing.md) | Dependencies, commands, disposable course, report generation and limits |

[SonLVL's own guide](../SonLVL%20INI%20Files/README.md) owns editor setup,
property definitions and subtype options. [KeH sound tools](../build_tools/sound/README.md)
own song/SFX importing, packer formats and sound-tool builds.
[TODO.txt](../TODO.txt) is the development backlog, rather than implemented behavior.

## Source organization

`md-main.asm` is the Mega Drive main-68000 entry point. `mcd-main.asm` is the
Mega-CD sub-68000 program, embedded in the same cartridge ROM and uploaded into
CD PRG RAM at startup. Both CPUs are 68000s; distinguish code by its owner,
not by instruction set. See [Mega-CD](Mega-CD.md#cpu-source-boundary) for the
assembly and mailbox boundary.

`_definitions/` groups the shared constants, RAM declarations, assembler setup
and macros, debugger definitions, and generated sprite bounds. Constants and RAM
variables remain together in `_definitions/s2.constants.asm`; the CD build adds
its hardware and physical RAM definitions alongside it. Preserve include order
when moving definitions: some depend on macros or earlier allocations.

`md-only/` contains the cartridge-specific backends selected by
`MegaCDMode1 = 0`: direct codecs and streaming, collision, placement loading and
their private RAM. Mode 1 remains the default. Shared assets and engine sources
keep their existing paths; see [build dependencies](Mega-CD.md#cartridge-build-dependencies).

`_inc/` holds engine subsystems and substantial tables. Keep small helpers and
local macros with their owner; split a routine out when it makes the subsystem
easier to find and maintain. Generated audio tables belong under `sound/`, as
described in the [sound guide](../build_tools/sound/README.md).

## Branch scope

`Mystic-Island` is the ordinary cartridge branch. `test/rebuilt-kehmusic` primarily
targets Mode 1, with required Mega-CD RAM and selective sub-CPU work when
`MegaCDMode1 = 1`. Setting it to `0` selects the self-contained cartridge
dependencies in the same source tree. Shared guides apply to both; the Mega-CD
guide describes the KEH branch and its build selection. Sixteen four-act zones
are exposed (`$00-$0F`); editable starter acts are not
finished levels. Planned mixed-size SonLVL authoring is listed under
[future layout work](Levels.md#planned-layout-format), not as a current feature.

## Maintaining these guides

Update the existing guide when its subsystem changes. Put a fact in one guide
and link to it elsewhere. Keep current constraints, reproduction steps, asset
provenance and known limits; Git history preserves implementation narratives.
Do not add a new follow-up document for each fix or commit build-specific
hashes, screenshot digests, coverage matrices or generated result JSON here.
Write those to an explicit test-output directory instead; see [Testing](Testing.md).

Source files that are W.I.P. or not assembled are development work, not
permission to delete them during documentation or unused-code cleanup.
