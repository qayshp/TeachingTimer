# Teaching Timer — current verification

Updated October 31, 2026. This is the authority for current build and validation
status. Dated investigations describe their original builds, not current behavior.

| Item | Status |
| --- | --- |
| Source candidate | 1.0 (26): repository cleanup and Settings return-navigation fix; build/offline verification passed; interactive navigation pending. |
| Installed physical Watch | 1.0 (25), installed, independently version-verified and launched October 30. |
| Latest classroom evidence | Build 23, October 30: Pause and volume worked; song progress became stale twice near class end and recovered temporarily after page switching. |
| Preserved rollback | Build 16 signed local checkpoint. It has known intermittent media/volume issues; it is not a guarantee of reliability. |
| Distribution | No TestFlight upload or public release. Distribution identifier: `net.qays.TeachingTimer`; development: `com.qayshp.TeachingTimer`. |

## Current behavior and limits

- Two pages: squircle teaching clock and native Now Playing. Both clock hands
  remain wall-clock hands drawn above controls.
- Settings is available before and during class: Count vibrations (next count)
  and Minutes left. Preferences persist. See [build 25 screenshots](docs/SETTINGS_PASS_25.md).
- Native media refreshes on page entry, eligible background return, and active,
  undimmed wake after at least 30 seconds dimmed with a 60-second refresh cooldown.
  This is prevention, not failure detection. [Policy](docs/MEDIA_WAKE_REFRESH.md).
- Persistent class timing, runtime intent and monotonic counts remain independent.
  Intentional Stop survives reopening; a rejected recovery exposes Resume.
- Build 25 settings and wake-refresh classroom reliability remain unvalidated.
  A settings toggle or completed focus callback is not proof of physical effects.

## Open priorities

1. Incorrect native song progress with working Pause/volume: [incident](docs/MEDIA_PROGRESS_INCIDENT_2026-10-30.md), Apple FB25379883, [issue #8](https://github.com/qayshp/TeachingTimer/issues/8).
2. Intermittent blank native media, timer Crown response and unintended silencing:
   separate tracked defects, not established manifestations of one cause.
3. Automatic runtime recovery after dimmed Simulator relaunch: manual-recovery
   intent was retained after watchOS rejected start. Physical reproduction pending.
4. Seconds-hand backstep at dim/wake: separate Apple report; no speculative time correction.
5. TestFlight journal access/private support, signed pilot, and publishing metadata.

See the [issue map](docs/ISSUE_TRACKER.md), [Apple receipts](docs/APPLE_FEEDBACK.md),
[roadmap](docs/ROADMAP.md), and [publishing readiness](docs/PUBLISHING_READINESS.md).

## Verification and deployment boundaries

Build 26 passes 12 Swift suites, 85 Python tests, repository validation, Simulator
compilation and unsigned development/distribution archive rehearsals. Interactive
Settings navigation remains pending: Simulator discovery timed out. No physical
installation or playback test was performed.
The [supervised device-test plan](docs/PHYSICAL_MEDIA_TEST_PLAN.md) is a proposal;
no unattended run is scheduled.

October 30 collection is complete: three journals and both sysdiagnoses validated.
The Watch archive is 150,136,890 bytes with 582 system-log files. Unlocking and
launching succeeded while it remained on the charger through Device Hub's virtual
Crown/passcode interaction. Removing it from the charger was not required.
Transfer completion, screen sharing, installation and launch are distinct outcomes.

## Historical evidence

[Verification through build 25](docs/history/VERIFICATION_THROUGH_BUILD_25.md)
preserves earlier test results and deployment chronology.
[October 29 repository review](docs/REPOSITORY_REVIEW_2026-10-29.md) records the
12-suite/80-test verification and earlier interactive runs. Historical passes do
not close intermittent physical bugs. The latest physical build is stated above.
