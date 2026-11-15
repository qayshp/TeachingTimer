# Supervised physical media controls

This host-only helper prepares **one reviewed Device Hub action at a time** for
the [hypothesis-driven test suite](../../docs/PHYSICAL_MEDIA_TEST_PLAN.md).
It is separate from the Simulator driver and from TeachingTimer. It does not
install apps, obtain credentials, unlock devices, start a developer connection,
reset a class, or run an unattended playback loop.

Compilation and offline input guards are verified. **Physical touch/Crown
delivery remains unverified until the first supervised rehearsal.** In particular,
the Simulator scroll helper's success is not proof that physical Crown scrolling
will work. If the virtual Crown does not produce an observable native request,
stop that arm and request a known small physical Crown turn; do not mislabel a
host receipt as a volume result.

## Prepare without touching devices

```sh
sh tools/physical-media/build.sh work/physical-control-NEW
python3 tools/physical-media/self-test.py work/physical-control-NEW/HubControl
```

The build uses the selected Xcode's host SDK, warnings as errors, ad hoc signing
and signature verification. The self-test uses synthetic local receipt/request
files and never passes `--execute`; it performs no Accessibility queries. CI runs
these same checks. It does not select a real device or produce audio.

## First supervised rehearsal, after device availability and permission

1. Confirm the selected scenario, same installed build, class/runtime intent,
   source, quiet output, maximum duration and stop/recovery steps. Keep one input
   owner. User authentication stays outside the script.
2. Obtain fresh device details and app inventories using the notebook's prepared
   commands. They are not executed during preparation. Confirm
   `hardwareProperties.reality=physical`, platform, current device ID and exact
   Device Hub `TableRow.Device.<identifier-or-udid>` row. A details receipt is
   identity evidence, not proof of a functioning screen-sharing connection.
3. Start screen sharing through Device Hub and confirm actual current device
   content is visible, rather than a passcode or connection screen. Record any
   connection repair; do not silently combine it with a test transition.
4. Write a private request JSON for the current Hub PID, fresh details receipt,
   exact row and device kind. Begin with `action: "inspect"`:

   ```json
   {
     "hubPID": 123,
     "deviceDetailsFile": "/PRIVATE_RUN/watch-details.json",
     "rowIdentifier": "TableRow.Device.CURRENT_IDENTIFIER",
     "kind": "watch",
     "action": "inspect"
   }
   ```

   Replace all example values. `HubControl request.json` validates the local
   request/receipt and prints a plan with zero AX queries. Only
   `HubControl request.json --execute` selects/inspects the requested physical
   device. Save its private node paths, roles, identifiers and frames. Take a
   local screenshot, identify the actual display rectangle, and review it before
   sending input. Inspection does not automatically click View Screen or unlock.
5. A touch request adds `displayPath` (integer child indices from inspection),
   `displayRole` (`AXGroup` or `AXImage`), `displayIdentifier` (including an empty
   string if absent), and `coordinates` in normalized display coordinates.
   `tap` needs two numbers; `swipe` needs four. The target must already be selected;
   input actions never select a different device. Unsupported/changed paths,
   geometry, modal dialogs and nonforeground ownership fail rather than guess.
6. `home` presses an exposed native bezel Home/Crown button when available.
   `crown` is Watch-only, uses the exposed virtual Crown's actual AX bounds and a
   single `scrollUnits` request of -3...-1 or 1...3. Those are host scroll units,
   **not degrees, detents, or calibrated volume direction**. Establish actual
   direction and delivery against a known quiet level before using it as test
   input. Phone Play/Pause, track selection and class Start remain explicit,
   screenshot-reviewed taps; a launch acknowledgment is not a playback result.
7. Save before/after screenshots, actual phone/native volume behavior and
   notebook marks. A helper `inputSent:true` says only that the Mac submitted
   an event. If input, source, route or UI state is ambiguous, mark the arm
   inconclusive and stop; preserve evidence before trying recovery.

Apple describes [Device Hub interaction](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)
for physical and simulated devices, including bezel controls and mouse-wheel
Crown gestures. These docs do not establish that our synthetic events reach the
physical Watch. The helper requires a locally unlocked Mac, Accessibility access,
the exact Device Hub bundle/PID, one window, no modal, and a successful details
receipt modified within five minutes. Recapture details when stale. It never
accepts a Simulator receipt or creates a developer tunnel itself.

Use a local screen capture of the reviewed Device Hub display for evidence, and
label mirrored pixels separately from a video of the actual Watch/Crown/sound.
Do not run either device's Camera app as part of this media test; it changes the
test conditions and can interrupt Device Hub interaction. Keep all captures,
details and requests in ignored `work/`, never in the public repository.
