# Supervised physical media controls

This host-only helper prepares **one reviewed Device Hub action at a time** for
the [hypothesis-driven test suite](../../docs/PHYSICAL_MEDIA_TEST_PLAN.md).
It is separate from the Simulator driver and from TeachingTimer. It does not
install apps, obtain credentials, unlock devices, start a developer connection,
reset a class, or run an unattended playback loop.

Compilation and offline input guards are verified. **Watch touch/Crown delivery
still requires a working shared view and supervised rehearsal.** In particular,
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
2. Obtain fresh device identity receipts and app inventories using the notebook's
   prepared commands. They are not executed during preparation. A successful
   `devicectl device info details` receipt or `devicectl list devices` inventory
   is accepted: the latter can establish identity when developer-image/details
   services are unavailable but an existing shared screen still works. Confirm
   `hardwareProperties.reality=physical`, platform, current device ID and exact
   Device Hub `TableRow.Device.<identifier-or-udid>` row. Inventory must identify
   exactly one requested device. Device Hub may repeat the identifier on its
   icon/text siblings; the helper resolves their one nearest owning `AXRow`.
   Matches in two different rows remain ambiguous and fail. Either receipt is
   identity evidence, not proof of a developer tunnel or live shared screen.
3. Start screen sharing through Device Hub and confirm actual current device
   content is visible, rather than a passcode or connection screen. Record any
   connection repair; do not silently combine it with a test transition.
4. Write a private request JSON for the current Hub PID, fresh identity receipt,
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
   request/receipt and prints a plan with zero AX queries. The historical field
   name `deviceDetailsFile` also accepts the successful inventory JSON. Only
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
   When Device Hub exposes a larger canvas rather than the display itself,
   add a screenshot-reviewed `displayCrop: [x, y, width, height]`, normalized to
   that anchor, `reviewedAnchorFrame: [screenX, screenY, width, height]`, and
   `reviewedAtUnix` in Unix seconds. Fractions must fit inside the anchor. Each
   action checks that its current AX anchor differs by **less than 0.5 points**
   on every component and that review age is **0–180 seconds**. Moving/resizing
   the canvas or an old/future review fails. Cropped display geometry must still
   fit the Device Hub window and the requested Watch/phone proportions.
6. `home` presses an exposed native bezel Home/Crown button when available.
   `crown` is Watch-only, uses the exposed virtual Crown's actual AX bounds and a
   single `scrollUnits` request of -3...-1 or 1...3. Those are host scroll units,
   **not degrees, detents, or calibrated volume direction**. Establish actual
   direction and delivery against a known quiet level before using it as test
   input. For a cropped canvas, an optional `crownPoint: [x, y]` specifies the
   screenshot-reviewed Crown position normalized to the same anchor; it is
   Watch/Crown-only and must remain in the window outside the display crop.
   It does not establish Crown ownership or delivery. Phone Play/Pause, track
   selection and class Start remain explicit,
   screenshot-reviewed taps; a launch acknowledgment is not a playback result.
7. Save before/after screenshots, actual phone/native volume behavior and
   notebook marks. A helper `inputSent:true` says only that the Mac submitted
   an event. If input, source, route or UI state is ambiguous, mark the arm
   inconclusive and stop; preserve evidence before trying recovery. **A grey or
   reconnecting screen invalidates the review even if its frame/time checks
   still pass.** The helper cannot infer live device pixels from geometry;
   inspect a fresh screenshot/content before the next input.

Apple describes [Device Hub interaction](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)
for physical and simulated devices, including bezel controls and mouse-wheel
Crown gestures. These docs do not establish that our synthetic events reach the
physical Watch. The helper requires a locally unlocked Mac, Accessibility access,
the exact Device Hub bundle/PID, one window, no modal, and a successful physical
identity receipt modified within five minutes. Recapture identity when stale. It never
accepts a Simulator receipt or creates a developer tunnel itself.

Use a local screen capture of the reviewed Device Hub display for evidence, and
label mirrored pixels separately from a video of the actual Watch/Crown/sound.
Do not run either device's Camera app as part of this media test; it changes the
test conditions and can interrupt Device Hub interaction. Keep all captures,
details and requests in ignored `work/`, never in the public repository.

## Capture-related playback interference

During the November 15 supervised attempt, the user reported that Apple Music
was inaudible while phone Device Hub screen sharing was active; music-video
content was black. After stopping phone sharing, playback became audible. A
Play/Pause state, moving elapsed time or nonzero slider had not established
audible output. Preserve earlier no-response observations as **confounded**
until audible source playback is independently confirmed; they do not prove a
Watch volume command silenced the output.

For the volume reference, stop phone screen sharing and verify the stop, leave
the Watch timer/control context intact where possible, and obtain operator
confirmation of quiet sound on the intended output **before Crown input**.
Record sharing on/off and audibility as separate observations. Use direct phone
observations for source/level changes, or physical video from an existing
Mac/external camera; do not replace sharing with unvalidated phone screen
recording/mirroring, which may change the same condition. No audible source means
a setup failure/inconclusive arm, not a native volume failure.

Apple's [capture documentation](https://developer.apple.com/documentation/uikit/uiscreen/iscaptured)
describes protected FairPlay video being omitted from screen capture, while audio
is not automatically excluded by that mechanism; a media app can respond to
capture state itself. This makes protected content/app policy plausible, but
black video does **not** confirm why audio was silent. No inspected official
Device Hub guidance identifies this exact Apple Music symptom or establishes
DRM as its cause. Apple's separate
[iPhone Mirroring guidance](https://support.apple.com/120421) describes audio routing
and premium-video restrictions for that product; do not transfer those behaviors
to Device Hub without evidence.

## Initial November 15 physical rehearsal

The first bounded attempt established phone-side Device Hub touch/navigation:
Apple Music's planned **Thursday Afternoon** page was loaded **paused**, and
iPhone-speaker output was confirmed. No playback or Watch Crown request was
submitted during that attempt. Selecting the Watch encountered reconnecting/grey
shared content while a developer-details query timed out. A Stop Sharing action
was acknowledged, but that acknowledgment did not establish a new live view.
This is a connection/input-readiness result, not a volume-baseline test. Later
attempts must record current content/delivery independently of this checkpoint.

Offline regression checks cover sibling-row coalescing, ambiguous/missing rows,
details/inventory identity and platform rejection, valid/invalid crop requests,
and the exact pure geometry function used by execution. Synthetic frames test
0.49 versus 0.5-point movement, 179/180 versus 181-second review age, future
reviews, window containment, minimum size and platform aspect ratios. None of
these checks performs AX queries or proves physical input/media behavior.

## Read-only captures with detached device windows

`HubControl` deliberately rejects multiple Device Hub windows for input. Do not
remove that guard merely to capture an already visible phone/Watch side by side.
The separate `WindowList` helper lists **host window metadata only** for an
explicit current Device Hub PID, after verifying its bundle identifier. It does
not query AX, select/activate a window, move anything, post input or contact a
device. `WindowList --self-test` uses synthetic metadata only; the build/CI checks
also reject malformed PID arguments without querying a live process/window.

After current device/window availability is confirmed, an operator can run:

```sh
work/physical-control-NEW/WindowList CURRENT_DEVICE_HUB_PID \
  > work/PRIVATE-RUN/current-hub-windows.json
```

Review the returned `windows` entries' current `kCGWindowNumber`, title, bounds,
layer and on-screen status. Titles may be missing/redacted by macOS. Match the
intended detached device window against its current AX window title/frame and
visible content; a matching PID alone identifies the app, not the particular
Watch or phone. Do not guess from list order. AX matching, if used, is a separate
read-only inspection; this helper itself performs none.

Once an exact current window ID is reviewed, capture it without activating or
moving it:

```sh
screencapture -l CURRENT_REVIEWED_WINDOW_ID work/PRIVATE-RUN/window.png
```

The capture is a separate host operation and may require Screen Recording
permission. Review its pixels before relying on it. Window shadows/frame margins
may be included, so image pixel bounds can differ from the AX content rectangle;
do not recycle old screenshot crop coordinates for input. Grey/old content is
still not a live device result. Window IDs, PIDs, titles and geometry are
ephemeral: re-list/review after closing, reopening, moving or changing windows,
and never store real IDs or captures in the public repository. Successful
capture does not establish that a later input reached the device.

## Notebook clock interpretation

The notebook now records `hostClockMetadata` with clock source, scope, process ID
and Python version for every new stamp. It explicitly uses native
`clock_gettime_ns(CLOCK_MONOTONIC)` when available; values can be compared across
CLI processes only with the same source, host and boot. If the native API is
missing or unavailable, `time.monotonic_ns()` is labelled **same-process only**.
Wall UTC/Pacific timestamps remain separate operator-mark times, not exact
device-event times or proof that an action happened.

The November 15 rehearsal exposed the older Xcode Python **3.9.6** behavior on
this Mac: its `time.monotonic_ns()` starts near zero in each CLI process. Thus
legacy notebook values without clock metadata cannot be subtracted across CLI
marks, despite the earlier boot-scoped description. Their original bytes are
preserved; use wall timestamps for those marks and do not silently reinterpret
them using the new native clock. This affects host notebook correlation, not
TeachingTimer's Watch clock/count scheduling. Python documents the macOS
cross-process clock change in [version 3.10](https://docs.python.org/3/library/time.html#time.monotonic).
Offline tests launch two real Python subprocesses and check their stamps against
the parent native clock, as well as explicit fallback and legacy-preservation
cases. No device is contacted by that check.
