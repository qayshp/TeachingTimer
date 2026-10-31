# Supervised physical media test setup

Plan approved for preparation October 31, 2026; execution is not started or
scheduled. No playback, device installation or overnight automation is performed
by this document. Current teaching build: consult [verification](../DEVELOPMENT_STATUS.md).

## Purpose

Capture stale native progress with working Pause/volume, compare the build-25
wake-refresh mitigation, and produce a small reproducible case for Apple
FB25379883. Keep blank media, focus loss and silencing as separate test cases.
Paired Simulator media discovery remains blocked by FB25294079. Preserve the
[October 30 incident](MEDIA_PROGRESS_INCIDENT_2026-10-30.md) and its raw originals.

## First supervised session: approximately 20–30 minutes

| Step | Action | Evidence / exit condition |
| --- | --- | --- |
| 1. Prepare | Record Watch/iPhone/Mac OS, app build, intended audio source/output, battery and device IDs privately. Agree on quiet output and a fixed end time. Copy existing journals. | Explicit target devices and output confirmed; stop if source/route is ambiguous. |
| 2. Control rehearsal | Select Watch/phone in Device Hub; navigate the installed app and capture its screen. Verify one deliberate page switch and recovery. | Actual visible action confirmed, not just a successful automation command. No passcode storage or automated unlock attempts. |
| 3. Known playback | Start an agreed local track on iPhone. Prefer a separate native fixture with actual playback position and metadata timestamps; repeat later in the normal player. | Audible/observed playback, known duration, and independent position reference. A fixture is not yet installed or validated on hardware. |
| 4. Observe | Compare continuous screen sharing with a disconnected observation interval. Try short (~10 s), medium (~35 s) and longer (~70 s) dim/wake intervals, including recurrence soon after refresh. | Confirm actual dim/wake. Simulator Lock is not assumed equivalent on hardware. Reconnecting the mirror may itself affect reproduction. |
| 5. Capture before recovery | On suspect progress, save a short recording showing two positions several seconds apart, phone position/play state and exact times. Then one page-away/back recovery. | Freeze candidate distinguished from paused playback, track change or a stale Mac mirror; record recovery duration and recurrence. |
| 6. Finish | Stop test audio and session, save journals. At first useful failure collect one diagnostic capture and validate transfer/archive. | Known stopped audio, saved evidence, readable result, no repeating capture loop. |

An external camera can verify the physical screen if mirroring is suspect; it is
optional and arranged with the maintainer. No visual-only algorithm can establish
that the physical Watch was frozen from a possibly stale mirror alone.

## Minimal harness to prepare after the rehearsal

- Explicit Watch and phone IDs; bounded stages, maximum duration/cycle count,
  timestamped action records and a stop control. One input driver owns Device Hub.
- Record requested action, confirmed UI, file-transfer outcome and playback
  position independently. Native host callbacks do not prove pixels or volume.
- Use screenshots/short recordings at transitions rather than all-night video.
  Keep evidence private in a new incident folder with build/OS/source metadata.
- On lock screen, lost connection, unexpected route, ambiguous UI or screen-sharing
  interference: stop input and report. Do not restart/re-pair, store passcodes,
  force-close apps repeatedly or start multiple sysdiagnoses.
- Check disk space and output route before playback; finish with audio stopped.
  A phone-reported volume value is not a measurement of audible sound.

Appium's current watchOS support is Simulator-only; do not assume it controls a
physical Watch. Device Hub input and wake behavior must be established in the
rehearsal. The existing Simulator helper intentionally rejects physical-device
selection; do not remove that guard to reuse it here.

## Later comparisons and overnight gate

A separate diagnostic identity or minimal native-view probe may compare refresh
on/off without overwriting the teaching build. Capture original progress before
build 25's mitigation recreates the view; a normal-looking post-refresh frame
alone cannot show whether a freeze occurred.

Only after the supervised control/observation loop works should we arrange a
60–90 minute unattended run, capped cycles/data and stop-after-first-useful-failure.
Do not infer permission to schedule it from this preparation. A test on a charging
Watch also does not substitute for moving/wrist-down classroom validation.

Then reuse the harness for Home → return Crown recovery, tap refresh, no-playback
startup, real output changes, blank native view, track changes and Pause/Resume.
Do not combine those with the first progress experiment. Give Apple the smallest
verified reproduction, exact timeline, versions and diagnostics, with remaining
unknowns explicit.
