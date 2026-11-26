# Retired Safari Media Session probe

Preserves the distinct October 22, 2026 browser-source workflow from
`work/support/2026-10-22-paired-media/media-server.cjs` in the canonical checkout.
The maintained [native phone audio fixture](../phone-audio-probe/README.md) is
preferred for a controlled native-player baseline. This older arm can isolate
browser-versus-native source discovery; publication is not a current reproduction.
Original source SHA-256:
`d32b7426ee961cc9c135b9d6648f8919577f2366f4662fcf302859807b54651f`.

Only Node built-in modules are used. The server always binds to `127.0.0.1`,
requires an explicit port, and serves a self-contained HTML page and generated
120-second mono PCM WAV. No account, downloaded media, package installation,
external request, phone companion or browser/device automation is included.
The page starts paused and the audio never loops. PCM is **silent by default**:

```sh
node --check tools/safari-media-probe/media-server.cjs
python3 -m unittest discover -s Tests -p test_safari_media_probe.py -v
node tools/safari-media-probe/media-server.cjs --port 8765
```

Open `http://127.0.0.1:8765/` manually in the intended Simulator's Safari after
checking the live target. Press Play explicitly. `--audible` restores the old
quiet 220-Hz tone; use a quiet Mac output and stop after a bounded observation.
Sample amplitude is not an acoustic loudness measurement. Pause the page, verify
its stopped state, close it, then stop the server with Control-C. Stopping the
server alone may leave an already buffered file playing until its finite end.

The page preserves `navigator.mediaSession` metadata, playbackState and native
Play/Pause/Next/Previous handlers. Browser events, player time, paused/ended,
element volume/mute and page wall time appear on screen and are posted to the
loopback server's stdout with receipt UTC time. Save stdout in an ignored run
folder if needed. These are browser/host observations; browser `audio.volume`
does not measure phone system/AirPlay volume. Native phone media selection and
Watch discovery require separate system/UI evidence. No elapsed-position
republish is added here; the silent Watch fixture serves that progress question.

On October 22, iPhone Safari's player and independent system logs showed Playing
with the supplied metadata. TeachingTimer's embedded view and Apple's standalone
Watch Now Playing both remained Not Playing despite a configured Simulator pair.
That failed to establish usable companion media; it did not prove every
Simulator transport unsupported or reproduce the physical zero-volume fault.
See the [historical investigation](../../docs/PAIRED_SIMULATOR_MEDIA_TEST.md).

The original HTML looped its tone. This maintained derivative adds MPL notices,
explicit port selection, silent default, finite non-looping playback and strict
local routes/ranges. It was syntax checked and its loopback HTTP/WAV/event routes
were checked offline on November 15. No browser, Simulator, physical device or
playback was used by those checks, and current-runtime discovery remains untested.
The regression test runs in the lightweight Python tooling lane using Node. It
checks the real loopback CLI/routes and finite PCM; Safari-only changes do not
request Watch compilation or publishing. Node must be available for these checks.
