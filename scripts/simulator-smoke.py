#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Boot one disposable Watch, verify real launches and saved state, then remove it.

No Device Hub, UI automation, paired iPhone, physical device, or production test
hook is used. Screenshots are evidence for human review, not rendering assertions.
"""
import argparse
from datetime import datetime, timezone
import json
import platform
import plistlib
from pathlib import Path
import re
import shutil
import signal
import subprocess
import time
import uuid

BUNDLE = 'com.qayshp.TeachingTimer'
CLASS_KEY = 'teachingClassContext.v1'
INTENT_KEY = 'teachingRuntimeIntent.v1'
REFERENCE_DATE_OFFSET = 978307200


def version(value):
    parts = tuple(int(part) for part in value.split('.'))
    return parts + (0,) * max(0, 3 - len(parts))


def build_order(value):
    return tuple((1, int(part)) if part.isdigit() else (0, part)
                 for part in re.findall(r'\d+|\D+', value))


def select_watch(runtimes, minimum_os, architecture):
    """Use the newest available compatible runtime; prefer the smallest SE 3."""
    candidates = [r for r in runtimes if r.get('isAvailable')
                  and r.get('platform') == 'watchOS'
                  and version(r['version']) >= version(minimum_os)
                  and architecture in r.get('supportedArchitectures', [architecture])]
    if not candidates:
        raise RuntimeError('No available compatible Watch runtime; install one before running smoke checks')
    runtime = max(candidates, key=lambda r: (version(r['version']), build_order(r['buildversion'])))
    devices = [d for d in runtime.get('supportedDeviceTypes', [])
               if d.get('productFamily') == 'Apple Watch']
    if not devices:
        raise RuntimeError('Newest Watch runtime has no supported Watch device types; refusing older fallback')

    def preference(device):
        match = re.search(r'(\d+)mm', device['name'])
        return ('Watch SE 3 (40mm)' not in device['name'],
                int(match.group(1)) if match else 999, device['name'])
    return runtime, min(devices, key=preference)


def fixture(now):
    pressed = now - REFERENCE_DATE_OFFSET
    context = dict(initialStartPressedAt=pressed, scheduledStart=pressed, durationMinutes=60)
    intent = dict(classID=pressed, state='stopped')
    return {CLASS_KEY: json.dumps(context).encode(), INTENT_KEY: json.dumps(intent).encode()}


def read_events(container):
    path = container / 'Documents/RuntimeDiagnostics.json'
    try:
        events = json.loads(path.read_text())
        return events if isinstance(events, list) else []
    except (FileNotFoundError, json.JSONDecodeError):
        return []


def launch_evidence(events, seen, page):
    """Require one new process and matching lifecycle/page callbacks, not old data."""
    launches = [e['details']['launchID'] for e in events
                if e.get('event') == 'app_launched' and e.get('details', {}).get('launchID') not in seen]
    if len(launches) != 1:
        return None
    launch_id = launches[0]
    current = [e for e in events if e.get('details', {}).get('launchID') == launch_id]
    if any(e.get('event') in {'start_requested', 'runtime_started'} for e in current):
        raise AssertionError('Intentional Stop was not preserved: a runtime start was requested')
    restored = any(e.get('event') == 'runtime_intent_restored'
                   and e['details'].get('savedRuntimeIntent') == 'stopped' for e in current)
    appeared = any(e.get('event') == 'interface_appeared'
                   and e['details'].get('selectedPage') == page for e in current)
    page_appeared = any(e.get('event') == 'page_appeared'
                        and e['details'].get('observedPage') == page for e in current)
    return launch_id if restored and appeared and page_appeared else None


def assert_saved_state(container, expected):
    path = container / 'Library/Preferences' / (BUNDLE + '.plist')
    actual = plistlib.loads(path.read_bytes())
    for key, value in expected.items():
        if actual.get(key) != value:
            raise AssertionError('Saved class or intentional Stop changed: ' + key)


class Smoke:
    def __init__(self, app, output):
        self.app, self.output = app, output
        self.owned_device = None
        self.container = None
        self.started = time.monotonic()
        self.deadline = self.started + 480
        self.report = dict(complete=False, startedAt=datetime.now(timezone.utc).isoformat(), scope='Booted Watch app launch and seeded-state persistence',
                           physicalDevicesUsed=False, pairedMediaVerified=False,
                           renderingVerified=False, hapticsVerified=False, commands=[], launches=[])

    def save(self):
        (self.output / 'smoke.json').write_text(json.dumps(self.report, indent=2) + '\n')

    def command(self, *arguments, timeout=60, cleanup=False):
        if not cleanup:
            timeout = min(timeout, self.deadline - time.monotonic())
            if timeout <= 0:
                raise TimeoutError('Eight-minute smoke deadline exceeded')
        command = [str(a) for a in arguments]
        started = time.monotonic()
        log_name = f'{len(self.report["commands"]):02d}-{Path(command[0]).name}.log'
        record = dict(command=command, log=log_name)
        self.report['commands'].append(record)
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=False)
            (self.output / log_name).write_text(result.stdout + result.stderr)
            record['exitCode'] = result.returncode
            if result.returncode:
                raise RuntimeError(f'Command failed ({result.returncode}); see {log_name}: ' + ' '.join(command))
            return result.stdout.strip()
        except subprocess.TimeoutExpired as error:
            record['error'] = 'timeout'
            (self.output / log_name).write_bytes((error.stdout or b'') + (error.stderr or b''))
            raise
        finally:
            record['elapsedSeconds'] = round(time.monotonic() - started, 3)
            self.save()

    def simctl(self, *arguments, **options):
        return self.command('xcrun', 'simctl', *arguments, **options)

    def collect(self, label):
        if self.container:
            for source in (self.container / 'Documents').glob('*Diagnostics.json'):
                shutil.copyfile(source, self.output / f'{label}-{source.name}')
        if self.owned_device:
            self.simctl('io', self.owned_device, 'screenshot', self.output / f'{label}.png', timeout=20)

    def cleanup(self):
        if not self.owned_device:
            return
        # The only removable ID is returned by our successful create operation.
        # Never use "all", an existing device, or a caller-provided identifier.
        errors = []
        for operation in ('shutdown', 'delete'):
            try:
                self.simctl(operation, self.owned_device, timeout=30, cleanup=True)
            except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
                errors.append(str(error))
        self.report['cleanup'] = dict(device=self.owned_device, errors=errors)
        if errors:
            self.report['complete'] = False
        self.save()

    def run(self):
        info = plistlib.loads((self.app / 'Info.plist').read_bytes())
        if info.get('CFBundleIdentifier') != BUNDLE or 'WatchSimulator' not in info.get('CFBundleSupportedPlatforms', []):
            raise ValueError('Requires a development TeachingTimer Watch Simulator artifact')
        self.command('codesign', '--verify', self.app)
        self.report['xcode'] = self.command('xcodebuild', '-version')
        self.report['developerDirectory'] = self.command('xcode-select', '-p')
        self.report['build'] = info['CFBundleVersion']
        metadata = self.app / 'BuildInfo.plist'
        if metadata.exists():
            self.report['buildMetadata'] = plistlib.loads(metadata.read_bytes())
        runtimes = json.loads(self.simctl('list', 'runtimes', '--json'))['runtimes']
        runtime, device = select_watch(runtimes, info.get('MinimumOSVersion', '26.0'), platform.machine())
        self.report['runtime'] = {key: runtime[key] for key in ('identifier', 'version', 'buildversion')}
        self.report['deviceType'] = device['identifier']
        name = 'TeachingTimer CI Smoke ' + str(uuid.uuid4())[:8]
        created = self.simctl('create', name, device['identifier'], runtime['identifier'])
        self.owned_device = str(uuid.UUID(created))
        self.report['createdDevice'] = self.owned_device
        self.save()
        self.simctl('boot', self.owned_device, timeout=60)
        self.simctl('bootstatus', self.owned_device, '-b', timeout=180)
        self.simctl('install', self.owned_device, self.app, timeout=90)
        self.container = Path(self.simctl('get_app_container', self.owned_device, BUNDLE, 'data'))
        preferences = self.container / 'Library/Preferences' / (BUNDLE + '.plist')
        preferences.parent.mkdir(parents=True, exist_ok=True)
        expected = fixture(time.time())
        # Only this newly installed, never-launched container receives a fixture.
        preferences.write_bytes(plistlib.dumps(expected))
        (self.output / 'seed.json').write_text(json.dumps({k: json.loads(v) for k, v in expected.items()}, indent=2))
        seen = set()
        for label, page, arguments in [('timer', 'classProgress', []),
                                       ('media', 'nowPlaying', ['--show-now-playing']),
                                       ('timer-reopened', 'classProgress', [])]:
            self.simctl('launch', self.owned_device, BUNDLE, *arguments)
            deadline = min(self.deadline, time.monotonic() + 40)
            while True:
                events = read_events(self.container)
                launch_id = launch_evidence(events, seen, page)
                if launch_id:
                    break
                if time.monotonic() >= deadline:
                    raise TimeoutError(f'No complete new {label} launch evidence within 40 seconds')
                time.sleep(.25)
            assert_saved_state(self.container, expected)
            # Appearance callbacks can precede the first composited frame. This
            # bounded settling delay improves evidence; it is not a pixel assertion.
            time.sleep(1)
            self.collect(label)
            self.report['launches'].append(dict(label=label, launchID=launch_id, selectedPage=page,
                                                classUnchanged=True, intentionalStopPreserved=True))
            seen.add(launch_id)
            self.save()
            self.simctl('terminate', self.owned_device, BUNDLE)
        self.report['complete'] = True
        self.save()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path, help='New evidence directory; never overwrites')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    smoke = Smoke(args.app.resolve(), output)

    def interrupted(_signum, _frame):
        raise InterruptedError('Smoke interrupted; cleaning up its disposable simulator')

    signal.signal(signal.SIGTERM, interrupted)
    try:
        smoke.run()
    except (OSError, ValueError, AssertionError, RuntimeError, subprocess.TimeoutExpired) as error:
        smoke.report['error'] = str(error)
        try:
            smoke.collect('failure')
        except (OSError, RuntimeError, subprocess.TimeoutExpired) as capture_error:
            smoke.report['captureError'] = str(capture_error)
        if smoke.owned_device:
            try:
                smoke.simctl('spawn', smoke.owned_device, 'log', 'show', '--last', '2m', '--style', 'compact',
                             '--predicate', 'process == "TeachingTimer"', timeout=20, cleanup=True)
            except (OSError, RuntimeError, subprocess.TimeoutExpired) as log_error:
                smoke.report['systemLogError'] = str(log_error)
    finally:
        smoke.cleanup()
        smoke.report['finishedAt'] = datetime.now(timezone.utc).isoformat()
        smoke.report['elapsedSeconds'] = round(time.monotonic() - smoke.started, 3)
        smoke.save()
    print(json.dumps(smoke.report, indent=2))
    return 0 if smoke.report['complete'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
