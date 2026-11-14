# Importing objects

Use the project's named fields and services rather than transplanting source
offsets. [Objects](Objects.md) owns the SST, loading, dispatch and respawn ABI;
[Sprites and VRAM](Sprites-and-VRAM.md) owns mappings, generated bounds and DPLCs.

## Import checklist

1. Include the implementation/mappings through `md-main.asm` and connect the
   placement ID in `Obj_Index`, or the event that creates it. Dynamic creation
   writes `move.l #ObjectEntry,code(a1)`; initialize the complete pointer.
2. Convert mappings to the ordinary six-byte format before generating bounds.
   Adapt collision masks, animation, allocation and deletion calls. Preserve
   placement ownership and handle partial child-allocation failure.
3. Set mappings, display bounds, art and word priority on every SST initialized,
   including children. Keep collision radii separate. A priority tier is `$80`.
4. Add art to the appropriate [act PLCs](Levels.md#per-act-art), check simultaneous
   VRAM lifetimes, and adapt indexed pixels to the common palette. Static art
   needs no DPLC; streamed art needs the encoding expected by its loader.
5. Add editor properties/previews and, where useful, an act's Debug entry. Use
   [Testing](Testing.md) for source, art, collision and actual-level checks.

## Asset-only boss preparation

CPZ, ARZ, CNZ, MCZ and MTZ currently stop before the controller, PLC and editor
steps above. Their prepared banks, palette roles, source revision and VRAM
budgets are owned by [Sprites and VRAM](Sprites-and-VRAM.md#prepared-sonic-2-boss-weapons).
There are no new playable encounters or placement IDs for them.

Each boss has one `mappings/sprite/ZONE Boss.asm` file. Source weapon frame IDs
are retained; frames containing only the omitted shared pod/pilot are empty.
ARZ keeps weapon and pillar families together. CPZ smoke and MCZ debris have
separate mapping families/art lifetimes in their boss's same mapping file.
MCZ's main family keeps source drill frames 2, 3, 4, 8, 9, 10 and 11 for slot A,
then appends frames 21-27 for slot B; the two byte lookup tables map DPLC phases
to those frames. Its source debris frames 13/20 move to `Map_MCZBoss_Debris`.
CNZ's unused source frame zero is normalized to empty.
Its frame 1 contains the adapted collar alone; appended frame 21 is the rear
topper. Assemble them around `Map_Eggman` and `Map_GHZBoss_Cockpit` using the
[documented layer order](Sprites-and-VRAM.md#prepared-sonic-2-boss-weapons).
MTZ retains S2's frame IDs but uses Sky Sanctuary's six egg/orb poses at 3-8;
its S2 balloon stages, cannon and laser stay in the same family. The sprite
guide owns the shared EHZ gray slots and palette-index conversions.

The future controllers must compose these weapons with the universal pod,
pilot and exhaust. New constructors will reference their actual mapping bounds,
which lets the existing bounds generator discover them without a registry.
Current asset tests inspect every compiled frame directly; they do not stand
in for the deferred arena, collision, palette and lifecycle checks.

## Worked example: EHZ boss

`objects/55 EHZ Boss.asm` adapts Sonic 2 final's boss from s2disasm
`15e9fd52a65318bec3d5e746ce48dba6db6910db`. The controller initializes:

```asm
		move.l	#Map_EHZBoss_Vehicle,obMap(a0)
		move.b	#Map_EHZBoss_Vehicle_height,height_pixels(a0)
		move.b	#sprite_bound($20,Map_EHZBoss_Vehicle_width),width_pixels(a0)
		move.b	#$14,obHeight(a0)	; collision half-height: 20 pixels
		move.w	#$200,obPriority(a0)	; priority tier 4
```

`sprite_bound` emits the larger assembly-time constant. The ordinary build
discovers referenced `Map*_height/width/frames` symbols without registration.
Set bounds on `a1` when initializing an `a1` child. A change of mapping set also
requires suitable bounds, or maxima covering every set the object uses.

| Mapping | Frames | Display half-width | Display half-height |
| --- | ---: | --- | --- |
| `Map_EHZBoss_Vehicle` (S1 hull) | 1 | `$24` | `$18` |
| `Map_EHZBoss_Cockpit` | 11 | `$14` | `$21` |
| `Map_EHZBoss_Ground` | 8 | `$30` | `$10` |
| `Map_BossExplosion` (shared S2 fiery effect) | 7 | `$10` | `$10` |

EHZ uses Sonic 2's controller and ground vehicle with
Sonic 1's complete Eggpod/cockpit. Generated EHZ mappings translate all S1 pod
pixels by Y=-4; the controller and chassis anchors stay unchanged. Display
bounds include transparent tile padding and remain separate from the original
20-pixel collision half-height.
Every boss part uses high VDP sprite priority so foreground flowers cannot
cover the vehicle or pod; the existing queue tiers preserve their internal
depth, including the hull tucked into the chassis.

Eight ordinary SSTs hold the controller/hull, cockpit, car, three wheels,
drill and a persistent rear exhaust. The controller/cockpit link is reciprocal;
children use `objoff_38` for their owner. Initialization still retries until
all seven children can be allocated. The rotor and reload paths are retired.
The rear flame runs on entry, stops while docked, and stays off during a
48-pixel vertical escape lift, leaving 16 clear pixels beneath the pod. The
shared S1 flare/loop then starts as the pod flies up and right. See
[shared boss art](Sprites-and-VRAM.md#shared-eggman-heads-and-exhaust).

The fight retains eight hits, terrain-following wheels, drill separation and
escape. Hit flashing saves and restores the actual palette word through
`EHZBoss_flash_color`; do not substitute a hardcoded restore shade.

## Arena and art lifetime

EHZ2 locks camera X to `$28F0-$2940` and Y to `$690`, including Debug return
and primary Tails. Normal row streaming settles either vertical approach before
spawning. Escape extends the right limit to `$2AB0`; play continues to the
capsule. Origin deltas at `$44/$46` also support the existing MZ placeholder.

| Bytes, end exclusive | Art and current constant |
| --- | --- |
| `$7E00-$8580` | Shared S1 hull/cockpit, `ArtTile_Eggman`, 60 tiles |
| `$8580-$8680` | Shared Eggman/EggRobo head buffer, `ArtTile_EggmanFace`, 8 streamed tiles |
| `$8680-$9680` | Car/wheels/drill, `ArtTile_ArtNem_EHZBoss`, 128 tiles |
| `$A020-$AAC0` | Capsule, `ArtTile_Prison_Capsule`, 85 tiles; loaded at defeat |
| `$AAC0-$ADE0` | Shared S1 exhaust, `ArtTile_Eggman_Exhaust`, 25 tiles |
| `$B020-$BCA0` | Shared S2 fiery boss explosion, `ArtTile_BossExplosion`, 100 tiles |

Boss/capsule phases replace general object art. They preserve both shield
banks; normal explosions and animals replace large-explosion art after escape.
The capsule needs separate body/button placements. Resident water bubbles
overlap the boss weapon region: do not assume that combination can coexist.
See [the shared map](Sprites-and-VRAM.md#shared-level-allocations) before
extending an arena's object set.

`check_ehz_boss.py` validates converted geometry, art indices, compiled PLC
lifetimes and capsule records. Its optional `--s2disasm /path/to/s2disasm`
compares the retained chassis and explosion mappings with a built source checkout. The shared S1-pod check validates its complete hull/cockpit against GHZ.
Shared pilot/exhaust ownership is described in
[Sprites and VRAM](Sprites-and-VRAM.md#shared-eggman-heads-and-exhaust).
The faster shared explosion controller is covered by
[the boss checks](Testing.md#boss-runtime-checks).
Runtime fight checks belong in the
normal arena; a lifecycle fixture alone does not establish boss/capsule behavior.

## EHZ boss palette

The car body retains the primary sprite
palette. Its drill and wheels use row two's existing black/white/gray ramp,
plus slot C (`$A88`) for Sonic 2's extra `$666` metal shade. The complete S1
pod, pilot, orange seat and shared exhaust already use existing colors; their
art and palette entries are unchanged by this adaptation.

The successful constructor saves only row-two slot C through
`EHZBoss_saved_metal_color` and writes `EHZBoss_MetalColor` to
`v_palette+EHZBoss_MetalPaletteOffset` (`$38`). Failed child allocation leaves
all palette words untouched. Offscreen escape cleanup restores the saved word.
Slots 2-5 continue the foreground waterfall cycle; the fixed cloud colors,
HUD, shared grays and all Act-2 background cycling slots are retained. Hit
flashing still independently saves/restores slot 1 through `EHZBoss_flash_color`.
Slot C is unused by visible terrain across both boss-scene camera ranges;
other placements require checking their visible background/foreground first.
Act 1 has no authored boss arena; its palette/rendering check is a staged scene.

The editable source is `art/uncompressed/EHZ boss.unc`, packed normally by
`build_tools/build_end_art.py`. `build_tools/import_ehz_boss.py --source PATH`
can reimport just the 128 chassis/drill/wheel tiles from sonicretro/s2disasm
`4ef457c18fc4902396c43ab06fabc119ac6ecb64`; `--check` verifies reproduction.
It follows each original mapping frame's primary/secondary palette role,
rather than treating the former Mystic Island slot permutation as source art.
Normal builds do not rerun the importer or overwrite hand-edited raw pixels.

The earlier [Mystic-Island-EHZ-palette-WIP branch](https://github.com/Ushupiuck/S2-The-Mystic-island/tree/Mystic-Island-EHZ-palette-WIP)
retains its separate three-gray candidate and archived S2 pod/rotor import.
The obsolete pod/rotor archives have been removed. See the
[boss checks](Testing.md#boss-runtime-checks) for source-color, masked-load,
animated-background and real fight coverage.
