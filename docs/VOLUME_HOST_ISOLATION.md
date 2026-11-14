# Experimental stable volume host

Experiment for [issue #3](https://github.com/qayshp/TeachingTimer/issues/3), based
on the [November 13 physical incident](VOLUME_INCIDENT_2026-11-13.md). This is a
candidate mitigation, not a diagnosed framework fix. It remains separate from
main until reviewed; no physical installation or TestFlight publication is
implied by this document.

## Change and invariants

The timer page is now a stable child of `TabView`. Its static dial, Class/settings
button, Class-sheet owner and retained native companion-volume control live
outside scheduled drawing. One anchored one-second `TimelineView` supplies the
same sampled date to class/count graphics, date-dependent action labels and
both foreground clock hands. Clock/class/count invalidation remains in that
scheduled subtree.

The volume adapter, its identity, focus state machine, cancellation guards and
native `.companion` origin are unchanged. Startup/background setup still stages
for one second; explicit refocus still waits 250 ms; media-to-timer return keeps
its immediate focus path. No scalar setter, custom Crown handler, readiness claim,
extra gesture, artificial volume floor or discarded first movement is added.
Class, runtime and landmark state retain their existing owners.

`ClockAdditions` moves above volume in compositing order. Its painted landmark
dots, class-progress stroke and end markers remain geometrically clear of both
the native frame and the visible backing circle across all eight tested sizes.
New checks protect that premise. Both hands remain above controls. Simulator
interaction checks cover the controls and app-side focus lifecycle; paired-phone
commands and audibility still require physical testing.

## Reconstructed state at 19:04:27 PST, November 13

The table combines historical journal/system records, not a screenshot or a
capture-time device snapshot. Raw diagnostics and exact correlation identifiers
remain private.

| Component | Established state | Limit |
| --- | --- | --- |
| Watch display / wearer | Wrist raise completed; active/full luminance, unlocked and on wrist before Crown input. Battery 48%, not charging at the preceding sample. | No recorded ring image or signed Crown delta; battery is a preceding sample. |
| TeachingTimer | Same process and retained native control from earlier classes. Timer selected; Crown-associated input and native control action precede zero. | Window-visible/input routing does not prove internal control focus or every pixel. |
| Native volume model | An earlier remote-device XPC interruption/replacement occurred at 18:55:14. The new connection obtained 0.625. The native widget survived. | Internal interaction baseline and individual native child subscriptions are inaccessible. |
| Focus | Last page-return focus completed about 22 seconds before zero. No matching late focus callback, replacement or accepted refresh at zero. | The void return does not establish actual native focus. |
| Now Playing | Recovery rebuilds its view, generation 18 to 19, within the same service process. | View recreation is not a process restart or a proven pixel repair. |
| Runtime / class | Mindfulness runtime running, no expiry/renewal at the outage. Scheduled class anchor remained 18:45 despite late app Start. | Runtime start and scheduled class start are distinct. |
| Landmarks | A six-landmark run was active; two local haptic pulses preceded Crown input. Haptic policy says route/volume cannot be set. | Submission/policy does not measure physical vibration; no causal bridge to companion zero was found. |
| iPhone | Unified logs show display off and locking at 18:48:34–35, with no later transition through 19:05 in the calibrated historical records. Correctly aligned incident samples show approximately 66% battery, external power and charging, no critical-battery flag. | Powerlog uses a stored time offset; its raw timestamps are not directly comparable with unified logs. Exact zero-time thermal state and complete renderer health are unknown. |
| Playback | Amazon Music remained active in the background and was the locally playing volume client. Now-playing item updates preceded zero. | No PCM recording, sample-rate proof or continuous decoder measurement. |
| Route / transport | Same wired USB absolute-volume route handles zero and recovery. All 62 retained MediaRemote IDS send outcomes report success. | Retained outcomes are not an inventory of every network packet or all app connectivity. |
| Nearby errors | Recurring Now Playing app-info lookup errors also precede successful recovery. Amazon's own Watch-app-not-installed errors follow zero. A phone UI helper suspends after zero; core media/audio daemons remain stable. | These are surrounding records, not demonstrated causes or TeachingTimer companion-install failures. |

The [opening/playback timeline](VOLUME_TIMELINE_2026-11-13.md) confirms that
Amazon launched at 18:48:12 and began playback at 18:48:23, before TeachingTimer
returned at 18:55:14 and started its runtime at 18:55:17. The correct 0.625 model
update precedes runtime start; the brief readiness zero is not the later outgoing
zero. Phone powerlog timing was calibrated using its explicit stored system
offset and 39 matching volume transitions. This corrects an earlier draft
interpretation of lock time and battery percentage.

This supports investigating a retained native interaction state across connection,
view and display transitions. It does not prove the timeline caused zero, or
exclude a large/coalesced downward input reaching minimum.

## Additional experiments and artificial states

Change one factor at a time and preserve the known starting phone level, signed
input script, page, scene/luminance transitions, object generation and requested
absolute values. Record the native ring and audible result for physical runs.

| Test | How to force the condition | Useful result / boundary |
| --- | --- | --- |
| Native baseline versus isolation | Repeat cold start, Home/reopen, Class sheet, refresh, media return and dim/wake with otherwise identical builds. Begin with a small explicitly upward Crown movement. | Compare the first outgoing value with the starting level; visible ring response alone is insufficient. |
| Endpoint replacement and music-before-class | Retain the Watch control while the app is suspended, attach phone USB audio, freshly launch Amazon, start playback and change phone volume, then return to TeachingTimer and start the class. Separately test route reconnection while the app is foreground. | Stress the observed connection-generation transition; no private framework cache mutation is needed. |
| Delayed baseline and stale interaction model | In a separate fake-control harness, deliver unavailable/zero then 0.625 late; deliberately leave a distinct interaction baseline at zero. | Prove the test oracle detects an unintended zero for a known positive delta. This does not reproduce the private native control. |
| Late/out-of-order callbacks | Deliver an obsolete focus or endpoint-generation callback after media selection, replacement or a newer request. | Assert stale work cannot reclaim focus or overwrite newer intent. Existing model checks cover stale focus/removal; endpoint emulation belongs in a probe. |
| Wake/input boundary | Replay dim/full transitions and vary known Crown input timing: before wake, on activation and shortly afterward. | Measure callback order and first value without adding a production gesture delay. |
| Haptic concurrency | Repeat with Count vibrations enabled/disabled, then align input near a pulse in a probe. | Test the observed overlap while keeping all other inputs equal; local haptic mute strings are not companion-music mute evidence. |
| Surviving service / fresh view | Recreate only native media while its service survives; separately use the existing Simulator-only service-termination scenario. | Distinguish controller generation, process generation and retained timer state. A killed service is an artificial fault, not proof of the physical cause. |
| Burst and feedback delay | Use explicit positive/negative bursts and delayed, duplicated or reordered acknowledgments in a fake endpoint. | Distinguish intended saturation/coalescing from a discontinuity; validate the harness without claiming native cache access. |
| Fresh native control | Use the existing probe's replacement variant only after the retained baseline. | Lower priority: replacing the widget previously caused dead Crown feedback. Repeat the focus regression before considering production use. |

The public native API exposes no scalar/readiness callback. Do not add private
selectors, synthetic playback, or phone-side automatic volume restoration to the
teaching app merely to manufacture a result. A fake model validates a hypothesis
and test harness; only observed native behavior can establish a native fix.

## Verification record

The candidate compiles for Watch Simulator and generic watchOS. All 16 Swift
suites and 375 Python tooling checks pass. The expanded layout suite covers
5,760 landmark positions, eight full progress strokes and 960 end-marker
triangles against the native frame and backing circle.

Interactive Simulator checks and representative awake/dimmed screenshots were
reviewed on SE 3 40 mm and Ultra 4 49 mm, using watchOS 27.2 (24S118):

- SE 3: all 21 essential actions, all six focus-lifecycle assertions, and the
  33-frame count/Lock sequence passed. This includes refresh, media return,
  Home/reopen and unchanged native-control identity.
- Ultra: all 21 essential actions and the 33-frame count/Lock sequence passed on
  the retry. The initial run missed one native Help-to-Settings Back tap; the same
  tap then worked and the unchanged suite passed. The SE-only focus scenario was
  not run on Ultra.
- Both sizes completed all six landmark groups while locked, ending at about
  64.8 seconds. Sampled button outlines had no missing-edge warnings. OCR needed
  visual review where the deliberately foreground hands crossed labels; the
  reviewed frames retained their control outlines and expected states.
- An unrelated physical-Watch download-error dialog initially blocked Device Hub
  input in both the unchanged app baseline and candidate. The helper now rejects
  an existing modal before input and checks again after device selection. Its
  negative live check rejected the real dialog; compilation and the unobstructed
  bounds check passed. The dialog was not an app-layout regression.

The local app is build 61, compiled from the experiment's app source before
commit, with revision metadata `4de5168e56cb-dirty`. Its executable hash is recorded
in both suite manifests; the app source matches committed `bb0ae03`. Hosted Watch
checks and CodeQL also passed for that immutable commit. All 375 Python tests were rerun after the helper guard change; the guard also
has its separate compile/live checks.

[Draft PR #33](https://github.com/qayshp/TeachingTimer/pull/33) remains unmerged.
No physical audio or Crown response is claimed by these checks, and no physical
Watch install or TestFlight publication was performed for this experiment.
