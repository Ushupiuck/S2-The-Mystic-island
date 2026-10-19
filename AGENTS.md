# Development environment

Mystic Island's primary working copy lives in the owner's Windows 10 VM,
mainly because most Sonic ROM hacking tools target Windows.

Run native Windows build checks only when changes could affect compatibility:
compiler flags, launch commands, tools/libraries, or OS-specific code. Include
a project path containing spaces. Routine game code, art, and documentation
edits do not require duplicate Windows and Linux builds.
