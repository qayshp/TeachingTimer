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
9. Copyleft license **pending maintainer selection**; no license silently chosen.
10. Short current how-to, screenshots, and archived historical documentation.
11. Original app icon, privacy manifest, build number/revision/time identification.
12. Ordered off-main journals with corrupt-file preservation and recovery.
13. CI model/controller/geometry checks, Simulator build, and archive check.
14. `LandmarkController` naming, stable persisted result codes, retired face removal.

## Verified this iteration

- Eight local deterministic suites pass: schedule/persistence/retirement,
  landmark timing/future frames, runtime journal, runtime renewal, landmark
  controller, landmark journal, face layout, and ray geometry.
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

**Unresolved Simulator navigation issue:** on the SE 3 watchOS 27 Simulator in
Xcode 27.1 Device Hub, paging can leave an empty black page with the system time
and page dots. It was observed returning from Now Playing after Lock, and also
with the pre-review `84b10eb` build in the same simulator. This comparison does
not establish whether the cause is Simulator, SwiftUI/WatchKit, or an existing
app interaction. A launch displays the face normally. Timeline invalidation,
separating navigation from the timeline, view re-entry, and explicit sizing
did not reliably resolve it; all speculative changes were removed. The original
native volume adapter is byte-for-byte unchanged. Physical reproduction remains
unknown. [Baseline capture](docs/images/simulator-baseline-blank.png).

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

App Store metadata, licensing, signed export, and App Review acceptance remain
separate work. No workout fallback or new companion application was added.
