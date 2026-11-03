# Supervised TestFlight owner pilot — November 2, 2026

This dated record covers the separately authorized physical pilot after the
Mac-only review. [Current verification](../DEVELOPMENT_STATUS.md) owns the installed
build status; [TestFlight preparation](TESTFLIGHT_PREPARATION.md) owns signed
artifact provenance and the reusable checklist.

## Environment and limits

One physical Apple Watch SE 3 on watchOS 27.2, with Developer Mode enabled and
paired developer access from the maintainer's trusted Mac. TestFlight installation
was observed through its iPhone UI; Watch inventory independently confirmed the
Beta identity and build. The existing development app is a separate installation.
App launches used bundle-targeted developer commands without an attached debugger;
an independent launch by tapping the Watch app icon was not established.
This is a supervised owner test, not a normal tester-access guarantee or a
teaching-length validation.

## Completed pilot checks

| Check | Observation |
| --- | --- |
| Initial TestFlight install | Teaching Timer Beta 1.0 (35), `net.qays.TeachingTimer.watchkitapp`, installed separately from development build 25 and launched successfully. |
| Class and settings persistence | Beta class/runtime and settings were exercised. The configured and relaunched preference files were byte-identical. |
| Intentional Stop | A stopped session restored stopped intent on relaunch; no automatic Start was observed before the later explicit Resume. |
| Running-intent relaunch | The same saved class restored at 16:26:06 PST; `runtime_started` and `automatic_restart_succeeded` followed at 16:26:07 without manual Resume. This is not the exact dimmed Simulator reproduction or proof for arbitrary callback ordering. |
| Beta journal retrieval | All three files copied and parsed using developer tools against the Beta Watch identifier: 106 runtime events, 12 interface events and 2 count events in the first complete snapshot. A later runtime-only capture records the successful running-intent relaunch. |
| TestFlight update | The authorized 35 → 34 → 35 round trip completed; final inventory confirms Beta 35 and launch succeeded. Preferences before the round trip, on 34 and after updating to 35 are byte-identical. All earlier events from the first complete snapshot remain in the post-update journals: runtime 106 → 170, interface 12 → 37, count 2 → 2. All three post-update files copied and parsed. |
| Preserve development install | Final inventory still identifies development build 25. Every baseline journal event remains as an exact prefix: runtime 1,238 → 1,252, interface 3,770 → 3,774, count 99 unchanged. A stale class retired normally during a brief foreground appearance; see the qualification below. |
| Finish test | End class was confirmed in Beta and Start class returned. Final Beta preferences have no class/runtime keys; settings remain Minutes left on and Count vibrations off, with the latest count result stopped. Watch screen sharing was stopped. The owner personally confirmed TestFlight automatic updates restored on; that final toggle was not independently observed. |

The first journal collection could not obtain the count file before a count had
run. After a count created it, all three copies succeeded. Missing data in that
initial snapshot was not evidence that TestFlight container access was denied.

## Development-app preservation qualification

The development app briefly entered foreground during setup; the cause was not
established. Its stale saved class then retired under the existing scheduled-end
plus 30-minute rule. This is recorded as normal app retirement, not Beta state
migration, and means its old class cannot honestly be described as untouched.

Final development preferences are byte-identical to the available post-install
baseline. A pre-install preference copy was unavailable, so there is no full
before/after preference-byte comparison. The independently captured baseline
journals were retained as described above; the new lifecycle/retirement entries
do not constitute lost journal history.

## What journal access does and does not establish

The copied files came from the **TestFlight Beta container**, not the development
app. This establishes developer-tool retrieval in the specific setup above. It
does not show that an ordinary tester without a developer-enabled Watch and
trusted Mac can obtain those files. There is still no in-app journal export or
upload, and a support email/QR code does not attach diagnostics. Native Watch
file sharing and attachment delivery remain separate, unverified paths.

The installed build's Privacy copy says TestFlight access was not yet verified;
that was its pre-pilot state. This record provides the narrower subsequent result
without changing the installed app or its data handling.

## Evening supervised media and Crown check

The owner subsequently tested Beta 35 with Apple Music on the paired iPhone's
speaker. Initial timer Crown, immediate media-return Crown, Home/reopen and
tap-to-refresh all changed audible volume successfully. These are user-observed
results on one route, not conclusions from returned focus calls alone.

Embedded media progress updated on entry then stalled; re-entry produced a newer
snapshot without reliable live updates. Apple's separate Now Playing app appeared
to advance normally. Seeking on the phone updated both views, but the owner
perceived an unmeasured persistent offset in the embedded view. See the
[dated comparison](MEDIA_PROGRESS_INCIDENT_2026-11-02.md) for evidence and limits.

Runtime automatically recovered after leaving for the standalone app and after
Home/reopen, retaining the same class. Both page-entry and eligible long-dim media
refreshes were recorded. All three journals copied and validated repeatedly,
preserving earlier event prefixes. An installed-build query timed out before
those successful transfers; no reinstall or pairing change was performed.

The final evening snapshot still has the temporary class running. The owner was
told collection was finished and could end the class/pause the music; that cleanup
is not yet confirmed. This is distinct from the completed earlier installation
pilot cleanup above. No new sysdiagnose, screen recording or Apple follow-up was
performed during this short test.

## Still open

- Cold-process launch from the Watch app icon without the developer-command route;
  the evening manual-opening checks returned to an already running process.
- Broader paired audio routes and repeatable Crown reliability beyond the evening
  iPhone-speaker pass; native song-progress recovery; physical haptic delivery,
  wrist-down clock/count behavior, VoiceOver/touch usability, camera scanning,
  expiration-boundary renewal and teaching-length battery/reliability.
- Ordinary tester journal access or an explicitly description-only pilot,
  diagnostic attachment delivery, wider beta/review decisions and Apple runtime
  guidance. Incoming/outgoing plain support email is already verified separately.

Raw inventories, preferences, journals, captures and transfer records remain
private. Public results deliberately exclude account/device identifiers, class
timestamps and raw diagnostic content.
