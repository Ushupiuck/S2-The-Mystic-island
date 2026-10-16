# Tails AI: Scrap Madness follow-up

## Recorded playthroughs

The original Act 1 samples used the same Tails source throughout
(`66a67092db1d419a9589cbfc0773d49be30f8ae61daf3433732a0d5b4648a786`).
These are historical observations, not results for the revised AI.

| Completed Act 1 route | Sonic deaths | Tails deaths | Tails respawn starts |
| --- | ---: | ---: | ---: |
| Low | 0 | 7 | 8 |
| Normal | 0 | 1 | 4 |
| High | 1 | 1 | 7 |

The low run predates the materializing-platform collision correction. The
high run includes falls and an ordinary checkpoint restart, rather than a
perfect upper-only traversal. It reached the signpost at frame 12321 and
stopped after the Act 2 fade at frame 13055. Tails finished on the lower road,
405 pixels behind and 164 below Sonic. Act 2 wheel fixtures were object tests;
they were not full route samples for this AI work.

Level-object fixes landed between samples. Raw death/respawn counts therefore
describe each run; they do not isolate the AI's contribution or measure the
effect of this update. The requested new low-route playthrough remains
deferred. No new complete playthrough was performed for this change.

## Observations used

- **Conveyors and stack transfers:** Tails sometimes left his carrier before
  making the jump to Sonic's higher platform. In the normal run, frames
  3558–3955 contain 398 consecutive frames of vertical separation greater
  than 64 pixels while the characters remain within 256 pixels horizontally.
  Tails attempted six jumps. A second such interval at frames 4882–5233
  lasts 352 frames around the sliding-floor climb. The high run also records
  missed transfers; on checkpoint recovery he missed the stack near
  `(6000,496)` and respawned at frame 10338. Respawn totals alone miss these
  long periods of unsuccessful following.
- **Flat spring landing:** Low-run frames 2320–2352 show Tails carrying spring
  momentum onto the small landing near `(2425,1932)`. With a movement lock
  still active, he passed Sonic and entered CPU state 8 on flat ground. That
  state is slope/spindash recovery, not a suitable response to a moving
  spring landing. This diagnosis does not imply that the AI can cancel the
  spring's physical input lock or guarantee survival in the crusher chain.
- **Catch-up retry:** In the normal run, the flight beginning at frame 4006
  starts at `(4869,927)`, 192 pixels above Sonic. Sonic descends while the
  flight moves vertically at only one pixel per update. Tails remains above
  the camera and times out again at frame 4352, despite reaching only 148
  pixels above Sonic. This is a retry during catch-up, separate from a new
  running/jumping failure.
- **Behaviors to preserve:** Tails followed the successful three-girder
  descent and materializing-platform staircase, used useful spindash
  recoveries, and rejoined the normal run's final reversal/uphill jump.
  Earlier broad braking and timed flight fallback experiments had regressed
  HPZ recovery and were reverted; this update does not reinstate them.

## Changes

1. **Jump from an available surface.** An established approach to Sonic on a
   higher object can request a normal jump immediately once Tails is grounded
   and within the existing 64-pixel horizontal jump window. Larger gaps still
   require approaching first. Jumping immediately from rest at the wider
   approach limit missed the conveyor; the narrower launch window allows a
   run-up. Terrain-only climbs retain their existing jump timing so slope
   recovery still has an opportunity to act.
2. **Keep an established approach through a deliberate lead jump.** Sonic
   jumping from the target does not discard Tails's live steering halfway
   through the transfer. Falling still clears it, and an airborne Sonic does
   not create a new approach from nothing.
3. **Distinguish moving spring landings from slope slips.** Opposite inertia
   with an active lock enters spindash recovery only on a slope, using the
   same angle interval as `Sonic_SlopeRepel`. Zero-inertia recovery remains
   available after the floor angle has reset, as required by the HPZ ramp.
4. **Close a respawn flight's vertical gap.** Ordinary catch-up moves
   `min(abs(dy)/16 + 1, 6)` integer pixels toward its recorded target. It
   converges without overshooting. Local collapse rescue keeps its existing
   one-pixel vertical and six-pixel horizontal limits. Takeoff rules, target
   history, horizontal respawn pursuit and the five-second timeout remain
   intact.

No RAM, object fields, pool scans, new flight triggers or player-physics
changes are needed. One existing Labyrinth conveyor tail call needed an
absolute jump because code growth exceeded its word-branch range during the
sprite-bounds assembly pass; its behavior is unchanged.

## Focused comparison

Baseline: production `756ffe820a333479a73718de3723294298cfb389`, ROM SHA-256
`edaf0e4ab32ffae9a4ef8c20d3e8caa86b1cd2ad9302f71d7815771133e557ad`.

`build_tools/check_companion_sbz.py` uses Genesis Plus GX's actual 68000 code:

| Fixture | Baseline AI | Revised AI |
| --- | --- | --- |
| Rising SBZ conveyor, all 64 jump-clock phases | 14/64 transfers land on Sonic's carrier | 64/64 land, with no flight or death |
| Both characters sharing the same carrier | Stays aboard without unnecessary jumps | Same |
| Captured normal-run flight | Reproduces the retry at frame 4352 | Rejoins at frame 4042, after 36 updates |

The conveyor fixture initializes riders on the real eight-member SBZ group
and then runs ordinary game frames, without supplying delayed jump input.
Its 64 phases vary the jump clock, not the entire level's timing; this is a
deterministic reproduction rather than a success-rate estimate for full runs.
The flight fixture contains the captured Sonic/camera trajectory and history
in `build_tools/fixtures/smz1-normal-catchup.json`. It runs only the actual
flight routine and sprite renderer until rejoin or retry. It does not predict
what happens after Tails resumes ordinary physics at frame 4042.

The build and assembled manager/player suite pass, including 288 slope/spring
conditions, eight lead-jump/fall approach cases, 11 ordinary vertical-pursuit
boundary cases, 280 local-flight bounds cases and 1,680 unreachable-target
updates. Existing NTSC/PAL companion emulator checks cover ledges in both directions,
moving/unreachable targets, manual takeover, collapse flight, bridges,
signpost control and the GHZ paired ledges. NTSC/PAL HPZ checks retain both ramp
spindashes and the consecutive-platform sequence. Full revised-AI route
outcomes remain to be measured in the later playthroughs.

Run after building:

```sh
python build_tools/check_object_manager.py
python build_tools/check_companion_sbz.py --core /path/to/genesis_plus_gx_libretro.so --output /tmp/tails-sbz
python build_tools/check_companion_followup.py --rom s2built.bin --listing main.lst --core /path/to/genesis_plus_gx_libretro.so --output /tmp/tails-followup
python build_tools/check_companion_hpz.py --rom s2built.bin --listing main.lst --core /path/to/genesis_plus_gx_libretro.so --output /tmp/tails-hpz
```

Add `--pal` to the existing follow-up and HPZ runners for the PAL checks.
Use `--probe` on the SBZ runner to record an older ROM's failures.
