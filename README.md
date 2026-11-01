# The Mystic Island

A Sonic 2 Nick Arcade ROM hack with expanded level slots, adapted S3&K
object loading and rendering, Sonic/Tails gameplay, imported level objects,
a rotating S1 special stage, and the KeH enhanced sound driver.

`Mystic-Island` is the default branch and includes the former KEH branch's
engine, tools and assets. The hack targets Mega-CD Mode 1 exclusively: its
cartridge image requires CD RAM and uses both 68000 CPUs. See the
[build target and hardware requirements](docs/Mega-CD.md#build-target).
Level content includes unfinished acts and editable starters.

Build from the repository root with `build.bat` on Windows, or `lua build.lua`
on Linux/BSD with the matching native tools and Mono. Output is `s2built.bin`.
See [building and testing](docs/Testing.md) for dependencies and checks.

[Developer documentation](docs/README.md) is the subsystem index.
[SonLVL setup](SonLVL%20INI%20Files/README.md),
[sound importing/tools](build_tools/sound/README.md), and [TODO.txt](TODO.txt)
cover editor use, audio work, and the remaining backlog.

DISCLAIMER: Any and all content presented in this repository is presented for informational and educational purposes only. Commercial usage is expressly prohibited. We claim no ownership of any code in these repositories. You assume any and all responsibility for using this content responsibly. We claim no responsibiliy or warranty.
