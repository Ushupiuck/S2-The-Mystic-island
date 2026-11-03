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
| [Mega-CD](Mega-CD.md) | Mode 1 build, CPU ownership, banked RAM, jobs and DMA |
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

Mega-CD Mode 1 is the sole build target. The cartridge boot path, CD-owned
terrain/decoder services and their RAM declarations are unconditional; see the
[build target](Mega-CD.md#build-target). Shared editable assets keep their
existing paths.

`_inc/` holds engine subsystems and substantial tables. Keep small helpers and
local macros with their owner; split a routine out when it makes the subsystem
easier to find and maintain. Generated audio tables belong under `sound/`, as
described in the [sound guide](../build_tools/sound/README.md).

## Branch scope

`Mystic-Island` is the default development branch and includes the former KEH
baseline. `Mystic-Island-(Experimental)` is the experimental branch. Both target
Mega-CD Mode 1 with required CD RAM and sub-CPU processing. Sixteen four-act
zones are exposed (`$00-$0F`); editable starter acts are not finished levels.
The [independent-plane engine](Levels.md#mode-1-plane-engine) is the live terrain
path. Mixed-size SonLVL stamping remains [future work](Levels.md#planned-layout-format).

## Current development state

The rotating stage has seven collectible emeralds and seven layouts; Stage 7
is an editable copy of Stage 6, not a newly authored course. Its outcome flag,
Debug entries, results arrangement and consolidated art are documented in
[Special stage](Special-stage.md#emerald-items). Title/results typography,
streamed bonus digits and the 9:59 secret bonus belong to
[Sprites and VRAM](Sprites-and-VRAM.md#player-effects-and-ui).

[Levels](Levels.md#emerald-hill-flower-palette) records the EHZ palette/flower,
foreground waterfall, PP background animation and reflection work. Both-player
tunnel effects and Mecha's floor/facing fixes are in
[Players and effects](Players-and-effects.md) and
[Mecha Sonic](Sprites-and-VRAM.md#mecha-sonic-standard-fight).
EHZ and both SMZ acts retain their reusable foreground authoring collections;
see [Levels](Levels.md). The common [spring atlas](Sprites-and-VRAM.md#palette-adaptation)
is packed vertical/horizontal/diagonal/support, with spikes immediately after it.
The same guide records the shared full-height S1 seesaw and spikeball atlas.
GHZ/EHZ share S1 head and exhaust art while retaining their own cockpits;
S1's seat padding now uses the S2 orange ramp. See
[shared boss art](Sprites-and-VRAM.md#shared-eggman-heads-and-exhaust).
Next, return to [EHZ1/EHZ2 palette-space consolidation](Levels.md#emerald-hill-act-2-palmtree-panic-experiment).
The earlier cross-act greens preview was not applied to Act 1. The remaining
boss gray decision and its isolated WIP checkpoint are
[explicitly pending](Importing-objects.md#ehz-boss-palette-candidate).

The existing guides remain in use; migration/import scripts are kept
when they own a reproducible asset or a still-useful authoring operation.
`TODO.txt` retains older completed notes as history; current behavior lives in
these guides, and outstanding level/design work must be labelled as such.

## Maintaining these guides

Update the existing guide when its subsystem changes. Put a fact in one guide
and link to it elsewhere. Keep current constraints, reproduction steps, asset
provenance and known limits; Git history preserves implementation narratives.
Do not add a new follow-up document for each fix or commit build-specific
hashes, screenshot digests, coverage matrices or generated result JSON here.
Write those to an explicit test-output directory instead; see [Testing](Testing.md).

Source files that are W.I.P. or not assembled are development work, not
permission to delete them during documentation or unused-code cleanup.
