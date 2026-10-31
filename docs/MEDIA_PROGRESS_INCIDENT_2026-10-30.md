# October 30: frozen native song progress

Physical SE 3, build 23, watchOS 27.2 (24S118). The maintainer reported frozen
song status/progress during class, restored by swiping pages. Exact symptom onset
and which switches were recovery attempts remain unconfirmed. Times below are
Pacific daylight time. No new Apple submission or device action was made for
this saved-data analysis.

## Evidence

All three app journals parsed. Watch sysdiagnose downloaded fully (150,136,890
bytes), passed gzip validation, and yielded 582 system-log files. Watch logs
retain 260,924 entries across 12:25–15:15, including 3,226 embedded
NanoNowPlayingViewService entries, all with observed PID 4027. The phone archive
also validated, but the same interval's targeted media query returned only ten
entries. Archive-wide time coverage does not guarantee detailed incident coverage.
Raw archives, extracted logs and queries remain private under
`work/support/2026-10-30-class-build25/`.

## Strongest correlation

| Time | Observation |
| --- | --- |
| 14:39:08 | Media page selected. |
| 14:42–14:58 | Embedded service repeatedly replaces its playback response, including 14:47:21, 14:51:52, 14:55:54 and 14:58:06. Response contents are redacted. |
| 15:00:25 | Media page enters reduced luminance; scene becomes inactive a second later. |
| 15:01:34–35 | Scene becomes active and then undimmed after about 70 seconds dimmed. Runtime phase remains running. |
| 15:01:37 | Media → timer; native response loading ends. Timer focus calls are recorded, not proof of actual focus. |
| 15:01:38 | Timer → media; app requests generation 4, native response loading and volume-controller initialization recur, followed by response replacement. |
| 15:02:15 | Embedded service submits volume commands. |
| 15:02:17–19 | Another media → timer → media cycle and native reload. |
| 15:06:07–09 | Native responses update before another rapid switch at 15:06:16–17. |

These are candidate recovery sequences, not a precise freeze timestamp inferred
from the journal. One observed native-service PID and repeated response updates
argue against a continuously dead service, but do not prove a healthy animation,
correct elapsed-time metadata, or uninterrupted process execution. No explicit
progress/elapsed-time values were identified in the focused native-process query.

## Interpretation

A stale progress animation or stale part of a playback response after dim/wake
remains plausible. Recreating the native view renews both its rendering and data
subscriptions, so successful recovery cannot distinguish those mechanisms.
The 70-second dim/wake sequence fits the long-dim recovery case targeted by build
24 and included in now-installed build 25; this is rationale for testing the
mitigation, not proof it fixes the underlying bug. Build 23 did not include it.
The runtime was running at the 15:01 sequence; a simultaneous runtime expiration
is not supported as its explanation.

Account-store entitlement errors recur around native view creation, including
reloads; they are not established causes. Separately, timer volume initialization
reported MediaRemote code 36 (endpoint not picked or remotely controllable) around
12:38. That is useful volume evidence at a different time, not an explanation for
the later progress-ring symptom or proof of a user-observed volume failure today.

This strengthens an honestly qualified intermittent Apple progress report with
another physical observation, matched wake/reload events and a validated archive.
It still lacks exact onset, a video of frozen progress while audio advances,
visible elapsed-time values, and a deterministic reproduction. Keep it separate
from blank media and volume defects. Track progress in
[issue #8](https://github.com/qayshp/TeachingTimer/issues/8).

## Maintainer clarification after log review

The maintainer recalls two occurrences during the same song near the end of the
second class, believed to run 14:00–15:00. Estimated symptom time is around
14:58–15:00, not an exact timestamp. They were watching song progress to pause at
the song's end. Refreshing the view restored useful progress temporarily, then
another refresh was needed. They do not recall whether it also happened earlier
in this class or during the other class.

This makes the 15:01:37–38 and 15:02:17–19 page cycles plausible matches for the
two recoveries, but neither those exact matches nor the role of the 15:06 cycle
is confirmed. Importantly, view recreation did not provide lasting recovery in
this user-observed episode. The clarification does not establish that playback
or the Pause command itself failed; the confirmed symptom is stale song status/
progress requiring view refresh while timing a pause.

The journal also records a short wake at 15:01:53–55, then reduced luminance until
a later wake. A recurrence after a shorter dim interval could fall outside build
25's long-dim threshold or refresh cooldown. Exact recurrence timing is unknown,
so this is a limitation to test, not a demonstrated failure of build 25, which
was installed after these classes.
