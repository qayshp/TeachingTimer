#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Capture timer controls across count/Lock transitions on disposable simulators.

OCR warnings require frame review: foreground hands can obscure text. No pixel,
audio or focus success is inferred from a journal event. Resets only the test app.
"""
import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import plistlib
import subprocess
import time
from actions import choose_text
from ocr import readable_text, recognize_text
from count_evidence import locked_count_evidence
from run import checked, events_after, reset_test_app

BUNDLE = 'com.qayshp.TeachingTimer'


def luminance_observation(runtime, interface, launch_id):
    """Latest explicit interface state for this launch, not a tap/scene guess.

    Initial appearance is in the operational journal; transitions are in the
    interface journal. Their ISO timestamps have only one-second resolution,
    so order by the shared launch's monotonic elapsed field instead.
    """
    appearances = [e for e in runtime if e.get('event') == 'interface_appeared']
    if not appearances or appearances[-1].get('details', {}).get('launchID') != launch_id:
        return None
    observations = []
    for journal, events in [('RuntimeDiagnostics', runtime), ('InterfaceDiagnostics', interface)]:
        for event in events:
            fields = event.get('details', {})
            if (fields.get('launchID') != launch_id or event.get('event') not in
                    {'interface_appeared', 'luminance_changed', 'scene_state_changed'}):
                continue
            if fields.get('luminanceReduced') not in {'true', 'false'}:
                continue
            try:
                elapsed = float(fields['launchElapsedSeconds'])
            except (KeyError, TypeError, ValueError):
                return None
            if not math.isfinite(elapsed) or elapsed < 0:
                return None
            observations.append(dict(journal=journal, event=event['event'],
                timestamp=event.get('timestamp'), launchID=launch_id,
                launchElapsedSeconds=elapsed, luminanceReduced=fields['luminanceReduced'] == 'true'))
    if not observations:
        return None
    elapsed = max(e['launchElapsedSeconds'] for e in observations)
    latest = [e for e in observations if e['launchElapsedSeconds'] == elapsed]
    if len({e['luminanceReduced'] for e in latest}) != 1:
        return None
    return latest[-1]


def ensure_luminance(reduced, read_journals, toggle, launch_id, *, timeout=8,
                     monotonic=time.monotonic, sleep=time.sleep, report=None):
    """Confirm journal state, issuing at most one Controls→Lock toggle if needed.

    Missing or foreign-launch evidence never licenses a blind toggle. After a
    toggle, only a newer desired observation can confirm it. This establishes
    reported interface state, not pixel rendering or continuous visibility.
    """
    if not launch_id or not 0 < timeout <= 15:
        raise ValueError('A current launch and a bounded 0–15 second timeout are required')
    report = report if report is not None else {}
    report.update(requestedReducedLuminance=reduced, launchID=launch_id,
                  status='waiting_for_observation', toggleCount=0)
    deadline = monotonic() + timeout
    before = None
    while True:
        observed = luminance_observation(*read_journals(), launch_id)
        report['lastObservation'] = observed
        if observed:
            if before is None:
                before = observed
                report['before'] = before
                if observed['luminanceReduced'] == reduced:
                    report.update(status='already_observed', after=observed)
                    return report
                report.update(status='toggle_requested', toggleCount=1)
                try:
                    toggle()
                except Exception as error:
                    report.update(status='failed', error=f'Toggle failed: {error}')
                    raise
            elif (observed['launchElapsedSeconds'] > before['launchElapsedSeconds']
                  and observed['luminanceReduced'] == reduced):
                report.update(status='confirmed_transition', after=observed)
                return report
        remaining = deadline - monotonic()
        if remaining <= 0:
            reason = ('No current-launch luminance observation' if before is None
                      else 'No newer desired luminance observation after one toggle')
            report.update(status='failed', error=reason)
            raise RuntimeError(reason)
        sleep(min(.2, remaining))


def missing_labels(rows, counting):
    readable = [r for r in rows if readable_text(r)]
    missing = []
    # The upper-left control is icon-only. Its visibility needs human frame
    # review; opening it is exercised separately by the action suite.
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
    reset_test_app(args.simulator, BUNDLE)
    checked('xcrun', 'simctl', 'install', args.simulator, args.app.resolve())
    checked('xcrun', 'simctl', 'launch', args.simulator, BUNDLE)
    time.sleep(2)
    ui('tap', .5, .5)
    container = Path(checked('xcrun', 'simctl', 'get_app_container', args.simulator, BUNDLE, 'data'))
    def events(name):
        path = container / 'Documents' / (name + '.json')
        return json.loads(path.read_text()) if path.exists() else []
    def wait_event(name, event, baseline=None):
        until = time.monotonic() + 20
        while not any(e['event'] == event for e in events_after(baseline or [], events(name))):
            if time.monotonic() > until:
                raise RuntimeError('Missing event ' + event)
            time.sleep(.2)
    def screenshot(name):
        file = out / (name + '.png')
        checked('xcrun', 'simctl', 'io', args.simulator, 'screenshot', file)
        return recognize_text(out / 'screen-text', file)
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
    runtime_start = [e for e in events('RuntimeDiagnostics') if e['event'] == 'runtime_started'][-1]
    launch_id = runtime_start['details']['launchID']
    transitions = []
    def display_state(reduced, stage):
        report = dict(requestedStage=stage, requestedAt=datetime.now(timezone.utc).isoformat())
        transitions.append(report)
        try:
            return ensure_luminance(reduced,
                lambda: (events('RuntimeDiagnostics'), events('InterfaceDiagnostics')),
                lambda: ui('lock'), launch_id, report=report)
        finally:
            (out / 'display-transitions.json').write_text(json.dumps(transitions, indent=2))
    def observed_state():
        return luminance_observation(events('RuntimeDiagnostics'), events('InterfaceDiagnostics'), launch_id)
    def capture_display(name, reduced):
        evidence = dict(requestedReducedLuminance=reduced, before=observed_state(),
                        reportedDisplayStateConfirmed=False)
        def save():
            (out / (name + '-display-state.json')).write_text(json.dumps(evidence, indent=2))
        save()
        if evidence['before'] is None or evidence['before']['luminanceReduced'] != reduced:
            raise RuntimeError('Requested display state not observed before ' + name)
        rows = screenshot(name)
        evidence['after'] = observed_state()
        evidence['reportedDisplayStateConfirmed'] = (evidence['after'] is not None
            and evidence['after']['luminanceReduced'] == reduced)
        save()
        if not evidence['reportedDisplayStateConfirmed']:
            raise RuntimeError('Reported display state changed during ' + name)
        return rows, evidence
    frames = []
    def sample(stage, counting, count, reduced=None):
        for index in range(count):
            name = f'{len(frames):03d}-{stage}'
            at = datetime.now(timezone.utc).isoformat()
            rows, display = capture_display(name, reduced) if reduced is not None else (screenshot(name), None)
            frames.append(dict(file=name+'.png', at=at, stage=stage,
                missing=missing_labels(rows, counting), text=rows,
                displayStateEvidence=display,
                outline=json.loads(checked(out / 'control-outline', out / (name + '.png')))))
            (out / 'frames.json').write_text(json.dumps(frames, indent=2))
            time.sleep(1)
    sample('ready', False, 3)
    for cycle in range(2):
        baseline = events('LandmarkDiagnostics')
        ui('tap', .5, .76)
        wait_event('LandmarkDiagnostics', 'landmark_started', baseline)
        sample(f'count-{cycle}', True, 6)
        display_state(True, f'locked-{cycle}')
        sample(f'locked-{cycle}', True, 4, reduced=True)
        display_state(False, f'awake-{cycle}')
        sample(f'awake-{cycle}', True, 3, reduced=False)
        baseline = events('LandmarkDiagnostics')
        ui('tap', .5, .76)
        wait_event('LandmarkDiagnostics', 'landmark_ended', baseline)
        sample(f'cancelled-{cycle}', False, 2)
    # Exercise a complete real-duration count while locked, distinct from the
    # cancellation captures. Submission logs do not establish tactile delivery.
    baseline = events('LandmarkDiagnostics')
    ui('tap', .5, .76)
    wait_event('LandmarkDiagnostics', 'landmark_started', baseline)
    starts = [e for e in events_after(baseline, events('LandmarkDiagnostics')) if e['event'] == 'landmark_started']
    if len(starts) != 1:
        raise RuntimeError('Expected one fresh full-count run')
    run_id = starts[0]['details']['runID']
    display_state(True, 'full-count-locked')
    until = time.monotonic() + 85
    completion = None
    while time.monotonic() < until:
        matching = [e for e in events_after(baseline, events('LandmarkDiagnostics'))
                    if e['event'] == 'landmark_ended' and e['details'].get('runID') == run_id]
        if matching:
            completion = matching[-1]
            break
        time.sleep(.5)
    capture_display('full-count-locked-finish', True)
    display_state(False, 'full-count-awake-finish')
    capture_display('full-count-awake-finish', False)
    if not completion or completion['details'].get('reason') != 'completed':
        raise RuntimeError('Locked count did not complete normally within bounded wait')
    configuration = starts[0]['details']
    expected_end = int(configuration['landmarkCount']) * (float(configuration['intervalSeconds']) + float(configuration['pulseSpacing']))
    if float(completion['details'].get('elapsedSeconds', 0)) < expected_end:
        raise RuntimeError('Count ended before its final pulse-group completion deadline')
    lock_evidence = locked_count_evidence(events('InterfaceDiagnostics'), starts[0], completion)
    (out / 'full-count-evidence.json').write_text(json.dumps(lock_evidence, indent=2))
    for name in ['RuntimeDiagnostics', 'InterfaceDiagnostics', 'LandmarkDiagnostics']:
        (out / (name + '.json')).write_text(json.dumps(events(name), indent=2))
    if not lock_evidence['verified']:
        raise RuntimeError('Count completed, but locked-state evidence was not confirmed; see full-count-evidence.json')
    result = dict(lockedCountEvidence=lock_evidence, build=info['CFBundleVersion'], deviceType=selected[0]['deviceTypeIdentifier'],
        fullCountCompleted=True, completion=completion, frames=len(frames), reviewWarnings=sum(bool(f['missing']) for f in frames),
        outlineWarnings=sum(f['outline']['review'] for f in frames),
        visualResult='REVIEW_FRAMES_REQUIRED', audioAndCrown='unverified')
    (out / 'result.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result))


if __name__ == '__main__':
    main()
