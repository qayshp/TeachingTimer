# Changelog

User-facing beta milestones. Build availability and last confirmed installation
live in [current status](DEVELOPMENT_STATUS.md); these notes do not imply every
build was installed or passed hardware validation.

## 1.0 (37) — November 2, 2026

- Prepared the first external-eligible TestFlight build and submitted it for
  Apple's review. The [public invitation](https://testflight.apple.com/join/YA2WSmae)
  is published but is not yet accepting testers; the initial limit is 100.
- App behavior is unchanged from 36. Known song-progress, volume and other
  reliability limitations remain; private support accepts descriptions/screenshots.

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
