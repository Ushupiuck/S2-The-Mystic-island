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

## Worked example: EHZ boss

`objects/55 EHZ Boss.asm` adapts Sonic 2 final's boss from s2disasm
`15e9fd52a65318bec3d5e746ce48dba6db6910db`. The controller initializes:

```asm
        move.l  #Map_EHZBoss_Vehicle,obMap(a0)
        move.b  #Map_EHZBoss_Vehicle_height,height_pixels(a0)
        move.b  #sprite_bound($20,Map_EHZBoss_Vehicle_width),width_pixels(a0)
        move.b  #$14,obHeight(a0)     ; collision half-height: 20 pixels
        move.w  #$200,obPriority(a0) ; priority tier 4
```

`sprite_bound` emits the larger assembly-time constant. The ordinary build
discovers referenced `Map*_height/width/frames` symbols without registration.
Set bounds on `a1` when initializing an `a1` child. A change of mapping set also
requires suitable bounds, or maxima covering every set the object uses.

| Mapping | Frames | Display half-width | Display half-height |
| --- | ---: | --- | --- |
| `Map_EHZBoss_Vehicle` | 7 | `$20` | `$28` |
| `Map_EHZBoss_Ground` | 8 | `$30` | `$10` |
| `Map_EHZBoss_Propeller` | 7 | `$52` | `$28` |
| `Map_BossExplosion` | 7 | `$10` | `$10` |

The propeller's rightmost piece begins at X=50 and is 32 pixels wide, requiring
82 pixels (`$52`), beyond the old `$40` minimum. The ship's display half-height
of 40 pixels is independent of its 20-pixel collision radius.

The boss uses eight linked ordinary SSTs: ship/controller, cockpit, car, three
wheels, drill and propeller. `objoff_38` links children to their parent; the
controller/cockpit link is reciprocal. Initialization retries until all seven
children are available. Each child queues separately through `DisplaySprite`.
Packed composites instead need bounds covering child motion and the record
layout in [Objects](Objects.md#composites-and-other-records).

The fight retains eight hits, terrain-following wheels, drill separation and
escape. Hit flashing saves and restores the actual palette word through
`EHZBoss_flash_color`; do not substitute a hardcoded restore shade.

## Arena and art lifetime

EHZ2 locks camera X to `$28F0-$2940` and Y to `$390`, including Debug return
and primary Tails. Normal row streaming settles either vertical approach before
spawning. Escape extends the right limit to `$2AB0`; play continues to the
capsule. Origin deltas at `$44/$46` also support the existing MZ placeholder.

| Bytes, end exclusive | Art and current constant |
| --- | --- |
| `$7400-$8000` | Ship, `ArtTile_ArtNem_Eggpod_1`, 96 tiles |
| `$8000-$9000` | Car/wheels/drill, `ArtTile_ArtNem_EHZBoss`, 128 tiles |
| `$9000-$9280` | Propeller, `ArtTile_ArtNem_EggChoppers`, 20 tiles |
| `$94E0-$9F80` | Capsule, `ArtTile_Prison_Capsule`, 85 tiles; loaded at defeat |
| `$B020-$BCA0` | Large explosion, `ArtTile_BossExplosion`, 100 tiles |

Boss/capsule phases replace general object art. They preserve both shield
banks; normal explosions and animals replace large-explosion art after escape.
The capsule needs separate body/button placements. Resident water bubbles
overlap the boss weapon region: do not assume that combination can coexist.
See [the shared map](Sprites-and-VRAM.md#shared-level-allocations) before
extending an arena's object set.

`check_ehz_boss.py` validates converted geometry, art indices, compiled PLC
lifetimes and capsule records. Its optional `--s2disasm /path/to/s2disasm`
compares with a built source checkout. Runtime fight checks belong in the
normal arena; a lifecycle fixture alone does not establish boss/capsule behavior.
