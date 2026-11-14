# Internal consistency review — November 13, 2026

Scope: user-facing wording and menu actions, Watch/optional-phone behavior,
current public documentation, historical evidence boundaries, diagnostic report
contracts, project packaging and release verification. This is a consistency
review, not a claim that the known native media/volume bugs are fixed.

## Corrections

- Help now describes both **Start session** and **Resume session**, matching the
  actual action after fresh-process recovery versus a session already started in
  this process. No runtime policy or scheduling code changed.
- Report privacy says raw **saved preference files** are excluded. The selected
  diagnostic fields can include configuration summaries such as class duration
  and whether count vibrations were enabled. The complete policy and Watch
  summary agree, including the exact **Full policy on Watch** menu label.
- Phone and Watch report tests require identical supported time windows and
  compatible report-size limits, guarding a silent fallback or rejected receipt
  after changing one side of the contract.
- Current onboarding, support, store drafts and release notes describe the
  optional iPhone support app and the implemented explicit report/email route.
  Teaching remains independent on Watch. Older native Watch sharing and empty
  distribution-container descriptions are marked historical.
- The roadmap and issue map distinguish the resolved blank-media/clock regressions
  from reopened timer-volume response and continuing frozen song progress.
- Verified server availability of build **261113.1031.57** is separate from the
  owner's later update/class report and the last independently parsed build-39
  journal. The owner did not specifically compare song progress in the latest
  class. The Utility dual-launcher setup is documented with genuine Simulator
  evidence and subsequent owner confirmation.
- Release/configuration comments and errors describe the actual optional iPhone
  distribution app, independent embedded Watch app and complication extension.
  Verification reuse has a later successful automatic app-release record;
  disposable Simulator installs are distinguished from physical installation.

## Behavior audit

| Requirement | Authoritative implementation and checks |
| --- | --- |
| Default/custom schedules agree with controls | `ClassContext`, `ClassControlsView`, class/time-edge model tests and Simulator default/edit/replacement actions. Default is 60 minutes; Custom schedule supports 60/75 and does not change future defaults. |
| Start/Edit/New/End and retirement remain distinct | `ClassStore` and `ContentView`: exact initial Start retained by edits; replacement requires confirmation; End clears timing and stops count/session; retirement is scheduled end plus 30 minutes. Controller/model and action checks cover the state transitions. |
| Session recovery preserves intentional Stop | `ExtendedRuntimeController`, `RuntimeIntentStore`, renewal/controller sequence tests and Simulator Stop/Resume checks. Recovery is bounded and native eligibility remains system-controlled. |
| Wall-clock hands and class perimeter agree | `WallClockDisplay`, `ClockAdditions`, clock/time-edge checks. Hands share whole-second wall time; the scheduled perimeter is only drawn for 60-minute classes. |
| Count timing and settings agree with Help | `LandmarkController` and deterministic controller tests: groups at 10–60 seconds, full arc at 60 seconds, completion at 64.8 seconds, next-run vibration setting, no old-generation submissions after cancellation. Late groups can be skipped without cancelling the whole arc. |
| Crown/media behavior stays independent | Retained `.companion` volume adapter and existing focus/refresh state; native media remains outside the clock timeline. This patch changes neither implementation. Focus callbacks are not claimed as audible-volume proof. |
| Report/send/receive/email wording agrees | `DiagnosticRequest`, `DiagnosticReport`, `DiagnosticReportFile`, `DiagnosticCompanion`, Watch/phone support views and report/request tests. Preparing, queueing, phone receipt and email delivery remain separate stages. |
| Packaging and publication claims agree | Project/plists/configuration, artifact checks and release scripts. Development identity is separate from distribution; publishing requires the existing immutable-source, verification, signing and audience gates. |
| Current and historical documents are distinguishable | Documentation index, current status/roadmap/issue map, source review and repository link/style/private-artifact checks. Dated experiments retain their original evidence and explicit superseding pointers. |

## Verification record

Local source builds pass for Watch Simulator and iPhone Simulator. All 16 Swift
suites and 375 Python checks pass. The two added request-contract assertions run
inside the existing Swift suite and are included in CI.

- **Clean-source verification:** all 15 stages passed at source `5ef55b902ea9`,
  with unchanged clean source before/after. This includes model/tool checks, QR
  decoding, synthetic control-outline/OCR checks, both Simulator apps, inspection
  helpers and unsigned development/distribution archives.
- **Interactive actions:** all 21 assertions passed on SE 3 40 mm and all 21 on
  Ultra 4 49 mm, both watchOS 27.2 (24S118), using the same candidate source with
  local Simulator version 58. Original Help/Privacy/About, session recovery and
  replacement/end confirmation images were inspected separately from OCR/state
  assertions. The tests reset only each named disposable Simulator's app data.
- **Direct copy inspection:** the clean-source SE 3 build displays both session
  action names in Help and the clarified preference-file exclusion in Report
  privacy. Navigation paths and scrolling work. This separate build retains the
  project's local default version 41; neither local number is a TestFlight
  publication claim.
- **Phone inspection:** the iOS 27.2 (24B8117) Simulator displays the optional
  support interface, saved synthetic report, all three time-window choices and
  About & privacy. The unconfigured-Mail path presents the expected alternative
  rather than an unusable composer. No email, new report request or device
  transfer was attempted. The existing synthetic report is UI evidence only.
- **Bundled documents:** privacy policy, license and web-link definitions match
  current repository bytes in the Simulator app and both archives (nine resource
  comparisons). QR decoding is also part of the clean verification.
- **Additional setting/schedule checks:** SE 3's native duration picker saved a
  75-minute class, which survived relaunch unchanged. Count vibrations off and
  Minutes left on persisted without changing that class; the label displayed
  the expected minutes left. A silent count completed naturally with no
  acknowledgement or timing-haptic submissions in its run's journal. Its status
  temporarily replaced the minutes label with Visual count, as now documented.
  The next New class draft still offered 60 minutes and did not replace the
  saved 75-minute class. End class subsequently cleared class/runtime intent.
- **Hosted checks:** [Watch verification](https://github.com/qayshp/TeachingTimer/actions/runs/43532671048),
  [CodeQL](https://github.com/qayshp/TeachingTimer/actions/runs/43532671062) and the
  [automatic release](https://github.com/qayshp/TeachingTimer/actions/runs/43532670947)
  use the same immutable source. Watch verification passed all 17 stages,
  including booted SE 3 and Ultra runtime/recovery/retirement smoke checks. The
  retained report records clean unchanged source before/after and both smoke
  results complete. CodeQL passed Actions, Python, the full Swift production
  build/analysis and its final result gate.
- **Signed release:** the automatic release completed exact-source verification
  reuse, signing/export, upload, Apple VALID, test-note/group readback and
  Maintainer IN_BETA_TESTING for **1.0 (261113.1613.59)**, source `5ef55b902ea9`.
  Availability was confirmed November 13 at 16:32:24 PST, 93.544 seconds after
  the upload command succeeded. Its report explicitly records no installation
  or physical-device contact. Subsequent documentation-only updates skip a
  second publication.

A build or state assertion alone does not establish native playback, actual
Crown ownership, haptic sensation or physical Always-On cadence. This review does
not close those separate reliability issues. No physical device was used,
installed or launched by this review.


## Completion audit

The requirements in the behavior table have current source, model/controller,
rendered-menu or artifact evidence as appropriate. Help names the actual actions;
privacy and delivery instructions describe the implemented report boundaries;
current guides follow current menus; historical documents identify their older
scope; issue and release claims agree with their authoritative records. The
source and runtime assertions were verified independently of screenshot review.

The review required no scheduling, state-machine, media, Crown or geometry change.
Known native-media/volume reliability, hardware accessibility/battery testing,
external-beta installation and Apple guidance remain explicit separate work;
they are not represented as completed by this consistency pass. The final
publication/install claims remain bounded to the verified records above.
