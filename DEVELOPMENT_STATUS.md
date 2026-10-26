# Teaching Timer — current verification

Updated October 26, 2026. Historical observations are kept separately so that
previous build states do not read as current facts.

## Teaching baseline and deployment

**Build 16 (1.0), source `e5e5ab4`, was installed and launched on the physical
Apple Watch SE 3.** The saved installed-app query confirms build 16. The first
attempt failed despite an awake, unlocked Watch on top of the laptop; the retry
succeeded without re-pairing or restarting. A shorter command timeout on retry
is not a diagnosed remedy. No new installation is implied by this document.

The maintainer has since tested the usability changes on the Watch and reports
that the app is noticeably clearer and easier to understand. This is positive
physical usability feedback, not proof that the remaining intermittent bugs
are fixed. The exact app, symbols, signing information and deployment evidence
are preserved privately; see [the teaching checkpoint](docs/TEACHING_CHECKPOINT.md).

## Current behavior

- Two pages: teaching face and native Apple Now Playing. No iPhone companion.
- Wall-clock seconds and minute hands stay above controls. The scheduled-end
  wedge remains; the future/past perimeter is used only for 60-minute classes.
- Start class uses a fixed 60-minute default and quarter-hour suggestion.
  Custom schedule edits are separate; Cancel discards the draft. Class options
  use explicit outlined/solid buttons, and Stop/Resume returns to the face.
- Class schedule persists independently of runtime. Eligible reopening resumes
  intended-running sessions; intentional Stop survives reopening. Class retirement
  is scheduled end +30 minutes, not an automatic new-class start.
- Count arcs use monotonic elapsed time. Six haptic groups start at 10-second
  intervals; the sixth begins at 60 seconds, its last pulse is scheduled at 64
  seconds, and visual completion is 64.8 seconds. Late pulses retain spacing;
  obsolete groups are skipped without disabling later groups. Visual-only mode
  remains available. The former run-wide timeout warning is no longer current.
- Native companion volume is retained through refresh/background return, with
  one guarded 250 ms refocus cycle. Media-to-timer focus remains immediate.
- Native media refresh happens on page entry and eligible background return,
  not ordinary wrist wakes. Build 16 removed the redundant Reload media menu item.
  Refresh is preventive; it does not detect a black view or verify its recovery.

## Verified evidence and limits

- All eleven deterministic Swift suites passed for build 16. Debug and Release
  Simulator builds succeeded. These are standalone model/controller checks,
  not an Xcode UI-test target or physical audio tests.
- Menus/layouts were checked across eight available Watch geometries. Maximum-text
  confirmation included SE 3 40 mm, Series 12 42 mm and Ultra 4 49 mm. SE 3
  interaction checks covered Stop/Resume, schedule Cancel/Save and page/focus
  lifecycle. See [the usability review](docs/USABILITY_REVIEW_2026-10-26.md).
- Retaining the volume widget avoided the controlled Simulator focus regression.
  Focus-call returns and animated native feedback do not prove phone-volume
  commands, audible playback, or actual Crown ownership.
- Recreating native Now Playing recovered two deliberately induced Simulator
  service-loss failures. Physical blank media has occurred during classes;
  force-closing/reopening recovered it in user reports. Two later successful
  classes are encouraging but do not establish a permanent fix.
- The count arc advances in reduced luminance in Simulator and physical reports.
  Simulator haptic submissions/chimes are not proof of physical delivery or
  countability. The revised late-pulse policy still needs teaching validation.
- The clock-only probe reproduces the Always-On hand backstep in Simulator.
  A similar physical symptom is reported; no hand fix has been established.
- A signed build-16 archive was reconstructed for preservation. Its signature
  validates, but it is not an App Store/TestFlight export or review approval.

## Open investigations

| Issue | Current mitigation / next evidence |
| --- | --- |
| Timer volume unavailable or silent | Retained native control and bounded refocus; physical volume-only comparison remains needed. Returning API calls never prove audio recovery. |
| Black native media | Automatic view refresh; collect any recurrence and compare standalone Now Playing when practical. |
| Hand backstep on dim | Minimal probe available; retain evidence for Apple rather than adding speculative clock corrections. |
| Watch developer connection | Bounded retries and separate transfer verification; awake/unlocked/nearby is not sufficient or a proven universal transfer requirement. |
| Paired Simulator media | No working iPhone-to-Watch control baseline; cannot validate physical volume there. |

The original blank **timer return** in Simulator is distinct from physical black
**media** reports; a common cause is unproven. Silencing has occurred with both
AirPlay and USB audio while playback continued. A recorded zero-volume command
is useful evidence, but does not by itself explain the initiating fault.

[Apple feedback status](docs/APPLE_FEEDBACK.md) lists five submitted reports and
one silencing draft, with remaining capture gaps. Journals, system-log collection,
and installation have different requirements: [collection guide](docs/WATCH_LOG_COLLECTION.md).

Physical follow-through remains: actual iPhone volume after every recovery path,
landmark countability while moving, runtime renewal/endurance, accessibility and
battery impact. No new physical validation is implied by Mac-only checks.

## Historical detail

- [Verification reports through build 16](docs/history/VERIFICATION_THROUGH_BUILD_16.md)
- [Earlier prototype/review notes](docs/history/REVIEW_NOTES.md)
- [Runtime recovery](docs/RUNTIME_RECOVERY.md)
- [Haptic delay behavior](docs/HAPTIC_DELAYS.md)
- [Volume focus comparison](docs/SIMULATOR_VOLUME_FOCUS.md)
- [Native media recovery](docs/NOW_PLAYING_SERVICE_RECOVERY.md)
- [Always-On hand investigation](docs/ALWAYS_ON_HAND_TRANSITION.md)
