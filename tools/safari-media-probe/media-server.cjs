#!/usr/bin/env node
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Retired October 22 Safari/HTML Media Session diagnostic, made finite/opt-in.
'use strict';
const http = require('node:http');

function makeWave(audible) {
  const rate = 22050, frames = rate * 120;
  const wav = Buffer.alloc(44 + frames * 2);
  wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28);
  wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34); wav.write('data', 36);
  wav.writeUInt32LE(frames * 2, 40);
  if (audible) {
    for (let i = 0; i < frames; i++) {
      const envelope = Math.min(1, i / rate, (frames - i) / rate);
      wav.writeInt16LE(Math.round(Math.sin(i * 2 * Math.PI * 220 / rate)
        * 32767 * 0.015 * envelope), 44 + i * 2);
    }
  }
  return wav;
}

function page(audible) {
  return `<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Retired Safari media probe</title>
<style>body{font:20px system-ui;padding:24px}button{font:inherit;padding:16px;margin:12px 0}pre{white-space:pre-wrap;font-size:15px}</style>
<h1>Safari Media Session probe</h1>
<p>Retired diagnostic workflow. ${audible ? 'Explicit audible mode: quiet 220-Hz tone.' : 'Silent PCM; no audible sample.'}
Finite 120-second file, paused until Play. No account or external service.</p>
<audio id="audio" src="/tone.wav" controls preload="metadata"></audio><br>
<button id="play">Play</button><button id="stop">Pause</button><pre id="status"></pre>
<script>
const audio = document.getElementById('audio');
function state(event) {
  const value = {event, time: audio.currentTime, duration: Number.isFinite(audio.duration) ? audio.duration : null,
    paused: audio.paused, ended: audio.ended, volume: audio.volume, muted: audio.muted,
    mediaSession: !!navigator.mediaSession, pageWallMilliseconds: Date.now()};
  document.getElementById('status').textContent = JSON.stringify(value, null, 2);
  fetch('/event', {method: 'POST', body: JSON.stringify(value)}).catch(() => {});
}
document.getElementById('play').onclick = () => audio.play().then(() => state('play-button')).catch(error => state(String(error)));
document.getElementById('stop').onclick = () => audio.pause();
if (navigator.mediaSession) {
  navigator.mediaSession.metadata = new MediaMetadata({title: 'TeachingTimer test tone',
    artist: 'Local Simulator probe', album: '${audible ? 'Explicit quiet tone' : 'Silent PCM'}'});
  for (const action of ['play', 'pause', 'nexttrack', 'previoustrack']) {
    try {
      navigator.mediaSession.setActionHandler(action, () => {
        state('remote-' + action);
        if (action === 'pause') audio.pause();
        else if (action === 'play') audio.play().catch(error => state(String(error)));
        else audio.currentTime = 0;
      });
    } catch (error) { state('unsupported-' + action); }
  }
}
audio.onplay = () => { if (navigator.mediaSession) navigator.mediaSession.playbackState = 'playing'; state('play'); };
audio.onpause = () => { if (navigator.mediaSession) navigator.mediaSession.playbackState = 'paused'; state('pause'); };
audio.onended = () => { if (navigator.mediaSession) navigator.mediaSession.playbackState = 'paused'; state('ended'); };
audio.onvolumechange = () => state('volumechange');
setInterval(() => state('tick'), 5000);
state('ready');
</script></html>`;
}

function createServer({audible = false, record = value => console.log(JSON.stringify(value))} = {}) {
  const wav = makeWave(audible), html = page(audible);
  return http.createServer((req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    if (req.url === '/event' && req.method === 'POST') {
      let data = '', length = 0;
      req.on('data', chunk => {
        length += chunk.length;
        if (length > 4096) { res.writeHead(413); res.end(); req.destroy(); }
        else data += chunk;
      });
      req.on('end', () => {
        if (length > 4096) return;
        try { record({receivedUTC: new Date().toISOString(), browser: JSON.parse(data)}); }
        catch { res.writeHead(400); res.end('Invalid event JSON'); return; }
        res.end('ok');
      });
      return;
    }
    if (req.method !== 'GET') { res.writeHead(405); res.end(); return; }
    if (req.url === '/tone.wav') {
      let start = 0, end = wav.length - 1;
      if (req.headers.range) {
        const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range);
        if (!range || !Number.isSafeInteger(Number(range[1])) ||
            (range[2] && !Number.isSafeInteger(Number(range[2])))) {
          res.writeHead(416, {'Content-Range': `bytes */${wav.length}`}); res.end(); return;
        }
        start = Number(range[1]); end = Math.min(end, range[2] ? Number(range[2]) : end);
        if (start > end) { res.writeHead(416, {'Content-Range': `bytes */${wav.length}`}); res.end(); return; }
        res.setHeader('Content-Range', `bytes ${start}-${end}/${wav.length}`);
      }
      res.writeHead(req.headers.range ? 206 : 200, {'Content-Type': 'audio/wav',
        'Content-Length': end - start + 1, 'Accept-Ranges': 'bytes'});
      res.end(wav.subarray(start, end + 1)); return;
    }
    if (req.url === '/') {
      res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'}); res.end(html); return;
    }
    res.writeHead(404); res.end();
  });
}

function main(args) {
  let port, audible = false;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--audible') audible = true;
    else if (args[i] === '--port' && args[i + 1] !== undefined && /^\d+$/.test(args[i + 1])) port = Number(args[++i]);
    else throw new Error('Usage: node media-server.cjs --port PORT [--audible]');
  }
  if (!Number.isInteger(port) || port < 0 || port > 65535) throw new Error('--port must be 0–65535 (0 selects an ephemeral port)');
  const server = createServer({audible});
  server.on('error', error => { console.error(error.message); process.exitCode = 1; });
  server.listen(port, '127.0.0.1', () => console.log(JSON.stringify({event: 'listening',
    address: '127.0.0.1', port: server.address().port, audible, durationSeconds: 120, autoplay: false, loop: false})));
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => server.close());
  return server;
}
module.exports = {createServer, makeWave, page, main};
if (require.main === module) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
