# Sprites, dynamic art and VRAM

`_definitions/s2.constants.asm` defines allocation symbols; the tables below use **end-exclusive**
byte ranges. A tile is 32 bytes. Object-specific act loads are selected through
[per-act PLCs](Levels.md#per-act-art); fixed addresses do not replace those loads.

## Mapping and rendering ABI

Ordinary mappings use a word piece count followed by six-byte pieces:
signed-byte Y, byte size, tile/attribute word, signed-word X. Frame tables contain
word-relative offsets. S1 imports need count/piece conversion; S2 imports must
remove their second tile word. This conversion is not done by the bounds pass.
The rotating S1 stage deliberately retains [its separate format](Special-stage.md).

For size byte `s`, width is `((s >> 2)+1)*8`, height is `((s & 3)+1)*8`.
`build.lua` invokes `build_tools/lua/sprite_bounds.lua`, which finds included
`Map*_height`, `Map*_width` and `Map*_frames` references, assembles an intermediate
image, and regenerates `_definitions/Sprite Bounds.asm`. Aliases, binary/shared frames and
backward frame references are supported. There is no manual mapping registry.
A failed bounds pass restores previous constants and leaves the playable ROM intact.

Bounds are symmetric maxima of `abs(X)`, `abs(X+width)` and the corresponding
Y values across every piece/frame. Set them alongside mappings on the actual
SST being initialized. `sprite_bound(legacy_minimum,Map_Name_width)` emits the
larger assembly-time constant. Moving composites need group bounds covering
their child motion, not merely one child's geometry. See [Importing objects](Importing-objects.md).

`Render_Sprites` consumes initialized bounds and routine pointers, with ordinary
and composite paths plus inline HUD/ring drawing. It clips composite children
separately. SAT links are initialized on clear; the renderer repairs the previous
terminator and writes a new hidden terminator, retaining the 80-sprite limit.
The S1 stage appends to the same link chain. There is no star-specific renderer path.

The VBlank wait latch has three states: `$00` while foreground code runs, `$01`
when `WaitForVint` requests work, and `$FF` once VBlank admits that request.
Only `$01` starts the full screen handler. A second VBlank arriving while the
first handler still runs must count lag and return without touching the VDP;
re-entering the handler can exhaust the stack and overwrite the end of the block
table. Ordinary foreground lag (`$00`) retains its water-palette refresh path.
The old [Twizzler lag investigation](Testing.md#runtime-checks) exercised this
distinction; it is not part of current decompressor migration checks.

## Dynamic art

`_inc/Dynamic Sprite Art.asm` implements `Load_DynamicPLC`: word run count, then
packed words containing a 12-bit source tile and a four-bit tile-count-minus-one.
Source art is uncompressed. The loader reserves enough DMA queue space for the
whole frame, including possible 128 KiB source-boundary splits. A full queue
returns carry and leaves the cached frame unchanged; callers retry and must not
display partially uploaded art. No decompression runs in VBlank.

Sonic/Tails/body/tail/dust use this service. Some dedicated UI loaders, including
the signpost, retain their own cue encoding; do not assume every DPLC file uses
one format. SonLVL's overrides are documented in [its guide](../SonLVL%20INI%20Files/README.md).

### Mode 1 RAM art

On `test/rebuilt-kehmusic`, shield, invincibility and normal/lost-ring art is
Nemesis-compressed in ROM. The CD CPU decodes it into Word RAM, then MD copies
the results into its packed work area; see [the decoder boundary](Mega-CD.md#asset-decompression-and-plcs).
`Art_Shield`, `Art_Invincibility` and `Art_Ring` are RAM source addresses on this
branch; cartridge builds retain their uncompressed ROM sources. The existing
shield DPLCs, resident-star upload and eight-frame ring uploader use those
addresses without changing mappings, frame selection or VRAM banks.

| RAM bytes, end exclusive | Source | Size |
| --- | --- | --- |
| `$FFB4CC-$FFB82C` | Shield | `$360` |
| `$FFB82C-$FFBC6C` | Invincibility stars | `$440` |
| `$FFBC6C-$FFC06C` | Normal/lost rings | `$400` |

The cache occupies `$BA0` bytes after the CD ring event queue. `LoadPlayerEffectArt`
decompresses all three after level clears/PLCs and before `InitRingFrame`;
it also runs on death restarts and returns from other scenes. The rotating S1
stage loads its ring source independently with `LoadRingArt` before its first
upload to `$2940`; it needs no shield/star source. Its palette-remapped results
ring remains a separate ROM asset. Decompression runs outside VBlank.

Keep the editable files in `art/uncompressed/`; SonLVL continues reading the
raw ring. After editing these sources, run
`python build_tools/build_player_effect_art.py`, then use `--check` to verify
the committed packed copies. The old `art/nemesis/Shield.nem` is unrelated
to this dynamic art and is preserved.

## Shared level allocations

These apply during ordinary level play. Zone-specific terrain/badnik and boss
phases can have different lifetimes; the [special-stage map](Special-stage.md#vram)
is not a source of free level VRAM.

| Bytes, end exclusive | Tile base | Use |
| --- | --- | --- |
| `$0020-$0220` | `$001` | Streamed water surface: 16 tiles immediately after transparent tile zero |
| `$9BA0-$9F20` | `$4DD` | Diagonal springs, 28 tiles; GHZ reuses this space for Chopper |
| `$9F20-$A120` | `$4F9` | Vertical springs, 16 tiles |
| `$A120-$A320` | `$509` | Horizontal springs, 16 tiles |
| `$A320-$A520` | `$519` | Floor/side spikes, 16 tiles |
| `$A520-$ACA0` | `$529` | Monitor/signpost bank, 60 tiles |
| `$ACA0-$ADE0` | `$565` | Checkpoint, 10 tiles |
| `$ADE0-$B020` | `$56F` | Auxiliary shield, 18 tiles |
| `$B040-$BC00` | `$582` | Normal/shared fiery explosion art, 94 tiles |
| `$BC00-$BE40` | `$5E0` | Animal bank 1, 18 tiles |
| `$BE40-$C000` | `$5F2` | Animal bank 2, 14 tiles |
| `$C000-$D000` | `$600` | Foreground plane, 64 by 32 entries |
| `$D000-$D400` | `$680` | Sonic body allocation |
| `$D400`, `$D600` | `$6A0`, `$6B0` | Tails body/tail upload bases; see overlap rule below |
| `$D720-$D8A0` | `$6B9` | Ring, lost ring and sparkles |
| `$D8A0-$DE60` | `$6C5` | HUD, debug glyphs and counters |
| `$DE60-$DEA0`, `$DEA0-$DEE0` | `$6F3`, `$6F5` | Per-player points, two tiles each |
| `$DEE0-$DFE0` | `$6F7` | GHZ wall art, eight tiles |
| `$DFE0-$E000` | `$6FF` | One free level tile |
| `$E000-$F000` | `$700` | Background plane, 64 by 32 entries |
| `$F000-$F380` | `$780` | HScroll table |
| `$F380-$F800` | `$79C` | Shared shield/invincibility bank |
| `$F800-$FA80` | `$7C0` | Hardware sprite table |
| `$FA80-$FC00` | `$7D4` | Life art |
| `$FC00-$FE00`, `$FE00-$10000` | `$7E0`, `$7F0` | Primary/companion dust, splash or countdown |

Tails body/tail bases are intentionally shared as in S3&K: a body upload can
extend into the tail area. The largest body/tail uploads are 24/nine tiles,
ending before ring tile `$6B9`; they are not independent full banks.

**Check the symbols before allocating around `$B000`.** `ArtTile_Shield_2_End`
is `$581` (`$B020`), not `$580`. Cards and large boss explosions start at
`ArtTile_Title_Card` / `ArtTile_BossExplosion = $581`; the 84-tile maximum card
fits before animal art. Do not reuse the former claim that two tiles at `$B000`
are free. Boss/capsule loading deliberately replaces general object art;
see [the EHZ example](Importing-objects.md#arena-and-art-lifetime).

GHZ packs its bridge/scenery/badnik art after its terrain. Newtron uses one
complete 85-tile bank; Chopper starts at `$4D9` and occupies the diagonal-spring
space. Adding diagonal springs to GHZ needs a new allocation. Wall caps reuse
terrain tile `$D1`. HPZ keeps `ArtTile_Splats = $418`, resident bubbles at
`$45C-$493`, and BBat at `$494-$4CD` (bytes `$9280-$99C0`), below the spring bank.
Use the actual PLCs/constants for other zone banks, not an older address table.
SMZ's atlas, junction and smoke lifetimes are in [Levels](Levels.md#scrap-madness).

## Effects and UI ownership

### Boss explosions

GHZ and EHZ share Sonic 2 final's seven-frame fiery boss explosion through
both boss PLCs at `ArtTile_BossExplosion = $581`. Its 100 tiles occupy
`$B020-$BCA0`, replacing ordinary explosion art and the first five tiles of
animal bank 1 during the fight. Keep that bank live until every burst finishes.
GHZ reloads ordinary explosions and animals during recovery; EHZ does so after
its escape delay, before the capsule opens. The controller and parent SST
contract are in [Objects](Objects.md#ghz-boss-and-boss-explosions).

`art/uncompressed/Large explosion.unc` is the editable pixel source;
recompress it to `art/nemesis/Large explosion.nem` using mdcomp's
`nemcmp "art/uncompressed/Large explosion.unc" "art/nemesis/Large explosion.nem"`.
The art and `mappings/sprite/Boss Explosion.asm` retain the Sonic 2 final import
from s2disasm `15e9fd52a65318bec3d5e746ce48dba6db6910db`. The seven mapping
frames last 2, 2, 3, 3, 3, 4 and 4 game frames: S3&K's 21-tick lifetime fitted
to the S2 sequence. Ordinary bomb, enemy and capsule explosions retain their
separate art/timing.

The optional advancing wall loads `PLC_ExplosionWall`: the same large art plus
`Nem_Explosion` relocated to `ArtTile_ExplosionWall_Small = ArtTile_Eggman`
(`$8000-$8BC0`, 94 tiles). This is an alias of inactive ship space, not a new
permanent reservation. Its normal bursts use `Map_Explosion` without animals,
with S3&K's short first frame and high-priority flag. This lets both sizes
coexist despite the ordinary default bank overlapping the large effect.
The invoking level must keep both wall banks free of other users until all
visuals finish, then restore any art it needs. No act currently invokes the wall.

### Player effects and UI

Both eight-star trails share 34 resident tiles at `$F380`. Their gray ramp
uses the shared palette, while each player owns independent animation/lifetime.
The primary has a reserved SST; companion stars allocate one dynamic SST and
retry while needed. [Objects](Objects.md#composites-and-other-records) defines
packed records and all physical-bank cache offsets.

Classic shields stream nine or eighteen tiles per visible frame. With two shields,
the primary uses `$F380`, companion `$ADE0`. While either player is invincible,
a visible shield uses the auxiliary bank; the primary restores its current frame
when both invincibility timers end. Frame zero is invisible. The DPLC's extra
empty entry reserves cache value zero; `PlayerEffects_ShieldFrameBias` selects it.

Effect cache values are zero for empty, 1-4 for shield cues, `$80` for stars,
`$FE` for results/Game Over reservation, and `$FF` for invalid. Retirement retains
physical-bank cache state. Act clear reserves both banks before its UI reuses
that region; Game/Time Over protects the dead primary's bank from companion stars.

Each player has one visible points popup, with at most two uploaded tiles.
A new award replaces that player's predecessor only after the complete upload
fits. The predecessor gets an empty frame until retirement, preventing queued
sprites from reusing another award's SST. Primary Tails uses the primary bank.

The water surface shares one 16-tile bank/cache between its two reserved objects.
Gameplay uploads an eight-tile phase; paused display needs two phases (16 tiles).
A failed queue reservation retries the full phase. Dust, splash and countdown
share the separate per-player banks shown above and cache both art kind and frame.
A live splash takes precedence; numbers have their own screen-space draw path.
Resident bubble art is separate. See [player behavior](Players-and-effects.md#water-and-shared-effects).

Cards/results stream scene-specific glyphs at tile `$581` rather than loading
the whole raw font. `build_card_art.py` owns their mappings/DPLCs, including
act 4, V/W and the wide W metrics. Small results markers use blue-only shading
from `Title Cards Base.unc`; the generator supplies a separate gold/yellow
version for the special-results palette, keeping gray out of their edges. Both
versions retain the same two-tile scene allocation. `build_signpost_art.py` owns the streamed
signpost and monitor arrangement. Tails's portrait is the final four monitor
tiles (`$561-$564`); signpost frames stay below it. Sonic's life art remains
separate and is shared with Sonic monitors. HUD score uses ten-point units,
with maximum display 9,999,990.

`HudUpdate` shares ring, life and result-bonus updates between its ordinary and
placement displays. Its initial digit table uses S3&K-style readable strings,
with list bounds determining the upload counts. `HUD_Time` draws the current
time without advancing or enabling the clock, allowing an immediate Debug
return redraw. Time Over does not restart a player already in the death/over
routines. See [Debug](Objects.md#debug) for the placement-only HUD/timer rules.

`build.lua` generates `art/uncompressed/Debug Digits.bin` from the shared
`Level select and Debug Mode text.bin`, preserving the owner's Ristar glyphs.
It packs source tiles `0-9` and `17-22` into sixteen hexadecimal tiles, ordered
`0-F`, and changes foreground `$F` to HUD white `$6`; background `$0` stays
transparent. Edit the shared source, then rebuild to regenerate the HUD copy.
The existing coordinate VRAM range and menu/error font palette indices remain
unchanged.

## Palette adaptation

Runtime player art uses `palette/SonicAndTails.bin`. The S&K source index order
maps to `0 6 5 3 2 4 C D E F A B 7 8 9 1`; transparency is preserved.
The imported blue/gray ramps and warm skin colors are intentional. Adapt
individual imported pixels instead of changing global player colors to fix
one object. The current SMZ flame and protected button draft are described in
[Levels](Levels.md#scrap-madness). Check [Testing](Testing.md) after art changes.
