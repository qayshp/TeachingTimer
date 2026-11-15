# Successful volume run versus November 13 silencing

The November 14 class supplies a useful successful volume-command comparison,
but several conditions changed together. It does not establish a fix or a safe
startup order. This extends the [November 13 incident](VOLUME_INCIDENT_2026-11-13.md)
and [opening/playback timeline](VOLUME_TIMELINE_2026-11-13.md).

All times below are **Pacific Standard Time (UTC−08:00)**. The owner reported no
issues during the November 14 class. The new phone and Watch sysdiagnoses were
captured at 20:33:46 and 20:37:47, downloaded and fully validated. Their retained
records include the class. Raw captures, exact correlation identifiers, query
commands and source-row references remain private.

## Controlled facts and changed conditions

The failed Watch report identifies build **261113.1031.57**, source `b28e499319fb`;
the successful one identifies **261113.2020.62**, source `d9a78562217b`. Direct
source comparison finds identical clock/page, volume adapter, refresh/focus,
volume diagnostics and landmark-controller files. The complete app artifacts
are different; support/diagnostic-sharing changes exist elsewhere. Neither run
includes [PR #33's host-isolation experiment](VOLUME_HOST_ISOLATION.md).

Both native setters use the same Watch boot, MediaPlayer image and framework
log callsite. This controls for a Watch reboot or different native MediaPlayer
binary; it does not identify the same internal controller object. Those object
descriptions remain redacted in the physical captures.

| Observation | November 13 failure | November 14 success |
| --- | --- | --- |
| Provider/output | Amazon Music through wired USB audio. | Apple Music, initially phone speaker, then AirPlay. |
| Music app opening | Fresh process at 18:48:12.557; scene foreground at 18:48:16.649. | Foreground activation begins 17:00:34.265; an exact process-birth record is not established. |
| Actual playback | Audio starts 18:48:23.457, about 6 min 54 sec before the Watch runtime. | Playback request 17:01:12.136; player reports Playing and playback start at 17:01:13.016, about 12 sec after the Watch runtime. Opening Music preceded class; this retained playback start followed it. |
| Watch class/runtime | Scheduled 18:45; app returns 18:55:14, runtime running 18:55:17.002. | Recorded schedule 17:00–18:00; runtime running 17:01:01. |
| Native control lifetime | Retained from 12:23:35, roughly 6 h 41 min before the zero. | Newly created 17:01:02, about 102 sec before the first retained adjustment. The app process itself was already older; process age and control age are different. |
| Initial/transition model | Brief zero/unavailable after connection replacement; correct 0.625 fetched by 18:55:14.347. | Initial zero, then nonzero model updates. AirPlay selection around 17:01:22 also produces temporary zero/unavailable/None and endpoint error 36, followed by recovery to 0.475. |
| Baseline before relevant input | Model 0.625; native media also reads it shortly before timer return. | Phone Music model 0.567484 at 17:01:50.049; Watch observes the same value at .490. |
| First relevant timer request | 19:04:27.048 requests **0**, with no retained intermediate descending timer values in that burst. | 17:02:43.937 requests **0.563734**, a decrease of only **0.00375** from the last model. Subsequent requests change gradually. |
| Phone-side corroboration | Matched incoming companion command and endpoint application establish the USB change from 0.625 to zero; hardware muting is logged during that application. | Later Music model values match Watch requests about 31–101 ms afterward. The exact first request's phone counterpart and command/application IDs are not retained, so the evidence is weaker than the failed run's matched transaction. |
| Page/count context | Media → timer about 22 sec before zero; landmark count active, with two recent pulses. | No embedded-media visit before first adjustment; no November 14 app landmark events. This does not establish that all system/Crown haptics were disabled. |

The successful hour contains **138 retained TeachingTimer MediaPlayer volume
setter records**, all nonzero, ranging from **0.412984 to 0.718984**. They continue
through **17:59:22.953**, including well after nine minutes. These are log records,
not unique gestures or independent acoustic measurements. They support the
owner's successful-volume report without claiming complete event retention.

## An additional input-pattern clue

The saved UIKit dispatch records permit an empirical comparison:

| Input burst | Retained subtype | Native requested values |
| --- | --- | --- |
| November 14 first decrease | 200 | 0.563734 → 0.462859 |
| November 14 subsequent increase | 201 | 0.468484 → 0.516484 |
| November 14 later decrease | 200 | 0.513484 → 0.412984 |
| November 13 native-media recovery | 201 | 0.016406 → 0.784375 |
| November 13 failing timer burst | 201 | 0 |

The failing burst therefore shares a subtype with increasing-value bursts in
both native hosts. This is a testable clue, **not a recovered signed Crown
delta or proof of the owner's intended direction**. The installed public SDK
and Apple's [public subtype enumeration](https://developer.apple.com/documentation/uikit/uievent/eventsubtype)
do not supply the needed Watch-specific 200/201 mapping. These private numeric
events must not be interpreted using generic UIKit scroll constants.

### Owner recollection added November 15

After reviewing this comparison, the owner reports thinking they were trying
to **increase** volume when the November 13 mute occurred. This is retrospective
recollection with stated uncertainty, rather than a captured signed Crown delta.
It strengthens the working interpretation of an attempted increase unexpectedly
producing zero, alongside the subtype-201 pattern above.

The owner's observation that the recovered level was higher is also consistent
with the phone records: **0.625 before mute → 0 → 0.784375 after media-page
recovery**. That final increase alone does not establish the original input
direction, because it followed separate recovery adjustments. Rotation amount,
the ring's appearance and the native interaction baseline remain unknown.

## What this narrows

- **An initial zero/unavailable model is insufficient by itself.** It occurs in
  the successful run too, and the failed run obtained the correct nonzero value.
- **Normal requests persist well beyond nine minutes with this code.**
  The successful run contains nonzero setter records through 17:59:22.953. A simple elapsed
  class-time threshold or old app-process age does not separate the outcomes.
- **The focus requests alone do not explain the numeric fault.** Correct model
  data existed before the failed input; actual native focus and child interaction
  state remain inaccessible through the public wrapper.
- **A native interaction/conversion or retained-state mismatch remains plausible.**
  The different native object age, connection/page history and input-pattern clue
  make that family worth investigating. They do not identify which state failed.
- **Startup order, provider, route, control freshness and app-count activity are
  confounded.** The successful comparison cannot show that starting class before
  playback, using AirPlay, or creating a new control prevents the bug.

## Discriminating next checks

First calibrate the input-subtype pattern against known opposite Crown movements
in an isolated probe, without adding a competing Crown handler to TeachingTimer.
Simulator input can help even when its companion endpoint is unavailable; a
Simulator mapping still needs a physical check before interpreting user intent.

Then hold provider and output fixed while comparing a fresh control with the
same control after suspension, route/playback setup and media/wake transitions.
Record a known nonzero baseline, the ring, one small explicitly upward movement,
the first outgoing scalar and the phone result. Change playback-before/after-class
as a separate factor. Compare baseline and PR #33 separately; recreating controls
is not adopted as a fix because replacement previously regressed Crown response.

The existing capture comparison is ready for Apple as additional evidence. It
does not imply an Apple submission, a deterministic reproduction, a production
behavior change, or a physical test of PR #33.
