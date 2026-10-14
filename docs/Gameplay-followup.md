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

After 120 frames of unsuccessful pursuit of a nearby, grounded higher target,
Tails starts catch-up flight from his current position. Ordinary follow/jump
behavior remains the default, and controller 2 retains precedence. Catch-up
flight approaches large vertical gaps faster and slows near its target.

A collapsing ledge/floor already triggered under walking/running Sonic skips
that delay. The AI checks Sonic's standing-object index, its full routine
pointer and its real collapse flag, then takes off locally and waits in
flight while that moving target remains unsafe. A stationary or rolling
Sonic does not trigger this reaction; Tails can fall normally. Controller 2
still takes precedence. No additional SST fields are needed.

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
| Normal build and source audit | 94 mapping bounds / 1,118 frames; all 93 object sources plus `main.asm`; 6,261 named SST operands |
| Native packed-star tests | 270 updates with full/partial/no visible children; padding survives compaction and rendering |
| Native deletion | All 78 SST bytes cleared; following slot untouched |
| Companion emulator cases | Both ledge-jump directions, moving platform, flight fallback, walking/stationary crumbling ledge, manual override, flat ground, bridge approaches above/below, bonus pickup and signpost override pass in NTSC/PAL |
| Stage 1 bumper approaches | 352 valid starts / 140 real bumper contacts per region; old ROM embeds on three cases, current ROM embeds on none |
| Stage item callbacks | Normal DOWN contact changes rotation; normal GOAL contact reaches results |
| Ordinary stage play | 1,200 frames per region without an embedded position or added lag frames |
| Over cards | Real zero-ring monitor deaths lock Debug and logical input; raw controller 2 advances both cards; exit/restart unlocks |
| Object course | 57 placement lifecycles and 46 interactions pass for Sonic/NTSC and primary Tails/PAL |
| Effects, Debug and giant rings | Shield/star VRAM contents, hurt/death Debug entry and single/triple giant-ring contacts pass for both primary characters |
| Attract mode | All four demos finish and return to title in NTSC/PAL; intentional timing and desynchronization retained |

The optional emulator runners accept `--rom`, `--listing`, `--core` and
`--output`; add `--pal` for PAL. New cases live in
`build_tools/check_companion_followup.py`, `check_over_screen_input.py` and
`check_special_stage_overlap.py`. The latter accepts `--probe` to record an
older ROM's embedding failures. Native cases are in `check_object_manager.py`.
The course retains the previously documented broken Gator and excluded
Labyrinth conveyor; these are separate unfinished objects.

Code growth put several external word branches beyond the 68000 range in
the instrumented build. See-saw, conveyor and ordinary bumper tail calls use
absolute jumps where necessary; this does not finish the conveyor behavior.
