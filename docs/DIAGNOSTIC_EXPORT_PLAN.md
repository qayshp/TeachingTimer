# Diagnostic sharing and delivery plan

Updated November 6, 2026. **The owner approved merging after review and CI, then
using the internal TestFlight build for classroom and journal-sharing validation.**
Merge/release readiness is tracked in [current status](../DEVELOPMENT_STATUS.md).
No received attachment has yet been validated;
[issue #26](https://github.com/qayshp/TeachingTimer/issues/26) remains open.
General testers can still use [description-based private support](../SUPPORT.md).
See the [validation record](DIAGNOSTIC_SHARING_VALIDATION.md) for completed checks
and the limits of the current evidence.

## November 8 development follow-up

The optional [iPhone support companion](OPTIONAL_COMPANION.md) supersedes the native
Watch sharing proposal below. The owner found manual recipient entry unsuitable;
the physical Watch offered both Mail and Messages, without a prefilled recipient.
The original staging evidence remains historical. The new companion keeps teaching
independent and supplies pre-addressed email on the phone; physical delivery remains
an open gate. The Watch share sheet is removed in the companion branch.

## Original decision and evidence

Native `ShareLink` is the smallest candidate: no server, account service or iPhone
companion is needed. The implementation prepares a bounded file and asks the user to
choose a private destination. It must not be promoted as a working tester intake
route until a received attachment is validated.

- On November 6, Xcode 27.2/watchOS 27.2, SE 3 40 mm Simulator, **only Messages**
  was offered. A 139-byte synthetic JSON and a 1,401,371-byte representative
  report reached Messages compose. Staged files matched their source SHA-256
  hashes and parsed as JSON; cancellation returned to the probe. No recipient
  was selected, nothing was sent, and no recipient file was received. These are
  staging checks, not delivery evidence.
- The [isolated probe](../tools/diagnostic-share-probe/README.md) previously reached
  compose for a 198-byte JSON and 941,009-byte ZIP on November 2. Those historical
  fixtures also had no delivery test.
- Apple's [ShareLink](https://developer.apple.com/documentation/swiftui/sharelink)
  and [FileRepresentation](https://developer.apple.com/documentation/coretransferable/filerepresentation)
  are public APIs available in the selected SDK from watchOS 9; Teaching Timer
  targets watchOS 26+. Available destinations depend on the system and content.
  ShareLink has no recipient-email parameter. Mail availability, Messages
  delivery and minimum-supported-OS behavior remain unverified.
- The [owner pilot](TESTFLIGHT_PILOT_RESULTS.md) copied TestFlight journals using
  a developer-enabled Watch and trusted Mac. That does not establish an ordinary
  tester's export path.

If native delivery fails or requires an awkward Messages-to-phone-to-email relay,
compare the explicit HTTPS fallback below. A Simulator limitation alone does not
prove physical sharing fails. No upload backend or companion is implemented.

## User flow

**Gear → Settings → About → Share diagnostics**:

1. Choose **Last 2 hours** (default), **Last 24 hours**, or **All retained events**;
   tap **Prepare report**. The original journals and class/session/count state
   remain unchanged.
2. Review available dates, event counts, file size and any missing, unreadable or
   filtered history. **Preview events** shows the latest 20 included events per
   journal with their exported fields; the file includes the complete selected
   report, not just the preview.
3. Read the disclosure that exact timestamps can reveal teaching/app-use times.
   Tap **Share file…** to open native sharing and choose a private recipient.
   Preparation and opening the sheet never mean “Delivered.” Nothing is sent
   automatically or directly to the support address.

Share after class: native sharing may take the app out of the foreground and
end its mindfulness runtime. The read-only preparation itself does not stop the
runtime or clear class/count state; it cannot guarantee what a system sharing
activity does after opening.

Ordinary email and the existing support QR code do not attach journals. A report
can still begin with a description sent to
[teachingtimer@qays.net](mailto:teachingtimer@qays.net). No journals are required.

## Implemented report contract

- One versioned JSON envelope contains app/build/revision/OS metadata and the
  three fixed journals: runtime, interface and landmarks. It includes one cutoff,
  requested/actual date bounds, counts and per-source status. Source append order
  is preserved; inclusive date filtering uses original timestamps, including
  fractions. Future-dated events after a clock correction are excluded and counted.
- Ordered, read-only snapshots include available queued events without flushing
  or mutating source history. Missing/unreadable history, pending counts and the
  last failed write are reported separately. A readable in-memory snapshot does
  not claim that buffered events reached disk.
- An event/field/value allowlist removes unknown fields, arbitrary free text,
  raw error descriptions, paths and original generated IDs. IDs are consistently
  remapped within a report; approved error domains/codes remain useful. Omitted
  event/field counts are visible. Preferences, corrupt backups, arbitrary files,
  raw boot time and system captures are excluded. This is minimized diagnostic
  data, **not anonymous data**.
- Encoded report content is capped at **2 MiB**. An oversized report fails with
  a request for a shorter interval; events are not silently dropped to fit.
- Each prepared file is immutable, has a byte count and SHA-256, and lives in a
  dedicated cache excluded from backup. At most **eight files / 16 MiB of report
  content** are retained. A full cache rejects another preparation instead of
  evicting a recent file the system may still be sharing.
- Cleanup runs on the **next preparation**, removing owned files older than
  24 hours while preserving files used by the current sharing view. Age comes
  from the creation epoch in the filename, not filesystem timestamp APIs.
  Dismissal is not proof a share finished, so it does not immediately delete the
  file. Cleanup is not guaranteed if no later report is prepared; recipient
  copies and original rolling journals have separate lifetimes.

Deterministic checks cover window/subsecond boundaries, clock corrections,
redaction, identifier correlation, partial/corrupt sources, write failures,
stable encoding, size rejection, cache boundaries and source preservation.
These tests do not establish native attachment delivery. The journals' own
retention remains documented in [Privacy](PRIVACY.md).

## Owner pilot and gates before general support

The owner will install through TestFlight and try sharing after class. The
remaining checks establish supported delivery; they do not block the approved
owner pilot once the implementation checks pass. No developer-tool access to
the physical devices is requested for that plan.

1. Receive harmless small and realistically sized JSON fixtures from an
   authorized physical Watch. Verify filename, size, SHA-256 and parsed contents.
   If Mail is offered, test the private support inbox; if only Messages is offered,
   validate the complete deliberate relay. Do not assume the support email is an
   iMessage address.
2. Repeat from TestFlight without developer-tool retrieval. Test cancellation,
   no available destination, offline/deferred transfer, wrist-down/background
   interruption and repeated preparation. Verify minimum and current watchOS
   before advertising support on both.
3. After fixture delivery works, explicitly share a minimized real report and
   validate it privately. Confirm it helps diagnose an issue without exposing
   raw events in GitHub; report preparation, send and receipt separately.
4. Review user instructions, privacy handling and App Store answers against the
   route actually delivered. Update [private intake](PRIVATE_SUPPORT_PLAN.md)
   and close #26 only when those gates are satisfied.

## HTTPS fallback — not implemented

Reuse the report builder and consent screen. Prefer a background URLSession
upload from an immutable file, using Apple's
[Watch background-request guidance](https://developer.apple.com/documentation/watchos-apps/making-background-requests)
and [file-based background transfer guidance](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background).
Connectivity and scheduling can defer a Watch transfer. Persist pending state and
show Waiting/Sending/Failed; show Received and a case reference only after the
service acknowledges complete, validated private storage.

The service would need request/schema/size/abuse limits, idempotent retries,
authenticated maintainer retrieval, tested deletion and clear retention. A case
reference must not grant public download access. A proposed 30-day upload lifetime
would need enforcement and separate disclosure for active cases, email and backups.
No automatic new report may be created by a retry.

An upload changes today's data flow. Review collected diagnostics, linkage,
IP/server logs and providers under Apple's
[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).
User-triggered support sharing is not automatically exempt. No service, retention
promise or App Store privacy-label change has been deployed for this feature.

## Deferred companion option

A real optional iPhone receiver could use
[WCSession.transferFile](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferfile(_:metadata:))
and phone sharing. It requires paired-device delivery tests, receiver persistence,
installation checks and queued-transfer handling; Simulator does not support this
file-transfer method. The current watch-only distribution container is packaging,
not that receiver. The additional product and support scope is not justified
before native sharing and direct upload have been evaluated.
