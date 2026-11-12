# Private support and diagnostic intake

Updated November 12, 2026. The approved support address is
[teachingtimer@qays.net](mailto:teachingtimer@qays.net) in the existing iCloud
mailbox. Incoming and outgoing plain email were verified November 2; one
Watch-to-iPhone-to-support diagnostic attachment was verified November 11.
No mail routing or MX records were changed. Nothing is uploaded automatically.

## Support route

A description and optional cropped screenshot are sufficient for ordinary
support. Include app/build and OS versions, approximate incident time and time
zone, affected page, media source/output route if relevant, and whether a
recovery action helped. Do not require journals for an initial report.

The [public guide](../SUPPORT.md) is the support QR destination. Scanning the
QR code does not attach diagnostics. Builds with the optional iPhone companion
can request a selected window on the phone or send a prepared report from
Watch **Settings → Help → Send diagnostics to iPhone**. The phone's **Email
support** supplies the recipient and attachment; the user reviews and sends it.
Other phone export destinations may require manually entering the address.

The companion keeps only the latest received report, excluded from backup,
until replaced or deleted. Exact timestamps can reveal teaching/app use.
Sharing is optional and best done after class. Teaching on the Watch remains
independent of the phone app.

## Evidence and limits

- The November 2 developer-enabled Watch/trusted-Mac pilot copied the three
  Beta journals. That is not an ordinary tester workflow.
- The November 6 native Watch share-sheet experiment reached Messages compose
  in Simulator with matching bytes; this did not prove delivery. The owner later
  received an emailed native Watch report, but entering the support recipient on
  Watch was too cumbersome, so the optional companion replaced that route.
- The November 11 companion report reached support as valid schema-1 JSON with
  85 events. Initial linking and the first Mail sheet needed recovery. One
  success does not establish startup, update or interruption reliability.
- [Current build status](../DEVELOPMENT_STATUS.md) and the
  [companion validation record](OPTIONAL_COMPANION.md) separate availability,
  installation, transfer and email receipt. Follow-up fixes need device testing.

[Issue #26](https://github.com/qayshp/TeachingTimer/issues/26) tracks remaining
validation. No HTTPS upload service is planned for the current implementation.
App reports do not include or collect Apple's system sysdiagnose.

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
- [x] Approved address added to Help → Contact support, its QR destination and the repository guide.
- [x] Privacy/support wording describes actual handling; no automatic uploads.
- [x] TestFlight feedback email saved to the monitored route and verified after reload.
- [x] Owner pilot retrieves and validates all three TestFlight Beta journals in
  the tested developer-enabled Watch/trusted-Mac setup; general tester access
  remains unverified.
- [x] Public pilot explicitly accepts descriptions and optional cropped
  screenshots without requiring journal attachments. Optional companion export has one verified physical delivery; repeated and
  general tester delivery remain under validation.

The companion route does not require developer tools. If it is unavailable or
fails, accept a description and screenshot; do not require testers to extract
app containers or system captures.
