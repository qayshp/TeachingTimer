# Distribution metadata draft

Updated November 2, 2026. The App Store Connect record **Teaching Timer Beta**
has build 31 Ready to Test / Internal and available to the one-tester Maintainer
pilot. Build 29 is also assigned; build 30 is processed but unassigned. Distribution
remains manual. This is the metadata review packet
for the private pilot, not a completed store submission or external invitation.

| Field | Draft |
| --- | --- |
| App Store Connect name | Teaching Timer Beta; Teaching Timer was unavailable |
| Subtitle | A clock for teaching yoga |
| Version / development candidate | 1.0 / 31 at clean source 9da154876eeb; processed and assigned to the owner pilot alongside 29; 30 unassigned |
| App Store Connect bundle identifier | net.qays.TeachingTimer |
| Watch payload identifier | net.qays.TeachingTimer.watchkitapp |
| Keywords | yoga,teacher,clock,timer,class,landmarks,mindfulness |
| Support URL | https://github.com/qayshp/TeachingTimer/blob/main/SUPPORT.md |
| Privacy information | https://github.com/qayshp/TeachingTimer/blob/main/docs/PRIVACY.md |
| License | MPL-2.0 |

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

## Before a pilot or store submission

- Confirm account/team, private support/review contact, category,
  age-rating questionnaire and applicable export answers. Do not
  invent contact details or mark declarations complete from this draft.
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
- Complete the install/update and journal-access pilot in
  [TestFlight preparation](TESTFLIGHT_PREPARATION.md). Build 31 passed clean signed
  archive/export, upload and processing and is assigned to the owner pilot.
  It also passes the bounded Simulator comparison, 12 Swift suites and 107 Python tests.
  Neither source work nor processing establishes physical installation or journal access.

## Current candidate review

Build 31's scene-readiness guard passes one matched Simulator automatic recovery
comparison, all 12 Swift suites and 107 Python tests; physical behavior remains unverified.
Build 30 adds private support and
accessible Settings navigation to build 29, which fixed explicit Start and
schedule-retirement races. Build 25, including settings and bounded media
wake refresh, is installed as the development identity `com.qayshp.TeachingTimer`.
Build 25 received positive classroom Settings/volume feedback on October 31;
song progress still stalled and recovered by switching pages. Build 27 adds
Help/Privacy/About under Settings; that addition has not been installed on the
physical Watch. Build 31 is Ready to Test / Internal in App Store Connect and
assigned to the owner pilot alongside 29; build 30 remains unassigned. No TestFlight
installation has been verified.

- **Screenshot set:** the [Settings-era teaching face](images/settings-25/se3-face.png)
  was captured on the SE 3 Simulator during build-25 verification.
  The [setup screenshots](USABILITY_PASS_22.md) show the retained interface on
  SE 3 and Ultra. These are development evidence, not approved store assets;
  the face includes the Simulator's disconnected-phone indicator.
- **Privacy review:** [Privacy](PRIVACY.md) describes local journals and voluntary
  support email. The information pages do not add automatic collection and
  provide the full privacy policy and MPL license offline in Settings.
  Final App Store declarations still require review against the distribution binary.
- **Support:** GitHub issues are suitable for sanitized bug descriptions only.
  A private support alias has verified inbound delivery; outbound replies and
  tester-facing journal export remain unverified. The review contact is pending. Do not ask testers to attach raw journals publicly.
- **Saved Test Information:** beta description/known limitations, support address,
  repository and privacy URLs were saved and verified after reload. No custom
  EULA was added; the app requires no sign-in. Review contact remains blank.
- **Wider pilot gates:** verify separate-identity state handling, install/update,
  journal retrieval and support handling before inviting additional testers.
  The current owner-only invitation does not establish those results.
