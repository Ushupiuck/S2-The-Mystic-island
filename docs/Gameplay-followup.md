# Packed effects and gameplay follow-up

Invincibility's eight composite records already contain eight unused bytes.
Four hold orbit angles and four hold animation indexes; the child writer
skips those bytes. `object_size` is now `$4E`, retaining 23 reserved and 90
dynamic slots and reclaiming 226 bytes. Splash-bank caches use their unused
`$34–$35` scratch instead. See [the field map](SST-routine-pointers.md).

The renderer retains the user's entry and world-coordinate fall-through
optimizations. Legacy background-coordinate composite handling is at the
composite entry, eliminating its jump back to the world path.

## Companion movement

The old following dead zone inherited neutral input from a stationary Sonic,
so Tails could jump repeatedly without changing X. A ledge attempt now uses
an eight-pixel horizontal stopping range and steers toward Sonic throughout
the jump. A rider supplies his live X/Y instead of a historical platform
position. This supports static platforms, moving platforms and bridge sag
without relying on object-specific velocity fields or a math subroutine.

Unreachable ordinary platforms retain normal jump attempts. The approach
word is a steering state, not a timer that eventually promotes any higher
target to flight. A grounded slope lock with zero momentum or a slip away
from Sonic enters the existing CPU spindash routine; it waits for the lock,
comes to rest, charges and releases through normal logical controls.

Tails first makes his ordinary horizontal rolling jump toward Sonic. If the
last ridden ledge/floor actually fragments, he switches to local flight only
when Sonic is running or deliberately jumping away, still within 128 pixels
horizontally and at least 24 pixels above Tails. A jump already level with or
above Sonic continues normally, including GHZ1's paired ledges before the first
checkpoint. The distance check also prevents a retained fragment reference
from interrupting a later, distant jump. `jumping` distinguishes
a jump from simply falling off; a descending jump still qualifies. If Sonic
falls without that flag, Tails falls normally, and any flight tagged for that
ledge ends on the next AI update. Reaching a grounded target resumes ordinary
following.

The check resolves Sonic's retained standing-object index to one SST, validates
its full routine pointer and fragment routine, and never scans the object
pool. The initial touch countdown does not qualify. Controller 2 retains
precedence. The existing approach-state word becomes a marker during CPU
flight; no new RAM or SST fields are allocated. The common flight initializer
preserves that marker, avoiding a temporary stack save. The fragment routine
already proves break-up, so a redundant collapse-flag check is unnecessary.

Collapse pursuit moves at most six pixels horizontally per update. Vertical
CPU flight restores S3&K's one-pixel step. Ordinary offscreen respawn retains
its original horizontal pursuit calculation and five-second timeout.

Taking off detaches Tails from his standing object and its companion-rider
flag. Negative `obControl` prevents catch-up flight from becoming a platform
rider. Bridge landing uses the selected log's depressed Y, rather than the
bridge parent's original height. Catch-up Tails therefore neither depresses
a log while flying nor stalls above a sagging bridge's center.

## End-of-level input and bonuses

The signpost's held-right logical input overrides controller 2 and companion
AI. Game/Time Over uses a distinct high-bit input lock, preventing Debug entry
and clearing both logical controls while keeping raw A/B/C available to the
card. Sega/current Continue placeholder and restarted levels release it.
Objects intentionally continue updating after the primary player's death.

Primary drowning applies the same logical-input/Debug lock from the start of
the drowning animation, before routine 6 begins. Low air still permits Debug;
companion drowning does not lock the primary. Restart clears the lock. Other
hurt/death states remain eligible for Debug before the Over card.

Either live character can collect hidden end-of-level bonuses. The existing
shared score, popup mappings, art and one-time award remain unchanged.

## Special-stage collision

Two normal-play paths could commit an unchecked position inside a solid cell:

- `BonusPlayer_Fall` checked a full-precision displacement, then converted it
  to an 8.8 velocity. Rounding a negative fractional step could move farther
  than the checked position. It now masks the discarded fraction before
  collision testing, so the tested and committed displacement are identical.
- `SSS_ChkItems2` could replace that validated velocity with a bumper rebound.
  The final position update applied it without another collision test. Changed
  velocities now validate the rebound destination, keeping an unobstructed
  axis when the diagonal move meets a wall.

Ordinary movement retains the validated fast path. There is no wall-escape
search, position correction or dependence on Debug mode. Debug remains free
to place the player arbitrarily; test fixtures for this fix begin in clear
positions and use normal movement and real bumper callbacks.

## Validation

| Check | Result |
| --- | --- |
| Normal build and source audit | 94 mapping bounds / 1,118 frames; all 93 object sources plus `main.asm`; 6,269 named SST operands |
| Native packed-star tests | 270 updates with full/partial/no visible children; padding survives compaction and rendering |
| Native deletion | All 78 SST bytes cleared; following slot untouched |
| Companion emulator cases | Both ledge-jump directions, moving platform, four normal jump attempts at an unreachable platform without flight, actual collapse with running/jumping/falling Sonic and bounded speed, manual override, flat ground, bridge approaches above/below, bonus pickup and signpost override pass in NTSC/PAL |
| Actual HPZ1 routes | Both regions pass starts/stops, slow and faster ramp approaches with real spindash charge/release, and Sonic landing on each successive placed ledge while Tails keeps normal jump attempts; the old ROM reproduces a timed takeoff and misses the momentum-route spindash |
| GHZ1 double ledge before checkpoint 1 | 36 riding and 36 rock-approach speed/timing combinations per region; riding introduces no jump or flight, and neither setup triggers collapse flight; ordinary offscreen respawn remains available |
| Stage 1 bumper approaches | 352 valid starts / 140 real bumper contacts per region; old ROM embeds on three cases, current ROM embeds on none |
| Stage item callbacks | Normal DOWN contact changes rotation; normal GOAL contact reaches results |
| Ordinary stage play | 1,200 frames per region without an embedded position or added lag frames |
| Over cards | Real zero-ring monitor deaths lock Debug and logical input; raw controller 2 advances both cards; exit/restart unlocks |
| Object course | 57 placement lifecycles and 46 interactions pass for Sonic/NTSC and primary Tails/PAL |
| Effects, Debug and giant rings | Shield/star VRAM contents, hurt/death Debug entry and single/triple giant-ring contacts pass for both primary characters |
| Drowning | Real air expiry blocks both logical controls and Debug for the 120-frame animation, reaches death and unlocks on restart for Sonic/NTSC and primary Tails/PAL; companion expiry leaves primary Debug available |
| Attract mode | All four demos finish and return to title in NTSC/PAL; intentional timing and desynchronization retained |

The optional emulator runners accept `--rom`, `--listing`, `--core` and
`--output`; add `--pal` for PAL. New cases live in
`build_tools/check_companion_followup.py`, `check_companion_hpz.py`,
`check_over_screen_input.py`, `check_special_stage_overlap.py` and
`check_drowning_input.py`. The overlap
runner accepts `--probe` to record an older ROM's embedding failures. Native
cases are in `check_object_manager.py`.
The HPZ runner uses the actual level and controller input from its start for
the ramp routes. Its platform route positions only the initial actors at the
real ledges; no layout, object or collision substitute is introduced. Native
checks include 1,680 unreachable-target updates, 48 slope-recovery conditions
and 280 flight speed/direction/overshoot cases.
The course retains the previously documented broken Gator and excluded
Labyrinth conveyor; these are separate unfinished objects.

Code growth put several external word branches beyond the 68000 range in
the instrumented build. See-saw, conveyor and ordinary bumper tail calls use
absolute jumps where necessary; this does not finish the conveyor behavior.
