# Teaching Timer — current status

Source/CI status updated November 13, 2026. A November 12 physical companion
delivery was received and verified November 13; public-invitation status was last checked November 5. External
App Store Connect review/build membership was last checked November 2. This page
owns current build and validation status.
See the [changelog](CHANGELOG.md) for user-visible changes and the
[roadmap](docs/ROADMAP.md) for prioritized work.

| Artifact | Current evidence |
| --- | --- |
| External submission, last checked November 2 | **1.0 (37)**, signed source `a36f3be587825`. App behavior is unchanged from 36; packaging adds external eligibility. Signed export, upload, Apple processing, 13 Swift suites / 130 Python tests, Watch CI and CodeQL pass. |
| Public invitation, checked November 5 | [Join TestFlight](https://testflight.apple.com/join/YA2WSmae) now offers **View in TestFlight** and joining instructions. Initial configured limit: 100. The public page does not expose the eligible build/version; a new external tester's installation remains unverified. |
| Latest verified internal TestFlight release | **1.0 (261113.1613.59)**, source `5ef55b902ea9`. [Release run](https://github.com/qayshp/TeachingTimer/actions/runs/43532670947) passed exact-source Watch verification, three-payload signing/export, upload, Apple `VALID`, notes/group readback and Maintainer `IN_BETA_TESTING`, available November 13 at 16:32:24 PST. Clarifies session Help and diagnostic privacy; teaching, runtime, count and media/Crown behavior is unchanged. Server availability is distinct from installation; no physical-device contact was performed by this release. |
| Latest owner report | The owner reports updating Watch and phone through TestFlight, successfully using the Utility face with Teaching Timer and native Now Playing launchers, and a class where everything used worked. Song progress was not specifically compared between the two apps. No exact installed version was independently read for this report; the latest parsed physical report remains the build-39 record below. |
| First hosted internal release | **1.0 (42)**, source `190e0738b82d`, passed the first complete GitHub-hosted signed release, processing, test-note readback and sole Maintainer pilot assignment. It predates the later merged dial and media-timeline changes. [Exact provenance and timings](docs/TESTFLIGHT_PREPARATION.md#november-4-2026--hosted-release-validation). Subsequent app-affecting main pushes publish through the same gated workflow. |
| Media timeline experiment | PR 18 isolates Now Playing from the teaching clock timeline. TestFlight `1.0 (261104.1939.6)` includes the change; the owner reports song progress still freezes. Isolation alone did not fix the issue. |
| Latest parsed physical report / companion | The November 12 Watch-prepared report reached support and parsed: **261112.0232.39**, source `16a38f1d9067`, 1,225,763 bytes / 1,628 events. Fresh Watch journals corroborate it. The phone's installed build was not independently read. The earlier build-32 phone-requested delivery remains a separate successful flow; first linking/Mail recovery remains historical. [Current observations](docs/VOLUME_INCIDENT_2026-11-12.md). |
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
- **Earlier class feedback, October 31 (development 25):** volume and Settings
  worked; song progress stalled and page switching recovered a useful position.
- **November 12 physical feedback (Beta 261112.0232.39):** morning Amazon
  Music/AirPlay worked; afternoon Apple Music/USB timer volume did not recover
  after refresh/media return and needed phone buttons. Journals confirm focus
  requests on the retained native object, not command delivery or actual focus.
  The later phone capture lacks detailed media records for those class windows.
- **Latest supervised test, November 2 (Beta 35):** initial timer volume,
  media-return volume, Home/reopen and tap-refresh all worked audibly on the
  paired iPhone speaker. Embedded progress updated on entry then stalled;
  standalone Now Playing appeared to advance. Seeking updated the embedded
  indicator with an apparent, unmeasured offset.
- The user confirms eligible inactivity refresh updates song position. Neither
  that nor page reentry establishes continuously accurate progress.
- **Blank media (#1) remains resolved. Crown volume (#2) is reopened** for the
  later physical unresponsiveness; whether it shares the earlier corrected
  refocus mechanism is unknown. Unexpected silencing (#3) has not recurred
  recently but needs one bounded affected-route check;
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

## Monochrome complication artwork — November 13

Maintainer TestFlight **261113.1031.57** uses the rolled mat and clock for the
watch-face launcher, matching the app identity rather than the generic SF timer
symbol in build **261113.0211.55**. App icons, class/runtime/count state and
Crown/media code are unchanged.

SE 3 40 mm / watchOS 27.2 Simulator shows the new corner and circular icons while
awake and under Device Hub Lock. Rectangular rendering and the smaller inline
glyph also pass; the inline mark remains a compact brand cue beside the app name
in awake/Lock states. Opening through the launcher preserves saved class timing;
the owner subsequently confirmed the Utility launcher setup works. Small-slot
readability has not been independently inspected on the physical Watch. The image assets
use template rendering and transparent interiors. Ordinary size-bounded PNGs,
including a smaller inline asset, avoid the reproduced high-resolution PDF
snapshot failure. Tests guard image dimensions/scales/alpha metadata and require
the extension's compiled asset catalog in current archive checks. Historical
SF-symbol launcher archives remain inspectable.

All 16 Swift suites and 375 Python tests passed locally. The exact-source
[Watch verification](https://github.com/qayshp/TeachingTimer/actions/runs/43483472291),
[CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/43483472179) and signed
release passed. [Issue #32](https://github.com/qayshp/TeachingTimer/issues/32) is closed.
See [screenshots and setup](docs/TEACHING_FACE_GUIDE.md#quick-launch-from-a-watch-face)
and [artwork notes](docs/design/complication-glyph/README.md).

## Initial watch-face launcher — November 13

Build **261113.0211.55** adds a static **Teaching Timer** complication in all
four accessory families: circular, corner, inline and rectangular. Available
slots depend on the selected watch face. Open the updated Watch app once, then
add the launcher while editing that face. Tapping opens the app without creating
or resetting a class; normal saved-state and runtime recovery rules still apply.
The separate extension reads no app data and requests no repeating timeline
updates. See the [quick-launch guide](docs/TEACHING_FACE_GUIDE.md#quick-launch-from-a-watch-face).

The Simulator app and both unsigned archives build successfully. All 16 Swift
suites and 368 Python checks pass, including extension packaging and three-payload
release safeguards. On SE 3 40 mm / watchOS 27.2 Simulator, corner and circular
launchers appeared in Infograph, and the rectangular launcher appeared in Modular.
All three opened the app when tapped and preserved saved class bytes. Opening
with no class did not create one. At this initial build-55 checkpoint, inline rendering and physical-Watch
interaction remained separate checks; later artwork/launcher results are above. [Watch CI](https://github.com/qayshp/TeachingTimer/actions/runs/43407153076)
passed all 17 verification stages on clean source. The independent
[CodeQL run](https://github.com/qayshp/TeachingTimer/actions/runs/43407152903)
also passed Actions, Python and the full Swift build/analysis.
The third App Store profile for
`net.qays.TeachingTimer.watchkitapp.complications` is configured in the protected
`COMPLICATION_PROFILE_BASE64` secret; it reuses the existing distribution
certificate and expires November 4, 2027. Signed export checked all three profiles,
identities, signatures, entitlements and matching versions. Apple processing and
Maintainer availability passed; that does not establish installation. Tracked in
[issue #31](https://github.com/qayshp/TeachingTimer/issues/31).

## November 13 consistency review

Maintainer build **261113.1613.59** aligns Help with both Start/Resume session
actions, describes omitted preference files precisely, and reconciles current
optional-companion reporting with historical Watch-sharing experiments.
Report-window and size-contract checks protect phone/Watch agreement.
Class/runtime/count scheduling and the working media/Crown implementation are
unchanged. All 16 Swift suites, 375 Python checks, 42 local Simulator action
assertions and clean-source build/archive verification pass. Hosted Watch
verification passed all 17 stages. The release is available; no new physical
installation or media/volume validation is established by this review.
See the [review and verification record](docs/CONSISTENCY_REVIEW_2026-11-13.md).

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
[Hosted app checks](https://github.com/qayshp/TeachingTimer/actions/runs/43201276938),
[CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/43201276336), and the
release workflow all passed at `16a38f1d9067`. Build 261112.0232.39 is available
to Maintainers. No new physical installation is established.

The subsequent [OCR follow-up](docs/REVIEW_2026-11-12.md#screenshot-ocr-follow-up)
restores the complete interactive check: all 21 actions pass on both SE 3 40 mm
and Ultra 4 49 mm. SE lifecycle/relaunch, three retirement scenarios and locked
full-count captures on both sizes also pass. All 16 Swift suites and 298 Python
tests pass. Changes through `5d9bd66` are test tooling and documentation only;
the TestFlight app and physical installation are unchanged. The subsequent
[outline calibration follow-up](docs/REVIEW_2026-11-12.md#outline-checker-calibration-follow-up)
corrects the Ultra measurement issue and adds 18 independent regression cases.
The broader early-rendering investigation in #17 remains open.

Hosted follow-up at `b573bcdf29f7` passed Watch checks, release verification and
CodeQL. Both Mac jobs completed all 17 verification stages, including genuine
OCR and outline fixtures; publishing was skipped. CodeQL's extracted database
contains all 29 production Swift files across Watch and phone. The
[CI efficiency review](docs/CI_EFFICIENCY.md) records the measured timings and
removes the duplicate release-side Mac pass for non-publishing tooling changes,
while preserving full release verification for app candidates/manual rehearsals.
The next tooling pass adds selective Swift CodeQL scheduling: production,
dependency, project and security-routing changes still request full analysis;
weekly/manual scans remain full. Python and Actions scan every change. All 315
Python tests, repository checks and workflow lint pass. The first full hosted
scan passed with all 29 production Swift files byte-matching its commit and the
same 27 baseline security-rule IDs. A docs-only follow-up passed with Swift
skipped while the earlier full scan continued. The efficiency review records
the exact runs, source comparison and event-test limits. No app source or
distribution changed.

The November 13 tooling pass replaces automatic releases' duplicate Mac pass
with exact-source reuse of a completed trusted main-push Watch verification.
Manual rehearsal/publish retains fresh full verification. Schema-2 reports check
source cleanliness/revision before and after tests; the consumer binds run,
attempt, artifact digest and all required stages. At `c14b1a2`, all 356 local
Python tests, repository checks and workflow lint pass; hosted Watch checks,
release tooling/lint and CodeQL also pass. A live read-only consumer accepted
the new exact-source Watch artifact and all 17 stages. This tooling-only push
did not exercise an app-candidate publish; that gate's failure/manual routing is
covered by workflow-expression tests. The efficiency review records the exact
evidence and limits. App behavior, signing and distribution groups are unchanged.

## Optional companion — November 12

The companion adds an optional iPhone support app and moves Watch export to
Settings → Help → Send diagnostics to iPhone. Phone requests select 2 hours,
24 hours or all retained events while the Watch app is open. The Watch share
sheet is removed. Distribution IDs are preserved; teaching stays independent.
Phone-requested and Watch-initiated physical email deliveries are verified.
Startup, first composer and upgrade reliability remain validation gates; new source does not imply installation.
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
