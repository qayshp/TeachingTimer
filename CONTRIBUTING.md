# Working on Teaching Timer

Keep changes small and run the checks appropriate to the affected files. For
documentation-only edits, run `python3 scripts/check-repository.py`; tooling
changes also need `sh scripts/check-tools.sh`. App, Swift-test or build-input
changes need `sh scripts/check.sh` plus a Watch Simulator build. The
[automation map](docs/AUTOMATION.md) explains how CI selects those checks.
The bundled `docs/PRIVACY.md` and `LICENSE` are app inputs, even though they are
documents; changes to them need app verification.
The project has no external package dependencies. Xcode's scheme does not
contain an XCTest target; the script compiles and runs standalone Swift suites.
Do not claim hardware validation from a simulator or WatchKit test double.
See the [automation map](docs/AUTOMATION.md) for coverage and the combined
interactive Simulator runner. `python3 scripts/check-repository.py` checks
published local links, source notices and structured files without device access.

## Repository layout

- `TeachingTimer/`: production watchOS source, assets and privacy manifest.
- `TeachingTimer.xcodeproj/` and `Configurations/`: shared project/build settings;
  keep developer-specific Xcode state and signing material out of Git.
- `Tests/`: deterministic Swift checks, WatchKit boundary doubles and Python
  tooling tests. New tests should check behavior or failure handling rather than
  duplicate implementation details.
- `scripts/`: local/CI build checks, artifact inspection and diagnostic tools.
- `tools/`: isolated native probes and opt-in interactive Simulator runners.
  These are not production dependencies.
- `docs/`: maintained guides, dated evidence and curated Simulator images;
  use the [documentation index](docs/README.md) to find the current authority.
- Ignored `work/` and `outputs/`: private captures, local experiments, generated
  builds and evidence. Inventory before cleanup; never delete a known-good
  signed checkpoint or irreplaceable incident capture as routine tidying.

## Documentation maintenance

Keep current behavior in the README/tester guide, current verification in
`DEVELOPMENT_STATUS.md`, and remaining work in `docs/ROADMAP.md`. Add new guides
to the documentation index. Dated investigations describe the source and tools
used then; do not silently rewrite their counts, versions or observations to
match a later build. Put corrections prominently in the affected record and
link the supporting audit. Use relative links within the repository, and never
publish private capture paths as downloadable evidence or commit raw journals.

## Preserve these boundaries

- Class schedule, mindfulness runtime, and landmark counting are independent.
- No HealthKit workaround, iPhone companion, custom media controls, or Crown gesture.
- Both hands remain wall-clock hands, discrete at the one-second timeline cadence,
  above controls. Never animate them with a high-frequency sweep.
- Count scheduling uses absolute `ContinuousClock` deadlines and a per-run ID.
  Cancellation must prevent old-generation pulses from leaking into a fresh run.
- Late pulses retain spacing; obsolete groups are skipped without stopping the
  monotonic visual arc or disabling later groups. Future
  Always-On frames use their requested timeline date, not a cached progress value.
- The native companion volume adapter's focus/resign sequence is regression-sensitive.
  Restore focus after sheets and Now Playing; test on a real paired Watch/iPhone.

## Simulator versions

Follow the [runtime policy](AGENTS.md). Select the newest available compatible
iOS/watchOS runtimes from the current Xcode; discover identifiers live. Create
devices only when a task needs them. Old test UUIDs and runtime versions in dated
evidence are not instructions to recreate that environment.

## Visual checks

Check SE 3 40 mm first, then a larger Series and Ultra. Check class creation,
schedule correction, New/End class confirmation, active/silent counts, recovery,
Now Playing, and Lock. Debug launch arguments `--maximum-text`, `--large-text`,
and `--show-now-playing` aid inspection without automatically starting services.
`--show-class-setup` opens a new-class draft; add `--show-class-adjustments` to
inspect its secondary editor. These Debug-only flags do not start a class or
runtime, clear a saved class, or bypass replacement confirmation.
Check hands pointing through controls and markers at all four quarter-hours.
`--show-settings` opens Settings without starting a class.
Record what was actually observed in `DEVELOPMENT_STATUS.md`.

The icon renderer uses the tracked rolled-mat/timer artwork and adds distinct
Beta/Dev badges. Regenerate all three variants from the root with
`swift scripts/render-icon.swift`; see [asset provenance](docs/DISTRIBUTION_METADATA.md#bundled-asset-provenance).
Generated builds, user Xcode state,
credentials, profiles, and raw journals must not be committed. Curated, anonymous
Simulator screenshots belong in `docs/images/`.

The in-app full privacy policy and license are copied directly from
`docs/PRIVACY.md` and `LICENSE` by Xcode; do not maintain duplicate copies.
Website addresses/titles live in `TeachingTimer/Information/WebLinks.json`.
After changing an address, run
`swift scripts/information-qr.swift --generate TeachingTimer/Information`.
The combined build check decodes the committed QR images and checks the bundled
documents. Inspect the local Settings pages and their Back navigation after
changes; a functioning website is not proof that a Watch can launch a browser.

## Release discipline

Use a pull request for outside contributions. Before merging, require successful
Watch checks and CodeQL for the proposed revision, review the diff, and record
any interactive or physical checks separately. As of November 2, main has no
enforced branch rule; this procedure is a maintainer obligation until
[the safeguard follow-up](https://github.com/qayshp/TeachingTimer/issues/14)
establishes required checks with a tested maintainer recovery path.

For public beta milestones, tag the exact signed source as `v1.0-beta.BUILD`
and publish concise GitHub prerelease notes. Include the source revision,
validated local export digest, test scope and actual distribution stage.
A review candidate is labeled awaiting review; a GitHub release does not mean
Apple approved a build. Apple may repackage TestFlight downloads, so a local
export digest does not identify the downloaded bytes. Never attach signing
materials, private archives or raw diagnostics. The
[build-37 record](https://github.com/qayshp/TeachingTimer/releases/tag/v1.0-beta.37)
is the first such milestone.

Every distributed build needs a unique `CURRENT_PROJECT_VERSION`. The automatic
release workflow supplies `YYMMDD.HHmm.sequence` in Pacific local time (including
daylight-saving changes); manual release tooling accepts the same format or a
positive integer. Do not
change the checked-in project version merely to allocate an automatic release.
A build phase
also records Git revision (including a dirty suffix) and UTC build time in
`BuildInfo.plist`; launch journals include both. Source exports can supply
`SOURCE_REVISION` to that phase. `scripts/check-archive.sh` verifies the app is
present, but is not signed export, TestFlight, App Store privacy, or review approval.
For distribution, use the separate `TeachingTimerTestFlight` scheme and follow
[the signed export/pilot procedure](docs/TESTFLIGHT_PREPARATION.md). It keeps the
development identity intact and checks the outer distribution container plus
the embedded Watch app. A successful local export is not an upload or an
installation through TestFlight.
Do not amend known-good teaching checkpoints or install on someone's Watch
without an explicit request.

Describe the Watch size/OS, app revision, steps, expected/actual behavior, and
whether runtime/count were active when reporting a problem. Don't post raw logs
publicly without reviewing timestamps and error details for personal information.
For blank pages or timer-page silencing, also follow the
[interface diagnostics notes](docs/INTERFACE_DIAGNOSTICS.md). Do not interpret a
focus-call return or an appearance callback as proof of actual focus or pixels.

## License

Contributions to this project are under the [Mozilla Public License 2.0](LICENSE).
Preserve existing license notices and add the MPL notice to new source files.
Before including third-party material, verify license compatibility and retain
its required notices; do not relabel someone else's work as MPL.

## Maintaining public and private records

Every top-level guide belongs in the documentation index. Label dated evidence
with build, environment and limitations; update current status when deployment
changes instead of rewriting historical results. Repository checks validate local
Markdown/HTML image links and guide coverage.

Private artifacts use ignored `work/` folders. Follow
[local artifact organization](docs/LOCAL_ARTIFACTS.md); inventory before removing
generated outputs and preserve original journals/captures and signed checkpoints.
See [publishing readiness](docs/PUBLISHING_READINESS.md) and the
[supervised device plan](docs/PHYSICAL_MEDIA_TEST_PLAN.md) before distribution or
physical automation work.
