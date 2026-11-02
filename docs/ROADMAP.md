# Active roadmap

Updated November 2, 2026. Build 25 is installed and launched; October 31 classroom
feedback confirms Settings/volume worked, while song progress still stalled and
page switching recovered it. Build 27 adds Help/Privacy/About in Settings to the
source. Build 31 is Ready to Test / Internal after clean signed archive/export,
upload and processing. Builds 29 and 31 are assigned to the one-tester Maintainer
pilot, with automatic distribution off; build 30 is processed but unassigned.
Build 31's automatic-start scene-readiness guard passes one matched Simulator
comparison, 12 Swift suites and 107 Python tests. The physical pilot remains
pending. Build 16 remains a preserved rollback
checkpoint. Further physical installations require authorization. Simulator work
and repository changes do not count as physical validation.

## Current work order

| Order | Work | Completion gate |
| --- | --- | --- |
| 1 — complete | Reconcile backlog and corrected screenshot claims | Current docs distinguish verified evidence from superseded interpretations. |
| 2 — complete | Revalidate native-media rendering | Retain original images, OCR and central-content measurements; distinguish Not Playing, possible loading and candidate blank frames from lifecycle checks. |
| 3 — complete | Explain the default scheduled start | Added the compact Suggested time cue on SE 3 and Ultra; preserved inference, default 60 minutes and independent custom drafts. |
| 4 — reviewed | Review hand/label collisions | Compare selected angles awake/dim; retain both hands foremost and generous targets. Do not adopt a cosmetic change without a legibility benefit. |
| 5 — Simulator audit complete | Audit maximum text and 12/24-hour layouts | Exercise setup, custom schedule, summary and actions on small/large screens; source-check accessibility labels. Hardware VoiceOver remains separate. |
| 6 — complete | Apple Always-On documentation follow-up | File the missing-documentation issue requested in FB24696786, cross-reference it, and close the old report as requested. FB25347535 submitted; FB24696786 cross-referenced and closed. |
| 7 | Short coordinated hardware session | Native volume matrix, count cancel/restart while moving, and a connection capture if a failure naturally occurs. Requires a suitable time and device access. |
| 8 | Separate endurance session | Runtime renewal, Home/return, intentional Stop, persistence/new class, battery and diagnostic cost over a teaching-length run. |
| 9 | Private TestFlight pilot | Build 31 is available to the owner. Verify physical install/update, separate-identity state, journal access and support handling before inviting more testers. |
| 10 | Ordinary teaching observations | Early/late/consecutive classes, New Class discoverability and counting groups of 4–6 pulses. Avoid adding teaching UI before the observations justify it. |
| 11 | Seconds-hand transition comparison | Fixed-anchor probe reproduces backsteps on watchOS 27.2; preserve transition evidence for the existing report. Physical comparison remains pending. No speculative time clamping. |

Items 1–6 are the Mac-only batch. Items 7–10 depend on coordination, actual wear
or the distribution pilot; approval of the roadmap does not turn those into
completed tests. No periodic monitor or automatic installation is scheduled.

## Reconciliation with the original numbered list

| Original items | Status / remaining work |
| --- | --- |
| 1–7 | Teaching checkpoint, documentation separation, retention, device/summary tools, persistence diagnostics and confirmed dead-code cleanup implemented. Journal copying, install/version verification and launch have live evidence; connection reliability remains unresolved. |
| 8 | Simulator lifecycle regression automation implemented. Original-image audit complete; current bounded run renders. Physical reliability remains unproven. |
| 9 | Independent native-volume probe built; physical comparison remains current item 7. |
| 10 | Separate distribution identity, signed export and build-31 upload/processing verified. Builds 29/31 are assigned to the owner pilot; 30 is unassigned. Install/update and journal-access pilot remain current item 9. |
| 11–13 | Physical volume, connection and moving-haptic tests pending; current item 7. |
| 14–15 | Runtime endurance and battery/logging cost pending; current item 8. |
| 16–17 | Simulator usability checks exist; physical accessibility and ordinary schedule-use observations pending. |
| 18–21 | Time-edge tests, essential-action checks, build/release evidence and public issues implemented. |
| 22 | Clock probe and Apple report exist. The fixed-anchor probe reproduces backsteps on watchOS 27.2 (24S118); preserve that comparison for the existing report. Physical transition testing remains pending. |
| 23 | Mechanical presentation split complete; shared state/native lifecycle retained. |
| 24 | Tester/privacy guides, build-31 processing/owner-pilot assignment, saved beta Test Information and support inbound delivery verified. Review contact, physical beta install/update, journal access and support reply/attachment checks remain prerequisites for broader testing. |
| 25 | Apple follow-up is ongoing. The October 28 media correction was submitted; connection status and requested documentation follow-up need tracking. |

The older 14-point usability/public-code review is largely implemented: reserved
count track, explicit schedule editing and class actions, included archive app,
MPL-2.0, README/help split, icon/privacy/build identity and CI. Main remaining
questions are hand-label overlap and physical teaching/accessibility validation.
Journal writes already run off the main thread; measure before optimizing again.

## Suggested sequence for physical work

**Before a class, when the maintainer is available:** preserve current journals;
record installed build and route; test timer volume at launch, after Home, after
refresh and after media return, separately for no playback and iPhone playback.
Record displayed level, audible output and endpoint. A focus callback alone is
not a pass. Then try counts/cancellation/restart while moving. Do not intentionally
disrupt a class or play test tones without arranging it first.

**On a separate teaching-length run:** record start/end battery, class/runtime
timestamps, renewal and foreground changes. Check intentional Stop survives
reopen, active class recovery, and scheduled-end +30-minute retirement. Avoid
mixing diagnostic-heavy and normal runs when comparing battery costs.

**Only after the pilot gates pass:** invite a small TestFlight group. Keep the
existing development identity available until separate distribution identity,
updates, recovery and journal access are proven. See [pilot gates](TESTFLIGHT_PREPARATION.md).

## Evidence and references

- [Current verification](../DEVELOPMENT_STATUS.md)
- [Builds 17–21 historical batch record](history/ROADMAP_BATCHES_17_TO_21.md)
- [Usability follow-up](USABILITY_FOLLOWUP_2026-10-28.md)
- [Apple feedback](APPLE_FEEDBACK.md)
- [Physical tester checklist](TESTER_GUIDE.md)

No issue is closed because its symptom did not recur in a bounded Simulator run.

Original-image audit and fresh media run: [results](MEDIA_IMAGE_AUDIT.md).

Build 23 retains the build-22 additions: the schedule cue, two-line action wrapping and face
Start accessibility label.
[Usability comparison and limits](USABILITY_PASS_22.md). The icon/label trial was
not adopted; the existing hands and controls remain.

## October 29 regression follow-up

The [repository review](REPOSITORY_REVIEW_2026-10-29.md#locked-relaunch-observation)
records a locked Simulator relaunch where watchOS rejected automatic runtime
start and the app retained manual-recovery intent. Preserve the failed-run
journal and distinguish this from an awake relaunch. Investigate startup
eligibility/deferred recovery separately; intentional Stop and bounded retries
remain constraints. No physical reproduction or production policy fix is claimed.
Tracked as [issue #7](https://github.com/qayshp/TeachingTimer/issues/7).

November 2: build 30 reproduces the exact activation error code 3 on watchOS
27.2 after a dimmed relaunch. Waking does not resume the session, while class
bytes remain unchanged. [Baseline evidence](RUNTIME_RECOVERY.md#november-2-build-30-baseline-on-watchos-272)
now exists for the narrow source-build-31 scene-readiness guard. One matched
candidate trial deferred Start and recovered on a later active wake; another
trial had different initial luminance. Swift suites and Debug build pass.
Physical validation and broader callback-ordering coverage remain open; see
[the comparison limits](RUNTIME_RECOVERY.md#build-31-candidate-comparison).

## Media progress recovery

Build 24 adds [bounded long-dimmed wake refresh](MEDIA_WAKE_REFRESH.md) for
[frozen song progress (#8)](https://github.com/qayshp/TeachingTimer/issues/8).
Build 25 is installed and launched. The October 31 class report includes another
progress stall recovered by switching pages; it does not establish whether an
automatic refresh was eligible or attempted. Physical progress recovery, audio
continuity and Crown response remain validation gates; policy tests do not close
this issue. See [current verification](../DEVELOPMENT_STATUS.md) for later candidates.

## October 31 preparation

Follow [publishing readiness](PUBLISHING_READINESS.md) for distribution gates and
the [supervised physical-media plan](PHYSICAL_MEDIA_TEST_PLAN.md) for the next
coordinated session. The overnight idea is retained; no run is scheduled.
