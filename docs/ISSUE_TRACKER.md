# Public issue tracker

Use GitHub for reproducible observations and project follow-up. Apple feedback
IDs refer to separate submitted reports, not a confirmed Apple diagnosis.
The [current verification status](../DEVELOPMENT_STATUS.md) distinguishes
Simulator results, physical observations and unverified mitigations.

| GitHub issue | Apple feedback | Current boundary |
| --- | --- | --- |
| [#1 Blank native media](https://github.com/qayshp/TeachingTimer/issues/1) | FB25305069 | **Resolved November 6** by preventive view recreation, supported by no recent physical recurrence and a passing service-loss recovery capture. Current originals contain Not Playing; an initial preview misreading was corrected. Apple's root cause/status is separate; reopen on recurrence. |
| [#2 Crown volume response](https://github.com/qayshp/TeachingTimer/issues/2) | FB25329167 | **Reopened November 13** after build-39 physical timer-volume failure on Apple Music/USB despite recovery attempts. The former refocus regression's correction remains historical evidence; a shared cause is unproven. [Current incident and limits](VOLUME_INCIDENT_2026-11-12.md). Silencing remains #3. |
| [#3 Unexpected audio silencing](https://github.com/qayshp/TeachingTimer/issues/3) | Ready-to-submit draft; no FB ID | **Recurred November 13** on Amazon Music/USB-C. Correlated sysdiagnoses link Crown-associated native control action to zero at 19:04:27 PST, then USB mute; native Now Playing recovers at 19:04:32–34. Earlier model value was 0.625. Signed Crown input/internal baseline remain unknown; stable volume-host isolation is a proposed experiment, not a fix. [Investigation and gates](VOLUME_INCIDENT_2026-11-13.md#proposed-experiment-and-regression-gates). |
| [#4 Always-On seconds-hand backstep](https://github.com/qayshp/TeachingTimer/issues/4) | FB25329087 | **Closed as fixed, November 6.** Builds 33–34 correct the reproduced precision and moving-anchor mechanisms. Follow-up recordings show no backward ticks; the owner reports no recent physical recurrence. [Evidence and resolution](ALWAYS_ON_HAND_TRANSITION.md#resolution--november-6). Reopen on recurrence. Apple status is separate; follow-up not sent. |
| [#5 Watch developer connection failures](https://github.com/qayshp/TeachingTimer/issues/5) | FB25329139 | Apple could not diagnose with current information; coordinated failure/recovery evidence remains needed. |
| [#6 Paired Simulator media discovery](https://github.com/qayshp/TeachingTimer/issues/6) | FB25294079 | No known-working companion-media baseline; Apple support clarification remains needed. |
| [#7 Runtime recovery after dimmed relaunch](https://github.com/qayshp/TeachingTimer/issues/7) | Not separately filed | **Closed as fixed, November 6.** Builds 31–32 prevent the reproduced premature Start. Matched Simulator recovery and eight additional persisted-intent regression cases pass, alongside 1,280 seeded events. Broader native callback delivery/physical reliability remain in #10; reopen on recurrence. |
| [#8 Frozen song progress](https://github.com/qayshp/TeachingTimer/issues/8) | FB25379883 | Timeline isolation merged in `2e02452`. The maintainer reports progress still freezes on TestFlight `1.0 (261104.1939.6)`, which includes the change. Isolation alone did not fix it; matched physical comparison remains open. |
| [#27 Awake runtime recovery rejection](https://github.com/qayshp/TeachingTimer/issues/27) | Not filed | Hosted watchOS 26.5 smoke catches code 3 after both app and scene report active. This differs from #7's corrected inactive/dimmed submission. Preserve the failed capture and compare startup/relaunch timing; no physical reproduction or fix claimed. |

## Release and maintenance work

[Issue #17](https://github.com/qayshp/TeachingTimer/issues/17) records newly
inspected Simulator count/Lock frames with missing control labels. This is
separate from the withdrawn historical screenshot claims and has no physical
reproduction. See the [original-image comparison](MEDIA_WAKE_REFRESH.md#fresh-missing-label-observation).
The November 5 full count/Lock suite passed; all seven text-recognition warnings
were hand occlusion in the original images. Some early multi-size captures lacked
native/system elements that appeared later, so #17 remains open without assigning
a cause. See the [full review](REVIEW_2026-11-05.md).
The November 12 full SE/Ultra runs passed their action assertions and completed
counts while reported locked. Original-image review attributes the text warnings
to foreground hands; Ultra's outline flags expose fixed horizontal sampling
insets in the measurement helper. That calibration limitation is recorded in #17
separately from app disappearance. It is now corrected with 18 synthetic
regression cases covering both sizes and invalid dimensions; the older startup
rendering question remains open. [Calibration evidence](REVIEW_2026-11-12.md#outline-checker-calibration-follow-up).

The [roadmap](ROADMAP.md) orders these review follow-ups; each issue has its own
completion checklist:

The [November 6 review](ISSUE_REVIEW_2026-11-06.md) records current closures,
new automated coverage, the hosted failure and a next action for every open issue.

- [#9 Runtime intended use](https://github.com/qayshp/TeachingTimer/issues/9)
- [#10 Physical reliability/battery/accessibility](https://github.com/qayshp/TeachingTimer/issues/10)
- [#11 First external beta and release readiness](https://github.com/qayshp/TeachingTimer/issues/11)
- [#26 Private tester journal sharing](https://github.com/qayshp/TeachingTimer/issues/26): optional companion implemented; two support-email deliveries verified, including a later-build Watch-prepared report. [Flow and remaining gates](OPTIONAL_COMPANION.md). No upload service is added.
- [#14 Release traceability and contribution safeguards](https://github.com/qayshp/TeachingTimer/issues/14)
- [#15 Runtime invariants and performance baseline](https://github.com/qayshp/TeachingTimer/issues/15): invariant table and seeded tests implemented; performance measurement remains.
- [#30 Screenshot OCR stability](https://github.com/qayshp/TeachingTimer/issues/30): fixed by bounded CPU-backed fast recognition, exact multi-scale corroboration and observed icon/label pairs. Full SE/Ultra actions pass; CI executes real recognition on nine synthetic labels. [Evidence](REVIEW_2026-11-12.md#screenshot-ocr-follow-up).
- [#24 Release ordering](https://github.com/qayshp/TeachingTimer/issues/24): exact-source verification reuse and selective Swift CodeQL are implemented. Publisher serialization and a confirmed synthetic Pacific daylight-saving build-number reversal remain; main checks retain per-commit cancellation groups.

Completed: [#12 documentation and changelog](https://github.com/qayshp/TeachingTimer/issues/12),
[#13 teaching-face visual key](https://github.com/qayshp/TeachingTimer/issues/13),
[#16 Simulator action contract](https://github.com/qayshp/TeachingTimer/issues/16),
[#19 full-screen dial around top controls](https://github.com/qayshp/TeachingTimer/issues/19),
[#22 bundled release inputs and diagnostic-tool coverage](https://github.com/qayshp/TeachingTimer/issues/22),
[#23 hosted Simulator execution](https://github.com/qayshp/TeachingTimer/issues/23) (real launch/persistence checks passed on watchOS 26.5 and 27.2),
and [#25 complete stopped-session label](https://github.com/qayshp/TeachingTimer/issues/25).

## Reporting evidence

The [bug form](../.github/ISSUE_TEMPLATE/bug_report.yml) asks for versions,
actions, observed results, recovery and relevant audio-route context. Do not
post raw journals, sysdiagnoses, account details, device identifiers or private
paths. Use cropped screenshots and sanitized excerpts. Existing detailed
captures stay private; provide them to Apple through Feedback Assistant when
appropriate.

Keep symptoms separate unless evidence establishes a shared cause. A page
callback is not proof of rendered pixels; a focus call or moving ring is not
proof of a volume command, selected endpoint or audible output. Simulator results
alone do not establish a physical fix. Close issues when the identified cause,
correction, relevant tests and subsequent use support resolution; record the
limits and reopen on recurrence.

On November 6, #4 was closed as completed with the owner's approval. The two
clock corrections, passing follow-up recordings and no recent owner-observed
physical recurrence support calling it fixed. This does not claim every
historical occurrence had an identical cause or change Apple's report status.

Issues #1 and #5 were updated on October 28 to match the image audit and Apple
connection-report status. On November 5, #1 and #3 were annotated as apparently
mitigated after the maintainer corrected a transcription error; neither was
closed at that checkpoint. The table above records the later closure of #1.

On November 2, issue bodies #4, #7 and #8 were synchronized with the clock
precision/anchor comparisons, bounded runtime-recovery results, and October
30–31 song-progress recurrence plus FB25379883. Exact body readback was verified;
titles, open state and existing comments were preserved. No Apple follow-up or
new issue comment was sent by this synchronization.

On November 5, issue #8 was updated after the owner reported that TestFlight
build `1.0 (261104.1939.6)` still has frozen song progress. The timeline-isolation
change is already merged in `2e02452`; issue #8 remains open for matched physical
validation.
