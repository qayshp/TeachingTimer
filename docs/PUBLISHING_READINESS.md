# Publishing readiness

Reviewed November 2, 2026. The signed candidate is Ready to Test / Internal in
the manual-distribution, owner-only Maintainer pilot. Preparation, upload and
assignment are complete; physical installation/update, wider testing and public
release remain pending. [Current verification](../DEVELOPMENT_STATUS.md) owns
build/install status; the [artifact ledger](TESTFLIGHT_PREPARATION.md#subsequent-pilot-builds)
records exact revisions and checks.

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
| Names and identifiers | App Store Connect record **Teaching Timer Beta** created for `net.qays.TeachingTimer`; Teaching Timer was unavailable. Its Watch payload is `net.qays.TeachingTimer.watchkitapp`. `com.qayshp.TeachingTimer` remains the separate teaching/development installation. Distribution provisioning succeeded. |
| Build integrity | Build 35 at clean source `b5884e30dd8a` passes signed archive/export with actual Watch privacy-manifest checks, Watch CI (13 Swift suites / 117 Python tests), CodeQL and Apple processing. Clean Debug layout and bounded controls checks pass; build 34 owns the preceding clock integration evidence. Later tooling passes 128 Python tests. Processing is not a physical test. |
| Paid-team signing / App Store Connect | Owner-only manual pilot assignment is verified; see [current status](../DEVELOPMENT_STATUS.md) for assigned builds. Beta Test Information, build-35 What to Test notes and assignment are saved/verified after reload; review contact remains blank. Complete the physical self-pilot when authorized and available. |
| Private tester support | [Private email support](../SUPPORT.md) is configured and inbound delivery is verified. Outbound alias replies and diagnostic attachment delivery remain untested. An email address does not export Watch journals. See the [intake plan](PRIVATE_SUPPORT_PLAN.md); public issues must not receive raw logs. |
| Journal export/access | Development container copies work intermittently. TestFlight container access and a tester-friendly export path remain unresolved. |
| Install/update pilot | Check separate container, cold start, update, state preservation, runtime intent and recovery on a physical Watch. |
| Teaching reliability | Build 25 Settings/volume received positive October 31 class feedback; progress still froze and was recovered by swiping. Validate the release candidate and mitigation limits. Prioritize progress, blank media, Crown recovery and silencing. See supervised plan. |
| Accessibility/form factors | Build 35 has a reviewed [five-size static matrix](V1_READINESS_REVIEW.md#build-35-static-layout-matrix), small/large maximum-text Settings and bounded state-confirmed dim/wake controls checks. Physical VoiceOver, touch while teaching and Always-On remain separate gates. |
| Store materials | Shipping icon/QR technical provenance is verified in the [asset record](DISTRIBUTION_METADATA.md#bundled-asset-provenance). Review metadata/privacy/export/age-rating answers against the final binary and prepare a final screenshot set with capture provenance. |

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
3. **Help/About/Privacy added in build 27.** Settings contains offline explanations
   of hands/marker, class versus session, counts, media recovery and local data,
   plus the running version/build, complete bundled policy/license and website
   addresses/QR codes. Verify camera scanning from the physical display during
   the pilot; image decoding in Simulator is not a physical camera test. The private
   support inbox now receives reports; final metadata/privacy review remains outstanding.
4. **Run the release matrix.** Confirm physical fresh launch, Home/return,
   intentional Stop, force-close class recovery, settings persistence and class
   replacement. Exercise normal phone playback and relevant wired/AirPlay routes
   at modest volume. Complete one teaching-length runtime/renewal/battery run.
   The current five-size Simulator matrix is complete; physical accessibility
   remains open. The deployment target is watchOS 26; validate that declared minimum in a deliberate
   compatibility test or adjust the support claim rather than assuming only
   watchOS 27.2 results cover it.
5. **Pilot the real distribution build.** Use `net.qays.TeachingTimer`, preserve
   the development install and install via TestFlight when the Watch is available
   and installation is authorized. The current candidate has passed signed archive/export,
   upload and processing and is available to the owner pilot.
   Check install/update, separate-container state and journal/support access.
   Begin with the maintainer, then a small external teacher group. External beta
   review is an opportunity to expose runtime-use questions, not a guarantee of
   final store acceptance.
6. **Finish release materials and support.** Finalize support handling, the public
   release name and price, final icon/screenshots, supported-device wording, privacy,
   export/age-rating answers, review instructions, tag and release notes. Use the
   actual signed candidate and store-supported toolchain. Do not advertise
   guaranteed media progress, haptic timing or 1 Hz on every Watch.

A successful self-pilot plus several real classes by a few new users is a useful
release criterion, not an Apple requirement or a substitute for the matrix.
The self-pilot may proceed when its gates pass. Preserve the current physical
teaching installation; it is not part of the authorized distribution work.

References: [runtime categories](https://developer.apple.com/documentation/WatchKit/using-extended-runtime-sessions),
[review guidelines](https://developer.apple.com/app-store/review/guidelines/),
[TestFlight](https://developer.apple.com/testflight/).

## November 2 pilot preparation

Build 28 adds Apple's Watch-only distribution container, a separate TestFlight
scheme/configuration, and checks for the signed internal-only export. Packaging
resolved the bare Watch archive's export-method rejection. The account holder
then accepted the updated developer agreement, resolving Apple's **PLA Update
available** provisioning gate. The internal-only build-28 IPA exported
successfully and passed local package, profile, signature and entitlement checks.
That build-28 export was not uploaded. Subsequent clean candidates were uploaded
and processed successfully; the [artifact ledger](TESTFLIGHT_PREPARATION.md#subsequent-pilot-builds)
records each checkpoint. The pilot remains manual and owner-only. No TestFlight installation
or physical update has occurred during this preparation. See [the pilot procedure and remaining gates](TESTFLIGHT_PREPARATION.md).
The [private intake procedure](PRIVATE_SUPPORT_PLAN.md) now has a configured
alias and verified inbound delivery. Outbound reply and diagnostic attachment
delivery remain pending. These are
release gates, not completed tests.
