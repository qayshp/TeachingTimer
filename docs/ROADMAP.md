# Active roadmap

Updated October 31, 2026. Build 25 is installed and launched; its Settings and
media wake-refresh classroom validation is pending. Build 26 is the source
candidate from this cleanup. Build 16 remains a preserved rollback checkpoint. Further
physical installations require authorization. Simulator work and repository
changes do not count as physical validation.

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
| 9 | Private TestFlight pilot | Signed upload/install/update, separate-identity state and journal access, and a private support route before inviting more testers. |
| 10 | Ordinary teaching observations | Early/late/consecutive classes, New Class discoverability and counting groups of 4–6 pulses. Avoid adding teaching UI before the observations justify it. |
| 11 | Seconds-hand transition comparison | Use the isolated probe on a newer Watch runtime or in a planned physical session. No speculative time clamping. |

Items 1–6 are the Mac-only batch. Items 7–10 depend on coordination, actual wear
or the distribution pilot; approval of the roadmap does not turn those into
completed tests. No periodic monitor or automatic installation is scheduled.

## Reconciliation with the original numbered list

| Original items | Status / remaining work |
| --- | --- |
| 1–7 | Teaching checkpoint, documentation separation, retention, device/summary tools, persistence diagnostics and confirmed dead-code cleanup implemented. Journal copying, install/version verification and launch have live evidence; connection reliability remains unresolved. |
| 8 | Simulator lifecycle regression automation implemented. Original-image audit complete; current bounded run renders. Physical reliability remains unproven. |
| 9 | Independent native-volume probe built; physical comparison remains current item 7. |
| 10 | Distribution identity and unsigned archive rehearsal ready. Signed pilot is current item 9. |
| 11–13 | Physical volume, connection and moving-haptic tests pending; current item 7. |
| 14–15 | Runtime endurance and battery/logging cost pending; current item 8. |
| 16–17 | Simulator usability checks exist; physical accessibility and ordinary schedule-use observations pending. |
| 18–21 | Time-edge tests, essential-action checks, build/release evidence and public issues implemented. |
| 22 | Clock probe and Apple report exist. New runtime/hardware comparison pending. Only watchOS 27.0 (24R362) is installed locally at this review. |
| 23 | Mechanical presentation split complete; shared state/native lifecycle retained. |
| 24 | Tester/privacy guides and metadata draft ready. Signed pilot, support route and actual beta screenshots remain prerequisites for broader testing. |
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

## Media progress recovery

Build 24 adds [bounded long-dimmed wake refresh](MEDIA_WAKE_REFRESH.md) for
[frozen song progress (#8)](https://github.com/qayshp/TeachingTimer/issues/8).
Build 25 is installed and launched; build 26 cleanup is not installed. Physical progress recovery, audio continuity and
Crown response remain validation gates; this issue is not closed by policy tests.

## October 31 preparation

Follow [publishing readiness](PUBLISHING_READINESS.md) for distribution gates and
the [supervised physical-media plan](PHYSICAL_MEDIA_TEST_PLAN.md) for the next
coordinated session. The overnight idea is retained; no run is scheduled.
