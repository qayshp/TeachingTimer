# Publishing readiness

Reviewed October 31, 2026. Preparation only: no registration, upload, invitation or
release. [Current verification](../DEVELOPMENT_STATUS.md) owns build/install status.

## New user entry points

- [README](../README.md): what the app does, how to obtain/build it, known limits.
- [First-class guide](TESTER_GUIDE.md): setup, controls, recovery, between classes.
- [Privacy](PRIVACY.md): local data, optional sharing, unresolved beta export access.
- [Issues](ISSUE_TRACKER.md): distinct symptoms, workarounds and Apple reports.
- [Contributing](../CONTRIBUTING.md): code layout, checks and device boundaries.

There is no public beta link. Do not ask a new user to infer installation or
support procedures from historical engineering notes.

## Release gates

| Gate | Evidence / next action |
| --- | --- |
| Names and identifiers | Teaching Timer; `net.qays.TeachingTimer` for distribution. `com.qayshp.TeachingTimer` remains the separate teaching/development installation. Name availability/registration not confirmed. |
| Build integrity | Rehearse unsigned development and distribution archives with `scripts/verify-build.py`. This does not establish signing or store acceptance. |
| Paid-team signing / App Store Connect | Confirm team, register identifier, create record, validate signed archive and upload when explicitly requested. |
| Private tester support | Confirm a private contact before invitations. Public issues must not receive raw logs. No contact address is invented here. |
| Journal export/access | Development container copies work intermittently. TestFlight container access and a tester-friendly export path remain unresolved. |
| Install/update pilot | Check separate container, cold start, update, state preservation, runtime intent and recovery on a physical Watch. |
| Teaching reliability | Build 25 Settings/volume received positive October 31 class feedback; progress still froze and was recovered by swiping. Validate the release candidate and mitigation limits. Prioritize progress, blank media, Crown recovery and silencing. See supervised plan. |
| Accessibility/form factors | Repeat current candidate UI checks on small/large screens. Physical VoiceOver, touch while teaching and Always-On remain separate gates. |
| Store materials | Review metadata/privacy/export/age-rating answers against the final binary. Prepare screenshots without Simulator artifacts and confirm asset provenance. |

[Metadata draft](DISTRIBUTION_METADATA.md) and [TestFlight procedure](TESTFLIGHT_PREPARATION.md)
contain details. Keep the validated teaching installation available during the
pilot. Shipping and asking for a coordinated hardware session are separate decisions.

## Testing priorities

Start with the [supervised media plan](PHYSICAL_MEDIA_TEST_PLAN.md). Seek a small
repeatable failure and useful Apple evidence before adding more recovery policy.
An overnight run is conditional on that rehearsal, a bounded script and available
devices. None is scheduled by this document.

## Path to a true v1

The October 31 class report supports freezing the current product scope as a
release candidate. Settings, visual-only counting/time remaining and volume
worked for the maintainer; song progress remains a known recoverable defect.
This is firsthand feedback, not proof that the earlier silencing/focus bugs are
fixed or that automatic wake refresh prevented every recurrence.

1. **Freeze scope and acceptance criteria.** Keep the current clock, schedule,
   counts, Settings and native media. Block release on crashes, lost class state,
   unrecoverable runtime/volume failure, or reproduced unexpected silencing in the
   candidate. Treat recoverable progress stalling as an explicitly documented
   candidate limitation, subject to beta feedback. Do not require Apple to fix
   every reported defect or add unrelated teaching features.
2. **Resolve extended-runtime intended use early.** Apple's mindfulness category
   describes silent meditation and a one-hour time limit; category choice must
   follow intended use. Explain the actual yoga-instruction workflow and renewal
   policy accurately in a developer support/review inquiry. Acceptance is not
   established. Do not silently switch to HealthKit, use artificial background
   audio or disguise the purpose. A runtime-policy decision may be necessary.
3. **Add a small Help/About/Privacy surface.** Explain hands/marker, class versus
   session, count/vibration semantics, and page-swipe media recovery outside the
   teaching face. Show version/build, source/license, policy and support links.
   The repository privacy page and manifest do not supply the required in-app
   privacy-policy link. A full tutorial is not necessary.
4. **Run the release matrix.** Confirm physical fresh launch, Home/return,
   intentional Stop, force-close class recovery, settings persistence and class
   replacement. Exercise normal phone playback and relevant wired/AirPlay routes
   at modest volume. Complete one teaching-length runtime/renewal/battery run.
   Repeat small/large/current Simulator and accessibility checks. The deployment
   target is watchOS 26; validate that declared minimum in a deliberate
   compatibility test or adjust the support claim rather than assuming only
   watchOS 27.2 results cover it.
5. **Pilot the real distribution build.** Use `net.qays.TeachingTimer`, preserve
   the development install, sign/upload when authorized and install via TestFlight.
   Check install/update, separate-container state and journal/support access.
   Begin with the maintainer, then a small external teacher group. External beta
   review is an opportunity to expose runtime-use questions, not a guarantee of
   final store acceptance.
6. **Finish release materials and support.** Confirm private contact, name and
   price decision, final icon/screenshots, supported-device wording, privacy,
   export/age-rating answers, review instructions, tag and release notes. Use the
   actual signed candidate and store-supported toolchain. Do not advertise
   guaranteed media progress, haptic timing or 1 Hz on every Watch.

A successful self-pilot plus several real classes by a few new users is a useful
release criterion, not an Apple requirement or a substitute for the matrix.
No app feature, registration, upload, device action or external message was
performed while recording this plan.

References: [runtime categories](https://developer.apple.com/documentation/WatchKit/using-extended-runtime-sessions),
[review guidelines](https://developer.apple.com/app-store/review/guidelines/),
[TestFlight](https://developer.apple.com/testflight/).
