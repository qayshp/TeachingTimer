# First class with public beta build 37

Teaching Timer needs watchOS 26 or later. The clock works without music.
Crown volume requires a media connection to your paired iPhone. Try wrist-down
updates on a Watch that supports Always-On.

## Get the beta

[Join the public beta](https://testflight.apple.com/join/YA2WSmae).
On November 26, 2026, the invitation showed **Session Clock** and the public
TestFlight group offered **1.0 (37)**. The instructions below are for that build.

Open the invitation on your paired iPhone in TestFlight, accept it, and install
**Teaching Timer Beta** on your Watch. Open the Watch app and confirm **Version
1.0 (37)** in **Class → Settings → About**. If you have the development
installation of **Teaching Timer**, keep it installed. Each app has its own
classes, settings and journals. For newer builds, see the
[current instructions](../README.md#current-source-and-newer-builds).

The **Class** button at the upper left opens class controls and Settings. The
Watch app needs no account. Try the checks below outside class first.

## Try it before teaching

1. Open **Start class**. Check the suggested start and end, then press the large
   **Start class** button for the usual 60 minutes. **Custom schedule** changes
   only this class. **Cancel** discards the draft. Opening at 1:10 suggests
   1:00. Use **+15 min** if the class is scheduled for 1:15.
   Starting also requests a mindfulness session to help keep the app available
   and support wrist-down updates. When the face says **Session off**, tap
   **Resume** to request the session. Your saved class schedule is preserved.
2. The long, thin hand shows wall-clock seconds. The short, thick hand shows
   wall-clock minutes. The outer wedge marks the scheduled finish. A 60-minute
   class also shows time remaining along the dial perimeter.
3. Tap **1-min count** to try the inner arc. It starts from the tap and takes one
   minute to fill. Groups of 1–6 vibrations begin at 10–60 seconds. The full arc
   remains briefly while the final group finishes; the count normally ends at
   about 65 seconds. The full arc also holds briefly with vibrations off. Tap
   **Stop count** to cancel. Change **Count vibrations** in **Class → Settings**
   before the next count. Use the arc for timing when vibrations arrive late or
   are skipped.
4. With phone music playing, try the Crown on both pages at a comfortable volume.
   The timer controls the iPhone. The media page can show Watch playback, so
   check its source.

If the ring stalls, try Apple's standalone **Now Playing** app on the Watch
for song timing.

## During a class

- Swipe left for media and right for the clock. If song progress is wrong or
  the page is blank, swipe away and back. This may update the displayed
  position once. Pause and volume can still work while progress is stale.
- Tap the timer's volume display if Crown volume stops responding. A brief ring
  acknowledges the refresh request. Check whether the sound changes. If
  playback continues silently, try the iPhone's volume controls.
- **Class → Stop session** keeps class timing. **Resume** on the face or
  **Class → Resume session** requests a mindfulness session for wrist-down updates.
  Reopening can recover a session that was meant to run. An intentional Stop
  stays stopped. With the session off, wrist-down updates may slow.
- If swiping fails to recover blank media, try force-closing and reopening when
  you can. This ends any running count. The saved class should reopen. Check the
  session state when practical.

## Between classes

Use **Class → New class**, then confirm, for another class. **End class** clears
its timing and stops the session and count. A class clears 30 minutes after its
scheduled end. Start the next class when you're ready. Editing the schedule
preserves the original Start timestamp.

If **Class not restored** appears, choose **Start class** for a fresh schedule
or **Later** to dismiss. The app keeps a recovery copy of unreadable timing.

## Report something useful

Record the app build, Watch/watchOS version, the action just before the problem,
and what recovered it. For media, include phone versus Watch playback, audio
route, and whether playback continued silently. A screenshot helps distinguish
an empty native media view from a black page. Do not interrupt teaching merely
to gather evidence. [Email support](../SUPPORT.md) with a short description, or
use the [issue tracker](ISSUE_TRACKER.md) for a sanitized public report. Never
post raw journals or system logs publicly. See [privacy and diagnostics](PRIVACY.md).
A description or cropped screenshot is enough. Build 37 keeps its journals on
the Watch. Send feedback through TestFlight or email support from your usual
mail app.

The [current limitations](../DEVELOPMENT_STATUS.md) remain part of the beta.
The [distribution record](TESTFLIGHT_PREPARATION.md) separates owner-pilot results
from external review and public availability.

## Help on the Watch

Open **Class → Settings** before or during a class. **Help** explains the clock,
class timing, counts, sessions and media recovery. **Privacy** summarizes local
data and includes the policy for offline reading. **About** shows the app
version, source code and license. Tap **About → Contact support** to find the
support link and QR code for your phone.
