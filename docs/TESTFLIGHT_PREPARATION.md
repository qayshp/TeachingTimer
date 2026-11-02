# TestFlight pilot

Updated November 2, 2026. Build 34 passed signed archive/export, upload and Apple
processing and is Ready to Test / Internal. It is assigned to the manual-distribution
Maintainer pilot with one tester, the owner. Builds 29, 31, 32 and 33 are also assigned; build 30
is processed but unassigned. The physical teaching app remains build 25 and is
untouched; no physical TestFlight installation is verified.

Build 34 combines a stable clock schedule with build 33's narrow display-boundary
normalization, retaining the prior readiness, privacy verification and onboarding work.
Preparation/upload/group assignment are complete;
the physical self-pilot below remains unverified.

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

From build-32 tooling, archive inspection and the exported IPA must both contain
the expected Watch privacy manifest: no tracking or declared collection, plus
the reviewed UserDefaults and system-boot-time reasons. Missing, malformed,
duplicate or unexpected declarations fail the check. This is a package-policy
consistency check, not an API-usage audit or Apple privacy approval. The previously
exported build 31 already passes it; no privacy defect was found in that artifact.

Signed preparation requires a clean Git checkout, including untracked source.
It records the full commit in the binary and rechecks the checkout after archive,
before export. A changed HEAD, new edits or mismatched archive revision stops the
export. Ignored private build outputs are allowed. Unsigned rehearsals still
support work in progress; neither mode stages or commits files automatically.

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
internal-only; that build-28 artifact was not uploaded or installed.

The App Store Connect **iOS** app record has now been created as **Teaching Timer
Beta** for `net.qays.TeachingTimer` (the watch-only packaging identity).
**Teaching Timer** was unavailable. The following upload record establishes
build-29 processing; final review metadata and the physical pilot are separate
checks. Use **TestFlight Internal Only** and the maintainer alone for this first
pilot; do not enable automatic distribution to additional testers. Leave the existing physical teaching installation
untouched until a separate installation request.

## First uploaded pilot

Build 29, clean revision `7e9ca4a82324`, passed the signed export checks and was
uploaded November 2 at approximately 12:39 Pacific. App Store Connect subsequently
showed **Ready to Test**, **Internal**, and a 90-day lifetime. The **Maintainer
pilot** internal group has automatic distribution disabled and only the account
holder invited. No external tester, public link or physical installation was
created. Upload/processing are verified; installation/update and distribution
journal access below remain unverified. The separate development build 25 remains
the last confirmed physical installation.

## Subsequent pilot builds

Build 30, clean revision `da9d8d6756f8`, adds the private support entry point and
Settings navigation refinement. Its signed export and upload completed, and Apple
marked it **Ready to Test / Internal**. It has not been assigned to a tester group.

Test Information was saved and verified after reloading: beta description and
known limitations, support address, and repository/privacy URLs. The review
contact remains blank, no custom EULA was added, and the app requires no sign-in.
This is internal-pilot preparation, not a completed external review submission.

Build 31's scene-readiness guard passes all 12 Swift suites, 107 Python tests,
the Debug Simulator build and one matched dimmed-relaunch/wake comparison after the
[build-30 runtime recovery reproduction](RUNTIME_RECOVERY.md#build-31-candidate-comparison).
Clean revision `9da154876eeb6a429e3d655583696b5958b8dd2b` passed signed archive and
export, including the source-cleanliness guard. Upload completed November 2 at
13:19:59 PST; Apple processed it as **Ready to Test / Internal**. The build's
**What to Test** notes were saved, and its **Maintainer pilot** assignment was
verified as one group and one tester, the owner. Build 29 remains assigned too;
automatic distribution remains disabled and build 30 remains unassigned.

No physical installation/update or distribution journal access is established.
The bounded build-31 comparison does not
prove physical recovery or arbitrary activation-callback ordering. The signed
artifact identifies the clean source revision above; later release-documentation
commits do not change that artifact's source identity.

Build 32, clean source `f931c173ab86d6f27fda17083f4afc6163dc2b67`, passed signed
archive/export, including the actual Watch privacy-manifest checks. Its IPA
SHA-256 is `ece330038a7e9a5fb00e8351bab42a3bb6d5e99978a67220c4de519f783c2d21`.
Upload completed November 2 at 13:50:22 PST. Apple shows **Ready to Test / Internal**;
its What to Test notes and assignment to the one-owner **Maintainer pilot**
survived reload. At that checkpoint the group showed **Manual** distribution, one tester and three
builds: 29, 31 and 32. Build 30 remains unassigned. Build 32 passes all 12 Swift
suites, 110 Python tests, 21 Simulator UI-action assertions and
[CI](https://github.com/qayshp/TeachingTimer/actions/runs/41531683416).

Build 33, clean source `12772ccabb44b4bc93ce235f5bc94b3790c8d740`, passed signed
archive/export. Its IPA SHA-256 is
`1722581675ee31796e2e6fc27b783d1ea35a2d896358cd16eb35a681d1c23f88`.
Upload completed November 2 at 14:39:14 PST; Apple processed it as **Ready to
Test / Internal**. What to Test notes and assignment to the one-owner
**Maintainer pilot** survived reload. At that checkpoint assigned builds were 29, 31, 32 and 33;
30 remains unassigned, and distribution remains manual. All 13 Swift suites,
117 Python tests, 21 full-app Simulator UI-action assertions and
[CI](https://github.com/qayshp/TeachingTimer/actions/runs/41538777416) pass.
Later documentation commits do not change this artifact's source revision.
Physical install/update, journal access and teaching validation remain unverified.

Build 34, clean source `ee054de666c34274d3fe200d0f69d698c50c97b7`, passed signed
archive/export. Its IPA SHA-256 is
`a94b8505d72eab91df9f111570b778d04dee21d4c0fe4fb358cd5d24915c5e66`.
Upload completed November 2 at 15:02:59 PST; Apple shows **Ready to Test /
Internal**. What to Test notes and one-group assignment survived reload.
The **Maintainer pilot** settings show one tester, five builds (29, 31, 32, 33
and 34), and **Manual** distribution; 30 remains unassigned. All 13 Swift suites,
117 Python tests and [CI](https://github.com/qayshp/TeachingTimer/actions/runs/41541943839)
pass, alongside 21 app UI-action assertions and bounded clock/locked-count checks.
The recorded Debug integration artifact is distinct from this clean signed
source; later documentation commits do not alter the artifact's revision.
Physical installation/update, journal access and teaching validation remain open.

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
| Private support | Inbound delivery to teachingtimer@qays.net was verified November 2. Verify outbound alias replies and any attachment path separately; request only necessary evidence. |

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
