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
| Repository | Tracked local Markdown targets, source notices, Python syntax, JSON/plist parsing, standalone Swift suite wiring and private/generated-file exclusions. | Does not validate remote URLs or Markdown heading fragments, prove legal compliance, or inspect ignored private evidence. |
| Swift models/controllers | Class anchoring/persistence, clock edges, geometry/layout, runtime intent/renewal, landmark deadlines/cancellation/restart, journal retention and volume/media policies. | Standalone executables use WatchKit boundary doubles; they cannot establish watchOS acceptance or physical effects. |
| Python tooling | Device command failures/retries, journal summaries, build inspection, action/evidence classification and suite result handling. | Device/process boundaries are faked. Test success is not a successful transfer or deployment. |
| Build/archive | Simulator compilation plus structural inspection of development and future distribution archives. | Unsigned archive success is not signed distribution, installation, launch or App Store validation. |

GitHub Actions runs the noninteractive verification with its recorded toolchain.
See [build evidence](BUILD_VERIFICATION.md) for retained artifacts. It does not
drive an interactive Device Hub session or touch physical devices.

## Interactive Simulator checks

Use the [combined regression suite](../tools/simulator-regression/README.md#run-the-combined-suite)
for serial essential-action, optional lifecycle and count/Lock checks. It requires
Device Hub and explicit selection of a booted disposable test simulator; the
test app's data is reset. Run each size separately, never concurrently through
the same UI.

- **Essential actions:** create/cancel/edit/replace/end classes, count start/stop,
  runtime Stop/Resume and media/timer navigation, checked against saved values
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
- Build 16 remains the physical teaching checkpoint. Simulator reset authority
  does not authorize a Watch install. Signed/TestFlight deployment and journal
  access remain separately verified workflows.

Record the actual command, source revision, toolchain and retained results in
[current status](../DEVELOPMENT_STATUS.md). Keep dated test counts and observations
in their original reports; do not turn an unrun test or a bounded success into
a claim of complete coverage.
