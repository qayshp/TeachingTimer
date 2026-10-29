#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Run existing disposable-Watch regressions serially and retain a complete manifest.

Never boots or creates simulators and never contacts physical devices. Device Hub
must already be open. --reset-test-app explicitly discards the selected simulator's
TeachingTimer data. Only one suite may drive Device Hub at a time.
"""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
from datetime import datetime, timezone
import json
import os
import plistlib
from pathlib import Path
import signal
import subprocess
import sys
import time
import tempfile

HERE = Path(__file__).resolve().parent
ACTIONS = {
    'cancel-new-keeps-no-class', 'default-sixty-started', 'count-started',
    'count-cancelled', 'stop-keeps-class', 'resume-keeps-class',
    'cancel-edit-keeps-schedule', 'save-edits-only-schedule',
    'new-class-replaces-anchor', 'active-class-media-navigation',
    'active-class-timer-return', 'end-clears-class', 'media-navigation',
    'timer-return-keeps-class',
}
LIFECYCLE = {'sameHostPID', 'sameClassBytes', 'noNewVolumeControl',
             'mediaPageSelected', 'automaticMediaRefreshRequested'}


@contextmanager
def simulator_lock(path=None):
    """Device Hub has one input stream; another suite must fail before any tap."""
    path = path or Path(tempfile.gettempdir()) / f'TeachingTimerSimulatorSuite-{os.getuid()}.lock'
    descriptor = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another Simulator suite is using Device Hub; wait for it to finish') from None
        yield
    finally:
        os.close(descriptor)


def artifact_identity(app):
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    metadata_path = app / 'BuildInfo.plist'
    metadata = plistlib.loads(metadata_path.read_bytes()) if metadata_path.is_file() else {}
    executable = app / info['CFBundleExecutable']
    digest = hashlib.sha256()
    with executable.open('rb') as binary:
        for block in iter(lambda: binary.read(1024 * 1024), b''):
            digest.update(block)
    return dict(bundle=info.get('CFBundleIdentifier'), version=info.get('CFBundleShortVersionString'),
                build=info.get('CFBundleVersion'), platforms=info.get('CFBundleSupportedPlatforms'),
                sourceMetadata=metadata, executableSHA256=digest.hexdigest())


def evidence_errors(stage, evidence, folder):
    """Process exit alone is insufficient; require the runner's expected assertions."""
    errors = []
    if not isinstance(evidence, dict):
        return ['result.json must be an object']
    if stage == 'actions':
        passed = evidence.get('passed', [])
        if not isinstance(passed, list) or any(not isinstance(p, str) for p in passed):
            return ['passed must be a list of assertion names']
        if evidence.get('complete') is not True or set(passed) != ACTIONS or len(passed) != len(ACTIONS):
            errors.append('essential actions incomplete or unexpected')
        for label in ACTIONS:
            if not (folder / ('PASS-' + label + '.png')).is_file():
                errors.append('missing capture: ' + label)
    elif stage in {'focus', 'media'}:
        expected = LIFECYCLE | ({'manualRefreshRequested'} if stage == 'focus' else set())
        checks = evidence.get('checks', {})
        if not isinstance(checks, dict) or set(checks) != expected or any(v is not True for v in checks.values()):
            errors.append('lifecycle assertions incomplete or false')
        if not (folder / ('07-return-crown.png' if stage == 'focus' else '07-final.png')).is_file():
            errors.append('missing final lifecycle capture')
    elif stage == 'controls':
        if (evidence.get('frames', 0) != 33 or evidence.get('fullCountCompleted') is not True
                or evidence.get('lockedCountEvidence', {}).get('verified') is not True
                or not (folder / 'frames.json').is_file()
                or not (folder / 'full-count-locked-finish.png').is_file()):
            errors.append('control capture sequence incomplete')
    else:
        errors.append('unknown stage')
    return errors


def stage_plan(lifecycle, controls):
    # Actions leaves no class/count and the timer selected, satisfying the
    # focus/media setup contract. Do not chain focus into media: focus leaves
    # a count running, and the next runner's tap would cancel it.
    stages = [('actions', 'actions.py', ['--reset-test-app'])]
    if lifecycle != 'none':
        flags = ['--scenario', lifecycle]
        if lifecycle == 'media':
            flags += ['--allow-service-termination']
        stages.append((lifecycle, 'run.py', flags))
    if controls:
        stages.append(('controls', 'timer_controls.py', ['--reset-test-app']))
    return stages


def execute(command, log_path, timeout):
    with log_path.open('wb') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            return process.wait(timeout=timeout)
        except BaseException:
            # A timed-out/interrupted driver must not keep tapping Device Hub.
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            raise


def run_suite(simulator, app, output, lifecycle='none', controls=False, timeout=600,
              execute_command=execute):
    output.mkdir(parents=True, exist_ok=False)
    report = dict(simulator=simulator, app=str(app), startedAt=datetime.now(timezone.utc).isoformat(),
                  complete=False, stages=[], visualReview='required',
                  physicalWatchAndPhoneAudio='unverified', physicalDeviceContact=False)
    def save():
        (output / 'suite.json').write_text(json.dumps(report, indent=2) + '\n')
    save()
    try:
        report['artifact'] = artifact_identity(app)
        save()
        for stage, script, flags in stage_plan(lifecycle, controls):
            destination = output / stage
            command = [sys.executable, str(HERE / script), '--simulator', simulator,
                       '--app', str(app), '--output', str(destination), *flags]
            record = dict(stage=stage, command=command, status='running')
            report['stages'].append(record)
            save()
            started = time.monotonic()
            try:
                code = execute_command(command, output / (stage + '.log'), timeout)
                record['exitCode'] = code
                if code != 0:
                    raise RuntimeError('runner exited unsuccessfully')
                evidence = json.loads((destination / 'result.json').read_text())
                errors = evidence_errors(stage, evidence, destination)
                if errors:
                    record['evidenceErrors'] = errors
                    raise RuntimeError('runner evidence incomplete')
                record['status'] = 'passed'
            except Exception as error:
                record.update(status='failed', error=f'{type(error).__name__}: {error}')
                return False
            finally:
                record['elapsedSeconds'] = round(time.monotonic() - started, 3)
                save()
        report['complete'] = True
        return True
    finally:
        save()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True, help='Booted disposable TeachingTimer Regression UUID')
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--reset-test-app', required=True, action='store_true')
    parser.add_argument('--lifecycle', choices=['none', 'focus', 'media'], default='none',
                        help='Optional SE 3-only lifecycle sequence; media terminates its native view service')
    parser.add_argument('--allow-service-termination', action='store_true')
    parser.add_argument('--controls', action='store_true', help='Also capture count/Lock controls on SE 3 or Ultra')
    args = parser.parse_args()
    if args.lifecycle == 'media' and not args.allow_service_termination:
        parser.error('--lifecycle media requires --allow-service-termination')
    # Validate every requested stage before any test data can be reset.
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '--json'], text=True, timeout=30))
    selected = [d for group in devices['devices'].values() for d in group if d['udid'] == args.simulator]
    if len(selected) != 1 or selected[0]['state'] != 'Booted' or not selected[0]['name'].startswith('TeachingTimer Regression'):
        parser.error('Requires an already booted disposable TeachingTimer Regression simulator')
    kind = selected[0].get('deviceTypeIdentifier', '')
    if 'Apple-Watch-' not in kind or (args.lifecycle != 'none' and not kind.endswith('Apple-Watch-SE-3-40mm')):
        parser.error('Essential actions require Watch; optional lifecycle requires SE 3 40 mm')
    if args.controls and not kind.endswith(('Apple-Watch-SE-3-40mm', 'Apple-Watch-Ultra-4-49mm')):
        parser.error('Control captures support SE 3 40 mm and Ultra 4 49 mm')
    os.umask(0o077)
    success = run_suite(args.simulator, args.app.resolve(), args.output.resolve(), args.lifecycle, args.controls)
    print(('PASS: assertions complete; screenshots still need review. ' if success else 'FAILED: see suite manifest/logs. ') + str(args.output))
    raise SystemExit(0 if success else 2)


if __name__ == '__main__':
    try:
        with simulator_lock():
            main()
    except RuntimeError as error:
        raise SystemExit(str(error))
