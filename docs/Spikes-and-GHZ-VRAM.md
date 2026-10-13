# Spikes and common level art

Object `$36` uses the normal S3&K spike behavior and eight mappings from
[skdisasm](https://github.com/sonicretro/skdisasm/tree/73de97c6b55055bcb8089c1d55d006b02136f163).
The port adapts its object pointers to Mystic Island's ID/routine SSTs,
`SolidObject` contact masks and per-player damage routines. Floor, side and
ceiling contacts damage either player; an invincible player or one with a
nonzero **word** `flashtime` remains protected. A simultaneous contact preserves
the second player's collision flags across the first player's damage call.
Out-of-range deletion clears the placement's respawn flag.

The high subtype selects one through four pairs: `$00–$30` are floor rows and
`$40–$70` are side columns. Y flip selects ceiling behavior; X flip mirrors
the drawing. Low subtype `$0/$1/$2/$3` selects stationary, vertical movement,
horizontal movement or S3&K's 32-pixel pushable variant. The largest display
bounds use the generated `Map_Obj36_width/height`; smaller frames initialize
their exact bounds from the configuration table. Competition-mode art, FBZ
spikes and reverse gravity are outside the current engine's features.

`Spikes.nem` contains the original eight side tiles followed by eight floor
tiles. All frames use one art base; floor mappings add eight to their tile
indices. The S3 palette indices used by these pixels map as follows:

| S3&K index | Mystic Island index |
| --- | --- |
| `$0` | `$0` |
| `$1` | `$6` |
| `$C` | `$7` |
| `$D` | `$8` |
| `$E` | `$9` |

Both orientations use palette line 0. `PLC_Main2` loads this art once for
every level; the redundant zone spike loads are removed. The SonLVL definition
uses the same eight frames, palette, sizes and movement options.

## VRAM during normal gameplay

| VRAM range, inclusive | Tile range | Art |
| --- | --- | --- |
| `$6560–$669F` | `$32B–$334` | GHZ bridge, 10 tiles |
| `$66A0–$685F` | `$335–$342` | Swing, 14 tiles |
| `$6860–$6D1F` | `$343–$368` | Giant ball, 38 tiles |
| `$6D20–$701F` | `$369–$380` | Rock, 24 tiles |
| `$7020–$749F` | `$381–$3A4` | Ground explosion, 36 tiles |
| `$74A0–$7B7F` | `$3A5–$3DB` | Buzz Bomber, 55 tiles |
| `$7B80–$83FF` | `$3DC–$41F` | Crabmeat, 68 tiles |
| `$8400–$879F` | `$420–$43C` | Motobug, 29 tiles |
| `$87A0–$8A9F` | `$43D–$454` | Vertical Ball Hog, 24 tiles |
| `$8AA0–$907F` | `$455–$483` | Horizontal Ball Hog, 47 tiles |
| `$9080–$9A9F` | `$484–$4D4` | Newtron main art, 81 tiles |
| `$9AA0–$9E9F` | `$4D5–$4F4` | Diagonal spring bank; GHZ uses it for Chopper |
| `$9EA0–$A11F` | `$4F5–$508` | Vertical spring bank, 20 tiles |
| `$A120–$A2DF` | `$509–$516` | Horizontal spring bank, 14 tiles |
| `$A2E0–$A4DF` | `$517–$526` | Both spike orientations, 16 tiles |
| `$A4E0–$AC5F` | `$527–$562` | Monitor/signpost bank, 60 tiles |
| `$AC60–$AD9F` | `$563–$56C` | Checkpoint, 10 tiles |
| `$ADA0–$ADBF` | `$56D` | Free, one tile |
| `$DEE0–$DFDF` | `$6F7–$6FE` | GHZ wall segments, eight tiles |
| `$DFE0–$DFFF` | `$6FF` | Free, one tile |

GHZ scenery and badniks start immediately after its 811 terrain tiles. GHZ's
vertical spring uses only 16 of the reserved 20 tiles, so Newtron's four tail
tiles occupy `$A0A0–$A11F`. Its main art keeps the other 81 tiles, and assembly
mappings derive the tail offsets from `ArtTile_Newtron_Tail`. This preserves
every original pose without padding the lower bank or moving fixed effects.

The previously missing GHZ wall load uses the eight available tiles after the
points banks. Its cap reuses identical X-flipped terrain pixels at tile `$C1`.
Assembly mappings derive that offset from the named banks. This is the one GHZ
scenery allocation above the packed lower bank.

HPZ's Splats and BBat now use `$8300–$869F` and `$86A0–$8DDF`, directly after
water art. Their former slots overlapped the new common spike, monitor and
checkpoint banks. Their existing object/mapping bases follow the constants.

Rings, players, HUD, dust, explosions, flickies, shield/star banks and VDP tables
keep their established addresses. Boss and capsule PLCs deliberately replace
general level-object art, including springs, spikes and monitors. Their own
phases do not need those objects to remain resident.

GHZ's boss now queues `PLC_GHZBoss`, with S1 Eggpod art at `$8000`, weapons at
`$8D80`, exhaust at `$92C0` and capsule art at `$A100`. Moving the exhaust after
the weapons keeps it clear of the capsule during escape; the inline Eggman
mappings derive that offset from the constants. The ball and chain retain
their earlier GHZ banks. EHZ and its placeholder fights retain their own
existing boss list.

## Verification

After a normal build, run `python build_tools/check_ghz_vram.py` along with the
sprite asset/bounds and EHZ boss checks. The GHZ check reads the actual compiled
PLC destinations, checks all four GHZ acts and HPZ for overlaps, checks the
other live zone PLCs against common slots and verifies the shared mapping
references against resident art.

Native 68000 checks cover all sizes/orientations, both players, simultaneous
hits, shield and zero-ring damage, immunity, movement, push limits and respawn
flags. Pixel comparisons cover all eight S3 spike frames and both flip axes,
all Newtron poses in both palettes, and every wall frame. Genesis Plus GX tests
exercise both players' floor walking, side and ceiling collisions and compare
loaded GHZ/EHZ/HPZ VRAM bytes under NTSC and PAL.
The GHZ3 arena test also verifies the S1 boss/capsule PLC and the resident ball
and chain after the complete boss has spawned.
