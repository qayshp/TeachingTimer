# Physical volume silencing — November 13

Sanitized evidence for [#3](https://github.com/qayshp/TeachingTimer/issues/3),
separate from [#2 unavailable Crown volume](https://github.com/qayshp/TeachingTimer/issues/2).
No volume behavior changed during this investigation. Raw journals and system
captures remain private.

## Owner observations

The owner taught classes at 12:30, 14:00 and 18:45–19:45 Pacific Standard Time.
Early in the evening class, adjusting timer-page volume silenced the audio.
Playback continued silently. Switching to TeachingTimer's media page allowed
the owner to raise the volume from the Watch without using the iPhone.

The evening used **Amazon Music through USB-C audio**. This differs from the
[November 12 failure](VOLUME_INCIDENT_2026-11-12.md), when timer volume remained
unavailable despite recovery attempts. Neither the provider nor the route alone
is established as the cause.

The owner confirms that starting the evening class in the app late correctly
selected the **18:45** scheduled start. The existing prior-quarter anchoring is
working as intended and is independent of volume handling. The owner does not
remember whether volume was adjusted earlier in that class, the direction or
amount of Crown rotation during the mute, or the volume ring's appearance.
Those observations cannot be reconstructed from the app journal.

## What the emailed journal establishes

All times below are **PST (UTC−08:00)**. The Watch report identifies version 1.0,
build **261113.1031.57**, source `b28e499319fb`, watchOS **27.2.1**. It does not
identify the later build 59 as the installed Watch build.

The report contains 1,741 events across all three journals and includes all
three class windows. No events were omitted, no writes were pending, and no
last-write failure was reported. Earlier events excluded by the requested
24-hour window are not evidence of retention loss.

| Time | Recorded event |
| --- | --- |
| 18:55:17 | Evening mindfulness runtime confirms running. |
| 18:55:18 | Staged native volume setup finishes, including the delayed focus call. |
| 18:55:59 | Timer → media. |
| 19:04:05 | Media → timer; native focus call returns. |
| 19:04:31–19:04:35 | Timer → media → timer; native focus call returns again. |
| 19:50:07 | Runtime invalidates with `resigned_frontmost`, raw value 3. |
| 20:00:27 | Automatic runtime recovery succeeds on return. |

At the initial journal-only review, **18:55–19:05** was a candidate interval for
system-log correlation. The later captures below identify the zero-volume and
recovery commands within it. The app journal itself does not record the audible
incident. The first evening foreground-loss invalidation is after the scheduled
class end; it does not explain the reported early mute.

The same native volume object was retained from before the noon class. The
report contains no accepted volume-refresh event that day and no evening app
relaunch. Those absences do not prove that no tap or recovery was attempted.

Focus-call returns establish app-side requests, **not actual Crown ownership,
command delivery, endpoint selection or audible recovery**. The report has no
numeric volume, Crown direction, playback route or zero-volume command. A stale
native-control/backend association is a hypothesis, not a finding. The retained
control also served earlier classes, so its age alone does not establish cause.

## Initial capture report and later retrieval

The owner triggered an iPhone system capture and saw its completion toast.
At the initial review, that established reported completion on the phone;
retrieval and archive validation were still pending until the owner was home.

The owner also held the unlocked Watch's Crown and side button for about one
second, released them, and felt a Watch vibration. This is consistent with the
historically documented manual sysdiagnose acknowledgement, not proof that a
Watch archive has finished. A possible brief iPhone vibration does not establish
another capture. The trigger time is not established by the saved app logs.
The later retrieval checked the existing captures without starting another one.
Direct Watch file inventory timed out. Inventory and file copying through the
paired iPhone nevertheless retrieved its **20:02** capture and a **20:17 combined
capture** containing separate Watch and phone archives. Byte counts, hashes,
full gzip integrity and tar parsing validated the phone capture and both
combined-capture children. Only the system-log subtrees needed for analysis were
extracted; raw files, identifiers and detailed manifests remain private.

The 20:02 phone archive retains logs from November 12 **20:03:32** through
November 13 **20:03:31 PST**. The Watch archive retains November 12 **20:18:26**
through November 13 **20:18:25 PST**. Both contain useful media records for the
candidate interval. Overall archive bounds alone would not establish that
detail survived; the bounded queries verified the records below.

## Correlated Watch and phone system logs

All timestamps in this table are **November 13, 2026 PST (UTC−08:00)**. The
page transitions come from the app journal; volume commands and output changes
come from the separately retrieved system captures.

| Time | Recorded evidence |
| --- | --- |
| 19:04:05.052 | TeachingTimer returns from media to timer. |
| 19:04:27.047899–19:04:27.048316 | The Watch's **TeachingTimer process** logs `setVolume` to **0**, then requests endpoint volume **0** for the iPhone. Watch `mediaremoted` explicitly identifies TeachingTimer's installed bundle as the client for the corresponding output-volume request. |
| 19:04:27.140004–19:04:27.140918 | Phone `mediaremoted` receives `MRSetVolumeMessage` over an IDS companion MediaRemote transport, then requests local endpoint volume **0**. |
| 19:04:27.173797–19:04:27.193456 | Phone audio logs record hardware mute **1** on **AB13X USB Audio** and an observed iPhone volume change **0.625 → 0**. Amazon Music's process also receives an explicit volume-change notification to zero. |
| 19:04:31.210 | TeachingTimer enters its media page. |
| 19:04:32.431095–19:04:34.443965 | Watch **NanoNowPlayingViewService** issues 28 increasing endpoint-volume requests, from **0.016406** through **0.784375**. The phone receives the corresponding increases over the same companion transport used for the zero request. |
| 19:04:34.524192 | The phone observes volume reaching **0.784375**; the Watch also records the updated USB output volume. |
| 19:04:35.587 | TeachingTimer returns from media to timer. |

This establishes the originating process, companion transport and affected
phone USB output: the zero request came from TeachingTimer while its timer page
was selected, and the recovery requests came from NanoNowPlayingViewService
while the media page was selected. The logs independently support the reported
silencing and subsequent Watch-side media recovery. They do not measure audible
output at the external equipment.

The unresolved question is **why TeachingTimer's native volume control requested
zero**. These captures do not establish the initiating gesture, Crown direction
or delta, actual Crown focus, source-code path, stale association or framework
cause. The emailed journal's limitations still apply to that report separately;
system-log evidence supplies the command values and destination it did not
contain. Process attribution does not identify which app or system-framework
behavior calculated the value.

## Deeper input and native-state analysis

The Watch's MediaPlayer controller fetched **0.625 at 18:55:14**, so the process
did obtain a correct nonzero volume before the fault. Native Now Playing also
read 0.625 at 19:04:04. This weakens the simple theory that the timer process
never initialized its companion volume and kept only a startup zero.

At **19:04:26.635585**, Crown-associated Scroll input begins reaching the
TeachingTimer window. At 19:04:27.047201, UIKit dispatches a native control action;
the zero-volume call and endpoint request share its thread and activity. This
links the write to input handling, rather than a spontaneous write on session
start or page appearance. The preceding focus call returned about 22 seconds
earlier. The app journal records no replacement or accepted refresh at the zero.

Only one TeachingTimer volume write, zero, appears during this input burst,
without intermediate nonzero values. Direction, movement magnitude, the native
control's internal interaction baseline and the ring display remain unknown.
The event counts do not establish how far the Crown moved or exclude a large,
coalesced or accelerated downward adjustment reaching the minimum.

After native media recovery, the same TeachingTimer process sends gradual
nonzero changes at **19:05:52**. A broader retained query contains 246
TeachingTimer MediaPlayer volume writes that day, including normal midday
adjustments; only the incident is zero. This is a count of retained records,
not complete measurement of all user actions or proof of earlier-evening use.

On the phone, all 29 commands use the same absolute-volume operation and USB
route configuration. No preceding route switch or independent mute appears in
the bounded incident context. Hardware mute follows the zero request. Routine
volume-compensation resets also occur during every recovery update; they do not
explain a preceding reset to zero.

The leading engineering hypothesis is a temporary mismatch in the native
control's interaction baseline or state after focus/display-host transitions.
It is unproven: the correct earlier model value and the missing signed Crown
movement leave alternative input interpretations open. The captured chain
does establish delivery to the intended phone output for this occurrence.

The [extended opening/playback timeline](VOLUME_TIMELINE_2026-11-13.md) adds the
fresh Amazon launch at 18:48:12, audio start at 18:48:23, initial phone volume
adjustments and the Watch's later foreground return. This confirms the owner's
music-before-class recollection without establishing that the order caused zero.

## Proposed experiment and regression gates

The incident build and reviewed current source have identical volume/lifecycle
implementation. There is no app-owned volume scalar, setter or custom Crown
binding. Apple's [native control](https://developer.apple.com/documentation/watchkit/wkinterfacevolumecontrol)
handles the volume and exposes no public value/readiness callback. Its
[SwiftUI initializer](https://developer.apple.com/documentation/watchkit/wkinterfacevolumecontrol/init(origin:))
supports the representable construction used here.

First record a short baseline with known phone volume, the visible ring, an
explicitly small upward Crown movement, requested values and audio response.
Compare timer and media under the same provider/route, including media return,
Home/reopen and dim/wake. This is useful discriminating evidence, not a
requirement to withhold the existing intermittent report from Apple.

The first implementation experiment should **move the stable native volume
host outside the clock's TimelineView**, while keeping the same control object,
focus state machine and timings: one-second startup/background staging, 250 ms
explicit refocus, and immediate media-to-timer focus. Keep Class-sheet eligibility,
clock cadence and foreground hands unchanged. The current guards already avoid
repeated focus calls on ordinary ticks; there is no evidence that the timeline
caused zero. This is a hierarchy-isolation experiment, not a confirmed fix.

Validate one control identity, no per-tick focus requests, obsolete-request
cancellation, Class-sheet focus, tap refresh, Home/reopen, paging and hand/control
layer order in Simulator. Then compare actual phone values and audible response
physically. Simulator input feedback alone cannot validate paired media behavior.

Fresh-object replacement ranks lower because it already reproduced dead Crown
feedback in the [controlled focus comparison](SIMULATOR_VOLUME_FOCUS.md).
Do not add a blanket Crown delay, discard the first movement, impose a minimum
volume or automatically restore a remembered level: the current evidence does
not justify changing intentional volume control. No production behavior changed
during this analysis.
