# Native Now Playing service-loss reproduction

October 24, 2026. Apple Feedback **FB25305069**:
“watchOS 27 NowPlayingView stays black after native view service ends;
force-close restores it.” Submitted under Developer Technologies & SDKs →
watchOS → WatchKit.
Feedback Assistant shows the report as **Open** in Submitted. Both attachment
uploads completed at 00:56:28 PDT, and the submitted description was read back
and verified against the prepared report.

A follow-up at 01:27 PDT added the broader captured Simulator stream: 8,877
event records from 00:40:29–00:47:08, controller-invalidation excerpts, and a
reading guide to both trials. The stream was filtered at capture to TeachingTimer
or messages mentioning `NanoNowPlayingViewService`; it is not an unfiltered
system logarchive. The initial report already contained the steps, hypothesis,
screenshots, and selected errors. The follow-up text was read back and verified,
and its attachment upload completed at 01:27:41 PDT.

## Result

Deliberately terminating the native `NanoNowPlayingViewService` in Simulator
reproduced a black media page in **two consecutive trials**, while TeachingTimer's
process remained alive and its timer page still rendered. Force-closing and
reopening TeachingTimer restored the native media UI in both trials.

This is controlled fault injection, not a reproduction of the unknown original
physical trigger. It produces the same visible symptom and WatchKit error
domain/code as the [October 23 physical incident](MEDIA_INCIDENT_2026-10-23.md).
It does not establish why the physical view-service connection ended.

No application source, media/focus behavior, or physical-device installation was
changed for this test. The simulators were left running with the native media
page restored.

## Environment

- Apple Watch SE 3 40 mm Simulator, watchOS 27.0 (24R362).
- Xcode 27.1 (27A9275), macOS 27.0.1 (26A434).
- Teaching Timer 1.0 (6), source checkpoint `a8d8df607d45`. The tested Simulator
  binary was built immediately before that commit; its embedded build revision
  is `1d855a5f9a42-dirty`. The physical incident used 1.0 (5), `6d2e4448ffdc`.
- The native media page initially rendered **Not Playing**, artwork, and
  transport controls. No real playback source was needed for this rendering
  test. Paired-Simulator media discovery remains a separate issue, FB25294079.

## Reproduction

Use a disposable or development **Simulator**; this procedure deliberately
terminates a system view service. Use the current simulator ID and service label,
not the example process IDs recorded below.

1. Build/install TeachingTimer, start a class through the normal UI, and swipe
   to media. Confirm that native media content renders.
2. Press Home/Digital Crown in Device Hub, keeping TeachingTimer's process alive.
3. Find the current service label:

   ```sh
   xcrun simctl spawn SIMULATOR_UDID launchctl list
   ```

   Locate `UIKitApplication:com.apple.NanoNowPlayingViewService[...][rb-legacy]`.
   Terminate only that service in the selected simulator:

   ```sh
   xcrun simctl spawn SIMULATOR_UDID launchctl kill SIGKILL 'system/EXACT_SERVICE_LABEL'
   ```

4. Reopen the existing host process without `--terminate-running-process`:

   ```sh
   xcrun simctl launch SIMULATOR_UDID com.qayshp.TeachingTimer
   ```

5. An old image of native controls can initially remain visible. Swipe to timer,
   then back to media. The media area becomes entirely black, with system time
   and the two page dots still visible. Verify TeachingTimer's PID is unchanged.
6. Terminate and relaunch the host, then swipe to media:

   ```sh
   xcrun simctl launch --terminate-running-process SIMULATOR_UDID com.qayshp.TeachingTimer
   ```

   Native media UI returns with a new view-service process.

## Recorded observations

Times are America/Los_Angeles, UTC−7, October 24.

| Trial | Service termination | Host PID across service loss/reopen | Black media captured | Host recovery |
| --- | --- | --- | --- | --- |
| 1 | 00:41:31; service PID 46345 | 63267 → 63267 | 00:42, after timer → media | 00:43:14; host 73097, new service 73164; native Not Playing restored |
| 2 | 00:43:47; service PID 73164 | 73097 → 73097 | 00:45, after timer → media | Host 74257, new service 74387; native artwork and transport UI restored |

Both service terminations produced:

```text
SPInterfaceRemoteNowPlayingController viewServiceDidTerminateWithError
_UIViewServiceHostSessionErrorDomain Code=2
Underlying service connection to <service PID> halted
```

The physical evening log has the same domain/code but redacts the failure reason.
In trial 2, the callback's underlying-connection text reports PID `-1`, although
the service deliberately terminated for that trial was PID 73164. The broader
trace preserves that distinction and the subsequent remote-controller and
presentation-environment invalidation records.
ClassContext and persisted runtime intent were equal before and after both host
relaunches. The build 6 journal recorded `automatic_restart_succeeded`; class
timing survived, and runtime recovery worked independently of media recovery.

## Interpretation and remaining work

An invalid native remote controller surviving service loss is now a testable
hypothesis. Page navigation alone did not recover it; host recreation did.
This does not yet separate a WatchKit recovery defect from an interaction with
the host's view lifecycle, nor prove a physical service crash or memory pressure.

The next narrow experiment is to reconstruct **only** `NowPlayingView` on user
request, then repeat this service-loss test while preserving class, runtime,
count, and the working companion volume/focus adapter. That experiment has not
been implemented. A minimal native-media host would help separate framework
behavior from TeachingTimer's view hierarchy. No automatic periodic recreation
or private-API error hook is justified by this evidence.

The Apple report includes the physical screenshots, Simulator before/black/
recovered screenshots, focused system-log and journal excerpts, reproduction
instructions, source snapshot, and the combined Watch/iPhone sysdiagnose.
Raw evidence remains private under ignored
`work/support/2026-10-24-physical-media-feedback/`. The report asks Apple whether
there is a supported recovery mechanism or whether WatchKit should recover
internally. No further class incident is required before Apple can investigate.
