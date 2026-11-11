# Developer documentation

Run commands from the repository root. Windows is the primary development
environment; [AGENTS.md](../AGENTS.md) owns formatting, source organization,
cleanup and verification rules. Source declarations take precedence over guide
examples when changing allocations or formats.

| Guide | Owns |
| --- | --- |
| [Objects](Objects.md) | SST fields, placement/loading ownership, composites and Debug |
| [Importing objects](Importing-objects.md) | Import workflow and the EHZ boss example |
| [Sprites and VRAM](Sprites-and-VRAM.md) | Mapping/DPLC formats, renderer, shared art allocations and caches |
| [Players and effects](Players-and-effects.md) | Character behavior, companion AI, monitors, water and input locks |
| [Levels](Levels.md) | Zone status, per-act PLCs/music, tile animation and asset regeneration |
| [Special stage](Special-stage.md) | Rotating S1 stage, its separate ABI, overlays and screen-specific VRAM |
| [Mega-CD](Mega-CD.md) | Mode 1 build, CPU ownership, banked RAM, jobs and DMA |
| [Testing](Testing.md) | Dependencies, test catalog, reproduction commands and validation limits |
| [SonLVL](../SonLVL%20INI%20Files/README.md) | Editor setup, property definitions and subtype options |
| [KeH sound tools](../build_tools/sound/README.md) | Song/SFX imports, packer formats, sound-tool builds and audio validation |

## Branch scope

`Mystic-Island` is the default development branch;
`Mystic-Island-(Experimental)` contains experimental work. Both target
[Mega-CD Mode 1](Mega-CD.md#build-target), the sole build target. The MD entry
point is `md-main.asm`; `mcd-main.asm` owns the sub-CPU program embedded in that
cartridge image. [Mega-CD](Mega-CD.md#cpu-source-boundary) describes the boundary.

Sixteen four-act zones are exposed (`$00-$0F`); starter acts are editable slots,
not finished levels. See [Levels](Levels.md) for current terrain, art and music
selection. Mixed-size SonLVL stamping remains
[planned work](Levels.md#planned-layout-format).

[TODO.txt](../TODO.txt) contains outstanding design work and older completed
notes. The guides describe implemented behavior. Keep current constraints and
asset provenance in the owning guide, test instructions in [Testing](Testing.md),
and implementation history in Git.
