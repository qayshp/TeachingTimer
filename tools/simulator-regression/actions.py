#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Essential actions on a disposable booted Watch Simulator; resets only its test app.

Uses screenshot OCR where Device Hub does not expose app accessibility nodes.
Every action needs a persisted-state/event assertion; screenshots need human review.
"""
import argparse
import json
import os
from pathlib import Path
from datetime import datetime, timezone
import plistlib
import subprocess
import time
from run import checked, reset_test_app

BUNDLE = 'com.qayshp.TeachingTimer'
KEY = 'teachingClassContext.v1'


def choose_text(rows, alternatives, minimum_y=0.2):
    def normalized(text):
        parts = text.split(' ', 1)
        if len(parts) == 2 and parts[0] in {'Il', 'II', 'Ⅱ', '+', '▶', '✓', '×', '•'}:
            text = parts[1]
        return text.casefold()
    matches = [r for r in rows if normalized(r['text']) in {normalized(s) for s in alternatives}
               and minimum_y < r['y'] < 0.92 and r['confidence'] >= 0.7]
    if len(matches) > 1:
        raise ValueError('Ambiguous text target; inspect screenshot')
    return matches[0] if matches else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--reset-test-app', required=True, action='store_true')
    args = parser.parse_args()
    devices = json.loads(checked('xcrun', 'simctl', 'list', 'devices', '--json'))
    matches = [d for ds in devices['devices'].values() for d in ds if d['udid'] == args.simulator]
    if len(matches) != 1 or matches[0]['state'] != 'Booted' or not matches[0]['name'].startswith('TeachingTimer Regression') or 'Apple-Watch-' not in matches[0].get('deviceTypeIdentifier', ''):
        parser.error('Requires a booted disposable Watch named TeachingTimer Regression…')
    info = plistlib.loads((args.app / 'Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != BUNDLE or 'WatchSimulator' not in info.get('CFBundleSupportedPlatforms', []):
        parser.error('Requires development Watch Simulator app')
    if subprocess.run(['codesign', '--verify', str(args.app)], capture_output=True).returncode != 0:
        parser.error('Simulator runtime checks require a signed/ad-hoc-signed app, not an unsigned build')
    os.umask(0o077)
    args.output.mkdir(parents=True, exist_ok=False)
    output = args.output.resolve()
    for source, target in [('HubInput.swift', 'hub-input'), ('ScreenText.swift', 'screen-text')]:
        checked('swiftc', Path(__file__).with_name(source), '-o', output / target, timeout=60)
    pid = checked('pgrep', '-x', 'DeviceHub')
    if not pid.isdigit():
        raise RuntimeError('Expected one Device Hub')
    # Explicit opt-in above; an existing test class is deliberately discarded.
    reset_test_app(args.simulator, BUNDLE)
    checked('xcrun', 'simctl', 'install', args.simulator, args.app.resolve())
    checked('xcrun', 'simctl', 'launch', args.simulator, BUNDLE)
    time.sleep(2)
    container = Path(checked('xcrun', 'simctl', 'get_app_container', args.simulator, BUNDLE, 'data'))
    results, actions = [], []
    def ui(*values):
        actions.append({'at': datetime.now(timezone.utc).isoformat(), 'input': list(values)})
        (output / 'actions.json').write_text(json.dumps(actions, indent=2))
        checked(output / 'hub-input', pid, args.simulator, *values)
        time.sleep(1)
    def capture(label, recognize=False):
        path = output / (label + '.png')
        checked('xcrun', 'simctl', 'io', args.simulator, 'screenshot', path)
        rows = json.loads(checked(output / 'screen-text', path)) if recognize else []
        (output / (label + '-text.json')).write_text(json.dumps(rows, indent=2))
        for name in ('RuntimeDiagnostics', 'InterfaceDiagnostics', 'LandmarkDiagnostics'):
            source = container / 'Documents' / (name + '.json')
            if source.exists():
                (output / (label + '-' + name + '.json')).write_bytes(source.read_bytes())
        return rows
    def tap(label, *alternatives, scroll=False, minimum_y=0.2):
        for attempt in range(12 if scroll else 1):
            target = choose_text(capture(f'{len(actions):03d}-{label}-{attempt}', recognize=True), alternatives, minimum_y)
            if target:
                ui('tap', target['x'], target['y'])
                return
            if scroll and attempt < 11:
                ui('scroll', .5, .8, .5, .4)
        raise RuntimeError('Target not found: ' + label)
    def context():
        path = container / 'Library/Preferences' / (BUNDLE + '.plist')
        values = plistlib.loads(path.read_bytes()) if path.exists() else {}
        data = values.get(KEY)
        return json.loads(data) if data else None
    def events(name='RuntimeDiagnostics'):
        path = container / 'Documents' / (name + '.json')
        return json.loads(path.read_text()) if path.exists() else []
    def check(label, condition):
        deadline = time.monotonic() + 30
        while not condition():
            if time.monotonic() >= deadline:
                capture('FAILED-' + label)
                raise AssertionError(label)
            time.sleep(.2)
        results.append(label)
        capture('PASS-' + label)
        (output / 'result.json').write_text(json.dumps({'passed': results, 'complete': False}, indent=2))
    def event_since(name, offset, journal='RuntimeDiagnostics'):
        return any(e['event'] == name for e in events(journal)[offset:])
    def menu():
        ui('tap', .22, .12)
    def dismiss():
        ui('tap', .23, .13)
    ui('bounds')
    ui('tap', .5, .5)  # Wake a previously dimmed disposable simulator; no face action here.
    # A modified draft must not silently change the default class.
    ui('tap', .5, .76)
    tap('custom-draft', 'Custom', 'Custom schedule', scroll=True)
    tap('later-draft', '+15 min')
    dismiss()
    check('cancel-new-keeps-no-class', lambda: context() is None)
    ui('tap', .5, .76)
    tap('default-start', 'Start class')
    check('default-sixty-started', lambda: context() is not None and context()['durationMinutes'] == 60 and event_since('runtime_started', 0))
    original = context()
    offset = len(events('LandmarkDiagnostics'))
    ui('tap', .5, .76)
    check('count-started', lambda: event_since('landmark_started', offset, 'LandmarkDiagnostics'))
    ui('tap', .5, .76)
    check('count-cancelled', lambda: event_since('landmark_ended', offset, 'LandmarkDiagnostics') and context() == original)
    menu()
    offset = len(events())
    tap('stop-session', 'Stop', 'Stop session', scroll=True)
    check('stop-keeps-class', lambda: event_since('stop_requested', offset) and context() == original)
    offset = len(events())
    ui('tap', .78, .76)
    check('resume-keeps-class', lambda: event_since('runtime_started', offset) and context() == original)
    menu()
    tap('edit-cancel', 'Edit', 'Edit schedule', scroll=True)
    tap('later-cancel', '+15 min')
    dismiss()
    check('cancel-edit-keeps-schedule', lambda: context() == original)
    menu()
    tap('edit-save', 'Edit', 'Edit schedule', scroll=True)
    tap('later-save', '+15 min')
    tap('save', 'Save schedule', 'Save', scroll=True)
    check('save-edits-only-schedule', lambda: context() is not None and context()['scheduledStart'] == original['scheduledStart'] + 900 and context()['initialStartPressedAt'] == original['initialStartPressedAt'])
    edited = context()
    menu()
    tap('new-class', 'New class', '+ New class', scroll=True)
    tap('new-custom', 'Custom', 'Custom schedule', scroll=True)
    tap('earlier-new', '−15 min', '-15 min')
    tap('start-custom', 'Start class', scroll=True)
    # Confirmation alert: require the explicit destructive button, never title.
    tap('confirm-new', 'Start new', scroll=True)
    check('new-class-replaces-anchor', lambda: context() is not None and context()['initialStartPressedAt'] != edited['initialStartPressedAt'])
    new_class = context()
    offset = len(events())
    ui('swipe', .85, .55, .15, .55)
    check('active-class-media-navigation', lambda: context() == new_class and any(e['event'] == 'page_selection_changed' and e['details'].get('selectedPage') == 'nowPlaying' for e in events()[offset:]))
    ui('swipe', .15, .55, .85, .55)
    check('active-class-timer-return', lambda: context() == new_class and any(e['event'] == 'page_selection_changed' and e['details'].get('selectedPage') == 'classProgress' for e in events()[offset:]))
    menu()
    tap('end-class', 'End class', scroll=True)
    tap('confirm-end', 'End class', scroll=True, minimum_y=.45)
    check('end-clears-class', lambda: context() is None)
    offset = len(events())
    ui('swipe', .85, .55, .15, .55)
    check('media-navigation', lambda: any(e['event'] == 'page_selection_changed' and e['details'].get('selectedPage') == 'nowPlaying' for e in events()[offset:]))
    ui('swipe', .15, .55, .85, .55)
    check('timer-return-keeps-class', lambda: context() is None and any(e['event'] == 'page_selection_changed' and e['details'].get('selectedPage') == 'classProgress' for e in events()[offset:]))
    for name in ('RuntimeDiagnostics', 'InterfaceDiagnostics', 'LandmarkDiagnostics'):
        (output / (name + '.json')).write_text(json.dumps(events(name), indent=2))
    result = {'passed': results, 'complete': True, 'deviceType': matches[0]['deviceTypeIdentifier'], 'build': info['CFBundleVersion'], 'visualReview': 'required', 'phoneMediaAndHaptics': 'unverified'}
    (output / 'result.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
