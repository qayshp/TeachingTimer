# Native volume availability: October 24, 2026

This investigation concerns an unresponsive timer control while native Now
Playing worked. It is distinct from the earlier captured zero-volume submission
and from a black media page. Raw journals/system archives remain private under
ignored `work/support/`; only a sanitized assessment is published here.

## What the two-device evidence establishes

For the first class, Watch system logs contain 144 native volume submissions
from `NanoNowPlayingViewService` and none from `TeachingTimer`. For the later,
working class there are 54 from `TeachingTimer` and nine from the native service.
All 207 match the phone's requests in order and rounded volume value, with
9–142 ms between Watch submission and phone request. This is timestamp/value
correlation, not a shared request-ID join. None of those submissions requests zero.
Both classes used the same AirPlay receiver.

The important native state transitions (Pacific daylight time):

| Time | Evidence |
| --- | --- |
| 17:04:19 | TeachingTimer returns from suspension, briefly activates, then resigns active while route-change notifications arrive. Its native controller reports volume 0, `available: NO`, and `capabilities:None`. A companion routing-source dump has empty cached routes and picked routes. |
| 17:04:48 | Native Now Playing reports available YES and usable volume capabilities. |
| 18:02:39 | App journal records explicit timer-control replacement; no retained timer `setVolume` follows before switching to media at 18:02:44. Crown movement within those five seconds is not established. |
| 18:16:05 | Phone leaves AirPlay for its own speaker; TeachingTimer reports YES/Absolute about 0.2 seconds later. |
| 18:27:19 | TeachingTimer reports unavailable again. |
| 18:32:48 | On foreground return, TeachingTimer reports YES/Absolute. |
| 18:32:55 | Explicit replacement reports YES/Absolute too. Availability had recovered before this tap. |

This favors a stale/unusable companion endpoint or capability state over loss
of already-issued commands. A return from suspension during route discovery is
an observed trigger context, not a proven root cause. No app-side ordering fault
or confirmed premature `focus()` is established by these records. The UI wrapper
remembers requested focus, not actual focus; an unchanged desired value will not
reissue `focus()` just because internal native state changed.

The earlier idle test differed: the timer reported a valid phone endpoint and
available YES yet initially produced no request. The phone already had zero
volume and Crown direction was unavailable, leaving both focus readiness and
zero clamping possible. Do not force both incidents into one diagnosis.

## Meaning of immediate response

Separate startup/re-entry readiness from response to a Crown movement after
readiness. The user accepts a short startup delay; the desired steady-state
behavior remains native and responsive. There is no need for a custom Crown
binding, a chosen recovery volume, or periodic focus calls on every clock frame.

The watchOS 27 SDK's public `WKInterfaceVolumeControl` API exposes construction
origin, tint, focus and resign only. It has no availability, selected-endpoint,
volume-value, or readiness callback. Native private-framework logs expose more
state than the app is allowed to use. Do not add private API/KVC or pretend that
a successful focus return detects a healthy controller. Apple's
[volume-control documentation](https://developer.apple.com/documentation/watchkit/wkinterfacevolumecontrol?language=objc)
likewise assigns volume changes to the system.

## Proposed first repair experiment — not implemented yet

Try **one bounded, staged activation on cold launch and actual background
return**, while preserving the control during ordinary wrist wakes and page
swipes:

1. After the timer is selected, the Class sheet is dismissed, and the app is
   active, allow about one second for foreground/route discovery to settle.
   Then create a fresh companion control and focus it after mounting. Re-entry
   can temporarily keep the existing native display until replacement.
2. Guard delayed creation and queued focus work by generation and current
   selection. Cancel when leaving the timer or opening the Class sheet; a
   retired widget must never reclaim Crown focus from the new widget or media.
3. Do not repeatedly reset an already-used control, reset it on every dim/wake,
   or hide/open Now Playing to prime Apple's media services. Keep explicit
   tap-to-refresh as a fallback.
4. Compare against the current build on a physical Watch, beginning with a
   known nonzero phone volume, both with AirPlay already selected before opening
   the app and with a route change after opening. Repeat background returns and
   inspect native availability and submissions, not only focus-call timestamps.
5. If delayed reconstruction remains unavailable, stop adding timed retries.
   The current logs already show that a late manual recreation is not a proven
   cure. Escalate the native capability discrepancy with Apple and test a narrow
   focus-only alternative separately, so the result remains interpretable.

This is a plausible public-API mitigation, not a demonstrated fix. Delaying only
`focus()` cannot be assumed to repair an unavailable endpoint. A successful test
must establish actual paired-phone control and preserve normal page/count/class
behavior. Existing paired and Watch-local Simulator fixtures have not established
a working end-to-end audio-volume path; Simulator can verify cancellation and
native-view lifecycle, not validate this audio repair.

## Changes in this iteration

Build 10 changes journal retention/noise only. Native volume creation, focus,
refresh and media behavior remain unchanged pending this controlled experiment.
See [diagnostic event meanings and retention](INTERFACE_DIAGNOSTICS.md).
