# Public Crown event calibrator

A separate Watch Simulator app (`net.qays.TeachingTimer.CrownProbe`) for matching
known opposite Crown movements with a public SwiftUI binding and captured native
event logs. It has one stable focusable value panel, starts at 0.5, clamps to
0...1 without wrapping, uses medium sensitivity and disables Crown haptics.
It contains no native volume control, audio session, endpoint, playback, private
API or competing teaching-app Crown handler. Its numeric value is a test value.

```sh
sh tools/crown-event-probe/build.sh
xcrun simctl install SIMULATOR_UUID work/crown-event-probe/CrownEventProbe.app
xcrun simctl launch SIMULATOR_UUID net.qays.TeachingTimer.CrownProbe
```

Use an already booted disposable Watch Simulator. Resolve its identifier and
runtime live under the repository policy. The build only produces an ad-hoc
signed Simulator app; it does not boot/install/launch anything. Physical signing
and device calibration are separate work.

Starting from 0.5, send one small known input, wait for idle and save the value
change. Reset to 0.5 before the opposite input. Record each input's signed
amount and exact time. Match the app's `value_changed` old/new/delta and public
`crown_event` offset/velocity with the same interval's UIKit event-dispatch
records. Repeat once to check consistency. Tap the value panel or Reset to
request focus again if needed. Focus state is logged, not independently verified.

`reset_requested` explicitly marks programmatic reset. A following value change
from reset is not Crown input. Public event and binding callbacks are separately
sequenced; their callback order is not treated as a guaranteed one-to-one join.
At a range boundary, an event may occur without changing the clamped value;
calibrate near 0.5 instead.

`Documents/CrownProbe.json` keeps the latest 1,000 records from the current run,
with a run ID, sequence, wall-time seconds and monotonic uptime. Writes are serial
and off the main actor; allow them to finish and copy the journal before
terminating/relaunching the app. Logger uses subsystem
`net.qays.TeachingTimer.CrownProbe`, category `Crown`. Every observed binding
change includes old/new values and a signed delta; Crown callbacks also retain
the public offset and velocity. Appearance records include crown-orientation and
wrist-location raw values plus the watchOS version to scope each sign mapping.
Write failures are logged.

This establishes the sign of this public binding for the delivered Simulator
input. It does not establish native volume sensitivity, actual phone volume,
the interpretation of private UIKit subtype numbers on a physical Watch, or the
wearer's intended movement during an earlier incident. A native volume test
must run separately so this calibrator cannot take its Crown focus. No stale
native state or endpoint is injected by this fixture.
