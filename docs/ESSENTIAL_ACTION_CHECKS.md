# Essential-action Simulator regression

October 27, 2026; Xcode 27.1 / watchOS 27.0, development build 18.
The local runner is [documented here](../tools/simulator-regression/README.md#essential-teaching-actions).
It is deliberately separate from headless CI: Device Hub needs an interactive
Mac session and Accessibility permission.

The checks cover:

- Cancelling a custom draft, then starting the ordinary 60-minute default.
- Starting and cancelling a count without changing the class.
- Stopping and resuming runtime while preserving the class.
- Cancelling an edited schedule, then saving a +15-minute change while retaining
  the exact initial Start timestamp.
- Starting a custom replacement class through its confirmation.
- Entering media and returning while preserving that active class.
- Ending the class through its confirmation and verifying persisted timing is cleared.
- Entering media and returning with no active class.

Saved-state/event assertions and visual review are separate. A `complete: true`
result means the bounded input/state sequence finished; it never proves audio,
Crown ownership, haptic delivery or every native view's rendered pixels.

## Evidence and limitations

The SE 3 40 mm and Ultra 4 49 mm use the same action runner and production app.
Both final runs passed all 14 state assertions. Reviewed menu/confirmation,
media and timer captures rendered their expected content in those runs. This
does not erase the intermittent failure below.

The final results and screenshots are retained privately under
`work/support/2026-10-27-roadmap-18-21/`.

An earlier SE 3 run again showed a timer return with hands/dial but missing
controls. The class and page-selection event survived. This is recorded as a
rendering failure, not hidden by the state checks, and does not establish a
shared cause with physical blank-media incidents. Final successful runs do not
prove that intermittent bug is fixed.

Harness corrections included waking an initially dimmed simulator, recognizing
known icon prefixes in menu text, using a slow drag to avoid scrolling past
rows, and rejecting unsigned apps before the runtime test. An unsigned app did
open on Ultra but its extended runtime failed with an unknown session error;
the same production app with normal Simulator signing started successfully.

No production UI, session, volume, haptic or rendering behavior was changed.
No physical Watch was installed, launched or tested in this batch.
