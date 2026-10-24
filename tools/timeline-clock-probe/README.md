# Timeline clock transition probe

A separate, Simulator-only watchOS app for the
[Always-On hand transition investigation](../../docs/ALWAYS_ON_HAND_TRANSITION.md).
It renders one ticking hand from `TimelineView.Context.date`. It has no class,
runtime session, media view, volume control, landmark state, or haptics.
It does not modify TeachingTimer and uses a separate bundle identifier.

## Build and run

Requires Xcode with a watchOS Simulator SDK and an already booted Watch
Simulator. Tested with Xcode 27.1 / watchOS 27.0 on SE 3 40 mm. The script builds
for the Mac's architecture and signs locally; it does not boot, erase, or install
anything automatically. Default generated output is under ignored `work/`.

From the repository root:

```sh
sh tools/timeline-clock-probe/build.sh
xcrun simctl install SIMULATOR_UDID work/timeline-clock-probe/TimelineClockProbe.app
xcrun simctl launch SIMULATOR_UDID com.qayshp.TeachingTimer.ClockProbe
```

Watch the hand while alternating **Device Hub → Controls → Lock** (⌘L) and
unlock, about 3.5 seconds apart, for at least four cycles. Repeat at different
seconds: a short clean pass does not establish that a variant fixes the issue.
A video is more useful than occasional screenshots for the brief reversal.

The default uses ordinary Path strokes, a fixed whole-second epoch schedule,
and yellow/white color for active/reduced luminance. Optional launch arguments:

- `--canvas`: draw the same hand using Canvas.
- `--constant-color`: keep the hand white in both states.
- `--moving-anchor`: recompute the next-whole-second schedule anchor when the
  parent body evaluates, matching TeachingTimer's current schedule.

For example, restart only the probe in the selected simulator:

```sh
xcrun simctl launch --terminate-running-process SIMULATOR_UDID \
    com.qayshp.TeachingTimer.ClockProbe --constant-color
```

Expected: a hand ticking clockwise once per second, possibly at a slower system
cadence in Always-On, without briefly reversing at a transition. The test is
about frame ordering, not a guarantee of 1 Hz execution without extended runtime.
Use the supplied timeline date; do not substitute current time or globally clamp
dates because watchOS may request future frames before they are displayed.

This is a rendering diagnostic, not a replacement teaching app. There is no
icon, production packaging, physical-Watch validation, or automatic log capture.
The source/build script are MPL-2.0 like the containing repository.
