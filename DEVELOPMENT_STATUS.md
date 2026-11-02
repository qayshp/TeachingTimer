# Teaching Timer — current verification

Updated November 2, 2026, retaining the October 31 classroom report. This is the authority for current build and validation
status. Dated investigations describe their original builds, not current behavior.

| Item | Status |
| --- | --- |
| Source candidate | 1.0 (35): bundled Privacy copy replaces a repository-relative support path with the actual Settings → About → Contact support route. App behavior is unchanged from build 34. Bundled policy rendering, the five-size static matrix and bounded dim/wake/count controls checks pass. Clean source `b5884e30dd8a` is assigned to the owner pilot. |
| Installed physical Watch | 1.0 (25), installed, independently version-verified and launched October 30. |
| Latest classroom evidence | October 31, last confirmed installed build 25: Settings disabled vibrations and enabled time remaining; volume worked; no new bugs reported. Song progress still became stale and recovered after page switching. User observation, not a fresh device query or journal pull. |
| Preserved rollback | Build 16 signed local checkpoint. It has known intermittent media/volume issues; it is not a guarantee of reliability. |
| Distribution | Build 35 (`b5884e30dd8a`) is Ready to Test / Internal and assigned to the Maintainer pilot with one tester, the owner. Builds 29, 31, 32, 33 and 34 are also assigned; build 30 is processed but unassigned. Distribution remains manual. No public release or verified physical Beta install. Store container: `net.qays.TeachingTimer`; Watch payload: `net.qays.TeachingTimer.watchkitapp`; development: `com.qayshp.TeachingTimer`. |

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
3. Automatic runtime recovery after dimmed Simulator relaunch: build 30 reproduces
   exact activation error code 3 on watchOS 27.2 and wake does not recover it.
   Class timing survives. Build 31 defers the premature start and recovers on a
   later active wake in one matched Simulator trial. Broader callback orderings
   and physical behavior remain unverified.
4. Seconds-hand backstep at dim/wake: separate precision and moving-anchor
   mechanisms are now captured in the probe. Build 34 combines the bounded
   mitigations and passes bounded app integration checks. Physical validation
   and the Apple follow-up remain pending.
5. Physical TestFlight install/update/journal access, outbound support reply and
   attachment checks, and final publishing/review metadata.

See the [issue map](docs/ISSUE_TRACKER.md), [Apple receipts](docs/APPLE_FEEDBACK.md),
[roadmap](docs/ROADMAP.md), and [publishing readiness](docs/PUBLISHING_READINESS.md).

## Verification and deployment boundaries

Build 35 changes only the bundled policy's support directions over build 34.
Clean source `b5884e30dd8ab04c956e629a5f0a5c7864b58c2b` passed signed
archive/export, actual Watch privacy-manifest checks,
[Watch CI](https://github.com/qayshp/TeachingTimer/actions/runs/41544098376)
(13 Swift suites / 117 Python tests) and
[CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/41544096984).
Upload completed November 2 at 15:32:23 PST. Apple shows Ready to Test / Internal;
notes and assignment survived reload, and the manual Maintainer pilot has one
owner and six assigned builds. See the [artifact ledger](docs/TESTFLIGHT_PREPARATION.md#subsequent-pilot-builds).

The clean Debug build's [five-size gallery](docs/V1_READINESS_REVIEW.md#build-35-static-layout-matrix)
includes small/large maximum-text Settings and the rendered policy directions.
A separate strengthened controls run observed all six requested dim/wake
transitions, sampled 33 frames and completed all six count groups near 64.816 s
with runtime/locked-state evidence. Subsequent tooling has 128 passing Python
tests; those additions are not part of the signed build's 117-test source
checkpoint. These checks do not establish physical haptic/audio delivery,
TestFlight installation/update or journal access. Physical build 25 was not
contacted or changed; its last confirmed state remains the historical record above.

Build 34's [anchor comparison](docs/ALWAYS_ON_HAND_TRANSITION.md#build-34-follow-up-stable-schedule-anchor)
keeps precision normalization enabled in both variants. Moving anchoring produced
two matched input/pixel backsteps; the fixed epoch produced none. Each was one
short recording with two confirmed dim/wake cycles. Future-batch returns remain
valid and are not clamped. The app compiles and passes all 21 UI-action assertions.
A 23.815-second runtime-active video has 764 analyzed frames with no ambiguous detections or
backward-tick candidates; original frames confirm sampled dim/wake transitions
and forward minute rollover. A locked count completed six groups at 64.82272075 s
with runtime running and scene inactive. Its control/arc captures were reviewed;
logged group completion does not prove physical haptic delivery. These bounded
results do not establish a physical fix. Clean source
`ee054de666c34274d3fe200d0f69d698c50c97b7` passed signed archive/export and
[CI](https://github.com/qayshp/TeachingTimer/actions/runs/41541943839), including
13 Swift suites and 117 Python tests. Upload completed November 2 at 15:02:59 PST;
Apple shows Ready to Test / Internal. Build notes and assignment survived reload;
at that checkpoint the manual Maintainer pilot had one tester and five assigned builds. Physical
build 25 remains untouched, and physical Beta checks remain open.

Build 33's [clock comparison](docs/ALWAYS_ON_HAND_TRANSITION.md#build-33-candidate--bounded-simulator-validation)
captures raw Dates one representable step below a whole second. The shared
display helper normalizes only the integer and its immediate neighbors; it
does not change the timeline schedule, raw saved timing, runtime, count or native
controls. The normalized probe corrected all 113 affected inputs among 234
evaluations; independent replay matched every record. No backward whole tick was
measured in 190 frames over 24.283 s. All 13 Swift suites, 117 Python tests and
21 full-app UI-action assertions pass. These bounded Simulator results do not
establish physical behavior or explain every historical jump. Clean source
`12772ccabb44b4bc93ce235f5bc94b3790c8d740` passed signed archive/export and
[CI](https://github.com/qayshp/TeachingTimer/actions/runs/41538777416).
Upload completed November 2 at 14:39:14 PST; Apple shows Ready to Test / Internal.
Build notes and one-owner Maintainer pilot assignment survived reload. Physical
build 25 remains untouched; TestFlight installation/update/journal checks remain open.

Build 32 extends the existing readiness guard to an explicit Start queued while
an old runtime invalidates. The new boundary-double tests exercise both
invalidation/readiness orders and cancellation through Stop, reset, replacement
or retirement. These are deterministic tests, including injected error paths,
not another observed WatchKit rejection in Simulator. Direct immediate Start,
native media/volume and count behavior are unchanged.

The added privacy-manifest validator checks the actual Watch app in archives
and exported IPAs against the reviewed declarations. The existing build-31
archive/export already passes: this closes a verification gap, not a discovered
shipped privacy defect. Build 32 passes all 12 Swift suites, 110 Python tests
and Simulator compilation. All 21 UI-action assertions pass; reviewed Help,
active-clock, Stop/Resume and native Not Playing captures show no visual
regression in those views. This is not paired-media or physical validation.
Clean source `f931c173ab86d6f27fda17083f4afc6163dc2b67` passed signed archive/export
and [CI](https://github.com/qayshp/TeachingTimer/actions/runs/41531683416).
Upload completed November 2 at 13:50:22 PST; Apple processing, build notes and
manual owner-pilot assignment were verified after reload. This completes
preparation and distribution to the owner pilot, not its physical install/update
or journal-access checks. Physical build 25 remains untouched.

Build 31 passes all 12 Swift suites, including scene/native readiness and early
handoff checks, 107 Python tests and the Debug Simulator build. In one matched inactive/dimmed
relaunch, automatic Start was deferred, running intent survived and a later
active wake produced a successful runtime-start callback without error. The
second trial had a different initial luminance state and is not a second matched
reproduction. Intentional Stop controls made no Start attempt. All 14 candidate
preference captures matched the baseline class bytes. The wake helper used Home/reopen,
causing real foreground-loss invalidations between two nonoverlapping starts;
this is not a claim of one total start or guaranteed recovery for arbitrary
callback ordering. See [the full comparison and limits](docs/RUNTIME_RECOVERY.md#build-31-candidate-comparison).
The clean build-31 signed archive/export passed, including the source-cleanliness
guard. Upload completed November 2 at 13:19:59 PST; Apple processed it as Ready
to Test / Internal. Its What to Test notes and assignment to the one-tester
Maintainer pilot were verified in App Store Connect. Physical TestFlight
installation/update, journal access and teaching validation remain unverified.

Build 30's clean revision `da9d8d6756f8` passed signed export and Apple processing.
Its multi-size and maximum-text UI evidence is recorded in the
[v1 review](docs/V1_READINESS_REVIEW.md#build-30-usability-follow-up). The TestFlight
beta description/known limitations, support address and repository/privacy URLs
were saved and verified after reload. Review contact remains blank; no custom
EULA or app sign-in is configured. Build-30 processing does not validate the
changed build-31 runtime behavior or a physical installation.

The build-29 [v1 review](docs/V1_READINESS_REVIEW.md) passes 12 Swift suites,
102 Python checks, app compilation and the full unsigned build/archive pipeline
(the final export-declaration metadata is checked again in its signed archive).
All ten SE 3 retirement assertions pass with reviewed screenshots. Native volume
and media implementation ordering is unchanged. A fresh build-28 baseline action
run passed all 21 assertions before those narrow changes.

The prior build 28 passed all 12 Swift suites and 95 Python tests, including rejection of
incorrect/development distribution profiles and wrong package identities.
The packaged unsigned archive and distribution-identity Watch Simulator build
pass. A simulated 27→28 update (two build numbers of the same candidate source)
preserves the exact class timing and intentional Stop without restarting runtime;
the separate development app’s preferences and other files remain unchanged. Its
runtime journal records two scene transitions when Beta opens. The Simulator
moves the Beta container directory during the update without losing saved data. This is
an update rehearsal, not TestFlight delivery or physical journal-access proof.
The signed packaged archive passes local signature/resource/symbol checks;
after the account holder accepted Apple’s agreement, the internal-only
App Store distribution export passed signature, profile and entitlement checks. No physical
app was installed, launched, queried or removed during this review. The [private intake plan](docs/PRIVATE_SUPPORT_PLAN.md)
has a configured alias and verified inbound test; outbound reply and native attachment delivery remain unverified. [Pilot procedure](docs/TESTFLIGHT_PREPARATION.md).

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
