# Physical Watch diagnostic collection

The intermittent developer-tunnel failure is filed as **FB25329139**. Its
October 26 evidence includes failure while the Watch was already unlocked,
fully awake, and on the laptop, followed by success on retry. See
[Apple feedback status](APPLE_FEEDBACK.md). This does not establish the cause
of the separate direct-collector error below.

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

### October 25: forwarded archive recovered again

Build 11's Runtime, Interface, and Landmark journals copied successfully. One
new Watch sysdiagnose started at about 00:15:55 Pacific. Its direct transfer broke
after 96,124,443 bytes with CoreDevice 13003 / POSIX 32 (broken pipe). Subsequent
Watch inventories timed out, including an explicit unlocked/awake retry. The
partial download was unusable; display dimming was not established as the cause.

The paired iPhone's 00:15:56 capture transferred and validated successfully
(395,621,960 bytes, 889 logarchive files). At about 00:24, a combined
`co-sysdiagnose` appeared on the phone. Its 551,955,456-byte transfer completed;
the extracted Watch member passed gzip validation (156,324,666 bytes, 581
logarchive files). Both devices' archives supplied incident-time media evidence.
No second capture, device reset, logging profile, or further administrator prompt
was needed. This repeats the verified phone-forwarding recovery route; it does
not mean every phone-only capture includes Watch logs.

The preceding installation also encountered DDI errors 12040/12044/12018 and a
tunnel error 4000/1001 despite a reported awake Watch. A later connected Device
Hub state allowed installation and launch. The observed recovery does not isolate
which device/service transition fixed access. Keep installation, small journal
copying, capture generation, and large-file transfer as separate outcomes.

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

## Three separate operations: requirements and observed failures

Updated October 24, 2026 for Xcode 27.1 and a physical SE 3 on watchOS 27.
Do not confuse an unlocked-but-dimmed Always-On display with the passcode lock
that normally follows taking the Watch off the wrist. A 70-second wake setting
makes initial connection attempts easier; it does not guarantee developer access.

Apple's current [Device Hub pairing guide](https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac)
requires developer pairing/trust and Developer Mode on Watch and companion phone,
and describes network pairing and compatible local networking. The
[watchOS Group Lab](https://developer.apple.com/videos/play/wwdc2026/8014/)
explains that recent Xcode connects directly from Mac to Watch; devices must be
able to communicate on the network. It recommends keeping the Watch nearby.
Phone–Watch Bluetooth connectivity, matching Wi-Fi names, and a remembered
pairing are therefore useful but not proof of a usable Mac developer tunnel.
Neither source establishes a universal requirement to keep the display bright
throughout every transfer.

| Operation | What must work | What brightness/unlock establishes |
| --- | --- | --- |
| Copy app journals | Trusted developer connection and access to the installed app's data container; correct bundle ID/path; file accessible under current data protection. No app launch is needed. | A locked, charging SE 3 journal copy succeeded on September 19. Unlock/wake can help establish access, especially after reboot, but bright/unlocked is not a sufficient condition and is not a proven universal requirement for every copy. |
| Collect/copy system diagnostics | Starting a new capture needs a working diagnostic service. Capture generation, transfer and gzip/tar validity are separate checks. Copying a completed archive needs accessible crash-log storage; phone-forwarded combined archives provide another route. | We released the user from keeping the screen awake after the fresh October 24 capture started; direct download later succeeded. We did not measure the Watch's actual lock state throughout. A client timeout can leave the device collecting; inspect before starting another. |
| Install a development build | Usable developer services/DDI, supported Xcode/device OS, valid signing/provisioning/entitlements, and device acceptance of installation. Install and launch are separate operations. | Start unlocked/awake and respond to device trust prompts if requested. Those conditions do not fix a missing developer tunnel or failed DDI mount. Confirm the install result and installed bundle/build; a successful build on the Mac does not confirm deployment. |

[Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
is required for development installation/run; normal App Store/TestFlight
installation follows a different path. TestFlight could reduce future manual
build deployment friction, but would not itself solve raw developer-log access.
That is a distribution option, not a change made during this investigation.

### Verified history, rather than a list of supposed cures

- Direct administrator-authorized `log collect --device-udid` failed for Watch
  with connection-refused / `Device not configured (6)` despite trust and visible
  device reports. The same general collector worked for the iPhone. An elevated
  Watch retry also lacked the normal user's pairing context. These are distinct
  tool/service failures, not proof the historical logs were irretrievably gone.
- Earlier CoreDevice requests timed out or lost a socket after partial downloads
  (including roughly 105 MiB). A Watch capture nevertheless completed on-device;
  a phone-forwarded `co-sysdiagnose` later yielded a valid Watch archive. Do not
  treat a partially downloaded gzip as usable or keep restarting collection.
- During the first October 24 evening attempt, journal access failed with
  CoreDevice 4016: developer-services, trusted-discovery and power assertions
  were unavailable. Further copies/inventories timed out. The user had reported
  unlocked/awake and the same Wi-Fi. One Device Hub restart did not resolve it.
  At 23:01 the iPhone diagnostic showed Watch Bluetooth connected, while Mac
  developer access was still unavailable. The phone-only sysdiagnose did not
  generate a new Watch archive; existing combined captures predated the classes.
- After the user moved the Watch physically closer and woke it, the first journal
  copy still timed out. Crash-log inventory then succeeded and the next journal
  copy worked. Both runtime and landmark journals were retrieved. A fresh
  `devicectl device sysdiagnose` requested at 23:11:50 completed and downloaded
  directly, without another administrator prompt. Its 161,969,870-byte gzip
  validated; 570 system-logarchive files were extracted and queried successfully.
  Proximity is correlated with success, but a controlled test has not isolated
  distance, radio state, time, or service recovery as the cause.
- Build 8 installation records include CoreDevice 4016, a network timeout (60),
  and a DDI mount failure (12040 / 12044 / 12018, no mounted-image metadata).
  A later unlocked retry succeeded and an installed-app query confirmed the
  build. Unlocking was not an immediate cure on every attempt. Earlier signing
  expiration, keychain authorization and Xcode component preparation were
  separate build/deployment blockers; none proves a journal-copy problem.

### Practical collection sequence

1. Prepare paths/commands first. Read device status, then try the small journal
   copy once before asking the user to tap continuously. Use the existing bundle
   ID `com.qayshp.TeachingTimer`; do not launch or reinstall to extract a file.
2. For build 10 and later, copy `RuntimeDiagnostics.json`,
   `InterfaceDiagnostics.json`, and `LandmarkDiagnostics.json`. The interface
   detail file may not exist until a routine wake/dim event has been written.
3. Inventory Watch and phone sysdiagnose storage. Reuse an existing capture only
   if its time and retained contents cover the incident. If needed, start one
   new Watch capture, then separate generation from download progress.
4. Tell the user promptly when the small files are safe and the capture is
   underway. Do not equate waiting for analysis with needing an awake Watch.
5. Validate file transfer and archive integrity. If the direct copy fails, look
   for the matching combined archive on the phone. Preserve partial results and
   exact errors; use bounded retries, not repeated re-pairing or network toggles.

If the developer connection remains intermittent, Apple's DTS escalation is
CoreDevice profiles on Mac/phone/Watch, a Watch sysdiagnose profile, reproduction,
and Mac/Watch diagnostics. See the linked DTS guidance above. Profiles increase
evidence; they are not a proven connectivity repair. No such profiles were
installed by this investigation.
