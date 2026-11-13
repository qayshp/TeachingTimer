# Active roadmap

Updated November 12, 2026 after the companion and CI consistency review. GitHub issues own the task
checklists; this page owns their order. [Current status](../DEVELOPMENT_STATUS.md)
owns build, installation and distribution facts.

## Next work

| Priority | Work | Completion gate |
| --- | --- | --- |
| P0 — [#8](https://github.com/qayshp/TeachingTimer/issues/8) | Diagnose frozen native song progress | The merged isolation experiment did not fix TestFlight `1.0 (261104.1939.6)`. Add the supervised standalone/embedded comparison to Apple feedback, then obtain matched physical evidence; preserve playback, Crown and class state. |
| P0 — [#9](https://github.com/qayshp/TeachingTimer/issues/9) | Establish supported runtime policy | Documented Apple guidance on actual yoga teaching and renewal, or a supported alternative. Beta review approval alone does not complete this. |
| P1 — [#27](https://github.com/qayshp/TeachingTimer/issues/27) | Awake-relaunch runtime rejection | Compare cold/running-process relaunch timing against the captured hosted failure; verify a bounded correction without weakening the runtime assertion. |
| P1 — [#10](https://github.com/qayshp/TeachingTimer/issues/10) | Release-critical hardware validation | Supervised media/route/count checks, teaching-length renewal and battery results, readable controls and accessibility. Requires coordinated physical use. |
| P1 — [#11](https://github.com/qayshp/TeachingTimer/issues/11) | External beta installation | The public invitation now offers joining instructions. Verify exact eligible build and one new tester's install/update/support experience; internal-owner success is separate. |
| P1 — [#26](https://github.com/qayshp/TeachingTimer/issues/26) | Private tester journal sharing | Optional companion and filtered report export implemented; one physical email delivery verified. Retest startup, request retries, first Mail composition and upgrade preservation. [Validation](OPTIONAL_COMPANION.md). |
| P1 — [#14](https://github.com/qayshp/TeachingTimer/issues/14) | Contribution and release safeguards | Main still has no required-check enforcement. Define a practical recovery/bypass policy; retain durable source tags/notes after workflow artifacts expire. |
| P2 — [#24](https://github.com/qayshp/TeachingTimer/issues/24) | Release order and verification reuse | Avoid overlapping publishers, reduce duplicate Mac verification, and handle decreasing Pacific-local numbers at daylight-saving fall-back. Synthetic numbering failure is confirmed; no rejected upload is claimed. |
| P2 — [#17](https://github.com/qayshp/TeachingTimer/issues/17) | Transient missing Simulator controls | Keep original early/delayed captures and separate capture timing, dim state and actual missing pixels. The Ultra outline checker is calibrated with regression coverage; older early-rendering observations still merit follow-up. |
| P3 — [#15](https://github.com/qayshp/TeachingTimer/issues/15) | Performance baseline | Runtime invariant table and 1,280 seeded mixed events are implemented. Measure render cost before caching geometry; physical battery work remains in #10. |

Within a priority tier, work top to bottom. Physical-device and Apple-dependent
items can proceed alongside the laptop-only release/test work. There is no
unattended hardware test scheduled.

Completed in this review: [#13](https://github.com/qayshp/TeachingTimer/issues/13)
now has a [teaching-face visual key](TEACHING_FACE_GUIDE.md);
[#22](https://github.com/qayshp/TeachingTimer/issues/22) corrects bundled-input
release gating, manual build-number validation and diagnostic-tool compilation.
The narrow [#25](https://github.com/qayshp/TeachingTimer/issues/25) recovery-label
layout fix is recorded in the review's before/after captures.
[#23](https://github.com/qayshp/TeachingTimer/issues/23) is also complete: real
hosted Watch launches and class/Stop persistence passed on watchOS 26.5 and 27.2.
The November 6 expansion adds small/large matrices with real running-session
recovery, timed class retirement on both pages and overdue-launch checks. Local
and both hosted paths passed; [exact coverage](AUTOMATION.md#booted-watch-smoke-check)
still excludes menu interactions, physical audio/haptics and full-length renewal.
The follow-up adds compiler/source hygiene and clearer gear/session controls;
main verification can no longer be cancelled by a later docs-only push.
Screenshot OCR [#30](https://github.com/qayshp/TeachingTimer/issues/30) is corrected
and the full local action suite passes on SE 3 and Ultra. CI now executes the
recognizer instead of only compiling it; [coverage and remaining measurement limits](REVIEW_2026-11-12.md#screenshot-ocr-follow-up).
The [CI timing review](CI_EFFICIENCY.md) removes duplicate release-side Mac
verification for non-publishing tooling pushes. Exact-source reuse for actual
app releases and publication ordering remain in #24; no deadline or security
guard was removed.
Selective Swift CodeQL routing now keeps full scans for production, dependency,
project and security-configuration changes, plus weekly/manual runs. Python and
Actions still scan every change. Hosted full-scan source/rule comparison and a
docs-only skip both passed; the timing review records the evidence and the
separate local manual/scheduled routing tests.

Documentation simplification [#12](https://github.com/qayshp/TeachingTimer/issues/12)
is complete: a concise status page, user-facing changelog and separate historical
checkpoints. The [edge-following dial work #19](https://github.com/qayshp/TeachingTimer/issues/19)
is implemented and merged; its Simulator/form-factor checks passed. Physical
validation of the merged layout is part of #10. All 60 ticks continue behind a
translucent settings button and are subdued beneath system time.

## Existing reliability work

Use the [issue map](ISSUE_TRACKER.md) for silencing (#3), developer connections
(#5), paired Simulator media (#6), frozen progress (#8) and awake runtime
recovery (#27). The [November 6 review](ISSUE_REVIEW_2026-11-06.md) records the
latest closure decisions, tests and evidence limits.
Keep them separate unless evidence establishes a shared cause. Resolution should
consider the identified cause, correction, relevant tests and subsequent use;
it does not require proof that a symptom can never recur.

The seconds-hand transition issue [#4](https://github.com/qayshp/TeachingTimer/issues/4)
is closed as fixed by builds 33–34: stable timeline anchor and boundary
normalization, passing follow-up recordings and no recent owner-observed
physical recurrence. Reopen on recurrence; the separate Apple report retains
its last inspected status.

The dimmed-relaunch defect [#7](https://github.com/qayshp/TeachingTimer/issues/7)
is also closed as fixed: the readiness guard addresses the reproduced premature
Start, matched Simulator recovery passed, and persisted-intent regression tests
cover both readiness orders and bounded failure. Broader physical recovery
remains in #10; reopen #7 if the corrected symptom returns. Newly observed #27
has both readiness gates satisfied and is tracked independently.

**#1 blank media** and **#2 Crown focus** are also resolved using the targeted
corrections, passing follow-ups and owner evidence. Retain their reopen criteria.
**#3 silencing** remains for one bounded volume exercise on the previously
affected available routes; passing that alongside normal use can justify
closure without a universal route guarantee. **#6 paired Simulator media** awaits
Apple support guidance. **#5 connection failures** needs the existing requested
CoreDevice failure/recovery capture; TestFlight improves delivery but does not
repair that diagnostic transport.

The [supervised media plan](PHYSICAL_MEDIA_TEST_PLAN.md) includes initial focus,
Home return, refresh and media return with known playback routes. An overnight
test remains conditional on a successful supervised rehearsal and device access.
No test, physical installation or automatic monitor is scheduled by this roadmap.

## Historical work

- [Earlier numbered roadmap through build 37](history/ROADMAP_THROUGH_BUILD_37.md)
  preserves original items and their dated completion limits.
- [Builds 17–21](history/ROADMAP_BATCHES_17_TO_21.md) and
  [status checkpoints](history/STATUS_THROUGH_BUILD_37.md) retain evidence provenance.
- [Changelog](../CHANGELOG.md) summarizes changes for testers;
  [publishing readiness](PUBLISHING_READINESS.md) retains release gates.

Continue to preserve independent Watch teaching with optional phone support, native media/volume controls,
monotonic count timing, explicit Stop intent and independent class context.
