# TestFlight preparation and naming

Updated October 26, 2026. This is local preparation, not a distributed beta.

## Identity

Use the maintainer-owned **qays.net** as the namespace for future distribution.
It is short, personally owned and independent of a particular GitHub account.
No DNS or website changes are needed for this local configuration.

| Purpose | Identifier |
| --- | --- |
| Existing development/teaching installation | `com.qayshp.TeachingTimer` |
| Future TestFlight / App Store application | `net.qays.TeachingTimer` |
| Isolated native volume fixture | `net.qays.TeachingTimer.VolumeProbe` |
| Isolated timeline fixture | `net.qays.TeachingTimer.ClockProbe` |

The product/source name stays `TeachingTimer`; the display name remains
**Teaching Timer**. Normal Debug and Release builds keep the existing development
identifier. `Configurations/TestFlight.xcconfig` is an explicit opt-in override;
there is no silent migration of the current Watch installation or preferences.
The two identities have separate containers, saved classes and journals.
Production OSLog subsystems now derive from the running app's bundle identifier,
so development keeps its old subsystem and distribution uses the new one.
Historical incident documents retain the identifiers actually observed then.

Apple supports [watch-only TestFlight distribution](https://help.apple.com/xcode/mac/current/en.lproj/devaba4602fd.html).
Choose the final identifier before uploading: Apple says it cannot be changed in
App Store Connect after the first build upload ([distribution preparation](https://help.apple.com/xcode/mac/current/en.lproj/dev91fe7130a.html)).
No identifier registration or name availability has been checked with the account.

## Local rehearsal

```sh
sh scripts/prepare-testflight.sh work/testflight-rehearsal-new
```

Requires Xcode and a new destination directory. It creates a Release archive
with the distribution identifier, **without signing, provisioning changes,
upload, installation or launch**. It validates the app binary, identifier,
Watch-only declarations, mindfulness background mode and symbols. `readiness.json`
records build/version and the unverified gates. Private generated files stay in
ignored `work/`; never commit signing material or raw device logs.

Build 18 passed this structural rehearsal on Xcode 27.1. This is not App Store
validation, beta review, or physical runtime/media verification.

## Pilot gates before relying on it for a class

1. Preserve a known-good development app and its journals. Keep the existing
   teaching installation available until the distribution build is validated.
2. Register the explicit identifier on the paid team and create the App Store
   Connect record when distribution is requested. Confirm version/build,
   signing, privacy disclosures, beta instructions, and applicable export
   declarations. Use the override for the signed archive too; do not upload the
   ordinary development-identifier archive by mistake.
3. Validate and upload a signed archive, then install through a private TestFlight
   pilot. Confirm cold launch, saved-class recovery, intentional Stop, wrist-down
   clock/count behavior, media return and companion volume on the physical Watch.
4. Test **journal access separately**. Xcode 27.1 `devicectl device info apps
   --help` describes container access in terms of Xcode-installed development
   apps; our successful development copies do not prove TestFlight copies work.
   Try the new identifier explicitly. If access fails, design a user-triggered
   export path before relying on TestFlight for incident investigations. Do not
   add an iPhone companion or network service merely to assume this is solved.
5. Verify system-log collection independently. TestFlight crash/feedback reports
   do not replace the custom runtime/interface/landmark journals or guarantee a
   reliable developer tunnel. Easier app delivery would not fix device-log
   connection failures. See [diagnostic tools and access limits](DIAGNOSTIC_TOOLS.md).

Apple's [tester instructions](https://testflight.apple.com/) describe installation
and feedback, including watch-only apps. This project has not yet completed that
pilot. No App Store Connect record, signed distribution export, upload, tester
invitation or physical installation was performed in this batch.
