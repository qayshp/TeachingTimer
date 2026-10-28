# Roadmap implementation record: builds 17–21

Historical batch results. See the [current status](../../DEVELOPMENT_STATUS.md) and
[active roadmap](../ROADMAP.md) for corrected conclusions and remaining gates.

**Rendering correction:** historical assertions below about missing timer controls
and delayed black media are superseded. Original PNGs include the controls and
Not Playing. No recovery ranking follows from them. Physical black-media reports
remain valid. See [evidence audit](../TIMER_CONTROL_INVESTIGATION.md).

## Builds 20–21 — usability and evidence correction

Build 16 remains on the physical Watch; all work used disposable simulators.
Build 20 replaces success-looking volume refresh feedback with a brief outline
and “Refresh requested.” Native focus/identity/timing are unchanged; all six
SE 3 focus regression checks pass. Build 21 adds a concise unreadable-class
notice with Start class/Later, preserving original/backup values on dismissal.
[Changes and validation](../USABILITY_FOLLOWUP_2026-10-28.md).

The control-disappearance claim from the previous screenshot review was wrong.
The original PNGs contain those controls. A bounded 99-frame comparison found
no missing full-width count outlines; OCR warnings require review for hand
occlusion. Timeline/compositing experiments were removed. This is not a new
rendering fix or proof against other intermittent failures.

A related audit found Not Playing in all nine delayed PNGs attached to the
October 28 Apple media comparison. That delayed-blank/variant-ranking conclusion
was corrected in FB25305069 at 01:04 PDT. Physical black-media/volume incidents
remain unresolved; earlier Simulator rendering claims need revalidation.

## Roadmap 22–25 — candidate build 19, comparison and tester preparation

The physical Watch remains on **build 16**. No physical-device query, install,
launch or log collection was performed. That batch produced **build 19**.

22. Checked the installed runtime gate for the isolated hand-transition probe.
    Xcode 27.1 still has watchOS 27.0 SDK/runtime (24R362); there is no newer local
    Watch runtime for a useful comparison. Hardware work is deferred.
    [Recorded limit](../ALWAYS_ON_HAND_TRANSITION.md).
23. Mechanically [split shared presentation](../VIEW_SPLIT.md) into class UI,
    button style, refresh UI and WatchKit adapter files. Stable view identity,
    shared state, native lifecycle and focus order are preserved. All twelve
    Swift suites, 40 Python checks, Simulator build and both unsigned archives
    pass. SE 3 and Ultra pass all 14 action assertions; SE 3 passes all six focus
    lifecycle assertions. These do not certify pixel rendering or phone audio.
24. Added a [tester guide](../TESTER_GUIDE.md), [privacy/diagnostics explanation](../PRIVACY.md),
    [distribution metadata draft](../DISTRIBUTION_METADATA.md), actual
    [build 16 versus 19 screenshots](../BUILD_16_VS_19.md) and a
    [usability review](../USABILITY_REVIEW_BUILD_19.md). No TestFlight upload or
    invitations; signed install/update/journal access and physical validation
    remain pilot gates.
25. [Updated FB25305069](../APPLE_MEDIA_UPDATE_2026-10-28.md) with the four
    unsuccessful media-recovery experiments, delayed captures, source variants
    and bounded lifecycle evidence. Upload completion was verified. Other
    reports had no meaningful new evidence and received no duplicate updates.

**Correction:** the earlier comparison misidentified controls as missing in
individual screenshot previews. The original PNGs contain those controls, as
confirmed by OCR and outline checks. [Investigation](../TIMER_CONTROL_INVESTIGATION.md).
This does not resolve the separately documented black-media/volume bugs.

## Roadmap 18–21 — tests, automation and public tracking

Completed without changing the production app's teaching/session/media behavior.
The physical Watch remains on its last verified **build 16**; no physical-device
installation, launch or diagnostic collection was performed in this batch.

18. Added [time-edge regression checks](../TIME_EDGE_TESTS.md): DST gaps/folds,
    fractional timezones, year rollover, persisted instants, retirement boundaries
    and clock-correction-independent landmark projection. All twelve Swift suites pass.
19. Added a [bounded essential-action UI suite](../ESSENTIAL_ACTION_CHECKS.md).
    SE 3 40 mm and Ultra 4 49 mm each passed all 14 state assertions; final
    reviewed captures rendered the expected menus, native Not Playing and timer.
    An earlier SE 3 timer-return capture again lacked controls despite retained
    class/page state. The intermittent rendering problem remains open.
20. Added [build/release evidence automation](../BUILD_VERIFICATION.md), retained
    failure logs and toolchain/source metadata, archive/symbol inspection and a
    separate signed-artifact gate. The local ad-hoc Simulator build and both
    unsigned archives pass. All 40 Python tooling tests pass. Untracked source
    now marks generated revision metadata dirty; ignored artifacts do not.
21. Created [six public issues](../ISSUE_TRACKER.md) and a concise bug-report
    form, linking five submitted Apple reports and keeping silencing draft-only.
    No new Apple submission or report update was made in this batch.

At completion of that batch, source was build 18. Those tests do not establish
actual iPhone volume response, physical haptic delivery or a fix for intermittent native UI.
The two disposable Watch simulators remain running for manual inspection.

## Media recovery follow-up — production behavior unchanged

The [October 26 recovery comparison](../MEDIA_RECOVERY_COMPARISON.md) tested
stable page identity, a 300 ms native teardown gap, clock-only timeline placement,
and conditional native-view lifetime. None established reliable recovery; all
experimental app edits were removed. Longer-wait captures confirm persistent
blank frames as well as transient loading. Only the regression tooling and
investigation documentation changed; that batch retained build 18 and did not
install on the physical Watch. The native service-loss reproduction still
warrants further isolation. It was subsequently included in the
[October 28 Apple follow-up](../APPLE_MEDIA_UPDATE_2026-10-28.md).

## Build 18 — second reliability/tooling batch (not installed)

Completed October 26, 2026:

6. Class/runtime-intent persistence distinguishes absent data from decoding or
   encoding failures, preserves unreadable preferences locally, and reports
   metadata through the existing journal. [Details](../PERSISTENCE_DIAGNOSTICS.md).
7. Removed unreachable live haptic-stop state/warnings while preserving decoding
   and explanation of older saved outcomes. No haptic timing change.
8. Added [bounded Simulator regression captures](../../tools/simulator-regression/README.md)
   for Home/refresh/media return and deliberate native media-service loss.
9. Added a separate [native volume probe](../../tools/native-volume-probe/README.md)
   with retained/replacement control and immediate/delayed setup comparisons.
10. Prepared the future `net.qays.TeachingTimer` identity using the maintainer's
    qays.net domain, keeping the installed development identity unchanged.
    [Unsigned archive rehearsal and pilot gates](../TESTFLIGHT_PREPARATION.md).

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
See [retention audit and limits](../JOURNAL_RETENTION.md).

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

[Tool usage and limits](../DIAGNOSTIC_TOOLS.md). All 29 Python tooling tests pass
using a fake command boundary; no physical operation was performed in this batch.
The summary was also checked against a real saved build-12 incident. Eleven
Swift suites and the build-17 Simulator build passed. Live execution of the new
device tool remains to be checked during the next requested collection/install.
The physical Watch's last verified installed build remains **16**.

