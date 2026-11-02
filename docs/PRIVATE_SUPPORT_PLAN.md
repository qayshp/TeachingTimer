# Private support and diagnostic intake

Prepared November 2, 2026. **Address selection and a delivery test are pending.**
This is the intake procedure for the initial pilot, not a claim that a private
mailbox or upload service is already live. Keep the current public issue route
limited to sanitized descriptions until the maintainer confirms the private
contact. Do not publish a guessed address.

## Recommended route

Use a dedicated support email alias in an existing, monitored mailbox. Initial
reports should contain a description, app/build and OS versions, approximate
incident time with time zone, the affected page, playback source/output route if
relevant, and whether page switching or another recovery helped. No journal or
system capture is needed for the first message.

The maintainer's proposed qays.net domain currently uses iCloud Mail. Add an alias
at the existing provider; do not replace its MX records or enable another inbound
mail service merely for this app. The address and receiving inbox require the
maintainer's choice. Confirm a harmless test message arrives and replies work
before advertising the route in About, the privacy policy, repository support
links, or TestFlight's feedback contact.

For this small pilot, email is simpler than a custom upload backend. It also
keeps diagnostic sharing a separate, deliberate action. The Watch app should
continue making no automatic uploads.

## Handling a report

1. Assign a local case reference. Keep the original report and any raw files in
   a private case directory, outside tracked source. Do not place personal
   details in a public GitHub issue or commit message.
2. Request the smallest useful evidence: often a cropped screenshot or a short
   journal window is enough. Explain what it can contain before requesting it.
   Do not request student identities, passwords, verification codes or a whole
   device capture as a default.
3. For larger/sensitive captures, agree on a private file-sharing link restricted
   to the maintainer. Check the actual recipient/access settings; possession of
   a public unlisted link is not equivalent to restricted access. Use the
   tester's existing sharing service for this pilot rather than adding a new
   account or service requirement.
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

- [ ] Maintainer confirms public support alias and receiving inbox.
- [ ] Alias configured at existing mail provider; inbound and reply tested.
- [ ] Approved address added to About/support QR destination and repository guide.
- [ ] Privacy/support wording describes actual handling; no automatic uploads.
- [ ] TestFlight feedback contact matches the monitored route.
- [ ] Self-pilot separately verifies journal retrieval from the distribution app.

An email route does not itself solve exporting journals from a TestFlight Watch
app. If developer tools cannot copy that app's container, report the limitation
and evaluate user-triggered export before inviting testers who need that path.
