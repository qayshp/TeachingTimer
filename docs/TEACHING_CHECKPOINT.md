# Teaching checkpoint — build 16

Preserved October 26, 2026, before the diagnostics/tooling batch.

- Git tag: [`teaching-build-16`](https://github.com/qayshp/TeachingTimer/tree/teaching-build-16).
- Exact installed app source: `e5e5ab4bb7ee4c7b58fbfff4dcf2ba23e0f6f788`.
- Version/build: **1.0 (16)**; embedded build time **2026-10-26T18:13:27Z**.
- Saved deployment results confirm installation and launch on the physical SE 3,
  followed by an installed-app query reporting build 16. This is historical
  deployment evidence, not a new device query.
- The maintainer subsequently reported that the revised usability was noticeably
  clearer and easier on the physical Watch. This is not confirmation that the
  outstanding media, volume, haptic-delivery, or seconds-hand issues are resolved.

## Private recovery artifacts

Local folder, excluded from Git:
`work/checkpoints/teaching-build-16-2026-10-26/`.

It contains the original installed Release `TeachingTimer.app`, its matching
`TeachingTimer.app.dSYM`, embedded provisioning profile and decoded signing
information, build/install/query/launch evidence, a manifest, and SHA-256 hashes.
The original app passes strict code-signature verification. Both executable
architecture UUIDs match the saved dSYM. The saved profile expires on
October 13, 2027 (UTC); this does not guarantee indefinite installability.

`Reconstructed.xcarchive` is a **separate newly built signed archive**, made from
unchanged build-16 application sources with the original revision supplied as
build metadata. There was no original Xcode archive from the installed `build`
action. Do not describe the reconstructed archive as byte-identical to the
installed app. Preserve the original `.app` when reproducing the installed build.

No signing keys, device identifiers, raw logs, profiles, or binaries are published.
This local folder is a preserved checkpoint, not an off-machine backup. Normal
Mac backups should include it. Do not overwrite this tag or these artifacts.
A future physical installation remains a separately requested action.
