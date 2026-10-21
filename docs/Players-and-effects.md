# Players, solids and effects

Sonic's movement is adapted from S3&K, using the project's collision/input
services and the shared SST. Tails supports flight, swimming and carrying
Sonic. Imported player/effect art follows the palette and bank ownership in
[Sprites and VRAM](Sprites-and-VRAM.md); this guide owns gameplay behavior.
Super forms, Insta-Shield and the unfinished homing hook are not complete
features. The old rolling-jump steering lock was deliberately removed.

## Tails and companion control

Manual controller 2 input takes precedence over following AI for ten seconds.
Ordinary offscreen recovery retains its five-second timeout. Flight energy
uses the existing `(8*60)/2` half-frame budget. Carrying Sonic uses frames
`$D5-$D9`, a 28-pixel Y offset and an initial center-pose upload; S3's frame
numbers would select unrelated poses here.

Initialization updates body/tail together and retains position history. Flying
attacks use the S3&K upward sector and angle rounding; swimming and other sectors
retain ordinary collision responses. Large bubbles refill the touching actor's
air; only primary-player recovery changes music.

Tail copying/animation runs after other objects, so transports and moving
solids cannot leave it one carrier update behind the body. Body and tail share
the player's `tails_hidden` decision. Roll/jump anchoring derives the radius
difference from the character's defaults: Tails's difference is one pixel.
The common camera compensation uses those radii too, avoiding rolling camera
bob in every level. Wrapped camera distances are signed 11-bit differences.

Companion approach targets use a standing Sonic's live platform-relative X/Y,
including bridge sag. An established approach steers during the jump and stops
within eight horizontal pixels. Tails closes large gaps before jumping; within
the 64-pixel jump window, a grounded Tails can jump immediately toward a higher
object without waiting for the global jump clock. Terrain-only climbs retain
normal timing. A deliberate lead jump preserves an established approach;
falling cancels it. Airborne Sonic cannot create an approach from nothing.

Unreachable ordinary platforms keep ordinary jump attempts. The approach word
is steering state, not a timeout that promotes a target to flight. Grounded
zero-momentum locks and real slope slips use CPU spindash recovery. A moving
spring landing on flat ground retains normal steering. When sharing a carrier
with nearly stationary Sonic, the target is clamped inside it and stale
horizontal input is discarded, preventing Tails from chasing a toe off its edge.

Local collapse flight requires an actually fragmenting retained ledge/floor,
Sonic running or deliberately jumping away, horizontal separation within
128 pixels and Sonic at least 24 pixels above Tails. A descending deliberate
jump still qualifies; merely falling does not. A touch countdown alone does
not qualify. The code validates one retained object's full pointer/state,
without scanning the pool. Controller 2 still wins. Reaching grounded Sonic
resumes following; a lead fall ends the tagged flight.

Local pursuit is bounded to six horizontal and one vertical pixel per update.
Ordinary respawn flight uses its original horizontal pursuit and vertical
`min(abs(dy)/16+1,6)`, without overshoot. Takeoff clears standing/rider state;
negative `obControl` prevents catch-up flight becoming a platform rider.
Bridge landing uses the selected log's depressed height.

Focused HPZ/SMZ and collapse fixtures exist in [Testing](Testing.md). Historical
full-route samples predate the revised AI; complete revised-AI low/normal/high
route outcomes remain unmeasured. Do not treat old death counts as current results.

## Monitors and shared solids

Monitors support either actor. Standing relationships are valid only when the
player's object index and the monitor's rider flag agree. Stale ownership must
not snap a player to a distant monitor. A held spindash remains solid; grounded
rolling attacks reach the break path before the rising-underneath test, since
a grounded slope can have negative Y velocity. Airborne underside contacts
retain their separate behavior. Breaking detaches both riders and remembers
the actual collector, including for harmful rewards.

Object status rider bits 3/4 represent primary/companion; the on-object flag on
either player is bit 3. Capsule detachment clears bit 3 on both players and sets
their airborne state, preserving subsequent terrain following.

The double-life monitor resolves its portrait through
`ArtTile_Lives_Counter-ArtTile_Monitor` (`$2AD`), also reflected in SonLVL.
Sonic's life/monitor art uses the corrected blue and two red shades. Both live
actors can collect hidden end bonuses, awarding the shared score once.

The rare solo-Tails/backtracking monitor failure was not fully reproduced in
its exact original route. Ownership/contact regressions cover specific cases;
they do not establish that every rare monitor failure is solved.

Grounded ducking uses the roll/spindash diameter for solid-object head clearance
(28 pixels for Sonic), preserving stored radii, feet and support height.
Standing/airborne contacts retain ordinary bounds; genuinely insufficient gaps
still crush. Closed trapdoors try top landing before full solidity. Their first
closed frame resolves shallow foot overlap across the physical 24-pixel body;
closed sides and rising underside contacts remain solid. Horizontal springs
use 15 pixels for landing and 16 for standing, matching their visible top.

Running discs perform a rectangular reject followed by circular capture.
Terrain conveyors apply one push per player/frame using `conveyor_applied`.
The wheel is a separate carrier with independent ordinary payload objects;
its `WheelPayloads` table owns routine, vertical offset, subtype and facing.
Payload presets and object properties belong in the
[SonLVL guide](../SonLVL%20INI%20Files/README.md).

Spikes (`$36`) retain S3&K's floor/side/ceiling and movement behavior for both
actors. The damage path preserves simultaneous contact flags and checks the
full word `flashtime`. High subtypes `$00-$70` select S3 sizes/orientations;
`$80-$D0` add S1 arrangements using the same resident art. Low `$0-$3` select
stationary, vertical, horizontal or pushable movement. Y flip selects ceiling
behavior. See SonLVL for arrangement dimensions; reverse gravity, competition
art and FBZ spikes are not implemented.

## Water and shared effects

Splash `$08` and dust `$0E` remain separate objects. Each player has independent
air, mouth bubbles and countdown objects. Nine visible splash frames and ten
six-tile number frames stream through the common atomic art loader. The two
physical player banks cache both source kind and frame; matching frame numbers
from different sources are not a cache hit. Bank allocations/cache offsets
are defined in [Sprites and VRAM](Sprites-and-VRAM.md#effects-and-ui-ownership).

A live splash takes precedence over dust, including offscreen splashes. Skid
particles disappear when their bank changes. Spindash dust stays hidden while
airborne; held charge restarts its first frame on landing after any splash
finishes. Landing on an object counts as ground. Full DMA queues retry a whole
frame. Countdown numbers use screen-space rendering and disappear on air
refill or leaving water. Resident bubbles are separate from streamed numbers.

Both players' invincibility trails use the shared gray ramp. Their lifetime
and animation are independent; shield/star physical banks remain coordinated.
Points popups similarly use separate per-player banks, including primary Tails.

## Input locks and stage exits

The signpost's logical held-right input overrides both manual controller 2
and companion AI. Game/Time Over's high-bit `f_lockctrl` lock clears both
logical controls and blocks Debug, while retaining raw A/B/C for the card.
Sega/current Continue placeholder and level restart release it. Objects keep
updating after primary death.

Primary drowning takes that logical-input/Debug lock at the start of its
120-frame animation, before routine 6. Low air permits Debug; companion
drowning does not lock the primary. Other hurt/death states remain eligible
for Debug until the Over card. Restart clears the lock.

Scene entry clears both live and saved-jingle speed contexts, preventing shoes
tempo from leaking into the next scene. Act-specific song lookup and drowning
recovery are described in [Levels](Levels.md#per-act-music).

In the rotating stage, `BonusPlayer_Fall` quantizes the displacement before
collision so the tested and committed moves agree. If `SSS_ChkItems2` replaces
velocity with a bumper rebound, it validates the new destination, retaining an
unobstructed axis when possible. There is no wall-escape scan or Debug-based
correction. The stage's separate ABI is in [Special stage](Special-stage.md).
