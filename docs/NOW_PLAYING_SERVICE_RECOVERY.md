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

The next narrow experiment was to reconstruct **only** `NowPlayingView` on user
request; the successful build-7 tests are recorded below. A minimal native-media
host would help separate framework
behavior from TeachingTimer's view hierarchy. No automatic periodic recreation
or private-API error hook is justified by this evidence.

The Apple report includes the physical screenshots, Simulator before/black/
recovered screenshots, focused system-log and journal excerpts, reproduction
instructions, source snapshot, and the combined Watch/iPhone sysdiagnose.
Raw evidence remains private under ignored
`work/support/2026-10-24-physical-media-feedback/`. The report asks Apple whether
there is a supported recovery mechanism or whether WatchKit should recover
internally. No further class incident is required before Apple can investigate.

## Native-view-only recovery: build 7

The user-authorized candidate adds **Reload media** to the secondary Class
sheet. On dismissal it changes an identity attached only to `NowPlayingView`
and selects the media tab. No timer-page identity, volume adapter, class store,
runtime controller, or landmark controller is replaced. It uses public SwiftUI
view identity; there is no service manipulation or automatic retry in app code.

On the same SE 3 40 mm / watchOS 27.0 Simulator, the existing Home → service
termination → reopen → timer → media sequence produced black media content in
both trials. The new action restored native Not Playing and transport controls
**2/2 times without force-closing TeachingTimer**:

| Trial | Reload time (October 24 PDT) | Host PID | New native service PID | Active count progress at reload |
| --- | --- | --- | --- | --- |
| 1 | 01:55:47 | 94486 throughout | 95757 | 58.1% |
| 2 | 01:57:10 | 94486 throughout | 96325 | 26.4% |

- Saved ClassContext and runtime intent were identical before and after both
  tests. Each reload preserved the runtime ID/start/expiration already active
  at that moment. Going Home earlier in the reproduction separately caused the
  existing foreground runtime-recovery behavior; do not attribute that to reload.
- There was one companion volume-control creation and no dismantle during the
  candidate process. The same control ID received focus again on returning to
  the timer. The adapter's focus/resign implementation is unchanged. This is
  lifecycle evidence, not proof of physical Crown responsiveness or audio volume.
- Both landmark runs retained their original run ID, anchor, and completion
  deadline. The first run stopped further haptics at 40.54 seconds because its
  next pulse was 0.54 seconds late, above the existing 0.4-second cutoff; its arc
  continued and the run completed. The second run submitted all 21 timing pulses
  on the original schedule and completed normally. Simulator does not prove
  physical haptic delivery.
- Screenshots verify restored media pixels and the continuing count arc. No
  paired-iPhone media playback was established by this test.
- All nine deterministic suites and the Debug watchOS Simulator build passed.
- The reload action/help rendered and opened native media on Series 12 46 mm
  and Ultra 4 49 mm simulators as well. The Series check used the maximum-text
  launch flag; this does not establish that every native Form row adopted that
  environment size. Both checks used the new-class draft without starting it.

Private evidence is under `work/support/2026-10-24-media-reload/`. Physical
validation should try Reload media during the naturally occurring failure,
check that the active count and class continue, then return to the timer and
confirm immediate Crown volume. This is a manual recovery option, not a claim
that the original watchOS failure has been prevented.

## Automatic refresh: build 8

Build 8 uses the same narrow native-view identity change automatically on each
deliberate timer → media selection, and on an active return after the app has
actually entered the background if media is still selected. Returning to the
timer defers the refresh until media is opened. A regular inactive/active wrist
wake does not trigger it. There is no periodic retry, screenshot inspection, or
private service-error hook. The manual Class action remains and suppresses a
duplicate refresh when it also changes the selected page.

`MediaReloadPolicy` isolates these decisions and is exercised by deterministic
event-sequence checks, including foreground callback ordering and repeated wrist
wakes. The native volume adapter, runtime/count controllers, class store, clock
geometry, and original timeline/pager structure remain unchanged.

Each `media_reload_requested` event records the reason (`page_entry`,
`background_return`, or `class_options`), manual/automatic mode, previous/new
generation, active count/progress, and runtime context. `failureDetected` is
explicitly `unobserved`. This preserves when and why the app recreated the view,
but cannot establish whether the old view was broken. Retained system-service
logs can independently establish a connection error. Do not count preventive
refreshes as detected failures or successful recoveries.

### Simulator checks and remaining rendering uncertainty

On the same SE 3 40 mm Simulator, two deliberate native-service terminations
were followed by automatic native-content recovery without terminating the
TeachingTimer process (PID 14969):

- Background return with media selected: a refresh at 02:50:11 PDT created a
  replacement native connection. Later direct Device Hub and simctl captures
  showed Not Playing and transport controls, without a manual reload or another
  app-page change. Initial recovery captures were black, so instantaneous
  recovery or a measured latency bound is not established.
- Background return to the timer: no media refresh occurred until the subsequent
  swipe at 02:52:10 PDT. Direct Device Hub and simctl captures showed native media
  content after that entry. The active count still had its original anchor.

Saved class context and runtime intent matched before/after both trials. The
same companion volume-control object survived, without dismantling. Going Home
separately interrupted runtime and exercised the existing foreground runtime
recovery; the native-view refresh did not itself restart a session.

Both count runs retained their run IDs and finished with `reason: completed`.
Their haptics stopped at the existing missed-deadline cutoff (about 0.405 and
1.274 seconds late); the second was in the background with runtime interrupted.
This validates preserved visual-run state, not uninterrupted haptic delivery.
Three later page-entry refreshes retained the same running runtime ID, and two
Lock/unlock cycles added no refresh events. All ten deterministic suites passed,
including the new policy cases, and the signed Simulator build succeeded.
The manual Class action produced exactly one further generation and rendered
native controls. Across the final process there were seven refresh requests,
one companion-control creation, no dismantles, and unchanged saved class/intent.

Repeated-swipe tests also produced intermittent black captures in both the
candidate and the unchanged build 7 under the same Simulator conditions. One
candidate capture remained black at five seconds and displayed controls by ten
seconds without another gesture; an unchanged-build capture was still black at
eight seconds. These observations do not establish that automatic refresh causes
the delay, nor that every black page is repaired by it. A stable page wrapper,
changing identity in the selection binding, removing the native host offscreen,
and separating the clock timeline from the pager did not reliably eliminate the
captures. Those structural experiments were removed from the shipped change.

This is automatic recovery for the tested connection-loss scenario, not a claim
to have fixed every native-media rendering failure. Physical startup latency,
actual playback/Crown behavior, and recovery during a naturally occurring blank
page require hardware validation. **Volume silencing remains a separate
high-priority bug**; the companion control is not reconstructed by this change.
The lower-priority seconds-hand dimming transition is unchanged.

Private evidence is retained under ignored
`work/support/2026-10-24-auto-media/`, including the baseline comparison, failed
structural experiments, final candidate logs, screenshots, and state snapshots.
