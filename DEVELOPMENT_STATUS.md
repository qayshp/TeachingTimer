# Teaching Timer development checkpoint — 2026-09-11

## PoC version 2

The commit titled `PoC version 2: progress face and perceptible metronome`
supersedes the historical three-page checkpoint below. It has two pages:
the squircle class-progress face (default) and native Now Playing. Only the
baseline comparison page was removed from navigation.

Repeating metronome haptics now use `.directionUp`, with `.start` retained for
activation. The five-second interval and eight-beat limit are unchanged.
Beat-count and next-deadline bookkeeping no longer publish redundant UI changes.
The user reported on their physical SE 3 that this update resolved both the
faint pulses and the seconds-hand hiccup. Because both changes were tested
together, the precise cause of the smoother rendering is not isolated.

Version 2 retains the class snapping, persistent context, scheduled-end wedge,
progress perimeter, runtime renewal/fallback, and visible native Crown-volume
control. The later two-page navigation change still requires device validation;
the long-duration renewal checks listed below remain outstanding.

## Historical checkpoint

This document accompanies the second Git snapshot. It records the implementation
independently of chat history, after the user reported that the iPhone client's
conversation view omitted messages about work following the original POC commit.
The cause of that display/history gap has not been diagnosed.

## Recoverable checkpoints

- `50cc88f` — original usable POC: four pages (two squircle variants, fitted
  circle, native Now Playing), seconds hand, elapsed display, runtime and volume.
- The commit introducing this document — evolved three-page prototype described
  below. Use `git log --oneline` to locate its commit ID.

Both versions are stored in local Git history. No remote backup or publication
is implied by these local commits. Generated build products, screenshots, logs,
Xcode user state, and signing credentials remain excluded by `.gitignore`.

## Implemented in this checkpoint

1. Three horizontal pages: squircle baseline, identical squircle with class
   progress, native Apple Now Playing. The old circular/clipped geometry source
   remains available but those variants are absent from navigation.
2. Real wall-clock seconds and a shorter, thicker minute hand. Both use the
   one-second timeline; no numeric elapsed or remaining-time display.
3. Persistent class context, separate from runtime: exact initial Start timestamp,
   snapped scheduled start, duration, and end. The previous quarter-hour is used
   through minute 12; minutes 13–14 select the upcoming quarter-hour. Default
   duration is 60 minutes; the model also supports 75 minutes.
4. A solid inward end wedge on both timer pages: 8 × 14 points initially,
   9 × 17 after the scheduled midpoint. Runtime replacement never resets it.
5. Page 2 adds a 2.5-point solid remaining perimeter and a 0.75-point dashed
   elapsed perimeter. Progress is clamped to the scheduled interval; completed
   classes never wrap. No progress arc is drawn for 75-minute classes.
6. Independent metronome: immediate `.start` acknowledgement, eight `.click`
   beats at 5–40 seconds, second-tap cancellation, automatic completion. Deadlines
   derive from one monotonic activation anchor. Whole-interval-late execution
   cancels rather than producing a catch-up burst.
7. Automatic mindfulness runtime renewal after expiration when active; deferred
   renewal on return to active state otherwise. Rejected starts are logged and
   have a visible manual restart fallback. Running requires delegate confirmation.
   The policy can be switched to user-initiated. No HealthKit workout is used.
8. Confirmed New Class/Reset clears class context and stops runtime/metronome.
9. Visible native companion volume control restored above the controls. Existing
   asynchronous focus/resign behavior retained; no custom volume indicator or
   Crown gesture binding. The temporary hiding call is absent in this version.

## Verification record

### Prior observed tests during implementation

- Three-page build and launches succeeded in Apple Watch SE 3 40 mm Simulator.
- Each page rendered, including native Now Playing without a source and the
  visible native volume widget. Debug launch arguments were used for page captures.
- Active-class and expired-class progress rendering were inspected.
- Runtime start was confirmed by its delegate in Simulator.
- Class context survived process relaunch and runtime restart.
- Metronome logs showed eight beats over approximately 40 seconds, with the first
  after five seconds; second-tap cancellation and confirmed Reset were exercised.
- Horizontal swipe automation was unreliable; successful rendering of each page
  is not evidence of a completed automated swipe test.
- A physical-watch target compiled during the earlier iteration; this is not a
  signed installation or evidence of device behavior for the final three-page build.

### Checks for this snapshot

On 2026-09-11, the fresh-export watchOS Simulator build succeeded and all
deterministic class checks below passed.

The staged source is exported to a fresh temporary folder and built for the
watchOS Simulator, ensuring ignored local artifacts are not required. The
deterministic class checks cover quarter-hour boundaries, seconds, hour rollover,
75-minute end time, midpoint, persistence, and explicit reset. These checks can
be rerun using the commands below.

```sh
xcodebuild -project TeachingTimer.xcodeproj -scheme TeachingTimer \
  -configuration Debug -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath /tmp/TeachingTimerVerification CODE_SIGNING_ALLOWED=NO build
swiftc TeachingTimer/ClassContext.swift Tests/ClassContextChecks.swift \
  -o /tmp/TeachingTimerClassChecks
/tmp/TeachingTimerClassChecks
```

## Physical SE 3 checks still required for this checkpoint

- One-second wrist-down seconds/minute hand updates during runtime.
- Monochrome readability of the end wedge and future/past perimeter treatment.
- Immediate Crown volume response with restored visible native feedback;
  focus retention after controls and returning from Now Playing.
- Eight wrist-down metronome beats, distinct acknowledgement, cancellation, and
  large-button usability with sweaty fingers.
- Real approximately 60-minute renewal boundary, including inactive/rejected
  renewal and manual fallback; class context must remain unchanged.
- Horizontal paging and Now Playing playback on the updated build.

The user previously reported successful Crown routing, Now Playing, focus return,
and sustained one-second wrist-down updates during runtime on the earlier POC.
Those are baseline observations, not validation of the evolved checkpoint.
No physical-Watch installation of this checkpoint was performed by the agent.
