# Automation and evidence boundaries

Run commands from the repository root. Automated checks should detect behavioral
regressions and preserve enough evidence to explain failures. A green result
does not replace the separate physical teaching checklist.

## Offline and CI checks

```sh
python3 scripts/check-repository.py
sh scripts/check-tools.sh
sh scripts/check.sh
python3 scripts/verify-build.py work/verification-new
```

`verify-build.py` includes the repository, tooling and Swift checks, a Simulator
build and unsigned archives. Run the smaller commands when iterating; use the
complete verification for a candidate. The output directory must be new.

| Layer | Automated coverage | Boundary |
| --- | --- | --- |
| Repository | Tracked local Markdown targets and heading fragments, source notices, Python syntax, JSON/plist parsing, standalone Swift suite wiring and private/generated-file exclusions. | Heading checks cover the repository's ATX/plain-text/inline-code forms, including duplicate IDs. Remote URLs, non-Markdown fragments, reference links and other heading syntax remain outside this bounded checker; it is not a general Markdown renderer or legal audit. |
| Swift models/controllers | Class anchoring/persistence, clock edges, geometry/layout, runtime intent/renewal, landmark deadlines/cancellation/restart, journal retention and volume/media policies. | Standalone executables use WatchKit boundary doubles; they cannot establish watchOS acceptance or physical effects. |
| Python tooling | Device command failures/retries, journal summaries, build inspection, action/evidence classification and suite result handling. | Device/process boundaries are faked. Test success is not a successful transfer or deployment. |
| Build/archive | Simulator compilation, website QR decoding, bundled policy/license/website resources, exact reviewed privacy-manifest declarations, and structural inspection of development/distribution archives. Signed export checks inspect the Watch manifest again in the IPA. | Manifest comparison is not an API-usage audit or Apple privacy approval. Unsigned success is not signed distribution, installation or App Store validation. QR decoding is not a physical camera test. |

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
See [build evidence](BUILD_VERIFICATION.md) for retained artifacts. It does not
drive an interactive Device Hub session or touch physical devices.

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

The manually triggered `.github/workflows/testflight-release.yml` separates
credential-free verification/rehearsal from internal publishing. It supports an
immutable dispatch revision and unused build number, timed upload/processing,
verified test notes, and assignment only to the existing Maintainer pilot.
[Setup, credentials, reports and resume limits](TESTFLIGHT_PREPARATION.md#manually-triggered-github-release).

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
