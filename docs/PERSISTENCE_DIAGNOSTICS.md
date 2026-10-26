# Saved-state diagnostics — build 18

Class schedule and runtime intent remain separate. Their existing keys, JSON
formats, restoration rules and intentional-Stop behavior are unchanged.

Each store now distinguishes absent, successfully restored, unreadable JSON,
and an unexpected preference type. Events are drained once into the existing
runtime journal on startup/state changes; no separate writer competes for it.
`persistence_loaded`, `persistence_read_failed`, `persistence_saved`,
`persistence_write_failed`, and `persistence_removed` describe the store action.
They do not guarantee a synchronous durable disk flush; UserDefaults read-back
only checks the currently observable preference value.

Before a later explicit Start or state change can replace unreadable data, the
load path preserves it under `<original-key>.unreadable.v1`. Exactly one latest
backup per store is retained. Original Data bytes are unchanged; a wrong-type
preference is wrapped in a binary property list under `value`. Repeated loads
of identical bytes keep the original backup timestamp. A different unreadable
value replaces the previous backup and the diagnostic records that fact.

The original preference is not deleted merely because decoding failed. A failed
encode leaves the previous persisted value intact. No speculative saved class
or running intent is fabricated. Journal entries contain store names, outcome,
error type and byte count, never the raw saved contents. The preferences backup
is local; it is not included automatically by the three-journal copy tool.

Deterministic checks cover missing/restored/bad JSON/wrong-type values, exact
backup preservation across explicit recovery, one-shot event draining, failed
encoding, and restored intentional Stop. Existing renewal and class tests remain
in place. Inspect the app container preferences separately if recovery bytes are
needed; keep them private.
