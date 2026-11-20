# Now Playing progress probe

This separate watchOS app (`net.qays.TeachingTimer.NowPlayingProgressProbe`)
puts one Apple `NowPlayingView` in a `WindowGroup`. It lets us test whether
the progress ring can stall in a minimal third-party app. Apple owns
the display and transport controls.

## Build

Build and open it in an already booted compatible Watch Simulator.

```sh
sh tools/now-playing-progress-probe/build.sh work/now-playing-progress-probe/simulator
xcrun simctl install SIMULATOR_UUID work/now-playing-progress-probe/simulator/NowPlayingProgressProbe.app
xcrun simctl launch SIMULATOR_UUID net.qays.TeachingTimer.NowPlayingProgressProbe
```

Simulator installation checks that the native view can load. The paired
Simulator media-discovery limitation is tracked separately in
[#6](https://github.com/qayshp/TeachingTimer/issues/6).

```sh
sh tools/now-playing-progress-probe/build.sh work/now-playing-progress-probe/device device
```

The device command produces an unsigned universal Watch app. A registered
bundle ID, an appropriate development provisioning profile, and development
signing are required for hardware installation. The probe's distinct ID
keeps its installation separate from Teaching Timer.

## Compare on a paired Watch and iPhone

1. On iPhone, start one track long enough for all three observations. Keep the
   playback app, track, and output route the same. Pause or seek only after
   all observations are complete.
2. Open Apple's standalone Now Playing on the Watch and select the iPhone
   source if needed. With the display awake, record the Watch ring and iPhone
   elapsed time on entry and again 20–30 seconds later.
3. Open Progress Probe and repeat with the native view filling the screen.
4. Open Teaching Timer, swipe to its media page, and repeat once more.
5. Record the three pairs of observations, wall-clock capture times, Watch and
   iPhone OS versions, Teaching Timer build, and playback route. Keep capture
   images and device details private until reviewed for sharing.

Count a stall only when the iPhone advances on the same track over the full
interval and the visible Watch ring stays fixed. A stall in the probe while
Apple's app advances would give Apple a minimal third-party reproduction. A
stall limited to Teaching Timer would direct further investigation to its
view hierarchy or lifecycle.
