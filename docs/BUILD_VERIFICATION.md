# Build and release evidence

Run `python3 scripts/verify-build.py NEW_OUTPUT_DIRECTORY` from the repository.
The directory must not exist. This command never installs or uploads an app. The Simulator build uses
local ad-hoc signing; both device archives remain unsigned. It records the exact source commit and dirty state, selected Xcode path,
Xcode/Swift versions and installed SDKs, then runs repository consistency and model/tool checks,
Simulator build, development archive and future distribution-identity archive.

Every step has its own log and status in `verification.json`. Failed commands
and timeouts remain failures; their partial output is retained. Simulator build
results also have an `.xcresult` bundle. Local archive directories retain the
app, symbols and inspection report. Artifacts from a dirty tree are explicitly
marked and should not be presented as an exact clean-commit release.

GitHub Actions uses the same command on its available macOS 26 runner. It records
its actual toolchain rather than claiming to use the development Mac's Xcode 27.1.
It retains verification logs, metadata and Simulator results for 14 days, even
on failure. It does not upload application archives, signing profiles, private
journals or device captures. Workflow actions are pinned to commit hashes.

## Inspect a candidate artifact

```
python3 scripts/inspect-artifact.py PATH_TO_ARCHIVE_OR_APP
python3 scripts/inspect-artifact.py PATH_TO_SIGNED_ARCHIVE --require-signed
```

Inspection reads the build/version/revision, verifies the binary exists, and
checks matching binary/dSYM UUIDs for an archive. The signed gate additionally
requires a valid code signature and unexpired embedded profile. It prints no
profile device list, signing certificate or account credentials.

**Unsigned structural success is not a signed release.** Even the signed gate
does not establish provisioning-device membership, entitlement eligibility,
App Store acceptance or successful installation/launch. TestFlight requires a
separate authorized signing/export/upload/validation workflow. Physical
installation remains a separate explicit action.
