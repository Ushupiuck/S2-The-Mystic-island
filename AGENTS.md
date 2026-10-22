# Instructions for future work sessions

Read this file and [docs/README.md](docs/README.md) before editing, then read
the guide for the affected subsystem. These rules preserve the owner's ability
to find, understand and edit the project. A successful assembly does not excuse
an unreadable implementation. Current user instructions take precedence.

# Development environment

Mystic Island's primary working copy lives in the owner's Windows 10 VM,
mainly because most Sonic ROM hacking tools target Windows.

Run native Windows build checks only when changes could affect compatibility:
compiler flags, launch commands, tools/libraries, or OS-specific code. Include
a project path containing spaces. Routine game code, art, and documentation
edits do not require duplicate Windows and Linux builds.

# Documentation maintenance

Update the relevant canonical guide in `docs/` alongside subsystem changes.
Use `docs/README.md` as the index; keep each rule in one guide and link to it.
Verify formats, allocations and implementation status against current source,
and label branch-specific behavior and unimplemented plans explicitly.

Do not create per-fix follow-up documents or commit generated test snapshots,
ROM hashes and coverage matrices into `docs/`. Use explicit test-output
directories (`test-results/` is ignored). Preserve useful reproduction steps,
source provenance and known validation limits in the canonical testing guide.
W.I.P./unassembled sources are development work, not disposable unused code.

# Source organization

- Keep CPU ownership explicit: `md-main.asm` owns Mega Drive main-68000 code;
  `mcd-main.asm` owns Mega-CD sub-68000 code. Shared declarations stay in
  `_definitions/`. Subsystem includes inherit the owning entry point; CD bus,
  DMA and command callers execute on MD, while the subprogram's executors run
  on CD. Keep that distinction visible in include headers and documentation.
- Keep small helpers and local macros with their owning subsystem. Reuse the
  existing files and their formatting. A new ASM include should represent a
  cohesive subsystem or substantial table, not one helper or a few constants.
  Avoid both a maze of tiny includes and an unrelated-code dumping ground.
- Keep shared constants, RAM declarations, assembler setup and macro files in
  `_definitions/`. Do not scatter duplicate definitions between the root,
  `_inc/` and object files. Preserve definition/include dependency order.
- Art allocations belong in `_definitions/s2.constants.asm`; importers must
  verify their expected banks. Generated audio tables belong in `sound/`, and
  per-bank audio includes in `sound/generated/`. Update producers and consumers
  together when relocating outputs.
- Use descriptive names that distinguish addresses, record offsets, flags,
  masks, sizes and counts. A placement-record flag is not an SST field or an
  allocation size. Keep unlike definitions in clearly labeled sections.
- Follow the surrounding ASM layout: tabs for indentation/alignment, familiar
  section comments and consistent label/operand formatting. Declare RAM with
  `phase`/`dephase` and typed `ds.b`/`ds.w`/`ds.l` fields; retain `equ` for actual
  constants and record offsets. Document aliases and intentional overlays.

# Editable tables and macros

- Keep one authoritative editable definition for each live list. When replacing
  a table, migrate its consumers and remove the superseded implementation after
  checking references. Do not leave old zone lists beside new act lists, or
  retain dead compatibility tables just to keep obsolete checks passing.
- Keep hand-edited data visible as ordinary entries. Do not make the owner
  trace a macro chain, implicit fallback or scattered recipe to change one act.
  Some repeated data is preferable to an abstraction that hides the edit point.
- Macros should encode a real format, perform useful validation, or factor
  meaningful shared work. `plcm` and `plccheck` are examples. Do not create empty
  `*_Art` macros, macros immediately invoked only to stand in for a label, or
  wrapper layers that merely rename another invocation.
- Compute IDs from named pointer entries and counts from each list's own
  start/end labels. Do not infer a list's length from the next unrelated list,
  depend on accidental file order, or synthesize label names through opaque
  macro tricks where an ordinary declaration is clear.
- Keep the act PLC index, IDs and lists together in
  `_inc/Pattern Load Cues.asm`. Follow that file's section headers, ordering,
  count/entries/end-label layout and existing macros. Do not recreate separate
  Act PLC Index / Act Pattern Load Cue includes or per-act recipe files.
- Each act must remain directly editable, even when its art currently matches
  another act. Use explicit empty lists (`dc.w -1`), not dummy macros or fake
  assets. When populating one, restore the computed count header and preserve
  its queue-budget check. Follow [Levels](docs/Levels.md#per-act-art) for limits.
- Derive table lengths and slot ranges from the existing project constants.
  Check the first/last entry and every consumer when changing indexing; do not
  add an extra zone, act or sentinel unless the format actually requires it.
- Preserve the full binary contract: entry stride, relative-pointer base,
  count encoding, ID width and signedness. PLC IDs are unsigned bytes; the
  empty-list count is signed `-1`. Treat those as different fields. Capacity
  checks must include requests already occupying the queue and the largest
  applicable character variant, not just the new list in isolation.
- Validate the path actually used by the game: level/act/timezone selection,
  header ID, pointer entry and final list payload. Update generators, validators
  and documentation with the runtime consumers. A check against an obsolete
  lookalike table is not evidence that the live table works.

# Assets, generators and cleanup

- Find the authoritative editable source and its generator before changing
  generated art, mappings, DPLCs, bounds or audio data. Update that source or
  generator, regenerate the checked-in outputs, and inspect the resulting diff.
  A manual output-only patch must not disappear on the next regeneration.
- Keep source art convenient for human editing. Document palette-index roles
  and engine-reserved tile ranges; coordinate art changes with their mappings,
  PLCs, animations and SonLVL definitions instead of hiding a runtime workaround
  in an arbitrary part of an editable asset.
- Unlinked does not mean disposable. Preserve W.I.P., alternate palettes,
  editor sources and drafts unless their removal is explicitly in scope.
  Before deleting allegedly unused code/art, inspect references, build variants,
  generators, editor definitions and history. Remove only the obsolete portion.
- An optimization must actually reduce the relevant work/storage. Count unique
  tiles, shared palette roles and simultaneous VRAM lifetimes before duplicating
  art or claiming savings. Moving working RAM to the CD is not CPU offloading:
  move its executor too, with explicit bus ownership and buffer lifetimes. See
  [Mega-CD](docs/Mega-CD.md) for that subsystem's contracts.

# Scope, verification and handoff

- Inspect the current branch and local changes first. Implement shared fixes
  once and cherry-pick them onto the intended branches; keep experiments and
  branch-specific behavior isolated. Do not overwrite another person's work or
  mix unrelated functionality into a cleanup commit.
- Trace the complete affected path, not just the first matching file. Consider
  loaders, callers, mappings, art, palette, PLCs, placement/Debug/editor data,
  generators and documentation as applicable. Check retained variants too.
- Run the existing checks appropriate to the change. For visual changes, enter
  the relevant scene and inspect the rendered result, including animation or
  palette transitions when affected. Byte equality alone is not visual proof.
  Documentation-only edits do not need a ROM build.
- Before finishing, remove scaffolding introduced by the change: stale includes,
  dead wrappers, duplicate declarations and misleading comments. Verify generated
  outputs reproduce and documentation links resolve. Keep code, comments and
  guides honest about implemented behavior versus future plans.
- Report the actual commits/branches, meaningful verification and remaining
  limits. Preserve enduring decisions in the existing canonical guide; use Git
  history for the narrative, not another session-specific handoff document.
