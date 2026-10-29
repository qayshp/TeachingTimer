#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Run build/archive checks and preserve logs/metadata even when a step fails."""
import argparse
from datetime import datetime, timezone
import json
import os
import signal
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def run_step(name, command, output, timeout=1200):
    started = time.monotonic()
    record = {'name': name, 'command': command, 'startedAt': datetime.now(timezone.utc).isoformat()}
    with (output / (name + '.log')).open('wb') as log:
        try:
            process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                # Stop the entire build process group, not just the parent shell.
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                raise
            record['exitCode'] = code
            record['status'] = 'passed' if code == 0 else 'failed'
        except (OSError, subprocess.TimeoutExpired) as error:
            record.update(status='failed', error=type(error).__name__)
    record['elapsedSeconds'] = round(time.monotonic() - started, 3)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path, help='New artifact directory; never overwrites')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip())
    report = {'revision': revision, 'sourceDirty': dirty, 'distributionSigned': False, 'simulatorSigning': 'ad-hoc', 'uploaded': False, 'installed': False,
              'scope': 'Unsigned structural/build checks, not distribution approval or device validation', 'steps': []}
    steps = [
        ('xcode', ['xcodebuild', '-version']),
        ('developer-directory', ['xcode-select', '-p']),
        ('sdks', ['xcodebuild', '-showsdks']),
        ('swift', ['xcrun', 'swift', '--version']),
        ('repository', ['python3', 'scripts/check-repository.py']),
        ('models', ['sh', 'scripts/check.sh']),
        ('tools', ['sh', 'scripts/check-tools.sh']),
        ('simulator', ['xcodebuild', '-project', 'TeachingTimer.xcodeproj', '-scheme', 'TeachingTimer',
                       '-configuration', 'Debug', '-sdk', 'watchsimulator', '-derivedDataPath', str(output / 'DerivedData'),
                       '-resultBundlePath', str(output / 'Simulator.xcresult'), 'CODE_SIGN_IDENTITY=-', 'DEVELOPMENT_TEAM=', 'build']),
        ('archive', ['sh', 'scripts/check-archive.sh', str(output / 'development-archive')]),
        ('distribution-rehearsal', ['sh', 'scripts/prepare-testflight.sh', str(output / 'distribution-archive')]),
    ]
    try:
        for name, command in steps:
            print('Running ' + name, flush=True)
            result = run_step(name, command, output)
            report['steps'].append(result)
            (output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
            if result['status'] != 'passed':
                raise SystemExit('Failed ' + name + '; see ' + str(output / (name + '.log')))
    finally:
        report['complete'] = len(report['steps']) == len(steps) and all(s['status'] == 'passed' for s in report['steps'])
        (output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print('All build and unsigned archive checks passed. Artifacts: ' + str(output))

if __name__ == '__main__':
    main()
