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
from ocr import readable_text, recognize_text

BUNDLE = 'com.qayshp.TeachingTimer'
KEY = 'teachingClassContext.v1'
REFERENCE_DATE_OFFSET = 978307200

# One contract for the action runner's completion and the suite's evidence gate.
BASELINE_ACTIONS = frozenset({
    'cancel-new-keeps-no-class', 'default-sixty-started', 'count-started',
    'count-cancelled', 'stop-keeps-class', 'resume-keeps-class',
    'cancel-edit-keeps-schedule', 'save-edits-only-schedule',
    'settings-keeps-existing-class', 'new-class-replaces-anchor',
    'active-class-media-navigation', 'active-class-timer-return',
    'end-clears-class', 'media-navigation', 'timer-return-keeps-class',
} | {f'{phase}-{page}-keeps-state'
     for phase in ('before-class', 'during-class')
     for page in ('help', 'privacy', 'about')})


def baseline_complete(passed):
    return (isinstance(passed, list) and all(isinstance(p, str) for p in passed)
            and len(passed) == len(BASELINE_ACTIONS) and set(passed) == BASELINE_ACTIONS)


def retiring_preferences(now, delay=90):
    """Fresh stopped class fixture; Swift Codable Dates use the 2001 epoch."""
    if not 20 <= delay <= 90:
        raise ValueError('Retirement setup must remain bounded to 20–90 seconds')
    pressed = now - REFERENCE_DATE_OFFSET
    context = dict(initialStartPressedAt=pressed, scheduledStart=pressed - 90 * 60 + delay,
                   durationMinutes=60)
    intent = dict(classID=pressed, state='stopped')
    return {KEY: json.dumps(context).encode(), 'teachingRuntimeIntent.v1': json.dumps(intent).encode()}


def suggested_start(timestamp):
    minute = datetime.fromtimestamp(timestamp).minute
    offset = minute % 15
    return int(timestamp // 60) * 60 + (15 - offset if offset >= 13 else -offset) * 60


def choose_text(rows, alternatives, minimum_y=0.2):
    def normalized(text):
        # Exact observed SF Symbol/label readings on SE 3 and Ultra. Do not
        # strip arbitrary letters/numbers or fuzzy-match a destructive action.
        aliases = {'O Settings': 'Settings', 'O About': 'About',
                   '11 Stop session': 'Stop session', 'D Edit schedule': 'Edit schedule',
                   'O End class': 'End class'}
        if text in aliases:
            return aliases[text].casefold()
        parts = text.split(' ', 1)
        if len(parts) == 2 and parts[0] in {'Il', 'II', 'Ⅱ', '+', '▶', '✓', '×', '•'}:
            text = parts[1]
        return text.casefold()
    matches = [r for r in rows if normalized(r['text']) in {normalized(s) for s in alternatives}
               and minimum_y < r['y'] < 0.92 and readable_text(r)]
    if len(matches) > 1:
        raise ValueError('Ambiguous text target; inspect screenshot')
    return matches[0] if matches else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--reset-test-app', required=True, action='store_true')
    parser.add_argument('--retirement', action='store_true',
                        help='Instead of baseline actions, run three bounded retirement/editor cases; resets the test app for each')
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
    container = None
    if not args.retirement:
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
        rows = recognize_text(output / 'screen-text', path) if recognize else []
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
    def check(label, condition, timeout=30):
        deadline = time.monotonic() + timeout
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
        ui('tap', .15, .13)  # Center of the native leading Back/Done button.
    def finish(scenario):
        if scenario == 'baseline' and not baseline_complete(results):
            raise AssertionError('Baseline actions do not match the complete contract')
        for name in ('RuntimeDiagnostics', 'InterfaceDiagnostics', 'LandmarkDiagnostics'):
            (output / (name + '.json')).write_text(json.dumps(events(name), indent=2))
        result = {'passed': results, 'complete': True, 'scenario': scenario,
                  'deviceType': matches[0]['deviceTypeIdentifier'], 'build': info['CFBundleVersion'],
                  'visualReview': 'required', 'phoneMediaAndHaptics': 'unverified'}
        (output / 'result.json').write_text(json.dumps(result, indent=2))
        print(json.dumps(result, indent=2))
    def retirement_cases():
        def seed(label):
            nonlocal container
            reset_test_app(args.simulator, BUNDLE)
            checked('xcrun', 'simctl', 'install', args.simulator, args.app.resolve())
            container = Path(checked('xcrun', 'simctl', 'get_app_container', args.simulator, BUNDLE, 'data'))
            now = time.time()
            values = retiring_preferences(now)
            expected = json.loads(values[KEY])
            preferences = container / 'Library/Preferences' / (BUNDLE + '.plist')
            preferences.parent.mkdir(parents=True, exist_ok=True)
            # This new container has never launched the app. Do not edit live
            # preferences, change system time, or kill any preferences daemon.
            preferences.write_bytes(plistlib.dumps(values))
            (output / (label + '-seed.json')).write_text(json.dumps(expected, indent=2))
            checked('xcrun', 'simctl', 'launch', args.simulator, BUNDLE)
            time.sleep(2)
            ui('bounds')
            ui('tap', .5, .5)
            check(label + '-fixture-restored', lambda: context() == expected and
                  any(e['event'] == 'runtime_intent_restored' and e['details'].get('savedRuntimeIntent') == 'stopped'
                      for e in events()))
            return expected, now + 90
        def ready(label, original, deadline):
            if context() != original or deadline - time.time() < 3:
                capture('FAILED-' + label + '-setup-missed-deadline', recognize=True)
                raise AssertionError('Draft setup missed its fixed retirement deadline: ' + label)
            capture(label + '-ready-before-retirement', recognize=True)
        def retired(label, deadline):
            check(label + '-retired', lambda: context() is None and
                  any(e['event'] == 'stop_requested' and e['details'].get('source') == 'class_retired'
                      for e in events()), timeout=max(1, deadline - time.time() + 15))
            if any(e['event'] in {'start_requested', 'runtime_started'} for e in events()):
                raise AssertionError('Retirement unexpectedly started a session: ' + label)
        def require_setup(label):
            rows = capture(label + '-fresh-setup', recognize=True)
            text = ' '.join(r['text'] for r in rows).casefold()
            if 'previous class cleared' not in text or 'save schedule' in text or 'start class' not in text:
                raise AssertionError('Retired editor did not show fresh setup and notice: ' + label)

        original, deadline = seed('edit')
        menu()
        tap('retiring-edit', 'Edit', 'Edit schedule', scroll=True)
        tap('retiring-edit-later', '+15 min')
        ready('edit', original, deadline)
        retired('edit', deadline)
        require_setup('edit')
        # The old Save is gone. Only this explicit Start may establish new timing.
        tap('retirement-fresh-start', 'Start class', scroll=True)
        check('retired-edit-explicit-new-start', lambda: context() is not None and
              context()['initialStartPressedAt'] != original['initialStartPressedAt'] and
              context()['durationMinutes'] == 60)

        original, deadline = seed('settings')
        menu()
        tap('retiring-settings', 'Settings', scroll=True)
        ready('settings', original, deadline)
        retired('settings', deadline)
        rows = capture('settings-still-open', recognize=True)
        if not any(r['text'] == 'Settings' for r in rows):
            raise AssertionError('Retirement unexpectedly dismissed Settings')
        dismiss()
        require_setup('settings-return')
        check('retired-settings-return-keeps-no-class', lambda: context() is None)

        original, deadline = seed('new-draft')
        menu()
        before_new = time.time()
        tap('retiring-new-draft', 'New class', '+ New class', scroll=True)
        after_new = time.time()
        tap('retiring-custom-draft', 'Custom', 'Custom schedule', scroll=True)
        tap('retiring-new-later', '+15 min')
        ready('new-draft', original, deadline)
        retired('new-draft', deadline)
        rows = capture('custom-draft-preserved', recognize=True)
        text = ' '.join(r['text'] for r in rows).casefold()
        if 'scheduled start' not in text or 'previous class cleared' in text:
            raise AssertionError('Retirement discarded the independent custom-new editor')
        tap('retiring-custom-start', 'Start class', scroll=True)
        expected_starts = {suggested_start(t) + 900 - REFERENCE_DATE_OFFSET for t in (before_new, after_new)}
        check('retired-custom-draft-preserved', lambda: context() is not None and
              context()['initialStartPressedAt'] != original['initialStartPressedAt'] and
              context()['scheduledStart'] in expected_starts and context()['durationMinutes'] == 60)
        # Leave this disposable app with no class or count, just like baseline.
        menu()
        tap('retirement-end-class', 'End class', scroll=True)
        tap('retirement-confirm-end', 'End class', scroll=True, minimum_y=.45)
        check('retirement-cleanup-clears-class', lambda: context() is None)

    if args.retirement:
        retirement_cases()
        finish('retirement')
        return
    def information_pages(prefix, expected_class):
        # Read-only Settings destinations must render and return without changing
        # a draft, saved class, or intentional runtime state.
        offset = len(events())
        for page, text in [('Help', 'using teaching'), ('Privacy', 'your privacy'), ('About', 'version')]:
            tap(prefix + '-' + page.lower(), page, scroll=True)
            rows = capture(prefix + '-' + page.lower() + '-opened', recognize=True)
            rendered = ' '.join(row['text'] for row in rows).casefold()
            check(prefix + '-' + page.lower() + '-keeps-state',
                  lambda: text in rendered and context() == expected_class
                  and not event_since('stop_requested', offset)
                  and not event_since('start_requested', offset))
            dismiss()  # Native navigation Back returns to Settings, not the face.
            rows = capture(prefix + '-' + page.lower() + '-returned', recognize=True)
            if not any(row['text'] == 'Settings' for row in rows):
                raise AssertionError('Information page did not return to Settings')
    ui('bounds')
    ui('tap', .5, .5)  # Wake a previously dimmed disposable simulator; no face action here.
    # A modified draft must not silently change the default class.
    ui('tap', .5, .76)
    tap('settings-before-class', 'Settings', scroll=True)
    information_pages('before-class', None)
    dismiss()  # Back to the same new-class draft.
    tap('custom-draft', 'Custom', 'Custom schedule', scroll=True)
    tap('later-draft', '+15 min')
    dismiss()
    check('cancel-new-keeps-no-class', lambda: context() is None)
    ui('tap', .5, .76)
    tap('default-start', 'Start class')
    check('default-sixty-started', lambda: context() is not None and context()['durationMinutes'] == 60 and event_since('runtime_started', 0))
    original = context()
    menu()
    tap('settings-during-class', 'Settings', scroll=True)
    information_pages('during-class', original)
    dismiss()  # Settings → class summary.
    dismiss()  # Done → face.
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
    tap('settings-in-replacement-draft', 'Settings', scroll=True)
    dismiss()
    check('settings-keeps-existing-class', lambda: context() == edited)
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
    finish('baseline')

if __name__ == '__main__':
    main()
