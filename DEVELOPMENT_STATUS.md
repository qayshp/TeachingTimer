# Teaching Timer — current verification

Updated November 2, 2026, retaining the October 31 classroom report. This is the authority for current build and validation
status. Dated investigations describe their original builds, not current behavior.

| Item | Status |
| --- | --- |
| Source candidate | 1.0 (28): separate Watch-only TestFlight packaging and checked internal-only export tooling. Teaching behavior remains the build-27 source baseline. |
| Installed physical Watch | 1.0 (25), installed, independently version-verified and launched October 30. |
| Latest classroom evidence | October 31, last confirmed installed build 25: Settings disabled vibrations and enabled time remaining; volume worked; no new bugs reported. Song progress still became stale and recovered after page switching. User observation, not a fresh device query or journal pull. |
| Preserved rollback | Build 16 signed local checkpoint. It has known intermittent media/volume issues; it is not a guarantee of reliability. |
| Distribution | No TestFlight upload or public release. Packaged archive signs locally; distribution export is blocked by Apple’s pending Program License Agreement. Store container: `net.qays.TeachingTimer`; Watch payload: `net.qays.TeachingTimer.watchkitapp`; development: `com.qayshp.TeachingTimer`. |

## Current behavior and limits

- Two pages: squircle teaching clock and native Now Playing. Both clock hands
  remain wall-clock hands drawn above controls.
- Settings is available before and during class: Count vibrations (next count)
  and Minutes left. Preferences persist. Build 27 adds read-only Help, Privacy and
  About destinations, including the running version/build, complete offline
  policy/license and website addresses/QR codes. See [Settings screenshots and verification](docs/SETTINGS_PASS_25.md).
- Native media refreshes on page entry, eligible background return, and active,
  undimmed wake after at least 30 seconds dimmed with a 60-second refresh cooldown.
  This is prevention, not failure detection. [Policy](docs/MEDIA_WAKE_REFRESH.md).
- Persistent class timing, runtime intent and monotonic counts remain independent.
  Intentional Stop survives reopening; a rejected recovery exposes Resume.
- Build 25 Settings has positive classroom validation on October 31. The progress
  freeze still recurred; the wake-refresh mitigation is not established as a fix.
  Actual trigger eligibility at that recurrence is unknown without fresh journals.
  A returned focus callback alone remains insufficient proof of physical effects.

## Open priorities

1. Incorrect native song progress with working Pause/volume: [incident](docs/MEDIA_PROGRESS_INCIDENT_2026-10-30.md), Apple FB25379883, [issue #8](https://github.com/qayshp/TeachingTimer/issues/8).
2. Intermittent blank native media, timer Crown response and unintended silencing:
   separate tracked defects, not established manifestations of one cause.
3. Automatic runtime recovery after dimmed Simulator relaunch: manual-recovery
   intent was retained after watchOS rejected start. Physical reproduction pending.
4. Seconds-hand backstep at dim/wake: separate Apple report; no speculative time correction.
5. TestFlight journal access/private support, signed pilot, and publishing metadata.

See the [issue map](docs/ISSUE_TRACKER.md), [Apple receipts](docs/APPLE_FEEDBACK.md),
[roadmap](docs/ROADMAP.md), and [publishing readiness](docs/PUBLISHING_READINESS.md).

## Verification and deployment boundaries

Build 28 passes all 12 Swift suites and 95 Python tests, including rejection of
incorrect/development distribution profiles and wrong package identities.
The packaged unsigned archive and distribution-identity Watch Simulator build
pass. A simulated 27→28 update (two build numbers of the same candidate source)
preserves the exact class timing and intentional Stop without restarting runtime;
the separate development app’s preferences and other files remain unchanged. Its
runtime journal records two scene transitions when Beta opens. The Simulator
moves the Beta container directory during the update without losing saved data. This is
an update rehearsal, not TestFlight delivery or physical journal-access proof.
The signed packaged archive passes local signature/resource/symbol checks, but
Apple’s agreement gate prevents an App Store distribution export. No physical
app was installed, launched or removed. The [private intake plan](docs/PRIVATE_SUPPORT_PLAN.md)
awaits the approved address and a delivery test. [Pilot procedure](docs/TESTFLIGHT_PREPARATION.md).

The following remains the prior build-27 UI validation:

Build 27 passes 12 Swift suites, 87 Python tests, repository validation, Simulator
compilation and unsigned development/distribution archive rehearsals on Xcode
27.2. All 21 SE 3/watchOS 27.2 action assertions pass, including Help/Privacy/About
before and during class, native Back, unchanged saved timing/runtime start-stop
intent, and the retained teaching action flow. A separate 16-assertion nested-page
check verified full policy/license rendering, navigation/Back and all three QR
addresses decoded from actual SE 3 screenshots. The [prior build-26 runtime run](docs/RUNTIME_27_2_VALIDATION.md)
remains dated evidence. No physical installation or paired playback test was
performed for build 27.
The [supervised device-test plan](docs/PHYSICAL_MEDIA_TEST_PLAN.md) is a proposal;
no unattended run is scheduled.

October 30 collection is complete: three journals and both sysdiagnoses validated.
The Watch archive is 150,136,890 bytes with 582 system-log files. Unlocking and
launching succeeded while it remained on the charger through Device Hub's virtual
Crown/passcode interaction. Removing it from the charger was not required.
Transfer completion, screen sharing, installation and launch are distinct outcomes.

## Historical evidence

[Verification through build 25](docs/history/VERIFICATION_THROUGH_BUILD_25.md)
preserves earlier test results and deployment chronology.
[October 29 repository review](docs/REPOSITORY_REVIEW_2026-10-29.md) records the
12-suite/80-test verification and earlier interactive runs. Historical passes do
not close intermittent physical bugs. The latest physical build is stated above.
