#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Prepare the selected SDK's Watch runtime on an ephemeral GitHub-hosted Mac.

This is an explicit CI dependency step, never a local Xcode/platform repair.
It refuses local and self-hosted execution before invoking any tools.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SMOKE = runpy.run_path(str(ROOT / 'scripts/simulator-smoke.py'))
RUN_STEP = runpy.run_path(str(ROOT / 'scripts/verify-build.py'))['run_step']


def hosted_output(output, environment):
    if environment.get('GITHUB_ACTIONS') != 'true' or environment.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise ValueError('Runtime preparation is restricted to ephemeral GitHub-hosted runners')
    temporary = environment.get('RUNNER_TEMP')
    if not temporary or not output.resolve().is_relative_to(Path(temporary).resolve()):
        raise ValueError('Runtime preparation evidence must be under RUNNER_TEMP')


def matching_runtime(runtimes, sdk, architecture):
    candidates = [r for r in runtimes if SMOKE['version'](r['version']) == SMOKE['version'](sdk)]
    try:
        runtime, _ = SMOKE['select_watch'](candidates, sdk, architecture)
        return runtime
    except RuntimeError:
        return None


def prepare(execute, architecture):
    sdk = execute('sdk-version', ['xcodebuild', '-version', '-sdk', 'watchsimulator', 'SDKVersion'], 30).strip()
    if not re.fullmatch(r'\d+(?:\.\d+){1,2}', sdk):
        raise ValueError('Selected Watch Simulator SDK did not return a numeric version')
    before = json.loads(execute('runtimes-before', ['xcrun', 'simctl', 'list', 'runtimes', '--json'], 30))['runtimes']
    existing = matching_runtime(before, sdk, architecture)
    downloaded = existing is None
    if downloaded:
        variant = 'arm64' if architecture == 'arm64' else 'universal'
        execute('download-watch-runtime', ['xcodebuild', '-downloadPlatform', 'watchOS',
                '-buildVersion', sdk, '-architectureVariant', variant], 600)
        after = json.loads(execute('runtimes-after', ['xcrun', 'simctl', 'list', 'runtimes', '--json'], 30))['runtimes']
        existing = matching_runtime(after, sdk, architecture)
        if existing is None:
            raise RuntimeError('Download finished without an available matching Watch runtime; refusing to skip smoke')
    return dict(sdkVersion=sdk, downloaded=downloaded,
                runtime={key: existing[key] for key in ('identifier', 'version', 'buildversion')})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path, help='New evidence directory under RUNNER_TEMP')
    args = parser.parse_args()
    output = args.output.resolve()
    try:
        hosted_output(output, os.environ)
    except ValueError as error:
        parser.error(str(error))
    output.mkdir(parents=True, exist_ok=False)
    report = dict(complete=False, scope='GitHub-hosted runtime dependency only', commands=[])

    def save():
        (output / 'runtime-preparation.json').write_text(json.dumps(report, indent=2) + '\n')

    def execute(name, command, timeout):
        result = RUN_STEP(name, command, output, timeout=timeout)
        report['commands'].append(result)
        save()
        if result['status'] != 'passed':
            raise RuntimeError('Failed runtime preparation: ' + name + '; see ' + str(output / (name + '.log')))
        return (output / (name + '.log')).read_text()

    try:
        report['xcode'] = execute('xcode', ['xcodebuild', '-version'], 30).strip()
        report.update(prepare(execute, platform.machine()))
        report['complete'] = True
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        report['error'] = str(error)
    finally:
        save()
    print(json.dumps(report, indent=2))
    return 0 if report['complete'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
