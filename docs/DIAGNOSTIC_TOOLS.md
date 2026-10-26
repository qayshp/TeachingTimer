# Local diagnostic tools

Python 3.9+ standard library only. Device operations require the selected Xcode's
`xcrun devicectl`; command syntax was checked against Xcode 27.1. These tools do
not alter pairing, restart Device Hub, toggle networks, request administrator
access, or start a system diagnostic. Raw output is private; use ignored `work/`
folders, not public issues/attachments without review.

## Copy the app journals

```sh
python3 scripts/watch_device.py journals \
  --device 'EXPLICIT_WATCH_IDENTIFIER' \
  --output work/support/NEW-INCIDENT/journals
```

The output directory must not exist, preventing evidence overwrite. Explicitly
supply the Watch ID/name; the script never chooses a device based on proximity.
It records bounded discovery/details queries, then copies and validates Runtime,
Interface and Landmark JSON separately. Discovery/details can be cached and are
not treated as proof that the transfer service works. A failed query does not
prevent trying the small copies. No app launch/install occurs.

Default: one attempt per file, 30 seconds per command, 300 seconds total.
Discovery/details use shorter 10/15-second limits. `--retry` permits just one
extra attempt per unsuccessful copy, preserving both. `--timeout` (1–120 seconds)
and `--budget` (10–900 seconds) allow an explicit bounded window. A command's
local watchdog adds at most three seconds within the total budget. Transfer
attempts have separate result/console files and copied payloads; only validated
copies are promoted to the output root's canonical names.

`operation.json` records UTC start/end, monotonic durations, stages, command
results and per-file outcomes. Detailed CoreDevice error codes remain in each
raw result. Partial success exits 2 and keeps successful files. Missing interface
history can mean that no routine transition was recorded; a failed copy alone
cannot establish that explanation. The original files on the Watch are untouched.

The tool announces that device operations are finished **before offline analysis**.
An interrupted or timed-out command may leave a device operation completing;
inspect saved evidence before retrying. No assertion is made that dimming caused
a failure or that brightness is necessary throughout a transfer.

## Install a prepared signed app

Only run this when physical installation is requested:

```sh
python3 scripts/watch_device.py install \
  --device 'EXPLICIT_WATCH_IDENTIFIER' \
  --app /absolute/path/to/TeachingTimer.app \
  --output work/support/NEW-INSTALL \
  --launch
```

Local checks reject a Simulator app, a mismatched bundle ID, missing build or
executable, and an invalid signature. Installation and installed-app version
verification are separate commands. The default install command timeout is 90
seconds; the overall budget remains 300 seconds. `--retry` allows a second install
only after a failed request and a successful query showing that the requested
version is absent. No retry follows an unknown verification outcome.

If the desired version is present after an unacknowledged install, the tool
reports **version present / install unconfirmed**: an older install of that same
version might already have been there. It neither claims success nor blindly
reinstalls. A successful build on the Mac is never treated as device deployment.

`--launch` explicitly requests launch after acknowledged installation and matching
bundle/version/build. Without it the app is not launched. Launch needs its own
successful result and process ID; a launch failure never triggers reinstallation.
The completion message promptly releases the user from holding the Watch awake.
A launch acknowledgement is not independent evidence of visible pixels or sound.

## System logs are separate

Use [the system-log collection guide](WATCH_LOG_COLLECTION.md). Do not start a
new sysdiagnose merely because a download failed: first inventory existing
captures, check their incident coverage, and use the phone-forwarded archive
when appropriate. This tool intentionally cannot start a large system capture.

Xcode 27.1's local `device info apps --help` documents container access as requiring
an Xcode-installed, profile-validated, third-party, non-enterprise app. Therefore
we must not assume this journal-copy path works with TestFlight distribution.
TestFlight journal access/export is still a separate pilot gate, not verified here.

## Validation

```sh
sh scripts/check-tools.sh
```

The subprocess boundary is faked: tests cover complete/partial/corrupt transfers,
bounded retry, timeouts/budget, evidence preservation, install/query disagreement,
and independent launch success/failure. They never contact or modify a real
Watch, phone or simulator. Live connectivity reliability is not established by
these tests; verify the tools against the next authorized physical operation.
