# Public issue tracker

Use GitHub for reproducible observations and project follow-up. Apple feedback
IDs refer to separate submitted reports, not a confirmed Apple diagnosis.
The [current verification status](../DEVELOPMENT_STATUS.md) distinguishes
Simulator results, physical observations and unverified mitigations.

| GitHub issue | Apple feedback | Current boundary |
| --- | --- | --- |
| [#1 Blank native media](https://github.com/qayshp/TeachingTimer/issues/1) | FB25305069 | Preventive native-view refresh helps some cases; not reliably fixed. Original October 24 black frames are verified; later delayed-frame and missing-timer-control interpretations were corrected. |
| [#2 Crown volume response](https://github.com/qayshp/TeachingTimer/issues/2) | FB25329167 | Retained control/refocus avoids a controlled regression. November 2 Beta 35 passes initial, media-return, Home-return and tap-refresh Crown checks with iPhone-speaker playback; intermittent reliability and other routes remain unproven. |
| [#3 Unexpected audio silencing](https://github.com/qayshp/TeachingTimer/issues/3) | Draft only | Playback continues; a recorded zero-volume request does not establish the initiating fault. |
| [#4 Always-On seconds-hand backstep](https://github.com/qayshp/TeachingTimer/issues/4) | FB25329087 | [Exact-Date and anchor comparisons](ALWAYS_ON_HAND_TRANSITION.md#build-34-follow-up-stable-schedule-anchor) separate precision errors from moving-anchor regressions. Build 34 combines narrow normalization and a fixed epoch; bounded probe/app video, UI and locked-count checks pass. Signed release and owner-pilot assignment are complete. Hardware validation remains open; no universal cause or compositor defect claimed. Apple follow-up not sent. |
| [#5 Watch developer connection failures](https://github.com/qayshp/TeachingTimer/issues/5) | FB25329139 | Apple could not diagnose with current information; coordinated failure/recovery evidence remains needed. |
| [#6 Paired Simulator media discovery](https://github.com/qayshp/TeachingTimer/issues/6) | FB25294079 | No known-working companion-media baseline; Apple support clarification remains needed. |
| [#7 Runtime recovery after dimmed relaunch](https://github.com/qayshp/TeachingTimer/issues/7) | Not separately filed | Build 30 reproduces exact activation error code 3 on watchOS 27.2. Build 31 defers the premature Start and recovers on later active wake in one matched Simulator trial; class bytes and Stop intent survive. Physical behavior and arbitrary callback ordering remain unverified. |
| [#8 Frozen song progress](https://github.com/qayshp/TeachingTimer/issues/8) | FB25379883 | [November 2 Beta 35 test](MEDIA_PROGRESS_INCIDENT_2026-11-02.md): embedded progress updates on entry then stalls; repeated entry yields a newer snapshot. Standalone Now Playing appears to advance. Phone seeking updates both, with an apparent unmeasured offset in the embedded view. Page-entry and eligible wake refreshes are logged, not proof of recovery. |

## Release and maintenance work

The [roadmap](ROADMAP.md) orders these review follow-ups; each issue has its own
completion checklist:

- [#9 Runtime intended use](https://github.com/qayshp/TeachingTimer/issues/9)
- [#10 Physical reliability/battery/accessibility](https://github.com/qayshp/TeachingTimer/issues/10)
- [#11 First external beta and release readiness](https://github.com/qayshp/TeachingTimer/issues/11)
- [#12 Current documentation and changelog](https://github.com/qayshp/TeachingTimer/issues/12)
- [#13 Annotated onboarding](https://github.com/qayshp/TeachingTimer/issues/13)
- [#14 Release traceability and contribution safeguards](https://github.com/qayshp/TeachingTimer/issues/14)
- [#15 Runtime invariants and performance baseline](https://github.com/qayshp/TeachingTimer/issues/15)
- [#16 Simulator action-contract drift](https://github.com/qayshp/TeachingTimer/issues/16)

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
connection-report status. Both project issues remain open.

On November 2, issue bodies #4, #7 and #8 were synchronized with the clock
precision/anchor comparisons, bounded runtime-recovery results, and October
30–31 song-progress recurrence plus FB25379883. Exact body readback was verified;
titles, open state and existing comments were preserved. No Apple follow-up or
new issue comment was sent by this synchronization.
