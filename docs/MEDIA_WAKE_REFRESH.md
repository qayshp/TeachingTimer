# Bounded media wake refresh

Build 24, October 29, 2026. [Issue #8](https://github.com/qayshp/TeachingTimer/issues/8)
tracks a visible but frozen song-progress indicator, separately from blank media,
timer Crown nonresponse, and volume silencing. The reported class used build 16.
Exact symptom time and the native cause remain unknown.

## Policy

- Record the first reduced-luminance callback using monotonic system uptime.
- On wake, require both active scene and non-reduced luminance, in either callback order.
- Refresh only the selected media page after at least 30 seconds dimmed, and only
  when at least 60 seconds have elapsed since any media refresh.
- Consume the wake even when suppressed. There is no delayed timer or periodic retry.
- Page entry and background-return refreshes clear pending wake recovery and
  update the cooldown timestamp. Existing explicit navigation recovery stays immediate.
- Recreate only the native media host by identity. Do not replace the timer's
  native volume widget, alter its focus sequence, reset class/runtime/count, or
  issue playback commands. A brief native loading/focus interruption remains possible.

The journal records `media_reload_requested` with `source=long_dimmed_wake`,
previous/new generation, scene/luminance and runtime/count context. As with
other preventive reloads, `failureDetected=unobserved`: this is not evidence of
stale pixels or proof that progress recovered. Thresholds are named constants
in `MediaReloadPolicy`; no user setting is added.

## Verification and limits

Deterministic tests cover the exact 30-second threshold, short wakes, callback
ordering, one-shot behavior, 60-second cooldown, timer-page exclusion and
navigation/background deduplication. All 12 Swift suites pass and the Simulator
build succeeds. Existing SE 3 focus/lifecycle checks pass with unchanged class
bytes, host process and native volume identity. Native Not Playing renders.
All 80 Python checks and repository consistency checks also pass.

An actual SE 3 Lock/wake run confirmed reduced luminance, waited 65 seconds,
then toggled Lock off. Exactly one `long_dimmed_wake` refresh occurred. Class
bytes, runtime and native volume identity stayed unchanged; the media screen
rendered Not Playing. Returning to timer requested focus with zero settling
delay and returned in about 12 ms. These are lifecycle/API observations, not
proof of Crown ownership. Initial test-driver attempts checked the wrong journal
and incorrectly assumed a screen tap cleared Lock; corrected verification uses
InterfaceDiagnostics and the explicit Lock toggle. Private evidence is retained
under `work/support/2026-10-29-media-wake/`.

Physical validation remains required: leave real iPhone music playing, remain on
media while wrist-down, wake after a longer interval, observe progress and audio
continuity, try media Crown control, then return to timer and test immediate
Crown volume. Repeat a short wrist wake and several closely spaced wakes. The
Simulator does not establish phone audibility, source selection or Crown ownership.
This build is not installed on the Watch as part of this change.

## November 2 physical Beta 35 follow-up

The [supervised test](MEDIA_PROGRESS_INCIDENT_2026-11-02.md) records both page-entry
refreshes and two eligible `long_dimmed_wake` refreshes on a physical SE 3. Runtime
recovery and class preservation passed when returning from Home and the standalone
Now Playing app; timer Crown checks also passed with iPhone-speaker playback.

The user nevertheless observed embedded progress updating once on entry and then
remaining stale, including during a requested bright-screen comparison. Repeated
page entry produced a newer snapshot rather than reliable ongoing progress.
The standalone Now Playing app appeared to advance normally. These observations
show that native-view recreation does not guarantee live progress. In a follow-up,
the user confirmed that automatic refresh after inactivity does update the
displayed position. This is a useful physical position-catch-up result, separate
from restoring continuous progress. It is not matched to a particular recorded
refresh timestamp and does not establish the underlying cause. The app's timeline
ancestor remains a variable to test.
