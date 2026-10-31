# Public issue tracker

Use GitHub for reproducible observations and project follow-up. Apple feedback
IDs refer to separate submitted reports, not a confirmed Apple diagnosis.
The [current verification status](../DEVELOPMENT_STATUS.md) distinguishes
Simulator results, physical observations and unverified mitigations.

| GitHub issue | Apple feedback | Current boundary |
| --- | --- | --- |
| [#1 Blank native media](https://github.com/qayshp/TeachingTimer/issues/1) | FB25305069 | Preventive native-view refresh helps some cases; not reliably fixed. Original October 24 black frames are verified; later delayed-frame and missing-timer-control interpretations were corrected. |
| [#2 Crown volume response](https://github.com/qayshp/TeachingTimer/issues/2) | FB25329167 | Retained control/refocus avoids a controlled regression; physical reliability remains unproven. |
| [#3 Unexpected audio silencing](https://github.com/qayshp/TeachingTimer/issues/3) | Draft only | Playback continues; a recorded zero-volume request does not establish the initiating fault. |
| [#4 Always-On seconds-hand backstep](https://github.com/qayshp/TeachingTimer/issues/4) | FB25329087 | Minimal Simulator probe reproduces; no speculative time correction added. |
| [#5 Watch developer connection failures](https://github.com/qayshp/TeachingTimer/issues/5) | FB25329139 | Apple could not diagnose with current information; coordinated failure/recovery evidence remains needed. |
| [#6 Paired Simulator media discovery](https://github.com/qayshp/TeachingTimer/issues/6) | FB25294079 | No known-working companion-media baseline; Apple support clarification remains needed. |
| [#7 Runtime recovery after dimmed relaunch](https://github.com/qayshp/TeachingTimer/issues/7) | Not separately filed | Simulator start rejection retained manual intent; physical reproduction pending. |
| [#8 Frozen song progress](https://github.com/qayshp/TeachingTimer/issues/8) | FB25379883 | Pause/volume worked; view refresh helped temporarily. Build 25 adds bounded wake recovery, pending classroom validation. |

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
