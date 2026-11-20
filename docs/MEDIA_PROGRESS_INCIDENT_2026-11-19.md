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

## Next comparison

Run the [bare Now Playing probe](../tools/now-playing-progress-probe/README.md)
on the same physical pair. If the bare view freezes while Apple's standalone app
advances, the probe is a minimal app-level reproduction for Apple. If the bare
view advances, compare a paged host with a single full-screen host before changing
Teaching Timer's refresh policy. Preserve the class, playback and Crown behavior
when testing any candidate change.
