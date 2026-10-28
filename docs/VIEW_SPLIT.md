# Build 19: mechanical view split

`SharedClockPage.swift` previously contained 608 lines. It now keeps the clock
composition and teaching-face actions; class management, its button style,
refresh presentation and the native WatchKit adapter have focused files:

- `ClassControlsView.swift`
- `ClassActionStyle.swift`
- `RefreshableCompanionVolumeControl.swift`
- `CompanionVolumeControl.swift`

The type names, view hierarchy, state ownership, modifier order and native
control creation/update/removal sequence are unchanged. Three file-private
types become internal so the original call sites can refer to them. No new
wrapper view, identity key, timer, focus request or state model was introduced.
Reassembling the extracted text matches the prior file after those three
access-level substitutions and ignoring trailing file-boundary whitespace. The
Xcode target includes the new source files; the candidate is identified as build 19.

All twelve Swift suites, forty Python checks, the Simulator build and unsigned
archives pass. The SE 3 essential-action suite and focused Home/refresh/media
sequence preserve class state and the existing native volume-control instance.
Hardware Crown ownership/audio response is not inferred from these tests.

An Ultra run showed the End class UI and removal journal event before the
preferences file flushed; the former ten-second disk assertion failed. A later
read confirmed removal. The action runner now allows thirty seconds for that
asynchronous persisted-state observation. This is a bounded test allowance,
not a claim that UserDefaults guarantees durable storage within that period.

The bounded-wait rerun passed all 14 Ultra assertions; SE 3 also passed all 14.
The separate focus regression passed all six lifecycle checks. Rendering and
physical audio/haptic limitations remain unchanged.
