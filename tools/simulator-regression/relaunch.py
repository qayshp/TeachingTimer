#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Verify process-relaunch recovery and intentional Stop on an existing test class.

Run after suite.py --controls on a booted disposable SE 3/Ultra. Does not install,
reset or create a class. Leaves the test class intact and runtime intentionally
stopped. Screenshots remain visual evidence, not proof of audio or Crown focus.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import time
from actions import choose_text
from run import checked, events_after
from suite import artifact_identity, simulator_lock

BUNDLE = 'com.qayshp.TeachingTimer'
CLASS_KEY = 'teachingClassContext.v1'
INTENT_KEY = 'teachingRuntimeIntent.v1'


def restored_state(events, state):
    return any(e['event'] == 'runtime_intent_restored'
               and e.get('details', {}).get('savedRuntimeIntent') == state for e in events)


def running_recovery(events):
    launches = [e for e in events if e['event'] == 'app_launched']
    if len(launches) != 1:
        return False
    launch_id = launches[0].get('details', {}).get('launchID')
    same_launch = [e for e in events if e.get('details', {}).get('launchID') == launch_id]
    return bool(launch_id) and restored_state(same_launch, 'running') and any(e['event'] == 'runtime_started' for e in same_launch)


def stopped_recovery(events):
    launches = [e for e in events if e['event'] == 'app_launched']
    if len(launches) != 1:
        return False
    launch_id = launches[0].get('details', {}).get('launchID')
    same_launch = [e for e in events if e.get('details', {}).get('launchID') == launch_id]
    return (bool(launch_id) and restored_state(same_launch, 'stopped')
            and not any(e['event'] in {'start_requested', 'automatic_restart_attempt', 'runtime_started'} for e in events))


def awake_state(runtime_events, interface_events):
    """Require fresh scene/luminance evidence from this process, not native state alone."""
    launches = [e for e in runtime_events if e['event'] == 'app_launched']
    if not launches:
        return {'awake': False, 'reason': 'no_launch_evidence'}
    launch_id = launches[-1].get('details', {}).get('launchID')
    if not launch_id:
        return {'awake': False, 'reason': 'no_launch_identity'}
    observations = sorted((e for e in runtime_events + interface_events
                           if e.get('details', {}).get('launchID') == launch_id),
                          key=lambda e: float(e['details'].get('launchElapsedSeconds', -1)))
    scene, luminance = None, None
    for event in observations:
        detail = event['details']
        if event['event'] == 'scene_state_changed':
            scene = detail.get('sceneState')
        elif event['event'] == 'interface_appeared':
            scene = detail.get('scenePhase')
        if event['event'] in {'scene_state_changed', 'interface_appeared', 'luminance_changed'} and 'luminanceReduced' in detail:
            luminance = detail['luminanceReduced']
    return dict(awake=scene == 'active' and luminance == 'false', scene=scene,
                luminanceReduced=luminance, launchID=launch_id)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    devices = json.loads(checked('xcrun', 'simctl', 'list', 'devices', '--json'))
    selected = [d for group in devices['devices'].values() for d in group if d['udid'] == args.simulator]
    if (len(selected) != 1 or selected[0]['state'] != 'Booted'
            or not selected[0]['name'].startswith('TeachingTimer Regression')
            or not selected[0].get('deviceTypeIdentifier', '').endswith(('Apple-Watch-SE-3-40mm', 'Apple-Watch-Ultra-4-49mm'))):
        parser.error('Requires a booted disposable TeachingTimer Regression SE 3 or Ultra')
    container = Path(checked('xcrun', 'simctl', 'get_app_container', args.simulator, BUNDLE, 'data'))
    app = Path(checked('xcrun', 'simctl', 'get_app_container', args.simulator, BUNDLE, 'app'))
    def preferences():
        return plistlib.loads((container / 'Library/Preferences' / (BUNDLE + '.plist')).read_bytes())
    def events(name='RuntimeDiagnostics'):
        path = container / 'Documents' / (name + '.json')
        return json.loads(path.read_text()) if path.exists() else []
    original_class = preferences().get(CLASS_KEY)
    intent = json.loads(preferences().get(INTENT_KEY, b'{}'))
    if not original_class or intent.get('state') != 'running':
        parser.error('Requires an existing class with running intent; run suite.py --controls first')
    os.umask(0o077)
    args.output.mkdir(parents=True, exist_ok=False)
    output = args.output.resolve()
    report = dict(complete=False, artifact=artifact_identity(app), simulator=args.simulator,
                  checks={}, actions=[], stoppedObservationSeconds=3,
                  visualReview='required', physicalAudioAndCrown='unverified')
    def save():
        (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    save()
    try:
        for source, target in [('HubInput.swift', 'hub-input'), ('ScreenText.swift', 'screen-text')]:
            checked('swiftc', Path(__file__).with_name(source), '-o', output / target, timeout=60)
        pid = checked('pgrep', '-x', 'DeviceHub')
        if not pid.isdigit():
            raise RuntimeError('Expected one Device Hub')
        def ui(*values):
            report['actions'].append(dict(at=datetime.now(timezone.utc).isoformat(), input=list(values)))
            save()
            checked(output / 'hub-input', pid, args.simulator, *values)
            time.sleep(.8)
        def capture(label):
            path = output / (label + '.png')
            checked('xcrun', 'simctl', 'io', args.simulator, 'screenshot', path)
            for journal in ('RuntimeDiagnostics', 'InterfaceDiagnostics', 'LandmarkDiagnostics'):
                (output / (label + '-' + journal + '.json')).write_text(json.dumps(events(journal), indent=2))
            (output / (label + '-preferences.plist')).write_bytes(plistlib.dumps(preferences()))
            return json.loads(checked(output / 'screen-text', path))
        def wait_for(predicate, timeout=20):
            deadline = time.monotonic() + timeout
            while not predicate():
                if time.monotonic() >= deadline:
                    raise RuntimeError('Relaunch state did not satisfy expected assertion')
                time.sleep(.25)
        def ensure_awake(label):
            before = awake_state(events(), events('InterfaceDiagnostics'))
            report.setdefault('awakePreflights', []).append(dict(stage=label, before=before))
            save()
            if not before['awake']:
                ui('home')
                checked('xcrun', 'simctl', 'launch', args.simulator, BUNDLE)
                wait_for(lambda: awake_state(events(), events('InterfaceDiagnostics'))['awake'])
            after = awake_state(events(), events('InterfaceDiagnostics'))
            report['awakePreflights'][-1]['after'] = after
            capture(label + '-awake-preflight')
            save()
        def relaunch(label):
            ensure_awake(label)
            baseline = events()
            report['actions'].append(dict(at=datetime.now(timezone.utc).isoformat(), action=label))
            save()
            checked('xcrun', 'simctl', 'terminate', args.simulator, BUNDLE)
            checked('xcrun', 'simctl', 'launch', args.simulator, BUNDLE)
            return baseline
        ui('bounds')
        baseline = relaunch('relaunch-running')
        wait_for(lambda: running_recovery(events_after(baseline, events())))
        if preferences().get(CLASS_KEY) != original_class:
            raise RuntimeError('Class changed during running recovery')
        report['checks']['runningClassAutomaticallyRecovered'] = True
        capture('01-running-recovered')
        ui('tap', .22, .12)
        for attempt in range(12):
            rows = capture(f'stop-menu-{attempt}')
            target = choose_text(rows, ['Stop session', 'Stop'])
            if target:
                ui('tap', target['x'], target['y'])
                break
            ui('scroll', .5, .8, .5, .4)
        else:
            raise RuntimeError('Stop session action not found')
        # Wait for persistent intent before killing the process, not just a tap.
        wait_for(lambda: json.loads(preferences().get(INTENT_KEY, b'{}')).get('state') == 'stopped')
        baseline = relaunch('relaunch-intentionally-stopped')
        wait_for(lambda: restored_state(events_after(baseline, events()), 'stopped'))
        time.sleep(report['stoppedObservationSeconds'])
        fresh = events_after(baseline, events())
        if not stopped_recovery(fresh) or preferences().get(CLASS_KEY) != original_class:
            raise RuntimeError('Intentional Stop or saved class was not preserved')
        report['checks']['intentionalStopSurvivesRelaunch'] = True
        capture('02-intentional-stop-preserved')
        report['complete'] = True
    except Exception as error:
        # Preserve failed-state evidence too; do not convert native start
        # rejection into a successful awake-case assertion.
        for journal in ('RuntimeDiagnostics', 'InterfaceDiagnostics', 'LandmarkDiagnostics'):
            (output / ('failure-' + journal + '.json')).write_text(json.dumps(events(journal), indent=2))
        report['lastObservedDisplayState'] = awake_state(events(), events('InterfaceDiagnostics'))
        report['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        save()
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    with simulator_lock():
        main()
