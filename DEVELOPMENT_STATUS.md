# Teaching Timer — current verification

Updated October 29, 2026. Historical observations are kept separately so that
previous build states do not read as current facts.

## Current candidate and teaching checkpoint

Current source and installed physical-Watch build: **1.0 (23)**. Installation
and launch were verified October 29; classroom validation of build 23 is pending.
**Build 16** remains the preserved classroom-tested rollback checkpoint, not the
currently installed version. [Active roadmap](docs/ROADMAP.md) is the single
place for completed work, next steps and hardware gates. The
[builds 17–21 implementation record](docs/history/ROADMAP_BATCHES_17_TO_21.md)
preserves earlier batch reports without treating them as current conclusions.

Builds 17–21 extend journal retention, add persistence diagnostics, bounded local
collection/summary/regression tools, release checks and a separate distribution
identity. Build 20 makes refresh acknowledgement neutral; build 21 adds a short
unreadable-class notice with a direct Start action. Native volume/focus timing,
media policy, wall-clock hands and count scheduling are unchanged by those last
two UI changes. [Usability verification](docs/USABILITY_FOLLOWUP_2026-10-28.md).

## October 29 maintenance review

The maintenance verification below used build 22. The subsequent release pass
bumped the version to build 23 without changing production behavior and installed
it on the Watch; see the deployment record below. Documentation is now
indexed by purpose and evidence age; deterministic and interactive regression
coverage has expanded. See the [repository review](docs/REPOSITORY_REVIEW_2026-10-29.md)
and [automation map](docs/AUTOMATION.md). The maintainer reports build 16 worked
well in the October 28 class around 1:15 p.m.; that is a user observation, not a
new log capture or evidence that intermittent bugs are resolved.

### October 29 verification results

- All 12 Swift suites and 80 Python tests pass. Repository consistency checks,
  Simulator build and unsigned development/distribution archive checks pass.
- SE 3 and Ultra each pass 14 essential actions and 33 count/Lock captures;
  all outline measurements are present. OCR flags 29 SE 3 and 6 Ultra frames
  for review, not missing-control diagnoses. Representative locked frames and
  the SE 3 native Not Playing screen were visually inspected.
- SE 3 passes all six focus/lifecycle assertions. Both simulators complete the
  full count at about 64.82/64.81 seconds. Retrospective validation of original
  journals confirms reduced luminance at +2 seconds and no recorded wake before
  completion. The final runner now requires that evidence automatically.
- Awake process-relaunch tests pass on both sizes for automatic running-class
  recovery and intentional Stop, with the saved class unchanged. The initial
  dimmed SE 3 relaunch was rejected by watchOS and saved manual-recovery intent;
  it remains a separate [open finding](docs/REPOSITORY_REVIEW_2026-10-29.md#locked-relaunch-observation).
- Original run manifests/captures remain private. The test app is build 22 from
  `68bf84a7897f-dirty`; production source/configuration is unchanged from that
  base. The maintenance changes are tests, tooling and documentation. No physical
  device was contacted. Both test simulators finish with their sessions stopped.

## Build 22 — usability changes retained in build 23

The default Start card identifies its interval as **Suggested time**. Action
labels stay within two lines with modest scaling at maximum text; the face's
short Start fallback announces **Start class**. Quarter-hour inference, default
60 minutes, separate custom drafts, hands and native session/media behavior
are unchanged. [Screenshots and review](docs/USABILITY_PASS_22.md).

The hand/icon comparison did not establish a consistent benefit and was removed.
The original-media audit confirmed four October 24 black frames and their
recovery images; the later comparison ranking remains withdrawn. One fresh
build-21 media sequence rendered all six captures and passed its five lifecycle
checks. Apple received that clarification and the separate documentation report
**FB25347535**; **FB24696786** was cross-referenced and closed as requested.

## Evidence that must not be conflated

- The previous disappearing-timer-control screenshot diagnosis was incorrect.
  Original PNGs contain the controls; 99 bounded frames did not reproduce a
  missing full-width outline. Experimental drawing changes were removed.
- Nine delayed media captures attached to Apple contain Not Playing. The
  delayed-black and recovery-ranking claims were corrected in FB25305069 at
  01:04 PDT on October 28. The original October 24 black captures are now confirmed by an
  [image audit](docs/MEDIA_IMAGE_AUDIT.md); native callbacks alone cannot
  establish a visible failure.
- Physical black-media reports and intermittent volume failures remain valid
  unresolved observations. Neither correction dismisses those experiences.
- Lifecycle checks verify host/class/control state only. Focus return, a moving
  volume ring, a haptic submission or a view callback does not prove actual
  phone volume, tactile delivery or rendered content.

## October 28 build-22 verification snapshot

At that checkpoint, twelve deterministic Swift suites and 48 Python tooling checks
pass, along with the Simulator build and unsigned development/distribution
archives. All 14 essential-action assertions pass on each of SE 3 and Ultra;
all six focus/lifecycle assertions pass on SE 3. Four final media captures
contain Not Playing, and full count-button outlines are present in the
start/cancel captures on both sizes. These are not phone-audio assertions.
Latest setup/custom flows were checked at normal/maximum text and
12/24-hour time on SE 3 and Ultra; maximum-text summaries reach End class by
scrolling. The unreadable-class notice/data-preservation checks from build 21
remain separately recorded. These are local tests; no physical operation was performed.
[Build evidence workflow](docs/BUILD_VERIFICATION.md).

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
- Original view-only recovery trials show native content after induced Simulator
  service loss, confirmed by the original-image audit. Physical blank media has occurred during classes;
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

Earlier blank **timer return** interpretations require original-image review and
are distinct from user-reported physical black **media**; a common cause is unproven. Silencing has occurred with both
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

## Build 23 — physical candidate

Build 23 packages the build-22 app behavior and October 29 maintenance work for
physical testing, at the maintainer’s request. The version bump introduces no
new runtime/media policy. Installation outcome is recorded separately; build 16
remains the preserved rollback checkpoint. The dimmed-relaunch finding above
is unresolved.

Build 23 installation and installed-version verification succeeded on October 29.
The first attempt failed with DDI service errors; the bounded retry installed it.
The initial launch was unconfirmed; a launch-only retry succeeded. Private
evidence: `work/support/2026-10-29-build23/`. Physical class validation remains
pending. Build 16 remains preserved for rollback, but is no longer the installed
build. The signed profile expires October 13, 2027 at 06:37:14 UTC.
