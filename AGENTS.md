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
