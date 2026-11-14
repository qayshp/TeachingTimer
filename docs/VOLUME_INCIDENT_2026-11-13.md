# Physical volume silencing — November 13

Sanitized evidence for [#3](https://github.com/qayshp/TeachingTimer/issues/3),
separate from [#2 unavailable Crown volume](https://github.com/qayshp/TeachingTimer/issues/2).
No volume behavior changed during this investigation. Raw journals and system
captures remain private.

## Owner observations

The owner taught classes at 12:30, 14:00 and 18:45–19:45 Pacific Standard Time.
Early in the evening class, adjusting timer-page volume silenced the audio.
Playback continued silently. Switching to TeachingTimer's media page allowed
the owner to raise the volume from the Watch without using the iPhone.

The evening used **Amazon Music through USB-C audio**. This differs from the
[November 12 failure](VOLUME_INCIDENT_2026-11-12.md), when timer volume remained
unavailable despite recovery attempts. Neither the provider nor the route alone
is established as the cause.

## What the emailed journal establishes

All times below are **PST (UTC−08:00)**. The Watch report identifies version 1.0,
build **261113.1031.57**, source `b28e499319fb`, watchOS **27.2.1**. It does not
identify the later build 59 as the installed Watch build.

The report contains 1,741 events across all three journals and includes all
three class windows. No events were omitted, no writes were pending, and no
last-write failure was reported. Earlier events excluded by the requested
24-hour window are not evidence of retention loss.

| Time | Recorded event |
| --- | --- |
| 18:55:17 | Evening mindfulness runtime confirms running. |
| 18:55:18 | Staged native volume setup finishes, including the delayed focus call. |
| 18:55:59 | Timer → media. |
| 19:04:05 | Media → timer; native focus call returns. |
| 19:04:31–19:04:35 | Timer → media → timer; native focus call returns again. |
| 19:50:07 | Runtime invalidates with `resigned_frontmost`, raw value 3. |
| 20:00:27 | Automatic runtime recovery succeeds on return. |

The **18:55–19:05** interval is a candidate for system-log correlation, not an
established mute-onset or recovery timestamp. The app journal does not record
the audible incident itself. The first evening foreground-loss invalidation
is after the scheduled class end; it does not explain the reported early mute.

The same native volume object was retained from before the noon class. The
report contains no accepted volume-refresh event that day and no evening app
relaunch. Those absences do not prove that no tap or recovery was attempted.

Focus-call returns establish app-side requests, **not actual Crown ownership,
command delivery, endpoint selection or audible recovery**. The report has no
numeric volume, Crown direction, playback route or zero-volume command. A stale
native-control/backend association is a hypothesis, not a finding. The retained
control also served earlier classes, so its age alone does not establish cause.

## Capture status and next evidence

The owner triggered an iPhone system capture and saw its completion toast.
That establishes reported capture completion on the phone, not retrieval or
archive validation. No system capture for this incident has yet been retrieved
and validated. Direct device collection is deferred until the owner is home.

The owner also held the unlocked Watch's Crown and side button for about one
second, released them, and felt a Watch vibration. This is consistent with the
historically documented manual sysdiagnose acknowledgement, not proof that a
Watch archive has finished. A possible brief iPhone vibration does not establish
another capture. The trigger time is not established by the saved app logs.
Neither manual trigger needs repeating before checking the existing captures.

1. Find and retrieve the existing iPhone capture first; verify its integrity,
   device, timestamp and retained log bounds before starting another capture.
2. Check for an existing Watch capture before requesting one. Retrieve it if
   available; avoid duplicate collection simply because a transfer failed.
3. Correlate retained volume, media-route and command records with the candidate
   interval and page switches. Seek the destination and requested value; do not
   equate a missing record with no command, or a focus return with success.
4. Confirm the approximate mute/recovery times if the owner remembers them.
   Compare playback continuing silently with actual route/volume evidence.
5. If useful detail has rolled out, preserve that limitation and arrange a short
   supervised reproduction with immediate capture. Repeated later captures
   cannot recover expired class-time records.

The successful Watch-side media recovery is worth testing separately from
timer refocus. Preserve the normal Crown sequence until evidence supports a
change; native-control replacement previously regressed focus.
