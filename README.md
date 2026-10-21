# Teaching Timer watchOS proof of concept — version 2

## Review follow-up (October 21, 2026)

Saved class contexts now validate duration (1–1440 minutes, a sanity bound rather
than the Watch runtime limit) and usable dates when decoding. Invalid bytes are
left intact until an explicit Start replaces them; the UI treats them as no
class. Landmark configuration rejects non-finite or over-one-day schedules before
creating deadlines. Valid 60/75-minute classes and the 10-second landmark preset,
quarter-hour anchoring, foreground seconds hand, and Crown focus are unchanged.

Copy now distinguishes Start session (no successful start) from Resume session
(a previously running session), with Starting… while the action is disabled.
Reset confirmation uses a shorter body and Reset button; VoiceOver describes six
ten-second landmarks without confusing the 60-second arc with its 64.8-second
completion. Existing diagnostic keys, errors, and persisted result text are kept.

## Foremost seconds hand (October 21, 2026)

The seconds hand and center pivot now draw above all teaching-face controls and
status text, restoring continuous visibility across their opaque backgrounds.
The same clock view renders separate dial/hand layers from the same timeline
date; its geometry, whole-second cadence, color, and display clipping are
unchanged. Class/count arcs and the scheduled marker stay behind controls; the
later foreground-minute-hand follow-up below also brings the minute hand forward.
The foreground hands disable hit testing and the background dial is
hidden from accessibility to avoid duplicate seconds-hand announcements.
Native volume creation/focus and all session/class/haptic logic are unchanged.

Verified Debug simulator and signed Release builds, signature validation, and
eight-size layout checks. SE 3 40 mm screenshots confirm the hand crosses the
count/session/status regions and the count and reset controls still respond.
Artifacts are ignored under `work/validation-2026-10-21-foreground-hand/`.
Physical Always-On and Crown regression validation remain necessary.

## Readability third pass (October 20, 2026)

The native companion volume control receives a white resting tint using
WatchKit's `setTintColor` API. A static 38-point black circle behind it prevents
clock/arc strokes from crossing its center; this is not a custom volume display.
The native control, its frame, companion origin, and asynchronous focus/resign
sequence are otherwise unchanged. Apple applies the tint only to the resting
state; system Crown-adjustment feedback and unavailable-source dimming remain
system-owned. The simulator has no paired media source, so physical playback
appearance and instant Crown responsiveness still require Watch validation.

The reset glyph now has a screen-proportional 20–25-point size independent of
Dynamic Type; its existing 44-point-or-larger target remains unchanged. Footer
lines have two scaled points of separation and six scaled points of horizontal
padding within the existing reserved black status region. No runtime, class,
count, navigation, or hand geometry behavior changed.

Verified Debug simulator and signed Release watchOS builds, signature validation,
and eight-size layout checks including volume-backing clearance and reset glyph
proportion. Simulator screenshots cover SE 3 40 mm accessibility text and Ultra
larger text under `work/validation-2026-10-20-third-pass/` (ignored).
No physical Watch installation was performed.

## Readability second pass (October 20, 2026)

The background squircle outline is now 0.75 points rather than 1.5, with lower
brightness. The 2.5-point future-class track, dashed past track, ticks, and filled
scheduled-end wedge are unchanged, preserving a geometry-based hierarchy in
monochrome. The reset button now uses a counterclockwise arrow rather than an
ellipsis; its target, accessibility label, and confirmation are unchanged.
Count labels try full text, then short “Count” / “Stop” text, then the icon,
without reducing the existing scaled text or touch target.

Only the inner landmark arc and its start dot are clipped beneath a tunable
upper-right system-clock quiet zone in `TimerFaceLayout`. This is an approximate
screen-relative rectangle, not a claim that watchOS exposes the clock's frame.
The arc retains its original monotonic anchor, start angle, and full progress;
it continues invisibly behind the quiet zone and reappears beyond it. Hands,
outer class progress/end marker, and native volume are not clipped or changed.

Verified simulator and signed Release builds and all seven deterministic suites.
The layout suite now checks the quiet zone across eight screen sizes. Device Hub
checks include 40 mm accessibility-size short-label rendering, Ultra larger-text
rendering, reset confirmation, and arc exclusion as the arc passes the system
time. Screenshots are ignored under `work/validation-2026-10-20-second-pass/`.
Physical readability and Crown regression validation remain pending; no physical
Watch installation was performed.

## Readability first pass (October 20, 2026)

Count, session, and reset controls now have opaque black backing so clock hands
cannot cross their labels. The active count outline is reduced from 3 to 2 points;
the inactive outline remains 1 point. The existing reserved status area also has
opaque black backing to separate its two text lines from hands, ticks, and arcs.
Control positions, dimensions, touch targets, dial geometry, timing, haptics, and
the native companion volume/focus implementation are unchanged.

Verified Debug simulator and signed Release watchOS builds, plus layout checks
for eight Watch sizes. Device Hub screenshots cover SE 3 40 mm and 44 mm, and
Ultra 3 49 mm with larger text, including locked monochrome views. The small
locked screen also showed the two-line haptic-stop status with the arc continuing.
Artifacts are ignored under `work/validation-2026-10-19-readability/` (the test
crossed midnight). These are simulator layout checks, not renewed physical Crown,
haptic, or Always-On validation. No installation on the physical Watch was made.

## Automatic class retirement (October 19, 2026)

An old class now clears automatically **30 minutes after its scheduled end**.
For a 1:15–2:15 class this is 2:45: 90 minutes from the scheduled start, not
exactly 90 minutes after the initial tap. A 75-minute class gets its full interval
plus the same grace (105 minutes from scheduled start). The constant lives in
`ClassContext.retirementGraceMinutes`; quarter-hour snapping is unchanged.

Retirement stops the runtime, suppresses pending automatic renewal, stops any
count, removes the persisted context/end marker, and presents Start class.
It never silently starts or infers the next class. Only the next Start creates
a fresh context. Reset class remains available for back-to-back classes before
the grace window ends. Ordinary session Stop/Resume during the interval continues
to preserve class timing; the one-hour WatchKit runtime limit is separate.

A cancellable task waits for the deadline, with checks on appearance, return to
active, clock changes, and before a session-button action. All checks use actual
Date(), never future Always-On frame dates. Clock changes reschedule the wait.
watchOS may suspend or delay the task; cleanup then occurs on return before old
foreground-recovery intent is processed. This is not a background wake guarantee.
The cutoff is idempotent, also handling persisted contexts from previous days.

The runtime journal records `stop_requested` with source `class_retired`, exact
initial/scheduled dates, duration, deadline and actual retirement time. Active
counts record `landmark_ended` with reason `class_retired`. Existing journal data
is retained across retirement.

Verification: all seven deterministic suites and Debug simulator / signed Release
builds pass. New checks cover the exact cutoff, grace, repeated checks, persistence,
fresh Start, 75-minute protection, and cancellation of deferred runtime recovery.
In Device Hub (SE 3 44 mm), simulator-only persisted-context fixtures placed the
deadline seconds away: active session/count stopped at the cutoff, Start created
fresh timing, returning from background cleared old timing without renewing it,
and a cold launch on Now Playing also cleared a stale context. This exercised the
normal lifecycle with synthetic dates, not a 90-minute wall-clock endurance test.
Physical validation is pending; no build was installed on the user's Watch.

## Copy review (October 19, 2026)

User-facing language distinguishes scheduled **class** timing, the keep-active
**session**, and the one-minute **count**. Start/Stop count replaces the ambiguous
Landmarks label. Session controls say Start class, Stop session, or Resume session;
short status/error messages describe the state without repeating a potentially
truncated instruction. Reset class asks before ending the session/count and
clearing timing. Count results use concise “taps” language, while VoiceOver hints
explain the vibrations and actions. The native Now Playing copy is Apple's UI.
Technical runtime/haptic names, raw errors and journal keys are unchanged.
Previously saved count-result wording is translated on load. This is an English
copy pass, not a localization implementation or a change to haptic scheduling.

Verified: simulator build, deterministic landmark-controller checks, and live
SE 3 44 mm active/reset screens in Device Hub. Screenshots are ignored artifacts
under `work/validation-2026-10-19/`.

A watchOS-only app for Apple Watch / watchOS 26 and later. It tests a one-hour
mindfulness extended-runtime session, a wall-clock-derived teaching timer,
second-stepped analog hand, paired-iPhone Crown volume, and native Now Playing.

## Adaptive layout pass (October 18, 2026)

The teaching face now derives control widths, heights, and positions from available
screen points using `TimerFaceLayout`, rather than fixed 40 mm offsets. Larger
screens gain modestly larger controls; runtime/reset targets remain at least
44 points and the landmark control remains oversized. Status text is larger and
reserves fixed space so state changes do not shift touch targets. Action labels
respond to Dynamic Type; landmark/runtime labels use symbol fallbacks when text
does not fit, retaining explicit VoiceOver labels. The active haptic-failure
message is shortened visually with the full result retained for VoiceOver.
The reset confirmation uses shorter copy on the smallest display. Status text still
uses compact fixed fonts: this is not full large-text accessibility support.

The dial, clipped boundary, class progress and landmark arc use one size-adjusted
corner-radius approximation. Physical curvature remains tunable, not exact.
VoiceOver can read the minute-hand time and scheduled end without adding visible
digital time. The native companion control's focus/resign implementation, timing,
runtime renewal, class snapping, haptic policy and Now Playing are unchanged.

Layout arithmetic checks span eight logical screen sizes (162×197 through
211×257 points), verifying control separation, edge clearance and action targets:

```sh
swiftc TeachingTimer/TimerFaceLayout.swift Tests/TimerFaceLayoutChecks.swift -o /tmp/TimerFaceLayoutChecks
/tmp/TimerFaceLayoutChecks
```

Xcode 27.1 initially encountered an old CoreSimulator 1171.7 framework. Running
Apple's first-launch component installer with user-supplied administrator approval
updated it to 1174.9.2. Restarting Device Hub after the update restored its screen
view; native accessibility plus pointer input allowed live interaction testing.
No simulator erasure or physical-device installation was involved.

Simulator validation on watchOS 27.0:

| Device | Checks |
| --- | --- |
| SE 3 40 mm | Idle/active layout, Start, landmarks, reset confirmation/reset, locked arc progression |
| SE 3 44 mm | Idle/active layout, native volume feedback, reset/cancel confirmation and reset, page indicator |
| Series 11 46 mm | Accessibility text fixture, Start/Stop, landmarks/cancel, swipe to Now Playing and back, class marker retained after Stop |
| Ultra 3 49 mm | Large text fixture, Start/Stop, landmarks/cancel, swipe to Now Playing and back |

The SE's locked run retained its arc after the existing late-pulse cutoff stopped
haptics and later logged completion. Simulator completion callbacks can arrive
late while inactive (observed 64.9s and 68.1s); this is not a precise haptic-delivery
or frame-cadence guarantee. The existing projected visual lifetime is unchanged.
Now Playing correctly rendered its native no-source state. Screenshots/journals
from this pass are local ignored artifacts under `work/validation-2026-10-18/`.

`simctl ui content_size` and Increase Contrast return unsupported for this watch
runtime. Debug-only launch arguments `--large-text` and `--accessibility-text`
instead set SwiftUI's `.xxxLarge` and `.accessibility3` environments respectively;
they trigger no runtime or haptic actions and are absent from Release behavior.
For example, after installing the Debug build on a simulator:

```sh
xcrun simctl launch --terminate-running-process WATCH_SIMULATOR_ID com.qayshp.TeachingTimer --accessibility-text
```

On hardware, recheck volume feedback and immediate Crown focus after controls,
reset dismissal and Now Playing, plus reduced-luminance clarity. Longer localized
labels and full VoiceOver/large-text acceptance remain follow-up work.
This pass does not add duration settings, localization, onboarding or media
availability handling. The installed Watch build is still the prior checkpoint.
All seven deterministic check suites, simulator Debug build, and signed watchOS
Release build passed before committing. The Release build excludes text fixtures.

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
forwards. Runtime Stop/Resume never changes an unexpired context. The ellipsis button
opens a confirmation before Reset clears the context and cancels both services.

The inward triangular end marker uses the scheduled end minute and the existing
perimeter intersection geometry (or the fitted circle radius). It grows modestly
from an 8-point-wide, 14-point-deep solid white wedge to 9 points wide and
17 points deep at the scheduled midpoint. Its initial filled area is roughly
twice that of a major tick; emphasis relies on shape and size, not opacity.
It persists through the scheduled end and across process relaunches until Reset
or automatic retirement 30 minutes after the scheduled end.

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

After class, connect the development Watch and retrieve the file using
Xcode's device container facilities or `devicectl`. Transfer succeeded from the
locked, charging physical SE 3 on September 19; unlock only if the connection
requires it, and do not launch or reinstall just to collect the journal:

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
`willExpire` records renewal intent. While active, within the last 20 seconds of
the known expiration and after that warning, the app may request an early handoff:
invalidate the old session, wait for its normal-end callback, then start a new one.
It never starts overlapping sessions or changes class context/landmarks. There
may be a gap and the replacement can fail; chaining is experimental.

Normal expiration and `resignedFrontmost` remain renewable. A narrowly qualified
expiration-associated error is also eligible: the same running session must have
received the warning, and `RBSAssertionErrorDomain` code 1 must arrive between
2 seconds before and 30 seconds after its known expiration. The original error
name/raw values are retained; internal assertion reason 4 is not interpreted.
This addresses the September 18 physical log: expiration warning at 19:47:12 PDT,
expiration at 19:47:27, then error invalidation at 19:47:28 rather than `.expired`.
Other errors retain the manual fallback. No warning or no confirmed start means
this special recovery is not eligible.

If inactive, renewal is logged as deferred,
the Restart control remains available, and the next active scene transition
attempts it. A rejected replacement logs its error and requires manual restart;
there is no unbounded retry loop. Running is shown only after `didStart`.
Explicit Stop cancels renewal intent. Class context is never owned by the runtime.
Returning to an active TeachingTimer scene after losing frontmost status attempts
a replacement automatically; this does not reset class context or landmarks.
If the active transition arrives before invalidation, the invalidation handler
also checks current application state so the restart is not missed. Restart
evaluation and automatic attempts are journaled. Other invalidation reasons retain
the manual fallback. This intent is in-memory only, not restored after process
termination.

Early-handoff requests, eligibility decisions, parent/replacement runtime IDs,
deferred starts, confirmed successes and rejected starts are journaled. Stop/Reset
wins even during a handoff or an in-flight start. Failed replacements do not
automatically retry. The new paths have deterministic controller tests using
WatchKit boundary doubles; they still require an actual hour-boundary Watch test.

## Landmark diagnostics (September 19, physically exercised)

`Documents/LandmarkDiagnostics.json` is a separate 2,000-event bounded journal.
It records run IDs, configuration, acknowledgement and timed haptic submissions,
scheduled/actual monotonic elapsed time, lateness, haptic name/raw value, and
explicit visual-run end reasons: `completed`, `user_cancelled`, `new_class_reset`,
or `class_retired`.
A missed deadline now records a separate `landmark_haptics_stopped` event with
reason `missed_deadline`; it does not end the visual run. Runtime ID/phase, scene state and application state are captured
for correlation. A submission is not proof of physical vibration delivery.

Loading, batching (250 ms), JSON encoding and atomic writes run on a utility serial
queue, not the haptic submission actor. End events request an immediate queued
flush. A sudden process kill/suspension can still lose the newest unwritten
events; a missing end event means unknown outcome, not a diagnosed cancellation.
Unreadable existing history is preserved and the write failure is logged.

The small secondary status area keeps runtime status and adds the last count
result, retained across relaunch and cleared on the next activation. There is no
new haptic, countdown, Crown binding, or touch target. The original `.directionUp`
pattern, 0.8-second spacing, absolute deadlines, >=0.4-second cutoff for further
haptics, 21 pulses in a successful run, and 64.8-second completion remain unchanged.
After a missed deadline the original arc continues with `Stop count` still usable
and `Taps off · arc continues` in the secondary status area. It reaches full
extent at 60s and clears at 64.8s even when haptics stopped earlier. Stop/Reset
immediately cancels both. Completion preserves the fact that haptics stopped.
Tests cover cancellation during groups 5 and 6 followed by immediate restart:
not-yet-submitted old-generation pulses must never leak into the new run.

### Landmark frame projection (Always-On fix)

The former arc getter sampled `ContinuousClock.now` while evaluating a view, so
future frames prepared in the same batch could all receive almost the same arc
progress. The hands instead used the requested timeline date. Apple's
[watchOS timeline guidance](https://developer.apple.com/documentation/watchos-apps/updating-watchos-apps-with-timelines)
explicitly requires using that date and notes future batching in Always-On.

The arc now projects each requested frame from a freshly paired wall/monotonic
sample: `frameElapsed = monotonicElapsedNow + (frameDate - wallNow)`. It never
derives elapsed time from the initial wall-clock start. Clock corrections affect
both wall dates equally; the original monotonic anchor and snapped starting angle
remain unchanged. Future frames also hide the arc after the original 64.8-second
finish even if the completion task has not yet run. System-clock-change and visual
run state changes invalidate cached timeline content. No extra repeating timer,
high-frequency animation, or change to the clock hands is introduced.

Deterministic tests cover future frame batches, minute rollover, positive/negative
clock corrections, haptic-failure visual continuation, and explicit Stop/Reset.
The updated app builds/launches on SE 3 40mm / watchOS 27 Simulator. On September
19, the user manually tested Device Hub Lock and reported that the arc continued
while locked, including when haptics stopped. The same build was installed on the
physical SE 3 without assistant-initiated launch; the user then confirmed that the
wrist-down arc worked while haptics stopped. These are user-observed visual
results, not an independently measured display cadence or proof of the original
rendering mechanism. Device Hub automation remains unreliable after the bounded
quit/reopen investigation; assisted testing supplied the practical validation.

Physical journals from the 12:11:25 PDT run confirm the first timed pulse was
submitted at 10.380 seconds. At the next landmark, the deadline check was about
0.457 seconds late, beyond the unchanged 0.4-second cutoff: that pulse was not
submitted and remaining haptics stopped. The visual run remained active until
the user cancelled at 40.082 seconds. The mindfulness runtime stayed running
throughout and was explicitly stopped afterward. This verifies separate haptic
and visual lifecycles; it does not establish that watchOS physically delivered
every submitted haptic.

The arc-reliability goal was accepted as complete by the user on September 19.
Remaining follow-up validation: observe an entire wrist-down run after haptic
failure through the 60-second full arc and 64.8-second completion, and explicitly
check for any corrective jump on unlock. Those endpoints and clock-correction
behavior are covered deterministically, but not yet by a full physical run.
Whether to relax the haptic lateness policy is a separate product decision;
this change intentionally preserves the existing cutoff and haptic pattern.

Retrieve this journal using the runtime copy command with
`--source Documents/LandmarkDiagnostics.json` and a separate destination.

Additional deterministic checks (macOS; no real Watch/haptics):

```sh
swiftc -D CONTROLLER_CHECKS TeachingTimer/RuntimeDiagnostics.swift TeachingTimer/RuntimeRenewalRules.swift TeachingTimer/ExtendedRuntimeController.swift Tests/RuntimeRenewalChecks.swift -o /tmp/RuntimeRenewalChecks
/tmp/RuntimeRenewalChecks
swiftc -D CONTROLLER_CHECKS TeachingTimer/LandmarkDiagnostics.swift TeachingTimer/MetronomeController.swift Tests/LandmarkControllerChecks.swift -o /tmp/LandmarkControllerChecks
/tmp/LandmarkControllerChecks
swiftc TeachingTimer/LandmarkDiagnostics.swift Tests/LandmarkDiagnosticsChecks.swift -o /tmp/LandmarkDiagnosticsChecks
/tmp/LandmarkDiagnosticsChecks
```

Follow-up physical checks include readability of the two-line status area on
SE 3 40 mm; early warning while active and inactive; lowering the wrist
during handoff; Stop/Reset suppressing restart; manual fallback after rejection;
class-context and landmark continuity; journal readability after class; Crown
response after landmark/runtime controls and Now Playing.

Physical SE 3 validation on September 16, 2026 confirmed four automatic restart
attempts, all followed by delegate-confirmed starts approximately 107–128 ms
after the recorded active-scene transition. Each followed `resignedFrontmost`
invalidation and deferred while inactive; ordinary inactive/active transitions
did not replace a still-running session. No rejected starts were recorded in
that test. The user confirmed this resolves having to remember to press Start
after returning from a media app that took focus; the journal does not identify
which app took foreground. Explicit Stop/Reset followed by leaving/returning
was not exercised in this updated-build log, and hour-boundary renewal remains
unvalidated. September 19 landmark-arc validation is recorded above; it does not
validate the new hour-boundary renewal paths.

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

## Foreground minute hand (October 21, 2026)

The minute hand now draws above teaching controls and native volume, but below
the seconds hand. It remains the same shorter, six-point white hand at
`minute + second / 60`, using the existing one-second timeline. Its overlay is
noninteractive and adds no duplicate accessibility element. Dial arcs, markers,
control dimensions, focus routing, and session/count logic are unchanged.
