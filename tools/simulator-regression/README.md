# Bounded Device Hub regression captures

## Run the combined suite

`suite.py` runs the existing checks serially and verifies their evidence before
calling a stage complete. It requires an explicit, already booted disposable
Watch Simulator named `TeachingTimer Regression…`, an ad-hoc-signed Simulator
app, a new output directory and permission to reset that Simulator's TeachingTimer
data. It never boots/creates a simulator or contacts a physical device.

```sh
# SE 3 40 mm: essential actions, focus lifecycle, then count/Lock captures.
python3 tools/simulator-regression/suite.py --simulator SIMULATOR_UUID \
  --app /absolute/path/TeachingTimer.app --reset-test-app \
  --lifecycle focus --controls --output work/regression-suite-se3-new

# Ultra 4 49 mm: actions and count/Lock; lifecycle coordinates are SE 3-only.
python3 tools/simulator-regression/suite.py --simulator SIMULATOR_UUID \
  --app /absolute/path/TeachingTimer.app --reset-test-app \
  --controls --output work/regression-suite-ultra-new
```

Device Hub must be open with Accessibility permission for the invoking process.
Keep its display visible and avoid concurrent manual or automated input.
The first stage uninstalls/reinstalls only the selected Simulator's TeachingTimer;
`--controls` resets that test app again before its capture sequence. The simulator
is left running. Do not use a simulator whose app data you want to preserve.

`--lifecycle media --allow-service-termination` can replace the focus stage on
SE 3. It explicitly permits the existing media fault-injection test described
below. Focus and media are separate runs because focus leaves a count active;
chaining their setup taps would otherwise cancel that count.

The suite retains stage logs and `suite.json`. A missing result, failed assertion,
missing required capture or timeout fails the run; process exit alone is not a
pass. Every run still requires screenshot review. Neither the suite nor its
state assertions prove native pixels, real Crown ownership, phone audio, or
physical haptic delivery. See the [automation coverage map](../../docs/AUTOMATION.md)
for CI versus interactive and hardware boundaries.

## Individual focus and media runs

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

**October 28 correction:** the nine delayed images included in the later Apple
comparison contain Not Playing. Their earlier black-frame classification was
incorrect. The historical visual conclusions below require revalidation against
original pixels; callbacks and OCR warnings alone cannot establish failure.

Build 18 / Xcode 27.1, watchOS 27.0 SE 3 40 mm: both sequences passed lifecycle
checks, preserving host, class and native volume-control instance. Home caused
`resigned_frontmost`; automatic recovery restarted runtime with the class intact.
The historical black-page interpretation is withdrawn pending an original-image
audit. No actual phone-volume or continuous-runtime success follows from this.
Private original captures are under `work/support/2026-10-26-second-batch/`.

## Follow-up comparison

[Recovery comparison](../../docs/MEDIA_RECOVERY_COMPARISON.md) records four
experimental candidates and superseded visual classifications. No reliable
recovery ranking was established. Setup now waits up to ten seconds for the new class's
UserDefaults write. Each media stage receives an additional five-second capture;
this is observation, not an automatic retry or a visual success assertion.

## Essential teaching actions

For bounded count/Lock/wake captures, use `timer_controls.py` with the same
`--simulator`, `--app`, `--output` and explicit `--reset-test-app` arguments.
It supports default-size SE 3 40 mm and Ultra 4 49 mm captures. A final full-duration count must finish normally while locked; its run ID and
completion deadline are checked. OCR and count
outline measurements flag frames for review; they never prove disappearance,
touchability or native audio behavior. See the [investigation and correction](../../docs/TIMER_CONTROL_INVESTIGATION.md).

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

## Original media-image audit

Use `media_evidence.py --output NEW_DIRECTORY ORIGINAL.png ...` for read-only
OCR and central-content measurements, with original SHA-256 hashes. It never
infers rendering failure from missing text alone or success from callbacks.
The [October 28 audit](../../docs/MEDIA_IMAGE_AUDIT.md) confirms the original
October 24 black captures and withdraws the later delayed-frame interpretation.

## Force-close and reopen

After a suite with `--controls` leaves a running class, verify persistent runtime
intent across actual app-process replacement:

```sh
python3 tools/simulator-regression/relaunch.py --simulator SIMULATOR_UUID \
  --output work/relaunch-new
```

This requires a booted disposable SE 3/Ultra and its existing running class. It
neither installs nor resets the app. It first requires journal-confirmed active scene/non-reduced luminance (native
application state alone is insufficient), then checks automatic recovery for that exact
saved class, uses the Stop session action, waits for the stopped intent to persist,
and relaunches again. A three-second observation must show restored Stop without
an automatic start. It leaves the simulator's class intact and session stopped.
Screenshots, original journal/preferences snapshots and artifact identity are
retained. This shares the suite's exclusive Device Hub lock.
