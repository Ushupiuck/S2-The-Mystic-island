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

Keep small helpers with their owning subsystem. Reuse the existing source
files and their formatting; a new ASM include should represent a cohesive
subsystem or substantial generated data, not a single helper or a few constants.
Keep editable tables direct. Use macros for real shared work or validation,
not empty recipes or wrappers around one use. Art allocations belong in
`_definitions/s2.constants.asm`; importers must verify their expected banks.

Keep shared constants, RAM declarations and macro files in `_definitions/`.
Keep generated audio tables in `sound/` and per-bank audio includes in
`sound/generated/`; update generators and consumers together when relocating
outputs. Small local macros may stay with their owning subsystem.
