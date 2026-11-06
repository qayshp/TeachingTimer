# Runtime transition checks

`scripts/check.sh` compiles the actual `ExtendedRuntimeController` against a
small WatchKit boundary double. It runs on the Mac and in the hosted macOS
verification job. It does not establish WatchKit permission to renew, physical
foreground retention, battery life, or native media/Crown behavior.

The named regression cases in `Tests/RuntimeRenewalChecks.swift` cover saved
intent, process relaunch, early handoff, late invalidation, pending explicit
Start, Stop/reset, schedule edits, missing/corrupt persistence, and native/scene
readiness arriving in either order.

Eight fixed seeds also generate 160 mixed events each. These combine scene
transitions, Start/Stop, class replacement and retirement, schedule edits,
delegate callbacks, stale callbacks, and renewal-policy changes. Every event
checks the following independent invariants:

| Invariant | What a failure would mean |
| --- | --- |
| At most one non-invalid runtime object | A replacement overlapped its predecessor. |
| At most one successor per event | One callback or user action created duplicate sessions. |
| A new session requires a current class | Cleared or retired timing was resurrected. |
| Native active state is required for any start | An ineligible start escaped the controller guard. |
| Deferred recovery also requires an active scene | Native readiness alone consumed deferred intent. |
| Explicit Stop persists until another explicit Start | Later callbacks silently rearmed a stopped class. |
| Running presentation requires a confirmed live object | UI state claimed a session that had not started or had already ended. |

Failures include the seed, step, and last 24 actions. Re-running `scripts/check.sh`
replays the same action choices. Dates anchor classes to the test run so they do
not expire as the test ages; absolute boundary arithmetic has separate named
tests. The WatchKit double deliberately lets the test deliver confirmation and
invalidation independently, preserving the asynchronous ordering that matters.

This is the first lifecycle-invariant portion of
[#15](https://github.com/qayshp/TeachingTimer/issues/15). It does not complete the
requested performance baseline or replace the physical checks in
[#10](https://github.com/qayshp/TeachingTimer/issues/10).
