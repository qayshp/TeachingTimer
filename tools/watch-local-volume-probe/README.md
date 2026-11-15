# Watch-local native volume comparison

Simulator-only descendant of the October 24, 2026 isolated local-audio fixture.
It preserves the unique comparison between `WKInterfaceVolumeControl(origin:
.local)`, actual `AVAudioPlayer` playback, `AVAudioSession.outputVolume` KVO and
direct scalar reads. The separate [silent Watch audio probe](../watch-audio-probe/README.md)
has no standalone `.local` control or KVO; use it for finite native-progress tests.
Neither fixture establishes paired-phone volume behavior.

Build against the current selected Xcode's Watch Simulator SDK, with warnings as
errors. The output directory must be new. This command only builds and ad hoc signs:

```sh
sh tools/watch-local-volume-probe/build.sh work/watch-local-volume-probe-new
```

The distinct bundle is `net.qays.TeachingTimer.WatchLocalVolumeProbe`. It launches
paused; Play tone explicitly requests asynchronous longFormAudio activation.
Activation can fail or select a route, so verify its result and advancing player
time. The tone is audible 440-Hz PCM at the historical fixture's quiet sample
amplitude; sample amplitude does not guarantee acoustic loudness on a route.
There is no audio-session activation on an ordinary paused launch. The first
page hosts the native local-volume control and the public session scalar; the
second page is native `NowPlayingView`. It has no companion endpoint injection,
custom Crown arithmetic or volume setter.

Root/operator chooses a current Watch Simulator according to [repository policy](../../AGENTS.md).
Optional explicit autoplay and a per-Play bound are available:

```sh
xcrun simctl install WATCH_UUID work/watch-local-volume-probe-new/WatchLocalVolumeProbe.app
xcrun simctl launch WATCH_UUID net.qays.TeachingTimer.WatchLocalVolumeProbe \
  --autoplay --playback-limit-seconds 30
```

The limit defaults to 30 seconds and clamps to 1–120. A one-second timer stops
playback at the bound; process suspension can delay that timer. The WAV itself
ends after 120 seconds and never loops. Stop cancels pending activation before
play, stops the player and deactivates the session. Finish with Stop or terminate
the fixture; the build helper never launches, installs, boots or controls a device.

`Documents/LocalVolumeProbe.json` retains the latest 1,000 events for the current
process, written serially off the main queue. Unified subsystem
`net.qays.TeachingTimer.WatchLocalVolumeProbe` records the same events. Preserve
the journal before relaunch. It records native-control creation/requested focus,
scene/page, orientation/OS, activation, KVO values, periodic direct session reads,
actual player time/gain/play state and route. Native focus return is a request
observation, not proof that Crown input reached the control. Native internal
volume commands require a separate unified-log capture; public session scalar
and audible result must be assessed independently.

On October 24, watchOS 27.0 Simulator logged 33 native local-volume backend
updates from 0.005625 to 0.185625, reporting `available: NO` and capabilities
`None`. The public session scalar remained about 0.6000000238 in KVO and direct
reads while the actual player advanced. That is evidence of native scalar/UI
activity without a demonstrated session-volume change. It is not proof of real
output attenuation, successful companion control or the cause of the physical
November 13 zero. The original source, logs and `FINDINGS.md` remain private at
`work/support/2026-10-24-watch-local-volume/` in the canonical checkout.
Original `fixture/Probe.swift` SHA-256:
`85bccb760f063b1ee2c0c3aad510166e433f9b9809b3faebfc8952f6882aa027`.

The original fixture autoplayed a looping two-second tone and published
live-stream metadata. This maintained derivative keeps the local-volume/KVO
comparison and historical live-stream metadata, adds opt-in finite playback,
and bounds journal retention. It is intentionally unsuitable as a finite-progress
oracle. Its current source was compiled on November 15; that compilation is not
a new runtime reproduction of the October result or physical-device validation.
