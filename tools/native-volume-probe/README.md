# Native companion-volume probe

A separate Watch Simulator diagnostic app (`net.qays.TeachingTimer.VolumeProbe`)
with only a native companion-iPhone volume control, Refresh, and native Now
Playing on a second page. No runtime, class state, landmark scheduler, playback,
custom Crown handler, private API, or volume setter. It cannot read the native
control's actual volume, destination route, availability, or focus ownership.

```sh
sh tools/native-volume-probe/build.sh
xcrun simctl install SIMULATOR_UUID work/native-volume-probe/NativeVolumeProbe.app
xcrun simctl launch SIMULATOR_UUID net.qays.TeachingTimer.VolumeProbe --staged
```

Requires Xcode and an already booted Watch Simulator. The script only builds an
ad-hoc signed Simulator app; no simulator boot, physical install, account access,
or production signing. For a future physical experiment, create a separate
watchOS-only target with this source and identifier, use the paid development
team, and validate it before installation. This fixture is not a distributable
physical build yet.

Default: retain the native control, resign then refocus after 0.25 seconds on
refresh. Media-to-timer return requests focus without that delay. Options:

- `--replace`: refresh replaces the native control instance.
- `--staged`: wait one second before startup/background-return setup.
- `--immediate`: remove the refresh delay for comparison.

Restart only this probe to change options:

```sh
xcrun simctl launch --terminate-running-process SIMULATOR_UUID \
  net.qays.TeachingTimer.VolumeProbe --replace --staged
```

Compare cold launch, Home/reopen, Refresh and media/timer return with otherwise
identical conditions. With a compatible physical phone source, record audible
output, route, phone volume, and page alongside the probe journal; lifecycle
callbacks alone cannot diagnose mute or successful focus. Simulator companion
playback remains an unresolved platform/testing limitation.

`Documents/VolumeProbe.json` retains the latest 1,000 events for the current
process. It is a disposable experiment, not the production seven-day journal.
Writes run serially off the main queue. Events include control identity, page,
scene, refresh request, requested delay, focus call/return and superseded work.
Actual focus and phone volume are explicitly unobserved. Copy private journals
from the app data container before terminating/relaunching the probe.

## October 26, 2026 smoke test

Built and ran on watchOS 27.0 SE 3 40 mm. Both retained and replacement refresh
paths rendered; the retained path kept its identifier, the replacement path
created a new identifier and suppressed the old pending focus request after
dismantling. This verifies lifecycle isolation, not real audio behavior. No
physical Watch installation or companion-media success is claimed.
