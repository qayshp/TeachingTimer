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

## Staged activation experiment — build 11

Build 11 implements **one bounded, staged activation on cold launch and actual
background return**, while preserving the control during ordinary wrist wakes
and page swipes:

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

Build 10 changed journal retention/noise only. Build 11 includes those changes
and the staged setup above. A small progress indicator and VoiceOver value
communicate preparation. Automatic setup has no success checkmark because the
app cannot verify actual volume availability. Manual tap-to-refresh retains its
existing focus-call acknowledgement. Pending automatic setup is canceled when
its scene/page/sheet eligibility changes; it is rescheduled when eligible again.
A completed setup is not repeated until another actual background transition.

The maintainer reports that tapping refresh did not fix the failed class.
That makes this a tentative timing experiment, not an established cure. A late
refresh can still leave the underlying native endpoint unavailable. If staged
creation also fails, collect the native availability/capability evidence and
avoid layering periodic blind retries on top of it.

The native media page worked correctly in both October 24 classes, according
to the maintainer. This is encouraging physical evidence for the existing media
recovery behavior, but two successful classes do not establish that the
intermittent blank-page bug is resolved. Its behavior is unchanged in build 11.

See [setup validation](VOLUME_CONTROL_RECOVERY.md#staged-setup--build-11) and
[diagnostic event meanings and retention](INTERFACE_DIAGNOSTICS.md).

## Physical follow-up, October 25 — available control after refresh

Build 11 was installed and launched on the SE 3. The maintainer reported losing
Crown response after tapping refresh, with response returning after visiting
media. The user explicitly tapped Play on media, starting Watch playback; swiping
alone was not reported to start audio. Watch-local and iPhone playback were then
active separately. Times below are Pacific daylight time.

All seven manual refreshes created replacements, resigned the old control, and
called new focus in that order. Call returns followed taps by about 18–41 ms.
No obsolete queued call was observed. Native timer controllers reported available
YES/Absolute at startup and every replacement, unlike the earlier failed class.

The strongest sequence was:

- 00:07:48–55: 31 timer volume submissions reached the phone.
- 00:07:56: refresh read nonzero phone volume and available YES/Absolute.
  Another refresh followed at 00:08:01.
- 00:07:56.300–00:08:04: no timer submissions, despite 193 non-touch input
  dispatches reaching the app window. Those event types do not prove Crown
  direction or which native control owned focus.
- 00:08:04–05: media round trip, without another replacement. Ten timer
  submissions and matching phone requests resumed at 00:08:05–06.
- A similar gap followed the 00:08:25 refresh; input reached the window, and
  submissions resumed after a later media round trip.

Across the captured interval, all 202 timer volume submissions targeted iPhone.
Native media made 306 Watch-local submissions, then eight iPhone submissions.
All 210 Watch-to-phone commands matched phone-side requests in order and rounded
value; this is correlation, not a shared request-ID join or proof of audibility.
It supports different source selection on the two pages, with no evidence that
the timer controlled the Mac or Watch-local audio in this test. One zero request
followed descending values during deliberate testing; its intent is unknown and
it is not established as another unexpected mute incident.

The evidence favors focus/host-lifecycle timing after manual replacement. It
does not identify the native focus owner or prove premature focus is the cause.
Build 12 tests a single 250 ms delay before manual replacement focus, preserving
immediate media return and build 11 startup/background staging. See
[implementation and validation](VOLUME_CONTROL_RECOVERY.md#focus-after-manual-refresh--build-12).
This is not yet a physical fix for either failure mode. Raw journals and paired
system archives remain private under `work/support/2026-10-25-volume-startup-report/`.
