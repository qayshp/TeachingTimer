# Automation and evidence boundaries

Run commands from the repository root. Automated checks should detect behavioral
regressions and preserve enough evidence to explain failures. A green result
does not replace the separate physical teaching checklist.

## Offline and CI checks

```sh
python3 scripts/check-repository.py
sh scripts/check-tools.sh
sh scripts/check.sh
python3 scripts/verify-build.py work/verification-new --simulator-smoke
sh scripts/check-control-outline.sh work/control-outline-smoke-new
sh scripts/check-simulator-tools.sh work/simulator-tools-new
work/simulator-tools-new/check-screen-text work/simulator-tools-new/ScreenText work/screen-text-smoke-new
```

`verify-build.py` includes the repository, tooling and Swift checks, a Simulator
build and unsigned archives. With `--simulator-smoke`, it also boots disposable
small and large Watches serially and exercises real app launches, runtime recovery
and class retirement. Omit that flag for build-only
verification. Run smaller commands when iterating; use complete verification
for a candidate. The output directory must be new.
The separate Simulator-tools check compiles all four diagnostic fixtures,
four UI-inspection helpers and the OCR smoke fixture. It does not launch them or produce audio. The
screen-text smoke check then runs the compiled OCR helper against two synthetic
images; it does not launch an app or Simulator.
The independent `control-outline-smoke` runs early in full verification, before
Simulator builds/boots. It compiles the measurement helper and exercises fixed
SE/Ultra outline fixtures and invalid-image guards without opening Device Hub.

| Layer | Automated coverage | Boundary |
| --- | --- | --- |
| Repository | Tracked local Markdown targets and heading fragments, source notices, source whitespace/line-ending hygiene, Python and shell syntax, JSON/plist parsing, standalone Swift suite wiring and private/generated-file exclusions. | Heading checks cover the repository's ATX/plain-text/inline-code forms, including duplicate IDs. Remote URLs, non-Markdown fragments, reference links and other heading syntax remain outside this bounded checker; it is not a general Markdown renderer or legal audit. |
| Swift models/controllers | Class anchoring/persistence, clock edges, geometry/layout, runtime intent/renewal, landmark deadlines/cancellation/restart, journal retention and volume/media policies. | Standalone executables use WatchKit boundary doubles; they cannot establish watchOS acceptance or physical effects. |
| Python tooling | Device command failures/retries, journal summaries, build inspection, action/evidence classification and suite result handling. | Device/process boundaries are faked. Test success is not a successful transfer or deployment. |
| Build/archive | Simulator compilation, website QR decoding, bundled policy/license/website resources, exact reviewed privacy-manifest declarations, and structural inspection of development/distribution archives. Signed export checks inspect the Watch manifest again in the IPA. | Manifest comparison is not an API-usage audit or Apple privacy approval. Unsigned success is not signed distribution, installation or App Store validation. QR decoding is not a physical camera test. |
| Booted Watch smoke | Runs serially on disposable small/large Watches using the same newest available compatible runtime. Checks saved class/Stop persistence, real running-intent recovery after process replacement, live retirement on timer and media pages, and overdue-class retirement on launch. Fresh journals and persisted values must agree. | Screenshots require human review. No swipe/menu interaction, pixel assertion, Crown ownership, phone audio, physical haptics or full-duration WatchKit expiry/renewal is tested. No existing Simulator or physical device is targeted. |
| Diagnostic tools | Compiles the phone-audio, native-volume, timeline-clock and diagnostic-share Simulator fixtures, plus HubInput, ScreenText, MediaPixels and ControlOutline helpers. | Compilation catches SDK and syntax regressions; no simulator boots, UI interactions, audio, sharing or device behavior is tested. |
| Screen-text smoke | Runs real text recognition on two harmless 324×394 synthetic images containing nine action/navigation labels. Requires exact labels, corroborated fast recognition, raw confidence and expected centers. | Each image has a 20-second deadline plus bounded termination. This checks OCR execution and its output contract, not app rendering, live UI interaction or device state. |
| Control-outline smoke | Runs the real pixel-measurement helper on 15 independent SE/Ultra fixtures, plus three invalid resolutions. Covers thin/thick outlines, each missing side, black/text-only images, short crossings and the obsolete Ultra inset. | Five-second per-image deadline plus bounded termination. This checks calibrated straight-side coverage, not complete control visibility or touchability. |

The manifest check rejects missing, unreadable or changed tracking/data-collection
declarations and omitted, duplicate or unexpected required-reason entries. Update
the reviewed policy and validator together when data or API use changes. Build 31's
existing archive/export already has the expected manifest; build 32 adds enforcement
at both artifact boundaries rather than correcting a shipped privacy declaration.

Local heading checks now catch the clock-investigation link typo that file-only
validation missed. Fixtures cover same-document links, duplicate/colliding IDs,
encoded fragments and fenced examples. Extend the checker before relying on
Setext headings, custom HTML anchors or richer heading markup in a linked target.
Private ignored evidence is outside repository validation.

GitHub Actions runs the noninteractive verification with its recorded toolchain.
The Watch-check and release verification jobs compile and run the booted Watch
smoke check described below. They also compile the four diagnostic fixtures and
four UI-inspection helpers, then run the `screen-text-smoke` stage. Both workflows
retain its synthetic images, expected labels, raw OCR output, stderr and result
report for 14 days, including failures. The Swift model/controller suites are separate host
executables that use
WatchKit boundary doubles. Interactive Watch Simulator scenarios require the
local Device Hub workflow below. See [build evidence](BUILD_VERIFICATION.md) for
retained artifacts. CI does not touch physical devices.

### Booted Watch smoke check

```sh
python3 scripts/simulator-smoke.py \
  --app /absolute/path/to/Debug-watchsimulator/TeachingTimer.app \
  --output work/simulator-smoke-new
```

The smoke check requires an available Watch runtime and an ad-hoc-signed Debug
artifact; a missing runtime or failed check fails CI rather than silently
skipping. The default `--watch-size matrix` creates its own unpaired Watches for
the smallest and largest supported millimeter sizes on the newest compatible
runtime and runs them serially. The matrix fails if two distinct sizes are
unavailable or the selected runtime changes between runs. Use `--watch-size small`
or `--watch-size large` for a focused local run; neither alone establishes a
passing matrix.

Each Watch runs the same scenarios:

- **Intentional Stop:** a synthetic 60-minute class and stopped intent must survive
  timer/media/timer process launches byte-for-byte, with fresh page callbacks and
  no runtime start.
- **Running-intent recovery:** two timer process launches must restore the same
  class and intent, recover automatically while awake, and report ordered recovery
  callbacks with a distinct runtime identity for each process.
- **Live class retirement:** separate fixtures reach the real retirement deadline
  while the timer page has a running session and while the media page has stopped
  intent. The same process must remove class and intent without restarting them.
  The running timer case also requires runtime invalidation and a renewal decision
  that rejects restarting after the explicit stop. Reopening must keep the class
  absent.
- **Overdue launch:** a class already past retirement, with saved running intent,
  must retire on launch without starting a runtime.

Fixtures are written only into fresh, never-launched app installations on the
owned test device. No live preferences or system clocks are changed. Live
retirement fixtures are seeded 60 seconds before their deadline on the timer page
and 45 seconds before it on the media page; overdue retirement is five seconds
past its deadline. This tests the app's **scheduled end plus 30 minutes** retirement
rule, not WatchKit's full-duration session expiry or automatic renewal. Each
launch and live retirement includes a three-second observation of its required
postconditions, followed by another check after screenshot capture.

Page selection uses launch arguments and fresh page callbacks; no swipe gestures
or open-menu interactions are tested. No production test hook, Device Hub window,
paired phone, account or release credential is used. Screenshots remain evidence
for human review, and the result keeps `renderingVerified=false`.

An eight-minute work budget **per Watch**, plus shorter command/launch deadlines,
bounds the checks; cleanup has its own bounded timeout. On success or ordinary
failure/interruption it shuts down and deletes only the device it created. Forced
runner termination can prevent final cleanup; on hosted runners the disposable
runner is the final boundary. CI retains command logs, synthetic journals,
screenshots, runtime/build metadata, per-size results and the combined manifest
for 14 days, including failure evidence. Existing devices and evidence are not
reset. Local output directories are retained for review.

The CI workflows additionally pass `--prepare-ci-runtime`. This guarded dependency
step runs only on **GitHub-hosted** runners and writes its evidence under
`RUNNER_TEMP`; local and self-hosted invocation is rejected. If the selected
Watch Simulator SDK has no matching usable runtime, it performs one ten-minute
bounded `xcodebuild -downloadPlatform watchOS` request with that SDK version and
architecture. It then rechecks availability and fails if the runtime is still
missing. See [Apple's runtime installation commands](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components).

This provision was necessary because the first Xcode 27.2 hosted image had the
Watch SDK but **no Watch runtime**. The first attempt correctly failed before
signing or uploading. Download logs and before/after inventories are retained;
no laptop platforms, physical devices, accounts or license agreements are changed.
CI timeouts include this dependency step. Both PR/main verification and release verification use the xcode-27 hosted
runner with Xcode 27.2 explicitly selected. The older default-runner failure
remains recorded under #27; alignment is not a runtime bug fix. Local smoke uses the already
installed newest compatible runtime and never downloads one.

Python tests cover runtime selection, missing-runtime failure, stale/wrong-page
journal rejection, synthetic state preservation and cleanup ownership. The earlier
three-launch Stop-persistence smoke passed locally on watchOS 27.2 / SE 3 40 mm. The first
[hosted Watch check](https://github.com/qayshp/TeachingTimer/actions/runs/42183165891)
also passed all three launches on watchOS 26.5 / Xcode 26.6 in 87.117 seconds,
with clean device removal. The subsequent November 6
[release verification](https://github.com/qayshp/TeachingTimer/actions/runs/42184213880)
at source `8ddde8f` passed that earlier smoke on watchOS 27.2 / Xcode 27.2 in
152.214 seconds, after 94.781 seconds of runtime setup including download/install.
These are results for the earlier smoke, not the expanded small/large recovery
and retirement matrix described above.

The expanded matrix passed locally on November 6 using Xcode 27.2 / watchOS 27.2
(24S118): SE 3 40 mm in 213.050 seconds and Ultra 4 49 mm in 209.940 seconds.
Both completed ten process launches, two timed retirements and an overdue-launch
check, with clean Simulator removal. All 13 Swift suites and 253 Python tests,
fixture/helper builds, Simulator compilation and unsigned archives passed.

Expanded hosted execution also passed at clean source `d0ac054`:

| Verification | Runtime | Small / large models | Matrix time |
| --- | --- | --- | --- |
| [Watch checks](https://github.com/qayshp/TeachingTimer/actions/runs/42192825908), Xcode 26.6 (17F113) | watchOS 26.5 (23T570) | Series 6 40 mm / Ultra 49 mm | 612.961 s |
| [Release verification](https://github.com/qayshp/TeachingTimer/actions/runs/42192825784), Xcode 27.2 (27B48) | watchOS 27.2 (24S116) | SE 3 40 mm / Ultra 4 49 mm | 699.564 s |

Each hosted matrix completed all 20 launches, four timed retirements, two
overdue-launch checks and clean removal of both devices. All 14 verification
stages passed. These jobs cover two size extremes on their recorded runtime;
they are not a test of every Watch generation or every rendered layout. The
local and hosted 27.2 runtime build numbers differ and are intentionally retained
above. [CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/42192825381)
passed for the same source. Publishing was skipped because these changes affect
tests and documentation, not the app artifact.

The initial local attempts exposed two harness races: the interface journal can
flush after runtime callbacks, and the preference file can update after a
retirement event is recorded. Readiness now waits for both independent sources
within the existing launch deadline before starting its three-second observation.
It does not treat a callback alone as persisted-state proof. The 49 added Python
tests also reject stale launch/runtime IDs, premature retirement, lost journal
records, late restarts, transient dim/background intervals, and incomplete
matrices. The app's production code was unchanged.

### November 2, 2026 — Swift CodeQL coverage check

Read-only inspection of [the completed Swift job](https://github.com/qayshp/TeachingTimer/actions/runs/41554828979/job/125651053865)
at source `17f2d3c1df8e` confirms Autobuild selected the production
`TeachingTimer` target. Its source phase contains 23 Swift files; CodeQL reported
23 of the repository's 46 Swift files scanned. The remaining files are 13 tests,
two scripts and eight tools. This is production-app analysis, not fixture-only
coverage. The job reported zero unresolved AST nodes; the uploaded Swift analysis
had no analysis error and zero results. Those results cover the configured
queries, not every possible defect, source branch or security property.

Autobuild took about 14 minutes, principally in build preparation and compilation;
database finalization and query results followed in about one minute. It performed
traced, optimized whole-module device builds for `arm64_32` and `arm64`, explicitly
disabling compilation caches and the integrated Swift driver on a clean hosted
runner. A short local build is not an equivalent workload. The log does not
isolate the cause of every preparation or compilation pause.

That job used Xcode 26.6 and the watchOS 26.5 SDK with a 26.0 deployment target.
This adds 26.x SDK compilation evidence; it does not establish execution on
watchOS 26. No workflow was changed or rerun for this inspection.

## Interactive Simulator checks

Use the [combined regression suite](../tools/simulator-regression/README.md#run-the-combined-suite)
for serial essential-action, optional lifecycle and count/Lock checks. It requires
Device Hub and explicit selection of a booted disposable test simulator; the
test app's data is reset. Run each size separately, never concurrently through
the same UI.

- **Essential actions:** create/cancel/edit/replace/end classes, count start/stop,
  runtime Stop/Resume, Settings information-page navigation before/during class,
  and media/timer navigation, checked against saved values, rendered content
  and fresh journal events.
- **Focus lifecycle, SE 3:** Crown input, Home/reopen, refresh and media return,
  preserving the app host, class and native control instance.
- **Media lifecycle, SE 3:** opt-in native view-service termination and recovery
  observation. This deliberately injected failure is not a diagnosis of the
  physical blank-media trigger.
- **Process relaunch, SE 3 and Ultra:** run `relaunch.py` after the count suite;
  require journal-confirmed awake state, then verify running-intent recovery
  and intentional Stop across real process replacement, retaining the saved class.
- **Count/Lock captures, SE 3 and Ultra:** timed screenshots, OCR and outline
  measurements, followed by a full locked count with same-run normal completion
  at or after its configured completion deadline, with journal-confirmed reduced
  luminance and no recorded wake through completion. Flags request review; they
  do not automatically declare a disappearing control, certify touch response
  or prove a haptic was felt.

The suite records incomplete assertions or missing evidence as failures. Review
original screenshots independently: callbacks, text recognition and visible
native controls each answer different questions. Keep captured preferences,
journals and logs private under ignored `work/`.

## Practical limits and remaining checks

- The UI runner targets English/default-text layouts. Large text, 12/24-hour
  formats, other geometries and accessibility navigation need separate captures
  and review; historical screenshots are not current-build results.
- The retained volume control can receive a focus call without acquiring Crown
  ownership. Neither a changing ring nor a logged submission proves the iPhone
  received a command or audio remained audible.
- Simulator Lock can exercise reduced luminance. It does not establish display
  cadence, physical haptics, wet-finger usability, battery use or class-length
  runtime reliability on a Watch.
- Build 16 remains a preserved rollback checkpoint; [current status](../DEVELOPMENT_STATUS.md)
  identifies the actual installed build. Simulator reset authority
  does not authorize a Watch install. Signed/TestFlight deployment and journal
  access remain separately verified workflows.

Record the actual command, source revision, toolchain and retained results in
[current status](../DEVELOPMENT_STATUS.md). Keep dated test counts and observations
in their original reports; do not turn an unrun test or a bounded success into
a claim of complete coverage.

## Maintainer TestFlight release

The `.github/workflows/check.yml` and
`.github/workflows/testflight-release.yml` workflows classify the changed paths
before selecting expensive checks or publishing.

- Every push and pull request runs tracked-file/documentation validation and the
  Python tooling tests on Ubuntu.
- Changes under the Watch app, Xcode project, app configuration or package
  inputs, plus bundled `LICENSE`/`docs/PRIVACY.md` and the build-metadata script,
  also run the Mac Simulator build, Swift suites and unsigned archive
  checks. Swift test-harness changes run that Mac verification without triggering
  a TestFlight upload.
- Workflow changes run pinned `actionlint`; other tooling changes run the
  Python tooling checks. Mac build harnesses, diagnostic fixtures and Swift
  inspection helpers additionally receive Mac verification without publishing.
  Non-bundled documentation changes skip the Mac/Xcode job.
- Only app inputs, or an unrecognized path handled conservatively as an app
  input, can trigger automatic TestFlight publishing. CI/workflow configuration
  changes and non-bundled docs alone cannot publish.
- A manual release rehearsal or publish still runs the full verification path.

`scripts/change-impact.py` is the shared classifier. Its unit tests cover
documentation-only, app, mixed, tooling, Swift-test and unknown-path cases. Keep
the app input rules conservative and extend the tests when project layout or
generated app resources change. The Watch-check workflow has a stable
required-result job that reports success only after every applicable check
passes. Unknown paths take the full verification and publishing path.
Main-branch Watch checks use a concurrency group per commit, so a later docs-only
push cannot cancel unfinished verification of an earlier app change. Pull-request
runs still replace older runs of the same PR because their comparison includes
the entire proposed diff. This does not deduplicate the release workflow or
serialize TestFlight publishers; [#24](https://github.com/qayshp/TeachingTimer/issues/24)
tracks those separate concerns.

The release workflow still separates credential-free verification/rehearsal
from internal publishing. It supports an immutable dispatch revision and unused
build number, timed upload/processing, verified test notes, and assignment only
to the existing Maintainer pilot.
[Setup, credentials, reports and resume limits](TESTFLIGHT_PREPARATION.md#automatic-and-manual-github-release).

Release tests use a synthetic API and fake clock for visibility delays, failure,
timeouts, exact destination matching, duplicate-build refusal, idempotent notes/
groups, metadata-only resume and uncertain-upload handling. A temporary generated
P-256 key exercises the real CryptoKit JWT helper and independently verifies its
signature with OpenSSL. Credential tests validate profile identity/expiry and
cleanup after failure without accessing any real keychain or Apple service.
These checks do not establish live API permissions, CI signing, Apple processing,
or physical TestFlight installation.

The [November 4 hosted validation](TESTFLIGHT_PREPARATION.md#november-4-2026--hosted-release-validation)
separately establishes a successful rehearsal and actual signed build-42 publish,
including Apple processing, saved notes and internal Maintainer pilot assignment.
It records the initial signing-package import failure and the corrected retry,
exact source/toolchain, stage timings and restored main-only publishing access.
The owner subsequently confirmed build 42 installed through the paired iPhone's
TestFlight app without a developer connection. This separate delivery result is
recorded with the release evidence; unattended automatic-update timing remains
unestablished and is not included in CI's server-readiness measurements.

## Companion regression coverage

The shared verification entry point also builds the real iPhone support app and
embedded Watch app for Simulator using a generic iOS Simulator destination.
It deliberately avoids a global iPhone SDK override, which would miscompile the
Watch target. Both PR checks and release verification execute this step.
`DiagnosticRequestChecks` exercises real report-builder output, request retry
isolation, stale/unsolicited receipt, preparation-before-queue ordering, failed
queue/preparation, malformed/oversized input and corrupted saved-report rejection.
These tests run in the regular Swift CI suite; they do not establish paired-device
file delivery or native Mail delivery. Those remain physical validation gates.
