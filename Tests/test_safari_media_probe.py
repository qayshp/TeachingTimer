# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Real Node/loopback checks; no browser, playback or device operations."""
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "tools/safari-media-probe/media-server.cjs"


class SafariMediaProbeChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.node = shutil.which("node")
        if not cls.node:
            raise RuntimeError("Node is required for the lightweight Safari probe checks")

    def test_source_syntax_and_cli_reject_unknown_bind_options(self):
        subprocess.run([self.node, "--check", str(SERVER)], check=True,
                       capture_output=True, text=True, timeout=10)
        for arguments in (["--host", "0.0.0.0"], ["--port", "65536"], []):
            with self.subTest(arguments=arguments):
                result = subprocess.run([self.node, str(SERVER), *arguments],
                                        capture_output=True, text=True, timeout=10)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('"event":"listening"', result.stdout)

    def test_real_loopback_media_and_event_routes(self):
        # Use the actual CLI entry point with an ephemeral loopback port. The
        # finally block closes its server; subprocess timeout bounds a regression.
        script = r"""
const assert = require('node:assert/strict');
const http = require('node:http');
const {main, makeWave, page} = require(process.argv[1]);
(async () => {
  const silent = makeWave(false), tone = makeWave(true);
  assert.equal(silent.toString('ascii', 0, 4), 'RIFF');
  assert.equal(silent.readUInt32LE(24), 22050);
  assert.equal(silent.readUInt16LE(22), 1);
  assert.equal(silent.readUInt16LE(34), 16);
  assert.equal(silent.readUInt32LE(40), 120 * 22050 * 2);
  assert(silent.subarray(44).every(value => value === 0));
  assert(tone.subarray(44).some(value => value !== 0));
  const audio = page(false).match(/<audio[^>]*>/)[0];
  assert(!/\b(?:loop|autoplay)\b/.test(audio));
  assert(page(false).includes('navigator.mediaSession.setActionHandler'));
  assert(page(false).includes('navigator.mediaSession.metadata'));
  const server = main(['--port', '0']);
  try {
    await new Promise((resolve, reject) => { server.once('listening', resolve); server.once('error', reject); });
    assert.equal(server.address().address, '127.0.0.1');
    const request = (path, method = 'GET', headers = {}, body = '') => new Promise((resolve, reject) => {
      const req = http.request({host: '127.0.0.1', port: server.address().port,
        path, method, headers, agent: false}, res => {
        const chunks = [];
        res.on('data', chunk => chunks.push(chunk));
        res.on('end', () => resolve({status: res.statusCode, headers: res.headers, data: Buffer.concat(chunks)}));
      });
      req.on('error', reject); req.end(body);
    });
    const index = await request('/');
    assert.equal(index.status, 200); assert.equal(index.data.toString(), page(false));
    const all = await request('/tone.wav');
    assert.equal(all.status, 200); assert.deepEqual(all.data, silent);
    assert.equal(Number(all.headers['content-length']), silent.length);
    const range = await request('/tone.wav', 'GET', {Range: 'bytes=0-43'});
    assert.equal(range.status, 206); assert.deepEqual(range.data, silent.subarray(0, 44));
    assert.equal(range.headers['content-range'], `bytes 0-43/${silent.length}`);
    for (const invalid of ['bytes=999999999-', 'bytes=20-10', 'bytes=0-1,4-5']) {
      assert.equal((await request('/tone.wav', 'GET', {Range: invalid})).status, 416);
    }
    assert.equal((await request('/event', 'POST', {}, JSON.stringify({event: 'test', paused: true}))).status, 200);
    assert.equal((await request('/event', 'POST', {}, 'not-json')).status, 400);
    assert.equal((await request('/missing')).status, 404);
    assert.equal((await request('/', 'PUT')).status, 405);
  } finally { await new Promise(resolve => server.close(resolve)); }
})().catch(error => { console.error(error); process.exitCode = 1; });
"""
        result = subprocess.run([self.node, "-e", script, str(SERVER)], check=True,
                                capture_output=True, text=True, timeout=15)
        self.assertIn('"address":"127.0.0.1"', result.stdout)
        self.assertIn('"autoplay":false,"loop":false', result.stdout)
        self.assertIn('"browser":{"event":"test","paused":true}', result.stdout)


if __name__ == "__main__":
    unittest.main()
