#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Verify recovery, retirement and saved state on disposable small/large Watches.

No Device Hub, UI automation, paired iPhone, physical device, or production test
hook is used. Screenshots are evidence for human review, not rendering assertions.
"""
import argparse
from datetime import datetime, timezone
import json
import math
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


def select_watch(runtimes, minimum_os, architecture, size='small'):
    """Use the newest compatible runtime and a real minimum/maximum screen size."""
    if size not in {'small', 'large'}:
        raise ValueError('Watch size must be small or large')
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

    def millimeters(device):
        match = re.search(r'(\d+)mm', device['name'])
        if not match:
            raise RuntimeError('Cannot determine Watch screen size: ' + device['name'])
        return int(match.group(1))

    sizes = {millimeters(device) for device in devices}
    target = min(sizes) if size == 'small' else max(sizes)
    # Prefer the newest numbered generation when multiple types share a size.
    candidates = [device for device in devices if millimeters(device) == target]
    return runtime, max(candidates, key=lambda device: build_order(device['name']))


def fixture(now, state='stopped', retire_after=None):
    pressed = now - REFERENCE_DATE_OFFSET
    scheduled = pressed if retire_after is None else pressed + retire_after - 90 * 60
    context = dict(initialStartPressedAt=pressed, scheduledStart=scheduled, durationMinutes=60)
    intent = dict(classID=pressed, state=state)
    return {CLASS_KEY: json.dumps(context).encode(), INTENT_KEY: json.dumps(intent).encode()}


START_EVENTS = {'start_requested', 'automatic_restart_attempt', 'runtime_started'}
FAILURE_EVENTS = {'start_rejected_inactive', 'automatic_restart_failed',
                  'persistence_read_failed', 'persistence_write_failed'}


def awake(events):
    scene, luminance = None, None
    for event in events:
        detail = event['details']
        if event['event'] == 'scene_state_changed':
            scene = detail.get('sceneState')
        elif event['event'] == 'interface_appeared':
            scene = detail.get('scenePhase')
        if event['event'] in {'scene_state_changed', 'interface_appeared', 'luminance_changed'}:
            luminance = detail.get('luminanceReduced', luminance)
    return scene == 'active' and luminance == 'false'


def launch_evidence(events, seen, page, intent='stopped'):
    """Require one new process and matching lifecycle/page callbacks, not old data."""
    launches = [e['details']['launchID'] for e in events
                if e.get('event') == 'app_launched' and e.get('details', {}).get('launchID') not in seen]
    if len(launches) != 1:
        return None
    launch_id = launches[0]
    current = [e for e in events if e.get('details', {}).get('launchID') == launch_id]
    if not launch_id:
        return None
    if any(e['event'] in FAILURE_EVENTS for e in current):
        raise AssertionError('Runtime or persistence failure in fresh launch')
    if intent != 'running' and any(e['event'] in START_EVENTS for e in current):
        raise AssertionError('Intentional Stop or absent class was not preserved: runtime start requested')
    restored = intent == 'none' or any(e['event'] == 'runtime_intent_restored'
                   and e['details'].get('savedRuntimeIntent') == intent for e in current)
    appeared = any(e.get('event') == 'interface_appeared'
                   and e['details'].get('selectedPage') == page for e in current)
    page_appeared = any(e.get('event') == 'page_appeared'
                        and e['details'].get('observedPage') == page for e in current)
    if not (restored and appeared and page_appeared):
        return None
    if intent == 'running':
        if any(e['event'] == 'runtime_invalidated' for e in current):
            raise AssertionError('Recovered runtime invalidated during recovery observation')
        required = ['runtime_intent_restored', 'automatic_restart_attempt', 'start_requested',
                    'runtime_started', 'automatic_restart_succeeded']
        positions = []
        for name in required:
            matches = [i for i, e in enumerate(current) if e['event'] == name]
            if not matches:
                return None
            if len(matches) != 1:
                raise AssertionError('Duplicate recovery event: ' + name)
            positions.append(matches[0])
        if positions != sorted(positions):
            raise AssertionError('Recovery callbacks are out of order')
        start = current[positions[2]]
        runtime_id = start['details'].get('runtimeID')
        if not runtime_id or runtime_id == 'none' or any(
                current[i]['details'].get('runtimeID') != runtime_id for i in positions[3:]):
            raise AssertionError('Recovery runtime identity differs across callbacks')
        if start['details'].get('appState') != 'active':
            raise AssertionError('Recovery was requested while the native app was inactive')
        # The interface journal flushes independently, up to 250 ms later. Wait
        # within the launch deadline for evidence; never infer it from didStart.
        if not awake(current[:positions[2]]) or not awake(current):
            return None
    return launch_id if restored and appeared and page_appeared else None


def iso_seconds(value):
    return datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()


def retirement_evidence(events, launch_id, expected, live=False):
    current = [e for e in events if e.get('details', {}).get('launchID') == launch_id]
    if any(e['event'] in FAILURE_EVENTS for e in current):
        raise AssertionError('Runtime or persistence failure during retirement')
    stops = [e for e in current if e['event'] == 'stop_requested'
             and e['details'].get('source') == 'class_retired']
    before = current[:current.index(stops[0])] if stops else current
    if not live and any(e['event'] in START_EVENTS for e in current):
        raise AssertionError('Stopped or overdue class attempted a runtime start')
    if live and any(e['event'] == 'runtime_invalidated' for e in before):
        raise AssertionError('Running session ended before class retirement')
    if live and any(sum(e['event'] == name for e in before) > 1 for name in START_EVENTS):
        raise AssertionError('Running session restarted before class retirement')
    if not stops:
        return False
    if len(stops) != 1:
        raise AssertionError('Class was retired more than once')
    stop = stops[0]
    details = stop['details']
    context = json.loads(expected[CLASS_KEY])
    end = context['scheduledStart'] + context['durationMinutes'] * 60 + REFERENCE_DATE_OFFSET
    deadline = end + 30 * 60
    dates = {'classInitialStart': context['initialStartPressedAt'] + REFERENCE_DATE_OFFSET,
             'classScheduledStart': context['scheduledStart'] + REFERENCE_DATE_OFFSET,
             'classScheduledEnd': end, 'classRetirementDate': deadline}
    # The app's ISO diagnostics omit fractional seconds; runner fixtures use
    # whole seconds, and evidence comparisons respect that timestamp precision.
    if details.get('classDurationMinutes') != str(context['durationMinutes']) or any(
            key not in details or abs(iso_seconds(details[key]) - value) >= 1 for key, value in dates.items()):
        raise AssertionError('Retirement belongs to a different class or deadline')
    if 'classRetiredAt' not in details:
        raise AssertionError('Retirement event has no actual retirement time')
    if iso_seconds(details['classRetiredAt']) < math.floor(deadline):
        raise AssertionError('Class retired before its fixed deadline')
    after = current[current.index(stop) + 1:]
    if any(e['event'] in START_EVENTS for e in after):
        raise AssertionError('Runtime restarted after class retirement')
    removed = {e['details'].get('store') for e in after if e['event'] == 'persistence_removed'}
    if not {CLASS_KEY, INTENT_KEY}.issubset(removed):
        return False
    if live:
        runtime_id = details.get('runtimeID')
        starts = [e for e in before if e['event'] in {'start_requested', 'runtime_started'}]
        if len(starts) != 2 or any(e['details'].get('runtimeID') != runtime_id for e in starts):
            raise AssertionError('Retirement did not stop the originally recovered runtime')
        invalidated = any(e['event'] == 'runtime_invalidated'
                          and e['details'].get('runtimeID') == runtime_id
                          and e['details'].get('stopRequested') == 'true' for e in after)
        stopped = any(e['event'] == 'renewal_decision' and e['details'].get('runtimeID') == runtime_id
                      and e['details'].get('eligible') == 'false'
                      and e['details'].get('cause') == 'explicit_stop' for e in after)
        if not runtime_id or runtime_id == 'none' or not invalidated or not stopped:
            return False
    return True


def assert_awake_interval(events, launch_id, after_elapsed):
    """Reject even brief dim/background transitions during a live deadline case."""
    for event in events:
        detail = event['details']
        if detail.get('launchID') != launch_id or float(detail.get('launchElapsedSeconds', -1)) <= after_elapsed:
            continue
        if event['event'] == 'stop_requested' and detail.get('source') == 'class_retired':
            return
        if ((event['event'] == 'scene_state_changed' and detail.get('sceneState') != 'active') or
                (event['event'] == 'interface_appeared' and detail.get('scenePhase') != 'active') or
                (event['event'] in {'scene_state_changed', 'interface_appeared', 'luminance_changed'}
                 and detail.get('luminanceReduced', 'false') != 'false')):
            raise AssertionError('Live retirement crossed a dim/background transition; task timing is unproven')


def assert_saved_state(container, expected):
    path = container / 'Library/Preferences' / (BUNDLE + '.plist')
    actual = plistlib.loads(path.read_bytes())
    for key, value in expected.items():
        if actual.get(key) != value:
            raise AssertionError('Saved class or intentional Stop changed: ' + key)


def assert_retired_state(container):
    path = container / 'Library/Preferences' / (BUNDLE + '.plist')
    actual = plistlib.loads(path.read_bytes()) if path.exists() else {}
    if CLASS_KEY in actual or INTENT_KEY in actual:
        raise AssertionError('Retired class or runtime intent remains in preferences')


class Smoke:
    def __init__(self, app, output, size='small'):
        self.app, self.output = app, output
        self.size = size
        self.owned_device = None
        self.container = None
        self.running = False
        self.seen = set()
        self.journals = {}
        self.runtime_ids = set()
        self.started = time.monotonic()
        self.deadline = self.started + 480
        self.report = dict(complete=False, startedAt=datetime.now(timezone.utc).isoformat(), scope='Booted Watch recovery, retirement and seeded-state persistence',
                           size=size, negativeObservationSeconds=3,
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
            preferences = self.container / 'Library/Preferences' / (BUNDLE + '.plist')
            if preferences.exists():
                shutil.copyfile(preferences, self.output / f'{label}-preferences.plist')
        if self.owned_device:
            self.simctl('io', self.owned_device, 'screenshot', self.output / f'{label}.png', timeout=20)

    def events(self):
        events = []
        for name in ('RuntimeDiagnostics', 'InterfaceDiagnostics'):
            path = self.container / 'Documents' / (name + '.json')
            if not path.exists() and name not in self.journals:
                continue
            values = json.loads(path.read_text())
            if not isinstance(values, list) or any(not isinstance(e, dict) or
                    not isinstance(e.get('details'), dict) or 'event' not in e for e in values):
                raise AssertionError('Malformed journal: ' + name)
            previous = self.journals.get(name, [])
            if values[:len(previous)] != previous:
                raise AssertionError('Journal lost or changed already observed events: ' + name)
            self.journals[name] = values
            events.extend(values)
        return sorted(events, key=lambda e: (e['details'].get('launchID', ''),
                      float(e['details'].get('launchElapsedSeconds', -1))))

    def install_fixture(self, label, state='stopped', retire_after=None):
        if self.running:
            raise AssertionError('Refusing to replace data in a running test app')
        if self.container:
            self.simctl('uninstall', self.owned_device, BUNDLE)
        self.container = None
        self.journals = {}
        self.seen = set()
        self.simctl('install', self.owned_device, self.app, timeout=90)
        self.container = Path(self.simctl('get_app_container', self.owned_device, BUNDLE, 'data'))
        preferences = self.container / 'Library/Preferences' / (BUNDLE + '.plist')
        preferences.parent.mkdir(parents=True, exist_ok=True)
        expected = fixture(int(time.time()), state, retire_after)
        # Only a fresh, never-launched installation in our own disposable Watch.
        preferences.write_bytes(plistlib.dumps(expected))
        (self.output / (label + '-seed.json')).write_text(json.dumps(
            {key: json.loads(value) for key, value in expected.items()}, indent=2))
        return expected

    def terminate(self):
        self.simctl('terminate', self.owned_device, BUNDLE)
        self.running = False

    def observe(self, assertion, seconds=3):
        deadline = time.monotonic() + seconds
        while True:
            assertion()
            now = time.monotonic()
            if now >= self.deadline:
                raise TimeoutError('Eight-minute smoke deadline exceeded during observation')
            if now >= deadline:
                return
            time.sleep(min(.25, deadline - now))

    def launch(self, label, page, intent, expected):
        arguments = ['--show-now-playing'] if page == 'nowPlaying' else []
        self.simctl('launch', self.owned_device, BUNDLE, *arguments)
        self.running = True
        deadline = min(self.deadline, time.monotonic() + 40)
        while True:
            launch_id = launch_evidence(self.events(), self.seen, page, intent)
            if launch_id and expected is None:
                try:
                    assert_retired_state(self.container)
                except AssertionError:
                    # The journal records the in-process removal first; require
                    # the actual preferences write before starting observation.
                    launch_id = None
            if launch_id:
                break
            if time.monotonic() >= deadline:
                raise TimeoutError(f'No complete new {label} launch/state evidence within 40 seconds')
            time.sleep(.25)

        def preserved():
            events = self.events()
            if launch_evidence(events, self.seen, page, intent) != launch_id:
                raise AssertionError('Launch evidence changed during observation')
            if expected is None:
                assert_retired_state(self.container)
            else:
                assert_saved_state(self.container, expected)
                pressed = json.loads(expected[CLASS_KEY])['initialStartPressedAt'] + REFERENCE_DATE_OFFSET
                for event in events:
                    if event['details'].get('launchID') == launch_id and event['event'] in START_EVENTS | {'runtime_intent_restored'}:
                        value = event['details'].get('intentClassID')
                        if not value or abs(iso_seconds(value) - pressed) >= 1:
                            raise AssertionError('Recovered runtime intent belongs to a different class')

        self.observe(preserved)
        self.collect(label)
        preserved()  # Capture is not allowed to hide a late restart/failure.
        current = [e for e in self.events() if e['details'].get('launchID') == launch_id]
        runtime_id = next((e['details']['runtimeID'] for e in current if e['event'] == 'runtime_started'), None)
        if intent == 'running':
            if runtime_id in self.runtime_ids:
                raise AssertionError('Recovery reused a previous process runtime identity')
            self.runtime_ids.add(runtime_id)
        self.report['launches'].append(dict(label=label, launchID=launch_id, selectedPage=page,
                                            expectedIntent=intent, runtimeID=runtime_id,
                                            savedStateVerified=True))
        self.seen.add(launch_id)
        self.save()
        return launch_id

    def wait_retirement(self, label, launch_id, expected, live=False):
        context = json.loads(expected[CLASS_KEY])
        deadline = context['scheduledStart'] + (context['durationMinutes'] + 30) * 60 + REFERENCE_DATE_OFFSET
        remaining = deadline - time.time()
        if remaining < 3:
            raise AssertionError('Setup missed the fixed live-retirement deadline')
        # Translate this one real wall-clock deadline into a bounded monotonic wait.
        limit = min(self.deadline, time.monotonic() + remaining + 20)
        current = [e for e in self.events() if e['details'].get('launchID') == launch_id]
        if not awake(current):
            raise AssertionError('Timed retirement requires an awake pre-deadline launch')
        after_elapsed = max(float(e['details']['launchElapsedSeconds']) for e in current)
        self.collect(label + '-before')
        if deadline - time.time() < 3:
            raise AssertionError('Pre-retirement capture missed the fixed deadline')
        while True:
            events = self.events()
            assert_awake_interval(events, launch_id, after_elapsed)
            if {e['details'].get('launchID') for e in events if e['event'] == 'app_launched'} != self.seen:
                raise AssertionError('Unexpected process launch during timed retirement')
            if retirement_evidence(events, launch_id, expected, live):
                try:
                    assert_retired_state(self.container)
                    break
                except AssertionError:
                    pass  # UserDefaults writes may follow the journal callback.
            elif time.time() < deadline:
                assert_saved_state(self.container, expected)
            if time.monotonic() >= limit:
                raise TimeoutError('Timed class retirement did not complete by its fixed deadline plus 20 seconds')
            time.sleep(.25)

        def remains_retired():
            events = self.events()
            assert_awake_interval(events, launch_id, after_elapsed)
            if not retirement_evidence(events, launch_id, expected, live):
                raise AssertionError('Retirement evidence disappeared')
            # No process replacement is permitted to stand in for the live task.
            if {e['details'].get('launchID') for e in events if e['event'] == 'app_launched'} != self.seen:
                raise AssertionError('Unexpected process launch during timed retirement')
            assert_retired_state(self.container)

        self.observe(remains_retired)
        self.collect(label + '-after')
        remains_retired()
        self.report.setdefault('retirements', []).append(dict(label=label, launchID=launch_id,
            deadline=datetime.fromtimestamp(deadline, timezone.utc).isoformat(),
            liveRuntimeInvalidationVerified=live, classAndIntentRemoved=True))
        self.save()

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
        runtime, device = select_watch(runtimes, info.get('MinimumOSVersion', '26.0'), platform.machine(), self.size)
        if self.size == 'large':
            _, small = select_watch(runtimes, info.get('MinimumOSVersion', '26.0'), platform.machine(), 'small')
            if re.search(r'(\d+)mm', small['name'])[1] == re.search(r'(\d+)mm', device['name'])[1]:
                raise RuntimeError('Newest Watch runtime does not offer two distinct screen sizes')
        self.report['runtime'] = {key: runtime[key] for key in ('identifier', 'version', 'buildversion')}
        self.report['deviceType'] = device['identifier']
        name = 'TeachingTimer CI Smoke ' + self.size + ' ' + str(uuid.uuid4())[:8]
        created = self.simctl('create', name, device['identifier'], runtime['identifier'])
        self.owned_device = str(uuid.UUID(created))
        self.report['createdDevice'] = self.owned_device
        self.save()
        self.simctl('boot', self.owned_device, timeout=60)
        self.simctl('bootstatus', self.owned_device, '-b', timeout=180)
        expected = self.install_fixture('stopped')
        for label, page in [('timer', 'classProgress'), ('media', 'nowPlaying'), ('timer-reopened', 'classProgress')]:
            self.launch(label, page, 'stopped', expected)
            self.terminate()

        expected = self.install_fixture('running', state='running')
        for label in ('running-restored', 'running-recovered'):
            self.launch(label, 'classProgress', 'running', expected)
            self.terminate()

        # Exercise real deadline passage on both pages without advancing clocks
        # or modifying preferences after launch. Each fixture is independent.
        for label, page, state, lead in [('timer-retirement', 'classProgress', 'running', 60),
                                          ('media-retirement', 'nowPlaying', 'stopped', 45)]:
            expected = self.install_fixture(label, state, retire_after=lead)
            launch_id = self.launch(label + '-restored', page, state, expected)
            self.wait_retirement(label, launch_id, expected, live=state == 'running')
            self.terminate()
            self.launch(label + '-reopened', 'classProgress', 'none', None)
            self.terminate()

        expected = self.install_fixture('overdue', state='running', retire_after=-5)
        launch_id = self.launch('overdue-retired', 'classProgress', 'none', None)
        if not retirement_evidence(self.events(), launch_id, expected):
            raise AssertionError('Overdue running class did not retire on launch')
        self.terminate()
        self.report['complete'] = True
        self.save()


def run_one(smoke):
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
    return smoke.report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path, help='New evidence directory; never overwrites')
    parser.add_argument('--watch-size', choices=('small', 'large', 'matrix'), default='matrix',
                        help='Matrix runs the same checks on both size extremes, serially')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    sizes = ['small', 'large'] if args.watch_size == 'matrix' else [args.watch_size]
    report = dict(complete=False, sizes=sizes, devices=[], renderingVerified=False,
                  physicalDevicesUsed=False, startedAt=datetime.now(timezone.utc).isoformat())
    started = time.monotonic()
    try:
        for size in sizes:
            target = output / size
            target.mkdir()
            print('Running Watch smoke: ' + size, flush=True)
            result = run_one(Smoke(args.app.resolve(), target, size))
            report['devices'].append(dict(size=size, complete=result['complete'],
                runtime=result.get('runtime'), deviceType=result.get('deviceType'),
                elapsedSeconds=result['elapsedSeconds'], report=size + '/smoke.json'))
            if not result['complete']:
                break
        report['complete'] = len(report['devices']) == len(sizes) and all(d['complete'] for d in report['devices'])
        if len(report['devices']) == 2 and report['devices'][0]['runtime'] != report['devices'][1]['runtime']:
            report['complete'] = False
            report['error'] = 'Selected runtime changed during the matrix'
    finally:
        report['elapsedSeconds'] = round(time.monotonic() - started, 3)
        report['finishedAt'] = datetime.now(timezone.utc).isoformat()
        (output / 'smoke.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['complete'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
