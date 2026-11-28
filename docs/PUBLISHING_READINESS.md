# Publishing readiness

On November 20, **1.0 (261120.0102.67)** was selected on the 1.0 draft for manual
release. A USB-C volume drop recurred on that build, so physical acceptance remains open.
The [current status](../DEVELOPMENT_STATUS.md) records the public beta,
the signed candidate, and their verification evidence.

## Release gates

| Gate | Evidence and remaining work |
| --- | --- |
| Build integrity | Store candidate `f06755f3b2f9ea1c3df8645fa36114b0d87b4dfa` passed Watch checks, CodeQL, signed export, and Apple processing. If release inputs change, repeat verification and attach the replacement build to the 1.0 draft. |
| Store materials | The November 20 draft included production artwork, Watch and iPhone screenshots, privacy disclosure, 4+ rating, reviewer contact and notes, and free U.S.-only availability. Finish the name, subtitle, and Content Rights declaration. Check EU trader status before adding EU territories. Confirm screenshots and notes match the final build. [Metadata](DISTRIBUTION_METADATA.md). |
| Runtime policy | Ask Apple about the mindfulness extended-runtime category for guided yoga instruction and the renewal policy. Document the answer or adopt a supported alternative. [Runtime-use briefing](DISTRIBUTION_METADATA.md#runtime-use-briefing-for-apple--not-submitted) · [#9](https://github.com/qayshp/TeachingTimer/issues/9). |
| Teaching reliability | Finish the physical checks below. The embedded song-progress stall already reproduces in Apple's own sample. Explain it and the standalone Now Playing workaround in reviewer notes. |
| Watch size and accessibility | Review the current candidate on small and large Watches and check VoiceOver on hardware. The [earlier five-size layout matrix](V1_READINESS_REVIEW.md#build-35-static-layout-matrix) documents build 35. Verify the watchOS 26 minimum separately from newer runtime checks. [#10](https://github.com/qayshp/TeachingTimer/issues/10). |
| Install, update and support | The [owner installation/update pilot](TESTFLIGHT_PILOT_RESULTS.md) passed with separate app containers. Private email and both companion report directions have worked on hardware. Verify the first external install and remaining companion upgrade/interruption cases. [#11](https://github.com/qayshp/TeachingTimer/issues/11) · [#26](https://github.com/qayshp/TeachingTimer/issues/26). |

New testers can use the [first-class guide](TESTER_GUIDE.md), [privacy policy](PRIVACY.md),
and [support guide](../SUPPORT.md). A short support description is enough. The
[TestFlight procedure](TESTFLIGHT_PREPARATION.md) records signing, group assignment,
and upload milestones.

## Physical acceptance for the 1.0 candidate

The owner used **1.0 (261120.0102.67)** successfully in two AirPlay classes.
On November 26 a timer-page volume drop on USB-C recovered through Now Playing.
The paired logs suggest an earlier volume value was reused. The cause remains
unknown. [Incident and Apple report](APPLE_FEEDBACK.md#november-26-volume-drop-on-the-10-candidate).

Use the [Control A / Isolated B comparison](https://github.com/qayshp/TeachingTimer/pull/33)
to investigate the affected adapter. The experimental apps can identify a
mitigation. Confirm any mitigation on the exact signed release candidate.

Read the Watch app's build in **Settings → About** before starting. Preserve the
development installation and its data through candidate testing.

1. **Recover after reopening.** Start a test class and note its scheduled end.
   Force-close and reopen with the Watch awake. Check that the schedule survives
   and the session resumes. Stop the session intentionally, reopen again, and
   verify that it stays stopped.
2. **Exercise the affected volume route.** With USB-C playback audible at a
   comfortable level, make one small Crown adjustment on the timer. Repeat after
   returning from media and after Home and reopen. If volume drops, stop turning.
   Note the time, output, ring response, and Crown direction, then restore sound
   from Now Playing or the iPhone.
3. **Teach a full class.** Record battery at start and end, wrist-down readability,
   scheduled finish, and any runtime interruption. Try a count with the preferred
   vibration setting. Check whether the session reached the renewal boundary.
4. **Check support and accessibility.** Try one companion report with the
   smallest useful time window. Check the key controls with VoiceOver and
   confirm that you can reach Apple's standalone Now Playing quickly.

Record the actual build, Watch OS, playback route, expected and observed
results, and recovery. A crash, lost class schedule, unrecoverable runtime or
volume control, or unexpected silencing blocks the candidate. A progress
stall can remain a known limitation if the maintainer accepts its effect and
the recovery is documented.

## Submit and release

After the gates pass, confirm the exact build, listing fields, owner
declarations, reviewer notes, and manual release setting. Submit for review
and record Apple's decision or requested changes. Keep the development
installation available while checking the published build.

Apple references: [runtime categories](https://developer.apple.com/documentation/WatchKit/using-extended-runtime-sessions),
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
and [TestFlight](https://developer.apple.com/testflight/).
