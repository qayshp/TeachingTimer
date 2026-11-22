# Embedded media progress on a physical Watch, November 19, 2026

[Issue #8](https://github.com/qayshp/TeachingTimer/issues/8) and Apple feedback
FB25379883 track a frozen song-progress ring in Teaching Timer's native
`NowPlayingView`.

## Matched playback comparison

An Apple Watch SE 3 on watchOS 27.2.1 (24S132) ran Teaching Timer Beta
1.0 (261113.2020.62), source `d9a7856`. This build includes the media view's
isolation from the teaching clock timeline. The paired iPhone played one Apple
Music track through iPhone Mirroring, and Device Hub showed the Watch.
The same track and output route were used in both Watch apps. No class or
extended runtime was active.

| Watch view | iPhone elapsed time | Watch ring endpoint |
| --- | --- | --- |
| Teaching Timer after swiping to media | 0:34 → 0:41 → 0:56 | 44° → 44° → 44° |
| Apple's standalone Now Playing, paired iPhone selected | 1:37 → 1:57 | 146° → 176° |
| Teaching Timer after returning from Now Playing | 2:08 → 2:33 | 192° → 192° |
| Teaching Timer after swiping to timer and back | 2:46 → 3:15 | 248° → 248° |

Ring endpoints are approximate clockwise angles measured from the top in
timestamped Watch screenshots. The phone positions are from corresponding
iPhone screenshots. Original captures and journals are retained privately.

## Journal correlation

The operational journal recorded media generation 32 on entering the page at
22:52:18 PST, generation 33 on foreground return at 22:53:58, and generation 34
on reentering media at 22:54:36. Each reload was followed by a media appearance
callback. Scene state was active and reduced luminance was false at each reload.
No further reload was recorded during any of the three stalled intervals.

The standalone comparison shows that the same playback can drive an advancing
Watch ring. Both Teaching Timer reload paths caught the displayed
position up once, then the ring froze again. Class runtime, a recorded dim/wake
transition, and the clock timeline being an ancestor of the media view were
absent in this reproduction. The journal records the app's view lifecycle. The
screenshots establish the visible behavior.

## Bare view on the same hardware

The development-signed [bare Now Playing probe](../tools/now-playing-progress-probe/README.md)
ran on the same Watch. It displays only `NowPlayingView()` in a `WindowGroup`.
It has no paging, clock, class runtime, or media-refresh code. The same Apple
Music track and iPhone Mirroring output were used in one uninterrupted playback
run across all three observations.

| Watch view | iPhone elapsed time | Watch ring endpoint |
| --- | --- | --- |
| Bare probe already visible when iPhone playback began | 0:04 → 0:24 | 0° → 0° |
| Apple's standalone Now Playing, paired iPhone selected | 1:07 → 1:27 | 100° → 131° |
| Bare probe freshly launched mid-track | 1:45 → 2:08 | 157° → 157° |

The probe showed the correct title and a Pause button during both stalled
intervals. Tapping Pause then paused the iPhone at 2:28 and moved the Watch
ring to approximately 222°. This separates a working playback command and
position update at Pause from missing progress updates during steady playback.

The bare probe reproduces the freeze with the app's hosted WatchKit view on
this pairing and output route. It needs no Teaching Timer source and gives
FB25379883 a minimal reproduction. Apple's standalone watch app advanced on
the same source. The captures do not identify the internal cause.

## Apple's published workout sample

Apple's [Build a workout app for Apple Watch](https://developer.apple.com/documentation/healthkit/building-a-workout-app-for-apple-watch?changes=__9_5)
sample reproduced the same stall on the physical SE 3. The Swift files matched
the official archive byte for byte. Xcode 27.2 used a separate development
bundle ID and a watchOS 9.0 deployment target because its SDK no longer accepts
the sample's watchOS 8.0 setting.

Dismiss the Health Access prompt, select Walk, and swipe from metrics to the
sample's third page. Start Apple Music on the paired iPhone while the sample's
native media page is visible. Keep the track and iPhone Mirroring output
unchanged when switching to Apple's standalone Watch app for the reference.

| Watch view | iPhone elapsed time | Watch ring endpoint |
| --- | --- | --- |
| Apple's workout sample, native media page | 0:04 → 0:24 | 0° → 0° |
| Apple's standalone Now Playing, paired iPhone selected | 0:52 → 1:12 | 79° → 109° |

The sample showed the correct track and Pause button while the ring stood still.
This reproduces the symptom using Apple's original paged host and media code.

## Public implementations reviewed

- Apple's workout sample places `NowPlayingView()` in its own paged tab.
  Its WatchKit reference assigns source selection to the system and exposes no
  progress or refresh API. [Workout sample](https://developer.apple.com/videos/play/wwdc2021/10009/?time=968) · [WatchKit reference](https://developer.apple.com/documentation/watchkit/nowplayingview)
- openGym 1.4.5 and SparkyFitness use a dedicated native Now Playing page for
  workouts. openGym returns to the workout page when the wrist goes down.
  Its original contribution describes a Simulator screenshot without music.
  [openGym source](https://github.com/DuarteSantos8/openGym/blob/v1.4.5/frontend/ios/App/Watch/SideScreens.swift#L465-L471) · [openGym implementation notes](https://github.com/DuarteSantos8/openGym/pull/899) · [SparkyFitness source](https://github.com/CodeWithCJ/SparkyFitness/blob/a516bbafd0783859cf4d309e2b8b43023501ead4/SparkyFitnessMobile/targets/watch/Presentation/NowPlayingPage.swift)
- AudioBooth uses the native view in its remote player and adds a companion
  volume overlay and options toolbar. The code shows no separate song-progress
  updater. [AudioBooth source](https://github.com/AudioBooth/AudioBooth/blob/cc16b30308a19991563e38008ec5cddc37168103/AudioBooth/AudioBooth%20Watch%20App/Screens/RemotePlayer/RemotePlayerView.swift)

The public trackers and reports reviewed did not independently document the
same steady-playback stall in the embedded view while Apple's standalone app
advanced on the same track.
