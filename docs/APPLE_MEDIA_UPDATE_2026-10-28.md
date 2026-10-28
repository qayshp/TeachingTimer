# Apple media follow-up — October 28, 2026

Submitted to existing **FB25305069** through Feedback Assistant. The saved
follow-up text was read back and matched the prepared text. FeedbackCore
reported attachment upload completion at 00:03:30 PDT.

The update explains why the prior view-refresh mitigation is not reliable:

- Four recovery variants were compared on the existing SE 3/watchOS 27.0 setup:
  stable outer page, 300 ms teardown gap, clock-only TimelineView placement,
  and conditional native-view lifetime.
- Additional five-second captures distinguish transient loading from a longer
  blank. No candidate established reliable recovery; experimental changes were removed.
- Host/class/native-volume identity survived. Home ended the runtime with
  `resigned_frontmost`, followed by automatic recovery. Those lifecycle checks
  do not prove rendered media, phone volume or tactile haptic delivery.
- Deliberate native-service termination is fault injection, not an established
  cause of the physical incidents. A smaller independent two-page reproduction
  is still needed. The report asks about a supported recovery/availability API.

`MediaRecoveryComparison.zip` contains the comparison, variant source snapshots,
selected delayed screenshots, results and focused Simulator lifecycle excerpts.
It was attached privately to Apple; raw device journals were not published.
See the [comparison](MEDIA_RECOVERY_COMPARISON.md) for the observations and limits.

No unchanged duplicates were submitted to the other reports. The seconds-hand
newer-runtime comparison remains unavailable locally; no new physical volume,
silencing or developer-connection evidence was collected in this batch.
