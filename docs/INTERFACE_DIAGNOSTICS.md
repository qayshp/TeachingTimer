# Page and volume diagnostics

These diagnostics investigate two unresolved symptoms: an intermittently blank
teaching page, reported in Simulator and on a physical Watch, and timer-page
Crown adjustment silencing playback while native Now Playing can still adjust
volume. They do not attempt to repair either behavior.

## Journal and correlation

Events go to the existing local `Documents/RuntimeDiagnostics.json`. Its bounded
1,000-event history survives relaunch; older entries rotate out. Writes and
encoding are off the main thread, with the existing corrupt-file preservation.
A sudden process kill can lose the most recent queued events. Pull the journal
soon after an incident, together with `LandmarkDiagnostics.json` if relevant.
Do not uninstall the app or clear its container to recover a blank page before
collecting evidence.

All interface events carry `category: interface`, a launch ID, the runtime ID
when present, runtime phase, last reported scene state, current application
state, wall timestamp, and high-resolution `launchElapsedSeconds` from a
monotonic clock. The existing `app_launched` event identifies the build/revision.
Elapsed time is relative to launch, not raw device uptime.

## Events

| Event | Meaning and limits |
| --- | --- |
| `interface_appeared`, `interface_disappeared` | Root SwiftUI lifecycle callbacks. |
| `page_selection_changed` | Previous and newly selected tab. Not proof that the selected content is visible. |
| `page_appeared`, `page_disappeared` | Callback for `observedPage`, plus current `selectedPage`. Pages may be prepared before selection; this is not pixel evidence. |
| `luminance_changed` | SwiftUI reduced-luminance value changed, with previous/current values. No independent wrist-motion measurement. |
| `interface_scene_changed` | Scene transition with page/dimming context, alongside existing `scene_state_changed` runtime events. |
| `class_sheet_state_changed` | Whether the timer view requests its Class sheet; not confirmation of presentation completion. |
| `volume_control_created`, `volume_control_dismantled` | Native control creation/removal, identified by `controlID`. |
| `volume_focus_requested` | Focus or resign request, identified by `requestID`, from `update` or `dismantle`. |
| `volume_focus_call`, `volume_focus_call_returned` | Immediately before and after the existing WatchKit call; its return does not confirm focus was granted. |

Volume events identify `.companion` as the configured origin, not a discovered
audio route. They include the latest request ID/focus intent, whether the
particular request is superseded, whether dismantling has occurred, and monotonic
`secondsSinceRequest`. On `volume_focus_call`, this interval includes time waiting
for the queued callback. It is not an audio-command round-trip measurement.
`actualFocus` is always `unobserved` because no confirmation is available here.

The `lastView...` fields are the last inputs supplied to the native-control
adapter: timer page selection, Class-sheet request, and reduced luminance. They
are snapshots, not a fresh query of onscreen visibility. Ordinary one-second
view updates refresh the snapshot but do not write events. No render heartbeat
or frame-rate measurement has been added.

## Preserve the experiment

The control still has the same origin, tint, requested-focus guard, one queued
focus/resign call when intent changes, and synchronous resign on removal. Even
if a pending call later executes after removal, diagnostics only record it;
they do not cancel, reorder, or retry the call. The timing, tab hierarchy, hands,
landmarks, and runtime policy are unchanged. Logging has some overhead and is
not a guarantee of identical timing under every condition.

## Useful incident details

- Approximate time, Watch/phone OS and app build, and whether runtime/count were on.
- Blank page: last action (swipe, raise wrist, Class sheet, return from another
  app), which page dot was selected, whether swiping still worked, and what
  restored the face. A photo is useful if convenient outside teaching.
- Silencing: iPhone playback app and connection type (Bluetooth, AirPlay, cable),
  receiver type, whether the track timer continued, whether the volume indicator
  moved, and which device/control restored sound. Do not assume silence means a
  pause or a zero-volume command.

The October 21 report involved iPhone → AirPlay → WiiM → speaker system; the
last connection type was not specified. Raising volume on the iPhone restored
both timer-page and Now Playing volume adjustment. This narrows reproduction
conditions but does not identify a cause. It is not a guaranteed workaround.

These journals cannot read the receiver's volume, verify the active AirPlay
route, capture Crown deltas, confirm real focus, or prove that sound was heard.
Correlate them with observations; absence of an event is not proof of a cause.
Review/redact journals before sharing; never commit raw device logs to GitHub.
