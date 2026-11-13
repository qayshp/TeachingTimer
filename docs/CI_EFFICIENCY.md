# CI timing and useful safeguards

Measured November 12, 2026 at source `b573bcdf29f7`. All three runs passed;
no failure required a retry or code correction. Verification artifacts were
downloaded, matched against GitHub's digests and checked for the clean source
revision, complete results and actual native-fixture output.

| Workflow | Wall time | Result |
| --- | ---: | --- |
| [Watch checks](https://github.com/qayshp/TeachingTimer/actions/runs/43369591103) | 18m 21s | All applicable jobs passed; all 17 verification stages passed. |
| [Release verification](https://github.com/qayshp/TeachingTimer/actions/runs/43369589054) | 14m 09s | All 17 stages passed; publishing skipped. |
| [CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/43369589061) | 21m 14s | Swift, Python and Actions passed. |

## Where the time went

Stage sums exclude checkout, artifact upload and queue time. The two Mac workers
ran in parallel on separate hosts; their difference does not establish a cause
for the variability.

| Verification stage | Watch job | Release job |
| --- | ---: | ---: |
| Outline compilation and 18 native fixture cases | 22.7s | 5.2s |
| Swift model/controller suites | 40.4s | 18.6s |
| Watch Simulator build | 67.8s | 46.5s |
| Two-size booted Simulator smoke | 711.5s | 533.6s |
| Combined iPhone/Watch Simulator build | 70.8s | 72.0s |
| Diagnostic fixture/helper builds | 49.0s | 43.1s |
| Genuine OCR execution | 1.6s | 1.8s |
| Development archive | 31.4s | 38.2s |
| Distribution archive rehearsal | 43.3s | 41.3s |
| All verification stages, including metadata/other checks | 17m 51.8s | 13m 34.4s |

The smoke matrix consumes about two thirds of verification time. Each size
checks ten fresh launches and two real retirements. The 60/45-second retirement
leads and three-second negative observations are intentional behavioral evidence.
The reports show about 152–157 seconds per size outside subprocesses, including
those observations and local processing. Boot, installation and screenshot
times also vary between workers.

Swift CodeQL was the overall critical path: 18m 58s in Autobuild and 1m 35s in
analysis. The extracted database includes all 29 production Swift files (28
Watch, one phone), byte-for-byte matching the source. It uses Xcode 26.6 and
builds `TeachingTimerDistribution` with its Watch dependency. Source inclusion
does not prove all branches are analyzed or establish an absence of defects.

## Implemented: avoid duplicate non-publishing Mac verification

The change classifier now distinguishes `mac_verify` from `release_verify`.
Watch checks retain their existing Mac gate. Release verification is required
only for an app candidate (`mac_verify && publish`) or a manual rehearsal/publish
using `--all`. Automatic candidates now reuse exact-source Watch evidence as
described below; manual requests still perform a fresh full pass.

Native-tooling pushes still get the complete Watch verification and cheap
release-side repository/Python checks, but no second Mac matrix/archive pass.
App/unknown-input pushes retain the same required verification coverage through
reuse. The publication job still requires successful release verification;
the credential-bearing environment and group assignment are unchanged.

Replaying the actual `b731197`→`b573bcd` native-tooling diff through the new
classifier gives `mac_verify=true`, `publish=false`, `release_verify=false`.
Under this gate that push would avoid the 13m 34s release verification stage,
or about 14 minutes including runner setup. This saves runner work and may reduce queues;
it does not promise the same reduction in feedback time because the original
jobs overlapped and CodeQL was slower. Regression cases cover native tools,
model tests, app/phone/embedded inputs, unknown paths, manual force-full behavior
and the actual workflow gate bindings.

The optimization commit `a0d1f48` passed its [Watch checks](https://github.com/qayshp/TeachingTimer/actions/runs/43372976535)
and [release checks](https://github.com/qayshp/TeachingTimer/actions/runs/43372976380),
including 303 Python tests and workflow lint. It changes only workflow/Python
tooling and documentation, so the existing classifier already calls for no Mac
build on that push. The live run validates the workflow bindings and lightweight
fallback; it is not a post-change native-tooling timing benchmark. App/native
paths and manual force-full behavior are covered by the routing regression cases.

## Implemented: selective Swift CodeQL execution

The tracked `.github/workflows/codeql.yml` replaces GitHub's repository default
setup. Python and Actions analysis still run on every main push and pull request.
Swift scans run for production Watch/phone sources and resources, dependency
manifests, Xcode project/configuration, bundled documents and build metadata,
CodeQL configuration and routing edits, and unknown inputs. Known non-bundled
documentation, tests and standalone diagnostic helpers skip that Mac job.

Weekly Tuesday 09:23 UTC and manual runs force a full scan. Unavailable Git
history selects full analysis; a failed classifier or missing output also runs
Swift and fails the final workflow result. The complete push/PR range retains
deleted and renamed app paths. A later docs-only main push cannot cancel an
earlier app scan.

This selects job execution, not Swift source files or queries. Full-target
Autobuild, default security queries, the default remote threat model and the
three language categories remain. No build cache, source exclusion or
architecture reduction was added. Repository default setup must stay disabled:
GitHub otherwise blocks advanced-workflow uploads. The
[migration guide](https://docs.github.com/en/code-security/how-tos/find-and-fix-code-vulnerabilities/configure-code-scanning/configuring-advanced-setup-for-code-scanning)
explains that prerequisite.

Local regression tests exercise the classifier, the actual workflow shell for
push/PR/manual/scheduled events, and the result gate. All 315 Python tests,
repository checks and workflow lint pass. The implementation commit `2ebf2cc`
also passed hosted [Watch checks](https://github.com/qayshp/TeachingTimer/actions/runs/43376780859)
and [release tooling/lint checks](https://github.com/qayshp/TeachingTimer/actions/runs/43376780882),
with the app build and publishing correctly skipped for this workflow/tooling
change.

Hosted migration validation passed:

| Case | CodeQL outcome | Wall time |
| --- | --- | ---: |
| [Security-workflow/router change, `2ebf2cc`](https://github.com/qayshp/TeachingTimer/actions/runs/43376780823) | Full Swift, Python and Actions analysis; final result passed. | 19m 12s |
| [Documentation-only follow-up, `36dda9b`](https://github.com/qayshp/TeachingTimer/actions/runs/43376973876) | Swift skipped; Python, Actions and final result passed. Earlier full scan continued. | 1m 15s |

The full scan retained Xcode 26.6 and the `TeachingTimerDistribution` build with
its Watch dependency. Its extracted database `629703228` contains all 29
production Swift files, byte-for-byte matching `2ebf2cc`; analysis `2158837602`
contains the same 27 security-rule IDs as the baseline, zero unresolved AST
nodes and no configured-query findings. This verifies source and rule inclusion,
not absence of every possible defect. Full-scan Autobuild took 17m 19s and
analysis/upload 1m 02s; variable worker performance is separate from routing.

Both follow-up Watch/release workflows passed, with no app build, signing or
publishing requested. Manual and scheduled force-full routing was exercised by
the actual workflow-shell tests; these two hosted runs were pushes, not calendar
or manual events. The baseline above remains the pre-migration measurement.
Database metadata, original source hashes, SARIF/rule comparisons and run/job
records are retained privately alongside the baseline evidence.

## Implemented: exact-source verification reuse

Automatic main-branch app releases no longer repeat the Watch workflow's complete
Mac verification. The release workflow resolves immutable source and inputs on
Ubuntu, then uses `scripts/reuse-watch-verification.py` to wait for the trusted
`.github/workflows/check.yml` **push to main** at that exact full SHA. Manual
rehearsal and publish keep fresh full Mac verification, including branch
rehearsals; PR results are never promoted into main-release evidence.

Reuse requires a completed successful workflow, successful Mac/required/repository
jobs, and applicable workflow lint. It binds the repository and head-repository
IDs, workflow ID/path, source SHA and run attempt. Exactly one unexpired
`verification-SHA-attempt` artifact must match those identities and GitHub's
SHA-256 digest. The consumer reads only the expected JSON report, without
extracting or executing archive contents, and bounds download/report sizes.

Report schema 2 includes CI identity and source state at both ends of verification.
Source must start and finish clean at the same revision. All 17 required stages
must occur exactly once and pass, including two-size booted smoke, runtime
preparation, native OCR/outline fixtures, model/tool suites and both unsigned
archive paths. Incomplete, mismatched, skipped, failed, cancelled, malformed or
expired evidence stops publication. A newer failed attempt cannot be replaced
by an older green result. The consumer rechecks the selected run/attempt after
download and records its origin, digest and wait duration in a receipt.

Pending work may be awaited for up to 40 minutes. An unavailable API or invalid
result fails visibly, with no automatic fallback that could bypass a failed
Watch run. Rerun the relevant checks or use a manual fresh-verification release.
No new signing credentials or privileged workflow trigger is involved. The
release job still requires validated source, the appropriate verification path,
and release-side checks before entering its environment. Signing, immutable-source
and archive/export checks, IPA identity, uncertain-upload handling and sole
Maintainer assignment are unchanged. CodeQL remains a separate workflow rather
than a new publication gate.

This saves one complete duplicate Mac pass for an automatic app release. It does
not promise a fixed wall-time reduction: the earlier two passes overlapped and
worker timing varies. Signed publishing still builds its own archive from source.
Read-only checks against existing GitHub evidence already reject a successful
docs-only run (`6f1d76e`, skipped Mac job) and a legacy full report (`b573bcd`,
missing schema-2 provenance). Neither negative test signs or publishes anything.

### November 13 validation

The implementation at
[`c14b1a24fc2d51836d13499ce3df5304b8164889`](https://github.com/qayshp/TeachingTimer/commit/c14b1a24fc2d51836d13499ce3df5304b8164889)
passed the following hosted checks. Wall time runs from workflow creation to
its final applicable job completing.

| Workflow | Wall time | Observed result |
| --- | ---: | --- |
| [Watch checks](https://github.com/qayshp/TeachingTimer/actions/runs/43392488060) | 17m 13s | All applicable jobs and all 17 verification stages passed. |
| [Release tooling/lint](https://github.com/qayshp/TeachingTimer/actions/runs/43392488017) | 28s | Passed; source resolution, reuse, manual verification and publishing were correctly skipped for a non-app change. |
| [CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/43392488119) | 20m 35s | Swift, Python, Actions and the final result passed. |

All 356 Python tests, repository checks and workflow lint passed. The schema-2
Watch report identifies the same full source SHA before and after verification,
both clean, and binds repository `1379015152`, the main-push workflow, run
`43392488060` and attempt `1`.

The actual consumer was also run read-only against GitHub while that producer
was still running. It waited for completion, downloaded and checked artifact
`14022690104`, and saved a receipt with `status=verified` and `verified=true`.
The artifact's verified digest was
`sha256:ce26060420e5c33fbf04bf3d3316e2d2fead9de59c873a12ac99ab6d3c7f39fe`.
The receipt records 1,037.587 seconds (17m 17.6s), including the wait for the
existing Watch job; this was not another Mac verification pass.

This establishes successful consumption of real GitHub metadata and a complete
schema-2 report. The automatic release workflow's reuse job was intentionally
skipped on this tooling-only push, so it does **not** establish a live app-candidate
release, signing, upload or TestFlight assignment through the new route. Routing
and failed/cancelled/missing-evidence gates are covered by the workflow-expression,
shell and consumer regression tests; those tests are separate from this live
successful read. Manual fresh-verification routing is likewise covered by tests,
not a new hosted manual event in this validation.

## Next optimizations, in order

1. **Parallelize small/large smoke on isolated workers.** All cases have useful
   purposes; keep them and their timing assertions. Two workers could overlap
   the per-size runs, but require the same app/runtime, both complete reports,
   failure propagation and owned-device cleanup. This is a measured experiment,
   not a claimed speedup. Direct threads are unsuitable because the runner
   installs process signal handlers; shared-host concurrency also needs a load
   check against the known awake-recovery issue #27.
2. **Use narrower native-tool verification where dependencies are known.**
   Helper-only edits could compile/run the native guards without rebuilding
   unchanged app archives and the full matrix. Unknown dependencies must select
   full checks, and pipeline/app changes plus manual full checks must retain
   appropriate coverage. This needs a tested dependency map, not blanket skips.
3. **Improve failure order before adding build concurrency.** Running native
   helpers/archives before the long booted matrix would report those failures
   sooner, without reducing successful-run duration. Later, measure bounded
   parallel host checks or independent builds with isolated outputs; avoid
   competing heavy compilation during timing-sensitive smoke observations.

Publisher serialization, source ordering and daylight-saving build-number policy
remain in [#24](https://github.com/qayshp/TeachingTimer/issues/24).

Keep the real OCR and outline checks: they exercise failure paths compilation
missed. Keep both packaging archives, cross-OS Python checks, fresh-process
recovery, explicit Stop, both page retirements, overdue launch, original images
and strict cleanup/evidence gates. Removing a few seconds of metadata or one
relaunch offers less benefit than eliminating duplicate complete verification.
No timer duration, observation period, security query or failure assertion was
removed in this pass. No physical device was used or build published.

Private timing manifests, original logs, validated verification artifacts and
CodeQL coverage evidence are under `work/ci-efficiency-2026-11-12/`.
The November 13 reuse receipt and validated report are under
`work/verification-reuse-2026-11-13/live-c14b1a2/`.
