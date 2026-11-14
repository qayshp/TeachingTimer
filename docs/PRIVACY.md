# Privacy and diagnostics

Policy updated November 13, 2026 for the optional iPhone support companion.

Teaching Timer has no developer-operated account service, advertising or analytics
SDK. The app does not automatically upload its journals to the developer. It does
not request location, contacts, microphone, camera or HealthKit data. Apple's
native media controls communicate with system media services and the paired
phone; Apple may separately collect system diagnostics under your Apple settings.

## What stays on the Watch

- Current class timing: exact initial Start, scheduled start, duration and end.
- Session recovery intent, preferences and the most recent count result.
- Three diagnostic journals: session/app events, interface/focus events and
  count scheduling/submission events. These contain timestamps, generated run
  identifiers, app/OS versions, lifecycle state and errors. They can reveal
  when you taught or interacted with the app. They do not record song titles,
  audio content, actual audible volume, heart rate or pose sequences.
- If a saved class or recovery value is unreadable, one recovery copy per store
  is preserved locally. It is separate from the rolling journals.
- An unreadable journal may be preserved byte-for-byte in a separate recovery
  file before a new journal is started. These files are not pruned by the
  journal age or event limits. Repeated recoveries can create multiple copies;
  they remain until separately removed or the app's local container is deleted.

Journals are bounded to seven days as new events are written, and also capped at
10,000 session events, 10,000 interface events and 20,000 landmark events. Heavy
use can reach a cap sooner. This is not a promise of a background deletion at an
exact deadline. Class preferences and unreadable-value backups have separate
lifetimes. End class clears current class timing; it does not erase diagnostics.
Removing the app removes its local container; previously exported copies and
system/backup copies are outside that operation.

Connection diagnostics show recent activation, reachability, request and transfer
events on each device. These bounded in-memory events also go to Apple’s local
system log. They are not added to exported reports; no automatic support upload
is performed.

## Sharing is a separate choice

**Settings → Help → Send diagnostics to iPhone** prepares a filtered report.
The iPhone support app is optional; teaching remains independent on the Watch.
An explicit request from the iPhone collects the selected interval (last 2 hours,
last 24 hours, or all retained events) while the Watch app is open. Alternatively, review and send a selected interval from Watch Help. Watch Connectivity transfers it to
the paired companion; no developer server receives it. The phone keeps the latest
received report in local application support, excluded from backup, until replaced,
deleted using the app, or the app is removed. Email support opens a composer with
our address and the report attached; the user reviews and sends it. A configured
Apple Mail account is needed for that composer. Phone file export is available
for other mail apps. Neither an opened composer nor completed device transfer
establishes email delivery.

The report includes app/build/OS versions, exact event timestamps, class/session
and interface state, count timing and selected error codes. Generated run IDs
are replaced with report-local labels. Unknown events and fields, free-form
errors, raw system uptime, saved preference files and unreadable recovery copies
are omitted. Allowed event fields can include configuration summaries such as
class duration and whether count vibrations were enabled. Reports can still
reveal usage and teaching times; they are not anonymous. Missing or unreadable
history and omitted fields are disclosed.
The report is limited to 2 MiB; an oversized selection is rejected rather than
silently shortened. No system logs, audio or other apps' data are collected.

Prepared files are held in an app-owned cache, excluded from backup. Up to eight
files (at most 16 MiB of report content) are kept. During a later preparation,
files older than 24 hours are removed unless retained by the current report
view or an outstanding transfer. Cleanup is not scheduled in the background and cannot run if the app is
never used again. The system may clear caches sooner. Leaving the sharing view
does not immediately delete a file that its destination may still be reading.
The original journals, prepared files and recipient copies have separate lifetimes.

Developer-tool copying to a trusted Mac was separately verified for the
maintainer's TestFlight build on a developer-enabled Watch; ordinary testers
are not expected to use that route.

Before sharing, inspect and minimize the data. GitHub issues are public: use
cropped screenshots and sanitized excerpts. Arrange a private route with the
maintainer for larger captures. Sending diagnostics to Apple through Feedback
Assistant is a separate action, not an automatic app feature. Copies already
sent to Apple or a recipient follow that recipient's handling policies.

Tap the upper-left gear, then **Settings → Privacy → Full policy on Watch**,
to read this complete policy offline. Help, About and the complete MPL license
are also readable on the Watch.
Website destinations show an address and a QR code for a phone camera. Visiting
GitHub or Mozilla is subject to those websites' policies; no journals or other
app data are included in these addresses or QR codes.

## Private support

Email [teachingtimer@qays.net](mailto:teachingtimer@qays.net) with a short
description; no logs are needed to start. The maintainer receives the sender
address, message and any attachments you choose to send in an iCloud Mail inbox.
These support messages are separate from the Watch's rolling journals and are
kept while needed to handle the request. You can ask about removing a report by
emailing the same address; copies already shared with another recipient or
retained in backups may have separate lifetimes.

Share only necessary details. The maintainer will ask before forwarding raw
private evidence to Apple or another party. Opening email support does not establish attachment delivery. In the Watch app,
**Settings → Help → Contact support** shows the address and QR code for the
reporting steps. The [public issue form](https://github.com/qayshp/TeachingTimer/issues/new/choose)
remains available for sanitized descriptions.
