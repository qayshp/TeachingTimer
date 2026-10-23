# Teaching Timer — current verification

Updated for the October 21, 2026 usability/public-project pass. The older
chronological notes are in [docs/history](docs/history/REVIEW_NOTES.md).

## Implemented

1. Complete inner count track clear of controls and the system-clock region.
2. Confirmable quarter-hour suggestion, ±15-minute correction, 60/75-minute choice.
3. Explicit, confirmed New class before the old class's automatic retirement.
4. Open teaching face; Class management secondary; direct Resume when needed.
5. Both hands foremost with black edging; geometry remains wall-clock based.
6. Visible delayed-vibration warning and optional visual-only count mode.
7. Concise labels, accurate renewal state, optional minutes-left text (off by default).
8. Real app included in archives, with an automated contents check.
9. MPL 2.0 selected by the maintainer, with the full license and source notices.
10. Short current how-to, screenshots, and archived historical documentation.
11. Original app icon, privacy manifest, build number/revision/time identification.
12. Ordered off-main journals with corrupt-file preservation and recovery.
13. CI model/controller/geometry checks, Simulator build, and archive check.
14. `LandmarkController` naming, stable persisted result codes, retired face removal.

## Verified this iteration

- Nine local deterministic suites pass: schedule/persistence/retirement,
  landmark timing/future frames, runtime journal, runtime renewal, landmark
  controller, landmark journal, face layout, ray geometry, and the follow-up's
  volume-control diagnostics.
- Cancellation/restart isolation includes cancelling during groups five and six.
  Arc-only runs submit no haptics. Late haptics preserve the original arc lifetime.
- Layout checks sample 5,760 count-track positions across eight logical sizes,
  including the start dot, against control bounds. Geometry checks cover 17,280
  ray intersections across sizes/insets. They are not pixel-perfect display tests.
- Local signed Simulator build succeeds. An unsigned build was rejected by
  WatchKit; signing the Simulator build produced `runtime_started` in its journal.
- A clean Git source export builds successfully without local project artifacts.
- Unsigned Release archive includes the executable, icon assets, privacy manifest,
  and generated build metadata. This does not validate signed distribution.
- GitHub Actions passed all suites, Simulator build, and archive verification
  for `001ea2c` ([run](https://github.com/qayshp/TeachingTimer/actions/runs/39733429786)).
- Device Hub: SE 3 40 mm face at maximum text size; Series 11 46 mm and Ultra 3
  49 mm layouts; class setup, +15 correction, and the 75-minute picker updating
  the end from 00:15 to 00:30. Active count captures show the clear track on both
  larger sizes. Screenshots are actual simulator captures, not physical evidence.
- Native Now Playing's empty-source "Not Playing" UI was observed. The final
  return-navigation check exposed an intermittent blank-page problem, described
  below; a complete paging pass must not be claimed. Actual paired-iPhone
  transport and restored Crown volume focus require hardware verification.
- SE 3 Lock captures ten seconds apart show the inner arc advancing while the
  hands are monochrome. In that no-runtime run, delayed vibrations stopped and
  the warning appeared while the arc continued. This is not proof of delivery
  guarantees or physical haptic strength. The warning's small-screen fit was
  tightened after this test.
- The final signed SE run also resumed runtime successfully. With runtime
  running, a later locked count still hit the lateness cutoff; its arc continued
  and the narrower monochrome warning stayed inside the clear status lane.
  The recorded missed pulse was about 0.607 seconds late (threshold 0.4 seconds).
  Completion callback arrived at 66.67 seconds; the rendered arc's lifetime is
  independently bounded by its original 64.8-second timeline deadline.

## Physical checks before relying on this iteration

No physical Watch installation was requested or performed in this pass.

- Immediate iPhone Crown volume after Class sheet dismissal, count taps,
  session Stop/Resume, and return from native Now Playing.
- One-second seconds/minute hands and count arc with wrist down.
- Count button reachability while moving; 4–6 pulse groups still countable.
- Geometry-only warning, end wedge, and two arcs readable in monochrome/dim light.
- 60/75-minute scheduling, early preparation, back-to-back class replacement,
  overrun grace, and automatic retirement in real teaching use.
- Runtime expiration/early handoff, foreground-loss recovery, and manual fallback.
- VoiceOver listening/navigation, watch battery impact, and sustained performance.

Earlier SE 3 tests established useful Crown volume, native Now Playing, and
wrist-down hands/arc. They do not prove this new layout/management flow.

## Known limits

**Unresolved blank-page issue, including physical Watch reports:** on the SE 3 watchOS 27 Simulator in
Xcode 27.1 Device Hub, paging can leave an empty black page with the system time
and page dots. It was observed returning from Now Playing after Lock, and also
with the pre-review `84b10eb` build in the same simulator. This comparison does
not establish whether the cause is Simulator, SwiftUI/WatchKit, or an existing
app interaction. A launch displays the face normally. Timeline invalidation,
separating navigation from the timeline, view re-entry, and explicit sizing
did not reliably resolve it; all speculative changes were removed. The original
native volume adapter's behavior was left unchanged; the follow-up below adds
passive instrumentation. On October 21, the maintainer confirmed the same visible
symptom had occurred on a physical SE 3 during one or two earlier classes, with
a paired iPhone. This establishes a real-use report, not only a Simulator issue;
it does not prove the two environments have the same underlying cause. The exact
physical trigger and recovery are not yet recorded.
[Baseline Simulator capture](docs/images/simulator-baseline-blank.png).

**Intermittent timer-page silencing:** the maintainer also reported that Crown
volume changes on the timer page could silence playback at nonzero indicated
levels while native Now Playing could still adjust volume. In the most recent
example, October 21, the iPhone used AirPlay to a WiiM device connected to the
speaker system by an unspecified connection. Raising volume using the iPhone's
own controls restored subsequent volume adjustment on both Watch pages. No
contemporaneous audio-route/volume trace was captured, and whether playback time
kept advancing is unknown. Do not label this a confirmed mute command, routing
fault, pairing failure, or shared root cause with the blank page.

## Interface diagnostics follow-up — October 21, 2026

- Added passive page selection/appearance/disappearance, reduced-luminance,
  scene, class-sheet request-state, and native volume-control lifecycle events
  to the existing bounded, off-main `RuntimeDiagnostics.json` journal.
- Each native control and focus request has a random ID. Requests, API invocation,
  and return are separate events; queued delay uses monotonic time. An older
  queued request after a newer request/removal is logged, not suppressed.
- Native `.companion` origin, focus guard, asynchronous call scheduling, and
  removal-time `resignFocus()` are preserved. No timers, UI recovery, focus
  retries, volume changes, or runtime/landmark behavior changes were added.
- Focus is explicitly `unobserved`; callbacks do not prove visible pixels,
  actual Crown routing, audio volume, or audible sound. There is no per-frame
  logging and no collection of audio-route identifiers or track information.
- The nine-suite check runner now covers passive diagnostic ordering, distinct
  control/request IDs, superseded/post-removal calls, no per-frame events, and
  no runtime state publication or session actions from interface logging.
- All nine local suites pass. Xcode 27.1 signed/ad-hoc Simulator build succeeds;
  the unsigned Release archive also contains the Watch app. A new capture-list
  compiler warning was resolved before final verification.
- SE 3 40 mm Simulator: separately launched teaching and Now Playing pages render
  correctly. Runtime journal reads confirm page callbacks and distinct control/
  request IDs for the existing focus call. Repeated reads of a stationary face
  show no recurring per-second events. Launching directly on Now Playing does
  not create or focus the timer's volume control in this check.
- This was a launch/journal smoke check, not an interactive paging/Lock pass:
  the desktop-control probe stalled and was cancelled without restarting Device
  Hub. Page-transition/dimming capture, physical Crown/AirPlay behavior, and
  reproducing either reported bug remain unverified for this instrumented build.
  No physical Watch installation or fresh device-log pull was performed.

Event names, interpretation, and reproduction details to collect are in
[interface diagnostics](docs/INTERFACE_DIAGNOSTICS.md).

## Remaining evidence boundaries

### October 22 class feedback and quick-start change

The maintainer clarified that during the October 22 class, the media page was
completely black: no useful media information, no skip/pause controls, and no
working Crown volume on that page. The timer and timer-page volume worked.
Playback was Apple Music on the iPhone through AirPlay to the same WiiM receiver.
This is a physical-device observation, not a "Not Playing" empty-source screen.
No fresh Watch journal has been retrieved for this incident, and no media or
navigation fix is claimed. The Watch was reported away from the laptop.

Class creation now opens with a large **Start 60-min class** action showing the
inferred time range. **Custom schedule** reveals the schedule editor and its
separate **Start custom class** action. Custom edits remain isolated from the
default's original inferred time and fixed 60-minute duration. **Back to default**
does not carry custom values into that action. The routine date row is omitted
unless the schedule is on another day. The face's Class control has an outlined
capsule and disclosure chevron. Replacing a class still asks for
confirmation; the exact Start timestamp is recorded only when confirmed.
Quarter-hour inference, runtime renewal, landmarks, and native media/focus code
are unchanged.

Validation: all nine deterministic check suites passed, the watchOS Simulator
Debug build succeeded, and the unsigned watchOS archive check passed. Simulator
screenshots on SE 3 40 mm and Ultra 3 49 mm show the default action, time range,
and adjustment option without scrolling; the existing adjustment form also
renders. Debug-only launch arguments open drafts for these visual checks without
starting a class or runtime. Full interactive confirmation/back-navigation and
largest accessibility text sizes remain unverified: the maximum-text launch
argument did not visibly enlarge this sheet, and Simulator's content-size query
returned unsupported. No physical installation or new Watch-log retrieval was
performed for this change.

Do not describe this iteration as fully validated for real teaching until the
physical navigation/Crown checks above have passed. The existing Watch install
was not replaced during this review.

Mindfulness runtime and OS scheduling are not delivery guarantees. A late pulse
stops further vibrations, not the arc. The arc reaches full at 60 seconds; the
six-pulse group's last submission is scheduled at 64 seconds; its visual endpoint
is 64.8 seconds even if the completion callback arrives late. Confirming a new class
cancels the old count but does not replace an already-active runtime.

Only 60-minute classes use the outer future/past progress line. At scheduled end,
the future portion is empty; the end wedge remains until class replacement or
retirement (scheduled end +30 minutes). There is no automatic new-class start.

Runtime journal writes are queued off main, not synchronously guaranteed at
process kill. A missing callback is not proof of a cause. Existing malformed
logs are backed up before recovery, not discarded. The app makes no network
uploads; raw journals are excluded from public artifacts.

App Store metadata, signed export, and App Review acceptance remain
separate work. No workout fallback or new companion application was added.
