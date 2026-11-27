# Journal retention and writer measurements

October 26, 2026. This changes storage bounds only: no new per-frame events,
focus requests, runtime actions, haptic scheduling or UI changes.

| File | Build 16 | Build 17 |
| --- | --- | --- |
| RuntimeDiagnostics.json | 7 days / 10,000 events | Unchanged |
| InterfaceDiagnostics.json | 1 day / 4,000 events | 7 days / 10,000 events |
| LandmarkDiagnostics.json | 2,000 events, no age limit | 7 days / 20,000 events |

These are maximum bounds, **not a guaranteed minimum history**. The event cap
can evict entries earlier than seven days. Files prune only on their next write;
an idle file can contain older entries. Event order, JSON schema, atomic writes,
250 ms off-main batching and corrupt-file preservation remain unchanged.
Backward wall-clock corrections preserve future-dated entries, subject to the cap.
Existing files load in place. Already-evicted entries cannot be reconstructed.

## Why these bounds

The saved pre-build-10 physical capture held exactly 1,000 runtime events over
about 103 minutes. Routine scene/luminance events dominated and earlier class
history was absent. Build 10 separated these events and enlarged operational
retention. Later captures contain that legacy history, so they should not be
used as a clean measurement of current event rates.

The saved landmark capture had 1,249 events spanning several weeks, but current
late-pulse logging can produce more entries per count than that older behavior.
At 45 entries per full late count (start, acknowledgement, 21 late notices,
21 timing submissions, end), 2,000 events cover only 44 complete counts. That
is insufficient headroom for a busy multi-class week. A one-day detail window
also loses earlier days' dimming evidence regardless of available capacity.

## Deterministic verification

The production defaults were tested with:

- **21 classes / seven days**, three classes per day, 100 wake cycles per class:
  all 6,342 runtime and 6,300 detail events survive, with all class IDs present.
- **420 counts**, 20 per class, every timing pulse late: all **18,900** landmark
  events survive with all run IDs present.
- Reopening and pruning at the inclusive seven-day boundary for every journal.
- Backward clock corrections, explicit small count caps, and corrupt-byte backup.

All eleven Swift check suites and a watchOS Simulator build passed. This is a
synthetic capacity test, not a measured seven-day Watch battery/performance run.
The arrays are still encoded and atomically rewritten on flush; larger bounds
increase worst-case storage and write work. Physical overhead measurement remains
separate follow-through. Routine wrist events remain separated so they cannot
consume the operational journal's capacity.

No diagnostic events were removed in this batch: callbacks distinguish requests,
invocations and returns and remain useful for the current focus investigation.
Summaries can condense them without destroying the underlying evidence.

Build 17 has not been installed on the physical Watch as part of this batch.

## November 26 physical writer benchmark

A standalone probe ran the unchanged journal writer on an Apple Watch SE 3
with watchOS 27.2.1. It seeded synthetic journals, verified all 16 flush
results and exercised the 20,000-event cap.

| Seeded events | Final file size | First flush with a fresh writer | Median of three subsequent flushes |
| ---: | ---: | ---: | ---: |
| 1,000 | 0.76 MB | 305 ms | 76 ms |
| 5,000 | 3.80 MB | 763 ms | 367 ms |
| 10,000 | 7.61 MB | 1,502 ms | 730 ms |
| 20,000 | 15.23 MB | 3,043 ms | 1,489 ms |

The first flush included loading an existing seed file. The timings include
writer queue scheduling and the atomic write, with the normal batching delay
excluded. Subsequent flush time scaled roughly with file size in this run.
Classroom event frequency, main-thread responsiveness and battery effects
remain unmeasured. [Performance issue #15](https://github.com/qayshp/TeachingTimer/issues/15)
