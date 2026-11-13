# Build and release evidence

Run `python3 scripts/verify-build.py NEW_OUTPUT_DIRECTORY` from the repository.
The directory must not exist. This command never installs or uploads an app. The Simulator build uses
local ad-hoc signing; both device archives remain unsigned. It records the exact source commit and dirty state, selected Xcode path,
Xcode/Swift versions and installed SDKs, then runs repository consistency and model/tool checks,
decodes the website QR assets against their configured destinations,
Simulator build, isolated phone audio-fixture build, development archive and
future distribution-identity archive. The fixture build generates audio locally
and never launches playback.

The early `control-outline-smoke` stage compiles the actual outline helper and
runs 18 independent synthetic cases before the slower Simulator checks. It
verifies both calibrated screen sizes, separate missing-side/blank/text/crossing
negatives, the obsolete Ultra sampling position and invalid dimensions. Each
helper invocation has a five-second deadline plus bounded termination. Both
workflows retain `control-outline-smoke/fixtures/` with PNGs, raw measurements
and results; no Simulator or physical device is used by this stage.

After compiling the Simulator tools, the `screen-text-smoke` stage runs the real
OCR helper on two harmless 324×394 synthetic images containing nine labels.
It checks exact text, corroborated fast recognition, raw confidence and normalized
centers, with a 20-second deadline per image plus bounded termination. This is
an OCR execution check; interactive Simulator action tests remain a separate
local workflow and are not established by this stage.

Every step has its own log and status in `verification.json`. Failed commands
and timeouts remain failures; their partial output is retained. Simulator build
results also have an `.xcresult` bundle. Local archive directories retain the
app, symbols and inspection report. Artifacts from a dirty tree are explicitly
marked and should not be presented as an exact clean-commit release.

GitHub Actions uses the same command on its available macOS 26 runner. It records
its actual toolchain rather than assuming it matches the development Mac.
It retains verification logs, metadata and Simulator results for 14 days, even
on failure. Both Watch-check and TestFlight verification workflows also retain
`screen-text-smoke/`: synthetic images, expected labels, raw OCR responses,
stderr and the result report. It does not upload application archives, signing profiles, private
journals or device captures. Workflow actions are pinned to commit hashes.

Watch checks own full Mac verification for non-publishing native-tooling pushes.
The release workflow retains cheap self-checks for those changes and reserves
its full pass for app candidates or manual rehearsals. The same native guards
remain in `verify-build.py`; [timing evidence and policy](CI_EFFICIENCY.md).

## Inspect a candidate artifact

```
python3 scripts/inspect-artifact.py PATH_TO_ARCHIVE_OR_APP
python3 scripts/inspect-artifact.py PATH_TO_SIGNED_ARCHIVE --require-signed
```

Inspection reads the build/version/revision, verifies the binary exists, and
checks matching binary/dSYM UUIDs for an archive. The signed gate additionally
requires a valid code signature and unexpired embedded profile. It prints no
profile device list, signing certificate or account credentials.

For build 27 onward, inspection also requires the bundled full privacy policy,
MPL license and website metadata/QR assets. This catches missing resources before
distribution. QR decoding verifies the configured address, not physical camera
readability or the availability of the destination website.

**Unsigned structural success is not a signed release.** Even the signed gate
does not establish provisioning-device membership, entitlement eligibility,
App Store acceptance or successful installation/launch. TestFlight requires a
separate authorized signing/export/upload/validation workflow. Physical
installation remains a separate explicit action.
