# Privacy and diagnostics

Last reviewed October 28, 2026, against the build-21 source.

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

Journals are bounded to seven days as new events are written, and also capped at
10,000 session events, 10,000 interface events and 20,000 landmark events. Heavy
use can reach a cap sooner. This is not a promise of a background deletion at an
exact deadline. Class preferences and unreadable-value backups have separate
lifetimes. End class clears current class timing; it does not erase diagnostics.
Removing the app removes its local container; previously exported copies and
system/backup copies are outside that operation.

## Sharing is a separate choice

A development build's journals may be copied to a trusted Mac using Apple's
developer tools. TestFlight journal access is not yet verified. There is no
in-app journal export in this build. Do not promise testers automatic collection.

Before sharing, inspect and minimize the data. GitHub issues are public: use
cropped screenshots and sanitized excerpts. Arrange a private route with the
maintainer for larger captures. Sending diagnostics to Apple through Feedback
Assistant is a separate action, not an automatic app feature. Copies already
sent to Apple or a recipient follow that recipient's handling policies.

The bundled privacy manifest declares no tracking/data collection and describes
the existing preferences and monotonic timing API uses. App Store Connect privacy
answers still require a review of the actual release and support workflow;
this page is not a claim that Apple has validated the app or its disclosures.

Questions can be raised through the [project's public issue form](https://github.com/qayshp/TeachingTimer/issues/new/choose)
without including personal data. A dedicated private support contact must be
confirmed before broader distribution.
