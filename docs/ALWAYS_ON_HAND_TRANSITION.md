# Seconds-hand transition investigation — October 23, 2026

## Report and scope

After the 2 p.m. class, the user reported a brief apparent backward step of the
seconds hand when the physical Watch dimmed into Always-On, followed by normal
ticking. No sustained freeze or clock error was reported. This investigation
used the existing SE 3 40 mm watchOS 27.0 Simulator in Xcode 27.1 Device Hub.
No physical device was contacted or installed to.

## Code findings

- `ContentView` supplies one `TimelineView.Context.date` to the timer face.
  Seconds are extracted from that date; the minute hand uses the same date.
- `SquircleClockFace` uses discrete integer-second geometry and Canvas strokes.
  There is no hand rotation animation, accumulated counter, or separate dimmed
  angle calculation. Reduced luminance changes the hand color, not its angle.
- The periodic schedule's `nextWholeSecond` is computed from current time each
  time the parent body evaluates. Luminance, scene, and observed state changes
  can therefore move the schedule anchor forward to the next whole second.
- A temporary opt-in trace confirmed that a dimming update could request a
  future second immediately: at wall time `17:23:54.186`, the context date and
  new schedule anchor were `17:23:55`. About 0.56 seconds later, a context dated
  `17:23:54.722` was requested. Video showed **55 → 54 → 55**.
  Those timestamps are local Simulator log times, not the physical-class event.

The moving anchor is a concrete premature-frame hazard, but it is **not a
complete explanation or proven complete fix**: keeping the anchor constant
still reproduced transition backsteps.

## Bounded experiments

Each video pass covered four Lock/unlock cycles, about 32 seconds. The initial
screenshot pass covered four Lock entries but missed the brief reversal.
Videos were inspected using frame extraction and radial hand-position estimates;
small sub-tick estimate fluctuations from rasterization/color changes were not
counted as full backward ticks. Captures are not a hardware timing benchmark.

| Variant | Observation |
| --- | --- |
| Original scheduling with temporary opt-in context logging; session off | Visible 55 → 54 → 55, plus another backward tick near a later Lock transition |
| Fixed whole-second epoch anchor; session off | Backward ticks still occurred during Lock transitions |
| Fixed anchor plus timeline-content invalidation on luminance changes; session running | Backsteps still appeared, including on unlock; not a reliable remedy |
| Original unchanged build, no per-frame logging; session confirmed running | 1,230 recorded frames; visible backward ticks at approximately 3.82 and 25.87 seconds into the video, both shortly after Lock (22 → 21 and 44 → 43) |

The candidate fixes and per-frame logging were removed. The source and installed
SE Simulator app were restored to the unchanged pre-investigation implementation.
The other Simulator devices and physical Watch were not modified.
All nine deterministic test suites passed. Both temporary instrumented variants
built successfully; neither is retained as a shipped fix.

## Interpretation and next step

The symptom is reproducible; it is not merely a subjective impression of the
yellow-to-white change. The evidence points to the handoff between live rendering
and reduced-luminance timeline frames, with the moving schedule anchor as one
app-level hazard. A stable anchor alone does not eliminate stale-looking frames,
so the remaining cause could involve nested view/Canvas invalidation or watchOS
transition snapshots. This investigation does not establish an Apple framework
bug or prove the physical Watch has exactly the same underlying cause.

The next useful isolation is a tiny standalone timeline clock without session,
media, or nested geometry views, comparing ordinary shape drawing with Canvas
under the same transition sequence. If that also reverses, it provides a small
Apple feedback reproduction. Do not rewrite the working app around a guess.

Do not replace context dates with `Date.now` or clamp every render to the
largest previously requested date. Apple can request future frames in batches;
either workaround can make Always-On content stale or jump ahead. Keep the
landmark arc's monotonic projection intact.

Apple references:

- [Timeline context date](https://developer.apple.com/documentation/swiftui/timelineview/context/date)
- [Updating watchOS apps with timelines](https://developer.apple.com/documentation/watchos-apps/updating-watchos-apps-with-timelines)

Private local evidence is under `work/support/2026-10-23-hand-transition/`:
screen captures, short videos, extracted frames, context logs, and the Simulator
runtime journal. These generated diagnostic artifacts are ignored by Git.
