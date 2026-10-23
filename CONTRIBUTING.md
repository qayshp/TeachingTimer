# Working on Teaching Timer

Keep changes small and run `sh scripts/check.sh` plus a Watch Simulator build.
The project has no external package dependencies. Xcode's scheme does not
contain an XCTest target; the script compiles and runs nine standalone suites.
Do not claim hardware validation from a simulator or WatchKit test double.

## Preserve these boundaries

- Class schedule, mindfulness runtime, and landmark counting are independent.
- No HealthKit workaround, iPhone companion, custom media controls, or Crown gesture.
- Both hands remain wall-clock hands, discrete at the one-second timeline cadence,
  above controls. Never animate them with a high-frequency sweep.
- Count scheduling uses absolute `ContinuousClock` deadlines and a per-run ID.
  Cancellation must prevent old-generation pulses from leaking into a fresh run.
- Late vibrations can stop while the monotonic visual arc continues. Future
  Always-On frames use their requested timeline date, not a cached progress value.
- The native companion volume adapter's focus/resign sequence is regression-sensitive.
  Restore focus after sheets and Now Playing; test on a real paired Watch/iPhone.

## Visual checks

Check SE 3 40 mm first, then a larger Series and Ultra. Check class creation,
schedule correction, New/End class confirmation, active/silent counts, recovery,
Now Playing, and Lock. Debug launch arguments `--maximum-text`, `--large-text`,
and `--show-now-playing` aid inspection without automatically starting services.
`--show-class-setup` opens a new-class draft; add `--show-class-adjustments` to
inspect its secondary editor. These Debug-only flags do not start a class or
runtime, clear a saved class, or bypass replacement confirmation.
Check hands pointing through controls and markers at all four quarter-hours.
Record what was actually observed in `DEVELOPMENT_STATUS.md`.

The icon is original, deterministic drawing code. Regenerate it from the root
with `swift scripts/render-icon.swift`. Generated builds, user Xcode state,
credentials, profiles, and raw journals must not be committed. Curated, anonymous
Simulator screenshots belong in `docs/images/`.

## Release discipline

Increment `CURRENT_PROJECT_VERSION` for each distributed build. A build phase
also records Git revision (including a dirty suffix) and UTC build time in
`BuildInfo.plist`; launch journals include both. Source exports can supply
`SOURCE_REVISION` to that phase. `scripts/check-archive.sh` verifies the app is
present, but is not signed export, TestFlight, App Store privacy, or review approval.
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
