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

## Local results — November 8

Xcode 27.2 with iOS 27.2 and watchOS 27.2: companion and Watch Simulator build
and launch passed; phone installation detection reported the paired Watch app
present. A manually seeded synthetic report exercised phone inbox restoration
UI only, not delivery. Unsigned distribution archive and structural checks passed,
including independent execution and unchanged parent/Watch bundle IDs. All 15
Swift suites and 276 Python checks passed. Physical transfer, mail composition
with a configured account, receipt and upgrade preservation remain pending.

## Distribution commitment

Apple documents that after adding an iOS companion and publishing it to the
App Store, reverting that product to watch-only is not supported. Independent
Watch execution remains supported. This PR is not an App Store publication.
Reference: https://developer.apple.com/documentation/technotes/tn3157-updating-your-watchos-project-for-swiftui-and-widgetkit

## Maintainer TestFlight pilot — November 8

**1.0 (261108.1359.32)** from PR #29 revision `3f20c2577a828563661a173870b113a68eb32cc0`
is available to the Maintainer pilot. [Release run 42527911603](https://github.com/qayshp/TeachingTimer/actions/runs/42527911603)
verified a clean source checkout, all 15 Swift suites / 277 Python tests, ten
lifecycle launches each on watchOS 27.2 SE 3 40 mm and Ultra 4 49 mm, helper
builds and both archive paths. Signing/export and Apple processing passed;
notes, group membership and `IN_BETA_TESTING` were read back. Availability was
confirmed at 14:20:25 PST, 96.36 seconds after upload completed.

A pre-upload icon check found an alpha channel in the iPhone asset. The initial
run was cancelled before upload, the icon was converted to an opaque format,
and a regression check was added before the successful run. Only one build was
uploaded. The temporary exact-branch environment allowance was removed afterward;
only main remains allowed. PR #29 remains unmerged. Physical installation,
transfer, email receipt and upgrade preservation are still unverified.
