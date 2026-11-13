# Build and release evidence

Run `python3 scripts/verify-build.py NEW_OUTPUT_DIRECTORY` from the repository.
The source checkout must be clean and committed, and the output directory must
not exist. Put output outside the checkout or under ignored `work/`; creating an
unignored directory in the checkout would itself make the source dirty. Dirty
input is rejected before checks begin. Commit or set aside pending changes
before starting, and leave the source unchanged while verification runs.

This command never installs or uploads an app. The Watch Simulator build uses
local ad-hoc signing; both device archives remain unsigned. Verification records
the exact commit, selected Xcode path, Xcode/Swift versions and installed SDKs.
It runs repository and model/tool checks, decodes the website QR assets, builds
the Watch app and the combined iPhone/Watch Simulator target, compiles diagnostic
fixtures/helpers, executes native OCR/outline checks, and creates development
and distribution-identity archives. Audio fixtures generate their own test
audio; verification never starts playback.

Add `--simulator-smoke` to create disposable small/large Watches and exercise
fresh-process recovery, intentional Stop, saved state and real class-retirement
deadlines. This is separate from building for Simulator. It does not drive
Device Hub or validate paired media playback, Crown volume, tactile haptics or
physical-Watch behavior. CI also supplies `--prepare-ci-runtime`, which prepares
the matching Watch runtime on a GitHub-hosted runner and requires
`--simulator-smoke`; that runtime-preparation option is not for local use.

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
app, symbols and inspection report.

Report schema 2 records `revision`/`sourceDirty` before the run and
`sourceRevisionAfter`/`sourceDirtyAfter` afterward. `complete=true` requires every
requested stage to pass and the source to remain clean at the same commit.
Dirty input, edits during verification or unavailable final Git state leave the
report incomplete and fail the command, even if individual build stages passed.
On GitHub Actions, the report also binds repository ID, workflow reference/SHA,
event/ref, run ID and attempt in its `ci` metadata. A local report without that
identity is useful local evidence, but cannot substitute for trusted hosted
main-push evidence in an automatic release.

GitHub's full verification jobs use the `xcode-27` runner label and explicitly
select `/Applications/Xcode_27.2.app/Contents/Developer`. Reports record the
actual toolchain rather than assuming it matches the development Mac. The
Watch-check and manual TestFlight verification workflows retain logs, metadata
and Simulator results for 14 days, even on failure. They also retain
`screen-text-smoke/`: synthetic images, expected labels, raw OCR responses,
stderr and the result report. These verification artifacts do not upload whole
application archives, signing profiles, private physical-device journals or
physical-device captures. Workflow actions are pinned to commit hashes.

Watch checks own full Mac verification for non-publishing native-tooling pushes.
The release workflow retains cheap self-checks for those changes. For automatic
main-branch app candidates, it reuses the completed successful Watch workflow's
exact-source schema-2 report and digest-verified artifact, instead of repeating
the Mac matrix and unsigned archives. Repository/workflow identity, source/run
attempt, clean before/after state and every required stage must match; stale,
incomplete or failed evidence blocks publication. PR evidence is not promoted
to a main release. Manual rehearsals and publishing requests still run fresh
full verification, including the two-size booted smoke. Signed publishing still
creates and checks its own archive from the immutable source.

The November 13 read-only consumer check accepted real hosted evidence, while
the corresponding tooling-only release workflow correctly skipped app work.
An automatic app-candidate publish through reuse was not exercised by that
validation. See [timing evidence, provenance and event limits](CI_EFFICIENCY.md#november-13-validation).

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
