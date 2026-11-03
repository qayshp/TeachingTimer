# Embedded media progress — physical owner test, November 2, 2026

Teaching Timer Beta **1.0 (35)** on a physical **Apple Watch SE 3 / watchOS 27.2**.
Apple Music played on the paired iPhone through its own speaker. This supervised
test concerns stale song progress in the embedded native media page, distinct
from a completely black page or silent playback.

Tracked by [GitHub issue #8](https://github.com/qayshp/TeachingTimer/issues/8)
and existing Apple report **FB25379883**. This document records new evidence;
no Apple update was submitted during this session.

## What the wearer reported

1. After opening the app and starting a class, timer-page Crown volume worked.
2. Entering media showed the song position at page entry, but progress did not
   keep advancing. Returning to the timer still allowed audible volume changes.
3. Repeated media entries advanced the displayed position substantially, then
   it appeared stuck again. The wearer was asked to keep the display bright for
   about 20 seconds; the exact action times and continuous brightness were not
   independently observed.
4. In Apple's standalone Now Playing app, progress seemed to keep advancing.
   Seeking on the iPhone also updated the standalone indicator.
5. Seeking on the iPhone updated Teaching Timer's embedded indicator too, but
   the wearer perceived a persistent offset from the expected position. The
   offset was not measured and no synchronized recording was made.
6. Timer-page Crown volume worked audibly after Home/reopen and after tapping
   refresh without a media round trip. These are physical passes for this run,
   not proof that intermittent volume failures are resolved.
7. In a follow-up, the wearer confirmed that automatic media refresh after
   inactivity does update the displayed song position. This establishes useful
   position catch-up by observation, not restored continuous progression. The
   report was not matched to a particular captured refresh timestamp.

## What the journals establish

Five capture sets successfully copied all three app journals: initial volume,
frozen media, repeated page entry, standalone/seek comparison and final Crown
checks. The raw journals and collection metadata remain private.

- Page-entry refresh requests and native-page lifecycle callbacks occurred.
  The observation is therefore not explained simply by a missing refresh
  request. A callback does not prove fresh pixels or the native playback clock.
- A `long_dimmed_wake` media refresh preceded `resigned_frontmost` invalidation
  by about one second. The wearer intentionally left Teaching Timer to compare
  standalone Now Playing; the ordering alone does not make refresh the cause
  of invalidation.
- On return, background refresh and automatic runtime recovery occurred with
  the same class retained. The runtime reached running again.
- A later media-page entry was followed by roughly **54 seconds with no recorded
  dimming transition** before reduced luminance was reported. This is a useful
  logged observation window, not a video of continuous illumination or proof
  of precisely when the wearer saw stalled progress.

The journals do not expose native song position, playback rate, seek values,
rendered progress, actual volume or audio output. They cannot quantify the
reported offset or identify the native service's internal failure.

## Interpretation and next evidence

Repeated entry refreshed the apparent position but did not restore continuing
progress in this test. The wearer also confirmed position catch-up after the
automatic refresh following inactivity. Seeking still reached the embedded
indicator. Together with the standalone comparison, that narrows the question toward embedded
presentation or playback-time updates; it does not establish an Apple root cause.

The app embeds Apple's `NowPlayingView` under `TimelineView` → `TabView`. It does
not implement song time, playback rate, seeking or media-progress arithmetic.
The timeline ancestor is an **untested hypothesis**, not a diagnosed cause.
No hierarchy, refresh, runtime or Crown behavior was changed for this capture.

A useful next comparison would isolate the native view from the clock timeline
while preserving the same class/runtime and volume behavior, with a clean-launch
baseline and synchronized phone/Watch video. Record whether position stalls
while bright, after dimming, and after a known seek. No new system diagnostic,
video or deterministic clean-launch reproduction was collected in this session.
