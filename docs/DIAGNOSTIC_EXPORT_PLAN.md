# Proposed diagnostic export

Research reviewed November 6, 2026. **Proposed, not implemented or shipped.**
Teaching Timer currently has no journal export or upload control. Ordinary
TestFlight/App Store users must not be asked to extract files with developer
tools. [Private support](../SUPPORT.md) continues to accept a description and
optional cropped screenshot without journals.

## Recommendation and decision gate

First finish the existing harmless native-sharing experiment on an authorized
physical Watch. This is the smallest change to investigate: no server, account
service or iPhone companion is needed. Implement native journal sharing only if
a usable route delivers and validates the intended attachment.

If native sharing is unreliable, unavailable in common configurations, or requires
a cumbersome Messages-to-phone-to-email relay, prefer **an explicit HTTPS upload
from the Watch with a case reference** as the reliable product direction. Its
advantage is control over receipt and support intake; its actual reliability
still needs testing. It adds a private service and data-handling responsibilities.
Defer an iPhone companion unless there is a broader product reason to build one.
This plan does not authorize a device install, message, backend deployment or
collection of real journals.

## Evidence and platform limits

- The [isolated probe](../tools/diagnostic-share-probe/README.md) presented text,
  a 198-byte JSON and a 941,009-byte synthetic ZIP in the SE 3 40 mm Simulator on
  watchOS 27.2 on November 2. Only Messages was offered. Both files reached
  compose and their export closures ran; cancellation returned correctly. No
  recipient was chosen, nothing was sent, and no received file was validated.
- Apple's [ShareLink](https://developer.apple.com/documentation/swiftui/sharelink)
  and [FileRepresentation](https://developer.apple.com/documentation/coretransferable/filerepresentation)
  are public watchOS APIs. The selected WatchOS 27.2 SDK declares ShareLink,
  Transferable, FileRepresentation and SentTransferredFile available from
  watchOS 9. Sharing services depend on the content representation and system;
  neither API availability nor the Simulator observation proves physical Mail
  or Messages attachment delivery. ShareLink has subject/message parameters,
  but no email-recipient parameter.
- The [owner pilot](TESTFLIGHT_PILOT_RESULTS.md) retrieved TestFlight journals
  from a developer-enabled Watch through a trusted Mac. That establishes only
  that setup, not an ordinary tester's retrieval path.
- Apple's [independent-app guidance](https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps)
  distinguishes a functional iPhone companion from a watch-only distribution
  stub. Teaching Timer's packaging does not provide a phone receiver.
- This feature exports the app's own journals. It does not collect sysdiagnose,
  system logs, audio, receiver volume or other apps' data. Apple system captures
  remain a separate, specifically arranged diagnostic action.

## Minimal future user flow

Proposed location: **Settings → About → Share diagnostics**.

1. Choose **Last 2 hours** (default), **Last 24 hours**, or explicitly
   **All retained events**. Show the actual available interval, event counts
   and file size; explain when earlier history is unavailable.
2. Review a readable summary and the warning that timestamps can reveal when
   the app was used or a class occurred. Describe the included data and the
   chosen destination/handling before any send. Offer Cancel equally clearly.
3. Choose **Share file…** to open native sharing, or **Send to support** if the
   separately implemented upload service is selected. Each report needs a fresh
   affirmative action; no persistent opt-in or automatic future collection.
4. For native sharing, show only instructions validated for an available route.
   Opening sharing or an export callback must not produce a “Delivered” claim.
   For upload, show **Waiting**, **Sending**, **Received**, or **Failed** based on
   actual transfer/receipt state, and display a case reference after receipt.

The timer remains usable without sharing. A report can begin by emailing
[teachingtimer@qays.net](mailto:teachingtimer@qays.net). Existing support QR codes
do not attach journals, and scanning a future case-reference QR is not consent
to upload.

## Bounded report contract

Build one versioned JSON document containing metadata and arrays derived from
RuntimeDiagnostics, InterfaceDiagnostics and LandmarkDiagnostics. This avoids
adding on-Watch ZIP creation initially. Reconsider compression only after
measuring final-format size and testing the chosen delivery route.

- Capture one cutoff and take ordered snapshots off the main thread. Report
  missing, unreadable or failed snapshots explicitly. Existing writer `flush()`
  methods return no error and log write failures internally; an export operation
  must return a result rather than treating a completed flush as proof that fresh
  bytes were saved. Preserve source journals and timer/session state.
- Include schema version, app/build/revision, OS version, selected and actual
  bounds, counts, per-journal status and any truncation. Apply the selected time
  window at export, even when source files contain older retained data. Add
  required version/context metadata explicitly rather than silently including
  out-of-window events. Test backwards-clock and future-dated-event handling.
- Export only the three known stores through an event/field allowlist. Exclude
  preferences, arbitrary container files and unreadable recovery copies.
  Remap generated launch/runtime/count identifiers consistently within a report.
  Keep error domains/codes; omit free-form error descriptions by default unless
  a reviewed sanitizer has a demonstrated diagnostic need for them. Such text
  can contain unexpected paths or identifiers. Exact event timestamps remain
  disclosed diagnostic data; do not call the report anonymous.
- Proposed initial cap: **2 MiB of encoded report data**. If a selection exceeds
  it, ask for a narrower interval and show the reason. Do not silently drop
  events. Test the boundary, multibyte strings, unknown fields and large errors.
  Missing data and retained-history limits must not appear as complete coverage.
- Keep the prepared report immutable during transfer. Record its byte length
  and SHA-256 for receipt validation. Delete canceled/prepared temporary files
  when safe; retain an in-flight file only while needed by the transfer. Use a
  bounded cleanup policy on subsequent launches and disclose that cleanup is
  not guaranteed while the app never runs. Original journals, exported files,
  recipient copies and backups have separate lifetimes.

Normal journals currently retain up to seven days as new events are written,
subject to 10,000 runtime, 10,000 interface and 20,000 landmark event caps.
Recovery copies have different lifetimes. See [Privacy](PRIVACY.md).

## Acceptance gates

1. **Physical native capability:** receive harmless small and realistically
   sized final-format fixtures from an authorized Watch. Validate filename,
   size, SHA-256 and parsed contents. Test direct Mail to the intended private
   inbox if offered. If Messages is the only route, validate the complete
   deliberate relay and assess its usability; do not assume the support email
   is an iMessage destination.
2. **Distribution and interruption:** repeat from a TestFlight installation
   without a developer-tool retrieval step. Test cancellation, absent sharing
   destinations, offline/deferred transfer, wrist-down/background interruption
   and repeated export. Cover the minimum supported and current watchOS before
   promising both. A Simulator pass cannot substitute for these results.
3. **Packaging:** deterministic tests cover window edges, corruption/partial
   availability, writer failure, redaction/unknown fields, size rejection and
   unchanged source bytes. Verify that preparation does not delay count timing
   or alter an active class/session.
4. **Real evidence and intake:** only after fixture validation, deliberately
   share a minimized real report with consent and validate it privately. Match
   it to a case, record receipt separately from preparation/send, and confirm
   useful diagnostic content without exposing raw evidence in GitHub.
5. **Release wording:** update in-app help, support instructions and privacy
   documents to the tested behavior. Review App Store privacy answers against
   actual data handling. Do not advertise untested routes or future features.

## HTTPS fallback

Reuse the report builder and consent screen. Apple's
[Watch background-request guidance](https://developer.apple.com/documentation/watchos-apps/making-background-requests)
supports background URLSession work but allows system/connectivity deferral.
Use a persistent background session, its delegate and Watch background-task
handling; upload an immutable file. Apple documents that
[background uploads must be file-based](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background),
and recommends [background transfers on Watch](https://developer.apple.com/documentation/watchkit/wkurlsessionrefreshbackgroundtask)
because ordinary asynchronous transfers can suspend with the app.

The smallest service needs HTTPS, bounded/schema-checked requests, private
storage, abuse limits, idempotent retry handling and an authenticated maintainer
retrieval route. Mark **Received** only after server acknowledgement that the
complete report was stored and validated. Persist pending state across app
relaunches and test retries, cancellation, timeout, rejection and interrupted
acknowledgements. No automatic new report may be created by a retry.

Return a human-readable case reference and show the support email/QR for a
follow-up description. The reference identifies a case; it must not grant
public file access. Do not encode raw journals or download credentials in a QR.
No user account is required by this proposal. Network access and server receipt
are still prerequisites for completion.

Before release, choose and enforce server retention. A proposed default is
deletion of upload objects after **30 days**, with separately disclosed handling
for evidence retained in an active case, operational logs, email and backups.
Validate expiry/deletion and provide removal requests through the support email.
Keep raw reports private and request permission before forwarding them to Apple
or another party, following the [private intake plan](PRIVATE_SUPPORT_PLAN.md).

An upload changes today's data flow. Review collected diagnostics, any linkage
to a reporter, IP/server logging and service providers in the policy and App
Store Connect answers. Apple's [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
requires all optional-disclosure conditions to be met; a user-triggered support
upload is not automatically exempt. No server or privacy-label change is
implemented by this document.

## Deferred companion option

A real optional iPhone app could receive a report through
[WCSession.transferFile](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferfile(_:metadata:))
and expose phone sharing. It needs installation checks, an activated session,
receiver persistence and clear absent-companion/queued-transfer behavior.
Apple explicitly requires paired-device testing because Simulator does not
support this file-transfer method. Keep the Watch independently usable. The
extra app, distribution and support scope is not justified by export alone
while the native and direct-upload options remain available for evaluation.
