# Changelog

User-facing beta milestones. Build availability and last confirmed installation
live in [current status](DEVELOPMENT_STATUS.md); these notes do not imply every
build was installed or passed hardware validation.

## Unreleased — build 41 layout candidate

- Restored all 60 full-length ticks behind the top elements. The Class button
  has a translucent black backing and opaque text/outline; ticks under the
  native system time are reduced to quarter strength within an approximate region.
- Kept the full-screen perimeter, foremost hands and existing touch targets.
  Class, runtime, count and native Crown-volume behavior are unchanged.
- Checked five current display sizes, SE 3/Ultra dimmed and maximum-text views,
  and Home/refresh/media-return lifecycle behavior in Simulator.

## Layout checkpoint — build 40

- Restored a full-screen dial that follows the display edge around Class/settings
  and the system clock. Only ticks crossing those labels are shortened or omitted.
- Used adjustable corner profiles fitted to current Simulator masks; physical
  display curvature remains an approximation. Both hands remain foremost.
- Kept the inner count track clear of the top labels without moving the outer
  clock down. Status/minutes-left remains inside the count control.
- Checked all five current display sizes, reduced luminance and maximum app text.
  Class, runtime, count timing and native Crown-volume behavior are unchanged.

## Superseded — build 39 layout proposal

- Aligned the dial, class-progress perimeter and count track below a clear header.
  Both hands use the same center and remain above controls.
- Moved status/minutes-left into the count control, keeping the hand hub clear.
- Checked five current Watch sizes, dimmed presentation and maximum app text.
  This is a separate draft from build 38 and is not distributed through TestFlight.
- Replaced by build 40 after the maintainer clarified that preserving the full
  display area around the top controls was preferable to a separate header strip.

## 1.0 (38) — media experiment upload

- Moved the clock timeline inside the teaching page so native media is outside it.
  Live song-progress improvement remains unverified; [PR #18](https://github.com/qayshp/TeachingTimer/pull/18)
  is still an experiment.
- Signed/uploaded November 2. Owner TestFlight group availability awaits browser
  sign-in and readback; upload does not establish installation.

## 1.0 (37) — November 2, 2026

- Prepared the first external-eligible TestFlight build and submitted it for
  Apple's review. The [public invitation](https://testflight.apple.com/join/YA2WSmae)
  is published but is not yet accepting testers; the initial limit is 100.
- App behavior is unchanged from 36. Known song-progress, volume and other
  reliability limitations remain; private support accepts descriptions/screenshots.
- [Source tag and prerelease record](https://github.com/qayshp/TeachingTimer/releases/tag/v1.0-beta.37)
  preserve the signed revision and local export digest, separately from Apple approval.

## 1.0 (35–36) — November 2, 2026

- Made the full privacy policy and license available offline in Settings, and
  clarified support/journal access for beta testers.
- Improved small/large-screen information-page readability. The owner pilot
  verified TestFlight installation, updating, saved state and limited journal access.
- Supervised Beta 35 testing confirmed timer-volume recovery in four iPhone-speaker
  scenarios. Embedded song progress still stalled even when entry refreshed position.

## 1.0 (31–34) — November 2, 2026

- Deferred runtime starts until app and scene readiness agree, including a Start
  queued behind session invalidation. Intentional Stop and saved class survive.
- Corrected two bounded Simulator seconds-hand mechanisms: precision at whole-second
  boundaries and a moving schedule anchor. Physical dim/wake validation remains open.

## 1.0 (25–29) — October 30–November 2, 2026

- Added Settings for count vibrations and optional minutes-left text, followed by
  offline Help, Privacy and About. No iPhone companion interface is required.
- Retained bounded native-media refresh after eligible inactivity; it refreshes a
  position snapshot but is not a guarantee of continuously accurate song progress.
- Prepared separate development/beta identities and private email support.

For earlier changes, see [historical checkpoints](docs/history/VERIFICATION_THROUGH_BUILD_25.md).
