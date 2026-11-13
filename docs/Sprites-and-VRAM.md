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
ROM readers of shared ASM mappings use the generated `Map_Name_frames` count;
the first frame offset can span other slot tables and cannot delimit the table.

Bounds are symmetric maxima of `abs(X)`, `abs(X+width)` and the corresponding
Y values across every piece/frame. Set them alongside mappings on the actual
SST being initialized. `sprite_bound(legacy_minimum,Map_Name_width)` emits the
larger assembly-time constant. Moving composites need group bounds covering
their child motion, not merely one child's geometry. See [Importing objects](Importing-objects.md).

`Render_Sprites` consumes initialized bounds and routine pointers, with ordinary
and composite paths plus inline HUD/ring drawing. It clips composite children
separately. Ordinary objects with render bit 4 also clip their mapping pieces,
using the same four flip paths and queue continuation. Tall waterfalls therefore
do not spend SAT entries on pieces outside the viewport. SAT links are initialized on clear; the renderer repairs the previous
terminator and writes a new hidden terminator, retaining the 80-sprite limit.
The S1 stage appends to the same link chain. There is no star-specific renderer path.

The VBlank wait latch has three states: `$00` while foreground code runs, `$01`
when `WaitForVint` requests work, and `$FF` once VBlank admits that request.
Only `$01` starts the full screen handler. A second VBlank arriving while the
first handler still runs must count lag and return without touching the VDP;
re-entering the handler can exhaust the stack and overwrite the end of the block
table. Ordinary foreground lag (`$00`) retains its water-palette refresh path.
The retired Twizzler investigation exposed this distinction. Current plane
and CD tests are listed under [runtime checks](Testing.md#runtime-checks).

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

### Monitor contents

`build_monitor_art.py` owns monitor mappings, the body/life seed archives and
four-tile icon DPLCs. Edit `art/nemesis/Monitor and contents.unc`, then run the
generator (or `--check`). The 60-tile editable/editor master keeps intact tiles
0-15, broken tiles 16-23, eight four-tile content images in type order, and the
permanent Tails portrait at 56-59. The separate static icon is removed; the
intact box already contains that pattern. Regular-shield pixels come from
Sonic 2's frame-7 `$2C-$2F` icon (s2disasm commit
`4c5dc02b3eea186c3f80a020447b206343f30c0a`), adapted through `PLAYER_FROM_S1`; the three
existing elemental images remain separate. `build_signpost_art.py` delegates
monitor generation rather than modifying its layout independently.

| Type | Content | Reward |
| --- | --- | --- |
| `$0` | Eggman | Hurt the actual collector |
| `$1` | Rings | Ten rings |
| `$2` | Regular shield | Existing shared shield behavior |
| `$3` | Water shield | Reserved art/type; ability not implemented |
| `$4` | Fire shield | Reserved art/type; ability not implemented |
| `$5` | Electric shield | Reserved art/type; ability not implemented |
| `$6` | Speed shoes | Existing shared speed-shoe behavior |
| `$7` | Invincibility | Existing shared star/invincibility behavior |
| `$8` | Sonic double life | Two lives; permanent HUD portrait |
| `$9` | Tails extra life | One life; permanent tile `$561` portrait |

Both life images load on every level entry and bypass the four content slots.
Tails has not moved after the HUD. The other eight kinds share four physical
16x16 slots, including rising rewards and Debug previews. `MonitorArt_Select`
reuses a loaded kind and pins slots used in the current or previous object
pass. Offscreen loaded boxes do not occupy visible slots. Misses use the common
atomic DPLC loader; a full queue keeps the old tag and retries. Four tag bytes
and four timestamp words use twelve bytes of MD RAM; no object-pool scan or
per-monitor tile buffer is needed. The resident footprint falls from 60 to 44
tiles, reclaiming 16 tiles/512 bytes before the permanent Tails image.

Visible authored scenes must fit four distinct non-life kinds, including their
moving payloads. Cache pressure keeps the baked static on a box and defers a
floating icon rather than replacing another displayed kind. The editor reads
the complete master through `Monitor.bin`. Runtime `Monitor.asm` contains four
12-entry slot tables sharing twelve frame records, including the body, broken
base, both life icons and repeated content mappings. Its 252 bytes replace the
four former 180-byte mapping banks; the renderer uses the same pointer lookup.
The single actual DPLC table remains `mappings/spriteDPLC/Monitor.bin` (48 bytes). The full master archives remain editor assets and are
not linked into the ROM. The usual frame convention remains type+1, with zero
for the bare box and 11 for its broken base. The signpost still replaces the
first 26 tiles only during its separate end-of-act lifetime.

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

Shield, invincibility and normal/lost-ring art is
Nemesis-compressed in ROM. The CD CPU decodes it into Word RAM, then MD copies
the results into its packed work area; see [the decoder boundary](Mega-CD.md#asset-decompression-and-plcs).
`Art_Shield`, `Art_Invincibility` and `Art_Ring` name RAM source addresses.
The editable source art remains available for regeneration. The existing shield
DPLCs, resident-star upload and eight-frame ring uploader use those
addresses without changing mappings, frame selection or VRAM banks.

| RAM bytes, end exclusive | Source | Size |
| --- | --- | --- |
| `$FFB3FE-$FFB75E` | Shield | `$360` |
| `$FFB75E-$FFBB9E` | Invincibility stars | `$440` |
| `$FFBB9E-$FFBF9E` | Normal/lost rings | `$400` |

The cache occupies `$BA0` bytes after the CD ring event queue. `LoadPlayerEffectArt`
decompresses all three after level clears/PLCs and before `InitRingFrame`;
it also runs on death restarts and returns from other scenes. The rotating S1
stage loads its ring source independently with `LoadRingArt` before its first
upload immediately after the stage emerald sheet; it needs no shield/star source. Its palette-remapped results
ring remains a separate ROM asset. Decompression runs outside VBlank.

Keep the editable files in `art/uncompressed/`; SonLVL continues reading the
raw ring. After editing these sources, run
`python build_tools/build_player_effect_art.py`, then use `--check` to verify
the committed packed copies. The old `art/nemesis/Shield.nem` is unrelated
to this dynamic art and is preserved.

## Shared level allocations

These are runtime VRAM lifetimes, not a finalized cartridge-file placement
plan. ROM ordering/banking remains provisional. Add variants to the existing
editable art sheet and mapping family when they belong to the same object;
a new palette variant alone does not justify separate files and PLC entries.


These apply during ordinary level play. Zone-specific terrain/badnik and boss
phases can have different lifetimes; the [special-stage map](Special-stage.md#vram)
is not a source of free level VRAM.

| Bytes, end exclusive | Tile base | Use |
| --- | --- | --- |
| `$0020-$0220` | `$001` | Streamed water surface: 16 tiles immediately after transparent tile zero |
| `$9BA0-$9D20` | `$4DD` | Vertical springs, 12 tiles |
| `$9D20-$9EA0` | `$4E9` | Horizontal springs, 12 tiles |
| `$9EA0-$A0E0` | `$4F5` | Diagonal springs, 18 tiles |
| `$A0E0-$A160` | `$507` | Shared static spring support, four tiles |
| `$A160-$A360` | `$50B` | Floor/side spikes, 16 tiles |
| `$A360-$A520` | `$51B` | Free after packing springs and adding the support, 14 tiles |
| `$A520-$A820` | `$529` | Resident intact/broken monitor bodies, 24 tiles |
| `$A820-$AA20` | `$541` | Four shared monitor-content DPLC slots, 16 tiles |
| `$AA20-$AC20` | `$551` | Reclaimed from resident monitor contents, 16 tiles |
| `$AC20-$ACA0` | `$561` | Permanent Tails life portrait, four tiles |
| `$ACA0-$ADE0` | `$565` | Checkpoint, 10 tiles |
| `$ADE0-$B020` | `$56F` | Auxiliary shield, 18 tiles |
| `$B040-$BC00` | `$582` | Normal/shared fiery explosion art, 94 tiles |
| `$BC00-$BE40` | `$5E0` | Animal bank 1, 18 tiles |
| `$BE40-$C000` | `$5F2` | Animal bank 2, 14 tiles |
| `$C000-$D000` | `$600` | Foreground plane, 64 by 32 entries |
| `$D000-$D400` | `$680` | Sonic body allocation |
| `$D400`, `$D600` | `$6A0`, `$6B0` | Tails body/tail upload bases; see overlap rule below |
| `$D720-$D8A0` | `$6B9` | Ring, lost ring and sparkles |
| `$D8A0-$DCC0` | `$6C5` | Packed HUD, debug glyphs and counters, 33 tiles |
| `$DCC0-$DE60` | `$6E6` | Free, 13 tiles |
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
complete 85-tile bank at `$43D-$491`; Chopper follows at `$492-$4B1`. They
use the former Ballhog reservation, clear of the shared spring atlas. Wall caps reuse
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

### Shared Eggman heads and exhaust

GHZ and EHZ share the complete Sonic 1
Eggpod: its hull, cockpit, seven head poses and full escape flame. EHZ keeps
Sonic 2's car/wheels/drill. Its pod/cockpit mappings draw the S1 pixels four
pixels higher, while the controller, chassis and collision anchors keep their
original positions. That hides the deeper S1 underside inside the chassis in
both directions; moving the whole boss upward would also move its children. EHZ
sets high VDP sprite priority on the pod, pilot, chassis, wheels, drill and
flame to keep them above foreground flowers. Their existing sprite-queue tiers
still control their order against one another.

The shared editable banks are `art/uncompressed/Old Eggpod.unc` (60 tiles),
`Eggman face.unc` (40) and `Boss exhaust.unc` (25). They start at `$3F0`, `$43F`
and `$556`. The cockpit, face and flame use the primary sprite palette; metal
pieces select the existing second row. Profile lenses retain the selected
`C/B` to `B/A` blue remap. Exposed S1 seat padding uses `4/3/2` in place of
`A/B/C`; both the hull's backrest and cockpit rim change, with the original
shading and shapes preserved.

`python build_tools/build_end_art.py` packs the editable banks. The explicit
`build_boss_shared_art.py --rom PRE_SPLIT_ROM --listing PRE_SPLIT_LISTING --write`
migration reads pre-sharing revision `21c233e`, extracts the S1 face contours
and emits the GHZ mappings plus EHZ's whole-pod drawing offset. Per-pose 8x8
grid phases reuse tiles without changing indexed pixels. Declared allocation
boundaries are checked before writing. Normal builds do not re-import old art.

The retired S2 cockpit/rotor files, their mappings and the old full S1 bank
have been removed. The migration emits only the shared S1 hull/head banks
and their mappings. EHZ's drawing offset references the same tiles as GHZ.
The original pre-split source remains available through Git history.
Final Zone keeps its separate piston assembly and damaged cockpit as moduled
Kosinski+ banks, `Kospm_FzBoss` and `Kospm_FzEggman`. They are reserved for the
planned fight and have no active load cue. `build_end_art.py` repacks the
cockpit from its Nemesis source. That source already uses the earlier palette
conversion, so tiles `$20-$39` translate from those slots to the current player
line for both poses. Their `$3/$4/$F` indices become `$4/$F/$A`. The legs and
lower metal retain their existing line-two indices.

Both bosses share their expression/exhaust scripts. In GHZ, S1's hit/normal
animation plays during explosions, the burnt frame during recovery, and the
panic animation during getaway. In EHZ, Eggman holds the burnt frame from
the final hit through the unpowered hop. Ignition starts his panic animation.
EHZ retains one exhaust
SST through approach, driving and escape; there is no rotor or reload
allocation. Its nozzle is at mirrored X=34, Y=-4. Entry uses the small flame
on a straight diagonal, which stops at docking. After defeat it detaches from
the chassis and rises 48 pixels with the flame off, leaving 16 pixels between
its visible underside and the chassis top. It then ignites S1's
startup flare and leaves at four pixels right and a quarter pixel up per
update. The large flare plays once before the small flame loop.

Child words `BossChild_OffsetX/Y` at `$30/$32` hold attachment offsets; X mirrors
with the parent. Each caller validates its parent's code and main routine.
The arena stays in level mode through escape and the real capsule. See
[the import guide](Importing-objects.md#arena-and-art-lifetime) for live ranges.

### Boss explosions

GHZ and EHZ share Sonic 2 final's seven-frame fiery boss explosion through
both boss PLCs at `ArtTile_BossExplosion = $581`. Its 100 tiles occupy
`$B020-$BCA0`, replacing ordinary explosion art and the first five tiles of
animal bank 1 during the fight. Keep that bank live until every burst finishes.
GHZ reloads ordinary explosions and animals during recovery; EHZ does so after
its escape delay, before the capsule opens. GHZ queues bursts that overlap
the cockpit behind it so the 320-pixel sprite limit cannot clip the face
in a dense burst. Lower bursts still draw over the hull. The controller and parent SST
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

`art/nemesis/Game Over.nem` is the editable 34-tile GAME/TIME/OVER sheet.
Both OVER mappings share the same V quartet (tiles 24-27). Its white/blue
lettering uses slots `6/A/B/C`; the edge uses dark blue `C`, never red `F`.

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
tile with nine time/ring bonus digit tiles (`ArtTile_Bonuses`: five time,
four ring), then stream glyphs at `$58A` (`ArtTile_Results_Card`). Normal results
use at most 70 glyph tiles and stay below animal bank 1; special results use
at most 90 and
have no live level animals. Both shield banks remain disjoint from the complete
results allocation. The generator checks these lifetimes at assembly time.
Scene DPLCs avoid loading the whole raw font. `Pal_TitleCardYellow` must
immediately follow `Pal_SonicTails`: the title-card loader copies them as one
two-line palette. Assembly and the native palette-loader check guard that pair. `build_card_art.py` owns their mappings/DPLCs, including
act 4, V/W and the wide W metrics. Its `act_four()` draws the digit into the
existing six-tile (16x24) slot. Small results markers preserve the blue fill
and dark-blue edge from `Title Cards Base.unc`, with the outer black pixels
removed. Both screens share that treatment and the tightened final S in BONUS.
Special results use the aligned palette contract below. Every heading block
is centered on the regular oval at screen `(160,60)`. Single-line SPECIAL
STAGE and CHARACTER GOT THEM ALL start at Y=52; the partial-success and
Super-announcement two-line blocks start at Y=40/64, with eight clear pixels
between their 16-pixel rows. The oval's bottom stays clear of the emerald grid.
The all-seven heading has two independent groups: CHARACTER GOT enters from
the left, THEM ALL from the right. One offset brings both to their assembled
positions together.
The ring-bonus controller waits for the completed tally, then pauses for
120 updates. If a Continue was earned, it plays that celebration for 270
updates before starting the heading departure. This follows the S3&K
post-tally sequence in `sonic3k.asm` (`loc_2E4C4` through `loc_2E5E0`) at
`73de97c6b55055bcb8089c1d55d006b02136f163`. The groups leave towards their
respective sides at 32 pixels per update. Once both have cleared the screen,
CHARACTER CAN NOW BE enters from the left and SUPER CHARACTER from the
right at 16 pixels per update.
Their rows are Y=40/64, centering the complete two-line message on the same
stationary oval. The new announcement gets 240 updates from spawning before
the results can exit, matching S3&K. The extra right group uses reserved slot
21 (`v_bsresright`), shared with inactive normal results; the five existing
bonus-result slots keep
their roles. The left owner controls both groups' positions and mapping frames.
Both groups use piece clipping to prevent VDP X wrapping at the screen edges.
Both messages share the resident all-seven bank, so the change needs no upload.
This is the announcement UI; Super transformation gameplay remains unfinished.
CONTINUE pulls its INUE mapping pieces two pixels left, leaving one clear pixel
between T and I. The existing shared glyph art and 18-tile word bank stay in use.

Normal and special results share `Card_InitResultSprite`, an eight-byte-record
constructor adapted from S3&K's `sub_2E802`. Their editable configuration tables
and classic movement remain in the owning object files. Title cards already
use table-driven initialization and per-scene DPLCs; they keep those compact
scene banks rather than S2/S3's larger title-card artwork. The normal tally
already combines both bonus deltas into one score update, as S3&K does.

Finishing at any frame displaying exactly 9:59 awards 100,000 time-bonus
points, following `Obj_LevelResultsInit` in skdisasm
`73de97c6b55055bcb8089c1d55d006b02136f163`. Other finish times retain this
project's existing bonus table. The counter holds 10,000 ten-point units;
its fifth streamed digit plus the resident trailing zero display all six
figures. The ordinary tally awards the full amount, including score lives.
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
and retains the eight standard effect mapping entries plus a compact copy of
the rematch's small energy ball (original extra mapping `$15`, now frame 8).
The decoded extra source is the pinned `Mecha Sonic Extra Art.kosm`; only
its first 22 tiles are resident for jets/electric sparks; original tiles
`$75-$76` are appended as local tiles 22/23 for the energy ball. Raw body/effect art
and mappings remain directly editable. Resident effects use moduled Kosinski+;
the body remains raw ROM data for frame-by-frame DPLC DMA. The original
Main/Flash palettes retain source colors in remapped slots; hit/defeat offsets follow them. Mecha sounds retain their source data.

During the SMZ2 fight, `$400-$426` is Mecha's 39-tile streamed bank;
`$427-$43E` holds the 24 resident effect tiles. This replaces an inactive
portion of the SMZ object atlas after the last hazards have left the window.
The boss-explosion PLC uses the existing `$581` bank; player/effect, signpost,
terrain, HUD and plane allocations are preserved. The body caches a frame
only after its complete DMA is queued and hides/retries on backpressure.
Palette line two belongs to Mecha through defeat and results. The collapsed
body keeps its electrical palette/sparks until the next level loads.
The entry dash uses floor radius `$1F`: frame 2 has the same 32-pixel foot
baseline as the standing frames, despite its shorter upper silhouette.

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
The coordinate tiles overlay the normal score bank; placement/frame-cycle
switching restores the score, timer and ring counters. Menu/error font palette
indices remain unchanged.

`python build_tools/build_hud_art.py` rebuilds SCORE/TIME/RINGS and the 8x8
score, timer, ring and results-bonus digit cells from that same Ristar font
(also used by the small CONTINUE label). Labels retain yellow/red blinking;
white counters have a black one-pixel shadow. The timer colon is an authored
pair of square dots matching the font's stroke weight. The resident label bank
contains only `SCORTIMENG` (ten unique letters); short shared runs limit sprite
count while avoiding duplicate letters. Normal counters occupy fourteen tiles;
Debug needs nine extra tiles before the seven score cells, making 33 reserved
tiles instead of 46. The freed `$DCC0-$DE60` range is unused by HUD uploads and
mappings. All life-HUD sources and pieces retain their original cells.
The generator also owns `obj21.asm` and the four-tile private BONU label in
`SS Results Labels.unc`; run `build_card_art.py` afterwards. Both results
screens share the resident SCORE/TIME/RINGS letters, use the nine bonus digit
tiles described above, and select their own glyph/marker banks. Large title/result headings
retain their separate card font. The special-results ring copy and animation
are removed; rotating-stage rings keep their original assets and loader.

## Palette adaptation

Runtime player art uses `palette/SonicAndTails.bin`, identical to the owner's
alternate `Sonic and Tails.bin`. Slots 2–5 are orange/skin, 6–9 white through
dark gray, A–C blue, D–F red. The second level row aligns its gray and D–F yellow
ramps; other slots are per-act enemy colors. S&K indices map to
`0 6 A B C F D E 4 3 5 2 7 8 9 1`. `sprite_palette.py` owns offline import
conversions; editable runtime art already uses the new slots. No runtime pixel
conversion is performed. Keep every compressed archive followed by `even`.

The EHZ boss's drill/wheels use a one-word masked row-two load; see the
[boss palette contract](Importing-objects.md#ehz-boss-palette). The former
three-gray WIP remains separate.

The EHZ waterfall object keeps its 24-tile bank at `$400-$417` and all six
mapping frames. Its editable `art/uncompressed/EHZ Waterfall.unc` uses P1
indices `2-5` for the four cyans and `6` for white. Run
`python build_tools/build_ehz_waterfall_art.py` to pack it. Waterfalls use
priority zero so the flow still overlays characters. Render bit 4 clips
offscreen pieces before they consume SAT entries. The mappings themselves remain intact.

Springs retain S3&K mechanisms/geometry, with Sonic CD straight caps from
scddisasm `f8cf3f0af7bf419d18182ba98554f09307ad3cc6` (normal spring tiles 0–3
and 18–21). Both colors share the cap tiles, selecting a palette per piece.
The editable `art/uncompressed/Springs.unc` is one contiguous atlas: 12 vertical,
12 horizontal and 18 diagonal tiles, then four static support tiles.
`build_spring_art.py` packs it as `Springs.nem`; all act PLCs load that single
archive at `ArtTile_Springs`. Runtime objects, Debug and SonLVL use the same
base, with orientation offsets in the existing mapping family. Spikes start
immediately after the support. Monitors keep their existing `$529` base.
All three cap shapes use the shared red/yellow ramp `D-F` with white at `6`:
`D` is brightest, `E` is the middle shade and `F` is darkest. Gray `7-9` belongs
to their metal mechanisms. The diagonal face now maps both original S3&K orange highlights to bright `D`;
the former conversion made the brighter orange darker than the neighboring
medium orange. Its 34 corrected pixels retain the existing silhouette and
white marker. The diagonal cap's local tile `7` remains the
empty lower-left corner of its final 16x16 sprite piece; deleting it would
require another hardware sprite for the three remaining quadrants.

The support uses diagonal Sonic CD tiles `1,0,blank,2` in one column-major
16x16 sprite. Its black/white/gray indices already match the shared player
row. Every diagonal pose adds this independent, static VDP piece behind the
moving plate/coil. Its unflipped mapping is `(-18,-2)`, aligning its
longitudinal center with the existing S3&K coil; the former `(-16,0)` displaced
it two pixels along the plate. The down-facing pose mirrors that position
vertically. Both colors and all flips reuse the same four resident tiles. It has no duplicate pose art and needs no extra object slot. The empty
corner is part of that rectangular sprite, not padding between art banks.

The shared seesaw uses Sonic 1's full-height artwork from s1disasm
`2c51d46a0b0682133834db2093292d41da872ecf`: 44 plank tiles followed by both
nine-tile spikeball frames. `art/uncompressed/Seesaw.unc` is the editable
62-tile atlas; `build_seesaw_art.py` packs `Seesaw.nem`. Its optional `--source`
import also converts the two original S1 mapping families. Ordinary builds
do not overwrite the editable art/mappings. `--check` verifies the packed copy.
There are no interleaved two-player rows. The plank's original blue indices
`2-5` deliberately use the orange/skin ramp, including its central ball.
White/grays remain at `6-9`; the spikeball's skin/red pixels use the shared
skin and `D-F` red slots. All pieces use the primary player palette.

Plank mappings are translated down 16 pixels to retain the existing object's
collision origin and spikeball offsets. The physical slope remains 96 pixels
wide; its width is independent of the original art's three-pixel overhang.
The complete atlas occupies EHZ `$46C-$4A9` or HTZ `$420-$45D`, clear of terrain,
the HTZ lift and bridge, and the common spring bank. Every act PLC, Debug and
SonLVL consumer selects the corresponding bank and full-height mappings.

`build_special_results_art.py` builds the independent navy/white/gold results
palette, seven four-tile emeralds at tiles `$500-$51B` on lines three/four, and the
original two-frame 16x24 continue sprites at the existing mini-character banks.
Blue uses P2 slots `2/3/4` (`$822/$C42/$E66`) plus white `6`. Its former light
slot `5` and unused slots `1/7` provide cyan (`$A60/$EC4/$EEA`); cyan shares
blue’s dark outline `2` and white `6`. Both sprites select the same P2 row.
Frames `0-5` retain the original gem IDs and `6` is cyan. The seven-frame
results object skips drawing on its hidden blink phase; see the
[special-stage guide](Special-stage.md#emerald-items) for outcome and layout.
Stage emeralds remain in the existing `Bonus Stage Emeralds.nem` sheet and
its original mapping file; the results generator does not rebuild those
editable stage assets. See the [stage guide](Special-stage.md#emerald-items).
The retained Mini Sonic/Tails compressed sources supply the poses; Sonic's
old CONTINUE tiles are replaced by lettering from the shared Ristar font.
Only the lettering pieces select line two's gold slot D; the portrait pieces
keep the player palette, including their two distinct animation poses.
Mini Sonic is the unchanged S1 Continue Screen Stuff sheet. Its source slot E
is dark red and maps to shared slot F; it must not use Tails' S2 conversion,
where E/F are orange. `PLAYER_FROM_S1` owns that source contract. Both blue
ramps share the three available player blues. The packed results copy is
regenerated from the retained sources; both Sonic poses keep their third red.
Its ring
selects the second-line gold ramp. `build_card_art.py` generates matching labels
and blue markers. The rotating stage retains its palette positions and private
copies of its formerly shared bumper/ring/sparkle banks.
`build_special_sonic_art.py` extracts five original-index Sonic rolling poses
(80 source tiles), three Tails rolling poses (48 source tiles), and sixteen
directional tail poses (96 source tiles) from the editable player art/DPLCs.
Tails copies are adapted offline to its shared warm ramp. Their compact
DPLCs retain the original frame indices, with empty rows outside those sets.
See the [stage allocations and palette limits](Special-stage.md).

### Fire art

`art/uncompressed/Fireballs.unc` contains S1's complete 44-tile fireball sheet.
`mappings/sprite/Fireballs.asm` retains its two flight poses and impact pose in
each direction. EHZ and HTZ load the shared Moduled Kosinski+ sheet at `$4B0`;
both the maker and individual fireballs are available in their Debug lists
and editor pickers.
SMZ does not load this bank. [Objects](Objects.md#sonic-1-fireballs) owns the
spawner/flight behavior; existing level layouts do not add new hazards.

`art/uncompressed/Fireball maker.unc` is the right-facing SLZ launcher master,
from s1disasm `2c51d46a`'s `SLZ Cannon.nem`. Its original greens use the shared
blue ramp and its trim uses the gray ramp on the first player line. The packer
rotates it for the upward version and reuses mirrored corners: 14 unique tiles,
three mapping pieces per orientation. Placement flips supply left/down facings.
The Moduled Kosinski+ bank occupies `$51B-$528`, between shared spikes and monitors,
and loads in every EHZ/HTZ act beside the fireball bank. It is decorative;
the emitted projectile owns harmful collision. Editing the master must preserve
the mirrored corners checked by the packer or require a revised allocation.

`art/uncompressed/SBZ Flaming Pipe.unc` owns its three flame rectangles and
two pipe ends. The first 20 tiles use the first player line. Slots `D/E/F`
supply the three reds, `2/3/4/5` the warm ramp and `6` white. Colors are baked
into the art; the player palette is unchanged. The eight hardware tiles retain
stage line three. All 22 packed SMZ frames retain their geometry and flips.

The shading reference is skdisasm `73de97c6b55055bcb8089c1d55d006b02136f163`:
LRZ's fireball, Act 2 flamethrower and Fireworm segment flames use a pale core
with warmer rings toward the edge. S1's silhouettes, shadow regions and
transparent pixels come from s1disasm `2c51d46a`'s Fireballs/Flamethrower art.
The four warm player slots expand the original yellow cores. Bright red remains
in broad outer tongues (two pixels for fireballs, three for the longer pipe
flame), dark/medium reds stay within the outer two pixels, and original interior
shadow pixels progress through bright red into the warm ramp. White stays
inside the hottest cores; deep shadow flecks must not puncture it.

Run `python build_tools/build_fire_art.py` after editing a fire/launcher sheet. It packs
the fireballs, rotated launcher and pipe, updates the mapped atlas rectangles and repacks the
atlas without moving its tiles. It rejects changes that would affect another
SMZ object's shared rectangle. `--import-s1 /path/to/s1disasm` resets the editable
sheets from the original silhouettes and the documented shading conversion.
The SMZ importer preserves the edited pipe sheet; a full atlas repack consumes
its generated Nemesis bank. `pack_scrap_sprites.py --check` verifies all 133
packed frames without replacing outputs and uses a host Nemesis decoder.

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
