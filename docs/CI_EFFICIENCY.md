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
Watch checks retain their existing Mac gate. The release workflow repeats full
verification only for an app candidate (`mac_verify && publish`) or a manual
rehearsal/publish using `--all`.

Native-tooling pushes still get the complete Watch verification and cheap
release-side repository/Python checks, but no second Mac matrix/archive pass.
App/unknown-input pushes and manual rehearsals keep their previous verification.
The publication job still requires successful release verification; the
credential-bearing environment and group assignment are unchanged.

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

## Next optimizations, in order

1. **Scope expensive Swift CodeQL runs to relevant changes.** The current
   repository default setup rebuilds production Swift even for documentation
   and native test-helper changes. An explicit workflow could retain
   relevant Python/Actions analysis and full Swift scans for app, dependency,
   project and security-workflow changes, plus scheduled/manual full scans.
   Scope job execution, not the production files included in a Swift scan.
   Compare extracted-source coverage, queries and required-check behavior before switching. Current
   companion coverage is complete; there is no need to repair a coverage gap.
2. **Reuse exact-source verification for actual app releases.** The two full
   passes still exist for publishing app pushes. One verified main-branch result
   could serve both, but it must bind the repository, trusted workflow, source
   SHA, successful applicable checks and evidence provenance. PR and post-merge
   verification remain distinct. Publication currently waits for its own full
   verification/lint, not the separate Watch Required result or CodeQL; decide
   the desired publication gates explicitly. Ordering remains [#24](https://github.com/qayshp/TeachingTimer/issues/24).
3. **Parallelize small/large smoke on isolated workers.** All cases have useful
   purposes; keep them and their timing assertions. Two workers could overlap
   the per-size runs, but require the same app/runtime, both complete reports,
   failure propagation and owned-device cleanup. This is a measured experiment,
   not a claimed speedup. Direct threads are unsuitable because the runner
   installs process signal handlers; shared-host concurrency also needs a load
   check against the known awake-recovery issue #27.
4. **Use narrower native-tool verification where dependencies are known.**
   Helper-only edits could compile/run the native guards without rebuilding
   unchanged app archives and the full matrix. Unknown dependencies must select
   full checks, and pipeline/app changes plus manual full checks must retain
   appropriate coverage. This needs a tested dependency map, not blanket skips.
5. **Improve failure order before adding build concurrency.** Running native
   helpers/archives before the long booted matrix would report those failures
   sooner, without reducing successful-run duration. Later, measure bounded
   parallel host checks or independent builds with isolated outputs; avoid
   competing heavy compilation during timing-sensitive smoke observations.

Keep the real OCR and outline checks: they exercise failure paths compilation
missed. Keep both packaging archives, cross-OS Python checks, fresh-process
recovery, explicit Stop, both page retirements, overdue launch, original images
and strict cleanup/evidence gates. Removing a few seconds of metadata or one
relaunch offers less benefit than eliminating duplicate complete verification.
No timer duration, observation period, security query or failure assertion was
removed in this pass. No physical device was used or build published.

Private timing manifests, original logs, validated verification artifacts and
CodeQL coverage evidence are under `work/ci-efficiency-2026-11-12/`.
