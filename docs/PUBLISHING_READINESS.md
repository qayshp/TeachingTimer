# Publishing readiness

Updated November 13, 2026; public invitation last checked November 5. The
[public invitation](https://testflight.apple.com/join/YA2WSmae) now offers
**View in TestFlight** and joining instructions. The public group was initially
configured with a 100-tester cap. Exact eligible-build membership and a new
external tester's installation remain to be verified; the public page does not
identify its build number. Automatic internal releases now use GitHub Actions.
[Current verification](../DEVELOPMENT_STATUS.md) owns the latest uploaded and
owner-reported installed builds, separately from this release checklist.

Physical installation/update/relaunch and limited Beta
journal access passed in the [owner pilot](TESTFLIGHT_PILOT_RESULTS.md). Cleanup
and development-app preservation checks are documented with their limits.
Wider teaching tests and App Store release remain pending. The
[artifact ledger](TESTFLIGHT_PREPARATION.md#subsequent-pilot-builds)
records exact revisions and checks.

## New user entry points

- [README](../README.md): what the app does, how to obtain/build it, known limits.
- [First-class guide](TESTER_GUIDE.md): setup, controls, recovery, between classes.
- [Privacy](PRIVACY.md): local data and optional companion sharing.
- [Issues](ISSUE_TRACKER.md): distinct symptoms, workarounds and Apple reports.
- [Contributing](../CONTRIBUTING.md): code layout, checks and device boundaries.

The public link is in README and the tester guide with current availability
and installation instructions. A new user should not need historical engineering
notes to learn installation or support procedures.

## Release gates

| Gate | Evidence / next action |
| --- | --- |
| Names and identifiers | App Store Connect record **Teaching Timer Beta** created for `net.qays.TeachingTimer`; Teaching Timer was unavailable. Its Watch payload is `net.qays.TeachingTimer.watchkitapp`. `com.qayshp.TeachingTimer` remains the separate teaching/development installation. Distribution provisioning succeeded. |
| Build integrity | Build 37 at clean source `a36f3be587825e27b424cf54355ea13afdfded83` passes signed external-eligible archive/export and 13 Swift suites / 130 Python tests. Watch CI and CodeQL pass. Apple processed the upload completed at 19:56:05 PST. App behavior is unchanged from 36. Earlier build-36 Privacy rendering, build-35 layout/controls and build-34 clock results retain their original scope. Processing is not a physical test. |
| Paid-team signing / App Store Connect | The public invitation now offers joining instructions. Exact external build membership and first external installation remain unverified. Review-contact fields and actual runtime-use notes were saved with build 37. Automatic internal releases verify processing and Maintainer assignment; server readiness does not prove Watch installation. |
| Private tester support | [Private email support](../SUPPORT.md) is configured; incoming and outgoing plain email were verified November 2. The public pilot accepts descriptions and optional cropped screenshots without requiring journals. Phone-requested and Watch-initiated companion reports have reached support; startup, retry and upgrade reliability remain under validation. See the [intake plan](PRIVATE_SUPPORT_PLAN.md); public issues must not receive raw logs. |
| Journal export/access | All three TestFlight Beta journals copied and parsed in the owner’s developer-enabled SE 3/trusted-Mac setup. A filtered in-app report and optional iPhone email/export route are implemented, with two verified physical deliveries. General tester access and retry, interruption and upgrade reliability remain open; see [companion validation](OPTIONAL_COMPANION.md). |
| Install/update pilot | TestFlight installation/update, saved class/settings, intentional Stop and running-intent relaunch passed on one physical SE 3. Cleanup and development-app preservation were checked; the original stale class retired normally and pre-install preference bytes were unavailable. See [dated results](TESTFLIGHT_PILOT_RESULTS.md). |
| Teaching reliability | Build 25 Settings/volume received positive October 31 class feedback. The November 2 [Beta 35 supervised test](MEDIA_PROGRESS_INCIDENT_2026-11-02.md) passes timer Crown checks on iPhone-speaker playback, but media entry updates a position snapshot without reliably restoring live progress. Broader audio routes and a teaching-length candidate run remain unverified. |
| Accessibility/form factors | Build 35 has a reviewed [five-size static matrix](V1_READINESS_REVIEW.md#build-35-static-layout-matrix), small/large maximum-text Settings and bounded state-confirmed dim/wake controls checks. Physical VoiceOver, touch while teaching and Always-On remain separate gates. |
| Store materials | Shipping icon/QR technical provenance is verified in the [asset record](DISTRIBUTION_METADATA.md#bundled-asset-provenance). Beta review metadata was submitted; the App Store privacy-label form remains incomplete. Review remaining store/privacy/export/age-rating answers against the final binary and prepare a final screenshot set with capture provenance. |

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
worked for the maintainer; song progress remains an unresolved defect. The
November 2 Beta 35 test shows that swiping can refresh a position snapshot without
restoring live progress, so recovery must not be assumed.
This is firsthand feedback, not proof that the earlier silencing/focus bugs are
fixed or that automatic wake refresh prevented every recurrence.

1. **Freeze scope and acceptance criteria.** Keep the current clock, schedule,
   counts, Settings and native media. Block release on crashes, lost class state,
   unrecoverable runtime/volume failure, or reproduced unexpected silencing in the
   candidate. Treat progress stalling as a candidate limitation only with the
   maintainer's acceptance of its observed recovery limits and beta feedback.
   Do not require Apple to fix every reported defect or add unrelated teaching
   features.
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
   upload and processing; the public invitation now offers joining instructions.
   Check install/update, separate-container state and journal/support access.
   The owner pilot has completed its recorded checks and public-beta invitations
   are authorized. The first external installation remains to be checked. External beta
   review is an opportunity to expose runtime-use questions, not a guarantee of
   final store acceptance.
6. **Finish release materials and support.** Finalize support handling, the public
   release name and price, final icon/screenshots, supported-device wording, privacy,
   export/age-rating answers, review instructions, tag and release notes. Use the
   actual signed candidate and store-supported toolchain. Do not advertise
   guaranteed media progress, haptic timing or 1 Hz on every Watch.

A successful self-pilot plus several real classes by a few new users is a useful
release criterion, not an Apple requirement or a substitute for the matrix.
The separately authorized installation/update owner pilot is complete within
its stated limits. Preserve the development teaching installation. Public-beta
invitations are authorized and available; broader teaching tests
remain necessary and no App Store release is implied.

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
records each checkpoint. At that earlier stage the pilot was manual and owner-only. No TestFlight installation
or physical update occurred during the initial preparation; the subsequently
authorized [owner pilot](TESTFLIGHT_PILOT_RESULTS.md) records physical results. See [the pilot procedure and remaining gates](TESTFLIGHT_PREPARATION.md).
The [private intake procedure](PRIVATE_SUPPORT_PLAN.md) now has a configured
alias and verified incoming/outgoing plain email as of November 2. One physical
companion diagnostic email was verified November 11. Startup, first-composer,
update and interruption reliability remain under validation; see the
[companion record](OPTIONAL_COMPANION.md).
