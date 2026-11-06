# Teaching Timer support

Email [teachingtimer@qays.net](mailto:teachingtimer@qays.net) for private help or
to report a problem. A short description is enough to start; no logs are required.

Useful details, when convenient:

- App version/build from the **gear → Settings → About**, and Watch/watchOS version.
- What you were doing, the approximate time and time zone, and what helped.
- For media issues: phone or Watch playback, the audio output, and whether
  sound, volume, controls or song progress stopped working.

Do not interrupt a class to gather evidence. You do not need to include student
information or other personal details. Never send passwords or verification codes.

## Sending from your phone or computer

In build 30 and later, open **gear → Settings → About → Contact support** on
the Watch and scan the QR code with your phone. On an earlier build, use the
email address above directly. Then use your usual email app to send a description.
No GitHub account is required to email support.

Released builds do not yet provide a validated journal-sharing route. Scanning
the support QR code or sending an email does not attach journals. If more evidence would help, the
maintainer will explain what is needed and arrange a private route for files
you can obtain. The maintainer retrieved TestFlight journals using a trusted
Mac and a developer-enabled Watch, but this is not an ordinary tester export
path. Native Watch attachment delivery is still being evaluated; you are not
expected to extract these files yourself.

## Draft diagnostic sharing

The branch implementation tracked by [issue #26](https://github.com/qayshp/TeachingTimer/issues/26)
adds **Settings → About → Share diagnostics**. Choose an interval, prepare and
review the report, then choose **Share file…**. Preparation sends nothing. The
report is filtered and bounded, and the screen warns when history is missing.
Use a private destination; do not attach raw diagnostics to public GitHub issues.

This is **not released or verified for delivery**. In the current Simulator,
only Messages is offered. Small and realistic synthetic files reached its
composer intact, but no message was sent and no recipient received a file.
Physical Watch and TestFlight receipt checks remain necessary. Do not assume
that the support email address is an iMessage destination. Keep using email
descriptions and optional screenshots until a complete route is verified.

## Public reports and known issues

You can also use the [GitHub issue form](https://github.com/qayshp/TeachingTimer/issues/new/choose)
for a sanitized public description; GitHub sign-in is required. Do not post raw
journals or system logs there. Review screenshots for private information first.
The [known-issue guide](docs/ISSUE_TRACKER.md) lists current problems and mitigations.

Teaching Timer does not send diagnostics automatically. See the
[privacy policy](docs/PRIVACY.md) for local data and voluntary support sharing.
