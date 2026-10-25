# Page and volume diagnostics

These diagnostics investigate two unresolved symptoms: an intermittently blank
teaching page, reported in Simulator and on a physical Watch, and timer-page
Crown adjustment silencing playback while native Now Playing can still adjust
volume. Diagnostics record observations; bounded media refresh, staged volume setup,
and explicit volume refresh are separate actions, not evidence that a fault occurred.

## Journal and correlation

Build 10 separates operational evidence from routine wrist transitions:

- `Documents/RuntimeDiagnostics.json` retains seven days of runtime, class,
  page, media, and volume events, with a 10,000-event safety cap. Background
  entry/exit and initial scene state remain here. New Class does not clear it.
- `Documents/InterfaceDiagnostics.json` retains routine active/inactive and
  reduced-luminance transitions for one day, with a 4,000-event safety cap.
  These precise timestamps remain useful for dimming investigations, but cannot
  displace earlier classes from the operational journal.
- `Documents/LandmarkDiagnostics.json` keeps its existing 2,000-event policy.

Age pruning happens on the next write to each file. Count caps can shorten the
time window under exceptional event volume; these are bounds, not guaranteed
minimum retention. Existing runtime history is read in place and is not cleared
on upgrade; already-rotated entries cannot be recovered. Old interface events
already in that history age out normally rather than being moved retroactively.

Encoding and atomic file replacement stay off the main thread, with corrupt-file
preservation. Routine callbacks batch for 250 ms; launches, runtime start/stop,
invalidation/expiration, and significant scene changes request an immediate
queued write. A sudden process kill can lose the latest queued events. Pull all
three files soon after an incident; detailed system logs have separate retention.
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
| `luminance_changed` | In the interface detail file: SwiftUI reduced-luminance value changed. No independent wrist-motion measurement. |
| `scene_state_changed` | One canonical scene event with previous/current state and page/dimming/media-generation context. Background entry/exit and initial state go to the runtime journal; ordinary active/inactive transitions go to the interface file. |
| `class_sheet_state_changed` | Whether the timer view requests its Class sheet; not confirmation of presentation completion. |
| `media_reload_requested` | Native-view recreation request: source, manual/automatic mode, previous/new media generation, active-count flag/progress, and existing runtime context. `failureDetected: unobserved`; not proof of failure or rendered recovery. |
| `volume_refresh_requested` | Explicit timer-volume tap, with previous/new request generation and `failureDetected: unobserved`. Build 13 uses `volumeRequestGeneration` and `controlReplaced: false`; older builds used `volumeControlGeneration` for replacements. Does not change page or media generation. |
| `volume_refresh_completed` | The requested focus call returned. `completion: focus_call_returned`, `actualFocus: unobserved`, `audioRecovery: unobserved`. Not proof of Crown routing or audible recovery. |
| `volume_setup_scheduled`, `volume_setup_cancelled` | Build 11 settling attempt on startup/background return, including attempt ID, background revision and one-second delay. Cancellation means eligibility changed or the view was removed; no control was created by that attempt. |
| `volume_setup_requested`, `volume_setup_focus_returned` | Automatic startup/background setup, then the requested focus call returned. Build 13 creates the widget only on initial setup and retains it afterward. Sources are `startup` or `background_return`; request generation connects the lifecycle events. Actual focus and audio recovery remain unobserved. |
| `volume_focus_call_skipped` | An obsolete queued update was prevented from invoking WatchKit because the control was dismantled or a newer focus intent superseded it. No focus/resign API was called for this event. |
| `volume_control_created`, `volume_control_dismantled` | Native control creation/removal, identified by `controlID`. |
| `volume_focus_requested` | Focus or resign request, identified by `requestID`, from `update`, `dismantle`, or build 13's explicit `refocus` cycle. |
| `volume_focus_call`, `volume_focus_call_returned` | Immediately before and after the existing WatchKit call; its return does not confirm focus was granted. |

Volume events identify `.companion` as the configured origin, not a discovered
audio route. They include the latest request ID/focus intent, whether the
particular request is superseded, whether dismantling has occurred, and monotonic
`secondsSinceRequest`. On `volume_focus_call`, this interval includes time waiting
for the queued callback. It is not an audio-command round-trip measurement.
Build 12 adds `settlingSeconds` to request/call/return/skip events: 0.25 for the
first focus request on a manually replaced widget, otherwise zero. Build 13 uses
0.25 for manual/background refocus on the retained widget; initial focus and
ordinary page returns remain zero. Compare the
requested settling interval with `secondsSinceRequest` to distinguish deliberate
delay from main-queue scheduling time. An interrupted request cannot reclaim
focus after a newer intent or removal; a media-to-timer return has no extra delay.
`actualFocus` is always `unobserved` because no confirmation is available here.

Build 9 adds `volumeControlGeneration` to the adapter snapshot. Correlate the
refresh request with old-generation removal and new-generation creation/control
IDs, then focus-call ordering. Build 13 renames the counter to
`volumeRequestGeneration`: it counts setup/refresh requests, not native widgets.
The native `controlID` stays the same across those requests. `refocus` records a
synchronous resign followed by one guarded delayed focus; it is not a retry loop.
A tap is ignored while that request is pending.
Build 11 also stages setup once on startup and actual background return. A short
preparation indicator is not a health measurement; automatic setup does not show
a success checkmark. Pages, class/runtime state, count, and ordinary wrist wakes
do not themselves replace a ready widget. The manual checkmark confirms the
returned call, never sound or successful focus. See
[volume recovery](VOLUME_CONTROL_RECOVERY.md).

Root interface events also include `mediaViewGeneration`. Build 8 changes it
once on deliberate media page entry (`source: page_entry`), on an active return
after a recorded background phase while media is selected (`background_return`),
or through **Reload media** (`class_options`). `refreshMode` distinguishes
automatic from manual requests. `previousMediaViewGeneration` ties each request
to the old host; `failureDetected` stays `unobserved` because no public service
health callback is available. Healthy views are recreated too. The journal must
not count automatic requests as failures prevented or recovered.

Only the native media view's SwiftUI identity changes. Manual recovery selects
that page after the Class sheet dismisses and suppresses the duplicate page-entry
refresh. Background return while the timer is selected defers reconstruction
until a media visit. Ordinary inactive/active wrist wakes, timeline frames, and
staying on the page do not trigger reloads. Check pixels separately and compare
runtime, count run, and volume-control IDs across each request. System-service
logs may still preserve an underlying termination even if the page recovers
before the user notices; automatic refresh is not a reliable incident detector.

The `lastView...` fields are the last inputs supplied to the native-control
adapter: timer page selection, Class-sheet request, and reduced luminance. They
are snapshots, not a fresh query of onscreen visibility. Ordinary one-second
view updates refresh the snapshot but do not write events. No render heartbeat
or frame-rate measurement has been added.

## Preserve the experiment

The control retains the same companion origin, tint, native focus/resign API,
and synchronous resign on removal. Build 11 changes creation timing only at
startup and actual background return; it also guards queued update calls so an
obsolete control cannot reclaim the Crown. A skipped call is logged explicitly.
Build 12 adds a one-time 250 ms wait before manual replacement focus, preserving
the existing immediate page-return path. Neither wait verifies native readiness.
Build 13 retains the widget and cycles its focus for manual/background requests;
it removes the identity-based replacements that broke native feedback in the
Simulator reproduction. A request generation change does not imply replacement.
There are no periodic retries, custom Crown handlers, private volume APIs or
chosen recovery volume. Tab hierarchy, hands, landmarks, runtime and media policy
are unchanged. Logging has some overhead and is not a guarantee of identical
timing under every condition.

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

### Noise review in build 10

The October 24 retained runtime file contained 848 scene/luminance records out
of 1,000, covering only about 103 minutes. Each scene transition was recorded
twice. Build 10 removes the duplicate `interface_scene_changed` event and moves
ordinary wake/dim traffic to the detail file. Scene and runtime handling itself
is unchanged. Each operational event still carries its current app state, and
root interface events carry current page/dimming context.

Keep creation/removal, page appearance/selection, and focus request/call/return
records. They are a small fraction of traffic and distinguish a queued request
from an executed call, identify stale generations, and help diagnose blank native
views. Neither appearance nor a returned focus call proves visible/working UI.

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

### October 24: wired-output silencing correlation

The maintainer subsequently recalled timer-page volume adjustment silencing
USB-C-connected audio early in the October 23 18:45 class. Saved iPhone logs
corroborate a USB audio route. At 18:52:47.854 the Watch's native volume framework
inside TeachingTimer requested zero; iPhone Music reported zero at 18:52:48.051.
The app journal places the timer page active with runtime running, and records
no new focus call at that moment. The earlier focus call was not superseded or
invoked on a dismantled control. The black media screenshot was taken about
17 seconds before the recorded zero request, so it is not evidence that this
volume change caused the black page.

This is system-log correlation, not a new readable-volume capability in the app
journal. Unexpected silencing is a high-priority issue across both reported
AirPlay and USB routes; its root cause and relationship to the media-service
failure remain unproven. **Reload media** preserves the companion control and
has not been validated as an audio recovery. See the
[incident timeline and proposed physical comparison](MEDIA_INCIDENT_2026-10-23.md#october-24-follow-up-timer-page-silencing-with-usb-audio).
