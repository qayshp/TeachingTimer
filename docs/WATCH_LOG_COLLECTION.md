# Physical Watch diagnostic collection

## Meaning of the direct collection error

The administrator-authorized `/usr/bin/log collect --device-udid …` attempt
returned `Device not configured (6)` and produced no usable Watch archive.
On macOS, error 6 is POSIX `ENXIO`; the text alone does not identify a missing
setting, lost trust, or a particular service. The device UDID was used, so a
device-name apostrophe is not the cause of this invocation.

App-container copies, crash-report access, and installation use different
operations from unified-log collection. Their success does not prove the
direct `log collect` path works, and that path's failure does not prove the
Watch is generally unpaired or inaccessible. The exact internal failure of
the direct collector remains unresolved.

## CoreDevice route found on October 24, 2026

Xcode 27.1 exposes `devicectl device sysdiagnose` in addition to the older,
broader `devicectl diagnose`. Check the installed tool's help before use:

```sh
xcrun devicectl device sysdiagnose --help
xcrun devicectl device sysdiagnose --device WATCH_UDID \
  --destination /private/local/path/watch-diagnostics --timeout 300
```

The first live attempt used the broader `diagnose` command with only the Watch
selected and host sysdiagnose excluded. Its 45-second deadline expired, leaving
a partial host/CoreDevice bundle, but Watch collection continued. A subsequent
request reported `sysdiagnose already in flight` (`libsysdiagnoseError -56`).
That was evidence of an ongoing collection, not another pairing failure.

The Watch then exposed an `IN_PROGRESS_…` directory under
`systemCrashLogs/DiagnosticLogs/sysdiagnose`, followed by a completed 152.7 MB
`.tar.gz`. Use the exact name returned by the inventory to retrieve it:

```sh
xcrun devicectl device info files --device WATCH_UDID \
  --domain-type systemCrashLogs --subdirectory DiagnosticLogs/sysdiagnose \
  --no-recurse
xcrun devicectl device copy from --device WATCH_UDID \
  --domain-type systemCrashLogs \
  --source DiagnosticLogs/sysdiagnose/EXACT_ARCHIVE_NAME.tar.gz \
  --destination /private/local/path/watch-sysdiagnose.tar.gz --timeout 600
```

Do not keep starting collections while one is in flight. A client timeout does
not necessarily cancel the device operation. Keep archives outside version
control: they contain system-wide private data. The first wireless transfer
reached roughly 105 MiB before its 180-second timeout, so allow a longer transfer
deadline and verify the resulting gzip/tar before analyzing it. Archive generation is distinct
from successful transfer, integrity checking, and useful incident-time coverage.

### Successful retrieval through the paired iPhone

The longer direct-Watch retry lost its network socket (CoreDevice 7000,
underlying POSIX 60); a final attempt could not establish a tunnel (4000/1001).
The paired iPhone had automatically received a combined `co-sysdiagnose_….tar`
for this collection. Its 526.4 MB transfer completed successfully, even though
both devices were using the local network. The combined archive contained
separate iPhone and Watch `.tar.gz` files. Both passed gzip integrity checks;
the Watch member was 160,080,384 bytes. The Watch `system_logs.logarchive` was
extracted and successfully queried with `log stats` and `log show`.

If direct Watch transfer fails, inventory `DiagnosticLogs/sysdiagnose` on the
paired iPhone with the same commands, substituting its UDID. Copy the exact
combined archive returned by that inventory, then extract the Watch member.
Do not confuse AppleDouble `._` metadata entries with the actual `.tar.gz`.
This is a verified recovery route for this run, not a guarantee that forwarding
or wireless transfer always completes. No re-pairing, restart, logging-profile
installation, or new administrator authorization was needed for this route.

The archive's overall range was October 23 00:12:08 through October 24 00:12:07
local time, with about 3.16 million events. Retention varies by event type:
the noon incident interval had only 60 retained records and no results in the
targeted media query, while the evening interval retained substantial evidence.
See [the physical media incident assessment](MEDIA_INCIDENT_2026-10-23.md).

## Profiles and incident capture

No logging configuration profile was present on the Watch during this attempt;
none was installed to obtain the sysdiagnose. A profile may still be needed to
increase the detail retained for a future media incident. Do not equate profile
absence with the proven cause of `ENXIO`.

[Apple's crash and console guide](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs)
describes Watch console logging via a logging profile on the paired iPhone,
then connecting that iPhone to the Mac and using Console. The
[watchOS Profiles and Logs catalog](https://developer.apple.com/feedback-assistant/profiles-and-logs/?platform=watchos)
provides Media Services, CoreDevice, and sysdiagnose instructions. Follow the
current instructions for the selected profile; installation can require device
confirmation, and gathering now cannot recreate previously unretained logs.

For connection failures specifically,
[Apple Developer Technical Support](https://developer.apple.com/forums/thread/811726)
requests CoreDevice profiles on Mac, iPhone and Watch, a Watch sysdiagnose
profile, then reproduced failure and Mac/Watch sysdiagnoses. This is an
escalation procedure, not a guarantee that a profile fixes connectivity.

For a black media page, prioritize a screenshot with time, the app journal,
Watch and iPhone diagnostics promptly after the incident, and a comparison
with standalone Now Playing if practical. Preserve the distinction between a
black embedded page and a visible native "Not Playing" screen. Do not infer
remote view rendering or audible playback from lifecycle callbacks alone.
