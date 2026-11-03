# Active roadmap

Updated November 2, 2026 after the repository review. GitHub issues own the task
checklists; this page owns their order. [Current status](../DEVELOPMENT_STATUS.md)
owns build, installation and distribution facts.

## Next work

| Priority | Work | Completion gate |
| --- | --- | --- |
| P0 — [#8](https://github.com/qayshp/TeachingTimer/issues/8) | Isolate native media from the clock timeline | Bounded Simulator lifecycle/state checks, then matched physical A/B continuous-progress comparison. No new refresh timer; preserve native volume and class/runtime/count state. |
| P0 — [#9](https://github.com/qayshp/TeachingTimer/issues/9) | Establish supported runtime policy | Documented Apple guidance on actual yoga teaching and renewal, or a supported alternative. Beta review approval alone does not complete this. |
| P1 — [#10](https://github.com/qayshp/TeachingTimer/issues/10) | Release-critical hardware validation | Supervised media/route/count checks, teaching-length renewal and battery results, readable controls and accessibility. Requires coordinated physical use. |
| P1 — [#11](https://github.com/qayshp/TeachingTimer/issues/11) | Public-beta readiness | Apple approval, working invitation, external install/update and usable support. Final store privacy disclosures precede App Store publication. |
| P2 — [#13](https://github.com/qayshp/TeachingTimer/issues/13) | First-use explanation | Annotated, accurately labeled teaching face; class/session, count-tail and audio-source meanings together in one guide. |
| P2 — [#14](https://github.com/qayshp/TeachingTimer/issues/14) | Release safeguards | Source-linked beta tags/notes and a practical required-check policy for outside contributions. Preserve maintainer recovery and private artifacts. |
| P3 — [#15](https://github.com/qayshp/TeachingTimer/issues/15) | Lifecycle/performance evidence | Transition invariants, reproducible seeded event tests and a bounded performance baseline. Measure before optimizing. |

Documentation simplification [#12](https://github.com/qayshp/TeachingTimer/issues/12)
is complete: a concise status page, user-facing changelog and separate historical
checkpoints. Keep those current rather than adding another review report.

## Existing reliability work

Use the [issue map](ISSUE_TRACKER.md) for blank media (#1), Crown response (#2),
silencing (#3), seconds-hand transitions (#4), developer connections (#5), paired
Simulator media (#6), dimmed runtime recovery (#7) and frozen progress (#8).
Keep them separate unless evidence establishes a shared cause. Bounded successful
tests do not close intermittent physical bugs.

Fresh Simulator-only missing-label frames are tracked in
[#17](https://github.com/qayshp/TeachingTimer/issues/17), independently of the
withdrawn historical interpretations. The action-contract mismatch found during
this review is tracked in [#16](https://github.com/qayshp/TeachingTimer/issues/16).

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
