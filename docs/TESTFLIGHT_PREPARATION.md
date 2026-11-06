# TestFlight pilot

Current build/install status lives in [current verification](../DEVELOPMENT_STATUS.md).
The owner most recently reports **1.0 (261104.1939.6)** on the Watch; frozen song
progress persists. The earlier [build-42 update](#november-4-2026--hosted-release-validation)
succeeded through TestFlight without a developer connection. Unattended-update
timing remains unverified.

The [public invitation](https://testflight.apple.com/join/YA2WSmae) now offers
**View in TestFlight** (checked November 5, 2026). Its page does not identify the
eligible build; exact external membership and a first external installation
remain separate checks. The November 2 submission history below retains its
original status rather than describing current availability.

## November 2 external submission checkpoint

On November 2, 2026, **build 37 was submitted for the first external Beta App
Review and was Waiting for Review.** Its signed external-eligible export, upload,
Apple processing and Public beta group assignment are verified. The
[public invitation](https://testflight.apple.com/join/YA2WSmae) is configured for
anyone with a 100-tester limit, but did not yet accept testers while
approval was pending. Build 37 preserves build 36's app behavior. No physical
installation was performed for this release.

Build 36 passed signed archive/export, upload and Apple
processing and is Testing / Internal. It is assigned to the manual-distribution
Maintainer pilot with one tester, the owner. Group settings confirm seven builds
(29, 31, 32, 33, 34, 35 and 36); 30 is processed but unassigned. The release is authorized to test
the owner's enabled TestFlight automatic updates. At that November 2 checkpoint,
build 35 was the last confirmed physical Beta and automatic updating was unverified.
The separately authorized
[physical owner pilot](TESTFLIGHT_PILOT_RESULTS.md) verifies initial Beta
installation/update/relaunch and limited developer-tool journal access. Cleanup
and development-app preservation checks are complete with the dated record's
qualification about normal stale-class retirement and unavailable pre-install
preferences.

Build 36 corrects privacy disclosure only. Core behavior is unchanged from build
35, including build 34's stable clock schedule and build 33's narrow display-boundary
normalization. Preparation/upload/group assignment are complete; the physical
installation/update/relaunch pilot is verified within its recorded limits,
not a completed teaching trial or general tester-export solution.

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

Signed, local export eligible for external TestFlight review (explicit opt-in):

```sh
sh scripts/prepare-testflight.sh --signed --external-eligible work/testflight-public-new
```

`--external-eligible` requires `--signed`. Omitting it preserves the internal-only
default. It changes the export audience, not application behavior; it does not
submit review, invite testers or create a link.

All modes require a new output directory and preserve logs and `readiness.json`.
The signed path archives with the separate scheme, verifies Watch resources and
matching symbols, then asks Xcode for an App Store Connect export. The export is
marked **TestFlight Internal Only** by default; the explicit external option
sets `testFlightInternalTestingOnly` to false. Both retain the explicit build
number and include symbols. Embedded profiles/signatures and exact identities are
checked; an expired, wildcard, development, device-limited or enterprise profile
is not accepted as a TestFlight export. None of these commands uploads or installs.
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

The following release checkpoints predate the separately authorized physical
[owner-pilot results](TESTFLIGHT_PILOT_RESULTS.md). Their original installation
and access limits are retained as history.

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
At that checkpoint the **Maintainer pilot** settings showed one tester, five builds (29, 31, 32, 33
and 34), and **Manual** distribution; 30 remains unassigned. All 13 Swift suites,
117 Python tests and [CI](https://github.com/qayshp/TeachingTimer/actions/runs/41541943839)
pass, alongside 21 app UI-action assertions and bounded clock/locked-count checks.
The recorded Debug integration artifact is distinct from this clean signed
source; later documentation commits do not alter the artifact's revision.
Physical installation/update, journal access and teaching validation remain open.

Build 35, clean source `b5884e30dd8ab04c956e629a5f0a5c7864b58c2b`, passed signed
archive/export, including actual Watch privacy-manifest checks. Its IPA SHA-256 is
`720b00521812f879ad18eb79199cbaa6e7cf6119afa925e3ae0f93c63461914f`.
Upload completed November 2 at 15:32:23 PST; Apple shows **Ready to Test /
Internal**. Exact What to Test notes and one-group/one-tester assignment survived
reload. At that checkpoint **Maintainer pilot** had one owner, six builds (29, 31,
32, 33, 34 and 35) and **Manual** distribution; 30 remained unassigned.
[Watch CI](https://github.com/qayshp/TeachingTimer/actions/runs/41544098376)
passes 13 Swift suites / 117 Python tests;
[CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/41544096984) also passes.
The clean Debug build's [layout matrix and bounded controls run](V1_READINESS_REVIEW.md#build-35-static-layout-matrix)
verify the support-copy change and sampled rendering. Subsequent tooling passes
128 Python tests, separately from this signed source checkpoint. The physical
Watch remains untouched and all physical self-pilot checks below remain open.

### Build 36

Clean source `1dbcfc4dacf9354e9b34a6d42ca7022b3566b600` passed signed archive
and internal-only export on November 2. Its IPA SHA-256 is
`dfa47e8e3e8b64f1835e6c7e140c1c3bb507c02a1bed82c4c7eaaf562e34bab9`.
Both payload identities, matching versions, distribution profiles, entitlements,
signatures and the exported Watch privacy manifest passed validation.
The source checkpoint's [Watch checks](https://github.com/qayshp/TeachingTimer/actions/runs/41556710607)
and [CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/41556710124) pass. The local verification
also passes 13 Swift suites and 128 Python tests, and the small SE 3 privacy
overview/full-policy rendering check is complete.

The user subsequently authorized uploading this existing artifact and assigning
it to test automatic updates. Upload completed November 2 at 17:23:52 PST;
Apple shows **Ready to Test / Internal**. Exact What to Test notes and assignment
to one **Maintainer pilot** group with one tester survived reload. Group settings
confirm seven assigned builds (29, 31, 32, 33, 34, 35 and 36) and **Manual for Xcode
Builds**; 30 remains unassigned.
The owner confirmed TestFlight automatic updates enabled. The assigned build is
shown as **Testing / Internal**. No direct physical
installation or device query was performed for this release; build 35 remains
the last confirmed physical Beta, and automatic installation of 36 is unverified.
Build 36 changes privacy disclosure, not recovery behavior or data handling.

### Build 37 public-beta preparation

The owner has authorized opening a public TestFlight beta and publishing its
real invitation link in the repository. Candidate 37 preserves build 36's app
behavior; release tooling now supports an explicit external-eligible export.
Clean source `a36f3be587825e27b424cf54355ea13afdfded83` passes all 13 Swift suites
and 130 Python tooling tests. Signed archive/export checks passed for both
identities, profiles, entitlements, signatures and the actual Watch privacy
manifest. The requested and Xcode-produced export options both set
`testFlightInternalTestingOnly=false`; the internal-only default remains unchanged
for ordinary `--signed` preparations. The local exported IPA SHA-256 is
`d09a54b067f7e5d2e4b841d4b51a94494e39e6d1cfd0171aeb746dd4ff23ab31`.

[Watch CI](https://github.com/qayshp/TeachingTimer/actions/runs/41574826046)
and [CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/41574826133)
both pass for that source commit.

Upload completed November 2 at 19:56:05 PST. Apple processed 1.0 (37) as
**Ready to Submit**, without the Internal Only designation. It is assigned to
the **Public beta** external group and is now **Waiting for Review** following
the first Beta App Review submission. Review contact was supplied by the owner;
the beta description, feedback address and reviewer instructions were saved and
verified after reload. Review notes describe the actual guided-yoga use of
mindfulness runtime and automatic renewal without claiming prior acceptance.
No app sign-in is required. The build's saved What to Test and single external
group assignment were read back after submission.

The public invitation is enabled for anyone, with a 100-tester cap and automatic
tester notification enabled at submission. The current public page still says
it is not accepting testers. Approval and a usable installation invitation remain
pending; link creation is not evidence of either. The initial public support route
accepts descriptions and cropped screenshots without requiring journal export.
Build 36 remains assigned to the existing internal Maintainer pilot; build 35
remains the last user-confirmed physical Beta. No automatic installation is
promised by an upload, group assignment or link creation.

Apple says Internal Only uploads can join only internal groups. Builds through
36 used that audience, so the public beta needs a new eligible upload. The first
external submission requires TestFlight App Review. Keep these stages separate:

1. Validate clean candidate source and its signed external-eligible export.
2. Upload and verify Apple's processed build number and audience.
3. Create an external group and add the eligible build with clear What to Test.
4. Complete real review-contact information, beta description and feedback
   email, then submit for review. No app sign-in or demo credentials are needed.
5. After approval, verify distribution and that the public invitation offers the
   intended build. The README currently includes the real link with a clear
   awaiting-approval label; it must not be described as installable before that check.

The configured 100-tester public-link cap is a pilot choice, not an Apple
requirement. The internal group and its owner assignment remain separate.
See Apple's [external-testing workflow](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
and [test information requirements](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

The public pilot can explicitly accept descriptions and cropped screenshots
without journal attachments. The monitored support alias has verified plain
email delivery; ordinary tester journal export remains unavailable. This is
the limited-intake option in the [support plan](PRIVATE_SUPPORT_PLAN.md), not
a claim that the app uploads diagnostics or that general tester retrieval works.

## Self-pilot record

Record the actual build, date, OS versions and result for every row. The dated
[physical results](TESTFLIGHT_PILOT_RESULTS.md) distinguish completed checks from
remaining teaching/access gates. A Simulator rehearsal is not a TestFlight pass.

| Check | Required observation |
| --- | --- |
| Preserve teaching install | Development identifier/build and journals remain present; do not delete it. |
| Install from TestFlight | Beta app appears separately and cold-launches without Xcode. |
| Establish independent state | Start a test class in Beta, note exact/scheduled times, and choose settings. Development state stays unchanged. |
| Relaunch | Beta restores the same class. Intentional Stop remains stopped; running intent attempts recovery. |
| Update through TestFlight | A later beta build preserves class identity/timing, settings and intentional Stop. Verify the new build number. |
| Journal retrieval | Copy all three journals using the **Watch** identifier below; verify parsed data, bounds and build identity. Record failure accurately if distribution container access is denied. |
| Teaching behavior | Check awake/wrist-down clock/count, media recovery, companion volume, and a teaching-length runtime/battery run. |
| Private support | Incoming and outgoing plain email through teachingtimer@qays.net were verified November 2. Native Watch and diagnostic attachment delivery remain unverified; request only necessary evidence. |

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
Development copies alone do not prove TestFlight container access. The owner
pilot retrieved all three Beta files in one developer-enabled setup; this does
not establish general tester access. If access fails,
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

### Build 38 owner media experiment

At the owner's request, clean PR-18 source
`57fde699e424f6a22e70a0c42da54c43e3c3961d` was signed/exported with
`--signed --external-eligible`. Both payloads, signatures, profiles, identifiers,
entitlements and the actual Watch privacy manifest passed validation; source
cleanliness/revision checks passed. The local IPA SHA-256 is
`c1811957673066550863b5629334f0e033b258e43b1008138cf04e0d64e39523`.
Xcode reported upload success November 2, 2026 at 23:09:35 PST. PR-18 Watch CI,
CodeQL and AccessLint all pass. The draft remains open for physical comparison.

The refreshed App Store Connect browser requested sign-in at that checkpoint.
Processing, saved What to Test and group availability were therefore unverified;
the signed preparation/upload records are retained privately. On November 3,
processing was verified: the external-eligible build is Ready to Submit and is
eligible for internal testing, but remains unassigned to tester groups. Its test
notes/group assignment are still pending. The intended destination is
the internal Maintainer pilot, with build 37 also available as the unchanged
hosting baseline. No public-group assignment, physical install or launch was
performed. Browser authentication is now available; no rebuild is required merely
to finish that earlier experiment's group assignment.

TestFlight supports sharing multiple builds and organizing tester groups. For
this experiment, choose 37 and 38 manually, one at a time on the same Watch:
keep the iPhone track/output fixed, compare at least 30 seconds of bright-screen
song progress, then test dim/wake, Pause, timer Crown and Home return. Do not
reset the saved class between versions; verify it and intended runtime state
after each install/open. Position catch-up is separate from continuous accuracy.
Automatic updates may change the chosen build, so check About before each trial.
The existing development installation remains a separate app.

Build 39's matching-dial work is independent and is not part of the build-38
upload or media A/B comparison.


### Build 41 maintainer layout pilot

At the owner's request, clean layout-PR source
`30df065a33e86211d76b34fd9a23da0d127ac64b` was signed/exported as an
internal-only TestFlight build. Both payload identities, signatures, profiles,
entitlements and the Watch privacy manifest pass validation. The archive retains
the exact clean source revision; the local exported IPA SHA-256 is
`be1aa4fbe4bab463bcda5189b1acf390061b1115e66d4a10172bf83ee77422d7`.

Xcode reported upload success November 3, 2026 at **15:56:00 PST**. Apple processed
**1.0 (41)** as **Testing / Internal**, with a 90-day lifetime shown. What to Test
notes and the sole **Maintainer pilot** assignment survived reload: one internal
group, one tester, the owner. The final builds listing also shows Testing and the
Maintainer pilot group. No external-group assignment or review submission was
performed for this build. Public build 37 is separately In Review.

Build 41 contains the full-screen edge-following dial and all 60 full-length ticks
layered beneath the top elements. The Class backing is 75% opaque; tick portions
under system time are reduced to quarter strength. Hands remain foremost. It
preserves baseline class/runtime/count/native-volume behavior and does **not**
include build 38's separate media-hosting experiment. Existing native song-progress
stalls may remain. The saved notes ask for bright/dim readability and volume
checks after Class interaction, Home/reopen, refresh and media return.

All 13 Swift suites, 132 Python tests, Simulator and unsigned archive checks,
six lifecycle/focus assertions and Class-sheet presentation/dismissal pass.
[Thirteen five-size captures](FORM_FACTOR_VALIDATION.md#november-3-build-41-layered-header-ticks)
include SE 3/Ultra reduced-luminance and maximum-text views. Those checks are
separate from the verified signed export/upload. No direct physical-device
connection, installation or launch was attempted for this release. TestFlight
installation/automatic-update outcome and physical readability remain unverified.
Later release-documentation commits do not change the signed source above.

## Automatic and manual GitHub release

The **TestFlight maintainer release** workflow builds on a GitHub-hosted Mac.
Every push to `main` runs the change classifier and lightweight repository/Python
checks. Only app inputs (or an unrecognized path, treated conservatively as an
app input) run full Mac/Xcode verification and may publish to TestFlight. Docs-only
and CI/tooling-only changes do not sign or upload an app; workflow changes run
`actionlint`, and other tooling changes run Python tooling tests. Swift test-harness
changes receive Mac verification without an upload. The Watch-check workflow's
stable required-result job reports whether its applicable checks passed. Manual
rehearsals and publishes always run full verification. See
[automation check boundaries](AUTOMATION.md#maintainer-testflight-release).

After app verification passes, the workflow automatically signs, uploads, waits
for Apple processing and assigns that build to the internal Maintainer pilot.
Failed verification never reaches the publishing job. Each published workflow
run gets an automatic build string in Pacific local time:
`YYMMDD.HHmm.sequence` (for example, `261104.1602.17` means November 4, 2026,
at 4:02 p.m. Pacific, workflow run 17). The final component is the workflow's
unique increasing run number, so builds created in the same minute remain
distinct without a race-prone lookup. Daylight-saving time follows Pacific
local time. Manual releases may still use an explicit positive integer.
App Store Connect's duplicate-build check remains an additional safeguard.
There is no concurrency policy that silently replaces queued `main` builds.

The workflow also retains a manual `workflow_dispatch` trigger. Choose **Use
workflow from: main**, then provide an unused integer build number, testing notes,
and either `rehearsal` or `publish`. Rehearsal remains the default and never
uploads. The tools and application come from the exact selected workflow commit;
there is no free-form application-ref input. The release job checks out the same
SHA verified by the first job. A command-line build-number override changes both
payloads without dirtying source; the archive retains its exact revision.

The credential-bearing publishing environment permits only `main`. Merge reviewed
application changes before publishing them with this workflow. Another branch
containing the workflow can run a credential-free rehearsal in its own branch
context. Do not copy an arbitrary branch into a privileged default-branch job;
that can expose default-branch caches even when no signing secret is supplied.

- **Rehearsal** is the default. It runs checks and creates a real unsigned
  distribution archive with the requested build number. It needs no credentials,
  never calls the App Store Connect API and does not assign a group. Its status is explicitly
  `rehearsal_complete`, never `available`.
- **Publish** uses the protected `testflight-maintainer` environment. It validates
  the app and existing internal group, rejects an already-used build number,
  signs/exports an internal-only package, uploads it, polls Apple, saves/verifies
  What to Test, assigns only Maintainer pilot and verifies `IN_BETA_TESTING`.
  It never creates/invites testers, enables a public link or submits App Review.

The hosted `xcode-27` runner explicitly selects Xcode 27.2 and records its actual
version/build. GitHub's published image may differ from the local Mac; a missing
or incompatible toolchain fails rather than silently selecting an older SDK.
No Simulator is created/booted and no physical device is contacted.
Verification also compiles the four standalone diagnostic fixtures and four
Simulator-inspection helpers through `scripts/check-simulator-tools.sh`; it
does not exercise their audio, sharing or UI behavior.

### One-time credentials

Create the GitHub environment **testflight-maintainer**, restricted to workflow
runs from `main`. Keep the separate rehearsal environment free of credentials.
The publishing environment needs these secrets:

| Secret | Value |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect team API key identifier |
| `ASC_ISSUER_ID` | Team API issuer identifier |
| `ASC_PRIVATE_KEY_BASE64` | Base64 of its downloaded `.p8` private key |
| `DISTRIBUTION_CERTIFICATE_BASE64` | Base64 of an Apple Distribution identity exported as password-protected `.p12`, including its private key |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | That `.p12` export password |
| `CONTAINER_PROFILE_BASE64` | Base64 App Store profile for `net.qays.TeachingTimer` |
| `WATCH_PROFILE_BASE64` | Base64 App Store profile for `net.qays.TeachingTimer.watchkitapp` |

Use an App Manager team API key for TestFlight metadata/distribution. Team keys
have role-level access across the account's apps; the release client additionally
pins this app, team and internal group. Do not use an Apple Account password.
Generating/downloading a key is a one-time account-owner setup; Apple may first
require requesting API access. Store private files outside Git and enter values
through GitHub's encrypted environment secrets, never an issue or workflow input.
A cloud-managed certificate without an exportable private key is not a `.p12`
identity; use a suitable dedicated CI identity without revoking the teaching one.

Verify the encrypted `.p12` imports into an isolated temporary macOS keychain
before saving it as a secret. During the November 4 setup, an OpenSSL 4 default
package failed `security import` with “MAC verification failed” despite the
correct password. Repackaging the same certificate/private key with
`PBE-SHA1-3DES` for both key and certificate encryption, a SHA-1 MAC and 100,000
iterations imported successfully. This changes the encrypted package format,
not the certificate signature or signing identity; no certificate was revoked.
The initial hosted attempt stopped at import, before archiving or uploading.

A temporary runner keychain and SDK-specific manual signing configuration use
both profiles. Profiles must be unexpired, explicit App Store profiles for the
expected team and identifiers. Cleanup restores the previous keychain search
list and removes only credentials/profiles created by this run. Secrets are not
needed by normal pull-request verification.

### Timing, errors and resume

The run summary and `testflight-release-RUN_ID` artifact contain `summary.md` and
`release.json`: source/build identity, local IPA digest, UTC stage timestamps,
monotonic durations, archive/export substeps, polling observations and final
verified status. GitHub dispatch/job times and Xcode identity are recorded too.
Neither the private IPA, raw signing logs, API tokens nor credentials are uploaded
as public artifacts. The report's `installed` field remains false.

Polling defaults to 15 seconds with a bounded wait. `availabilityConfirmedAt`
means first observed server-side readiness after notes/group readback; it is not
an exact server transition, client refresh, Watch download or installation time.
Apple failure/compliance states stop the release visibly. No processing timeout
or failed request is reported as success.

An interrupted or failed upload is never blindly repeated. The report preserves
whether the upload command actually succeeded. After a successful upload, the
CLI can resume metadata using a downloaded `release.json`, the same source/build/
notes, and API credentials; the private IPA/signing keys are not needed again:

```sh
python3 scripts/testflight-release.py --resume \
  --source /path/to/clean-reviewed-checkout --build-number 42 \
  --notes-file /private/path/notes.txt --output /private/path/saved-release-report
```

Configure `ASC_TOKEN_HELPER` (compiled from `scripts/asc-token.swift`),
`ASC_KEY_PATH`, `ASC_KEY_ID` and `ASC_ISSUER_ID` for that local resume. If upload
outcome is uncertain, inspect its original log/server record before taking another
action; the client deliberately refuses to repeat it. The first workflow version
accepts fresh releases/rehearsals; it does not automatically download past reports
when GitHub's Re-run button is used.

The setup and deterministic tests do not establish that live credentials work.
Record a successful hosted rehearsal separately from the first actual signed
publish, Apple processing and pilot assignment.

Primary references: [GitHub Xcode signing](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications),
[runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md),
[Apple API keys](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api),
[build/group API](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betagroups-_id_-relationships-builds).

### November 4, 2026 — hosted release validation

[Release automation PR 21](https://github.com/qayshp/TeachingTimer/pull/21) merged
as `9dd7c1cde7bf7d53cf696d797a898c704ab65a3d`. All 13 Swift suites,
161 Python tests, actionlint, Watch CI, CodeQL and AccessLint passed. The seven
publishing secrets are configured with a dedicated API key, distribution
certificate and two App Store profiles; existing signing credentials were not
revoked. The new certificate/profiles expire November 4, 2027 at 08:25:55 UTC.

The [hosted rehearsal](https://github.com/qayshp/TeachingTimer/actions/runs/41800134280)
passed on that exact main revision with build-number override 42. Its result is
`rehearsal_complete`, with `uploaded=false`; the archive took 30.674 seconds.
The runner recorded Xcode 27.2, build **27B48**, distinct from local build 27B52.
No older toolchain was silently selected.

For the signed live test, branch `codex/testflight-live-validation` at
`190e0738b82d03b9a24c9e9192a3ff86badafab8` combines layout source `76a1544`
with the merged automation. Its application implementation is unchanged from
build 41; the requested build-number override is 42. The layout and media draft
PRs remain separate and unmerged. All 162 Python tests, 13 Swift suites,
repository checks and actionlint passed for this integration. Normal future
publishing requires reviewed app changes on `main`; this branch was allowed only
for the bounded bootstrap test.

The [first live attempt](https://github.com/qayshp/TeachingTimer/actions/runs/41801696366)
passed verification but failed importing the encrypted identity. It never
started an archive or upload. The temporary branch exception was removed and
`main`-only access verified before correcting the package format described above.

The [second live run](https://github.com/qayshp/TeachingTimer/actions/runs/41802278857)
passed end to end. Its signed **1.0 (42)** export passed payload, signature,
profile, entitlement, privacy-manifest and exact-source checks. The IPA digest is
`59cd502944a5730634d6bcf993895f5a596143eceab22c70cb20b42d83a1fe6f`.
Apple reports `VALID`, `INTERNAL_ONLY` and `IN_BETA_TESTING`. Test notes match
their saved digest, and the sole assigned group is **Maintainer pilot**; a separate
read-only API check confirmed these results. No external submission was made.

| Milestone | November 4 UTC | Recorded duration |
| --- | --- | ---: |
| Workflow dispatched | 08:48:01 | — |
| Source verification | 08:48:05–08:51:13 | 3 min 8 sec |
| Signed archive/export | 08:51:37.350–08:52:14.399 | 37.049 sec |
| Upload | 08:52:14.428–08:54:16.608 | 122.181 sec |
| Processing/visibility polling | 08:54:16.614–08:57:36.383 | 199.769 sec |
| Test notes readback | 08:57:36.384–08:57:37.287 | 0.903 sec |
| Maintainer assignment/readback | 08:57:37.289–08:57:39.216 | 1.927 sec |
| Final availability check | 08:57:39.217–08:57:40.901 | 1.684 sec |

Availability was first confirmed at **08:57:40.903 UTC / 00:57:40.903 PST**,
204.290 seconds after the upload command succeeded, and about 9 minutes 40 seconds
after dispatch. These are observations at the configured 15-second polling
cadence. Apple's separate reported upload date is 08:56:40 UTC; it does not equal
the local upload command's completion time. Neither establishes the precise
instant a Watch client first offered or installed the build.

Runner cleanup passed. After completion, the temporary branch exception was
removed and an independent environment query confirmed **main only**. The final
timing/artifact reports contain no signing material. The CI run made no direct
physical-device connection, installation or launch. Build 42 preserves build 41's
app behavior and does not include the separate build-38 media-hosting experiment.

Later on November 4, the owner confirmed build **42 is installed on the physical
Watch**: TestFlight on the paired iPhone successfully updated the Watch app with
**no developer connection required**. This completes the observed delivery path
from the hosted workflow through TestFlight to the Watch. It is owner-reported
installation evidence, not a new developer inventory, launch check or class trial.
The owner reports updates do not appear on a regular cadence unless triggered
in the iPhone TestFlight app; unattended automatic-update timing remains
unestablished. The CI timing above ends at server-side availability and does not
include this later installation.
