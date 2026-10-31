# First class with Teaching Timer

This is a watchOS-only teaching clock, not a pose guide or workout tracker.
It needs watchOS 26 or later. The core clock works without phone music; iPhone
volume requires a paired iPhone and an available media connection. Always-On
needs a Watch that supports it. Screen-size simulations are not hardware certification.

There is no public beta link yet. Install a maintainer-provided build or build
from source using the [README](../README.md#build-and-contribute).

## Try it before teaching

1. Open **Start class**. Check the suggested start and end, then press the large
   **Start class** button for the usual 60 minutes. **Custom schedule** changes
   only this class; Cancel discards the draft. For an early start, check carefully:
   opening at 1:10 suggests 1:00, not 1:15. Use +15 minutes if needed.
2. Read the hands as real time: the long thin hand is seconds, the shorter thick
   hand is minutes. The outer wedge marks scheduled finish. For 60 minutes, the
   stronger perimeter segment is time ahead; 75 minutes has the wedge without
   a misleading single-revolution progress line.
3. Tap **1-min count** to try the inner arc. It starts from the tap and takes one
   minute to fill. Groups of 1–6 vibrations begin at 10–60 seconds; the final
   group finishes after the minute. Tap again to stop. **Class → Settings → Count vibrations**
   turns vibrations off for the next run. Delivery can be late or skipped by the
   system, so do not depend on it as an exact pacing signal.
4. With phone music already playing, try the Crown and both pages before class.
   The timer control targets the iPhone. Native Now Playing may instead show
   Watch playback, so the two pages are not guaranteed to control the same source.

## During a class

- Swipe left for media and right for the clock. Each entry recreates the native
  media view. If song progress is wrong or the page is blank, swipe away and back.
  Pause and volume can still work while progress is stale. Build 25 also refreshes
  after eligible longer dimmed intervals; this is not a proven fix.
- Tap the timer's volume display if Crown volume stops responding. A brief ring
  acknowledges the refresh request; it does **not** confirm sound recovered.
  If playback continues silently, phone volume controls have recovered it in
  reports. Neither workaround is guaranteed. Avoid repeated blind adjustments.
- **Class → Stop session** keeps class timing. **Resume** restarts the mindfulness
  runtime. Reopening can recover a session that was meant to run; intentional
  Stop remains stopped. A failed recovery exposes Resume.
- A count is separate from the class and runtime. Force-closing the app can
  recover a blank media page, but interrupts a count. Saved class timing should
  restore; check the displayed session state when practical.

## Between classes

Use **Class → New class**, then confirm, for another class. **End class** clears
its timing and stops the session/count. Neither is the same as Stop session.
An old class also retires 30 minutes after its scheduled end; no new class starts
silently. Editing the schedule preserves the original Start timestamp.

If saved timing cannot be read, **Class not restored** offers **Start class**
for a fresh draft or **Later**. Dismissing it preserves the stored recovery data;
starting a new class replaces current timing while retaining the recovery copy.
A normal first launch or a successfully restored class does not show this notice.

## Report something useful

Record the app build, Watch/watchOS version, the action just before the problem,
and what recovered it. For media, include phone versus Watch playback, audio
route, and whether playback continued silently. A screenshot helps distinguish
an empty native media view from a black page. Do not interrupt teaching merely
to gather evidence. Use the [issue tracker](ISSUE_TRACKER.md); never post raw
journals or system logs publicly. See [privacy and diagnostics](PRIVACY.md).

The [current limitations](../DEVELOPMENT_STATUS.md) remain part of the beta.
Wider invitations should follow the [private distribution pilot](TESTFLIGHT_PREPARATION.md).
