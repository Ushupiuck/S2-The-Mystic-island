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

In Mode 1, screen handlers return directly to the outer VBlank restore.
Timer tails use local short conditional exits, and the title-card handler tail-calls its final
PLC bookkeeping routine. Preserve the outer register restore and `rte` once.

Obj17's ICZ-style side rails reuse the platform and link tiles already loaded
for GHZ/SLZ/SMZ. `python build_tools/build_swing_rails.py` builds the three
`* rail.bin` mappings from their ordinary platform mapping files; those inputs
and the generator's explicit rail offsets are the editable source. Re-run the
generator after changing the source mappings. The normal bounds pass derives
all three rail bounds. No extra tile art, palette or VRAM allocation is added.

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

### Hanging animation

D9's traversable row reuses the original FBZ handhold: sixteen by forty pixels,
two mapping pieces and ten resident tiles for any number of grips. The editable
`art/uncompressed/Hanging surface.unc` keeps the first ten tiles of skdisasm's
`Levels/FBZ/Nemesis Art/Misc Art 1.nem`, revision
`73de97c6b55055bcb8089c1d55d006b02136f163`. Source indices `0,1,2,3,4,5,F`
map to shared palette-0 indices `0,6,7,8,9,9,1`; no zone palette change is needed.
Although flips reduce the source to two unique tiles, retaining its arrangement
avoids expanding each handhold into ten hardware sprites.

Run `python build_tools/build_hanging_surface_art.py` after editing that raw
source. It regenerates the Nemesis art and 1–11 visible-row mappings; `--check`
verifies all outputs. The controller clips its full 1–63-grip span before
selecting the mapping. Grips are 32 pixels apart and end at the controller's Y.

DA reuses this handhold and appends two 8×8 chain tiles, forming one 8×16 repeat.
The editable source is `art/uncompressed/Hanging chain.unc`: FBZ Misc Art 1
tiles `$EE-$EF`, with source indices `0,1,7,8,9,A,B` remapped to primary line
`0,6,F,D,4,B,1`. This is the approved orange/red chain and gray handhold preview;
neither image needs a level palette edit. The generator also builds DA's thirty
viewport mappings and the combined `art/uncompressed/Pull chain.unc` editor
atlas. Edit the separate handhold/chain sources, not that generated atlas.

`ArtTile_HangingSurface = $40D` occupies `$81A0-$8320` (twelve tiles). All four LZ
Extra PLCs load it in space released by the conveyor. GHZ4 loads it in its own
sparse test kit, with an empty badnik module list. Other GHZ acts retain their
complete badnik loads. Other acts must
load/reserve this art explicitly before using visible rows; hide-art bit `$0400`
requires no handhold bank. Classic/platform-spawned grips remain invisible.

D9 uses seven original FBZ hanging/traversal poses. Tails already has the S3&K
frames `$80-$85/$91`. Sonic's existing 251-frame table uses different IDs and
remains unchanged: while hanging he uses `Map_HangingSonic`, its seven-entry
DPLC table and the compact `art/uncompressed/Sonic hanging.unc` source. They
stream into the ordinary Sonic bank, with a maximum 21 tiles per pose. No new
resident level bank or PLC is required for the player poses. Bounds cover both mapping sets.

`python build_tools/import_hanging_art.py --source /path/to/skdisasm` reproduces
the imported raw art and the two `Sonic hanging.asm` files from skdisasm
`73de97c6b55055bcb8089c1d55d006b02136f163`. The importer selects only the seven
poses, compacts their DPLC runs and applies the common player palette mapping.
After import, the raw pixels and mapping ASM are directly editable sources.

Object control suppresses ordinary player animation while the controller
selects each pose and requests its complete DMA. A full queue keeps the previous
mapping/frame and retries. Entering/leaving the alternate Sonic mapping invalidates
the ordinary per-player art cache; release restores normal mappings and art.
Tails retains his original mapping and separate-tail animation throughout.

### Mode 1 RAM art

With `MegaCDMode1 = 1`, shield, invincibility and normal/lost-ring art is
Nemesis-compressed in ROM. The CD CPU decodes it into Word RAM, then MD copies
the results into its packed work area; see [the decoder boundary](Mega-CD.md#asset-decompression-and-plcs).
`Art_Shield`, `Art_Invincibility` and `Art_Ring` are RAM source addresses in this
configuration; cartridge builds retain their uncompressed ROM sources. The existing
shield DPLCs, resident-star upload and eight-frame ring uploader use those
addresses without changing mappings, frame selection or VRAM banks.

| RAM bytes, end exclusive | Source | Size |
| --- | --- | --- |
| `$FFB40C-$FFB76C` | Shield | `$360` |
| `$FFB76C-$FFBBAC` | Invincibility stars | `$440` |
| `$FFBBAC-$FFBFAC` | Normal/lost rings | `$400` |

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
| `$9BA0-$9DE0` | `$4DD` | Diagonal springs, 18 tiles; GHZ reuses this space for Chopper |
| `$9F20-$A0A0` | `$4F9` | Vertical springs, 12 tiles |
| `$A120-$A2A0` | `$509` | Horizontal springs, 12 tiles |
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
is `$581` (`$B020`), not `$580`. Title cards and large boss explosions start at
`ArtTile_Title_Card` / `ArtTile_BossExplosion = $581`; the 84-tile maximum intro
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

LZ's conveyor uses 32 tiles at `$3ED-$40C`: one shared 16-tile wheel, then
eight tiles each for normal and spiked platforms. This releases `$40D-$43C`
(48 tiles / 1,536 bytes); the hanging handhold/chain bank now occupies its first twelve tiles.
All wheels share one animation clock and DPLC cache;
the first wheel processed in a game frame services the bank. Animation advances
every four active frames; wheel count does not multiply uploads. Switch reversal
changes the shared clock's direction. The common atomic loader reserves both
possible DMA entries; a full queue preserves the cached art and retries on the
next frame. Level entry invalidates the cache. Its six global bytes replace
the obsolete six-byte conveyor group flags; no extra RAM is allocated.

Edit the complete 80-tile source `art/moduled kosinski/LZ conveyor.unc`, then
run `python build_tools/build_lz_conveyor_art.py`. It generates the 32-tile
moduled Kosinski+ seed/resident archive and the four raw wheel frames in
`art/uncompressed/LZ conveyor wheels.unc`. The raw ROM source trades ROM space
and periodic DMA for reduced VRAM. It uses the ordinary DMA queue, with no
decoder or CD wait in an interrupt.
`mappings/sprite/LZ conveyor.asm` aliases wheel frames 0-3 to one mapping;
frames 4/5 are normal/spiked platforms. Normal builds derive their bounds.
LZ's per-act module lists load the resident bank; another zone must load it too.

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
run `python build_tools/build_end_art.py` to regenerate its moduled Kosinski+
archive and the other resident end-of-act banks from their editable `.unc`
sources. Every ROM include retains `even`, including odd-length archives.
The art and `mappings/sprite/Boss Explosion.asm` retain the Sonic 2 final import
from s2disasm `15e9fd52a65318bec3d5e746ce48dba6db6910db`. The seven mapping
frames last 2, 2, 3, 3, 3, 4 and 4 game frames: S3&K's 21-tick lifetime fitted
to the S2 sequence. Ordinary bomb, enemy and capsule explosions retain their
separate art/timing.

The optional advancing wall loads `PLC_ExplosionWall`: the same large art plus
`Kospm_Explosion` relocated to `ArtTile_ExplosionWall_Small = ArtTile_Eggman`
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
`$FE` for Game Over reservation, and `$FF` for invalid. Retirement retains
physical-bank cache state. Act clear preserves both shield banks and their
uploads; Game/Time Over still protects the dead primary's bank from companion stars.

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

Title cards stream scene glyphs at tile `$581`. Results begin at that same
tile with sixteen time/ring bonus digit tiles (`ArtTile_Bonuses`), then stream
their glyphs at `$591` (`ArtTile_Results_Card`). Normal results use at most 74
glyph tiles and stay below animal bank 1; special results use at most 82 and
have no live level animals. Both shield banks remain disjoint from the complete
results allocation. The generator checks these lifetimes at assembly time.
Scene DPLCs avoid loading the whole raw font. `Pal_TitleCardYellow` must
immediately follow `Pal_SonicTails`: the title-card loader copies them as one
two-line palette. Assembly and the native palette-loader check guard that pair. `build_card_art.py` owns their mappings/DPLCs, including
act 4, V/W and the wide W metrics. Its `act_four()` draws the digit into the
existing six-tile (16x24) slot. Small results markers use blue-only shading
from `Title Cards Base.unc`; normal and special results use the same blue
ramp. Special results use the aligned palette contract below.
`build_signpost_art.py` owns the streamed
signpost and monitor arrangement. Tails's portrait is the final four monitor
tiles (`$561-$564`); signpost frames stay below it. Sonic's life art remains
separate and is shared with Sonic monitors. HUD score uses ten-point units,
with maximum display 9,999,990.

Signpost frame `$06` uses Mecha Sonic's original head and upper body in skdisasm
`73de97c6b55055bcb8089c1d55d006b02136f163`, main body frame `$00`.
`art/uncompressed/Mecha Sonic signpost.unc` is the editable 40×32 portrait.
The source crop is X `-12..27`, Y `-32..-5`, including the shoulders.
Place the crop three pixels below the canvas top,
then flip it horizontally to face right. The original pixels, dimensions
are preserved; palette indices follow the shared slot remap. The portrait sits four pixels left and
two pixels above the panel centre to balance the face against its back spines.
The body ends at panel Y `12`, immediately above the lower rim at Y `13`.
`palette/Mecha Sonic.bin` retains the original colors in remapped slots.
The generator fills the existing Eggman panel with Mecha palette slot `$5`
(`$004`) and reconstructs the metallic rim where his moustache cut into it,
then appends that
panel and the head to `Signpost extra.unc`, and rebuilds the packed/editor art,
mappings and DPLCs. Four portrait rectangles omit the five transparent tiles;
the board's inner columns share their lower three tiles. The frame uses
26 resident tiles and 13 hardware sprites, within the existing 26-tile
buffer; no VRAM allocation moves.

The portrait and red board select palette line two (attribute `$2000`);
only the post retains the primary line. The board's red uses Mecha's native
slot `$5`; its rim is adapted to his white/blue-gray metal ramp. No temporary
palette override or extra tiles are needed. Event code can load
`palid_MechaSonic` with `PalLoad2`, then select signpost animation 5 (`.mecha`).
The event owns that line's lifetime and any restoration; ordinary signposts
do not replace a level palette or select this portrait automatically.

The generator also rebuilds the checkerboard/compressed turning panels from
the current finished portraits and the original S3&K gray rim. Sonic uses
frames `$03/$05`; Tails has `$07/$08`; Mecha has `$09/$0A`. Tails's placed and
falling animations use his own pair, and the trap uses only Eggman/Mecha.
No Sonic face is sampled into either of those characters' intermediates.
Mecha's intermediate is 24 pixels wide, with a separate line-two overlay;
the other two keep the original 32-pixel turning silhouette. All eleven
signpost frames fit the existing 26-tile bank. `Signpost.kospm` is the packed
SonLVL archive; the live frame DPLCs read the raw sources directly. Compressing
those runtime sources would require stable decoded RAM across frame uploads.
The trap's thirteen debris
frames reference the same loaded bust tiles, retiring before the reward
sign reuses that bank.

### Mecha Sonic standard fight

`import_mecha_sonic.py --source /path/to/skdisasm --extra-raw /path/to/decoded/Mecha_Sonic_Extra.unc`
imports all 22 body frames, converts the original DPLCs to `Load_DynamicPLC`,
and retains the eight effect mapping entries used by the standard fight.
The decoded extra source is the pinned `Mecha Sonic Extra Art.kosm`; only
its first 22 tiles are resident for jets/electric sparks. Raw body/effect art
and mappings remain directly editable. Resident effects use moduled Kosinski+;
the body remains raw ROM data for frame-by-frame DPLC DMA. The original
Main/Flash palettes retain source colors in remapped slots; hit/defeat offsets follow them. Mecha sounds retain their source data.

During the SMZ2 fight, `$400-$426` is Mecha's 39-tile streamed bank;
`$427-$43C` holds the 22 resident effect tiles. This replaces an inactive
portion of the SMZ object atlas after the last hazards have left the window.
The boss-explosion PLC uses the existing `$581` bank; player/effect, signpost,
terrain, HUD and plane allocations are preserved. The body caches a frame
only after its complete DMA is queued and hides/retries on backpressure.
Palette line two belongs to Mecha until defeat; the act's palette is restored
before the ordinary falling sign is spawned.

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

Runtime player art uses `palette/SonicAndTails.bin`, identical to the owner's
alternate `Sonic and Tails.bin`. Slots 2–5 are orange/skin, 6–9 white through
dark gray, A–C blue, D–F red. The second level row aligns its gray and D–F yellow
ramps; other slots are per-act enemy colors. S&K indices map to
`0 6 A B C F D E 4 3 5 2 7 8 9 1`. `sprite_palette.py` owns offline import
conversions; editable runtime art already uses the new slots. No runtime pixel
conversion is performed. Keep every compressed archive followed by `even`.

Springs retain S3&K mechanisms/geometry, with Sonic CD straight caps from
scddisasm `f8cf3f0af7bf419d18182ba98554f09307ad3cc6` (normal spring tiles 0–3
and 18–21). Both colors share the cap tiles, selecting a palette per piece.
The editable `* spring S3.unc` files now contain 12 vertical, 12 horizontal
and 18 diagonal tiles; `build_spring_art.py` packs them. Their VRAM bases stay
fixed; the 18 released slots remain gaps rather than new global allocations.

`build_special_results_art.py` builds the independent navy/white/gold results
palette, six four-tile emeralds at tile $500 on lines three/four, and current
life-portrait continue badges at the existing mini-character banks. Its ring
selects the second-line gold ramp. `build_card_art.py` generates matching labels
and blue markers. The rotating stage retains its original palette and private
copies of its formerly shared bumper/ring/sparkle banks.
`build_special_sonic_art.py` extracts only its five original-index rolling
poses (80 source tiles) from the editable player art.

## Platform-mounted button art

Mounted buttons reuse the live SMZ switch. In SMZ, its existing atlas/mappings
stay resident. Outside SMZ, `ArtTile_PlatformButton = $419` is an optional eight-tile
bank (`$8320-$8420`, end exclusive), immediately after the twelve handhold tiles.
Only GHZ4 currently loads `Nem_PlatformButton`; other acts need an explicit PLC
entry and a compatible VRAM allocation before using carried buttons. This bank
is not globally free: some other acts use it for badnik art.

`python build_tools/build_platform_button.py` extracts the eight referenced tiles
from the authoritative `SMZ Sprite Atlas.unc` / `SMZ But.bin`, reindexes mappings
and produces the portable uncompressed/Nemesis art and mappings. It retains the
primary palette and both switch frames. Edit the atlas source, then regenerate;
do not patch only the extracted outputs. Springs, spikes and monitors keep their
existing common art banks. Swing artwork remains subject to each act's body-bank PLC.
