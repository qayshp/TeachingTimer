# Bounded Device Hub regression captures

The focus/media runner (`run.py`) requires macOS Accessibility permission for the invoking terminal/agent, Xcode 27
Device Hub open, and an already booted **disposable SE 3 40 mm** simulator named
`TeachingTimer Regression…`. Never targets physical devices. Keep its display
visible and do not interact with Device Hub during the short run. UI coordinates
are specific to the default SE 3 layout; this is not an all-size UI test.

Build TeachingTimer for Watch Simulator, then run:

```sh
python3 tools/simulator-regression/run.py --simulator SIMULATOR_UUID \
  --app /absolute/path/TeachingTimer.app --scenario focus \
  --output work/regression-focus-new
python3 tools/simulator-regression/run.py --simulator SIMULATOR_UUID \
  --app /absolute/path/TeachingTimer.app --scenario media \
  --allow-service-termination --output work/regression-media-new
```

The runner installs the supplied app, establishes a class if absent, and taps the
count control. Start with a current, non-retiring class (or no class), an inactive count and the timer page selected. It
leaves the simulator running. Output directories must be new. They contain
private preferences/journals, screenshots and timestamped command outcomes;
keep them out of Git. A command returning is not proof of its visual effect.

`focus` exercises Crown input, Home/reopen, refresh, media, and timer return.
`media` requires explicit opt-in to terminate exactly one running native Now
Playing view-service label **inside the selected disposable simulator** while
TeachingTimer is at Home. It tests recovery without terminating the app host.
Missing or ambiguous services stop the test. This deliberate fault does not
establish the cause of physical-Watch blank pages.

The result checks host process, saved class bytes, control identity, page changes
and refresh requests. **Inspect screenshots separately**, including the delayed
media capture: successful callbacks do not mean that pixels rendered, focus was
acquired, phone volume changed, or haptics were delivered. With no compatible
phone media source, an unchanged volume ring is inconclusive.

## October 26, 2026 evidence

Build 18 / Xcode 27.1, watchOS 27.0 SE 3 40 mm: both sequences passed lifecycle
checks, preserving the host, class and native volume-control instance. Home and
refresh screenshots showed no visible volume-ring change in this unpaired setup.
The media-service-loss run rendered Not Playing on first reopen, but the next
media entry was black. A repeat run retained the black page after five seconds,
despite a recorded automatic reload request. Another entry in the first run
rendered normally. This remains a failing visual regression, not a proven fix.
Home caused `resigned_frontmost`; automatic runtime recovery restarted the
session with the original class intact. No claim of uninterrupted runtime is made.
The runner captures early and delayed frames at all three media stages and never labels lifecycle checks
a visual pass. Private capture folders are `media` and `media-delayed` under
`work/support/2026-10-26-second-batch/` on the development Mac.

## Follow-up comparison

[Recovery comparison](../../docs/MEDIA_RECOVERY_COMPARISON.md) records four
unsuccessful recovery candidates and the distinction between short loading gaps
and longer blank pages. Setup now waits up to ten seconds for the new class's
UserDefaults write. Each media stage receives an additional five-second capture;
this is observation, not an automatic retry or a visual success assertion.

## Essential teaching actions

`actions.py` is a separate destructive-to-test-data regression on a **disposable**
Watch Simulator named `TeachingTimer Regression…`. It requires explicit
`--reset-test-app` because it uninstalls/reinstalls only TeachingTimer on that
simulator. It never accepts a physical device. Use a normal ad-hoc-signed
Simulator build: an unsigned app can open yet fail extended-runtime startup.

```sh
python3 tools/simulator-regression/actions.py --simulator SIMULATOR_UUID \
  --app /absolute/path/TeachingTimer.app --reset-test-app \
  --output work/essential-actions-new
```

The suite checks default Start, custom draft Cancel, count start/cancel,
Stop/Resume, schedule edit Cancel/Save, custom New class with confirmation,
End class with confirmation, and media/timer navigation. It checks persisted
class values and fresh journal events, waiting at most thirty seconds for an asynchronous persisted-state
assertion. It retains every target screenshot and recognized text, actions and
results. Missing/ambiguous targets fail; they never silently skip a step.

Device Hub does not expose the Watch application's accessibility nodes here.
Menu targets therefore use screenshot OCR; face controls use screen-relative
positions because the moving hands can cover their text. This is a local,
English/default-text-size test, not a portable XCTest suite. Do not run two UI
sequences concurrently or interact with Device Hub during a run. A screenshot
still needs human review; state assertions do not prove visible controls, native
media pixels, Crown ownership, phone playback or tactile delivery.
