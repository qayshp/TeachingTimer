# Native volume-control recovery

## Focus after manual refresh — build 12

The first focus request on a manually replaced volume widget now waits 250 ms
after mounting. This gives the replacement and the tap's native focus processing
time to settle. The old widget still resigns synchronously during removal; a
newer focus intent or removal invalidates a queued request before it can run.
This is one bounded timing experiment, not a readiness test or retry loop.

Ordinary media-to-timer returns keep the existing next-main-queue focus call,
with no additional delay or widget replacement. Even if the user leaves during
the initial refresh wait, returning uses that immediate path. Startup and actual
background return keep build 11's one-second staged setup. Volume remains native
and fixed to `.companion`; the app does not choose a recovery volume.

The physical build 11 test found available YES/Absolute controls that stopped
submitting volume commands after refresh, then resumed after a media round trip.
The app had called `focus()` correctly, but its return did not prove Crown
ownership. See [the physical evidence](VOLUME_AVAILABILITY_INVESTIGATION.md#physical-follow-up-october-25--available-control-after-refresh).
The precise cause is unconfirmed; delaying focus may not repair the separate
unavailable-endpoint or unexpected-silencing problems.

### Validation

SE 3 40 mm Simulator, watchOS 27.0, Xcode 27.1:

- Two manual refreshes invoked replacement focus about 264 ms after requesting
  it. Both old widgets resigned before the new focus call.
- A media round trip reused the same widget and invoked focus about 8 ms after
  requesting it, with `settlingSeconds: 0`. Native media rendered Not Playing
  and transport controls; the timer rendered on return.
- Class timing and runtime intent were unchanged. The same runtime and count
  continued through both replacements and the media round trip. All six pulse
  groups were submitted and the count completed normally at about 64.84 seconds.
- Deterministic checks cover superseded/removed delayed work, immediate return
  after an interrupted refresh, and zero extra delay for automatic setup.
  All eleven suites and Simulator/signed-device builds passed.

These are framework-call timings, not measured Crown-to-audio latency. Physical
validation still needs working iPhone playback → refresh → Crown adjustment
without a media-page visit, followed by a normal media round trip. The paired
Simulator does not provide a validated end-to-end companion audio-volume path.
Private evidence is under ignored `work/support/2026-10-25-delayed-focus/`.

## Staged setup — build 11

Build 11 waits for the app to be active, the timer to be selected, and the Class
sheet to be dismissed, then allows one second before creating/focusing the
companion volume control. Cold launch initially shows a small preparation
indicator. After an actual background return, the old native display remains
while setup waits, without requesting Crown focus for the old control.

A change in eligibility cancels pending setup. Returning schedules a new bounded
attempt; it does not run a retry loop. Completed setup is retained across ordinary
wrist-down/wake, Class sheets, media-page round trips, and clock frames. Only a
new background transition makes another automatic setup necessary. Each delayed
attempt and queued native focus call is protected against obsolete work.

Steady-state Crown input still goes directly to the same native `.companion`
widget. Manual tap-to-refresh remains available. No volume value is chosen, no
media page is secretly opened, and class/count/runtime/media logic is unchanged.
The one-second wait is a settling interval, not an availability test: WatchKit
has no public readiness callback here. Automatic setup therefore has no success
checkmark or claim of recovered sound.

### Validation

SE 3 40 mm Simulator, watchOS 27.0, Xcode 27.1:

- Startup created one native control after approximately 1.05 seconds of settling.
- Two actual Settings/background/return cycles each produced one replacement.
  One return briefly became inactive during the wait: that attempt was canceled
  and the next eligible attempt completed after approximately one second.
- Returning with the Class sheet open deferred setup until dismissal.
- Native media rendered Not Playing and transport controls. A media round trip
  relinquished/re-requested focus without replacing the timer control.
- Lock/unlock was confirmed by reduced-luminance true/false events. It did not
  create another control; the same runtime continued through those transitions.
- Saved class timing was identical across the checks. A count run survived the
  background return and volume replacement and reached normal visual completion.
  Its haptics stopped at the existing late-pulse cutoff (about 0.52 seconds late
  at 30 seconds), independently of the arc. Backgrounding ended the runtime,
  and the existing automatic recovery restarted it on return as intended.
- An explicit refresh after wake still replaced/focused the native control. Old
  synchronous resigns completed before replacement focus calls. No obsolete or
  post-removal queued focus invocation was observed.
- All eleven deterministic suites and Simulator/signed-device builds passed.
  Tests cover canceled/superseded setup, stale focus requests, manual fallback,
  journal retention, and absence of wrist/page replacement churn.

These checks validate setup and state continuity. They cannot establish that
the physical companion endpoint is healthy or that this repairs the intermittent
unavailable/zero-volume incidents. The maintainer reports that a manual refresh
did not fix the failed October 24 class. Staging tests a different startup/return
timing, but may encounter the same unavailable native endpoint. Compare physical
AirPlay and other routes after startup, background return, and ordinary paging.
If it still fails, collect native capability and volume-command logs; avoid
adding repeated blind resets.

Private validation evidence is under ignored
`work/support/2026-10-24-staged-volume/` (testing crossed midnight Pacific).
Build 11 also includes build 10 journal retention: seven days / 10,000 events in
the operational journal, with routine scene/luminance events isolated in a
one-day / 4,000-event detail journal. Safety caps can shorten these windows.

## Tap-to-refresh — original build 9 behavior

The following records the original manual recovery experiment. Build 11 adds
automatic setup and the obsolete queued-focus guard; build 12 adds the bounded
manual-refresh focus delay above.

The timer's native volume display now has a single-tap recovery action. Tap its
speaker area, then turn the Crown again. A small refresh arrow becomes a checkmark
for 1.5 seconds after the replacement control's focus call returns. This confirms
widget replacement, not actual focus or audible recovery. No haptic is added.

If the iPhone's volume is already zero, refreshing may leave it there until the
user turns the Crown up. The app never chooses a recovery volume. The maintainer
clarified that intermittent silencing leaves playback running and that either
the phone's buttons or Control Center restores sound without pressing Play.

## Scope and focus

- Only the `WKInterfaceVolumeControl(origin: .companion)` instance changes identity.
  The native volume indicator remains visible. Class, runtime, count, hands,
  selected page, and native Now Playing retain their state.
- The touch surface is at least 44 points high, widened to the native control's
  width, and clear of the Class button and lower actions. A transparent tap layer
  intercepts volume-area taps; it introduces no new focusable button or Crown
  binding. VoiceOver exposes a labeled refresh action on the volume element.
- The native adapter retains its requested-focus guard, one queued
  `focus()`/`resignFocus()` call when intent changes, and synchronous resign on
  removal. Build 12 delays only a manual replacement's first focus request.
- Duplicate taps while replacement is pending are ignored. Old-generation
  callbacks cannot complete a newer refresh or clear newer confirmation feedback.
- Clock renders, ordinary dim/wake, page returns, and media reloads do not replace
  the volume control. Startup/background setup is separate from explicit refresh;
  neither detects a failure.

## Simulator evidence, October 24, 2026

Xcode 27.1, watchOS 27.0, SE 3 40 mm. Four explicit refreshes each produced one
replacement control and one completion event, including taps during a running
class/count and after verified reduced-luminance Lock/unlock. Each old control's
resign returned before the new focus call. Recorded focus request-to-return
intervals for these replacements were approximately 10–15 ms; these are framework
call timings, not physical Crown/audio latency measurements. No superseded or
post-removal focus call was observed.

Horizontal navigation starting within the enlarged tap area selected native
Now Playing without another volume refresh. Returning restored the existing
replacement control's focus calls. Both pages rendered. A partial swipe that
returned to the timer also did not refresh the control. A lower-edge tap outside
the original native widget height triggered refresh successfully.

Saved ClassContext and runtime intent were unchanged; the same running runtime
continued. The same count run reached completion without cancellation/restart.
Its vibrations stopped under the existing late-haptic rule (about 0.57 seconds
late at the 30-second landmark); visual counting continued. This test does not
claim uninterrupted haptics. Series 46 mm and Ultra 49 mm rendering were also inspected; eight-size
layout checks cover the expanded target and separation from other controls.

All eleven deterministic suites and Simulator/signed-device builds passed.
Private screenshots and journal snapshots remain under ignored
`work/support/2026-10-24-volume-refresh/`.

## Physical validation still needed

1. Ordinary Crown response remains immediate before any refresh.
2. Tap, allow the quarter-second settling interval, then turn the Crown: volume
   responds with native feedback without needing a media visit. Repeat after
   wrist-down/wake; confirm a Now Playing round trip adds no settling delay.
3. Confirm tap accuracy and swipe behavior while moving/teaching.
4. During a real silencing incident, note whether a refresh followed by an upward
   Crown turn restores sound without touching the phone or visiting media.
5. Pull both-device logs and the app journal soon afterward. A refresh request
   is a user action, not proof a failure occurred; a completion is not proof it
   fixed sound. Compare with the known phone-side recovery if it does not help.

The paired-Simulator audio path still does not provide validated companion
volume control, so this is not a reproduction or proven fix of the mute bug.
See [incident evidence](MEDIA_INCIDENT_2026-10-23.md) and
[diagnostic event meanings](INTERFACE_DIAGNOSTICS.md).
