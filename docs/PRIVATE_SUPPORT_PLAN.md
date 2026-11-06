# Private support and diagnostic intake

Updated November 6, 2026. **The approved support alias is configured in the
existing iCloud mailbox; incoming and outgoing plain email are verified.**
No mail routing or MX records were changed. The owner has authorized the public
beta with **description-based support and optional cropped screenshots**, without
requiring journal attachments. This is not an automatic upload service. Keep public issues limited to sanitized
descriptions. The harmless incoming test and one authorized outgoing message
from the alias were received and their contents checked on November 2. Neither
test included attachments; native Watch and diagnostic attachment delivery remain
unverified.

## Recommended route

Use [teachingtimer@qays.net](mailto:teachingtimer@qays.net), the configured support
alias in the existing mailbox. [The public support guide](../SUPPORT.md) is
source build 30's support QR destination. Initial
reports should contain a description, app/build and OS versions, approximate
incident time with time zone, the affected page, playback source/output route if
relevant, and whether page switching or another recovery helped. No journal or
system capture is needed for the first message.

The qays.net alias uses the existing iCloud Mail provider. It can receive reports;
outgoing plain email from the alias also reached the intended recipient in the
verified test. Diagnostic attachment delivery remains untested. No MX records
or inbound mail provider were changed.

For the initial public pilot, email is the reporting route. A short description
is sufficient to open a report; a cropped screenshot can help when available.
Diagnostic sharing remains a separate, deliberate action. The Watch app continues
making no automatic uploads, and ordinary testers are not promised journal export.

## Getting journals off the Watch

Published builds have no journal export or upload control. Ordinary Watch Mail,
the support QR code and the distribution container do not attach app-private
journals. The November 2 [owner pilot](TESTFLIGHT_PILOT_RESULTS.md) copied all
three Beta journals through a developer-enabled SE 3 and trusted Mac; that is
not an ordinary tester's retrieval path.

A [native-sharing draft](DIAGNOSTIC_EXPORT_PLAN.md) now adds **Settings → About →
Share diagnostics**, a time-limited/filtered report, preview and explicit native
share action. It is **unmerged and Simulator-only**, with no upload service or
new iPhone companion. Current public-beta support still accepts descriptions and
optional cropped screenshots; it does not require journals.

The November 6 SE 3 Simulator probe offered only Messages. A harmless 139-byte
JSON and a 1,401,371-byte representative report reached compose; staged copies
matched source hashes and parsed correctly. No recipient was selected or file
sent, and cancellation returned. This extends the November 2 presentation checks
without proving delivery. The owner chose to defer physical testing. Do not
promise Mail support, a direct-to-support send, or a usable tester export until
received attachments and the complete intended route are verified.

[Issue #26](https://github.com/qayshp/TeachingTimer/issues/26) tracks physical
receipt, TestFlight, interruption/offline testing and the delivery decision.
If native sharing is unreliable or cumbersome, evaluate the plan's explicit
HTTPS fallback and its privacy obligations before deploying it. Recommend sharing
after class: native activities may take foreground and end the runtime even
though report preparation leaves class/session/count state unchanged.

## Handling a report

1. Assign a local case reference. Keep the original report and any raw files in
   a private case directory, outside tracked source. Do not place personal
   details in a public GitHub issue or commit message.
2. Request the smallest useful evidence: often a cropped screenshot or a short
   journal window is enough. Explain what it can contain before requesting it.
   Do not request student identities, passwords, verification codes or a whole
   device capture as a default.
3. For larger/sensitive captures that the reporter can obtain, agree on a private
   file-sharing link restricted to the maintainer. Check the actual recipient
   and access settings; possession of a public unlisted link is not equivalent
   to restricted access. Use the tester's existing sharing service for this
   pilot rather than adding a new account or service requirement.
4. Record file size, hash, date bounds, app/build and capture/transfer status.
   Distinguish a requested capture from a completed download and a validated
   archive. Use the [existing diagnostic workflow](DIAGNOSTIC_TOOLS.md).
5. Summarize only the necessary sanitized findings in the public tracker. Get
   permission before forwarding raw private evidence to Apple or another party.
6. Keep captures only while needed for the investigation; review and remove
   unnecessary working/export copies when closing the case. Tell the reporter
   about copies already shared and backup limits instead of promising deletion
   from systems the maintainer does not control.

Use [the privacy policy](PRIVACY.md) for the journal contents and local retention.
A voluntarily emailed report has different storage/retention from the Watch's
rolling journal. Public App Store privacy answers must be reviewed against the
actual intake practice; optional support sharing is not automatically exempt.

## Release checklist

- [x] Maintainer approves the proposed support alias in the existing mailbox.
- [x] Alias configured at the existing mail provider.
- [x] Harmless inbound test received and its contents verified.
- [x] Outgoing plain email from the alias sent, received and contents verified.
- [x] Approved address added to About/support QR destination and repository guide.
- [x] Privacy/support wording describes actual handling; no automatic uploads.
- [x] TestFlight feedback email saved to the monitored route and verified after reload.
- [x] Owner pilot retrieves and validates all three TestFlight Beta journals in
  the tested developer-enabled Watch/trusted-Mac setup; general tester access
  remains unverified.
- [x] Public pilot explicitly accepts descriptions and optional cropped
  screenshots without requiring journal attachments. Native export now has a
  separate draft; tester delivery remains unverified and unreleased.

An email route does not itself solve exporting journals from a TestFlight Watch
app. If developer tools cannot copy that app's container, report the limitation
and evaluate user-triggered export before inviting testers who need that path.
