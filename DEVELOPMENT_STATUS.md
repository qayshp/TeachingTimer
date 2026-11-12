# Teaching Timer — current status

Source/CI status updated November 12, 2026. Physical companion delivery was verified
November 11; public-invitation status was last checked November 5. External
App Store Connect review/build membership was last checked November 2. This page
owns current build and validation status.
See the [changelog](CHANGELOG.md) for user-visible changes and the
[roadmap](docs/ROADMAP.md) for prioritized work.

| Artifact | Current evidence |
| --- | --- |
| External submission, last checked November 2 | **1.0 (37)**, signed source `a36f3be587825`. App behavior is unchanged from 36; packaging adds external eligibility. Signed export, upload, Apple processing, 13 Swift suites / 130 Python tests, Watch CI and CodeQL pass. |
| Public invitation, checked November 5 | [Join TestFlight](https://testflight.apple.com/join/YA2WSmae) now offers **View in TestFlight** and joining instructions. Initial configured limit: 100. The public page does not expose the eligible build/version; a new external tester's installation remains unverified. |
| Latest verified internal TestFlight release | **1.0 (261112.0129.36)**, source `37f7ff64a6ae`. [Release run](https://github.com/qayshp/TeachingTimer/actions/runs/43191773551) passed app verification, signing, upload and Apple processing, then received HTTP 404 at group assignment. A metadata-only resume confirmed Maintainer membership and `IN_BETA_TESTING` November 12 at 01:55:07 PST, without another upload. Adds request isolation, validated saved reports and clearer phone UI. This is availability, not a confirmed installation. |
| First hosted internal release | **1.0 (42)**, source `190e0738b82d`, passed the first complete GitHub-hosted signed release, processing, test-note readback and sole Maintainer pilot assignment. It predates the later merged dial and media-timeline changes. [Exact provenance and timings](docs/TESTFLIGHT_PREPARATION.md#november-4-2026--hosted-release-validation). Subsequent app-affecting main pushes publish through the same gated workflow. |
| Media timeline experiment | PR 18 isolates Now Playing from the teaching clock timeline. TestFlight `1.0 (261104.1939.6)` includes the change; the owner reports song progress still freezes. Isolation alone did not fix the issue. |
| Physical Watch / companion | The owner matched both devices to **261108.1359.32** after reinstalling the Watch app. After force closing both apps, a phone-requested report reached support: 58,129 bytes / 85 events, matching that build. Initial linking and a gray Mail sheet required recovery. Latest follow-up build installation remains unconfirmed. |
| Owner pilot | The November 2 build-35 install/update/relaunch, saved state, intentional Stop and all three journal copies passed within the [recorded limits](docs/TESTFLIGHT_PILOT_RESULTS.md). Its seven-build group inventory through 36 is historical. The later build-42 update is separately owner-confirmed. |
| Rollback | Build 16 remains a preserved local checkpoint with its known media/volume issues. |
| November 6 journal-sharing owner pilot | [PR #28](https://github.com/qayshp/TeachingTimer/pull/28) was merged and released as **1.0 (261106.1118.29)**. Settings → About adds report preparation and native sharing. Simulator staging/hash checks and the final PR/release verification passed, including 15 Swift suites / 275 Python tests. The separate main check reproduced known awake-runtime rejection #27 on watchOS 26.5; the release's watchOS 27.2 SE 3 / Ultra matrix passed. At that checkpoint, installation and physical receipt were unverified. A later native-share email and the November 11 companion receipt were subsequently verified; see the current companion row above. [Validation evidence and limits](docs/DIAGNOSTIC_SHARING_VALIDATION.md); #26 remains open. |
| November 6 issue follow-up | #1, #2 and the original dimmed-start #7 are resolved. All 13 local Swift suites / 266 Python tests pass; fresh action, focus, media and count captures were reviewed. Hosted watchOS 26.5 testing caught a separate awake-runtime rejection (#27); the newer hosted path passed. [Full findings and evidence correction](docs/ISSUE_REVIEW_2026-11-06.md). No app behavior or physical device changed. |
| November 6 CI expansion | At `d0ac054`, local and both hosted small/large Watch matrices passed recovery, intentional Stop, timer/media retirement and overdue-class launch checks. Each matrix exercised 20 process launches; all 13 Swift suites / 253 Python tests and both archive paths passed. [Exact models, runtime builds and limits](docs/AUTOMATION.md#booted-watch-smoke-check). CodeQL passed; no app behavior changed, no new TestFlight release was published and no physical Watch was accessed. |
| November 5 cleanup follow-up | Gear-only class/settings control, complete Start/Resume session labels, strict compiler checks and booted Simulator smoke are implemented. All 13 Swift suites / 204 Python tests, 21 SE 3 action assertions and six lifecycle assertions passed. Both hosted paths executed the Watch app on watchOS 26.5 and 27.2 and passed archive verification at `8ddde8f`; see the [follow-up](docs/REVIEW_2026-11-05.md#hosted-follow-up--november-6). No physical-device action was performed. |
| November 5 review | Runtime sequence coverage, release-input checks and clearer stopped-session text are committed. Full SE 3 Simulator suite and five-size layout inspection completed; see the [review and evidence limits](docs/REVIEW_2026-11-05.md). No physical-device action was performed for this review. |

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
- **Blank media (#1) and the Crown-focus regression (#2) are resolved:** retained
  native controls/refocus and view recreation have targeted verification plus
  subsequent positive owner evidence. Reopen on recurrence. Unexpected silencing
  (#3) has not recurred recently but needs one bounded affected-route check;
  frozen progress (#8) and developer connections (#5) remain open.
- **Dimmed runtime recovery fixed in builds 31–32:** readiness gating prevents
  the reproduced premature Start. The matched Simulator recovery and eight
  added persisted-intent cases pass; [issue #7](https://github.com/qayshp/TeachingTimer/issues/7)
  is closed. A newly captured awake-relaunch rejection despite active readiness
  is tracked separately in #27; broader physical reliability remains in #10.
- **Seconds-hand backstep fixed in builds 33–34:** the stable timeline anchor
  and boundary normalization address the reproduced mechanisms. Subsequent
  Simulator recordings show no backward ticks, and the owner reports no recent
  physical recurrence. [Issue #4](https://github.com/qayshp/TeachingTimer/issues/4)
  is closed as completed; reopen if the symptom returns.
- Mindfulness runtime suitability for guided yoga teaching and automatic renewal
  still needs explicit Apple guidance. Beta review does not settle intended use.

## November 12 review verification

PR #29 is merged. [App checks](https://github.com/qayshp/TeachingTimer/actions/runs/43191773559)
and [CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/43191772222)
passed at `37f7ff64a6ae`. App checks needed one unchanged-code retry after a
20-second Simulator screenshot timeout; the independent release verification
passed first try. Both successful matrices cover ten launches each on SE 3 and
Ultra, and include the new iPhone Simulator build. Local checks pass all 16 Swift
suites and 282 Python tests including the subsequent release-metadata retry.
See the [review](docs/REVIEW_2026-11-12.md) for evidence and remaining limits.

## Support-page usability follow-up — November 12

Source now uses shorter Help topics, Help-based contact/support, compact Settings
and Privacy summaries, and dedicated Watch scan pages. Phone support prioritizes
received reports, offers ordinary email without a report and confirms deletion.
Local Simulator builds and model/tool checks pass; the interactive OCR-driven run
was incomplete after a helper timeout. Direct screen inspection and a decoded
SE 3 Support QR are recorded in the [review](docs/REVIEW_2026-11-12.md#follow-up-page-usability).
This source follow-up does not establish a new physical installation.

## Optional companion — November 12

The companion adds an optional iPhone support app and moves Watch export to
Settings → Help → Send diagnostics to iPhone. Phone requests select 2 hours,
24 hours or all retained events while the Watch app is open. The Watch share
sheet is removed. Distribution IDs are preserved; teaching stays independent.
One physical email delivery is verified. Startup, first composer and upgrade
reliability remain validation gates; new source does not imply installation.
See [companion validation](docs/OPTIONAL_COMPANION.md) and the
[November 12 review](docs/REVIEW_2026-11-12.md).

## Next validation

1. Investigate frozen progress on the timeline-isolated build with matched
   phone/Watch playback; the latest owner-reported TestFlight build still showed
   the issue.
2. Obtain runtime guidance and finish teaching-length, route, battery and
   accessibility checks before a general release.
3. Verify the exact public build and first external install; the invitation page
   is now open. Private email accepts descriptions and optional cropped
   screenshots. [Tester journal export](docs/DIAGNOSTIC_EXPORT_PLAN.md) now has
   an approved owner-pilot validation path in #26; repeat delivery, TestFlight
   delivery and interruption/offline checks remain open before general support.

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
