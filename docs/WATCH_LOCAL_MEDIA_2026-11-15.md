# November 15: Watch-local native progress experiment

Question: can an actual Watch-local player provide a native progress reference
without the paired Simulator media-discovery path? Related: [progress #8](https://github.com/qayshp/TeachingTimer/issues/8)
and [paired media #6](https://github.com/qayshp/TeachingTimer/issues/6).

**Result:** local player time advances, and the legacy publisher can expose a
finite track and position ring in native Now Playing, including TeachingTimer.
It has not established a dependable, advancing native-progress reference.
Do not treat this as a reproduction of the physical companion progress freeze
or use it to declare that bug fixed. Physical comparison is still needed.

## Source and protocol

The maintained [Watch audio probe](../tools/watch-audio-probe/README.md) uses a
real `AVAudioPlayer`, a non-looping 180-second all-zero PCM WAV, async Watch audio
activation, per-process run IDs, and transition-only metadata. Its one-second
heartbeat samples actual player time; it does not republish elapsed time in the
sparse arm. A separate frequent-metadata arm deliberately republishes it.

The [observer](../tools/watch-audio-probe/observe.py) records native screenshots
beside current-run player samples, submission counts and timestamps. It fails
the player prerequisite on paused, stale, malformed, mixed-run or nonadvancing
actual positions. A moving monotonic estimate or device clock cannot pass it.
`playerGatePassed` is expressly not a native-UI result; frames need review.

Environment: selected Xcode 27.2 (27B52), Watch Simulator SDK/runtime 27.2
(24S118), SE 3 40 mm. No physical device was contacted. The Watch fixture
executable SHA-256 was
`fdb00a3797cbcf7afd1e177b1f96b058feb1f797793df85df3cdaa71b5f9f7d8`.
The development TeachingTimer host was build 61 from the unmerged volume-host
experiment, not an installed physical/TestFlight result.

## Timed observations

Each controlled arm used a fresh source process, initially seeking to 30 seconds.
The source remained actually playing at every captured sample, with at most
three-second-old samples; the observer terminated it after capture.

| Arm | Actual player positions | App metadata submissions | Native observation |
| --- | --- | --- | --- |
| Legacy, frequent metadata, fixture host, 30 s | 32.927 → 62.927 s | 5 → 35 | Initially track/title, Play triangle and position ring; final content black with system time/page dots. This is not evidence of sparse extrapolation. |
| New `MediaSession`, sparse, fixture host, 30 s | 32.922 → 62.922 s | Constant 2: initial paused seek, then Play | Initially Not Playing; later black content. Application-primary request succeeded, but system source selection was not established. |
| Legacy, sparse, TeachingTimer host, clean 20 s | 32.934 → 52.932 s | Constant 2 | Initially correct synthetic title and position ring, but Play triangle despite the actual player running. Later frames at 10 and 20 s show black content with system time/page dots. No dependable advancing reference. |

Earlier exploratory sparse playback also advanced for over 72 seconds with one
metadata submission; the native view later went black. A standalone Now Playing
comparison found the synthetic title, but did not establish continuously
advancing progress. Some subsequent exploratory captures were after playback
ended and cannot diagnose live progress. An initial 30-second TeachingTimer
capture overlapped the next fixture launch at its final frame; that frame showed
the other app and was discarded. The clean 20-second arm above had exclusive
Simulator input and replaces it.

The new publisher arm uses public `NowPlaying.MediaSession` on watchOS 27 and
does not mix legacy publishing/remote commands into that process. A successful
application-primary request is not proof of system-primary selection. The
legacy `MPNowPlayingInfoCenter.playbackState` property is documented for macOS;
setting it was not used as a speculative Watch fix. No inspected contract
establishes that silent PCM is excluded; that remains an untested hypothesis.

A focused native error query retained repeated `cannot add handler to 0 from 0
- dropping` messages and local output-context messages. These are diagnostic
observations, not an established cause of blanking or the physical progress
problem. Raw logs, frames, run manifests and exact source samples remain private
under the ignored `work/` directories named `watch-progress-*2026-11-15` and
`watch-progress-legacy-sparse-teaching-clean-20261115`.

## Repeat and regression boundaries

Build/install the fixture as documented, resolve a live booted regression Watch,
then use a new output directory for each arm:

```sh
python3 tools/watch-audio-probe/observe.py \
  --simulator "$WATCH_SIMULATOR_UUID" \
  --host teaching --seconds 20 --interval 5 \
  --output work/watch-progress-NEW --execute
```

Omit `--execute` for a plan only. Use `--host fixture` or `--host system` for
separate host comparisons; add either `--session-api` or `--frequent-metadata`
for an explicitly labelled publisher comparison. Keep one input owner, and do
not start another fixture while a timed observer is capturing.

Offline regression tests protect real-player evidence, source-run attribution,
sparse metadata invariance, new/private output guards, default no-device mode,
and cleanup after an ambiguous launch timeout. CI compiles the fixture and runs
those tests. It does not claim to test working paired media, native live progress
or audible physical output. Establish a valid native playing/progress reference
before adding a visual freeze assertion. The [physical test plan](PHYSICAL_MEDIA_TEST_PLAN.md)
is the next useful path for the real defect; no TeachingTimer scheduling,
volume-focus or media implementation was changed by these experiments.
