# Late landmark haptics — build 14

The previous 0.4-second cutoff disabled all remaining vibrations after one late
pulse. The user requested removing that shutdown for the next teaching trial.
Build 14 keeps lateness as diagnostic information, not a run-wide stop condition.

## Behavior

- Landmark groups still target 10, 20, 30, 40, 50, and 60 seconds from the tap,
  using absolute `ContinuousClock` deadlines. `.start` acknowledgement and
  `.directionUp` timing pulses are unchanged.
- A late pulse is submitted, with subsequent submissions at least 0.8 seconds
  apart. This spacing can delay the rest of its group; it does not move later
  groups' original anchors or change the arc's time source.
- A group, or its remaining pulses, is skipped if it can no longer fit before
  the next landmark or the original 64.8-second completion. Later groups are
  still attempted. A long suspension cannot produce a burst of obsolete counts.
- Stop, End class, and replacement with a new class still cancel pending work.
  Generation guards prevent old pending pulses leaking into a fresh count.
- Visual-only mode, the 60-second arc, and its original 64.8-second lifetime
  remain unchanged. A delayed OS completion callback can still arrive later.

This is deliberately different from guaranteeing every pulse: watchOS can refuse
or delay haptic delivery, and a long interruption can still yield incomplete or
skipped groups. A submission is not confirmation that the wearer felt a pulse.
The old persistent result codes remain readable for diagnostics from prior builds.

## Diagnostics and verification

`landmark_started` identifies `latePolicy: continue_spaced_skip_obsolete_groups`.
`landmark_pulse_late` logs delays of 0.4 seconds or more with
`action: submit_and_continue`. `landmark_group_skipped` identifies an elapsed
group window. Per-submission logs retain requested/actual monotonic time,
landmark, pulse/count, haptic type, runtime, and scene state.
`landmark_haptics_stopped` is no longer emitted for late pulses.

All eleven deterministic suites passed. Controller checks cover 0.4-second and
two-second delays, spacing after lateness, multiple obsolete groups after a
25-second stall, no playback after the complete run window, cancellation during
groups five/six with immediate restart, visual-only mode, and normal completion.

On October 26, 2026, build 14 ran on the SE 3 40 mm / watchOS 27.0 Simulator in
Xcode 27.1 Device Hub. During a locked, reduced-luminance count with an active
runtime, it submitted all 21 timing pulses plus the acknowledgement. Fifteen
pulses exceeded the former cutoff, with maximum logged lateness about 0.663 s.
All six groups completed at about 64.809 s; haptics were not disabled. The inner
arc was visible while locked. This verifies scheduling and native submissions,
not physical vibration delivery, strength, or accurate counting while teaching.

Raw evidence is private under `work/support/2026-10-26-usability/`.
