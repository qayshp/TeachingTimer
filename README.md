# Teaching Timer watchOS proof of concept

A watchOS-only app for Apple Watch SE 3 / watchOS 26. It tests a one-hour
mindfulness extended-runtime session, a wall-clock-derived teaching timer,
second-stepped analog hand, paired-iPhone Crown volume, and native Now Playing.

## Why `mindfulness`

Apple documents `mindfulness` as a frontmost extended-runtime category with a
one-hour limit. That makes it the closest legitimate category for this narrowly
scoped mindful-yoga teaching session. `self-care` is limited to 10 minutes, and
`physical-therapy` is a background category intended for actual therapy. This
app does not start or fall back to `HKWorkoutSession`.

The category is declared as `mindfulness` in `TeachingTimer/Info.plist` under
`WKBackgroundModes`.

## Important Always-On limitation

`TimelineView(.periodic(..., by: 1))` requests one-second updates. watchOS owns
the actual Always-On refresh cadence and can lower it while luminance is
reduced. `WKExtendedRuntimeSession` grants runtime but does not promise that the
display will refresh at approximately 1 Hz. The physical-watch checklist below
is therefore the core experiment, not a pre-proven app behavior.

Elapsed time is never incremented by a counter. The session start timestamp is
captured when `extendedRuntimeSessionDidStart` arrives, and every rendered value
is computed from `context.date.timeIntervalSince(startedAt)`.

## Build and simulator

Open `TeachingTimer.xcodeproj`, select an Apple Watch SE 3 simulator, and Run.
The default page is the ray-intersection squircle. Swipe horizontally through
the fixed-length clipped squircle, the fully visible circular reference face,
and Apple's native full-screen `NowPlayingView` on Page 4. All three clock
pages share one session, elapsed-time source, current date, and Crown-volume
behavior.

## Physical Apple Watch validation (not proven by Simulator)

- [ ] On an SE 3, the seconds hand remains visibly advancing approximately once
      per second in wrist-down / Always-On mode during the extended session.
- [ ] `WKInterfaceVolumeControl(origin: .companion)` plus `focus()` routes the
      Digital Crown to the paired iPhone's currently playing audio on Page 1.
- [ ] Swiping to Now Playing and back automatically restores Crown volume focus.
- [ ] Native Now Playing controls actual iPhone next, previous, play, and pause.
- [ ] The mindfulness extended-runtime session remains active for a roughly
      60-minute teaching session.

The simulator can validate layout, launch, paging, timer arithmetic, and the
empty/no-source Now Playing presentation. It cannot validate the five hardware
and paired-device behaviors above.

Debug builds accept `--show-clipped`, `--show-circular`, and
`--show-now-playing` as launch arguments so every non-default page can be
captured deterministically in automated simulator checks.
