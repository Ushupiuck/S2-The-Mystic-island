# Spikes and common level art

Object `$36` uses the normal S3&K spike behavior and eight arrangements from
[skdisasm](https://github.com/sonicretro/skdisasm/tree/73de97c6b55055bcb8089c1d55d006b02136f163).
The port adapts its object pointers to Mystic Island's routine-pointer SSTs,
`SolidObject` contact masks and per-player damage routines. Floor, side and
ceiling contacts damage either player; an invincible player or one with a
nonzero **word** `flashtime` remains protected. A simultaneous contact preserves
the second player's collision flags across the first player's damage call.
Out-of-range deletion clears the placement's respawn flag.

The high subtype selects four, eight, twelve or sixteen spikes: `$00–$30`
are floor rows and `$40–$70` are side columns. Y flip selects ceiling behavior; X flip mirrors
the drawing. Low subtype `$0/$1/$2/$3` selects stationary, vertical movement,
horizontal movement or S3&K's 32-pixel pushable variant. The largest display
bounds use the generated `Map_Obj36_width/height`; smaller frames initialize
their exact bounds from the configuration table. Competition-mode art, FBZ
spikes and reverse gravity are outside the current engine's features.

Subtypes `$80–$D0` add Sonic 1's six arrangements to the same object:

| Subtype | Arrangement | Collision half-width / half-height |
| --- | --- | --- |
| `$80` | Three floor/ceiling spikes, 16 pixels apart | `$14 / $10` |
| `$90` | Three side spikes, 16 pixels apart | `$10 / $14` |
| `$A0` | One floor/ceiling spike | `$04 / $10` |
| `$B0` | Three floor/ceiling spikes, 24 pixels apart | `$1C / $10` |
| `$C0` | Six floor/ceiling spikes, 24 pixels apart | `$40 / $10` |
| `$D0` | One side spike | `$10 / $04` |

These keep the original [S1 mapping positions](https://github.com/sonicretro/s1disasm/blob/AS/_maps/Spikes.asm)
while using the already resident S3 art. Each upright spike selects one 1×4
column from the floor pair. The existing eight side tiles are de-interleaved
into two complete four-tile spikes. Each S1 side spike uses one 4×1 piece;
S3 side pairs use two 4×1 pieces instead of one 4×2 piece. Their X flips preserve the original facing
direction. No new tiles or PLC entries are needed. GHZ's 75
existing spike placements select these added frames, preserving their other
placement flags. The configuration tables supply the correct dimensions and
handler during initialization, without adding checks to the per-frame path.

`Spikes.nem` contains eight de-interleaved side tiles followed by eight floor
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
uses all fourteen frames, palette, arrangement and movement options.

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
| `$9080–$9B1F` | `$484–$4D8` | Complete Newtron, 85 tiles |
| `$9B20–$9F1F` | `$4D9–$4F8` | Chopper, 32 tiles; GHZ has no diagonal springs |
| `$9F20–$A11F` | `$4F9–$508` | Vertical spring bank, 16 tiles |
| `$A120–$A31F` | `$509–$518` | Horizontal spring bank, 16 tiles |
| `$A320–$A51F` | `$519–$528` | Both spike orientations, 16 tiles |
| `$A520–$AC9F` | `$529–$564` | Monitor/signpost bank, 60 tiles |
| `$ACA0–$ADDF` | `$565–$56E` | Checkpoint, 10 tiles |
| `$DEE0–$DFDF` | `$6F7–$6FE` | GHZ wall segments, eight tiles |
| `$DFE0–$DFFF` | `$6FF` | Free, one tile |

GHZ scenery and badniks start immediately after its 811 terrain tiles.
Newtron's body, tail and exhaust now share one 85-tile Kosinski+ art file and
one contiguous VRAM bank. Its bytes and tile order match the original Sonic 1
art, so the flying frames use ordinary `$50/$52/$53` mapping offsets. The
separate tail file, Nemesis load and cross-bank constants are removed.

The three common spring banks are contiguous: diagonal at `$4DD` (28 tiles),
vertical at `$4F9` (16), horizontal at `$509` (16), ending exactly at the
spike bank `$519`. GHZ's Chopper starts four tiles before the diagonal bank,
using that interval instead; this fits both complete badniks without adding
VRAM or moving the fixed player/effect banks.

Motobug uses the approved darker-blue option: four head-highlight pixels move
from `$4` to `$3`, the 15 stored dark-red pixels from `$E` to `$4`, and eight
antenna-tip pixels from `$F` to the brighter orange `$E`. The other brass
details, smoke art, transparency and shared palette are preserved.

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

Native 68000 checks cover all fourteen sizes/orientations, both players, simultaneous
hits, shield and zero-ring damage, immunity, movement, push limits and respawn
flags. Pixel comparisons cover all eight S3 spike frames, all six added S1
arrangements and both flip axes,
all Newtron poses in both palettes, and every wall frame. Genesis Plus GX tests
exercise both players' floor walking, side and ceiling collisions and compare
loaded GHZ/EHZ/HPZ VRAM bytes under NTSC and PAL.
The added S1 groups and the actual GHZ2 shield-monitor pickup also pass under
both regions, including all four shield frames and both physical shield banks.
The GHZ3 arena test also verifies the S1 boss/capsule PLC and the resident ball
and chain after the complete boss has spawned.
