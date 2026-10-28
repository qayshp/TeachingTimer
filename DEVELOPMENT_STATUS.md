# Teaching Timer — current verification

Updated October 28, 2026. Historical observations are kept separately so that
previous build states do not read as current facts.

## Roadmap 22–25 — candidate build 19, comparison and tester preparation

The physical Watch remains on **build 16**. No physical-device query, install,
launch or log collection was performed. Current source is **build 19**.

22. Checked the installed runtime gate for the isolated hand-transition probe.
    Xcode 27.1 still has watchOS 27.0 SDK/runtime (24R362); there is no newer local
    Watch runtime for a useful comparison. Hardware work is deferred.
    [Recorded limit](docs/ALWAYS_ON_HAND_TRANSITION.md).
23. Mechanically [split shared presentation](docs/VIEW_SPLIT.md) into class UI,
    button style, refresh UI and WatchKit adapter files. Stable view identity,
    shared state, native lifecycle and focus order are preserved. All twelve
    Swift suites, 40 Python checks, Simulator build and both unsigned archives
    pass. SE 3 and Ultra pass all 14 action assertions; SE 3 passes all six focus
    lifecycle assertions. These do not certify pixel rendering or phone audio.
24. Added a [tester guide](docs/TESTER_GUIDE.md), [privacy/diagnostics explanation](docs/PRIVACY.md),
    [distribution metadata draft](docs/DISTRIBUTION_METADATA.md), actual
    [build 16 versus 19 screenshots](docs/BUILD_16_VS_19.md) and a
    [usability review](docs/USABILITY_REVIEW_BUILD_19.md). No TestFlight upload or
    invitations; signed install/update/journal access and physical validation
    remain pilot gates.
25. [Updated FB25305069](docs/APPLE_MEDIA_UPDATE_2026-10-28.md) with the four
    unsuccessful media-recovery experiments, delayed captures, source variants
    and bounded lifecycle evidence. Upload completion was verified. Other
    reports had no meaningful new evidence and received no duplicate updates.

**Visual caveat:** comparison captures show the Class control missing in one
awake build-16 SE 3 frame and Stop count missing in one awake build-19 Ultra
frame. Both reappear in subsequent Lock captures. Duration and touch response
are unknown; similar timer-control failures predate the refactor. No new fix
for blank media, timer rendering, volume silencing or hand backstep is claimed.
The review recommendations are not implemented changes.

## Roadmap 18–21 — tests, automation and public tracking

Completed without changing the production app's teaching/session/media behavior.
The physical Watch remains on its last verified **build 16**; no physical-device
installation, launch or diagnostic collection was performed in this batch.

18. Added [time-edge regression checks](docs/TIME_EDGE_TESTS.md): DST gaps/folds,
    fractional timezones, year rollover, persisted instants, retirement boundaries
    and clock-correction-independent landmark projection. All twelve Swift suites pass.
19. Added a [bounded essential-action UI suite](docs/ESSENTIAL_ACTION_CHECKS.md).
    SE 3 40 mm and Ultra 4 49 mm each passed all 14 state assertions; final
    reviewed captures rendered the expected menus, native Not Playing and timer.
    An earlier SE 3 timer-return capture again lacked controls despite retained
    class/page state. The intermittent rendering problem remains open.
20. Added [build/release evidence automation](docs/BUILD_VERIFICATION.md), retained
    failure logs and toolchain/source metadata, archive/symbol inspection and a
    separate signed-artifact gate. The local ad-hoc Simulator build and both
    unsigned archives pass. All 40 Python tooling tests pass. Untracked source
    now marks generated revision metadata dirty; ignored artifacts do not.
21. Created [six public issues](docs/ISSUE_TRACKER.md) and a concise bug-report
    form, linking five submitted Apple reports and keeping silencing draft-only.
    No new Apple submission or report update was made in this batch.

At completion of that batch, source was build 18. Those tests do not establish
actual iPhone volume response, physical haptic delivery or a fix for intermittent native UI.
The two disposable Watch simulators remain running for manual inspection.

## Media recovery follow-up — production behavior unchanged

The [October 26 recovery comparison](docs/MEDIA_RECOVERY_COMPARISON.md) tested
stable page identity, a 300 ms native teardown gap, clock-only timeline placement,
and conditional native-view lifetime. None established reliable recovery; all
experimental app edits were removed. Longer-wait captures confirm persistent
blank frames as well as transient loading. Only the regression tooling and
investigation documentation changed; that batch retained build 18 and did not
install on the physical Watch. The native service-loss reproduction still
warrants further isolation. It was subsequently included in the
[October 28 Apple follow-up](docs/APPLE_MEDIA_UPDATE_2026-10-28.md).

## Build 18 — second reliability/tooling batch (not installed)

Completed October 26, 2026:

6. Class/runtime-intent persistence distinguishes absent data from decoding or
   encoding failures, preserves unreadable preferences locally, and reports
   metadata through the existing journal. [Details](docs/PERSISTENCE_DIAGNOSTICS.md).
7. Removed unreachable live haptic-stop state/warnings while preserving decoding
   and explanation of older saved outcomes. No haptic timing change.
8. Added [bounded Simulator regression captures](tools/simulator-regression/README.md)
   for Home/refresh/media return and deliberate native media-service loss.
9. Added a separate [native volume probe](tools/native-volume-probe/README.md)
   with retained/replacement control and immediate/delayed setup comparisons.
10. Prepared the future `net.qays.TeachingTimer` identity using the maintainer's
    qays.net domain, keeping the installed development identity unchanged.
    [Unsigned archive rehearsal and pilot gates](docs/TESTFLIGHT_PREPARATION.md).

All eleven Swift suites and 32 Python tooling tests pass. The Debug Simulator
build and unsigned distribution-identity Release archive pass. The volume probe
builds/runs on SE 3 40 mm, and both refresh modes have the expected lifecycle
journal events. No real companion-volume success is inferred from those events.

**New visual evidence:** after deliberately terminating the native media view
service in the isolated simulator, first reopen rendered Not Playing, but a
subsequent media entry stayed black through the five-second delayed capture.
The automatic reload request was recorded. Another entry rendered normally in
the first run. The mitigation is therefore not a complete visual fix for this
fault sequence. Saved class bytes and the app host survived; Home invalidated the
runtime with `resigned_frontmost`, and automatic recovery restarted it. Physical
blank-page causation remains unknown. Source behavior was not changed to hide
this failure. The unpaired volume ring showed no change during Crown tests, so
actual focus/phone volume remains unverified.

No physical installation, TestFlight upload or Apple report submission occurred
in this batch. The physical Watch's last verified installed build remains **16**.
Private evidence is under `work/support/2026-10-26-second-batch/` on the development
Mac. The disposable regression simulator remains running for manual inspection.

## Build 17 — diagnostics retention (not installed)

Operational history remains seven days / 10,000 events. Wake/dim detail now keeps
seven days / 10,000 events; landmarks keep seven days / 20,000 events. No session,
media, Crown, haptic or rendering behavior changed. The seven-day/21-class stress
checks and all eleven suites pass; a Debug Watch Simulator build succeeds.
See [retention audit and limits](docs/JOURNAL_RETENTION.md).

## First diagnostics/tooling batch

Completed locally, October 26, 2026:

1. Original installed build 16 and matching symbols preserved privately; signed
   archive reconstructed separately; immutable teaching source tag pushed.
2. Current status separated from historical reports, including build-16 physical
   installation and the maintainer's positive usability feedback.
3. Seven-day retention checked for all three journals; build 17 extends detail
   and landmark bounds without changing teaching behavior.
4. Bounded journal-copy/install tool records each attempt, validates copies and
   installed versions, and keeps launch separate. It does not auto-repair devices.
5. Local summary tool correlates supplied journals without inventing focus,
   rendering, audio, haptic delivery, or missing-event causes.

[Tool usage and limits](docs/DIAGNOSTIC_TOOLS.md). All 29 Python tooling tests pass
using a fake command boundary; no physical operation was performed in this batch.
The summary was also checked against a real saved build-12 incident. Eleven
Swift suites and the build-17 Simulator build passed. Live execution of the new
device tool remains to be checked during the next requested collection/install.
The physical Watch's last verified installed build remains **16**.

## Teaching baseline and deployment

**Build 16 (1.0), source `e5e5ab4`, was installed and launched on the physical
Apple Watch SE 3.** The saved installed-app query confirms build 16. The first
attempt failed despite an awake, unlocked Watch on top of the laptop; the retry
succeeded without re-pairing or restarting. A shorter command timeout on retry
is not a diagnosed remedy. No new installation is implied by this document.

The maintainer has since tested the usability changes on the Watch and reports
that the app is noticeably clearer and easier to understand. This is positive
physical usability feedback, not proof that the remaining intermittent bugs
are fixed. The exact app, symbols, signing information and deployment evidence
are preserved privately; see [the teaching checkpoint](docs/TEACHING_CHECKPOINT.md).

## Current behavior

- Two pages: teaching face and native Apple Now Playing. No iPhone companion.
- Wall-clock seconds and minute hands stay above controls. The scheduled-end
  wedge remains; the future/past perimeter is used only for 60-minute classes.
- Start class uses a fixed 60-minute default and quarter-hour suggestion.
  Custom schedule edits are separate; Cancel discards the draft. Class options
  use explicit outlined/solid buttons, and Stop/Resume returns to the face.
- Class schedule persists independently of runtime. Eligible reopening resumes
  intended-running sessions; intentional Stop survives reopening. Class retirement
  is scheduled end +30 minutes, not an automatic new-class start.
- Count arcs use monotonic elapsed time. Six haptic groups start at 10-second
  intervals; the sixth begins at 60 seconds, its last pulse is scheduled at 64
  seconds, and visual completion is 64.8 seconds. Late pulses retain spacing;
  obsolete groups are skipped without disabling later groups. Visual-only mode
  remains available. The former run-wide timeout warning is no longer current.
- Native companion volume is retained through refresh/background return, with
  one guarded 250 ms refocus cycle. Media-to-timer focus remains immediate.
- Native media refresh happens on page entry and eligible background return,
  not ordinary wrist wakes. Build 16 removed the redundant Reload media menu item.
  Refresh is preventive; it does not detect a black view or verify its recovery.

## Verified evidence and limits

- All eleven deterministic Swift suites passed for build 16. Debug and Release
  Simulator builds succeeded. These are standalone model/controller checks,
  not an Xcode UI-test target or physical audio tests.
- Menus/layouts were checked across eight available Watch geometries. Maximum-text
  confirmation included SE 3 40 mm, Series 12 42 mm and Ultra 4 49 mm. SE 3
  interaction checks covered Stop/Resume, schedule Cancel/Save and page/focus
  lifecycle. See [the usability review](docs/USABILITY_REVIEW_2026-10-26.md).
- Retaining the volume widget avoided the controlled Simulator focus regression.
  Focus-call returns and animated native feedback do not prove phone-volume
  commands, audible playback, or actual Crown ownership.
- Recreating native Now Playing recovered two deliberately induced Simulator
  service-loss failures. Physical blank media has occurred during classes;
  force-closing/reopening recovered it in user reports. Two later successful
  classes are encouraging but do not establish a permanent fix.
- The count arc advances in reduced luminance in Simulator and physical reports.
  Simulator haptic submissions/chimes are not proof of physical delivery or
  countability. The revised late-pulse policy still needs teaching validation.
- The clock-only probe reproduces the Always-On hand backstep in Simulator.
  A similar physical symptom is reported; no hand fix has been established.
- A signed build-16 archive was reconstructed for preservation. Its signature
  validates, but it is not an App Store/TestFlight export or review approval.

## Open investigations

| Issue | Current mitigation / next evidence |
| --- | --- |
| Timer volume unavailable or silent | Retained native control and bounded refocus; physical volume-only comparison remains needed. Returning API calls never prove audio recovery. |
| Black native media | Automatic view refresh; collect any recurrence and compare standalone Now Playing when practical. |
| Hand backstep on dim | Minimal probe available; retain evidence for Apple rather than adding speculative clock corrections. |
| Watch developer connection | Bounded retries and separate transfer verification; awake/unlocked/nearby is not sufficient or a proven universal transfer requirement. |
| Paired Simulator media | No working iPhone-to-Watch control baseline; cannot validate physical volume there. |

The original blank **timer return** in Simulator is distinct from physical black
**media** reports; a common cause is unproven. Silencing has occurred with both
AirPlay and USB audio while playback continued. A recorded zero-volume command
is useful evidence, but does not by itself explain the initiating fault.

[Apple feedback status](docs/APPLE_FEEDBACK.md) lists five submitted reports and
one silencing draft, with remaining capture gaps. Journals, system-log collection,
and installation have different requirements: [collection guide](docs/WATCH_LOG_COLLECTION.md).

Physical follow-through remains: actual iPhone volume after every recovery path,
landmark countability while moving, runtime renewal/endurance, accessibility and
battery impact. No new physical validation is implied by Mac-only checks.

## Historical detail

- [Verification reports through build 16](docs/history/VERIFICATION_THROUGH_BUILD_16.md)
- [Earlier prototype/review notes](docs/history/REVIEW_NOTES.md)
- [Runtime recovery](docs/RUNTIME_RECOVERY.md)
- [Haptic delay behavior](docs/HAPTIC_DELAYS.md)
- [Volume focus comparison](docs/SIMULATOR_VOLUME_FOCUS.md)
- [Native media recovery](docs/NOW_PLAYING_SERVICE_RECOVERY.md)
- [Always-On hand investigation](docs/ALWAYS_ON_HAND_TRANSITION.md)
