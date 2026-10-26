# Device Hub testing boundaries — October 26, 2026

Research and Simulator inspection used Xcode 27.1 (27A9275). No physical phone or
Watch was contacted or controlled for this pass.

## Haptics without sound

TeachingTimer requests `.start` for acknowledgement and `.directionUp` for
landmark pulses through `WKInterfaceDevice.play`. The public watchOS SDK exposes
a haptic type argument, with no per-request sound, volume, or silent flag.
Apple describes built-in Watch haptics as patterns combined with audible tones:
[Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics).

There is no verified public-API way in this investigation to retain the current
strong pattern while independently suppressing its sound. The quieter `.click`
is a possible comparison for a later physical trial, but it was previously too
faint during teaching. Its physical silence and suitability are not established
by these Simulator checks. No haptic type was changed, and no audio session,
volume manipulation, private API, or Watch Silent Mode change was introduced.

Simulator sound is a separate host setting. Device Hub's Settings inspector and
Device → Sound menu offer output routing. Apple documents the routing controls
in [Simulator environment settings](https://developer.apple.com/documentation/xcode/configuring-the-environment-of-a-simulated-device).
This installation offers **None**, but attempts to select it left the output at
**System**. Apple's [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
list failure to select None for sound input/output as known issue **175714711**.
This matches the observed limitation; no silent-output success is claimed.
The output remains System. Routing Simulator audio to headphones is a host-side
alternative, but does not change what a real Watch plays.

The build 14 locked-count test verifies haptic *submissions*. It cannot establish
that the physical Watch delivers every request while inactive. Apple's
[play documentation](https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:))
describes application-state restrictions, so removing our lateness cutoff cannot
override watchOS delivery decisions. See [the late-pulse experiment](HAPTIC_DELAYS.md).

## Physical-device input from the Mac

**Device Hub supports interactive physical-device control, not only screenshots.**
Apple's [Device Hub interaction guide](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)
instructs selecting the physical device and choosing **View Screen**. The WWDC26
session [Get the most out of Device Hub](https://developer.apple.com/videos/play/wwdc2026/260/)
demonstrates controlling a connected physical Apple Watch from the canvas.

The Xcode 27 release notes also explicitly describe Crown input for simulated
and physical Watches: scroll over the **Crown in the bezel**, because scrolling
over the face does not emulate Crown rotation (179079031 / FB22992052).

This supports a later Mac-driven media investigation once the user's devices
are available. Existing pairing/trust, Developer Mode, a usable developer
connection, and any screen-access/unlock prompt must still be satisfied. A live
screen alone is not evidence that each input reached its intended control.
The guide also documents camera/microphone conflicts that can interrupt physical
screen control. These are separate from the transport failures recorded in
[Watch log collection](WATCH_LOG_COLLECTION.md).

### Proposed bounded physical test

1. Open both devices in Device Hub. Verify a harmless app navigation tap, Home
   and reopen, and Watch Crown feedback before treating input as operational.
2. Use real iPhone playback at a known nonzero level and record the selected
   output route. Compare timer Crown, refresh, media Crown, and media → timer.
3. Repeat Home/reopen and a deliberate phone route change. Keep action timestamps
   and screenshots alongside all three app journals; collect matching Watch and
   phone system logs if failure occurs.
4. Observe actual phone volume/audibility separately from a moving Watch ring.
   Avoid repeated uncontrolled route changes or blind volume increases.

Remote interaction can change wake/foreground timing, so it may mask a bug that
normally appears with wrist down. It cannot validate vibration perception,
sweaty-finger reach, movement, or the experience of teaching. Physical controls
and real-class trials remain useful even if remote input works perfectly.

## Next seconds-hand step

The retained [clock-only probe](../tools/timeline-clock-probe/README.md) already
reproduces whole-second backsteps without media, session, or landmark code, using
both Path and Canvas. Fixed anchors and constant color did not reliably help.
See [recorded transition experiments](ALWAYS_ON_HAND_TRANSITION.md).

The next useful step is a separate Apple report with that minimal project and a
short Lock/unlock video showing the reversal. Compare the same fixture on a newer
watchOS Simulator runtime when one is available locally. This Mac currently has
only watchOS 27.0 installed (iOS 27.1 is not a newer Watch runtime).

No speculative hand-rendering change is included in builds 14/15. In particular,
substituting wall `Date.now` for supplied future timeline dates or globally
clamping those dates can break Always-On rendering. Reporting and cross-runtime
comparison are more useful now than repeating the same app rewrites.
