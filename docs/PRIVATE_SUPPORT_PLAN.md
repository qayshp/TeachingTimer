# Private support and diagnostic intake

Updated November 2, 2026. **The approved support alias is configured in the
existing iCloud mailbox; inbound delivery is verified and an outbound reply test
remains pending.**
No mail routing or MX records were changed. This procedure is for the initial
pilot, not an automatic upload service. Keep the current public issue route
limited to sanitized descriptions. A harmless test email reached the mailbox
on November 2, and its reference/content were checked. Do not describe outbound
reply behavior or diagnostic attachment delivery as tested.

## Recommended route

Use a dedicated support email alias in an existing, monitored mailbox. Initial
reports should contain a description, app/build and OS versions, approximate
incident time with time zone, the affected page, playback source/output route if
relevant, and whether page switching or another recovery helped. No journal or
system capture is needed for the first message.

The maintainer's proposed qays.net domain currently uses iCloud Mail. Add an alias
at the existing provider; do not replace its MX records or enable another inbound
mail service merely for this app. Confirm a harmless test message arrives and
replies work before advertising the route in About, the privacy policy,
repository support links, or TestFlight's feedback contact.

For this small pilot, email is the initial reporting route. Diagnostic sharing
remains a separate, deliberate action. The Watch app continues making no
automatic uploads.

## Getting journals off the Watch

The current app has no journal export, upload or attachment control. Journals
are private files in the Watch app's container. Sending an ordinary email from
Watch Mail, scanning the support QR code, or opening a support address does not
attach them. The empty distribution container is packaging, not an iPhone
companion or file-transfer service.

For the maintainer's self-pilot, try the existing developer-tool container copy
and verify the resulting files. Access to a development build does not prove
access to a TestFlight build. An ordinary tester should not be told to attach
journals they have no supported way to retrieve.

Before wider testing, evaluate a small, explicit sharing flow on a physical
Watch: first a harmless test file, then a minimized journal package, and verify
the received attachment. A share sheet appearing is not proof of delivery.
If native sharing cannot deliver files reliably, consider a user-triggered
private upload with a clear preview and consent step. Neither path is
implemented in TeachingTimer; update privacy wording before introducing an upload.

A separate [native sharing probe](../tools/diagnostic-share-probe/README.md)
was tested on the SE 3 Simulator, watchOS 27.2, November 2. Text, a 198-byte JSON
and a 941,009-byte synthetic ZIP opened the native share sheet. JSON and ZIP
reached Messages compose; the system requested both file representations.
Only Messages was offered in this Simulator setup. No recipient was selected,
nothing was sent, and cancellation returned correctly. This is promising
attachment-presentation evidence, not proof of delivery, Mail support, or a
usable tester-facing journal export.

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
- [ ] Outbound reply from the alias tested.
- [ ] Approved address added to About/support QR destination and repository guide.
- [ ] Privacy/support wording describes actual handling; no automatic uploads.
- [ ] TestFlight feedback contact matches the monitored route.
- [ ] Self-pilot separately verifies journal retrieval from the distribution app.
- [ ] Before wider invitations, verify a tester-usable journal delivery path or
  explicitly limit the pilot to reports without journal attachments.

An email route does not itself solve exporting journals from a TestFlight Watch
app. If developer tools cannot copy that app's container, report the limitation
and evaluate user-triggered export before inviting testers who need that path.
