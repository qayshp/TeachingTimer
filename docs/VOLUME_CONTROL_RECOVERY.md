# Tap-to-refresh volume control — build 9

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
- The existing native adapter retains its requested-focus guard, one queued
  `focus()`/`resignFocus()` call when intent changes, and synchronous resign on
  removal. The only addition to that path is a notification after focus returns.
- Duplicate taps while replacement is pending are ignored. Old-generation
  callbacks cannot complete a newer refresh or clear newer confirmation feedback.
- Clock renders, dim/wake, page returns, and media reloads do not replace the
  volume control. This is explicit recovery, not automatic fault detection.

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
2. Tap, then immediately turn the Crown: volume responds, with visible native
   feedback. Repeat after wrist-down/wake and a Now Playing round trip.
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
