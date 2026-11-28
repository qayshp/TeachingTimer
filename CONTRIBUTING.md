# Working on Teaching Timer

## Which checks to run

| Change | Checks |
| --- | --- |
| Docs | `python3 scripts/check-repository.py` verifies local links, source notices, and structured files. |
| Tooling | Also run `sh scripts/check-tools.sh`. |
| App, Swift tests, or build inputs | Run `sh scripts/check.sh` and build the affected Simulator target. `docs/PRIVACY.md` and `LICENSE` are bundled app inputs. |
| iPhone companion | Also build `TeachingTimerTestFlight` for iPhone Simulator. It builds the embedded Watch target with the Watch SDK. |
| Candidate verification | With clean, committed source, run `python3 scripts/verify-build.py work/verification-new` for the combined checks, builds, and unsigned archives. |

The model checks compile standalone Swift test suites. The
[automation map](docs/AUTOMATION.md) explains CI routing, the interactive
Simulator runner, and how to record physical evidence separately.

## Source style and compiler diagnostics

Use four spaces for Swift, Python and shell source, LF line endings, a final
newline and no trailing whitespace. `.editorconfig` records these defaults;
repository checks enforce source hygiene and parse tracked shell scripts without
executing them. Markdown hard-break spaces are preserved. Keep formatting changes
focused on the code being edited instead of reformatting unrelated files.

Debug, Release and TestFlight builds enable complete Swift concurrency checking
and treat Swift compiler warnings as errors. Standalone model checks, diagnostic fixtures and inspection helpers also reject
compiler warnings. The language mode remains Swift 5; this is not a Swift 6
migration. Native WatchKit sessions are not declared `Sendable`: delegate callbacks
carry a private immutable identity token, and native state is accessed only on
the controller's main actor.

Xcode 27.2 still emits `Metadata extraction skipped, no AppIntents.framework
dependency found` from Apple's metadata tool. Teaching Timer declares no App
Intents. Keep that tool diagnostic visible; do not add an unused framework or
suppress unrelated warnings just to remove it.

## Repository layout

- `TeachingTimer/`: production watchOS source, shared diagnostic transport/model,
  assets and privacy manifest.
- `PhoneSupport/`: optional iPhone report-request and email interface. Teaching
  features must remain independent on the Watch.
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

Use the README for current behavior, the tester guide for the public beta,
`DEVELOPMENT_STATUS.md` for verification and `docs/ROADMAP.md` for remaining work.
List each top-level guide in the [documentation index](docs/README.md). Use
relative links within the repository. Record corrections with supporting
evidence and preserve dated build, tool, and observation records.

## Preserve these boundaries

- Class schedule, mindfulness runtime, and landmark counting are independent.
- No HealthKit workaround, custom media controls, or Crown gesture. The optional
  iPhone companion is limited to diagnostics; it must not own teaching state.
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
any interactive or physical checks separately. As of November 28, main has no
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

Private artifacts use ignored `work/` folders. Follow
[local artifact organization](docs/LOCAL_ARTIFACTS.md); inventory before removing
generated outputs and preserve original journals/captures and signed checkpoints.
See [publishing readiness](docs/PUBLISHING_READINESS.md) and the
[supervised device plan](docs/PHYSICAL_MEDIA_TEST_PLAN.md) before distribution or
physical automation work.

## TestFlight notes

For tester-visible changes, update [the short TestFlight notes](TestFlight/README.md)
alongside [the changelog](CHANGELOG.md). Notes describe recent merged changes and
known limitations, not unverified fixes. Notes-only changes run lightweight
checks and are used by the next release without creating another app upload.
