# Crown calibration and native baseline experiment — November 15

Investigation for [volume silencing #3](https://github.com/qayshp/TeachingTimer/issues/3),
following the [successful/failing comparison](VOLUME_COMPARISON_2026-11-14.md).
The Simulator calibrated a **public test-value binding**, not native volume.
Controlled backend changes also exposed native model/view/sequencer divergence,
but **no outgoing volume command or mute was reproduced**.

## Environment and input delivery

Xcode 27.2 (27B52), SE 3 40 mm Simulator on the newest installed compatible
watchOS runtime, 27.2 (24S118). The public probe reported crown orientation raw
value 1 and wrist location 0. The existing paired iPhone Simulator was later
booted on the compatible general iOS 27.2 runtime (24B8117); no audio was started.
The physical incident used watchOS 27.2.1. No physical device was contacted.

The Mac was initially locked. After the owner unlocked it, Device Hub touches
worked, but synthetic line/pixel mouse-wheel gestures did not produce Crown
callbacks. Apple's [Device Hub interaction guide](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)
describes wheel input over the Crown, or over the display with bezels hidden;
those automation attempts did not establish delivery here.

A private host-only helper subsequently delivered input through the Simulator's
dedicated Crown scroll service. Its protocol follows a pinned revision of
[Meta idb's Crown transport](https://github.com/meta/idb/blob/feb60fd884e2bf22f9a8cf59111e0468e9039338/FBSimulatorControl/HID/SimulatorCrownHIDTransport.swift).
It accepts an explicit booted Watch Simulator UUID and bounded signed guest
scroll units. It has no physical-device, boot, install or pairing operation.
Transmission receipts alone were not counted as delivery: app journals and
UIKit records supplied that evidence.

## Public binding calibration

The separate [Crown event probe](../tools/crown-event-probe/README.md) starts at
0.5, uses a public SwiftUI Crown binding in 0...1, and records old/new value,
signed change, public event offset/velocity, orientation and timestamps. No
audio or volume control shares its input ownership.

Each trial used a fresh launch and quiet capture window. Counts refer to
evaluated UIKit type-7/backing-6 dispatches, without deduplicating reused object
pointers. The helper profile sends actual motion in began, then zero in ended
for these one-sample turns. Phase association is temporal, within 50 ms of the
retained send markers; UIKit's message itself does not expose the phase.

| Input | Repeats | Binding result | Motion-associated subtype | Ended-zero subtype |
| --- | --- | --- | --- | --- |
| +1 guest unit | 2 | 0.5 → 0.596428571 | 200 | 200 |
| −1 guest unit | 2 | 0.5 → 0.403571429 | 201 | 200 |
| +0.25 guest unit | 1 | 0.5; no binding callback | 200 | 200 |
| −0.25 guest unit | 1 | 0.5; no binding callback | 200 | 200 |

The four responsive turns establish a repeatable input-to-binding relationship
for this runtime, orientation and transport. They do not establish degrees,
detents, a physical clockwise mapping, or native volume direction. Fractional
input resolution remains unresolved. A whole-window rule that interprets every
200 as positive movement would misclassify zero-motion boundaries.

### Why this appears opposite to the physical volume logs

The physical records associate subtype 200 with **decreasing native volume**,
and 201 with increasing native volume. The public probe associates those same
numbers with the opposite changes in its **generic binding**. These are different
controls and environments. Their opposite mappings are observed; their cause
has not been established. Do not transfer the binding's sign to the physical
volume control or call this a successful calibration of native volume.

The owner's recollection of trying to increase volume remains separately
recorded. This experiment neither decodes the earlier signed Crown movement
nor invalidates that recollection.

## Native input prerequisite

The unmodified native companion-volume probe receives UIKit scroll events but
has no usable companion endpoint or outgoing scalar writes. A separate private
Simulator-only library then replaced only the real `MPVolumeController` data
source with an explicitly artificial backend. The original data source was
retained, runtime method encodings checked, and the native description function
identified capability mask 2 as `Absolute`. The original native slider,
sequencer, action handling and Crown arithmetic remained in place.

This established a visible 0.625 ring, a controller getter of 0.625 and a native
sequencer offset of 0.625. It still produced no outgoing requests for the tested
turns. Attempts included retained focus/Refresh, a larger multi-sample turn, a
separate zero-began/changed-motion/zero-ended profile, the booted paired phone,
a single-page composition and a native-widget tap. A diagnostic read reported
first-responder status; a later exploratory debugger reactivation call trapped.
That process was replaced before subsequent tests.

No native Crown-arithmetic comparison is valid without a responsive reference.
The absence of setters is a test limitation, not an unexpected zero request.
The public binding result therefore remains uncalibrated against native volume.

## Controlled notification-state experiment

Eight commands then tested the same real view/controller in a fresh single-page
probe. All fields below were measured; the native slider and sequencer were not
directly assigned. Only the fake backend value, availability and notification
delivery were controlled. Setter feedback was disabled throughout these arms.

| Injected state/update | Controller getter | Native slider | Sequencer offset |
| --- | ---: | ---: | ---: |
| Notify available 0.25 | 0.25 | 0.25 | 0.25 |
| Change backend to 0.625 without notifying | 0.625 | 0.25 | 0.25 |
| Notify 0.625 | 0.625 | 0.625 | 0.625 |
| Notify available zero | 0 | 0 | 0 |
| Change backend to 0.625 without notifying | 0.625 | 0 | 0 |
| Notify 0.625 | 0.625 | 0.625 | 0.625 |
| Notify unavailable zero | 0 | 0 | 0 |
| Notify available 0.625 | 0.625 | 0.625 | 0.625 |

The controller getter delegates to the fake source; it is not an independently
cached baseline. Notifications were synchronous batches of the four known
capability, availability, volume and muted callbacks. The test does not identify
which individual callback repairs state or model real transport timing.

The complete saved 58-record journal has no hook exception, unsupported
completion, ABI rejection, command rejection or outgoing volume setter. The
eight result snapshots independently reconcile with that journal.

## Interpretation and next discriminator

- A correct getter can coexist with a stale native slider and sequencer when
  updates are deliberately withheld. This makes propagation worth investigating;
  it does not show callbacks were lost in the physical incident.
- Normal notification batches synchronized all three values, including recovery
  from unavailable zero. That sequence alone did not leave a stale baseline.
- A stale zero plus an ordinary positive increment does not automatically imply
  an exact zero request. The actual native input/conversion remains necessary
  evidence; a fake rule that forces zero would assume the conclusion.
- Native volume's signed response remains uncalibrated in this Simulator setup.
  The next decisive check is known small movements against a known physical
  native-volume baseline, with ring video and matched phone/Watch records.
  Keep provider/output fixed before varying retained state or playback order.

The injected process was terminated and the ordinary native probe artifact
restored. The public calibrator and existing simulators remain available.
Private libraries, host helpers and raw records stay in ignored `work/`;
TeachingTimer's production behavior, physical installation and Apple feedback
were unchanged. CI now compiles the public calibrator and tests its change
routing; it does not run this interactive calibration or private fault injection.
