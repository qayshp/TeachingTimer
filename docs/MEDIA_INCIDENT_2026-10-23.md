# Physical black media page: October 23, 2026

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

System framework volume logs include a zero-volume request in TeachingTimer's
process at 18:52:47.85, followed by a zero-volume observation. The endpoint is
redacted. These records do not establish which visible control initiated it,
the receiver's volume, or audibility, and do not explain the separate earlier
AirPlay silencing report by themselves. The public volume-control API still
does not provide an app-readable percentage or change callback.

For noon, the original 12:29:07 screenshot and user-reported force-close recovery
remain the main evidence. The sysdiagnose retains only 60 records during
12:20–12:40 and no matches for the targeted media query. Do not infer that the
evening error was also the noon cause from that absence.

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

1. Test a user-triggered reconstruction of only the native `NowPlayingView`,
   offered from Class options so the native media page remains full-screen.
   Preserve class, runtime, count, and the working volume/focus adapter. Record
   the recovery request and resulting lifecycle; do not claim success from a
   lifecycle callback alone.
2. Use a minimal native-media host to investigate foreground return after the
   remote view service is lost. Compare with standalone Now Playing on hardware
   when practical; Simulator media-source discovery is not equivalent to this
   physical rendering failure.

Do not add automatic periodic recreation or attempt private-API error hooks.
There is no proven public blank-page detector in the current implementation.
This remains a diagnosis and next-step proposal; the shipped change is runtime
recovery, not a claimed media fix.
