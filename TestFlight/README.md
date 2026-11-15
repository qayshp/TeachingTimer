# TestFlight notes

[WhatToTest.en-US.txt](WhatToTest.en-US.txt) is the short, reviewed tester-facing
summary of recent **merged** app changes. Keep it current when changing features,
behavior or recovery guidance. State known limitations honestly; an experimental
PR or one successful class is not a verified fix. The longer
[changelog](../CHANGELOG.md) preserves dated history and distribution evidence.

The file supplies Apple's native TestFlight **What to Test / What's New** content.
There is no additional in-app modal to interrupt teaching. Apple controls when
and where TestFlight presents notes after installation or updating; metadata
readback does not prove the first-launch screen appeared on a particular device.

The filename follows [Apple's convention](https://developer.apple.com/documentation/xcode/including-notes-for-testers-with-a-beta-release-of-your-app)
for Xcode Cloud. This repository uses GitHub Actions, so the release workflow
explicitly prepares the file and writes it using the App Store Connect API.
The notes are not bundled in the Watch or phone app.

## Preview and update

Edit the text file using concise additions, fixes, testing priorities and known
issues, then commit it. Preview the exact committed text without any API call,
signing credential, app build or device contact:

```sh
python3 scripts/testflight-notes.py --source . \
  --expected-sha "$(git rev-parse HEAD)" --output work/notes-preview-NEW
cat work/notes-preview-NEW/notes.txt
```

The directory must be new. Preview reads the file from the selected Git commit,
so uncommitted edits deliberately do not change its output. The helper fails for
a missing/invalid file or more than 4,000 characters; it never truncates a bullet
or silently substitutes generic notes. The ordinary Python checks validate the
working copy too, before it reaches a release.

A manual workflow's optional `testing_notes` overrides the curated file. Leave
it empty to use the reviewed file. A supplied whitespace-only, oversized or
control-character-containing override fails. Pass free text through the workflow
input/environment, not executable shell interpolation.

## Release contract

The source job validates the exact selected application SHA, reads the committed
notes (or explicit override), and emits a bounded base64 payload with the source,
origin, locale, exact text, character count and content hash. This is a data
output within the same workflow run, not a new artifact download or an API token.
The release job validates and materializes that payload **once, before signing**.
Rehearsal and publishing use the same `notes.txt`; neither rewrites it later.

The release report's existing `notesSHA256`, timing record and retained
`notes.json` identify the text. The retained `notes.txt` permits inspection.
The publisher saves and reads back the exact English `whatsNew` content before
assigning the existing internal Maintainer group. Notes are visible to every
tester with access to that build, not separately customized per group.

Notes-only edits run lightweight repository/Python checks and do not create
another app build or TestFlight upload. The next app release uses the newly
reviewed notes. Changing an already uploaded build's notes is a separate metadata
update, not an upload or a claim that a new build was installed. Exact-source
verification, manual full-check fallback and signing/group safeguards are
unchanged. Track this feature in [issue #34](https://github.com/qayshp/TeachingTimer/issues/34).
