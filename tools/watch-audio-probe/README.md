# Silent Watch audio probe

Measured results and limitations: [November 15 Watch-local media experiment](../../docs/WATCH_LOCAL_MEDIA_2026-11-15.md).

Standalone watchOS Simulator fixture, separate from TeachingTimer and the phone audio probe. Its distinct bundle is `net.qays.TeachingTimer.WatchAudioProbe`. It plays a local, non-looping 180-second WAV containing only zero-valued signed 16-bit PCM samples. There is no tone, downloaded content, account, server, companion dependency, custom volume control, or custom Now Playing progress display.

The first page provides Play, Pause, Stop and +30-second Seek. The second page is Apple's native `NowPlayingView`. Launch with `--now-playing` to select it initially. The fixture stays paused until Play or `--autoplay`; Play still uses actual audio-session activation and `AVAudioPlayer.play()`. Category is playback with longFormAudio policy and asynchronous Watch activation. Activation can fail or present a route picker; only an activation result followed by player-time advancement establishes playback in that run.

Build against the current selected Xcode's Watch Simulator SDK, with warnings as errors and an ad hoc signature. The output directory must be new. This helper does not boot, select, install, or launch any device:

```sh
sh tools/watch-audio-probe/build.sh work/watch-audio-probe-new
```

Root/operator resolves a suitable current Watch Simulator UUID per [repository policy](../../AGENTS.md). Example operator commands, not actions performed by the build:

```sh
xcrun simctl install WATCH_UUID work/watch-audio-probe-new/WatchAudioProbe.app
xcrun simctl launch WATCH_UUID net.qays.TeachingTimer.WatchAudioProbe \
  --autoplay --now-playing --playback-limit-seconds 90
```

Playback always contains silent samples. A per-Play monotonic limit defaults to 180 seconds and clamps `--playback-limit-seconds` to 1–180. The file itself ends at 180 seconds and does not loop. The timer limit is not an external watchdog and can be delayed by process suspension. Pause leaves the session configured for easy resume; Stop resets position and deactivates it. Finish with Stop or terminate the fixture after evidence collection:

```sh
xcrun simctl terminate WATCH_UUID net.qays.TeachingTimer.WatchAudioProbe
```

Default metadata publication occurs only on Play, Pause, Stop, Seek, interruption/decode-error pause, and natural finish. It publishes finite duration, current elapsed time and rate (1 playing, 0 paused); this is not a live stream. A paused launch publishes nothing unless `--seek-seconds N` requests an initial seek. A one-second heartbeat reads player state but **does not publish metadata**. In the default arm, native progress must extrapolate between playback transitions rather than being refreshed by a new elapsed value every second.

`--session-api` selects an exclusive public `NowPlaying.MediaSession` publisher on watchOS 27 or later. It uses the same actual silent player and transition-only timing, but submits a `MediaPlaybackSnapshot` with actual playing/paused/stopped state, elapsed time and timestamp. Content has finite duration. After playback starts it requests application-primary status and journals the result/error. Session commands call the same actual Play/Pause/Stop/Seek operations. This mode never registers with `MPRemoteCommandCenter` or writes to `MPNowPlayingInfoCenter`; use a fresh process when switching publisher APIs. Below watchOS 27, this option records an unavailable error. The new framework is weak-linked; the fixture's minimum version remains 26, and no TeachingTimer target changes.

```sh
xcrun simctl launch WATCH_UUID net.qays.TeachingTimer.WatchAudioProbe \
  --autoplay --now-playing --session-api --playback-limit-seconds 90
```

In session mode, `session_snapshot_submitted` records each app submission and `metadataPublishCount` counts these submissions. It does not count internal framework messages or native UI updates. `session_activation_result` records `isApplicationPrimary`, `canBecomeApplicationPrimary` and errors. Application-primary status is not proof that the system's Now Playing view selected this source. The Watch SDK does not expose the new framework's system-primary request on watchOS. Default uninterrupted playback should still have exactly one submitted snapshot while actual player time advances. `--frequent-metadata` remains a separate comparison flag in either publisher mode.

For a separate comparison arm, terminate and relaunch with `--frequent-metadata`; only that flag republishes elapsed time every second while playing. Do not use that arm as evidence that sparse native progress works. Optional `--seek-seconds N` seeks initially, clamped to 0–180; UI +30s and native remote seeking also publish transitions. Native Play/Pause/Stop/Toggle/Seek commands are registered and their returned actions are journaled. A remote handler returning success only acknowledges dispatch; verify the subsequent player state separately.

`Documents/WatchAudioProbe.jsonl` and unified subsystem `net.qays.TeachingTimer.WatchAudioProbe` record:

- Per-process UUID `runID`, `pid`, increasing `eventSequence`, wall timestamp/Unix seconds and monotonic uptime. Journals append across launches; select a single runID for each comparison arm.
- Actual `playerCurrentTime`, `isPlaying` as `playing`, duration, and audio-device clock `playerDeviceCurrentTime`.
- Monotonic uptime, last play/seek/pause anchor, and a separate `monotonicExpectedPosition` for comparison. This expected value is an estimate, not player position or native progress.
- Every metadata publication, reason and count, plus the last published position/rate/uptime. With default uninterrupted playback, the count should stay constant as actual player time advances.
- Activation results/errors, route port types, session scalar, remote commands, scene/page changes, interruptions, route changes, and media-service notifications.

The audio-device clock continues independently of track position; advancement of that clock alone does not prove playback. Look for multiple advancing `playerCurrentTime` samples with `playing:true`. The journal does not measure native view progress; capture the native UI separately at two times. A frozen native UI with advancing actual player time and unchanged metadata count is a useful local observation. It does not establish companion-media support, correct physical volume, or the cause of the Nov 13 physical incident. Route/session volume is a Simulator observation, not an acoustic measurement. Media-service loss/reset is recorded, not automatically repaired; restart the fixture for a clean comparison if it occurs.

The older private October 24 Watch fixture used a looping tone and live-stream metadata without finite duration or elapsed time. It established local player advancement but stopped at an unsupported volume-path gate; it was not a finite-progress test. This fixture specifically separates player progress, metadata publication, and native progress.

For timed comparisons, `observe.py` targets an already installed source and a
booted disposable Watch named `TeachingTimer Regression…`. It creates a new
private `work/` directory and writes a plan without any device calls unless
`--execute` is explicit. `--host fixture|teaching|system` selects the native host;
the TeachingTimer host must already be installed under the development identity.
It captures frames with actual current-run player samples and submission counts,
then terminates the synthetic source even after an ambiguous launch timeout.
The host and Simulators remain open. Run one observer/input owner at a time.

```sh
python3 tools/watch-audio-probe/observe.py --simulator "$WATCH_SIMULATOR_UUID" \
  --host teaching --seconds 20 --interval 5 --output work/watch-progress-NEW
python3 -m unittest discover -s Tests -p test_watch_audio_observe.py -v
```

Add `--execute` only after reviewing the plan and live target. A passing
`playerGatePassed` establishes actual player advancement with the required
metadata policy, not visible native progress. `nativeProgressResult` deliberately
remains `unverified_visual_review_required`; inspect the frames before reporting
native behavior. Fresh comparison output is required; earlier evidence is not
overwritten. The tests exercise failure cases without contacting a Simulator.

The checked Watch SDK's `MPNowPlayingInfoCenter.h` documents automatic extrapolation from elapsed time and playback rate, and says frequent elapsed updates are unnecessary. Public APIs compile here; availability and compilation do not establish that a given Simulator exposes the app in native Now Playing. No physical build/signing path is provided.

Apple's [local-session documentation](https://developer.apple.com/documentation/nowplaying/publishing-media-sessions) describes `MediaSession` as a publisher and specifies elapsed time plus timestamp for extrapolation. Its [framework overview](https://developer.apple.com/documentation/nowplaying) explicitly forbids mixing this local publisher with the legacy Media Player publishing/command APIs. These are distinct fresh-process experiment arms.

The current Watch SDK accepts reading/writing legacy `MPNowPlayingInfoCenter.playbackState`, but both its header and [Apple's property documentation](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter/playbackstate) say the property applies only to macOS. This fixture does not use that setter as a Watch fix. `MPNowPlayingSession` and its automatic `AVPlayer` publishing facility are explicitly unavailable on watchOS. Plain `AVPlayer` is available, but that does not establish an automatic Watch metadata publisher. No inspected public contract says all-zero PCM must be excluded from Now Playing; silence-based classification remains an unverified hypothesis, and this fixture preserves its silent content.
