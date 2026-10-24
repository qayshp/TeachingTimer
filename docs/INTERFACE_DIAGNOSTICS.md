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
| `media_reload_requested` | Explicit Class-options recovery request, native media generation, active-count flag/progress, and existing runtime context. Not proof of rendered recovery. |
| `volume_control_created`, `volume_control_dismantled` | Native control creation/removal, identified by `controlID`. |
| `volume_focus_requested` | Focus or resign request, identified by `requestID`, from `update` or `dismantle`. |
| `volume_focus_call`, `volume_focus_call_returned` | Immediately before and after the existing WatchKit call; its return does not confirm focus was granted. |

Volume events identify `.companion` as the configured origin, not a discovered
audio route. They include the latest request ID/focus intent, whether the
particular request is superseded, whether dismantling has occurred, and monotonic
`secondsSinceRequest`. On `volume_focus_call`, this interval includes time waiting
for the queued callback. It is not an audio-command round-trip measurement.
`actualFocus` is always `unobserved` because no confirmation is available here.

Root interface events also include `mediaViewGeneration`. It changes only for
an explicit **Reload media** request; it is not an automatic failure detector.
The request changes only the native media view's SwiftUI identity, then selects
that page after the Class sheet dismisses. Check pixels separately and compare
runtime, count run, and volume-control IDs across the request.

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

On October 22, the maintainer reported a different failure with Apple Music on
iPhone → AirPlay → the same WiiM: the media page stayed entirely black, showed
no media or transport controls, and could not control volume. The timer page
and its volume control continued to work. This is not merely a visible "Not
Playing" state. The Watch journal for that class has not yet been collected;
whether this shares a cause with the earlier volume silencing remains unknown.

These journals cannot read the receiver's volume, verify the active AirPlay
route, capture Crown deltas, confirm real focus, or prove that sound was heard.
Correlate them with observations; absence of an event is not proof of a cause.
Follow-up retrieval for the October 22 incident confirmed repeated media-page
selection/appearance callbacks while runtime was running, with timer-control
resign/focus calls executing and returning on navigation. This does not verify
native media pixels or actual Crown ownership. A foreground interruption and
successful restart occurred between visits; visits spanned both sides, so that
interruption alone does not explain the report. Available crash-report inventories
did not identify a matching same-day media crash. After administrator approval,
the iPhone unified archive was collected; targeted and broader media searches
of the class interval yielded only sparse, non-diagnostic entries. Direct Watch
unified collection failed with connection-refused and device-not-configured
errors despite device availability and trust. Root cause remains unconfirmed;
no media/focus behavior was changed. Detailed evidence stays under ignored
`work/support/2026-10-22-media/`.

The maintainer subsequently clarified that the foreground interruption was an
intentional switch to another app to try to recover the black media page.
Returning did not restore it; force-quitting was not tried. Do not characterize
this event as unexplained foreground loss. The first retained event is consistent
with the reported late opening of the app during class, but retention boundaries
and callbacks cannot establish the exact first opening time.

Review/redact journals before sharing; never commit raw device logs to GitHub.

## October 23 physical recurrence

Original Watch screenshots confirm entirely black media pages at 12:29:07 and
18:52:31, with the media-page dot visible. A timer screenshot at 12:29:10 still
shows its controls. The maintainer reports recovery after force-closing and
reopening before the noon class. Standalone Now Playing was not checked during
either incident. Do not substitute the Simulator's visible "Not Playing" state
for this physical failure; prior black-timer Simulator observations are also a
separate symptom until a shared cause is demonstrated.

The retained evening journal shows media-page callbacks during a running
session, then app relaunch and idle runtime until manual Start several minutes
later. Build 6 addresses that separate recovery gap through persisted runtime
intent; see [runtime recovery](RUNTIME_RECOVERY.md). It does not change the
native media view, volume adapter, focus sequence, or page structure.

The next priority is incident-time system evidence and a narrow test of
recreating only the native media view as a user-requested recovery action.
There is no reliable public blank-pixel detector here, so do not add automatic
periodic media-view resets or claim this is definitively an Apple defect.
[Watch log collection](WATCH_LOG_COLLECTION.md) records the new CoreDevice
sysdiagnose route and the limits of the earlier direct-collector error.
