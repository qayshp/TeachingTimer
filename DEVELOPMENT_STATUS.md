# Teaching Timer development status — 2026-10-21

## Usability implementation follow-up

Runtime and landmark journals now share an ordered off-main writer. Runtime
events request immediate queued writes; landmark events retain their 250 ms
batching. A corrupt journal is copied to a uniquely named `.corrupt.*.json`
file before a new journal begins with `journal_recovered`. If preserving it
fails, the original remains untouched. Tests cover recovery, ordering, retention,
and relaunch. A sudden kill can still lose queued events; absence is not a cause.

Count options now include vibrations on/off (next run only), defaulting on, and
an optional minutes-left label, defaulting off. Arc-only runs submit no haptics
and retain the 60-second arc / 64.8-second completion. Delayed haptics still stop
independently, with a crossed-hand icon and "Vibrations off" text. Normal count
results live in Class options rather than lingering on the face. Results persist
as stable enum codes with migration from old English values. Renewal copy
distinguishes an actual handoff from waiting for the wrist to be raised.

Explicit class creation and schedule correction now preserve the initial Start
timestamp on edits and support a fresh class before the retirement grace ends.
Quarter-hour inference remains the default. Model checks cover early preparation,
75-minute correction, persistence, and back-to-back replacement.

The teaching face now reserves a complete inner count track below the system
clock. Its start angle and monotonic progress are unchanged; the track has its
own inset rectangle rather than passing behind controls or a clock mask. Tests
check every half-degree against control bounds (including the start dot) across
eight sizes. Both hands remain foremost, with black edging for contrast.

Class options move to a labeled top-left button. Start opens an editable schedule
with the inferred quarter-hour and 60/75-minute duration. New class explicitly
confirms replacement; editing retains the initial timestamp and active services.
Replacing a class stops the count but preserves an already-running runtime.
End class is confirmed. Session Stop is secondary; manual Resume stays on the
face when needed. Count remains a generous 44-point-or-larger target.

All eight deterministic suites and the locally signed Simulator build pass.
SE 3 40 mm class setup, recovery, and count rendering were exercised in Device
Hub. An unsigned Simulator build was rejected by WatchKit; the signed build's
journal confirms `runtime_started`. Physical Crown focus after sheets and new
class controls still needs testing. No physical Watch installation in this pass.

## Current implementation and evidence

The current app has two pages: the squircle teaching face and native Now Playing.
It remains watchOS-only, without a workout session or iPhone companion app.
Both wall-clock hands draw above controls, with the seconds hand foremost;
arcs remain behind them. Native companion volume and its focus sequence are
unchanged by this review. Class context survives runtime replacements and is
retired 30 minutes after scheduled end; Start establishes the next class.

Counting uses 1–6 haptic groups at 10-second landmarks, 0.8-second pulse spacing,
and `.directionUp`. The inner arc is full at 60 seconds and completes at 64.8.
Late haptic submission stops future haptics but does not cancel the arc. Explicit
Stop/Reset ends both. Journals preserve observed callback/error data without
inferring missing causes. See README for the dated implementation history.

The October 21 review produced, in order: persisted-data/schedule validation;
truthful shorter action/confirmation copy; large-text footer and session-label
layout fixes; extracted production geometry tests plus a fail-fast test runner;
and this evidence reconciliation. No changes were made to runtime renewal,
haptic scheduling, native Crown focus, or foreground seconds-hand geometry.

### Verification matrix for this review

| Simulator | Default text | Largest requested text | Notes |
| --- | --- | --- | --- |
| SE 3 40 mm | Inspected after settling | Inspected | Short Count label; session label wraps within its target |
| SE 3 44 mm | Inspected | Inspected | Labels, marker, and footer fit |
| Series 11 46 mm | Inspected | Inspected | No special geometry branch needed |
| Ultra 3 49 mm | Inspected | Inspected | Same proportional layout; no Ultra-only redesign |

The largest text setting is requested by a DEBUG-only flag; watchOS may cap its
effective sizes. A locked SE 3 render was also inspected in monochrome with the
seconds hand in front and a compact footer. Reset confirmation retains Apple's
native scrollable presentation; at large text sizes scrolling may still be
necessary. A native volume placeholder sometimes appeared late after launch on
the 40 mm simulator and rendered after settling. No paired media source exists
there, so screenshots do not validate playback volume or Crown responsiveness.
The final default-text 40 mm reset capture shows both Reset and Cancel without
scrolling after the body was reduced to “Stops session and count.”

The screenshots in ignored `work/review-2026-10-21/` use simulator-only class and
last-result fixtures, plus actual control taps for the active/locked view. Class
fixtures are generated using the production quarter-hour helper. The visual
matrix is not an automated interaction suite, VoiceOver listening test, measured
battery/performance profile, or a claim that every physical Watch was tested.

`sh scripts/check.sh` passes all eight deterministic suites. The layout suite
covers eight logical screen sizes (40/41/42/44/45/46/49 mm families); the production
geometry suite checks 17,280 rays across three insets. Debug simulator and signed
Release watchOS builds and signature verification pass. The only Release warning
is skipped App Intents extraction because this app does not use App Intents.

### Kept unchanged or deferred deliberately

- Keep the empirically working native volume/focus sequence and foreground hand.
- No geometry cache or observation rewrite: there is no trace-backed performance
  regression established by this review. The 1 Hz render does bounded geometry
  work. Runtime journaling does synchronous event-level writes on MainActor;
  changing durability/ordering needs profiling and is not justified as cleanup.
- Retain dormant circular/clipped source as historical comparison code; there
  are still only two navigable pages.
- App Store readiness (app icon, localization, privacy declarations, distribution
  metadata/review policy) is a separate review, not completed by this code pass.

### Physical checks still required for the review commits

Confirm seconds-hand visibility and 1 Hz wrist-down updates; minute/end-marker
readability; count haptics and independent arc continuation; native Crown volume
after controls, reset cancellation, and returning from Now Playing; automatic
renewal/manual fallback; and class survival/retirement. VoiceOver needs an actual
listening/navigation check. This review was not installed on the user's Watch.
The last installed baseline remains the foreground-seconds-hand build `088744e`.
The subsequent foreground-minute-hand change is a separate commit before the
replayed review work. Review behavior is retained; its comments/notes now reflect
both hands in front. Neither this combined build nor the minute-hand-only build
has been installed on the physical Watch as part of the GitHub push request.

## Archived development checkpoint — 2026-09-11

The material below describes an old checkpoint, not the current count schedule
or current verification status. It is retained as historical evidence.

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
