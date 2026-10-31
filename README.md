# Teaching Timer

A watchOS-only clock for teaching yoga: prominent wall-clock hands, scheduled
class progress, one-minute visual counts with optional vibrations, and native
media controls. No iPhone companion app, workout tracking, heart-rate collection,
account, advertising, or analytics.

Built around real teaching on Apple Watch SE 3. This is still an experimental
app with known media, volume and Always-On issues. Test it before relying on it
in class and keep another timing method available.

<img src="docs/images/settings-25/se3-face.png" alt="Build 25 SE 3 Simulator teaching face with Class and gear, native volume and wall-clock hands" width="240">

*Build 25, SE 3 40 mm Simulator. The disconnected-phone symbol is Simulator state.
The installed build and current source candidate are listed in
[current verification](DEVELOPMENT_STATUS.md).*

## Try it

There is no public TestFlight invitation or App Store release yet. To build it,
use the instructions below. New testers should read the
[first-class guide](docs/TESTER_GUIDE.md) and [privacy notes](docs/PRIVACY.md).

1. Tap **Start class**, check **Suggested time**, then confirm the 60-minute class.
   **Custom schedule** changes only this class: adjust its start and choose 60 or
   75 minutes. When starting early, check the suggested quarter-hour carefully.
2. Read the long thin hand for wall-clock seconds and the shorter thick hand for
   minutes. The inward wedge marks scheduled end. A 60-minute class also shows
   the remaining interval around the perimeter; 75 minutes uses the end wedge only.
3. Turn the **Digital Crown** for paired-iPhone volume. Swipe left for Apple's
   **Now Playing** page; swipe right for the clock. Native media can select Watch
   playback, so check the source before class.
4. Tap **1-min count** for an inner arc timed from your tap. Groups of 1–6 pulses
   mark 10–60 seconds; the last group finishes at about 64.8 seconds. Tap again
   to stop. Haptics may be late or skipped by watchOS.
5. Tap **Class** (with the gear) → **Settings** to turn **Count vibrations** off
   for the next count or enable **Minutes left**. Both preferences persist.

**Stop session / Resume session** affects the mindfulness runtime while retaining
class timing. **End class** clears timing and stops session/count. **New class**
creates another schedule with confirmation. An old class retires 30 minutes after
scheduled end; a new class never starts silently.

## When something goes wrong

- Frozen song progress or blank media: swipe to the timer and back to recreate
  the native media view. Progress has recurred after temporary recovery. Eligible
  long-dimmed wakes also refresh automatically; this does not detect a failure.
- Timer Crown volume: tap the native volume display to request refresh; returning
  from media is another recovery path. A visual acknowledgement does not prove
  focus or sound recovered. If playback is silent, the iPhone's volume controls
  have restored it in reported cases.
- **Session off**: use **Resume**. Intentional Stop stays stopped across reopening;
  automatic recovery is bounded and watchOS may reject it.

The [known-issue map](docs/ISSUE_TRACKER.md) keeps symptoms and mitigations
separate. [Report a problem](https://github.com/qayshp/TeachingTimer/issues/new/choose)
with build/OS, what happened, approximate time and recovery. Do not interrupt a
class to gather evidence or post raw diagnostics publicly.

## Build and contribute

Requires Xcode with watchOS 26 SDK or later; the current local toolchain is Xcode
27.1. Deployment target is watchOS 26. Open `TeachingTimer.xcodeproj`, choose the
TeachingTimer scheme and a Watch simulator, and Run. For your own physical Watch,
select your development team and a unique bundle identifier under Signing &
Capabilities. Credentials, profiles and user-specific Xcode state stay out of Git.

```sh
python3 scripts/check-repository.py
sh scripts/check-tools.sh
sh scripts/check.sh
python3 scripts/verify-build.py work/verification-new
```

The final command repeats the offline checks, builds for Simulator and rehearses
unsigned development/distribution archives. It does not install or upload.
Interactive Simulator checks need Device Hub and are run separately.

Start with [contributor setup](CONTRIBUTING.md), the
[documentation map](docs/README.md), [automation coverage](docs/AUTOMATION.md),
and [publishing readiness](docs/PUBLISHING_READINESS.md).
The [Settings review](docs/SETTINGS_PASS_25.md) and
[form-factor checks](docs/FORM_FACTOR_VALIDATION.md) include labeled Simulator
screenshots. They do not certify physical audio, haptics or Always-On cadence.

In Xcode 27 Device Hub, **Controls → Lock (⌘L)** exercises reduced-luminance
Always-On in Simulator. Haptic requests can sound as Mac speaker chimes.
[Testing boundaries](docs/DEVICE_HUB_TESTING.md) explain the limits.

## Privacy

Preferences, class context and bounded diagnostic journals stay in the app's
container. There is no automatic upload. App journals contain lifecycle/timing
and error information; system diagnostics can contain much more private data.
Review and minimize any diagnostic sharing. See [privacy](docs/PRIVACY.md).

## License

Teaching Timer is licensed under the [Mozilla Public License 2.0](LICENSE)
(`MPL-2.0`). Unless otherwise noted, this covers the project's source, tests,
build configuration, documentation, and original assets.

MPL is file-level copyleft: when distributing modified versions, changes to
covered files must remain available under MPL. See the license for the full
terms and [Mozilla's FAQ](https://www.mozilla.org/en-US/MPL/2.0/FAQ/) for guidance.

## Reliability and distribution tooling

- [Bounded Simulator lifecycle and media-failure captures](tools/simulator-regression/README.md)
- [Isolated native companion-volume probe](tools/native-volume-probe/README.md)
- [Persistence failure diagnostics](docs/PERSISTENCE_DIAGNOSTICS.md)
- [TestFlight identity preparation and diagnostic-access gates](docs/TESTFLIGHT_PREPARATION.md)

Future distribution uses `net.qays.TeachingTimer` (qays.net). The current
Xcode development installation keeps `com.qayshp.TeachingTimer`; no existing
class or journal is migrated simply by building the distribution identity.

Known bugs and evidence gaps are tracked in [GitHub issues](https://github.com/qayshp/TeachingTimer/issues)
and the [issue/Apple-feedback index](docs/ISSUE_TRACKER.md). Please use the bug
form and keep raw device logs and personal diagnostics out of public reports.

Current remaining work and physical/TestFlight gates: [active roadmap](docs/ROADMAP.md).
