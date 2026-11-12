# Distribution metadata draft

Reviewed November 5, 2026. The
[public invitation](https://testflight.apple.com/join/YA2WSmae) now offers
**View in TestFlight**. Exact eligible-build membership and a new external
tester's installation remain unverified. The first external submission was
Teaching Timer Beta 1.0 (37); the initial public group limit was 100.
See [current verification](../DEVELOPMENT_STATUS.md) for build/install status and
the [submission history](TESTFLIGHT_PREPARATION.md#build-37-public-beta-preparation)
for the dated review evidence. This is not an App Store release.

| Field | Draft |
| --- | --- |
| App Store Connect name | Teaching Timer Beta; Teaching Timer was unavailable |
| Subtitle | A clock for teaching yoga |
| First external submission | 1.0 (37), clean source `a36f3be587825e27b424cf54355ea13afdfded83`, signed/exported, uploaded and processed as external-eligible. See current status for invitation availability. |
| Internal owner pilot | App-affecting main pushes use the automated signed release and existing Maintainer pilot; this does not submit external review or change public-group membership. |
| Physical Beta | [Current verification](../DEVELOPMENT_STATUS.md) owns the latest owner-reported installation and its validation limits. |
| App Store Connect bundle identifier | net.qays.TeachingTimer |
| Watch payload identifier | net.qays.TeachingTimer.watchkitapp |
| Keywords | yoga,teacher,clock,timer,class,landmarks,mindfulness |
| Support URL | https://github.com/qayshp/TeachingTimer/blob/main/SUPPORT.md |
| Privacy information | https://github.com/qayshp/TeachingTimer/blob/main/docs/PRIVACY.md |
| License | MPL-2.0 |

**November 6 owner-pilot addition:** [native diagnostic sharing](DIAGNOSTIC_EXPORT_PLAN.md)
is approved for merge after review/CI and subsequent internal TestFlight testing.
Merge and release completion remain tracked in [current status](../DEVELOPMENT_STATUS.md).
Test notes should ask the owner to verify sharing after class and state that
successful Simulator staging does not establish recipient delivery. General
journal access remains unverified. No upload service or iPhone companion was added.

## Description

Keep a large wall-clock seconds hand in view while teaching. Add a scheduled
class-end marker, a one-minute visual count with optional vibration landmarks,
and access to Apple's native media controls on your Watch.

Start a suggested 60-minute class or adjust its start and duration. Class timing
is preserved when you stop the mindfulness runtime or reopen the app. Timer-page
Crown volume targets the paired iPhone. The app runs on Watch without an iPhone
companion app; phone playback control still needs the paired phone.

This beta has known media, volume and Always-On transition issues. System runtime
and vibration delivery are not guaranteed. Test it outside class before relying
on it while teaching.

## Beta test notes

Use the [quick start](TESTER_GUIDE.md). Please report app/build and OS versions,
what happened before a failure, and any recovery. Prioritize class timing,
Stop/Resume versus End class, count cancellation, media return and phone volume.
No account or login is required by Teaching Timer. Do not submit personal logs
in public feedback.

## Detailed reviewer execution notes — draft

A shorter reviewer summary was submitted with build 37. It describes the guided
yoga/mindfulness context, automatic runtime replacement, known limitations and
absence of an app account. The detailed draft below and the separate
[runtime-use inquiry](#runtime-use-briefing-for-apple--not-submitted) were not
submitted as standalone requests; no Apple intended-use guidance has been received.

Teaching Timer Beta is a Watch-first clock for yoga teachers. The optional iPhone
interface requests diagnostic reports and prepares support email; it is not
required for teaching. No app login or test account is required.
Clock and count features work without music. No workout or HealthKit access is used.

1. Open the Watch app. Tap **Start class**, check the suggested quarter-hour and
   press **Start class** again for 60 minutes. **Custom schedule** changes only
   this class. Both hands show wall time; the outer wedge marks scheduled finish.
2. Tap **1-min count**. Its inner arc fills over 60 seconds; vibration groups of
   1–6 begin every 10 seconds, with completion near 64.8 seconds. **Stop count**
   cancels immediately. Haptic delivery is system-controlled.
3. Tap the upper-left **gear**, then **Stop session**. Timing remains saved;
   **Start session** or **Resume session** on the face or in that menu requests
   the wrist-down session. **End class** requires confirmation and clears class
   timing. Intentional Stop persists on relaunch.
4. Open **Gear → Settings** for **Count vibrations**, **Minutes left**, and the
   offline Help, Privacy and About pages. Vibration changes apply to the next count.
5. For media testing, first play audio on the paired iPhone at modest volume.
   Timer Crown volume targets that phone. Swipe left for native Now Playing,
   which may select Watch playback instead. If native progress stalls or media
   is blank, swipe away and back; timer volume refresh is a tap on its display.

Start requests a mindfulness extended-runtime session, separate from the saved
class. Automatic replacement, its eligibility checks and the unresolved intended-use
questions are described in the [runtime-use briefing](#runtime-use-briefing-for-apple--not-submitted).
Neither renewal nor 1 Hz wrist-down updates are guaranteed. Known native
media/volume defects and recovery limits are listed in the [issue map](ISSUE_TRACKER.md).

## Before App Store submission

- The owner filled all four Beta App Review contact fields; they were saved and
  verified after reload before build 37's submission. Account/signing and the
  support route are established. Confirm category, age-rating and remaining
  store-specific declarations against the final candidate; beta submission does
  not complete those decisions.
- Review privacy answers against the final binary and how support diagnostics
  will actually be received. Apple says optional disclosure has specific
  criteria; do not assume all voluntary support data is exempt. See
  [Apple's privacy-detail guidance](https://developer.apple.com/app-store/app-privacy-details/).
- The existing privacy manifest is a starting point, not proof of store acceptance.
  Confirm required-reason declarations against [Apple's API guidance](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).
- The comparison screenshots are genuine Simulator evidence, including
  disconnected media icons and variable capture times. They are tester/review
  assets, not a finalized App Store screenshot set. Prepare final screenshots
  only after the beta behavior and supported-device claims are validated.
- The [owner installation/update/relaunch pilot](TESTFLIGHT_PILOT_RESULTS.md)
  completed, including developer-tool Beta journal retrieval in one
  developer-enabled Watch/trusted-Mac setup. General tester access and teaching
  validation remain open. Build 36 passed clean signed
  archive/export, upload and processing and is assigned to the owner pilot.
  Its Watch CI passes 13 Swift suites / 128 Python tests, and CodeQL also passes;
  its targeted Privacy rendering check and the earlier build-35 layout matrix
  and bounded controls checks are reviewed.
  The physical result is separate evidence from those source and processing checks.

### Bounded source-to-declaration inventory

Manual review on November 2 follows the listed source paths and current
[privacy manifest](../TeachingTimer/PrivacyInfo.xcprivacy). It is not a binary or
framework-wide API audit, a guarantee that no API was missed, or a final App Store
privacy/legal declaration. Artifact checks separately verify that the reviewed
manifest is present in the archive and IPA.

| Inspected use / data | Source evidence | Declaration or decision boundary |
| --- | --- | --- |
| App-owned preferences and recovery values | [ClassContext](../TeachingTimer/ClassContext.swift), [RuntimeIntentStore](../TeachingTimer/RuntimeRenewalRules.swift), [LandmarkController](../TeachingTimer/LandmarkController.swift), [Settings](../TeachingTimer/ClassControlsView.swift) and [persistence recovery](../TeachingTimer/PersistenceDiagnostics.swift) read/write class timing, runtime intent, count result and settings through UserDefaults/@AppStorage. | The manifest declares UserDefaults reason `CA92.1`. The inspected uses are app-owned storage, consistent with [Apple's reason for app-only defaults](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). This does not authorize reading another app's preferences. |
| Monotonic media-refresh intervals | [MediaReloadPolicy](../TeachingTimer/MediaReloadPolicy.swift) compares `ProcessInfo.systemUptime` samples for dim duration and refresh cooldown. Those absolute samples remain private policy state. | The manifest declares system-boot-time reason `35F9.1`, covering elapsed intervals/timers. [Apple's rule](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) distinguishes shareable in-app elapsed intervals from raw uptime and other derived data. Related [count](../TeachingTimer/LandmarkController.swift), [runtime](../TeachingTimer/ExtendedRuntimeController.swift) and [focus](../TeachingTimer/VolumeControlDiagnostics.swift) diagnostics use elapsed `ContinuousClock` durations; do not treat this declaration as permission to export raw boot-time values. |
| Local operational journals and recovery files | [RuntimeDiagnostics](../TeachingTimer/RuntimeDiagnostics.swift) and [LandmarkDiagnostics](../TeachingTimer/LandmarkDiagnostics.swift) store timestamps, lifecycle/errors and count submissions on the Watch. Valid journals trim on writes at seven days and caps of 10,000/10,000/20,000 events. | There is no automatic developer upload. Corrupt-journal copies are separate files and can accumulate without a count/time cap; they are not covered by the valid journals' rolling limits. Preference recovery is separately one value per store. Exported copies need their own handling/retention assessment. |
| Native diagnostic export — November 6 owner pilot | [Report builder](../TeachingTimer/DiagnosticReport.swift), [sharing UI](../TeachingTimer/DiagnosticSharingView.swift) and [prepared-file cache](../TeachingTimer/DiagnosticReportFile.swift) add an explicit filtered JSON share, with no automatic upload. | Report timestamps still disclose use times. Files are capped at 2 MiB, eight cached files, and cleanup after 24 hours on a later preparation; current sharing files are preserved. Cache age uses filename creation epochs, not filesystem timestamp APIs. Native receipt, off-device handling and the final distribution declarations remain unverified; this row updates the source inventory without changing the November 2 review history. |
| Optional support intake | [Support](../SUPPORT.md) asks for a description first. Email received outside the app includes the sender, message and any chosen attachments; [the intake procedure](PRIVATE_SUPPORT_PLAN.md) separates private reports from public issues. | The owner chose descriptions and optional cropped screenshots for the public pilot, without requiring journals. This still involves contact/message data; final App Store privacy answers remain incomplete. Native attachments and general tester export remain unverified. |

Apple excludes data processed solely on-device from its collection answers, but
off-device support intake needs separate assessment. Optional disclosure requires
all applicable criteria; voluntary email alone does not establish an exemption.
[App privacy guidance](https://developer.apple.com/app-store/app-privacy-details/).

### Privacy decisions before broader distribution

- **Known:** class state, preferences and journals stay on the Watch unless copied
  separately. The owner-pilot implementation adds explicit filtered-file sharing
  but no upload service; its native delivery is unverified. Support email
  retains the sender, message and chosen attachments as described in
  [the policy](PRIVACY.md).
- [ ] **Assess the label separately:** an empty manifest collection array is not
  an App Store answer. Apple excludes solely on-device processing; evaluate actual
  support intake separately under its [collection definition](https://developer.apple.com/app-store/app-privacy-details/).
- [x] **Initial intake scope chosen:** descriptions and optional cropped
  screenshots, without requiring unavailable journal export. This still involves
  email/contact information; it does not establish “no data collected.”
- [ ] **Before requesting optional diagnostics:** assess the actual fields,
  purposes, identity links and retention. Voluntary submission alone does not meet
  Apple's [optional-disclosure criteria](https://developer.apple.com/app-store/app-privacy-details/#optional-disclosure),
  including its in-app identified-submitter and per-submission requirements.
- [x] **External beta review submitted:** the owner saved review-contact details;
  concise runtime-use and limitation notes accompanied the first build-37
  submission. The public invitation now offers joining instructions; neither that
  nor Beta App Review establishes intended-use guidance for runtime renewal.
- [ ] **Before App Store submission:** owner approves privacy answers against the
  final binary and chosen intake practice; resolve uncertain classifications with
  Apple. This checklist records no account answers or legal determination.

## November 2 candidate checkpoints

Build 37 at clean source `a36f3be587825e27b424cf54355ea13afdfded83` passed signed
external-eligible archive/export and local checks (13 Swift suites / 130 Python
tests). Upload completed November 2 at 19:56:05 PST; Apple processed it without
Internal Only restriction. It is assigned only to Public beta and submitted for
first Beta App Review, then Waiting for Review. Watch CI and CodeQL pass.
The app's behavior is unchanged
from 36; build number and export eligibility differ. No Watch install was performed.
App Store privacy-label form answers have not been completed.

The following paragraphs retain earlier candidate checkpoints.

Build 36 changes privacy disclosure only. Its clean signed export, CI, Apple
processing, exact notes and owner-pilot assignment are verified. It is available
for the authorized automatic-update test; build 35 remains the last confirmed
physical Beta. See [current verification](../DEVELOPMENT_STATUS.md) and the
[artifact ledger](TESTFLIGHT_PREPARATION.md#build-36) for release evidence.

Build 35 replaces the bundled policy's relative support path with actual in-app
navigation directions. Behavior is unchanged from build 34. The clean source's
signed export, CI, Apple processing, notes and owner-pilot assignment are verified;
[the gallery](V1_READINESS_REVIEW.md#build-35-static-layout-matrix) records five-size
layout and bounded dim/wake/count evidence. Subsequent tooling passes 128 Python
tests, separately from the signed candidate's 117-test source checkpoint. The
subsequent [physical owner pilot](TESTFLIGHT_PILOT_RESULTS.md) verifies initial
Beta installation/update, saved state/relaunch and limited developer-tool journal
retrieval. Cleanup and development-app preservation checks are documented with
normal stale-class retirement and missing pre-install preferences qualified.
Earlier release-stage limits below describe their original checkpoints.

Build 34 adds a stable schedule anchor to the narrow display normalization.
Bounded clock/count integration and 21 app UI-action assertions pass. Clean
source `ee054de666c3` passed signed export, CI, upload and Apple processing;
build notes and one-owner manual-pilot assignment survived reload. Physical
installation, teaching validation and the final owner/review decisions remain open.

Build 33 adds narrow display normalization for the exact-Date boundary mechanism
reproduced in the clock probe. Its bounded normalized comparison and full-app UI
checks pass; signed export, Apple processing and owner-pilot assignment are
complete. Build notes and assignment survived reload. Physical validation remains open.

Build 32 adds queued explicit-Start readiness and artifact privacy-manifest checks.
Its clean signed archive/export, Apple processing and manual owner-pilot assignment
are complete. Build notes and assignment survived reload.

Build 31's scene-readiness guard passes one matched Simulator automatic recovery
comparison, all 12 Swift suites and 107 Python tests; physical behavior remains unverified.
Build 30 adds private support and
accessible Settings navigation to build 29, which fixed explicit Start and
schedule-retirement races. Build 25, including settings and bounded media
wake refresh, is installed as the development identity `com.qayshp.TeachingTimer`.
Build 25 received positive classroom Settings/volume feedback on October 31;
song progress still stalled and recovered by switching pages. Build 27 adds
Help/Privacy/About under Settings. Those pages are now present in the separately
installed physical Beta; the development teaching app remains build 25. See the
[owner-pilot results](TESTFLIGHT_PILOT_RESULTS.md) for the tested scope.

- **Screenshot set:** the [build-35 five-size gallery](V1_READINESS_REVIEW.md#build-35-static-layout-matrix) includes original captures and hashes. The historical [Settings-era teaching face](images/settings-25/se3-face.png)
  was captured on the SE 3 Simulator during build-25 verification.
  The [setup screenshots](USABILITY_PASS_22.md) show the retained interface on
  SE 3 and Ultra. These are development evidence, not approved store assets;
  the face includes the Simulator's disconnected-phone indicator.
- **Privacy review:** [Privacy](PRIVACY.md) describes local journals and voluntary
  support email. The information pages do not add automatic collection and
  provide the full privacy policy and MPL license offline in Settings.
  Final App Store declarations still require review against the distribution binary.
- **Support:** GitHub issues are suitable for sanitized bug descriptions only.
  Incoming and outgoing plain email through the private support alias were
  verified November 2. Native Watch/diagnostic attachment delivery and tester-facing
  journal export remain unverified. Review contact is now saved. Do not ask
  testers to attach raw journals publicly.
- **Saved Test Information:** beta description/known limitations, support address,
  repository and privacy URLs were saved and verified after reload. No custom
  EULA was added; the app requires no sign-in. All four review-contact fields were
  owner-supplied, saved and verified before the first external submission.
- **Public pilot limits:** the description/screenshot intake option is chosen;
  ordinary tester journal export is not promised. Teaching behavior and broader
  reliability remain to be evaluated. The owner install/update/relaunch and
  developer-tool journal checks do not establish those broader results.

## Bundled asset provenance

The three website QR images regenerated byte-for-byte on the November 2 Mac
toolchain. The icon renderer subsequently changed to use the selected
rolled-mat/timer artwork with Beta/Dev badges. Both generators and their inputs
are tracked and MPL-noticed; the build checks verify the packaged assets.

| Bundled asset | Source and verification |
| --- | --- |
| [App icon variants](../TeachingTimer/Assets.xcassets/) | [Rolled-mat and timer artwork](design/icon-drafts/mat-timer.png), rendered by [the icon script](../scripts/render-icon.swift). Release uses the unbadged `AppIcon`; local Debug uses `AppIconDev`; TestFlight uses `AppIconBeta`. |
| Privacy, source and support QR images | [QR generator](../scripts/information-qr.swift) uses [WebLinks.json](../TeachingTimer/Information/WebLinks.json). Regenerated images match and decode to the configured URLs. Physical camera scanning is still unverified. |

The [concept record](design/icon-drafts/README.md) retains all three generated
yoga alternatives. The current renderer depends on the selected mat-timer PNG;
the seated-figure and lotus drafts are not build inputs. This establishes
technical provenance, not an independent rights determination for every image
in the repository.

For the final store screenshot set, retain each selected capture's app revision,
build, OS, Watch size, original file/hash and any crop or composition. Historical
investigation screenshots remain dated evidence; do not silently relabel them
as current release captures.

## Runtime-use briefing for Apple — not submitted

Teaching Timer is a standalone Watch clock for a yoga **teacher**, with wall-clock
hands, scheduled class progress, brief optional vibration counts and Apple's
native media controls. It has no audio playback engine, workout session or
HealthKit data collection.

The saved class schedule is separate from its mindfulness extended-runtime
session. Classes last 60 or 75 minutes; a class retires 30 minutes after its
scheduled end. Stopping the runtime retains class timing.

The prototype currently attempts automatic runtime replacement only after the
old session's invalidation is confirmed, and only when native application and
SwiftUI scene state are active. After an expiration warning, it can invalidate
the old session during the final 20 seconds and then attempt replacement.
An explicit-renewal policy exists in code, but there is no user-facing policy
switch. Manual Start/Resume session remains available. Renewal and 1 Hz wrist-down updates
are not guaranteed.

[Apple's extended-runtime guidance](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions)
describes mindfulness as silent meditation, with frontmost execution and a
one-hour limit, and says the category must match intended use. Guidance is pending:

1. Does this teacher-facing timing use qualify for mindfulness? If not, which
   public API is appropriate without inventing a workout or background audio?
2. Is automatic replacement for a continuing class permitted, including the
   described expiration handoff, or should each additional session require an
   explicit user action?

This is a factual inquiry draft, not approval or justification for bypassing
runtime limits. No request or appointment has been submitted from this brief.
