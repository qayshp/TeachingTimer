# Native phone audio fixture

Standalone iPhone Simulator app, separate from TeachingTimer. It generates a
quiet local 30-second looping tone, publishes duration/elapsed time/rate through
MPNowPlayingInfoCenter, and handles native remote Play/Pause/Next/Previous/Seek.
Its local `Documents/MediaProbe.jsonl` records playback position, state, command
count and Simulator volume/route. These are not measurements of physical audio.
No account, download, web server, iPhone companion or production dependency.

Derived from the private fixture attached to Apple FB25294079; the original
incident copy remains unchanged. This maintained version uses the distribution
namespace and includes a bounded playback limit.

```sh
sh tools/phone-audio-probe/build.sh work/phone-probe-new
xcrun simctl install PHONE_UUID work/phone-probe-new/PhoneAudioProbe.app
# Explicit opt-in: quiet tone can be heard through the Mac's output.
xcrun simctl launch PHONE_UUID net.qays.TeachingTimer.PhoneAudioProbe \
  --autoplay --playback-limit-seconds 15
```

Output must be new. The build selects the current Xcode's iPhone Simulator SDK;
select newest compatible installed runtimes per [policy](../../AGENTS.md).
The app stays paused without `--autoplay`. Every Play has a 120-second maximum
by default; the argument clamps a requested limit to 1–120 seconds. Pause clears
the deadline; another Play/track selection starts a fresh bounded interval.
The limit uses monotonic uptime, checked by the foreground/audio-app timer.
It is not an external watchdog or a guarantee under process suspension.

During the bounded interval, inspect native phone Now Playing, Watch standalone
Now Playing and TeachingTimer's media page separately. Verify pair transport,
phone playback position, visible media and returned remote commands independently.
A green pair indicator alone does not establish companion-media support.

Always finish with Pause, check the journal for `playing: false`, then terminate
this fixture if it is no longer needed:

```sh
xcrun simctl terminate PHONE_UUID net.qays.TeachingTimer.PhoneAudioProbe
```

Do not leave an unbounded background tone running. The build script supports
Simulator only; physical signing/installation and the supervised setup remain
separate work in the [physical test plan](../../docs/PHYSICAL_MEDIA_TEST_PLAN.md).
