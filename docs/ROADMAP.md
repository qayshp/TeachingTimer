# Active roadmap

Updated November 6, 2026 after the compiler, UI and hosted Simulator follow-up. GitHub issues own the task
checklists; this page owns their order. [Current status](../DEVELOPMENT_STATUS.md)
owns build, installation and distribution facts.

## Next work

| Priority | Work | Completion gate |
| --- | --- | --- |
| P0 — [#8](https://github.com/qayshp/TeachingTimer/issues/8) | Diagnose frozen native song progress | The merged isolation experiment did not fix TestFlight `1.0 (261104.1939.6)`. Add the supervised standalone/embedded comparison to Apple feedback, then obtain matched physical evidence; preserve playback, Crown and class state. |
| P0 — [#9](https://github.com/qayshp/TeachingTimer/issues/9) | Establish supported runtime policy | Documented Apple guidance on actual yoga teaching and renewal, or a supported alternative. Beta review approval alone does not complete this. |
| P1 — [#10](https://github.com/qayshp/TeachingTimer/issues/10) | Release-critical hardware validation | Supervised media/route/count checks, teaching-length renewal and battery results, readable controls and accessibility. Requires coordinated physical use. |
| P1 — [#11](https://github.com/qayshp/TeachingTimer/issues/11) | External beta installation | The public invitation now offers joining instructions. Verify exact eligible build and one new tester's install/update/support experience; internal-owner success is separate. |
| P1 — [#14](https://github.com/qayshp/TeachingTimer/issues/14) | Contribution and release safeguards | Main still has no required-check enforcement. Define a practical recovery/bypass policy; retain durable source tags/notes after workflow artifacts expire. |
| P2 — [#24](https://github.com/qayshp/TeachingTimer/issues/24) | Release order and verification reuse | Avoid overlapping publishers, reduce duplicate Mac verification, and handle decreasing Pacific-local numbers at daylight-saving fall-back. Synthetic numbering failure is confirmed; no rejected upload is claimed. |
| P2 — [#17](https://github.com/qayshp/TeachingTimer/issues/17) | Transient missing Simulator controls | Keep original early/delayed captures and separate capture timing, dim state and actual missing pixels. Current count/Lock OCR warnings were hand occlusion; early multi-size captures still merit follow-up. |
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

Documentation simplification [#12](https://github.com/qayshp/TeachingTimer/issues/12)
is complete: a concise status page, user-facing changelog and separate historical
checkpoints. The [edge-following dial work #19](https://github.com/qayshp/TeachingTimer/issues/19)
is implemented and merged; its Simulator/form-factor checks passed. Physical
validation of the merged layout is part of #10. All 60 ticks continue behind a
translucent settings button and are subdued beneath system time.

## Existing reliability work

Use the [issue map](ISSUE_TRACKER.md) for blank media (#1), Crown response (#2),
silencing (#3), seconds-hand transitions (#4), developer connections (#5), paired
Simulator media (#6), dimmed runtime recovery (#7) and frozen progress (#8).
Keep them separate unless evidence establishes a shared cause. Bounded successful
tests do not close intermittent physical bugs.

After the release-blocking work above: verify **#2 Crown response**, **#4 clock
transitions** and **#7 dimmed recovery** within #10's supervised checks. Monitor
**#1 blank media** and **#3 silencing**, both reported absent since recent changes;
keep them open as apparently mitigated. **#6 paired Simulator media** awaits
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

Continue to preserve the standalone watchOS scope, native media/volume controls,
monotonic count timing, explicit Stop intent and independent class context.
