# Watch media laboratory

Reusable host and Watch **Simulator-only** experiments for native volume state
and Crown event calibration. These tools use private Simulator/framework
interfaces in isolated fixtures. They must not be added to TeachingTimer or a
physical app target. No tool here uses a physical-device API or plays audio.

The historical findings and limits are in
[Crown calibration](../../docs/CROWN_CALIBRATION_2026-11-15.md). Original raw
records remain private. Source ancestry and exact upstream revision are in
[PINNED_UPSTREAM.md](PINNED_UPSTREAM.md); Meta's MIT notice is retained in
[LICENSE-idb.txt](LICENSE-idb.txt).

## Build without a Simulator

From the repository root:

```sh
sh tools/watch-media-lab/build.sh
python3 -m unittest discover -s Tests -p test_watch_media_lab.py -v
```

The build uses the selected Xcode's current host and watchOS Simulator SDKs,
warnings as errors, and ad hoc signing/verification. It creates
`work/watch-media-lab/CrownHIDBridge`, `NativeBaselineHook.dylib`, an ordinary
`native-volume-probe/NativeVolumeProbe.app`, a public
`crown-event-probe/CrownEventProbe.app`, two local wire self-test receipts,
and `build.json` with source hashes and SDKs. The build never lists, boots,
installs or launches a Simulator. Host self-tests construct XPC dictionaries
without loading CoreSimulator or opening a connection.

The compile guard passes a second optional argument pointing to a fixture root
containing freshly built `native-volume-probe/` and `crown-event-probe/` outputs
from the same checkout. The lab verifies and copies these ordinary app bundles
into its new output instead of compiling them twice; host/hook builds and both
wire self-tests still run. `build.json` records the reused root. For example:

```sh
sh scripts/check-simulator-tools.sh work/simulator-tools-new
```

Before a runtime experiment, resolve the selected Xcode and live available
watchOS runtimes/devices. Use the newest installed compatible runtime unless a
historical comparison is explicitly intended. Choose an explicit already
booted Watch UUID; these tools never boot or create one and never accept
`booted` as an alias. No UUID is stored in source.

## Eight measured native-state arms

The hook replaces only the native volume controller's data source with a fake
backend inside `net.qays.TeachingTimer.VolumeProbe`. It retains the original
source and leaves the real slider, Crown sequencer and action code in place.
Compile-time `TARGET_OS_SIMULATOR` and the exact fixture identity gate the hook.
The capability description function must identify an `Absolute` mask; unknown
ABI, missing scalars or required unsupported completion paths fail the run.

The runner validates the `.app` identity/executable and Mach-O platform9
(watchOS Simulator) for both app and library. `TeachingTimer` is refused. It
uses the ordinary probe's `--staged --single-page` composition and one measured
native view/controller throughout. Its default invocation writes an offline
plan only; it makes no Simulator calls:

```sh
python3 tools/watch-media-lab/native-state.py \
  --simulator "$WATCH_SIMULATOR_UUID" \
  --probe work/watch-media-lab/native-volume-probe/NativeVolumeProbe.app \
  --hook work/watch-media-lab/NativeBaselineHook.dylib \
  --output work/native-state-plan
```

Use a **different new** output directory and add `--execute` to run it:

```sh
python3 tools/watch-media-lab/native-state.py \
  --simulator "$WATCH_SIMULATOR_UUID" \
  --probe work/watch-media-lab/native-volume-probe/NativeVolumeProbe.app \
  --hook work/watch-media-lab/NativeBaselineHook.dylib \
  --output work/native-state-run --execute
```

Execution first verifies live available/Booted/Apple-Watch inventory. It then
stops only the existing fixture, installs the supplied ordinary fixture, saves
prior fixture commands/journals, and launches that fixture with process-scoped
library injection. Each command is written atomically with an increasing
revision. Setter feedback is disabled in all eight arms.

| Arm | Backend / notification | Expected controller getter | Expected native slider | Expected sequencer offset |
| --- | --- | ---: | ---: | ---: |
| Seed interior | Available 0.25, notify | 0.25 | 0.25 | 0.25 |
| Silent model interior | Backend 0.625, withhold notify | 0.625 | 0.25 | 0.25 |
| Repair interior | Notify 0.625 | 0.625 | 0.625 | 0.625 |
| Seed enabled zero | Available zero, notify | 0 | 0 | 0 |
| Silent model zero | Backend 0.625, withhold notify | 0.625 | 0 | 0 |
| Repair zero | Notify 0.625 | 0.625 | 0.625 | 0.625 |
| Unavailable zero | Unavailable zero, notify | 0 | 0 | 0 |
| Ready after unavailable | Available 0.625, notify | 0.625 | 0.625 | 0.625 |

The controller getter delegates to the fake source: it is **not an independently
cached baseline**. Slider and sequencer values are read, never assigned by this
hook. Notifications are a synchronous batch of capability, availability, volume
and muted callbacks. The test does not identify which callback matters or model
real endpoint timing.

`run.json` records every simctl command, measured result and cleanup outcome.
The runner rejects missing/multiple native views, changed view/controller
identity, incorrect tuples, outgoing setters, exceptions, ABI rejections,
unsupported completions and rejected commands. Polls and subprocesses have
timeouts. A failure is preserved as unsupported/failed, not converted into a
passing zero result.

The `finally` path attempts to terminate the injected fixture, saves/audits the
final journals, and only then reinstalls the ordinary supplied artifact, even
after failure. Reinstallation can relocate the old data container, so final
evidence is read before that step. A separate observed journal snapshot is also
saved after each measured arm. It does not launch a final process. Inspect
cleanup acknowledgements; an unavailable
Simulator can leave cleanup unconfirmed, which exits unsuccessfully. No
automatic service repair, retries, boot, pairing or reset is performed.

The hook understands `Documents/NativeBaselineCommand.json` with `revision`,
`label`, `volume` (finite 0...1), `available`, `notify`, `feedback`, and `muted`.
With `notify:false`, only the fake backend changes. With `feedback:true`, exact
native outgoing scalars are logged and fed back without clamping; the eight-arm
runner always uses false. `getVolumeValueWithCompletion:` records unsupported
instead of invoking an unverified block ABI. Raw capability override exists for
historical diagnosis, is labelled in the hook journal, and is not used by the
runner.

## Crown input profiles and calibration

Build the separate public [Crown event probe](../crown-event-probe/README.md) and
install/launch only that fixture on the selected Simulator. Its initial generic
binding is 0.5 and contains no native volume control or audio source. The host
bridge validates an explicit booted default-set Watch before its sole scroll
service lookup:

```sh
work/watch-media-lab/CrownHIDBridge --dry-run "$WATCH_SIMULATOR_UUID" 1
work/watch-media-lab/CrownHIDBridge --send "$WATCH_SIMULATOR_UUID" 1
work/watch-media-lab/CrownHIDBridge --profile zero-began --send "$WATCH_SIMULATOR_UUID" 1
```

Delta is finite/nonzero, bounded to +/-100 **guest scroll units**, not degrees or
detents. Samples have magnitude at most five. The default `upstream` profile
carries the first actual delta on began, later deltas on changed, then ended0.
The explicit `zero-began` experiment sends began0, waits 50ms, then puts every
actual sample on changed before ended0. It changes both phase shape and timing.
The same profile must be recorded in comparison evidence.

The bridge uses the dedicated DTUHID scroll service, typed uint64 phase/target
fields and double axis values. It verifies a liveness reply before motion and
retains the connection for a one-second final drain. A send receipt is not
proof of app receipt. Intentional connection cancellation can produce
`XPC peer error: Connection invalid` adjacent to `gesture_finished`; merged
stdout/stderr order does not make that a delivery failure when the command
returned successfully with ended and completion markers.

The reproducible calibration protocol uses fresh launches and quiet windows
for `+1, -1, -1, +1, +0.25, -0.25`, followed by the reverse-order block. Capture
the exact launched PID, run ID, before-input/after-input/settled times, bridge
profile and before/after `CrownProbe.json`.

`calibrate.py` automates that isolated fixture workflow. With no `--execute`, it
only validates local artifacts and writes a new private plan. With `--execute`,
it validates live booted Watch inventory, installs only CrownProbe, starts its
own bounded 120s log capture, and performs the twelve fresh launches and turns.
It leaves quiet settling windows, saves all journals/run IDs/PIDs/timing/profile
receipts and analyzes its own captured file. It does not use Device Hub input:

```sh
python3 tools/watch-media-lab/calibrate.py \
  --simulator "$WATCH_SIMULATOR_UUID" \
  --probe work/watch-media-lab/crown-event-probe/CrownEventProbe.app \
  --bridge work/watch-media-lab/CrownHIDBridge \
  --profile upstream --output work/crown-calibration-plan

python3 tools/watch-media-lab/calibrate.py \
  --simulator "$WATCH_SIMULATOR_UUID" \
  --probe work/watch-media-lab/crown-event-probe/CrownEventProbe.app \
  --bridge work/watch-media-lab/CrownHIDBridge \
  --profile upstream --output work/crown-calibration-run --execute
```

Use another new output and `--profile zero-began` for that separate experiment.
The oracle requires responsive +/-1 references with repeatable opposite binding
signs, a fresh 0.5 start and distinct run ID for each trial, and stable
orientation/profile. It does not require exact displacement because pacing and
velocity affect interpolation. Fractional +/-0.25 nonresponse is retained as an
observation, not failed input. Missing UIKit correlation is a failure; a host
receipt alone cannot pass the calibration. The final path stops the fixture and
host capture; the guest log command is independently bounded to 120s. Inspect
cleanup acknowledgements and failures in run.json.

For manual replay or an independently recorded trial set, use a bounded stream
instead of starting a second capture alongside `calibrate.py`:

```sh
xcrun simctl spawn "$WATCH_SIMULATOR_UUID" log stream --timeout 90 \
  --level debug --style ndjson \
  --predicate 'process == "CrownEventProbe" OR process == "NativeVolumeProbe"' \
  > "$PRIVATE_RUN/live-apps.ndjson"
```

Run capture and input from separate terminals under one input owner. Each trial
must finish before its opposite begins. The offline analyzer accepts a private
directory containing `calibration-trials.json`, numbered before/after journals
and `live-apps.ndjson`:

```sh
python3 tools/watch-media-lab/analyze-calibration.py --root "$PRIVATE_RUN" \
  --expected-trials 12 --wait-seconds 0
```

It correlates exact launched PID plus before-input-to-settled window, counts
only evaluated type7/backing6 rows, and never deduplicates reused event pointers
or log-format trace IDs. Phase association uses the nearest retained send marker
within 50ms, including `began_sent` for the optional profile; UIKit's message
does not itself expose phase. Preserve all rows, including ended-zero events.

## Known negative results and evidence boundaries

The November 15 original six-trial public binding experiment observed +1
increase with sample subtype200 and -1 decrease with sample subtype201. All
ended-zero events were subtype200. Both +/-0.25 turns produced no public value
callbacks and no net change; small-input resolution remains unresolved. Do not
classify those fractional nonresponses as a signed-motion failure or read every
200 as positive motion.

The physical native volume records associated 200 with decreasing scalars and
201 with increasing scalars. That opposite control/environment mapping remains
unexplained; the generic binding result does not decode physical Crown intent.

The original native fixture received UIKit events but produced no outgoing
scalar writes, even after the fake ready 0.625 source, multi-sample input,
zero-began profile, paired Simulator phone, Refresh and single-page composition.
No native Crown arithmetic, silencing or paired audio application was
reproduced. A responsive native reference is required before interpreting a
stale-state/Crown comparison. The eight notification arms establish artificial
propagation/repair behavior only, not a reproduction of the physical incident.

Build success, offline tests, host send receipts, UIKit dispatch, public binding
changes, native getter/view/sequencer state, outgoing setters and actual phone
audio are distinct evidence. Keep each claim at the boundary actually measured.
