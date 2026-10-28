# Distribution metadata draft

Prepared October 28, 2026. Not submitted to App Store Connect. This is a review
packet for a private pilot, not authorization to invite external testers.

| Field | Draft |
| --- | --- |
| Name | Teaching Timer |
| Subtitle | A clock for teaching yoga |
| Version / candidate build | 1.0 / 22 |
| Future bundle identifier | net.qays.TeachingTimer |
| Keywords | yoga,teacher,clock,timer,class,landmarks,mindfulness |
| Support URL | https://github.com/qayshp/TeachingTimer/issues |
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

- Confirm the name's availability, account/team, private support/review contact,
  category, age-rating questionnaire and applicable export answers. Do not
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
- Complete the signed upload, install/update and journal-access pilot in
  [TestFlight preparation](TESTFLIGHT_PREPARATION.md). No upload, registration,
  tester invitation or physical installation is performed by these documents.
