# Public issue tracker

Use GitHub for reproducible observations and project follow-up. Apple feedback
IDs refer to separate submitted reports, not a confirmed Apple diagnosis.
The [current verification status](../DEVELOPMENT_STATUS.md) distinguishes
Simulator results, physical observations and unverified mitigations.

| GitHub issue | Apple feedback | Current boundary |
| --- | --- | --- |
| [#1 Blank native media](https://github.com/qayshp/TeachingTimer/issues/1) | FB25305069 | Preventive native-view refresh helps some cases. On November 5 the maintainer corrected a transcription: no blank page has recurred since recent changes. Apparent mitigation; physical recurrence/root cause remain unresolved. |
| [#2 Crown volume response](https://github.com/qayshp/TeachingTimer/issues/2) | FB25329167 | Retained control/refocus avoids a controlled regression. November 2 Beta 35 passes initial, media-return, Home-return and tap-refresh Crown checks with iPhone-speaker playback; intermittent reliability and other routes remain unproven. |
| [#3 Unexpected audio silencing](https://github.com/qayshp/TeachingTimer/issues/3) | Draft only | A captured zero-volume request does not establish the initiating fault. On November 5 the maintainer corrected a transcription: no zero-volume event during timer adjustment has recurred since recent changes. Apparent mitigation only. |
| [#4 Always-On seconds-hand backstep](https://github.com/qayshp/TeachingTimer/issues/4) | FB25329087 | [Exact-Date and anchor comparisons](ALWAYS_ON_HAND_TRANSITION.md#build-34-follow-up-stable-schedule-anchor) separate precision errors from moving-anchor regressions. Build 34 combines narrow normalization and a fixed epoch; bounded probe/app video, UI and locked-count checks pass. Signed release and owner-pilot assignment are complete. Hardware validation remains open; no universal cause or compositor defect claimed. Apple follow-up not sent. |
| [#5 Watch developer connection failures](https://github.com/qayshp/TeachingTimer/issues/5) | FB25329139 | Apple could not diagnose with current information; coordinated failure/recovery evidence remains needed. |
| [#6 Paired Simulator media discovery](https://github.com/qayshp/TeachingTimer/issues/6) | FB25294079 | No known-working companion-media baseline; Apple support clarification remains needed. |
| [#7 Runtime recovery after dimmed relaunch](https://github.com/qayshp/TeachingTimer/issues/7) | Not separately filed | Build 30 reproduces activation error code 3; build 31 defers Start and recovers on later active wake in one matched Simulator trial. November 5 adds 1,280 seeded lifecycle events through the controller, plus a fresh passing action/focus suite. Physical behavior and arbitrary callback ordering remain unverified. |
| [#8 Frozen song progress](https://github.com/qayshp/TeachingTimer/issues/8) | FB25379883 | Timeline isolation merged in `2e02452`. The maintainer reports progress still freezes on TestFlight `1.0 (261104.1939.6)`, which includes the change. Isolation alone did not fix it; matched physical comparison remains open. |

## Release and maintenance work

[Issue #17](https://github.com/qayshp/TeachingTimer/issues/17) records newly
inspected Simulator count/Lock frames with missing control labels. This is
separate from the withdrawn historical screenshot claims and has no physical
reproduction. See the [original-image comparison](MEDIA_WAKE_REFRESH.md#fresh-missing-label-observation).
The November 5 full count/Lock suite passed; all seven text-recognition warnings
were hand occlusion in the original images. Some early multi-size captures lacked
native/system elements that appeared later, so #17 remains open without assigning
a cause. See the [full review](REVIEW_2026-11-05.md).

The [roadmap](ROADMAP.md) orders these review follow-ups; each issue has its own
completion checklist:

- [#9 Runtime intended use](https://github.com/qayshp/TeachingTimer/issues/9)
- [#10 Physical reliability/battery/accessibility](https://github.com/qayshp/TeachingTimer/issues/10)
- [#11 First external beta and release readiness](https://github.com/qayshp/TeachingTimer/issues/11)
- [#14 Release traceability and contribution safeguards](https://github.com/qayshp/TeachingTimer/issues/14)
- [#15 Runtime invariants and performance baseline](https://github.com/qayshp/TeachingTimer/issues/15): invariant table and seeded tests implemented; performance measurement remains.
- [#24 Release ordering and verification reuse](https://github.com/qayshp/TeachingTimer/issues/24): overlapping publishers, duplicated checks and a confirmed synthetic Pacific daylight-saving build-number reversal. Main Watch-check cancellation by later docs pushes is fixed with per-commit groups.

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
proof of a volume command, selected endpoint or audible output. Successful
Simulator runs do not close physical-device bugs.

Issues #1 and #5 were updated on October 28 to match the image audit and Apple
connection-report status. On November 5, #1 and #3 were annotated as apparently
mitigated after the maintainer corrected a transcription error; neither is
closed because the intermittent reports lack a defined validation period.

On November 2, issue bodies #4, #7 and #8 were synchronized with the clock
precision/anchor comparisons, bounded runtime-recovery results, and October
30–31 song-progress recurrence plus FB25379883. Exact body readback was verified;
titles, open state and existing comments were preserved. No Apple follow-up or
new issue comment was sent by this synchronization.

On November 5, issue #8 was updated after the owner reported that TestFlight
build `1.0 (261104.1939.6)` still has frozen song progress. The timeline-isolation
change is already merged in `2e02452`; issue #8 remains open for matched physical
validation.
