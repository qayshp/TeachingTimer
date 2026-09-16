# Teaching Timer watchOS proof of concept — version 2

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
The default page is the ray-intersection squircle with its class-progress
perimeter. Swipe horizontally to Apple's native full-screen `NowPlayingView`
on Page 2. There are exactly two pages. The former baseline comparison page
has been removed; class context, runtime, metronome, and Crown behavior remain.

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
now starts a fresh landmark counter: immediate `.start` acknowledgement, then
1, 2, 3, 4, 5, and 6 `.directionUp` pulses in groups beginning at 10, 20, 30,
40, 50, and 60 seconds after the tap. Pulses within each group are 0.8 seconds
apart. The final group runs from 60 to 64 seconds; the counter clears at 64.8
seconds to let the last pulse finish. Tap again to cancel all pending pulses
(a haptic already handed to WatchKit may finish). No extra completion haptic
is added, so it cannot be confused with a seventh count.
Configuration exposes interval, landmark count (up to six), spacing, and haptic
types. The stronger `.directionUp` haptic is retained from the tested PoC.
Each pulse deadline is calculated from one `ContinuousClock` activation anchor;
callback delays never accumulate. A pulse at least 0.4 seconds late cancels the
run rather than compressing stale pulses into a misleading burst.
The existing one-second timeline samples an inner dashed squircle arc, anchored
to the seconds-hand position at activation. It grows clockwise to a full loop
at 60 seconds, holds during the final pulse group, and disappears on completion
or cancellation. A solid dot marks the starting point immediately. Geometry and
an inset of 23 points distinguish it from the outer class-progress perimeter in
monochrome. Progress uses monotonic elapsed time, so wall-clock corrections do
not change the haptic schedule or reset the arc. No per-pulse UI publications
or additional high-frequency animations are introduced.
No service grants background execution by itself: wrist-down haptics need device
validation during the runtime. Metronome activity is not restored after relaunch.

### Landmark iteration verification (September 15, 2026)

After accepting the updated Xcode license, the Simulator build succeeded and
the app launched on Apple Watch SE 3 (40 mm), watchOS 26.5. Landmark timing
checks and the existing class-context checks passed. Simulator interaction
confirmed activation, the growing inner arc, automatic return to inactive with
the arc removed, and second-tap cancellation. A complete logged run delivered
21 haptic calls in groups of 1–6, beginning at approximately 10–60 seconds;
completion was logged 64.8 seconds after activation. These are software timing
and UI checks, not proof of physical haptic delivery or wrist-down behavior.
Rerun the deterministic landmark checks with:

```sh
swiftc TeachingTimer/MetronomeController.swift Tests/LandmarkChecks.swift -o /tmp/TeachingTimerLandmarkChecks
/tmp/TeachingTimerLandmarkChecks
```

Physical follow-up: distinguish 1–6 pulses with the chosen spacing, cancel
mid-group and restart without old pulses leaking through, check automatic
completion and fresh arc anchors (including across :59/:00), verify arc contrast
in Always-On, and recheck Crown responsiveness and seconds-hand cadence.

### Simulator runtime signing and controls

Use normal Xcode Simulator signing when installing/running the app; do not pass
`CODE_SIGNING_ALLOWED=NO` for runtime validation. That override produced a
linker-signed executable with identifier `TeachingTimer` rather than
`com.qayshp.TeachingTimer`. The Simulator's Carousel session service rejected
runtime starts with SessionErrorDomain code 14 (client bundle-ID mismatch),
surfaced to the app as an unknown WKExtendedRuntimeSession error. Rebuilding with
normal signing corrected the identifier and the delegate confirmed runtime
start. Compilation-only unsigned builds do not validate extended runtime.

The reset entry now has a 44 × 44 point outlined hit target, with confirmation
still required. Runtime status distinguishes starting, active, stopped, expired,
and failed starts; a fixed-height status area keeps controls from shifting.
Invalidation logs include reason, error domain/code, and app state. Simulator
checks confirmed start, stop, restart, reset confirmation and confirmed reset.

Separate unresolved physical-media report: the first volume adjustment may stop
or mute playback and leave native Now Playing empty. No volume/focus/media
implementation changes were made as part of this runtime/control fix. It is
not established whether that report is related to the Simulator signing issue.

### Persistent runtime diagnostics

`Documents/RuntimeDiagnostics.json` in the Watch app's own data container retains
the latest 1,000 runtime/lifecycle events across app launches and New Class/Reset.
Each event is saved immediately using an atomic file replacement. It includes
UTC timestamp, launch/session IDs, app/scene state, session phase, start and
expiration dates when available, uptime, renewal state, and manual stop source.
Invalidation records include watchOS's reason name and raw code, error domain,
code and description, and one underlying error if supplied. Start requests,
confirmed starts, expiration warnings, deferred renewal, and inactive-start
rejections are also recorded. No media metadata, audio, or per-second timer data
is collected; nothing is uploaded. Oldest events rotate out at the limit.

The journal preserves whatever callbacks the app receives. A crash, force quit,
power loss, or undelivered/deferred callback can leave only a last-known state;
absence of an end event is not a diagnosed cause. Disk/write failures are logged
to OSLog. An unreadable journal is left intact rather than silently overwritten.
Uninstalling the app deletes its container, so collect diagnostics before doing
that. Reinstalling an update normally preserves app data; do not uninstall first.

After class, connect/unlock the development Watch and retrieve the file using
Xcode's device container facilities or `devicectl` (physical transfer still needs
verification on the paired SE 3):

```sh
xcrun devicectl device copy from --device WATCH_DEVICE_ID \
  --domain-type appDataContainer --domain-identifier com.qayshp.TeachingTimer \
  --source Documents/RuntimeDiagnostics.json \
  --destination /tmp/TeachingTimer-RuntimeDiagnostics.json
```

Verified in Simulator: actual start/stop invalidation records are written and
remain after relaunch. Pure storage checks cover reopen, bounded retention,
reason preservation, and refusing to overwrite unreadable data:

```sh
swiftc TeachingTimer/RuntimeDiagnostics.swift Tests/RuntimeDiagnosticsChecks.swift -o /tmp/RuntimeDiagnosticsChecks
/tmp/RuntimeDiagnosticsChecks
```

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

## Class-progress perimeter

The default timer page includes a perimeter treatment for 60-minute classes.
The remaining clockwise segment from the wall-clock minute-hand angle to the
scheduled-end wedge is solid, 2.5 points wide. The elapsed segment is 0.75 points
wide and dashed. This geometric contrast works without color. Both use the same
ray/perimeter geometry as the ticks and stay slightly inside the outer outline.
The existing solid end wedge is drawn above the progress treatment.

Progress is sampled at whole seconds and clamped to the scheduled interval:
before scheduled start the future track is full; at/after scheduled end only
the subdued past track remains. It never wraps into another hour. No context or
a 75-minute duration means no progress track. Hands, snapping, class state,
runtime, metronome, and the timer controls retain their existing behavior.

## Iteration 2 physical SE 3 checklist

- [ ] Seconds remain 1 Hz during active runtime in wrist-down Always-On.
- [ ] Minute hand advances at the same cadence and follows real minutes.
- [ ] End marker and its midpoint emphasis are readable in monochrome.
- [ ] All six landmark groups (1–6 pulses) fire wrist-down; acknowledgement is distinct.
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
