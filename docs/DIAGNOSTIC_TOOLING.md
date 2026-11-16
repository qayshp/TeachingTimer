# Diagnostic fixtures and historical workflows

Catalog reviewed November 15, 2026. These instruments keep individual questions
reproducible without adding diagnostic controls or private APIs to TeachingTimer.
Build success, dispatched input, app callbacks, native pixels, received files,
player time, phone volume and audible output are separate observations.

Use the selected Xcode's current SDK and the newest compatible installed
Simulator runtime under [repository policy](../AGENTS.md). Resolve identifiers
live. Build helpers do not authorize a device installation or interactive run.
Raw evidence, account/device details and original incident attachments remain
private under ignored `work/`; maintained synthetic source belongs in `tools/`.

## Maintained instruments

| Instrument | Question and signals | Boundary / reusable entry point |
| --- | --- | --- |
| [Native companion-volume probe](../tools/native-volume-probe/README.md) | Isolate retained versus replaced `WKInterfaceVolumeControl(.companion)`, focus/setup timing, Home/return and media/page composition. Journal records control identity and lifecycle requests. | Native volume has no public getter/setter here. A focus return is not actual input ownership or phone delivery. `build.sh`; launch flags include retained/replacement, staged/immediate and `--single-page`. |
| [Public Crown event probe](../tools/crown-event-probe/README.md) | Signed input oracle for one public `digitalCrownRotation` binding, initially 0.5 in 0...1; logs old/new/delta, event offset/velocity and orientation. | No audio or native volume on the same page. Its sign is not native volume's sign or a physical direction calibration. `build.sh`, optional Reset. |
| [Native Watch media lab](../tools/watch-media-lab/) | Explicit Simulator-only Crown transport plus an injected artificial native data source; inspect model, slider and sequencer state while leaving Apple's control/input arithmetic in place. | Private diagnostic API, never a production dependency. Deliberately withholding notifications creates a fault; it does not reproduce spontaneous physical failure. Source provenance and the two transport profiles are in [PINNED_UPSTREAM.md](../tools/watch-media-lab/PINNED_UPSTREAM.md). |
| [Phone audio probe](../tools/phone-audio-probe/README.md) | Known native iPhone player, generated tone, metadata and remote-command handlers; direct playback/route/volume journal. | Companion transport must be demonstrated independently. Paused by default; explicit bounded playback. Current source preserves the earlier Apple-report fixture's role without copying incident data. |
| [Retired Safari media probe](../tools/safari-media-probe/README.md) | Browser HTML audio and Media Session metadata/handlers as a source-type comparison with native phone playback. | Loopback-only Node built-ins, explicit port, silent default, manual Play and finite file. Browser volume is an element value. This preserved historical workflow is not a current companion baseline. |
| [Silent Watch audio probe](../tools/watch-audio-probe/README.md) | Actual finite `AVAudioPlayer` clock versus native Now Playing progress with sparse transition-only metadata; optional frequent-publication comparison. | Silent PCM, default paused, no companion dependency or standalone local-volume control. Player time, metadata extrapolation and displayed progress must be compared separately. |
| [Watch-local volume probe](../tools/watch-local-volume-probe/README.md) | Native `.local` control beside actual Watch-local tone playback; compare KVO and direct `AVAudioSession.outputVolume` reads with native ring/backend activity. | Different from the silent progress fixture. Default paused, explicit tone, finite file and bounded interval. Local scalar/UI movement does not establish changed output or companion delivery. |
| [Timeline clock probe](../tools/timeline-clock-probe/README.md) | One hand driven by `TimelineView.Context.date`; fixed/moving anchor, Path/Canvas, color, raw/normalized boundary and render-trace comparisons. | Evaluation order is not presentation order. Exact reference-time bits and displayed frames matter. The fresh wall-clock diagnostic hand is not a clock implementation. |
| [Diagnostic-sharing probe](../tools/diagnostic-share-probe/README.md) | Native ShareLink behavior with harmless text, deterministic JSON and ZIP fixtures; verify a separately received attachment's bytes/schema. | A sheet or matching bundled source is not delivery. No real recipient/account/send is preconfigured. `fixtures.py` has deterministic regression tests. |
| [Simulator regression harness](../tools/simulator-regression/README.md) | Bound existing UI actions, native outline/pixel observations, focus lifecycle, count/Lock and explicitly gated media-service-loss runs; capture receipts and journals. | Requires disposable Simulator context, exclusive input ownership and explicit reset/termination options where applicable. Input dispatch and journal state do not establish physical display, audio or vibration. |
| [Physical-media notebook](../scripts/physical-media-run.py) | Offline run preparation, UTC/Pacific/monotonic operator marks, saved-evidence references and a read-only summary. | It never contacts a device or performs the prepared commands. The [physical plan](PHYSICAL_MEDIA_TEST_PLAN.md) defines supervised class/music order and preservation. |
| [Physical Device Hub control helper](../tools/physical-media/README.md) | One explicitly executed, reviewed touch/swipe/Home/Crown action against a physical device's current screen-sharing view; default is local plan validation only. | Fresh physical identity, exact selected row, reviewed AX display and foreground/modal checks; no install/unlock/reset. Compiled/CLI-tested offline; actual physical delivery still requires rehearsal. A submitted event is not a native volume command or audible result. |

`scripts/check-simulator-tools.sh` compiles all seven app fixtures, the host Crown
bridge, Simulator hook and inspection helpers; it runs both local wire self-tests
without connecting to CoreSimulator. It reuses its freshly built native/Crown
apps in the lab output. `scripts/change-impact.py` routes native tool
implementation changes to that macOS lane without publishing. Safari source and
its Node/HTTP regression tests use the lightweight tooling lane; all probe README
edits remain documentation-only.
Python tests cover deterministic fixture generation, input/receipt checks and
notebook behavior. Swift model suites exercise production state machines with
explicit boundary doubles. Interactive and physical results remain separately
recorded; none of those checks manufactures a working companion audio endpoint.

## Historical workflow index

| Date / question | Recorded result | Maintained source or historical location |
| --- | --- | --- |
| October 22: Safari/HTML phone source | Phone-side WebKit/system logs established a playing Media Session with metadata. Embedded and standalone Watch Now Playing remained Not Playing. A configured pair did not prove working media transport. | Promoted [retired Safari fixture](../tools/safari-media-probe/README.md) and [original investigation](PAIRED_SIMULATOR_MEDIA_TEST.md). Original loopback source: canonical `work/support/2026-10-22-paired-media/media-server.cjs`; this browser workflow is distinct from the native phone fixture. |
| October 22–23: native phone source | The isolated native app removed the Safari-specific source factor; no known-working companion-media baseline was established. Later runtime checks still require independent transport evidence. | Maintained [phone audio probe](../tools/phone-audio-probe/README.md); original source copies under `work/support/2026-10-22-clean-pair/NativeAudioProbe/` and `work/support/2026-10-23-feedback-media/SimulatorMediaDiscovery/NativeAudioProbe/` are byte-identical. See [issue #6 / FB25294079](ISSUE_TRACKER.md) and [27.2 validation](RUNTIME_27_2_VALIDATION.md). |
| October 24: Watch-local volume | Player advanced; native backend logged 33 values from 0.005625 to 0.185625 with unavailable/no-capabilities reports; public session scalar stayed about 0.60 in KVO and direct reads. The basic end-to-end volume gate failed. | Promoted [Watch-local probe](../tools/watch-local-volume-probe/README.md). Original `fixture/`, `probe.jsonl`, `native-volume-excerpt.log`, screenshots and `FINDINGS.md` remain under canonical `work/support/2026-10-24-watch-local-volume/`. |
| October 24–28: native media service loss | Deliberate service termination reproduced black media; later image audit corrected several misclassified Not Playing screenshots. Recovery observations are separate from spontaneous incident causation. | Explicitly gated simulator-regression media scenario; [service-loss report](NOW_PLAYING_SERVICE_RECOVERY.md), [comparison](MEDIA_RECOVERY_COMPARISON.md) and [image audit](MEDIA_IMAGE_AUDIT.md). Full-app variant snapshots are evidence copies, not new standalone apps. |
| October 26: retained/replaced volume host | Both refresh paths rendered; IDs confirmed retention versus replacement and stale pending work was suppressed after dismantling. Real audio behavior remained unvalidated. | Maintained native-volume probe and [focus investigation](SIMULATOR_VOLUME_FOCUS.md). |
| October 26 / November 2: Always-On hand | Exact-date traces identified representable values immediately below whole seconds; separately tested fixed versus moving anchors and normalization. The old moving-anchor arm retained observed backward ticks. | Maintained timeline probe flags cover raw, normalized, trace, fixed and moving variants; [evidence and limitations](ALWAYS_ON_HAND_TRANSITION.md). Original small/trace app copies under `work/support/2026-10-26-apple-reports/hand/` and `work/support/2026-11-02-v1-review/` preserve the historical source. |
| November 2: queued runtime readiness double | The historical offline double drove actual controller callbacks into a scene-inactive/new-class sequence and injected a known activation error. This is a constructed controller case, not an independently observed WatchKit rejection. | Maintained [RuntimeRenewalChecks.swift](../Tests/RuntimeRenewalChecks.swift) covers queued Start, inactive invalidation, Stop and class replacement. Historical `pending-explicit-readiness/Baseline.swift` remains with November 2 private evidence. |
| November 13–14: physical volume comparison | Native timer zero request was correlated with Crown input after a previously correct model read; the next day's good run used unchanged production behavior. It is intermittent, with missing physical signed input and pre-input ring evidence. | [Comparison](VOLUME_COMPARISON_2026-11-14.md), [host-isolation experiment](VOLUME_HOST_ISOLATION.md) and [supervised plan](PHYSICAL_MEDIA_TEST_PLAN.md). Original sysdiagnoses/journals are private evidence, not synthetic fixtures. |
| November 15: public binding and native-state lab | Four responsive public-binding trials mapped signed guest input in one runtime/orientation. Native baseline notification tests produced deliberate getter/view/sequencer divergence, then synchronization, but no outgoing native setter or mute reproduction. | [Calibration/result record](CROWN_CALIBRATION_2026-11-15.md); maintained Crown event probe and Watch media lab. The single-page private native variant is now covered by `--single-page` in the maintained native probe. |
| November 15: sparse Watch-local progress alternative | Actual finite player time advances with unchanged sparse metadata count. Legacy native UI can show the track/position, but Play state and later blanking prevent a dependable advancing progress reference; the separate new-session arm also lacks a working native reference. | Maintained Watch audio probe and timed observer; [measured results and limits](WATCH_LOCAL_MEDIA_2026-11-15.md). This is not a reproduction of the physical companion-progress freeze. |

## Source coverage and preservation

The November 15 bounded source inventory covered canonical `work/support/` and
the active worktree's ignored `work/`. It did not traverse build products,
expanded system archives or symlinks. Whole-app/integration/merge copies and
evidence attachment snapshots were classified as copies rather than standalone
tools; a copy's presence is not another runtime result. The private inventory
receipt is `work/diagnostic-tooling-inventory-2026-11-15.json` in that worktree.

The unique October 24 `.local`/KVO comparison is promoted because the new silent
player does not cover it. The promoted version adds MPL notices, default-paused
launch, `--autoplay`, a finite non-looping file, bounded playback and off-main
bounded journaling. Its source compiled with warnings as errors on November 15;
the old October 24 runtime result has not been rerun by that compilation.

The historical Safari server is also promoted as a clearly retired workflow:
silent by default, paused until Play, finite audio, explicit port and loopback
binding. Its source syntax and local HTTP/WAV/event routes were checked on
November 15 without browser/audio/device actions. Browser/Watch discovery has
not been rerun on current Simulator runtimes. Native phone playback is the
preferred controlled source for current companion-discovery attempts, while a
browser arm can still isolate source type. No distinct app/workflow source found
by this bounded inventory remains solely private; original incident copies stay
unchanged alongside their historical results.

Several private pixel/video extraction and exact-date replay helpers remain
analysis artifacts rather than app fixtures: for example the November 2
`analyze.swift`, `extract.swift` and `trace-replay.swift` variants. The maintained
timeline fixture records the input needed for replay, and the regression harness
has current pixel inspectors, but a general historical video-analysis workflow
has not been promoted or claimed equivalent. Preserve original inputs, source
hashes and output receipts when reusing those one-off analyses.

New results should identify the exact source/build, launch flags, OS/runtime,
control/page, route/provider, actual input receipt, and evidence collected before
recovery. Keep original evidence bytes when modernizing a fixture. A reusable
fault injector should state which values/callbacks it changes and require a
responsive uninjected reference before drawing conclusions about native input.
