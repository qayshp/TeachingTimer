# Optional support companion

Issue #26 follow-up. Watch teaching has no dependency on installing the iPhone app.
The published bundle IDs are preserved. TestFlight packaging now embeds the Watch
in a real iOS support app; the Watch declares independent execution and its existing
parent identity. Local Debug/Release retain watch-only packaging.

## Flow

The iPhone requests a report only while Watch Connectivity reports the Watch app
reachable. The explicit phone request prepares the last two hours of filtered diagnostics on the Watch and queues the transfer. The Watch app must be open to prepare the report.
Watch Settings → Help → Send diagnostics to iPhone prepares a report from read-only
snapshots. Missing companion status is read after connectivity activation; install
changes update it. Sending queues a file, with one outstanding transfer allowed.
Queued files are protected from normal report-cache cleanup. A completed transfer
is not email delivery. The iPhone copies the temporary file before the delegate
returns, bounds input at 2 MiB, checks JSON, and retains only the latest report.
It restores that report after reopening and offers deletion. Email support uses
Apple Mail with recipient, subject, body and JSON attachment prefilled. No server
or account is added. Phone export supports alternative mail apps.

## Validation gates

- Verify Watch installation and teaching without the iPhone app.
- Install/uninstall companion and observe correct status after activation.
- Exercise explicit Watch send and explicit phone request.
- Receive/parse a physical report, retry interrupted and queued transfers.
- Verify mail cancellation, absent Mail account and independently received bytes.
- Update the existing TestFlight installation and verify retained class/settings.

Apple documents that WCSession.transferFile is unsupported in Simulator:
https://developer.apple.com/documentation/watchconnectivity/wcsession/transferfile(_:metadata:)
Simulator builds and screenshots therefore cannot establish paired delivery.
