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

There is no numeric elapsed-time display. Seconds and minute hands use the same
whole-second timeline date. The minute hand uses `(minute + second / 60) * 6`
degrees and is shorter, thicker, and square-ended for monochrome readability.

## Build and simulator

Open `TeachingTimer.xcodeproj`, select an Apple Watch SE 3 simulator, and Run.
The default page is the ray-intersection squircle baseline. Swipe horizontally
to the identical squircle with a class-progress perimeter, then Apple's native
full-screen `NowPlayingView` on Page 3. There are exactly three pages. Both clock
pages share class context, runtime and metronome controllers, current date, and
Crown-volume behavior.

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

Debug builds accept `--show-progress` and `--show-now-playing` as launch
arguments so every non-default page can be
captured deterministically in automated simulator checks.

## Class, runtime, and metronome

`ClassStore` persists a Codable `ClassContext` in UserDefaults. The first Start
captures the exact button timestamp, inferred scheduled start, and duration
(default 60 minutes; 75 is also supported). Minutes 0–12 after a quarter-hour
anchor backwards, including all seconds in minute 12; minutes 13–14 anchor
forwards. Runtime Stop/Restart never changes this context. The ellipsis button
opens a confirmation before Reset clears the context and cancels both services.

The inward triangular end marker uses the scheduled end minute and the existing
perimeter intersection geometry (or the fitted circle radius). It grows modestly
from an 8-point-wide, 14-point-deep solid white wedge to 9 points wide and
17 points deep at the scheduled midpoint. Its initial filled area is roughly
twice that of a major tick; emphasis relies on shape and size, not opacity.
It persists until Reset,
including beyond the scheduled end and across process relaunches.

`MetronomeController` is independent of the runtime and class. The large button
plays an immediate `.start` acknowledgement, then eight `.click` beats at
5, 10, 15, 20, 25, 30, 35, and 40 seconds. Tap again to cancel. Configuration
exposes interval, count, and haptic types. Each deadline is calculated from one
`ContinuousClock` activation anchor; callback delays never accumulate. A delay
of a whole interval cancels the run rather than replaying missed beats in a burst.
No service grants background execution by itself: wrist-down haptics need device
validation during the runtime. Metronome activity is not restored after relaunch.

Runtime renewal defaults to `.automatic`; `.userInitiated` is also available.
`willExpire` records renewal intent. Replacement starts only after expiration
invalidation, preventing overlap. If inactive, renewal is logged as deferred,
the Restart control remains available, and the next active scene transition
attempts it. A rejected replacement logs its error and requires manual restart;
there is no unbounded retry loop. Running is shown only after `didStart`.
Explicit Stop cancels renewal intent. Class context is never owned by the runtime.

Apple requires active application state for starting extended runtime:
[Using extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions).
Automatic chaining is experimental and does not guarantee uninterrupted display
cadence or App Review acceptance.

The native companion volume control is visible above the central controls and
remains mounted before Start. Its asynchronous focus/resign sequence is preserved;
the previous `setHidden(true)` call has been removed. Recheck immediate Crown
response and native feedback on the physical SE 3.

## Class-progress perimeter experiment

Page 2 differs from Page 1 only by a perimeter treatment for 60-minute classes.
The remaining clockwise segment from the wall-clock minute-hand angle to the
scheduled-end wedge is solid, 2.5 points wide. The elapsed segment is 0.75 points
wide and dashed. This geometric contrast works without color. Both use the same
ray/perimeter geometry as the ticks and stay slightly inside the outer outline.
The existing solid end wedge is drawn above the progress treatment.

Progress is sampled at whole seconds and clamped to the scheduled interval:
before scheduled start the future track is full; at/after scheduled end only
the subdued past track remains. It never wraps into another hour. No context or
a 75-minute duration means no progress track. Hands, snapping, class state,
runtime, metronome, and both pages' control layouts are shared and unchanged.

## Iteration 2 physical SE 3 checklist

- [ ] Seconds remain 1 Hz during active runtime in wrist-down Always-On.
- [ ] Minute hand advances at the same cadence and follows real minutes.
- [ ] End marker and its midpoint emphasis are readable in monochrome.
- [ ] All eight metronome haptics fire wrist-down; acknowledgement is distinct.
- [ ] Large metronome target works with sweaty fingers; tap cancels immediately.
- [ ] Visible native companion control retains immediate Crown volume response.
- [ ] Metronome/runtime controls do not steal Crown focus; paging restores it.
- [ ] Automatic renewal works at the real approximately 60-minute boundary.
- [ ] Inactive/rejected renewal exposes a usable manual restart fallback.
- [ ] Class anchor/end marker remain unchanged across runtime replacement.

Earlier user testing confirmed baseline Crown routing on all faces, Now Playing,
focus restoration, and sustained wrist-down seconds during runtime. Those results
are the regression baseline, not validation of these new changes. Exact hour-long
renewal behavior still needs a timed device test.

Run deterministic class checks on macOS with:

```sh
swiftc TeachingTimer/ClassContext.swift Tests/ClassContextChecks.swift -o /tmp/TeachingTimerClassChecks
/tmp/TeachingTimerClassChecks
```
