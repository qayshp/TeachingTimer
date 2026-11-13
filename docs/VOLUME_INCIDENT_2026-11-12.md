# Physical volume failure and diagnostic delivery — November 12

Reviewed November 13, 2026. This is a sanitized evidence record for
[#2](https://github.com/qayshp/TeachingTimer/issues/2), distinct from
[#3 unexpected silencing](https://github.com/qayshp/TeachingTimer/issues/3).
Raw journals, email metadata, device identifiers and system archives remain
private. No volume implementation changed during this investigation.

## Owner observations

- The morning class worked with Amazon Music over AirPlay.
- Timer volume remained unusable in the afternoon class, using Apple Music
  through a USB adapter. The iPhone's physical volume buttons worked.
- Timer refresh, visiting media and returning, and an attempted force close
  did not restore useful control. The journal does not establish whether the
  native media page's own volume control worked on that route.
- A Watch-prepared diagnostic report transferred to the iPhone and reached
  the support mailbox. The attachment parsed successfully: 1,225,763 bytes,
  schema 1, all-retained window, 1,628 events.

Both class windows identify Watch build **261112.0232.39**, source
`16a38f1d9067`, watchOS **27.2.1 (24S132)**. A recorded launch corroborates the
export metadata. This file covers Thursday, November 12; it cannot establish
events from a later day. Provider and output route changed together, so their
individual effects cannot be separated from these two classes.

## What the app journals establish

The good morning and failing afternoon windows retain the same native volume
object, exported as `control-3`. It was created before the morning class.
The afternoon has background setup, media return and three explicit refreshes;
each refresh finishes app-side focus-call logging in about 0.28–0.30 seconds.
Those records explicitly say `controlReplaced=false`, `actualFocus=unobserved`
and `audioRecovery=unobserved`.

These records establish requests, not actual Crown ownership or phone commands.
There are no numeric volume, selected endpoint, output route, command delivery
or audible-output measurements. They do not establish a volume-to-zero event.

The first afternoon `resigned_frontmost` invalidation occurs after the refresh
attempts, so it cannot by itself explain their initial failure. Automatic runtime
recovery preserves the class anchor. There is no recorded afternoon process
launch; the journal does not verify that a full termination/relaunch completed.
This does not dismiss the owner's attempted recovery.

Fresh raw copies corroborate all 1,628 emailed events, including consistent
launch/control identities. They add only six later scene/luminance/background
events, not another launch or volume attempt. Successful file copying does not
require the app to generate new events at retrieval time.

## System capture and retention limit

The iPhone sysdiagnose generated early November 13 was copied and validated:
416,991,331 bytes, successful gzip integrity check and tar listing, with only
its system logarchive safely extracted. It contains no child Watch sysdiagnose.

The archive's overall bounds span both classes, but detailed media records do
not. Unfiltered class-window queries retain only 19 morning and 313 afternoon
events; neither contains useful volume/route commands. Retained detailed media
records begin after both classes, and matching volume records begin much later.
Recent control queries decode successfully, corroborating the retention limit.
Missing old commands therefore do not establish that the Watch sent nothing.

Watch collection was blocked by developer-image metadata retrieval despite
working journal access and a usable local image. The separate
[collection guide](WATCH_LOG_COLLECTION.md#november-13-device-services-and-retention)
records the failure and component checks. Neither capture failure nor later
screen dimming diagnoses the app's volume fault.

## Next investigation

A stale native control/backend association after background time and the
reported route/provider change is plausible, not established. Retention is
intentional: replacing the control previously regressed Crown focus. Preserve
the normal working sequence while comparing retained refocus against a fresh
object in the isolated native-volume probe, with provider and route varied
separately. Record audible response and verified process relaunch explicitly.

Use a short supervised reproduction and immediate system captures. A late
capture cannot restore rolled-out detail. Repeating empty unified-log queries
does not restore that stream; keep any capture-time state separate from proof
of class-time commands. Repeated capture restarts are not a retention remedy.
Support delivery is now demonstrated on a later build; startup, offline,
interruption and upgrade tests remain in #26.
