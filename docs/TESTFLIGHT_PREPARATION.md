# TestFlight pilot

Updated November 2, 2026. Build 28 adds distribution packaging and export checks.
There is no uploaded TestFlight build yet. The physical teaching app is unchanged.

## Identities and packaging

| Purpose | Identifier |
| --- | --- |
| Existing development/teaching Watch app | `com.qayshp.TeachingTimer` |
| App Store Connect record / distribution container | `net.qays.TeachingTimer` |
| TestFlight Watch app and its data container | `net.qays.TeachingTimer.watchkitapp` |
| Isolated volume / timeline fixtures | `net.qays.TeachingTimer.VolumeProbe` / `net.qays.TeachingTimer.ClockProbe` |

Normal Debug/Release builds retain the development identity and **Teaching Timer**
name. The `TeachingTimerTestFlight` scheme selects the `TestFlight` configuration;
its Watch app is named **Teaching Timer Beta** to distinguish it on the Watch.
It has separate saved classes, settings and journals. Installing it does not
migrate the development app's data. Do not remove the development app to test it.

Apple's installed Xcode 27.2 Watch-only template includes an empty
`com.apple.product-type.application.watchapp2-container` target. Build 28 follows
that packaging: an iOS distribution stub embeds the single-target Watch app.
There is no iPhone app UI, companion functionality, or additional source code.
The Watch retains `WKWatchOnly = YES`, its mindfulness mode, and no
`WKCompanionAppBundleIdentifier`. The outer identifier is the Watch identifier's
prefix. This refines the earlier proposed bare `net.qays.TeachingTimer` Watch ID;
no TestFlight installation previously used that ID.

Why this was needed: exporting the old bare Watch archive with
`method=app-store-connect` failed because Xcode offered only release-testing,
enterprise and debugging. The packaged archive reaches distribution provisioning.
Apple documents [watch-only distribution](https://help.apple.com/xcode/mac/current/en.lproj/devaba4602fd.html);
see also the [related Apple Developer Forums report](https://developer.apple.com/forums/thread/817223).
The implementation follows the installed template, not a conversion to a
companion app.

## Rehearsal and signed preparation

Unsigned CI/local check (no account access):

```sh
sh scripts/prepare-testflight.sh work/testflight-rehearsal-new
```

Signed, local internal-only export (permits automatic provisioning):

```sh
sh scripts/prepare-testflight.sh --signed work/testflight-pilot-new
```

Both require a new output directory and preserve logs and `readiness.json`.
The signed path archives with the separate scheme, verifies Watch resources and
matching symbols, then asks Xcode for an App Store Connect export. The export is
marked **TestFlight Internal Only**, retains the explicit build number, and
includes symbols. Both embedded profiles/signatures and exact identities are
checked; an expired, wildcard, development, device-limited or enterprise profile
is not accepted as a TestFlight export. Neither command uploads or installs.
Private builds, provisioning material and raw logs remain in ignored `work/`.

Build 29 declares `ITSAppUsesNonExemptEncryption = NO` in both payloads, and
package checks require the actual plist Boolean. The source has no custom or
third-party cryptography; it relies on Apple system services. Reassess this
declaration if dependencies or data-transfer behavior change. See Apple's
[export-declaration key](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)
and [export-compliance guidance](https://developer.apple.com/documentation/Security/complying-with-encryption-export-regulations).

A signed development archive is not a distribution export. A verified local IPA
is not Apple server validation or proof of successful TestFlight installation.
`readiness.json` keeps those stages separate, including on failures.

## Account gate resolved November 2

On November 2, the correctly packaged build-28 archive signed successfully.
Distribution export initially failed with Apple's **“PLA Update available”**
response, requiring the account holder to accept the latest Apple Developer
Program License Agreement. Xcode also reported missing App Store profiles for
the outer and Watch identifiers. Provisioning was retried after agreement
acceptance rather than treating those profile messages as an independent
certificate problem. No certificate was revoked, no agreement was accepted by
automation, and no upload occurred.

The account holder subsequently accepted the agreement. Export of the clean
`ec809c2f12ed` build-28 archive then succeeded. Both distribution profiles,
signatures and signed entitlements passed local verification. The IPA is marked
internal-only; no upload or installation has occurred.

The App Store Connect **iOS** app record has now been created as **Teaching Timer
Beta** for `net.qays.TeachingTimer` (the watch-only packaging identity).
**Teaching Timer** was unavailable. Export compliance, beta contact, upload and
server validation remain separate checks. Use **TestFlight Internal Only** and
the maintainer alone for this first pilot; do not enable automatic distribution
to additional testers. Leave the existing physical teaching installation
untouched until a separate installation request.

## Self-pilot record

Record the actual build, date, OS versions and result for every row. A Simulator
rehearsal must not be recorded as a TestFlight pass.

| Check | Required observation |
| --- | --- |
| Preserve teaching install | Development identifier/build and journals remain present; do not delete it. |
| Install from TestFlight | Beta app appears separately and cold-launches without Xcode. |
| Establish independent state | Start a test class in Beta, note exact/scheduled times, and choose settings. Development state stays unchanged. |
| Relaunch | Beta restores the same class. Intentional Stop remains stopped; running intent attempts recovery. |
| Update through TestFlight | A later beta build preserves class identity/timing, settings and intentional Stop. Verify the new build number. |
| Journal retrieval | Copy all three journals using the **Watch** identifier below; verify parsed data, bounds and build identity. Record failure accurately if distribution container access is denied. |
| Teaching behavior | Check awake/wrist-down clock/count, media recovery, companion volume, and a teaching-length runtime/battery run. |
| Private support | Confirm the chosen address receives a harmless test report before publishing it or inviting testers. Request only necessary diagnostic excerpts. |

Try custom journals independently of installation:

```sh
xcrun devicectl device copy from --device WATCH_IDENTIFIER \
  --domain-type appDataContainer \
  --domain-identifier net.qays.TeachingTimer.watchkitapp \
  --source Documents/RuntimeDiagnostics.json \
  --destination PRIVATE_DIRECTORY/RuntimeDiagnostics.json
```

Repeat for `InterfaceDiagnostics.json` and `LandmarkDiagnostics.json`. Use the
bounded connection workflow in [diagnostic tools](DIAGNOSTIC_TOOLS.md).
Development copies do not prove TestFlight container access. If access fails,
record the error and evaluate a user-triggered export before depending on beta
journals. The app has no tester-facing journal export/upload control; a support
email address or QR code alone cannot attach its private files. TestFlight
feedback/crash reports do not include these custom files automatically. The
[private intake plan](PRIVATE_SUPPORT_PLAN.md) tracks this separate gate.
System-log collection remains a separate workflow with its existing connection
limits. See [Apple's TestFlight instructions](https://testflight.apple.com/).

## November 2 Simulator rehearsal

On the already booted SE 3 40 mm, watchOS 27.2 (24S118), a distribution-identity
Simulator app installed beside the development app and started a fresh class.
After an intentional Stop, an update from a synthetic build 27 to build 28 of
the same candidate source preserved exact class values and stopped intent.
The runtime did not restart. The Simulator moved the Beta container directory
during the update while preserving its saved data. The development container,
preferences and other checked files were unchanged; its runtime journal added
two scene transitions when Beta first opened. The app's runtime journal parsed successfully after
updating. This verifies bundle separation and a Simulator update/relaunch; it
does not verify Apple's TestFlight transport, physical Crown/audio, or
distribution-profile container access.
