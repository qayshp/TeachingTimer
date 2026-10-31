# Documentation map

This index separates current guidance from dated evidence. Start with
[Teaching Timer's quick start](../README.md),
[current build and verification status](../DEVELOPMENT_STATUS.md), and the
[active roadmap](ROADMAP.md). The physical teaching checkpoint and the newest
Simulator candidate are different artifacts; a successful build is not an
installation or a physical-device test.

## Using and contributing

| Document | Purpose |
| --- | --- |
| [Tester guide](TESTER_GUIDE.md) | Before-class checks, everyday controls and recovery choices. |
| [Privacy](PRIVACY.md) | Local storage, retention and diagnostic sharing boundaries. |
| [Contributor guide](../CONTRIBUTING.md) | Repository layout, behavior boundaries and maintenance rules. |
| [Teaching checkpoint](TEACHING_CHECKPOINT.md) | Preserved build 16 provenance and private recovery artifacts. |
| [Active roadmap](ROADMAP.md) | Completed work and remaining Simulator, physical and distribution gates. |

## Building and testing

| Document | Purpose |
| --- | --- |
| [Repository review](REPOSITORY_REVIEW_2026-10-29.md) | October 29 organization, test additions and verification boundaries. |
| [Automation map](AUTOMATION.md) | Offline/CI, interactive Simulator and physical evidence boundaries. |
| [Build verification](BUILD_VERIFICATION.md) | Reproducible build/archive checks and artifact inspection. |
| [Simulator regression runner](../tools/simulator-regression/README.md) | Interactive lifecycle, action, focus and rendering checks with bounded evidence capture. |
| [Device Hub testing](DEVICE_HUB_TESTING.md) | Lock/Always-On, haptic sound and remote-input limits. |
| [Time-edge checks](TIME_EDGE_TESTS.md) | Scheduled-time, clock-change and monotonic-count cases. |
| [Essential-action run](ESSENTIAL_ACTION_CHECKS.md) | Build 18 action sequence and historical results; use current status for later runs. |
| [Form-factor validation](FORM_FACTOR_VALIDATION.md) | Dated multi-size visual checks, not hardware certification. |
| [Native volume probe](../tools/native-volume-probe/README.md) | Isolated companion-volume experiment. |
| [Timeline probe](../tools/timeline-clock-probe/README.md) | Isolated Always-On clock experiment. |

## Current additions

- [Publishing readiness](PUBLISHING_READINESS.md): onboarding and outstanding release gates.
- [Supervised physical media plan](PHYSICAL_MEDIA_TEST_PLAN.md): preparation only; no run scheduled.
- [Settings pass](SETTINGS_PASS_25.md): build 25 screenshots and limits.
- [Media wake refresh](MEDIA_WAKE_REFRESH.md): current bounded recovery policy.
- [October 29 progress incident](MEDIA_PROGRESS_INCIDENT_2026-10-29.md) and
  [October 30 progress incident](MEDIA_PROGRESS_INCIDENT_2026-10-30.md): physical reports and log correlations.
- [Repository maintenance, October 29](REPOSITORY_REVIEW_2026-10-29.md) and
  [October 31 cleanup](REPOSITORY_REVIEW_2026-10-31.md): scope, results and remaining work.

- [Local artifacts](LOCAL_ARTIFACTS.md): private catalogs, evidence and generated outputs.

## State and diagnostics

| Document | Purpose |
| --- | --- |
| [Runtime recovery](RUNTIME_RECOVERY.md) | Persistent session intent and intentional Stop semantics. |
| [Late landmark haptics](HAPTIC_DELAYS.md) | Current scheduling policy, its introduction and subsequent cleanup. |
| [Persistence diagnostics](PERSISTENCE_DIAGNOSTICS.md) | Saved-state failures and preserved recovery copies. |
| [Journal retention](JOURNAL_RETENTION.md) | Build 17 storage bounds and synthetic multi-class capacity tests. |
| [Interface diagnostics](INTERFACE_DIAGNOSTICS.md) | Event meanings, historical schema differences and limits on inference. |
| [Diagnostic tools](DIAGNOSTIC_TOOLS.md) | Bounded journal copies, authorized installs and offline summaries. |
| [Watch log collection](WATCH_LOG_COLLECTION.md) | System logs, developer connections and collection history. |
| [View split](VIEW_SPLIT.md) | Build 19 presentation refactor and preserved shared state. |

## Bugs and evidence

[GitHub issues](ISSUE_TRACKER.md) track project work;
[Apple feedback](APPLE_FEEDBACK.md) records submissions and the last observed
Apple responses. The two trackers do not establish a root cause or a fix.
Read corrections before relying on earlier screenshot descriptions.

| Topic | Evidence and limits |
| --- | --- |
| Original black-media pixels and later misclassification | [Image audit](MEDIA_IMAGE_AUDIT.md), [Apple correction](APPLE_MEDIA_UPDATE_2026-10-28.md), [superseded recovery comparison](MEDIA_RECOVERY_COMPARISON.md). |
| Native media service loss and recovery | [Service-loss reproduction](NOW_PLAYING_SERVICE_RECOVERY.md), [earlier force-close/class-persistence test](SIMULATOR_MEDIA_RECOVERY.md). |
| Historical page failures | [Sequence reconstruction](BLANK_PAGE_RECONSTRUCTION.md), [exact Lock/reentry test](EXACT_LOCK_REENTRY_TEST.md), [timer-control correction](TIMER_CONTROL_INVESTIGATION.md). |
| Physical media and volume incident | [October 23 timeline](MEDIA_INCIDENT_2026-10-23.md). |
| Volume availability and focus | [Availability investigation](VOLUME_AVAILABILITY_INVESTIGATION.md), [retained-control comparison](SIMULATOR_VOLUME_FOCUS.md), [tap-to-refresh behavior](VOLUME_CONTROL_RECOVERY.md). |
| Paired Simulator media discovery | [Clean-pair tests](PAIRED_SIMULATOR_MEDIA_TEST.md); no validated companion-media baseline. |
| Seconds-hand transition | [Always-On investigation](ALWAYS_ON_HAND_TRANSITION.md); Simulator and physical evidence stay separate. |

## Usability and screenshots

- [Build 22 review](USABILITY_PASS_22.md): Suggested time, action wrapping,
  accessibility and the hand-label experiment.
- [Builds 20–21 follow-up](USABILITY_FOLLOWUP_2026-10-28.md): neutral volume
  refresh acknowledgement and saved-class recovery notice.
- [Build 16 versus 19](BUILD_16_VS_19.md) and its
  [usability review](USABILITY_REVIEW_BUILD_19.md): original side-by-side captures
  with the missing-control interpretation corrected.
- [October 26 review](USABILITY_REVIEW_2026-10-26.md): earlier action-button and
  large-text changes.
- [Icon drafts](design/icon-drafts/README.md): design alternatives, not installed icons.

`images/` contains curated Simulator captures referenced by these records.
Their times, build versions and test settings vary. Do not relabel an older
image as the current build or infer successful audio/haptics from visible controls.

## Distribution preparation

- [TestFlight preparation](TESTFLIGHT_PREPARATION.md): separate application
  identity, unsigned rehearsal and outstanding signed-pilot/journal-access gates.
- [Distribution metadata draft](DISTRIBUTION_METADATA.md): review before any upload.

## Historical archive

These records preserve past decisions and results rather than define current
behavior:

- [Prototype notes](history/PROTOTYPE_NOTES.md)
- [Original review notes](history/REVIEW_NOTES.md)
- [Verification through build 25](history/VERIFICATION_THROUGH_BUILD_25.md)
- [Verification through build 16](history/VERIFICATION_THROUGH_BUILD_16.md)
- [Roadmap batches 17–21](history/ROADMAP_BATCHES_17_TO_21.md)

Other dated investigations retain their existing paths so issue/report links
remain stable. Raw journals, private device captures, generated builds and signed
checkpoints belong in ignored local storage; they are not public documentation.
