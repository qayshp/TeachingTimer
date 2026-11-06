# Runtime recovery after reopening

**November 6 resolution:** [issue #7](https://github.com/qayshp/TeachingTimer/issues/7)
is closed as fixed for the reproduced premature Start during dimmed relaunch.
Builds 31–32 gate recovery on both scene and native readiness; the matched
Simulator comparison below recovered on wake. Eight additional persisted-intent
tests in `73d3cbd` exercise both readiness orders, saved Stop/manual recovery,
unchanged class bytes and the captured code-3 error without a retry loop.
All 13 Swift suites pass. The boundary doubles verify controller responses,
not native callback delivery; broader physical reliability remains in #10.
Reopen #7 for a recurrence of the corrected defect. Dated findings below retain
their original evidence limits.

Later in the same review, hosted watchOS 26.5 testing rejected an **awake**
relaunch despite both readiness gates reporting active. This distinct case is
[#27](https://github.com/qayshp/TeachingTimer/issues/27), not evidence that a
dimmed Start bypassed the corrected guard. See the [current review](ISSUE_REVIEW_2026-11-06.md#new-awake-relaunch-failure-caught-by-hosted-testing).

Build 6 fixes the gap between persisted class timing and process-local runtime
state. Previously, a force-close retained `ClassContext` but discarded
`renewalPending`; foreground recovery only considered that in-memory flag.
Reopening therefore displayed the class without starting a new mindfulness
session. Repeated foreground transitions could not repair that missing intent.

## Saved intent

`RuntimeIntentStore` saves a separate record in UserDefaults, bound to the
class's exact initial Start timestamp. Editing the scheduled start or duration
does not change that identity.

- `running`: a new class or explicit Resume requests a session. Relaunch arms
  one recovery attempt. From build 31, automatic recovery waits until the
  recorded SwiftUI scene and native application both report active.
- `stopped`: explicit Stop is persisted before invalidation, including while
  startup is pending. Returning or recreating the process does not undo Stop.
- `manualRecovery`: a non-renewable failure requires explicit Resume. Repeated
  appearance/scene events and relaunches do not create an automatic retry loop.

The session object itself is never persisted or reused. Existing expiration and
foreground-loss renewal rules still apply. An actual `didStart` callback is
required before reporting successful recovery. Automatic recovery continues to
respect `renewalPolicy`; it does not run under `userInitiated` policy.

Class synchronization occurs before a new-class Start, on root appearance, on
class changes, and before active-scene recovery. Missing, mismatched, or retired
class context cannot inherit another class's intent. Retirement remains at
scheduled end plus the existing 30-minute grace period. End class clears timing
and intent. Count state remains independent and does not resume after relaunch.

Older builds did not persist intentional Stop. Migration deliberately requires
one explicit Resume for an existing class rather than guessing. Newly started
classes need no migration step. UserDefaults is local persistence, not a promise
of atomic durability against device failure at the instant of a tap.

## Diagnostics and checks

Runtime journal events now include `savedRuntimeIntent` and `intentClassID`.
`runtime_intent_restored` / `runtime_intent_unavailable` explain launch recovery
eligibility; existing restart attempt/success/failure events record the outcome.

`sh scripts/check.sh` covers process recreation, inactive deferral, duplicate
activation callbacks, Stop while invalidation is pending, manual Resume,
schedule edits, policy selection, failure suppression across launches, and
missing/corrupt/mismatched/retired class intent. The same suite retains the
existing expiration handoff and foreground-loss tests.

On October 24, the SE 3 40 mm / watchOS 27 Simulator passed normal-UI Start,
process termination and relaunch with `automatic_restart_succeeded`, followed
by explicit Stop through Class options and another termination/relaunch with
no start attempt. The persisted class identity, scheduled start and duration
were identical before and after both launches. These checks used the normal
launch path, without a debug auto-start argument or injected saved intent.

Physical Watch validation remains necessary for watchOS startup eligibility and
foreground retention after force-closing during a real class. This change does
not claim to fix the blank media view or the seconds-hand dimming backstep.

## November 2 build-30 baseline on watchOS 27.2

The SE 3 40 mm Simulator on watchOS 27.2 (24S118), Xcode 27.2 (27B52),
reproduced [issue #7](https://github.com/qayshp/TeachingTimer/issues/7) with build
30. A class with running intent was terminated and reopened while dimmed. The
native app reported active, but the SwiftUI scene was inactive and luminance
reduced. Automatic start was submitted about 0.135 seconds after the recorded
launch; about 0.256 seconds after launch, invalidation reported
`WKExtendedRuntimeSessionErrorDomain` code `3`. The app saved `manualRecovery`.
Waking to an active, undimmed scene did not restart the session. The persisted
class bytes remained unchanged.

The intentional-Stop comparison preserved Stop and made no start attempt, but
its reopened interface was awake, so it does not establish the dimmed-Stop case.
Two earlier setup-only attempts never reached a runtime relaunch and are not
counted as successful or failed recovery trials. Original stage screenshots,
journals, preferences and `result.json` remain in ignored
`work/support/2026-11-02-v1-review/runtime-recovery-baseline-verified-face/`.

## Build 31 candidate comparison

Build 31 supplies scene state before evaluating recovery on appearance and
requires both scene and native activity for automatic recovery and early runtime
handoff. It prevents the observed premature submission; it adds no code-3 retry
and does not migrate old `manualRecovery` intent to `running`.

One candidate trial matched the baseline's inactive, reduced-luminance initial
appearance. No premature Start was submitted; running intent remained intact.
A later verified active wake produced a successful `runtime_started` callback
without error or a manual Resume. The second candidate trial initially appeared
inactive but not dimmed, then became dimmed during observation. It is a separate
nonmatching trial, not a second reproduction of the same launch condition. Both
intentional-Stop comparisons retained Stop with no Start before or after wake;
their initial appearance was not dimmed, so that specific Stop condition remains
unproven. All 14 candidate preference captures matched the baseline class bytes.

The wake helper used virtual Crown/Home followed by reopening, rather than a
passive wrist lift. Each running candidate trial includes two active edges with
a real background/`resigned_frontmost` invalidation between them. Two successful,
nonoverlapping runtime starts follow those edges; this is not a retry loop or a
claim of one total Start for the whole helper sequence.

All 12 Swift suites pass, including scene/native gating and early-handoff checks;
the Debug Simulator build succeeds. These results establish one matched
Simulator prevention/recovery success. They do not guarantee liveness for every
ordering of native and SwiftUI callbacks: there is no independent native
did-become-active observer, and this reproduction recovered through a later
SwiftUI active transition. Physical validation remains pending. Media/volume
ordering and class timing were not changed.

The private `runtime-recovery-comparison.md` and candidate stage records are
under ignored `work/support/2026-11-02-v1-review/`, beside the baseline evidence.
The clean build-31 archive at `9da154876eeb` passed signed export and upload;
Apple processed it as Ready to Test / Internal, and it is available in the
one-tester owner pilot. This distribution result does not establish TestFlight
installation/update, journal access or physical recovery behavior.

## Build 32 queued explicit Start guard

An explicit Start may be queued while the previous runtime is still
invalidating. The scene can become inactive before that old callback arrives,
even while native application state says active. Build 32 applies the same
scene/native readiness condition to this deferred path. Direct immediate Start
is unchanged, and a queued user request still works under user-initiated renewal
policy. The request remains tied to its class; Stop, reset, replacement or
retirement cancels it.

All 12 Swift suites pass. Boundary-double checks exercise both callback orders,
native-versus-scene readiness, duplicate callbacks and cancellation while waiting.
Injected failures remain synthetic evidence; no new physical or Simulator
WatchKit rejection is claimed for this queued-Start case. The build-31 matched
automatic-recovery comparison above remains separate evidence. These tests do
not add a native activity observer or prove liveness under every real callback
ordering. Media/volume, count timing and stored class values are unchanged.
