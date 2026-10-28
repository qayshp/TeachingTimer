#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Capture timer controls across count/Lock transitions on disposable simulators.

OCR warnings require frame review: foreground hands can obscure text. No pixel,
audio or focus success is inferred from a journal event. Resets only the test app.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time
from actions import choose_text
from run import checked

BUNDLE = 'com.qayshp.TeachingTimer'


def missing_labels(rows, counting):
    readable = [r for r in rows if r['confidence'] >= .7]
    missing = []
    if not any('class' in r['text'].casefold() and r['y'] < .2 for r in readable):
        missing.append('Class')
    # Count/Stop are the deliberate narrow-layout fallbacks.
    expected = ['stop count', 'stop'] if counting else ['1-min count', 'count']
    if not any(r['text'].casefold() in expected and .55 < r['y'] < .93 for r in readable):
        missing.append('Stop count' if counting else '1-min count')
    return missing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--reset-test-app', required=True, action='store_true')
    args = parser.parse_args()
    devices = json.loads(checked('xcrun', 'simctl', 'list', 'devices', '--json'))
    selected = [d for ds in devices['devices'].values() for d in ds if d['udid'] == args.simulator]
    supported = {'com.apple.CoreSimulator.SimDeviceType.Apple-Watch-SE-3-40mm',
                 'com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-4-49mm'}
    if len(selected) != 1 or selected[0]['state'] != 'Booted' or not selected[0]['name'].startswith('TeachingTimer Regression') or selected[0].get('deviceTypeIdentifier') not in supported:
        parser.error('Requires a booted disposable TeachingTimer Regression SE 3 40 mm or Ultra 4 49 mm')
    info = plistlib.loads((args.app / 'Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != BUNDLE or 'WatchSimulator' not in info.get('CFBundleSupportedPlatforms', []):
        parser.error('Requires the development Watch Simulator app')
    if subprocess.run(['codesign', '--verify', str(args.app)], capture_output=True).returncode:
        parser.error('Requires an ad-hoc-signed Simulator app for runtime startup')
    os.umask(0o077)
    args.output.mkdir(parents=True, exist_ok=False)
    out = args.output.resolve()
    for source, target in [('HubInput.swift', 'hub-input'), ('ScreenText.swift', 'screen-text'),
                           ('ControlOutline.swift', 'control-outline')]:
        checked('swiftc', Path(__file__).with_name(source), '-o', out / target, timeout=60)
    pid = checked('pgrep', '-x', 'DeviceHub')
    if not pid.isdigit():
        raise RuntimeError('Expected one Device Hub')
    def ui(*values):
        checked(out / 'hub-input', pid, args.simulator, *values)
        time.sleep(1)
    ui('home')  # Leave any prior dimmed app before replacing the disposable copy.
    subprocess.run(['xcrun', 'simctl', 'uninstall', args.simulator, BUNDLE], capture_output=True)
    checked('xcrun', 'simctl', 'install', args.simulator, args.app.resolve())
    checked('xcrun', 'simctl', 'launch', args.simulator, BUNDLE)
    time.sleep(2)
    ui('tap', .5, .5)
    container = Path(checked('xcrun', 'simctl', 'get_app_container', args.simulator, BUNDLE, 'data'))
    def events(name):
        path = container / 'Documents' / (name + '.json')
        return json.loads(path.read_text()) if path.exists() else []
    def wait_event(name, event, offset=0):
        until = time.monotonic() + 20
        while not any(e['event'] == event for e in events(name)[offset:]):
            if time.monotonic() > until:
                raise RuntimeError('Missing event ' + event)
            time.sleep(.2)
    def screenshot(name):
        file = out / (name + '.png')
        checked('xcrun', 'simctl', 'io', args.simulator, 'screenshot', file)
        return json.loads(checked(out / 'screen-text', file))
    ui('tap', .5, .76)
    rows = screenshot('setup')
    if not any('Custom' in r['text'] for r in rows):
        ui('tap', .5, .76)
        rows = screenshot('setup-retry')
    target = choose_text(rows, ['Start class'])
    if not target or not any('Custom' in r['text'] for r in rows):
        raise RuntimeError('Start menu not recognized')
    ui('tap', target['x'], target['y'])
    wait_event('RuntimeDiagnostics', 'runtime_started')
    frames = []
    def sample(stage, counting, count):
        for index in range(count):
            name = f'{len(frames):03d}-{stage}'
            at = datetime.now(timezone.utc).isoformat()
            rows = screenshot(name)
            frames.append(dict(file=name+'.png', at=at, stage=stage,
                missing=missing_labels(rows, counting), text=rows,
                outline=json.loads(checked(out / 'control-outline', out / (name + '.png')))))
            (out / 'frames.json').write_text(json.dumps(frames, indent=2))
            time.sleep(1)
    sample('ready', False, 3)
    for cycle in range(2):
        offset = len(events('LandmarkDiagnostics'))
        ui('tap', .5, .76)
        wait_event('LandmarkDiagnostics', 'landmark_started', offset)
        sample(f'count-{cycle}', True, 6)
        ui('lock')
        sample(f'locked-{cycle}', True, 4)
        ui('tap', .5, .5)  # Wake without leaving the teaching face.
        sample(f'awake-{cycle}', True, 3)
        offset = len(events('LandmarkDiagnostics'))
        ui('tap', .5, .76)
        wait_event('LandmarkDiagnostics', 'landmark_ended', offset)
        sample(f'cancelled-{cycle}', False, 2)
    for name in ['RuntimeDiagnostics', 'InterfaceDiagnostics', 'LandmarkDiagnostics']:
        (out / (name + '.json')).write_text(json.dumps(events(name), indent=2))
    result = dict(build=info['CFBundleVersion'], deviceType=selected[0]['deviceTypeIdentifier'],
        frames=len(frames), reviewWarnings=sum(bool(f['missing']) for f in frames),
        outlineWarnings=sum(f['outline']['review'] for f in frames),
        visualResult='REVIEW_FRAMES_REQUIRED', audioAndCrown='unverified')
    (out / 'result.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result))


if __name__ == '__main__':
    main()
