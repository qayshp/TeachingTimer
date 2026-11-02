# V1 readiness review — November 2, 2026

This is the active review record. [Current verification](../DEVELOPMENT_STATUS.md)
owns the candidate and installed-build status. The physical Watch is in use and
must not be contacted, installed, launched or tested during this review. Internal
TestFlight preparation/upload and support-alias setup are authorized separately.

## Scope and acceptance

Preserve the Watch-only teaching clock, shared class/runtime/count state, native
companion volume control and native Now Playing. Improve concrete correctness,
onboarding, evidence and release gaps before expanding features. A clean build
or Simulator pass does not establish physical Crown, audio, haptic, battery,
Always-On, distribution installation or App Review acceptance.

## Findings addressed

- **New Start lost during old runtime invalidation:** a deterministic controller
  reproduction showed a new class with running intent but no runtime. An explicit
  Start now waits for the previous session to finish and the app to be active.
  It is tied to its class, creates one successor and is cancelled by a subsequent
  Stop, reset, replacement or retirement. Existing automatic-renewal policy and
  native controls are unchanged.
- **Retired schedule editor silently saving nothing:** edits now check original
  class identity and retirement before saving. A retired editor becomes fresh
  setup with a short explanation; Settings returns there as well. Independent
  custom new-class drafts are preserved. Invalid saves cannot resurrect an old
  class or modify another class.
- **Release and repository checks:** test both signed payloads and the actual
  entitlement-plist parsing command. Reject force-added credential and generated
  artifact families already excluded by ignore rules. No such tracked files were
  found. Add optional, bounded retirement UI cases using pre-launch synthetic
  classes; no live preferences or system-clock changes.
- **Information copy:** About uses the real bundle display name, including Beta;
  Help explains the suggested quarter-hour; Privacy distinguishes development
  journal copies from unverified TestFlight access and says there is no in-app
  export/upload.
- **Documentation drift:** reconcile the accepted agreement, signed build-28
  export, newer runtime availability and continued song-progress recurrence.
  Keep dated investigations and their corrections intact.

Signed release preparation also now rejects dirty source before archiving and
rejects source/commit changes or a mismatched binary revision before export.
Unsigned rehearsals remain usable during development. Build 31's 107 Python tests pass,
including the signed-source boundaries and ignored-versus-untracked Git fixtures.

## Account and support preparation

The separate App Store Connect record is **Teaching Timer Beta**, with store
container `net.qays.TeachingTimer`. Apple rejected “Teaching Timer” as already
used; the public release name remains a decision. The Watch payload stays
`net.qays.TeachingTimer.watchkitapp`; development remains
`com.qayshp.TeachingTimer`. Build 32 is Ready to Test / Internal after clean
signed archive/export, upload and processing. It is assigned to the Maintainer
pilot with one tester, the owner, and manual distribution. Builds 29 and 31 are also
assigned; build 30 is processed but unassigned. No external testers or public
release are configured. The build-32 What to Test notes and one-group/one-tester
assignment were verified after reload in App Store Connect.

Beta Test Information was saved and verified after reload: description and known
limitations, support address, repository and privacy URLs. Review contact remains
blank; no custom EULA or app sign-in requirement was added.

The approved support alias was added to the existing iCloud custom domain.
Existing routing and catch-all settings were retained. A harmless inbound test was received and verified. Outbound reply verification
remains separate. See the
[private intake procedure](PRIVATE_SUPPORT_PLAN.md).

The isolated [sharing probe](../tools/diagnostic-share-probe/README.md) presented
synthetic text/JSON/ZIP to the SE 3 Simulator's native sharing UI. JSON and ZIP
reached Messages compose and triggered representation requests. Only Messages
was offered; nothing was sent. This supports a future physical file-sharing
experiment, not an implemented journal export or verified Mail/delivery path.

## Evidence and remaining checks

Selected Xcode is 27.2 (27B52), with Watch Simulator 27.2 (24S118) and the newest
compatible general iPhone runtime 27.2 (24B8117). Existing booted Simulators are
reused. The initial build-28 SE 3 action run passed all 21 assertions, including
information pages, saved timing, session/count controls, replacement, and page
navigation. Actual screenshots show the expected controls and native Not Playing
state; no paired audio result follows.

The first build-29 source checks passed all 12 Swift suites, the full build and
unsigned development/distribution archive pipeline. That build's Python suite
passed 102 tests after adding retirement fixtures and explicit export-declaration checks.
All ten SE 3 retirement assertions pass for build 29: old editor redirect,
Settings return, explicit new Start, custom draft preservation, and cleanup.
Screenshots were reviewed separately. Build 29's clean signed revision
`7e9ca4a82324` and build 30's `da9d8d6756f8` passed signed export and Apple
processing. Build 31 passes all 12 Swift suites (including new early-handoff
scene/native checks), 107 Python tests and Debug Simulator compilation. Clean
revision `9da154876eeb6a429e3d655583696b5958b8dd2b` passed signed archive/export,
including the source-cleanliness guard. Upload completed at 13:19:59 PST on
November 2; Apple processing and owner-pilot assignment are verified. Raw captures,
build products and account evidence remain
private under ignored `work/`.

Next independent work:

1. Preserve the now-completed [issue-7 comparison](RUNTIME_RECOVERY.md#build-31-candidate-comparison):
   one matched candidate trial defers the premature Start and recovers on later
   active wake without error. A second trial did not match initial dimming;
   Stop comparisons independently retained stopped intent. All 14 candidate
   preference captures matched the baseline class bytes. This is bounded Simulator evidence, not
   a guarantee for arbitrary callback ordering or physical behavior.
2. Arrange the physical build-32 TestFlight install/update/journal pilot when
   authorized and available. Signed export, upload, processing and owner-pilot
   assignment are complete; installation is not. Keep the teaching Watch untouched
   until the user authorizes that next step.
3. Preserve completed retirement/layout assertions and reviewed screenshots as
   regression evidence. These are completed UI checks, not pending redesign work.
4. The isolated fixed-anchor probe reproduced two backsteps on watchOS 27.2.
   Preserve the [exact evidence and qualifications](ALWAYS_ON_HAND_TRANSITION.md#november-2-watchos-272-reproduction)
   for the existing Apple report; do not clamp system timeline dates.
5. Verify outbound support replies and arrange a supervised physical file-sharing /
   TestFlight install-update-journal pilot when the devices are available.
   Inbound email receipt is already verified.

The [publishing gates](PUBLISHING_READINESS.md) remain: actual runtime-use guidance,
minimum watchOS compatibility, physical teaching/accessibility validation,
release metadata and privacy review, and a small teacher pilot. Known native
media/volume defects remain separate tracked symptoms with recovery guidance;
this review has not established their root causes or closed them.

## Build 30 usability follow-up

Default setup/face captures were reviewed across SE 3 40/44 mm, Series 12 42/46 mm
and Ultra 4 49 mm on watchOS 27.2. Maximum-text Settings was checked on the small
SE 3 and Ultra. On SE 3 the custom Back capsule obscured Settings; the icon-only
chevron keeps the same return action and accessible Back label. Cancel/Done retain
their distinct text. The maximum-text custom Cancel/Time header fits unchanged.
Back returned to the same fresh setup in the targeted test.

| Build 29, maximum text | Build 30, maximum text |
| --- | --- |
| ![Back obscures Settings on SE 3](images/v1-review/se3-settings-29-maximum.png) | ![Chevron leaves Settings readable on SE 3](images/v1-review/se3-settings-30-maximum.png) |

About now provides the verified private email and a support QR. The address stays
on one line; the QR page uses the short Support navigation title. Its code was
decoded from the actual SE 3 screenshot to the configured support-page URL. Native
Back returned to About. Physical camera scanning and attachment delivery remain
unverified; the probe is still isolated and not a feature of TeachingTimer.

| Offline email | Phone support link |
| --- | --- |
| ![Private support email in About](images/v1-review/se3-support-email-30.png) | ![Support-page QR on SE 3](images/v1-review/se3-support-30.png) |

## Build 32 bounded follow-up

Build 32 is the clean signed candidate and is available to the owner pilot.
The physical Watch remains untouched on build 25.

- **Queued explicit Start:** the readiness check now also covers an explicit
  request waiting for the previous runtime's invalidation. Deterministic
  boundary-double tests pass for both readiness/invalidation orders and for
  cancellation by Stop, reset, replacement or retirement. Injected error paths
  are synthetic tests, not a new observed Simulator rejection. Direct immediate
  Start, native media/volume and count behavior are unchanged.
- **Privacy artifact verification:** archive inspection and exported-IPA checks
  now verify the actual Watch privacy manifest against the reviewed declarations.
  The existing build-31 archive/export already passes. This closes a verification
  gap rather than a shipped privacy defect; it does not establish Apple approval
  or replace an API-usage/privacy review.
- **First-use instructions:** README and tester guide explain Beta's separate
  saved state, Start class versus session, and the arc filling at 60 seconds
  before count completion near 64.8 seconds, including visual-only counts.

Build 32 compiles for Simulator and passes all 12 Swift suites and 110 Python
tests. All 21 UI-action assertions pass; Help, active clock, Stop/Resume and native
Not Playing screenshots were reviewed without a new visual regression in those
views. Clean source `f931c173ab86` passed signed archive/export, actual Watch
privacy-manifest checks, CI, Apple processing and manual owner-pilot assignment.
See the [release artifact record](TESTFLIGHT_PREPARATION.md#subsequent-pilot-builds).
This does not establish paired audio, physical installation/update or journal access.

A source-only minimum-OS audit found all three build configurations target
watchOS 26. The used APIs checked against the current SDK were available by
watchOS 10, with no unguarded post-26 API found. This is not execution on the
minimum OS: no older runtime was installed, and watchOS 26 execution remains pending.
