# Water effects and monitor fixes

The ordinary water splash is still its own object `$08`; dust remains `$0E`.
Splash art, its nine visible frames, S3&K mappings and DPLCs now stream through
the common dynamic-art loader. The source is
[skdisasm 73de97c6](https://github.com/sonicretro/skdisasm/tree/73de97c6b55055bcb8089c1d55d006b02136f163).
All imported water pixels use Mystic Island's existing palette permutation,
the same one used for the imported Tails art. No palette colors are replaced.

| VRAM bytes, inclusive | Tiles | Use |
| --- | --- | --- |
| `$8B80–$927F` | `$45C–$493` | 56 resident S3&K bubble tiles |
| `$FC00–$FDFF` | `$7E0–$7EF` | Primary player's dust, splash or countdown |
| `$FE00–$FFFF` | `$7F0–$7FF` | Companion's dust, splash or countdown |

Primary Tails uses the primary bank. The mouth/countdown objects retain each
player's independent air supply. Both mapping tables share the ordinary bubble
pieces; their number pieces select the appropriate six-tile streamed bank.
Ten six-tile countdown frames live uncompressed in ROM, and only the current
frame is uploaded. Numbers retain a separate screen-space display path so
reaching the surface cannot reinterpret them as bubbles. Refilling air or
leaving water removes existing numbers.

The two physical banks cache an art kind and frame in the reserved splash SSTs.
Switching from dust to splash or numbers invalidates the cached frame even if
the frame indexes match. A full DMA queue leaves an invalid frame and retries.
A live splash takes priority over dust; skid particles disappear when their
bank no longer holds skid art. Both water zones load resident bubbles through
their normal PLCs. HPZ's BBat bank moves immediately after the bubbles, to
`$9280–$99BF`, below the common spring banks. The unrelated player/HUD/ring/
shield/effect allocations remain unchanged.

Sonic's double-life monitor reuses the resident lives icon. Its mapping had
retained the old `$310` offset after the monitor bank moved. The corrected
offset is `$2AD` (`ArtTile_Lives_Counter - ArtTile_Monitor`); SonLVL's additional
art offset matches, and a ROM check verifies the resolved tile against the
current constants. The two-life award and sound are unchanged.

A rolling player climbing a slope can have negative Y velocity while grounded.
The old monitor hit path treated that as a rising jump and lifted the monitor
instead of breaking it. Grounded roll attacks now reach the break path first;
airborne underside hits retain their old behavior. The fix applies to Sonic
and Tails without changing ordinary monitor solidity.

Native checks cover both banks, source changes with equal frame indexes, DMA
retry, every countdown frame and grounded slope/airborne monitor contacts.
Static checks cover imported pixel permutations, S3&K mappings/DPLCs, the
lives-icon tile and the water/HPZ/common-bank boundaries.

`build_tools/check_water_effects.py` runs real crossings and air-controller
updates with Genesis Plus GX. It checks all nine splash frames, actual VRAM
uploads, sprite-table output, number emission and removal on resurfacing.
Use `--player 2` for primary Tails, `--companion` for the second bank, and
`--pal` for PAL. `--course` selects the disposable LZ2 build; omit it for HPZ.
Supply `--rom`, `--listing`, `--core` and `--output` paths. The fixture places
players and adjusts their air supplies; the game's code creates the effects.

Normal GHZ Act 3 spindash checks exercised the slopes at monitor X `$1878`
and `$1D45`, including Sonic and primary Tails. All four attract demos finish
in both regions, and GHZ/EHZ fights pass eight real hits, capsule release and
act-clear for both primary characters in NTSC and PAL.
