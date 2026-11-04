# Teaching Timer — current status

Updated November 3, 2026. This page owns current build and validation status.
See the [changelog](CHANGELOG.md) for user-visible changes and the
[roadmap](docs/ROADMAP.md) for prioritized work.

| Artifact | Current evidence |
| --- | --- |
| Layout pilot | **1.0 (41)**, clean signed source `30df065a33e8` on `codex/aligned-squircle-dial`: full-screen dial with all 60 ticks restored behind translucent top elements. All 13 Swift suites / 132 Python tests, Simulator/archive checks, six focus checks and thirteen five-size captures pass. Signed export/upload, Apple processing, saved test notes and assignment to the one-owner **Maintainer pilot** are verified: **Testing / Internal**. [Layout comparison](docs/FORM_FACTOR_VALIDATION.md#november-3-build-41-layered-header-ticks) · [release record](docs/TESTFLIGHT_PREPARATION.md#build-41-maintainer-layout-pilot). Installation is unconfirmed; no direct physical-device action was performed. |
| Owner media experiment | **1.0 (38)**, clean signed source `57fde699e424`. Upload succeeded November 2 at 23:09:35 PST; Apple processing was verified November 3. It remains unassigned to tester groups. Intended comparison is 37 versus 38; build 41 does not include this experiment. [Release record](docs/TESTFLIGHT_PREPARATION.md#build-38-owner-media-experiment). |
| Submitted beta | **1.0 (37)**, signed source `a36f3be587825`. App behavior is unchanged from 36; packaging adds external eligibility. Signed export, upload, Apple processing, 13 Swift suites / 130 Python tests, Watch CI and CodeQL pass. |
| Public invitation | [Join TestFlight](https://testflight.apple.com/join/YA2WSmae). Build 37 is **In Review**; approval remains pending. Initial limit: 100. Automatic tester notification is enabled. Build 41 is internal-only and is not assigned to this group. |
| Physical Watch | **Beta 35** is last confirmed by the user in the November 2 supervised test. Development build 25 was inventoried in the earlier owner pilot. Later beta installation is unconfirmed. No physical install accompanies this review. |
| Owner pilot | Install/update/relaunch, saved state, intentional Stop and all three journal copies passed within the [recorded limits](docs/TESTFLIGHT_PILOT_RESULTS.md). Internal Maintainer pilot now includes build 41; no new physical installation or teaching validation is established. |
| Rollback | Build 16 remains a preserved local checkpoint with its known media/volume issues. |

## What works and what remains uncertain

- Two pages: squircle teaching face and native Now Playing. Seconds and minutes
  are wall-clock hands; class schedule, runtime and count state are independent.
- Settings includes Count vibrations, Minutes left, and offline Help/Privacy/About.
  Class context and intentional runtime Stop survive process relaunch.
- **Latest class feedback, October 31 (development 25):** volume and Settings
  worked; song progress stalled and page switching recovered a useful position.
- **Latest supervised test, November 2 (Beta 35):** initial timer volume,
  media-return volume, Home/reopen and tap-refresh all worked audibly on the
  paired iPhone speaker. Embedded progress updated on entry then stalled;
  standalone Now Playing appeared to advance. Seeking updated the embedded
  indicator with an apparent, unmeasured offset.
- The user confirms eligible inactivity refresh updates song position. Neither
  that nor page reentry establishes continuously accurate progress.
- Blank media, Crown nonresponse, unexpected silencing, seconds-hand backsteps
  and developer-connection failures remain distinct [open issues](docs/ISSUE_TRACKER.md).
  Runtime/clock fixes have bounded Simulator evidence, not universal hardware proof.
- Mindfulness runtime suitability for guided yoga teaching and automatic renewal
  still needs explicit Apple guidance. Beta review does not settle intended use.

## Next validation

1. Isolate native media from the clock timeline and compare lifecycle behavior;
   real progress accuracy requires matched phone/Watch playback testing.
2. Obtain runtime guidance and finish teaching-length, route, battery and
   accessibility checks before a general release.
3. Verify an approved public invitation and first external install. Private email
   accepts descriptions and optional cropped screenshots; tester journal export
   is not implemented.

The [issue-linked roadmap](docs/ROADMAP.md) records acceptance criteria.
No supervised device session or unattended playback run is scheduled here.

## Evidence and release boundaries

- [November 2 physical media/Crown results](docs/MEDIA_PROGRESS_INCIDENT_2026-11-02.md)
- [Exact signed revision and release stages](docs/TESTFLIGHT_PREPARATION.md#build-37-public-beta-preparation)
- [Publishing gates](docs/PUBLISHING_READINESS.md) and [Apple feedback](docs/APPLE_FEEDBACK.md)
- [Historical checkpoints through build 37](docs/history/STATUS_THROUGH_BUILD_37.md)
- [Documentation index](docs/README.md)

Standalone Swift tests use test doubles; Python tests primarily verify tooling.
Simulator rendering/focus callbacks do not prove phone commands, audible volume,
haptic delivery or teaching-length reliability. Review submission is not approval;
build success is not an install. Store identifiers are `net.qays.TeachingTimer`
and `net.qays.TeachingTimer.watchkitapp`; development remains `com.qayshp.TeachingTimer`.
