# October 29: frozen media progress and timer volume

Saved-data investigation, October 29, 2026. The maintainer reported a visible
but frozen native song-progress ring and a separate temporary timer Crown-volume
failure; swiping pages restored each. Exact symptom times are not known.
This is build 16 on physical SE 3/watchOS 27.2 (24S118), not build 24.
All times below are Pacific daylight time. Raw logs remain private.

## Evidence and limits

Validated Watch and iPhone sysdiagnoses plus three app journals were correlated.
Watch logs retain 121,499 records for 10:30–11:40, including 4,635 TeachingTimer
and 4,259 NanoNowPlayingViewService records. Phone logs retain only 92 records
in that interval and no targeted media/volume matches. Missing records are not
proof an action did not happen. The public policy is [bounded wake recovery](MEDIA_WAKE_REFRESH.md).

## Correlated sequence

| Time | Recorded behavior |
| --- | --- |
| 10:34:34 | Timer native volume reports available YES, Absolute capability and level 0.62. |
| 11:11:51 | Media selected; automatic page-entry recreation requested. |
| 11:13–11:31 | Native NowPlayingViewModel logs 13 response replacements during continued media selection; last at 11:31:04. Contents are private/redacted. |
| 11:32:57 | Media scene becomes active and undimmed. |
| 11:32:58–59 | Embedded media submits 13 volume requests; timer receives level updates. |
| 11:33:00 | Media → timer; focus requested on the retained timer volume control. |
| 11:33:01 | Timer → media; new native host loads responses and initializes volume controllers. |
| 11:33:03 | Media → timer; focus requested again. |
| 11:33:06–07 | Timer dims and becomes inactive. |
| 11:33:18–19 | Wake, then timer → media; another new native host/response-loading sequence. |
| 11:34:38 | Runtime expiration-associated interruption, later than the switches. |
| 11:36 | Timer volume submissions recorded again. |

The rapid switches are a candidate recovery sequence, not an established timestamp
for either reported failure. Native response-loading and hosted-window changes
correlate with the app's intentional page-entry recreation.

## Volume findings

TeachingTimer logs 38 setVolume calls across 10:37, 10:38, 10:53, 11:04, 11:11 and
11:36. Embedded media logs 71 across 11:08, 11:17, 11:32, 11:36 and 11:37. Observed
requested ranges are 0.458781–0.835625 and 0.429266–0.844500 respectively; no zero
submission appears in these calls. Neither process logs available NO in the
retained interval. This differs from the earlier endpoint-unavailable case;
it does not establish uninterrupted availability or phone audibility.

Three retained timer-window UIEvent type7/subtype200 clusters coincide with
volume submissions. Such input dispatch is not a public proof of Crown ownership;
we have no conclusive timer input-without-submission sequence here. Some media
input clusters lack submissions, but they do not establish timer failure or input
meaning. Do not diagnose the reported timer failure from silence in the log.

## Media-progress findings

The embedded service has one observed process ID across the interval and continues
model updates and volume handling. No matching native-view termination signature
was found. This is evidence against a sustained, completely dead media service,
not proof that the progress animation or elapsed-time metadata was correct.

The response contents are redacted and no direct progress/elapsed-time values were
identified. A stale animation/view state after dim/wake is plausible; a stale
component of the playback response remains possible. Recreation refreshes both,
so recovery by swiping does not distinguish them. Account-daemon sandbox errors
also recur around view creation, including ordinary entries; no causal link to
the freeze is established. The later runtime interruption cannot explain the
preceding switch sequence.

## Apple evidence assessment

There is enough for an honestly qualified intermittent-progress report: firsthand
symptom, OS/build, recovery action, journal correlation and a validated Watch
sysdiagnose with relevant native-service records. There is not enough to claim a
reproduction, exact onset, root cause or a measured stalled progress value.
Keep this distinct from blank-media issue #1 and volume issue #2; progress is
[issue #8](https://github.com/qayshp/TeachingTimer/issues/8).

For timer volume, these logs are useful supplementary evidence for the existing
focus investigation, not a newly established mechanism. Stronger evidence would
pair an exact failed-input time with phone playback/route and a brief video of
attempted Crown movement followed by recovery. For progress, a short video showing
unchanged position while audio continues, exact time/track, and a prompt capture
would distinguish visual stalling from missing time metadata more effectively.
No Apple report or upload was performed in this investigation.
