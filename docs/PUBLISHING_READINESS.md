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
| Teaching reliability | Validate build 25's Settings and wake-refresh mitigation. Prioritize progress, blank media, Crown recovery and silencing. See supervised plan. |
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
