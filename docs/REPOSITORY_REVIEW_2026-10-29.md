# Repository review and automation follow-through

October 29, 2026. This maintenance pass preserves build 22's production app
source and build number. Build 16 remains the physical teaching checkpoint;
the maintainer reported a successful class around 1:15 p.m. on October 28.
No physical Watch/phone connection, install or launch is part of this review.

## Organization and consistency

- The [documentation map](README.md) distinguishes current guidance, dated
  investigations, visual evidence and historical records. Existing paths are
  preserved so issue/Feedback links do not break.
- Contributor guidance describes source, tests, tools, public screenshots and
  private evidence. Stale suite counts, completed-work recommendations and
  ambiguous historical screenshot interpretations are corrected.
- Original journals, signed checkpoints, screenshots and build outputs remain
  in ignored local storage. A private `work/README.md` explains their layout;
  this is not a blanket deletion or publication of diagnostic evidence.
- Production review did not establish a correctness defect requiring a behavior
  change. Native media/volume lifecycle, class/runtime/count semantics and the
  teaching face remain unchanged.

## New regression coverage

- Exhaustive quarter-hour minute positions with whole/fractional seconds.
- All early-renewal eligibility gates and expiration classification boundaries.
- Invalid and duplicate count starts; cancelled arc-only completion cannot stop
  a newer run.
- Journal failed-write retry without a new event, bounded pending history and
  Unicode details, duplicate-free flush and concurrent producer ordering.
- Repository local links, source notices, Python/configuration parsing, private
  artifact exclusion and standalone Swift suite wiring.
- A combined serial Simulator runner with bounded stages, required evidence,
  artifact identity, a single-run lock, and failure reports. Fresh-app reset
  errors and lost journal boundaries cannot silently produce a passing result.
- A separate actual-process relaunch runner checks automatic recovery and
  persistent intentional Stop while preserving class bytes.
- Count/Lock captures include normal completion of a full-duration locked run.
  Completion events prove controller state, not physical tactile delivery.

## Verification

All 12 Swift suites and 80 Python checks pass. Simulator compilation and both
unsigned archive rehearsals pass. Each simulator passes 14 essential actions,
33 count/Lock captures and the full-duration count. SE 3 additionally passes six
focus/lifecycle assertions. Awake relaunch checks pass on both sizes. The
post-run locked-count journal validator passes on the original captures; future
runs require it automatically. Text-recognition flags remain review evidence,
not visual failure assertions. See [current status](../DEVELOPMENT_STATUS.md)
for exact results and the separate dimmed-relaunch failure.
The [automation map](AUTOMATION.md) distinguishes deterministic checks, builds,
interactive Simulator runs and remaining physical validation. Private run
artifacts are retained under `work/support/2026-10-29-repository-review/`.

The first new reset check rejected Xcode's OpenStep-format app inventory before
modifying the test app. It now uses the system plist converter; a real-format
contract test guards this parser. This was a harness failure, not an app bug.

An initial repository-check run rejected links to new files not yet staged in
Git. Staging the intended public documents resolved it; private/untracked files
must not make published links appear valid.

## Locked relaunch observation

The first new process-relaunch run followed the full locked-count check. Its
new launch reported native application state active, but SwiftUI appearance
reported an inactive scene and reduced luminance. Automatic runtime recovery
was attempted; watchOS rejected it with `WKExtendedRuntimeSessionErrorDomain`
code 3 (the app must be active). The existing policy then saved manual-recovery
intent. The saved class was retained.

This failed run is preserved separately; it is not counted as a passing awake
relaunch or attributed to an audio/volume bug. The awake test now requires a
journal-confirmed active scene and non-reduced luminance before terminating the
process. A separate investigation should establish whether startup eligibility
can be deferred safely without defeating intentional Stop or retry limits.
No runtime policy was changed in this maintenance pass.

## Remaining boundaries

No claim of exhaustive coverage is made. Hardware Crown ownership, real iPhone
volume/audibility, physical haptics, battery/runtime endurance and VoiceOver
navigation remain separate checks. No new fix for intermittent native blank
media, silencing or the Always-On hand backstep is implied by this maintenance.
