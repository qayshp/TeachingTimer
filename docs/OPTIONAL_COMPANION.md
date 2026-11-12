# Optional support companion

Issue #26 follow-up. Watch teaching has no dependency on installing the iPhone app.
The published bundle IDs are preserved. TestFlight packaging now embeds the Watch
in a real iOS support app; the Watch declares independent execution and its existing
parent identity. Local Debug/Release retain watch-only packaging.

## Flow

The iPhone requests a report only while Watch Connectivity reports the Watch app
reachable. The explicit phone request prepares the selected window (last 2 hours, last 24 hours, or all retained events) of filtered diagnostics on the Watch and queues the transfer. The Watch app must be open to prepare the report.
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
only main remained allowed. At that checkpoint, PR #29 was unmerged and
physical installation, transfer, email receipt and upgrade preservation were
unverified. The later physical result is recorded below.

## Connection and mail follow-up — November 11

A physical build-32 report reached the support mailbox through the iPhone mail
composer: valid schema-1 JSON, 58,129 bytes and 85 events. This confirms one
end-to-end delivery, not universal reliability. The initial companion request
appeared unresponsive until both apps were force closed. The first mail sheet
was gray; dismissing and preparing a fresh report recovered it.

The request previously acknowledged receipt before checking provider readiness
or queueing the file. It now replies only after preparation and a successful
queue submission, or returns an explicit failure. Queueing is not receipt or
email delivery. A 60-second UI wait expires honestly without cancelling an
already queued file. The phone disables duplicate requests while waiting.
Both apps expose their build and bounded, in-memory connection events; phone
replies include the Watch build. Connection events also go to the system log,
with codes rather than free-form errors. They are not added to exported journals.
The phone rechecks connectivity on foreground activation. The phone time-window
picker does not change Watch defaults or teaching state.

Mail presentation now uses one immutable draft containing the attachment instead
of separate presentation/payload state. This removes an empty-sheet state from
our UI; whether it eliminates the observed gray screen needs physical testing.
Simulator cannot establish file transfer or configured-Mail delivery. The new
queue helper has deterministic tests for each window, preparation failure,
transport refusal, and preparation-before-queue ordering.

## Maintainer follow-up release — November 11

**1.0 (261111.1849.33)** is available to Maintainers from source
`ee83fb446e4b2e70d79a1ce4ed522d8493fb551d`.
[Release run 43144012103](https://github.com/qayshp/TeachingTimer/actions/runs/43144012103)
passed 16 Swift suites, 277 Python tests, repository/QR/helper checks, the booted
SE 3 40 mm and Ultra 4 49 mm lifecycle matrix, and unsigned archive checks.
Signed archive/export/upload passed. Apple processing was VALID; testing notes,
Maintainer group membership and IN_BETA_TESTING were read back. Availability was
confirmed at 19:14:05 PST, approximately 97 seconds after upload completed.
The temporary branch release allowance was removed; only main remains allowed.
No physical installation or new-build delivery test was performed by the agent.
PR #29 remains unmerged. Recheck both installed version labels after updating.

## PR verification environment correction — November 12

PR run 43147024003 failed its immediate running-session relaunch on the older
Xcode 26.6 / watchOS 26.5 default runner: Start at +0.109 seconds, WatchKit error
3 at +0.266 seconds despite active/awake readiness, then persisted manual recovery.
This matches open issue #27. The second failed check was its required-result
aggregator. The release run used Xcode 27.2 / watchOS 27.2 and passed.
PR verification now uses the same xcode-27 environment as release verification;
a CI test guards that alignment and keeps real-runtime failures fatal. This
corrects toolchain drift; it does not establish a fix for issue #27 or remove
watchOS 26 deployment compatibility. Failed evidence is retained privately.
