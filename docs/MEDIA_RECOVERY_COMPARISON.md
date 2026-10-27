# Native media recovery comparison — October 26, 2026

## Outcome

No reliable replacement for the existing recovery behavior was established.
Experimental app changes were removed. TeachingTimer's class, runtime, landmark,
Crown focus, and native-media implementation remain at the build-18 baseline.
Only the regression tooling and this evidence record changed.

## Method and limits

Xcode 27.1, watchOS 27.0, disposable SE 3 40 mm Simulator. The regression sequence
starts a count, enters media, sends the app Home, terminates exactly the selected
Simulator's native Now Playing view service, reopens the **same host process**,
and visits timer/media/timer. No physical device or phone was used. The service
termination is deliberate fault injection, not evidence that physical incidents
have this cause.

The baseline app was the previously verified build-18 Simulator binary. Four
source variants were built successfully and installed separately; launch records
confirm different host PIDs across variant runs. Within each valid run, the host
PID and saved class bytes survived. The native timer volume control was not
replaced. Journals showed Home's `resigned_frontmost` runtime invalidation and one
automatic replacement, rather than uninterrupted runtime. Landmark submissions
continued in the captured journals; this does not prove physical haptic delivery.
No candidate changed the volume adapter or its focus requests. Actual paired-phone
volume responsiveness was not testable in this unpaired setup.

Early screenshots alone are insufficient: the baseline's initial black page
later rendered normally. The runner now takes an additional screenshot five
seconds after each initial-entry, background-return and reentry capture.
A black delayed capture is a lower bound, not a claim of indefinite failure.

## Comparisons

| Variant | Change | Observation |
| --- | --- | --- |
| Baseline | Existing generation-based native-view replacement | Valid run showed early blanks on entry and background return; media reentry rendered. Longer-wait rerun showed initial entry recover but background return still black after five additional seconds. |
| Stable page | Keep an outer ZStack page and replace only its native child | Early entry/return captures remained black; reentry rendered. No reliable advantage established; longer-wait behavior not separately measured for this variant. |
| Teardown gap | Stable page, remove native content, wait 300 ms, then remount | Remount callbacks occurred, but early entry/return captures were black. The longer-wait run stayed black at initial entry and reentry, while background return rendered. Not reliable. |
| Clock-only timeline | Move TimelineView from the whole pager to the timer page | Early entry/return captures remained black; reentry rendered. No reliable advantage established; longer-wait behavior not separately measured for this variant. |
| Conditional lifetime | Create native content only while media is selected and scene is not background; no live generation replacement | Longer-wait run remained black at initial entry and later reentry, while background return rendered. Not a reliable recovery. Ordinary inactive wrist states did not remove content. |

The evidence does not isolate a SwiftUI page-identity, timeline, teardown timing,
or native remote-service root cause. System errors included CoreAnimation
`cannot add handler to 0 from 0 - dropping` and MediaRemote output-context warnings.
These are correlated logs, not causal diagnoses, and are not sufficient to blame
TeachingTimer, the simulator, or watchOS alone.

## Test setup corrections

One initial run was excluded from the class-preservation comparison because an
old class retired during setup. After clearing only this disposable Simulator
app's data, another setup attempt reached an active class visually but checked
its preferences before UserDefaults flushed. The runner now waits up to ten
seconds for that setup prerequisite instead of immediately declaring failure.
It does not suppress failures or rewrite class data to make a check pass.

## Next useful work

1. Extend the independent native-view fixture to reproduce this exact fault
   sequence with a minimal two-page host. First confirm that the longer blank
   survives there without TeachingTimer's timeline and controllers.
2. Capture native service termination/relaunch and rendered frames together,
   including a no-fault comparison. Keep callback success separate from pixels.
3. Add the comparison to existing Apple report **FB25305069** when requested.
   No Feedback Assistant update was submitted in this investigation.
4. Keep the current teaching build available. Do not add periodic blind reloads,
   app restarts, private APIs, or a replacement of the working volume control on
   the strength of these results.

Private evidence: `work/support/2026-10-26-media-recovery/` on the development
Mac. It contains `baseline-valid`, `baseline-dwell`, `wrapper-1`, `staged-1`,
`staged-dwell`, `timeline-1`, `conditional-1`, `conditional-dwell`, experimental
source snapshots, build logs and system errors. Raw journals/preferences are not
published. Visual results were manually inspected; the runner's lifecycle pass
is deliberately not an automatic visual pass.
