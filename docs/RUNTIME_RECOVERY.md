# Runtime recovery after reopening

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
  one recovery attempt when the application is active.
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
