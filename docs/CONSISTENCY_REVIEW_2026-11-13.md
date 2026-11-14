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

Interactive small/large action checks, original-image review, clean-source build
verification and hosted results are being completed for this review. Their exact
results will be recorded here; a build or state assertion alone does not establish
native playback, actual Crown ownership, haptic sensation or physical Always-On
cadence. No physical device is used or installed by this review.
