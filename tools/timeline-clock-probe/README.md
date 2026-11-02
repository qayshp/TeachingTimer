# Timeline clock transition probe

A separate, Simulator-only watchOS app for the
[Always-On hand transition investigation](../../docs/ALWAYS_ON_HAND_TRANSITION.md).
It renders one ticking hand from `TimelineView.Context.date`. It has no class,
runtime session, media view, volume control, landmark state, or haptics.
It does not modify TeachingTimer and uses a separate bundle identifier.

## Build and run

Requires Xcode with a watchOS Simulator SDK and an already booted Watch
Simulator. Tested with Xcode 27.1 / watchOS 27.0 and Xcode 27.2 / watchOS 27.2
(24S118) on SE 3 40 mm. Use the selected Xcode's newest compatible installed
runtime and resolve the Simulator identifier live. The script builds
for the Mac's architecture and signs locally; it does not boot, erase, or install
anything automatically. Default generated output is under ignored `work/`.

From the repository root:

```sh
sh tools/timeline-clock-probe/build.sh
xcrun simctl install SIMULATOR_UDID work/timeline-clock-probe/TimelineClockProbe.app
xcrun simctl launch SIMULATOR_UDID net.qays.TeachingTimer.ClockProbe
```

Watch the hand while alternating **Device Hub → Controls → Lock** (⌘L) and
unlock, about 3.5 seconds apart, for at least four cycles. Repeat at different
seconds: a short clean pass does not establish that a variant fixes the issue.
A video is more useful than occasional screenshots for the brief reversal.
Record actual screen-state changes separately from input commands. In the
default variant, the white/yellow hand change helps distinguish the rendered
luminance states. A tap being dispatched does not prove that the simulator woke;
do not count command pairs alone as completed Lock/wake cycles.

The default uses ordinary Path strokes, a fixed whole-second epoch schedule,
and yellow/white color for active/reduced luminance. Optional launch arguments:

- `--canvas`: draw the same hand using Canvas.
- `--constant-color`: keep the hand white in both states.
- `--moving-anchor`: recompute the next-whole-second schedule anchor when the
  parent body evaluates, matching TeachingTimer through build 33. Build 34's
  source candidate uses the default fixed epoch.
- `--trace-render`: add the optional two-source rendering diagnostic below.
- `--normalize-second-boundary`: compare the narrow display-boundary normalization
  described below. It is off by default; the raw baseline is retained.

For example, restart only the probe in the selected simulator:

```sh
xcrun simctl launch --terminate-running-process SIMULATOR_UDID \
    net.qays.TeachingTimer.ClockProbe --constant-color
```

Expected: a hand ticking clockwise once per second, possibly at a slower system
cadence in Always-On, without briefly reversing at a transition. The test checks
visible hand progression; it does not guarantee 1 Hz execution without extended runtime.
Use the supplied timeline date; do not substitute current time or globally clamp
dates because watchOS may request future frames before they are displayed.

## Optional rendering trace

`--trace-render` leaves the default fixed-epoch schedule and ordinary Path hand
in place. It adds a **short dashed hand with an open endpoint** for fresh wall
time sampled during the same timeline-content evaluation. The original long,
solid hand still uses the supplied context date. Compact labels show the
evaluation ID (`E`), luminance state, rounded context seconds (`C`), the actual
drawn integer second (`S`) and sampled wall seconds (`W`). `C` and `W` include
milliseconds; `C` can conceal sub-second precision that changes `S`.
Geometry distinguishes the hands even in
monochrome; the labels may obscure part of a hand and are diagnostic only.

Each evaluation samples wall and monotonic time once and emits one `Logger`
record in subsystem `net.qays.TeachingTimer.ClockProbe`, category `RenderTrace`.
It contains that same ID, context/wall epoch timestamps, monotonic seconds since
the recorder's initialization, cadence and luminance. `context_reference_bits`
preserves the raw `Date.timeIntervalSinceReferenceDate` Double bit pattern;
`raw_second` is its Calendar component, `context_second` is the displayed
component, and `normalized` identifies the comparison mode. Decode the reference
bits when investigating boundaries: conversion to Unix epoch can round away
information before formatting, even with more decimal places.
The immutable snapshot is captured before `GeometryReader`; its stored
component drives both the hand and `S` label rather than rereading the context
during layout.
A lock protects the ID and sampling pair. There is no observable state change,
additional timer, date clamp or production-app change.

Capture unified logs in a separate terminal before launching the trace variant:

```sh
xcrun simctl spawn SIMULATOR_UDID log stream --style compact --level info \
    --predicate 'subsystem == "net.qays.TeachingTimer.ClockProbe" AND category == "RenderTrace"' \
    > work/clock-render-trace.log
```

```sh
xcrun simctl launch --terminate-running-process SIMULATOR_UDID \
    net.qays.TeachingTimer.ClockProbe --trace-render
```

Bound the first comparison to two short recordings of about 45 seconds each,
using the existing default sequence and confirming actual Lock/wake luminance
changes. Stop the log stream afterward. Correlate decoded visible IDs and hands
with the log records; video presentation time and monotonic-log time require an
observed alignment, not an assumption that launch or input timestamps match.

**Evaluation order is not display order.** Always-On can prepare future content
in batches, so an older evaluation ID appearing later is not inherently an
error. A fresh `Date()` hand can remain at preparation time while future frames
display; it is a diagnostic reference, not a correct replacement clock or fix.
A new evaluation with regressed context time differs from reappearing older
content, but neither alone proves the internal compositor cause. Logging and
extra geometry may also affect timing. Compare with the uninstrumented baseline
and do not interpret a clean short trace as a resolved bug. In particular, the
rounded Unix labels alone cannot exclude an input-precision explanation.

## Optional boundary normalization

The build script compiles the shared production
[`WallClockDisplay` helper](../../TeachingTimer/WallClockDisplay.swift) into this
isolated app. With `--normalize-second-boundary`, the context hand uses a date
normalized only when its reference-time value is an integer or that integer's
immediate `nextDown`/`nextUp` neighbor. Other fractions, future dates and genuine
clock corrections are retained; no last-rendered-date clamp is used. The raw
context date is still logged. Add both flags for a labeled comparison:

```sh
xcrun simctl launch --terminate-running-process SIMULATOR_UDID \
    net.qays.TeachingTimer.ClockProbe --trace-render --normalize-second-boundary
```

Without the normalization flag, the probe still draws the raw Calendar second.
The bounded normalized comparison exercised 113 one-step-below-boundary dates
among 234 evaluations and corrected every displayed component. Independent
replay matched all 234 records; 190 video frames over 24.283 s showed no measured
backward whole tick. Build 33 also passes all 21 app UI-action assertions.
These are Simulator results, not a physical-Watch fix claim or a guarantee
against every transition defect.

### Moving versus fixed anchor with normalization

A separate short comparison enabled normalization in both variants. The moving
anchor produced two pixel-confirmed backward ticks (18 → 17 and 29 → 28) in
192 frames over 23.7617 s. The fixed epoch produced none in 170 frames over
23.7333 s. Both runs completed two confirmed dim/wake cycles.

The moving-anchor regressions are ordinary fractional context dates following
a premature next-whole-second input, not one-step precision errors. The fixed
pass still exercised 112 below-boundary corrections. Each run also returned
twice from future-preparation batches to current time; these request-order
changes are not extra visible backsteps. See the
[comparison and limitations](../../docs/ALWAYS_ON_HAND_TRANSITION.md#build-34-follow-up-stable-schedule-anchor).
One short pass per variant is not a universal fix claim. Build 34 compiles with
the combined stable anchor and display helper, passes all 21 app UI-action
assertions and completes a locked six-group count near 64.823 seconds. A separate
23.815-second runtime-active app video has 764 analyzed frames with no ambiguous detections or
backward-tick candidates; reviewed frames cover dim/wake and forward 59 → 0
rollover. These remain bounded Simulator results, not physical validation.

## November 2, 2026 observation

The default fixed-epoch, ordinary-Path variant reproduced two visually confirmed
backward ticks on watchOS 27.2: about 54° → 48° at 12.400 seconds and 168° → 162°
at 31.722 seconds into a 39.88-second recording. Both occurred while the hand was
white, just before it changed to yellow, suggesting wake-side transitions in
this sequence. Four Lock/tap command pairs did not establish four completed
display-state cycles. Exact frames and qualifications are in the
[investigation](../../docs/ALWAYS_ON_HAND_TRANSITION.md#november-2-watchos-272-reproduction).

That first pass established a Simulator reproduction without identifying its
cause. A later exact-value trace found context Dates one representable Double
step (119.209 ns) below whole-second boundaries. Calendar correctly returned the
preceding second, while rounded Unix timestamps appeared unchanged. Captured
evaluation 291 used second 46; evaluation 292 used second 45, matching the
reviewed later frames. The same run includes 35 → 34 in the input trace.

This supplies a numerical mechanism for these probe results, not evidence of
stale composited frames or proof that every physical incident has the same
cause. See the [precision diagnosis and exact frames](../../docs/ALWAYS_ON_HAND_TRANSITION.md#november-2-exact-date-precision-diagnosis).
The newer evidence and an Apple follow-up draft remain local; no update has
been sent to FB25329087.

This is a rendering diagnostic, not a replacement teaching app. There is no
icon, production packaging or physical-Watch validation. The default variant
does not log; optional trace output must be captured separately as above.
The source/build script are MPL-2.0 like the containing repository.
