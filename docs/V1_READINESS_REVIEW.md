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

## Account and support preparation

The separate App Store Connect record is **Teaching Timer Beta**, with store
container `net.qays.TeachingTimer`. Apple rejected “Teaching Timer” as already
used; the public release name remains a decision. The Watch payload stays
`net.qays.TeachingTimer.watchkitapp`; development remains
`com.qayshp.TeachingTimer`. The pilot is internal-only; no external testers or
public release are configured.

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
unsigned development/distribution archive pipeline. The Python suite passes 102
tests after adding retirement fixtures and explicit export-declaration checks.
All ten SE 3 retirement assertions pass for build 29: old editor redirect,
Settings return, explicit new Start, custom draft preservation, and cleanup.
Screenshots were reviewed separately. Final signed source revision and server
acceptance must be recorded in current status when complete. Raw captures, build products and account evidence remain
private under ignored `work/`.

Next independent work:

1. Finish candidate UI cases, including retirement, small/large layouts and
   accessibility text. Review pixels separately from callback/state assertions.
2. Build and inspect a clean signed candidate, upload internal-only, and verify
   Apple's processing result. Do not install on the physical Watch during use.
3. Reproduce [issue #7](https://github.com/qayshp/TeachingTimer/issues/7) on the
   current Simulator before changing recovery. An October 29 journal shows native
   active state, inactive/dimmed scene, then WatchKit activation error code 3.
   The app persists manual recovery after that failed start. Investigate a
   scene-ready deferred attempt or one exact-error retry while preserving Stop;
   do not convert old unexplained manual-recovery intent into automatic starts.
4. Repeat the isolated seconds-hand transition probe on watchOS 27.2. Do not
   clamp system timeline dates or claim the newer OS fixed it without evidence.
5. Complete verified support delivery and a supervised physical file-sharing /
   TestFlight install-update-journal pilot when the devices are available.

The [publishing gates](PUBLISHING_READINESS.md) remain: actual runtime-use guidance,
minimum watchOS compatibility, physical teaching/accessibility validation,
release metadata and privacy review, and a small teacher pilot. Known native
media/volume defects remain separate tracked symptoms with recovery guidance;
this review has not established their root causes or closed them.
