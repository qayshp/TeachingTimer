# Time-edge regression checks

Run `sh scripts/check.sh`. `TimeEdgeChecks` exercises the production class and landmark models with explicit instants and named time zones, without changing the Mac or Watch clock.

- Spring-forward rounding crosses the missing hour; fall-back rounding preserves the correct occurrence of a repeated hour.
- A 60/75-minute class lasts that many elapsed minutes across DST, even when its displayed end hour changes unexpectedly.
- Quarter-hour inference covers year rollover and a zone with a 45-minute UTC offset.
- Persisted class instants remain unchanged when displayed in another timezone.
- Retirement occurs at the exact end-plus-30-minute boundary.
- Landmark frame projection survives forward/backward clock corrections and midnight. The arc reaches its endpoint at 60 seconds and disappears at 64.8 seconds.

These deterministic checks do not establish watchOS delivery cadence, audible/tactile haptic delivery, or correctness of system clock adjustments on hardware.
