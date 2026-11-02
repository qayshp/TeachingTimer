# Watch diagnostic-sharing capability probe

An isolated, Simulator-only watchOS app using native SwiftUI `ShareLink`.
It does not modify TeachingTimer, read its files, or run a runtime session.
The separate identity is `net.qays.TeachingTimer.DiagnosticShareProbe`.
No account sign-in, recipient, server, upload, or automatic send is configured.

The three buttons offer:

- Harmless plain text, to check the basic native sharing interface.
- A tiny synthetic JSON document exported with `FileRepresentation` and `.json`.
- A compressed ZIP of 34,000 generated events in three synthetic JSON files,
  exported with `FileRepresentation` and `.zip`. This checks a more realistic
  diagnostic-file size without touching real journals. The build records the
  exact sizes and hashes in `fixtures.json` outside the app bundle.

The selected Xcode WatchSimulator SDK declares `ShareLink`, `Transferable`,
`FileRepresentation`, and `SentTransferredFile` available from watchOS 9.
The probe has a watchOS 26 minimum like TeachingTimer and builds using the
selected Xcode's current SDK, not a pinned historical SDK. The build records
the SDK path/version and Xcode version.

## Build

From the repository root, use a new ignored output directory:

```sh
sh tools/diagnostic-share-probe/build.sh work/diagnostic-share-probe-new
```

The script generates deterministic fixtures, validates the ZIP/JSON, compiles
for the Mac's architecture, and signs only for Simulator. It refuses to
overwrite an existing output directory. It never boots, installs, launches,
selects or changes a device. The native export closure logs only a fixed file
type when requested, not content or a successful-delivery claim.

## Bounded manual observation

Use an explicitly selected, already booted Watch Simulator with the newest
compatible runtime available in the selected Xcode. A paired iPhone Simulator
may help expose an activity route, but do not assume it supports delivery.

```sh
xcrun simctl install SIMULATOR_UDID work/diagnostic-share-probe-new/DiagnosticShareProbe.app
xcrun simctl launch SIMULATOR_UDID net.qays.TeachingTimer.DiagnosticShareProbe
```

Open each button and record the sheet, offered activities, any error, and
whether cancellation returns to the probe. Do not send to a real recipient
without separate authorization. No Apple Account sign-in is needed just to
observe what the Simulator offers.

Compilation proves SDK availability. A visible sharing sheet proves only
presentation in that environment. An export-closure log proves only that the
system requested the file representation. None establishes that watchOS Mail,
Messages, a paired phone, or any other destination accepts and delivers a
usable attachment. A physical-device test must verify that separately by
receiving the harmless fixture and checking its name, size, hash and contents
before this becomes a proposed TeachingTimer journal-export route.

This is a capability experiment, not a supported support or diagnostics feature.

## November 2 Simulator observation

Xcode 27.2 (27B52), watchOS 27.2 (24S118), SE 3 40 mm: all three items opened
the native share sheet. Only Messages was offered in this setup. JSON and ZIP
opened Messages compose with their preview titles, and the probe logged requests
for both file representations. Cancelling compose returned to the share sheet;
cancelling that returned to the probe. No recipient was selected and no message
was sent. The harmless files have not been received or hash-checked on another
device. Mail support and physical delivery remain unverified.
