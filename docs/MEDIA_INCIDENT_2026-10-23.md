# Physical media and volume failures: October 23, 2026

## Evidence gained on October 24

A Watch sysdiagnose was generated through CoreDevice and retrieved inside a
combined archive from the paired iPhone. Gzip integrity checks passed, and the
Watch unified log archive was readable. Raw system logs and screenshots remain
private under ignored `work/support/2026-10-24-runtime-recovery/` and
`work/support/2026-10-23-physical-classes/`.

The following times are local, America/Los_Angeles. They correlate the evening
incident with the original Watch screenshot and the app journal:

| Time | Observation |
| --- | --- |
| 18:49:55.35 | WatchKit reports TeachingTimer entering foreground from suspension. |
| 18:49:55.41 | RunningBoard invalidates TeachingTimer's assertion for `NanoNowPlayingViewService`. This describes framework-managed activity, not a direct app call. |
| 18:49:55.75 | TeachingTimer's WatchKit `SPInterfaceRemoteNowPlayingController` logs `viewServiceDidTerminateWithError`, `_UIViewServiceHostSessionErrorDomain` code 2. The failure-reason text is private/redacted. |
| 18:50:00.79 | WatchKit confirms the mindfulness session started. |
| 18:52:28 | App journal records media-page selection during the running session. |
| 18:52:31 | Original Watch screenshot shows a black media page with its selected page dot. |
| 18:53:57 | TeachingTimer process relaunches. WatchKit reports no running or scheduled extended-runtime sessions available for recovery. |
| 18:54:36.02 | RunningBoard acquires a new view-service session assertion from the new TeachingTimer process; a new `NanoNowPlayingViewService` process starts. |
| 19:04:37 | Manual runtime Start succeeds in the old build. Build 6 separately fixes lost runtime intent after relaunch. |

## Interpretation and limits

The native remote controller's termination is a concrete lead for the black
page, beyond the app's appearance/focus callbacks. Its ordering is consistent
with a stale or failed native media-view connection surviving page changes,
then being replaced after process recreation. It does not yet establish the
initial cause: resource pressure, framework lifecycle behavior, or an interaction
with the host's view structure remain possibilities. The error alone does not
prove an OS process crash, and the logs do not verify rendered pixels after
the replacement service starts.

The native service also emits account-store entitlement errors after relaunch.
Those later errors are not proof of the earlier blank page's cause and are not
instructions to add private entitlements to TeachingTimer.

The volume request originally noted here can now be correlated with the
maintainer's recollection and the saved iPhone archive. See the follow-up below.
The public volume-control API still does not provide an app-readable percentage
or change callback; the additional values come from Apple's system logs.

For noon, the original 12:29:07 screenshot and user-reported force-close recovery
remain the main evidence. The sysdiagnose retains only 60 records during
12:20–12:40 and no matches for the targeted media query. Do not infer that the
evening error was also the noon cause from that absence.

## October 24 follow-up: timer-page silencing with USB audio

The maintainer recalled that adjusting volume on the timer page silenced the
audio during the 18:45 class, possibly during Hot Half Moon within the first
15 minutes. The initial estimate was a few to 30 minutes into class; the revised
estimate and pose association are approximate recollections, not timestamps.
The output used a USB-C-connected audio device, **not AirPlay**. The maintainer
also associated this with discovering/screenshotting the black media page, while
expressing uncertainty about the sequence. The exact action that restored sound
has not been established for this incident.

Read-only reanalysis of the already-collected Watch and iPhone sysdiagnose
archives found the following. Times are October 23, America/Los_Angeles (PDT):

| Time | Recorded evidence |
| --- | --- |
| 18:47:57.45 | iPhone Music's volume framework reports normalized volume `1.0`, the last retained Music volume value before the zero in this query. |
| 18:49:55.75 | Watch native media controller reports the service-connection failure described above. During initialization its volume framework separately reports unavailable/zero, then available/absolute/`1.0`; these initialization observations are not zero-volume commands. |
| 18:52:28–18:52:33 | Media selected, black-page screenshot at 18:52:31, then return to timer. The existing companion control's focus call returns about 12 ms after its request. |
| 18:52:43.05 | iPhone Music explicitly identifies its audio route as `USBAudio`, named `AB13X USB Audio`. This independently corroborates the reported wired output near the incident. |
| 18:52:47 | Timer page becomes active and leaves reduced luminance; the mindfulness runtime remains running. No new focus call or control replacement is recorded at this wake. |
| 18:52:47.854 | Apple's MediaPlayer volume framework inside TeachingTimer logs `setVolume to: 0.000000`; the endpoint is redacted. |
| 18:52:48.051 | iPhone Music's framework reports volume `0.000000`. |
| 18:52:48.102 | TeachingTimer's framework reports volume `0.000000`. |
| 18:52:54 | Media selected again; companion volume resign call returns. |
| 18:53:57–18:54:36 | App relaunch, then media selection and new native media-service connection. |
| 18:54:37.918–18:54:41.401 | The native media service submits 42 increasing volume requests, approximately `0.0082` to `0.6953`. Matching values appear in iPhone Music and TeachingTimer. These show renewed remote volume communication, not direct proof of audible sound or what input the user made. |

The zero request is about **7 minutes 48 seconds after scheduled class start**,
consistent with the recalled early-class window. The matching iPhone observation
is about 0.2 seconds later by recorded device timestamps; cross-device clock
alignment was not independently measured. Together with the user report, this
is stronger evidence of an actual volume-to-zero event than Watch focus logs
alone. It does not establish a separate mute-bit command, the USB device's
physical gain, Crown direction/delta, or the exact visible indicator value.

The black screenshot precedes the recorded zero request by about 17 seconds.
Preserve that ordering alongside the uncertain recollection; do not conclude
that this request caused the media page to go black. An earlier unretained
silencing event cannot be excluded. The service error, zero-volume event, and
later successful requests are temporally related, but a shared cause is unproven.

The retained focus requests around the incident were not superseded or invoked
after control dismantling. The same companion control survived until relaunch.
The adapter in the incident build (`6d2e4448ffdc`, build 5) configures the native
control and calls focus/resign; it does not calculate or set volume levels.
There is no evidence here for fixing this by changing the app's focus order.

### Investigation priority and limits

Treat unexpected silencing as a high-priority teaching interruption alongside
black media, ahead of the seconds-hand transition polish. It has now been
reported with both AirPlay/WiiM and wired USB audio, so an AirPlay-only explanation
is insufficient. This does not prove that the earlier AirPlay incident has the
same cause.

A stale native companion-volume state or endpoint after foreground/wake/page
transitions is a hypothesis worth testing. A shared media backend failure is
another possibility. Neither is diagnosed by these records. In particular, the
transient initialization values and earlier iPhone endpoint-initialization error
do not by themselves prove the later silencing cause.

The next useful controlled test is on the physical pair with wired output at a
comfortable level: compare native companion volume alone against the embedded
Now Playing combination, including wake and page-return transitions. Capture
both devices' logs and observe the starting indicator, Crown direction, whether
playback time continues, and which control restores sound. Paired-Simulator
media discovery has not worked, so Simulator cannot validate this audio path.
This follow-up made no behavioral changes or fresh physical-device requests.

**Reload media is not a proven silencing fix.** It deliberately leaves the
companion volume control intact. Its two successful rendering recoveries do not
establish volume recovery. The new USB/volume correlation is documented here;
it has not yet been added as a follow-up to Apple report FB25305069.

Private query outputs and a bounded journal excerpt are under ignored
`work/support/2026-10-24-volume-correlation/`. Raw route identifiers, track
metadata, and device logs are excluded from this public account.

## Simulator reproduction and Apple report

On October 24, deliberately terminating `NanoNowPlayingViewService` while the
Simulator host stayed alive reproduced the black media page twice, with the
same WatchKit error domain/code. Force-closing and reopening TeachingTimer
restored native media content both times. Class timing and saved runtime intent
survived; build 6 automatically recovered runtime. This induced test does not
establish why the service connection ended on the physical Watch.

Filed **FB25305069**, “watchOS 27 NowPlayingView stays black after native view
service ends; force-close restores it,” with the physical evidence, controlled
Simulator steps, source, and combined Watch/iPhone sysdiagnose. This is separate
from paired-Simulator media-discovery report FB25294079. See the
[full reproduction and limits](NOW_PLAYING_SERVICE_RECOVERY.md).

## Recommended next experiment

1. Validate **Class → Reload media** on the physical failure. This user-triggered
   reconstruction of only `NowPlayingView` recovered both controlled Simulator
   failures in build-7 testing, preserving class, runtime, count, and volume
   adapter identity. Native content remains full-screen. See the linked results
   for pixel evidence and the physical Crown/playback validation still needed.
2. Use a minimal native-media host to investigate foreground return after the
   remote view service is lost. Compare with standalone Now Playing on hardware
   when practical; Simulator media-source discovery is not equivalent to this
   physical rendering failure.

Do not add automatic periodic recreation or attempt private-API error hooks.
There is no proven public blank-page detector in the current implementation.
The manual media recovery does not prevent the original failure or establish
its physical cause. Automatic runtime recovery remains a separate behavior.
