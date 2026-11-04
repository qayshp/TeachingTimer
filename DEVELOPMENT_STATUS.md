# Teaching Timer — current status

Installed-build status updated November 4, 2026; external-review status was last
checked November 2. This page owns current build and validation status.
See the [changelog](CHANGELOG.md) for user-visible changes and the
[roadmap](docs/ROADMAP.md) for prioritized work.

| Artifact | Current evidence |
| --- | --- |
| External submission, last checked November 2 | **1.0 (37)**, signed source `a36f3be587825`. App behavior is unchanged from 36; packaging adds external eligibility. Signed export, upload, Apple processing, 13 Swift suites / 130 Python tests, Watch CI and CodeQL pass. |
| Public invitation, last checked November 2 | [Join TestFlight](https://testflight.apple.com/join/YA2WSmae). Build 37 was **Waiting for Review**; the link was enabled but not accepting testers yet. Initial limit: 100. Automatic tester notification was enabled. |
| Internal release | **1.0 (42)**, source `190e0738b82d`, passed the first complete GitHub-hosted signed release, processing, test-note readback and sole Maintainer pilot assignment. It preserves build 41's dial and app behavior; layout and media draft PRs remain separate. [Exact provenance and timings](docs/TESTFLIGHT_PREPARATION.md#november-4-2026--hosted-release-validation). |
| Media timeline experiment | PR 18 isolates Now Playing from the teaching clock timeline. The merged code is covered by the updated checks; a physical progress fix remains unverified and no new TestFlight build includes this experiment yet. |
| Physical Watch | **Beta 42**, confirmed by the owner November 4 after updating through TestFlight on the paired iPhone, with no developer connection required. This is an owner report, not a new developer-tool inventory or classroom validation. Unattended automatic-update cadence is not established. |
| Owner pilot | The November 2 build-35 install/update/relaunch, saved state, intentional Stop and all three journal copies passed within the [recorded limits](docs/TESTFLIGHT_PILOT_RESULTS.md). Its seven-build group inventory through 36 is historical. The later build-42 update is separately owner-confirmed. |
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
