# SPDX-License-Identifier: MPL-2.0
"""Evidence must belong to the observed launch, runtime, and seeded class."""
import copy
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    'smoke_lifecycle', Path(__file__).resolve().parents[1] / 'scripts/simulator-smoke.py')
smoke = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(smoke)

NOW = 1800000000.25


def iso(timestamp):
    # The production journals and class dates intentionally omit fractions.
    return datetime.fromtimestamp(timestamp, timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z')


def event(name, elapsed=0, launch='new', **details):
    return dict(event=name, timestamp=iso(NOW + elapsed),
                details=dict(launchID=launch, launchElapsedSeconds=str(elapsed), **details))


def launch_events(intent='running', launch='new', page='classProgress'):
    rows = [event('app_launched', launch=launch)]
    if intent != 'none':
        rows.append(event('runtime_intent_restored', .01, launch, savedRuntimeIntent=intent))
    rows.extend([
        event('interface_appeared', .02, launch, selectedPage=page,
              scenePhase='active', sceneState='active', luminanceReduced='false'),
        event('page_appeared', .03, launch, observedPage=page),
    ])
    if intent == 'running':
        rows.extend([
            # This callback precedes allocation of the replacement runtime.
            event('automatic_restart_attempt', .04, launch),
            event('start_requested', .05, launch, runtimeID='runtime-new', appState='active'),
            event('runtime_started', .06, launch, runtimeID='runtime-new', phase='running'),
            event('automatic_restart_succeeded', .07, launch, runtimeID='runtime-new'),
        ])
    return rows


def retirement_events(expected, *, live=False, launch='new'):
    context = json.loads(expected[smoke.CLASS_KEY])
    initial = context['initialStartPressedAt'] + smoke.REFERENCE_DATE_OFFSET
    scheduled = context['scheduledStart'] + smoke.REFERENCE_DATE_OFFSET
    end = scheduled + context['durationMinutes'] * 60
    retirement = end + 30 * 60
    elapsed = retirement - NOW
    rows = [event('stop_requested', elapsed, launch, source='class_retired',
                  runtimeID='runtime-new' if live else 'none', stopRequested='false',
                  classInitialStart=iso(initial), classScheduledStart=iso(scheduled),
                  classScheduledEnd=iso(end), classRetirementDate=iso(retirement),
                  classRetiredAt=iso(retirement), classDurationMinutes='60'),
            event('persistence_removed', elapsed + .01, launch, store=smoke.CLASS_KEY),
            event('persistence_removed', elapsed + .02, launch, store=smoke.INTENT_KEY)]
    if live:
        rows = launch_events('running', launch) + rows
        rows.extend([
            event('runtime_invalidated', elapsed + .03, launch,
                  runtimeID='runtime-new', stopRequested='true', reason='normal_end'),
            event('renewal_decision', elapsed + .04, launch,
                  runtimeID='runtime-new', eligible='false', cause='explicit_stop'),
        ])
    return rows


def watch(name, identifier):
    return dict(name=name, identifier=identifier, productFamily='Apple Watch')


def runtime(devices, number='27.2'):
    return dict(version=number, buildversion='24S118', isAvailable=True,
                platform='watchOS', supportedArchitectures=['arm64'],
                identifier='watchOS-' + number, supportedDeviceTypes=devices)


class WatchSizeSelectionChecks(unittest.TestCase):
    def test_size_uses_geometry_before_model_preference(self):
        devices = [watch('Apple Watch SE 3 (40mm)', 'se'),
                   watch('Apple Watch Series 3 (38mm)', 'smallest'),
                   watch('Apple Watch Ultra 4 (49mm)', 'largest')]
        for size, expected in [('small', 'smallest'), ('large', 'largest')]:
            with self.subTest(size=size):
                _, selected = smoke.select_watch([runtime(devices)], '26.0', 'arm64', size=size)
                self.assertEqual(selected['identifier'], expected)

    def test_latest_generation_wins_equal_geometry(self):
        devices = [watch('Apple Watch Ultra 2 (49mm)', 'older'),
                   watch('Apple Watch Ultra 4 (49mm)', 'newer')]
        for size in ('small', 'large'):
            with self.subTest(size=size):
                _, selected = smoke.select_watch([runtime(devices)], '26.0', 'arm64', size=size)
                self.assertEqual(selected['identifier'], 'newer')

    def test_missing_geometry_is_rejected_instead_of_becoming_a_large_watch(self):
        devices = [watch('Apple Watch Ultra unknown', 'malformed'),
                   watch('Apple Watch Series 12 (46mm)', 'valid')]
        with self.assertRaises(RuntimeError):
            smoke.select_watch([runtime(devices)], '26.0', 'arm64', size='large')

    def test_newest_runtime_without_measurable_watch_cannot_use_older_runtime(self):
        values = [runtime([watch('Apple Watch SE 3 (40mm)', 'old')], '26.0'),
                  runtime([watch('Apple Watch unknown', 'malformed')])]
        for size in ('small', 'large'):
            with self.subTest(size=size), self.assertRaises(RuntimeError):
                smoke.select_watch(values, '26.0', 'arm64', size=size)


class LifecycleFixtureChecks(unittest.TestCase):
    def test_near_retirement_keeps_the_class_identity_at_the_initial_press(self):
        for state in ('stopped', 'running'):
            with self.subTest(state=state):
                expected = smoke.fixture(NOW, state=state, retire_after=90)
                self.assertIsInstance(expected[smoke.CLASS_KEY], bytes)
                self.assertIsInstance(expected[smoke.INTENT_KEY], bytes)
                context, intent = (json.loads(expected[key]) for key in (smoke.CLASS_KEY, smoke.INTENT_KEY))
                self.assertEqual(context['initialStartPressedAt'] + smoke.REFERENCE_DATE_OFFSET, NOW)
                self.assertEqual(context['durationMinutes'], 60)
                self.assertEqual(context['scheduledStart'] + smoke.REFERENCE_DATE_OFFSET + 90 * 60, NOW + 90)
                self.assertEqual(intent, dict(classID=context['initialStartPressedAt'], state=state))
                self.assertNotEqual(intent['classID'], context['scheduledStart'])

    def test_running_fixture_without_retirement_shift_preserves_anchor(self):
        expected = smoke.fixture(NOW, state='running')
        context = json.loads(expected[smoke.CLASS_KEY])
        self.assertEqual(context['initialStartPressedAt'], context['scheduledStart'])
        self.assertEqual(json.loads(expected[smoke.INTENT_KEY])['state'], 'running')


class RunningLaunchEvidenceChecks(unittest.TestCase):
    def check(self, rows, seen=None):
        return smoke.launch_evidence(rows, set() if seen is None else seen, 'classProgress', intent='running')

    def test_complete_automatic_recovery_belongs_to_one_new_launch_and_runtime(self):
        self.assertEqual(self.check(launch_events('running')), 'new')
        self.assertEqual(self.check(launch_events('running', 'old') + launch_events('running'), {'old'}), 'new')
        self.assertIsNone(self.check(launch_events('running'), {'new'}))

    def test_each_recovery_callback_is_required(self):
        for missing in ('runtime_intent_restored', 'automatic_restart_attempt', 'start_requested',
                        'runtime_started', 'automatic_restart_succeeded', 'interface_appeared', 'page_appeared'):
            with self.subTest(missing=missing):
                rows = [row for row in launch_events() if row['event'] != missing]
                self.assertIsNone(self.check(rows))

    def test_stale_callbacks_cannot_complete_the_current_launch(self):
        for name in ('runtime_intent_restored', 'automatic_restart_attempt', 'runtime_started',
                     'automatic_restart_succeeded', 'interface_appeared', 'page_appeared'):
            with self.subTest(name=name):
                rows = launch_events()
                next(row for row in rows if row['event'] == name)['details']['launchID'] = 'old'
                self.assertIsNone(self.check(rows, {'old'}))

    def test_start_and_success_cannot_belong_to_different_or_missing_runtimes(self):
        for name in ('start_requested', 'runtime_started', 'automatic_restart_succeeded'):
            for identity in ('other-runtime', '', 'none', None):
                with self.subTest(name=name, identity=identity):
                    rows = launch_events()
                    details = next(row for row in rows if row['event'] == name)['details']
                    if identity is None:
                        details.pop('runtimeID')
                    else:
                        details['runtimeID'] = identity
                    with self.assertRaises(AssertionError):
                        self.check(rows)

    def test_stopped_restore_and_wrong_page_cannot_pass_running_recovery(self):
        rows = launch_events()
        next(row for row in rows if row['event'] == 'runtime_intent_restored')['details']['savedRuntimeIntent'] = 'stopped'
        self.assertIsNone(self.check(rows))
        self.assertIsNone(self.check(launch_events(page='nowPlaying')))

    def test_out_of_order_or_duplicate_recovery_callbacks_are_rejected(self):
        rows = launch_events()
        rows[-1], rows[-2] = rows[-2], rows[-1]
        with self.assertRaises(AssertionError):
            self.check(rows)
        rows = launch_events()
        rows.append(copy.deepcopy(rows[-1]))
        with self.assertRaises(AssertionError):
            self.check(rows)

    def test_native_active_alone_cannot_override_a_dimmed_or_inactive_scene(self):
        for changes in ({'scenePhase': 'inactive', 'sceneState': 'inactive'},
                        {'luminanceReduced': 'true'}, {'luminanceReduced': None}):
            with self.subTest(changes=changes):
                rows = launch_events()
                details = next(row for row in rows if row['event'] == 'interface_appeared')['details']
                for key, value in changes.items():
                    if value is None:
                        details.pop(key)
                    else:
                        details[key] = value
                self.assertIsNone(self.check(rows))

    def test_later_dim_transition_before_start_invalidates_earlier_awake_evidence(self):
        rows = launch_events()
        rows.insert(4, event('scene_state_changed', .035, sceneState='inactive',
                             previousSceneState='active', luminanceReduced='true'))
        self.assertIsNone(self.check(rows))

    def test_delayed_interface_flush_can_complete_recovery_on_a_later_poll(self):
        rows = launch_events()
        details = next(row for row in rows if row['event'] == 'interface_appeared')['details']
        details.update(scenePhase='inactive', sceneState='inactive', luminanceReduced='true')
        self.assertIsNone(self.check(rows))
        rows.insert(4, event('scene_state_changed', .035, sceneState='active',
                             previousSceneState='inactive', luminanceReduced='false'))
        self.assertEqual(self.check(rows), 'new')

    def test_background_runtime_request_does_not_pass_after_success_callback(self):
        rows = launch_events()
        next(row for row in rows if row['event'] == 'start_requested')['details']['appState'] = 'background'
        with self.assertRaises(AssertionError):
            self.check(rows)

    def test_late_failure_or_invalidation_overrides_prior_success(self):
        for name in ('automatic_restart_failed', 'start_rejected_inactive', 'runtime_invalidated'):
            with self.subTest(name=name), self.assertRaises(AssertionError):
                self.check(launch_events() + [event(name, .5, runtimeID='runtime-new', reason='error')])


class StoppedAndEmptyLaunchEvidenceChecks(unittest.TestCase):
    def test_stopped_and_cleared_class_launches_need_the_expected_page(self):
        for intent in ('stopped', 'none'):
            with self.subTest(intent=intent):
                rows = launch_events(intent)
                self.assertEqual(smoke.launch_evidence(rows, set(), 'classProgress', intent=intent), 'new')
                self.assertIsNone(smoke.launch_evidence(rows[:-1], set(), 'classProgress', intent=intent))

    def test_preserved_stop_cannot_pass_an_automatic_attempt_without_a_start(self):
        for intent in ('stopped', 'none'):
            for name in ('automatic_restart_attempt', 'start_requested', 'runtime_started'):
                with self.subTest(intent=intent, name=name), self.assertRaises(AssertionError):
                    smoke.launch_evidence(launch_events(intent) + [event(name, .5)],
                                          set(), 'classProgress', intent=intent)


class RetirementEvidenceChecks(unittest.TestCase):
    def setUp(self):
        self.expected = smoke.fixture(NOW, state='stopped', retire_after=90)

    def check(self, rows, live=False):
        return smoke.retirement_evidence(rows, 'new', self.expected, live=live)

    def test_one_matching_retirement_clears_both_stores(self):
        self.assertTrue(self.check(retirement_events(self.expected)))
        for store in (smoke.CLASS_KEY, smoke.INTENT_KEY):
            with self.subTest(store=store):
                rows = [row for row in retirement_events(self.expected)
                        if row['details'].get('store') != store]
                self.assertFalse(self.check(rows))

    def test_retirement_of_an_old_launch_or_other_class_is_not_evidence(self):
        self.assertFalse(self.check(retirement_events(self.expected, launch='old')))
        for key in ('classInitialStart', 'classScheduledStart', 'classScheduledEnd', 'classRetirementDate'):
            with self.subTest(key=key):
                rows = retirement_events(self.expected)
                rows[0]['details'][key] = iso(NOW - 86400)
                with self.assertRaises(AssertionError):
                    self.check(rows)

    def test_missing_or_malformed_dates_cannot_pass(self):
        for key in ('classInitialStart', 'classScheduledStart', 'classScheduledEnd',
                    'classRetirementDate', 'classRetiredAt'):
            for value in (None, 'not-a-date'):
                with self.subTest(key=key, value=value):
                    rows = retirement_events(self.expected)
                    if value is None:
                        rows[0]['details'].pop(key)
                    else:
                        rows[0]['details'][key] = value
                    with self.assertRaises((AssertionError, ValueError)):
                        self.check(rows)

    def test_early_retirement_and_wrong_source_cannot_pass(self):
        rows = retirement_events(self.expected)
        rows[0]['details']['classRetiredAt'] = iso(NOW + 80)
        rows[0]['timestamp'] = iso(NOW + 80)
        with self.assertRaises(AssertionError):
            self.check(rows)
        rows = retirement_events(self.expected)
        rows[0]['details']['source'] = 'runtime_button'
        self.assertFalse(self.check(rows))

    def test_duplicate_retirement_is_not_idempotent(self):
        rows = retirement_events(self.expected)
        with self.assertRaises(AssertionError):
            self.check(rows + [copy.deepcopy(rows[0])])

    def test_start_after_retirement_is_rejected(self):
        for name in ('automatic_restart_attempt', 'start_requested', 'runtime_started'):
            with self.subTest(name=name), self.assertRaises(AssertionError):
                self.check(retirement_events(self.expected) + [event(name, 91, runtimeID='unexpected')])

    def test_stopped_or_overdue_class_cannot_start_before_retirement(self):
        for name in ('automatic_restart_attempt', 'start_requested', 'runtime_started'):
            with self.subTest(name=name), self.assertRaises(AssertionError):
                self.check([event(name, 1, runtimeID='unexpected')] + retirement_events(self.expected))

    def test_live_retirement_requires_same_runtime_invalidation_and_no_renewal(self):
        rows = retirement_events(self.expected, live=True)
        self.assertTrue(self.check(rows, live=True))
        for name in ('runtime_invalidated', 'renewal_decision'):
            with self.subTest(missing=name):
                self.assertFalse(self.check([row for row in rows if row['event'] != name], live=True))
            changed = copy.deepcopy(rows)
            next(row for row in changed if row['event'] == name)['details']['runtimeID'] = 'old-runtime'
            with self.subTest(wrong_runtime=name):
                self.assertFalse(self.check(changed, live=True))

    def test_live_retirement_requires_the_original_start_request_and_confirmation(self):
        for name in ('start_requested', 'runtime_started'):
            with self.subTest(missing=name), self.assertRaises(AssertionError):
                rows = [row for row in retirement_events(self.expected, live=True) if row['event'] != name]
                self.check(rows, live=True)
            with self.subTest(wrong_runtime=name), self.assertRaises(AssertionError):
                rows = retirement_events(self.expected, live=True)
                next(row for row in rows if row['event'] == name)['details']['runtimeID'] = 'old-runtime'
                self.check(rows, live=True)

    def test_live_retirement_cannot_follow_a_second_runtime_start(self):
        for name in ('automatic_restart_attempt', 'start_requested', 'runtime_started'):
            with self.subTest(name=name), self.assertRaises(AssertionError):
                rows = retirement_events(self.expected, live=True)
                stop_index = next(index for index, row in enumerate(rows) if row['event'] == 'stop_requested')
                rows.insert(stop_index, event(name, 89, runtimeID='replacement'))
                self.check(rows, live=True)

    def test_invalidation_without_explicit_stop_does_not_prove_retirement(self):
        for name, key, value in (('runtime_invalidated', 'stopRequested', 'false'),
                                 ('renewal_decision', 'eligible', 'true'),
                                 ('renewal_decision', 'cause', 'expired')):
            with self.subTest(name=name, key=key):
                rows = retirement_events(self.expected, live=True)
                next(row for row in rows if row['event'] == name)['details'][key] = value
                self.assertFalse(self.check(rows, live=True))

    def test_live_retirement_cannot_use_a_missing_runtime_identity(self):
        for identity in ('', 'none', None):
            with self.subTest(identity=identity):
                rows = retirement_events(self.expected, live=True)
                for row in rows:
                    if 'runtimeID' in row['details']:
                        if identity is None:
                            row['details'].pop('runtimeID')
                        else:
                            row['details']['runtimeID'] = identity
                self.assertFalse(self.check(rows, live=True))

    def test_invalidation_before_stop_cannot_satisfy_live_retirement(self):
        rows = retirement_events(self.expected, live=True)
        for row in rows:
            if row['event'] in ('runtime_invalidated', 'renewal_decision'):
                row['timestamp'] = iso(NOW + 89)
                row['details']['launchElapsedSeconds'] = '89'
        rows = [row for row in rows if row['event'] in ('runtime_invalidated', 'renewal_decision')] + [
            row for row in rows if row['event'] not in ('runtime_invalidated', 'renewal_decision')]
        with self.assertRaises(AssertionError):
            self.check(rows, live=True)

    def test_old_store_removals_cannot_prove_this_retirement_cleared_preferences(self):
        rows = retirement_events(self.expected)
        rows = rows[1:] + rows[:1]
        self.assertFalse(self.check(rows))

    def test_retired_preferences_must_remove_both_keys_not_preserve_stop(self):
        with tempfile.TemporaryDirectory() as directory:
            container = Path(directory)
            path = container / 'Library/Preferences' / (smoke.BUNDLE + '.plist')
            path.parent.mkdir(parents=True)
            smoke.assert_retired_state(container)
            path.write_bytes(plistlib.dumps({'unrelated-preference': True}))
            smoke.assert_retired_state(container)
            for key in (smoke.CLASS_KEY, smoke.INTENT_KEY):
                with self.subTest(key=key):
                    path.write_bytes(plistlib.dumps({key: self.expected[key]}))
                    with self.assertRaises(AssertionError):
                        smoke.assert_retired_state(container)


class ClearedPreferencesLaunchChecks(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.check = smoke.Smoke(root / 'unused.app', root / 'evidence')
        self.check.container = root / 'container'
        self.preferences = self.check.container / 'Library/Preferences' / (smoke.BUNDLE + '.plist')
        self.preferences.parent.mkdir(parents=True)
        self.preferences.write_bytes(plistlib.dumps(smoke.fixture(NOW, state='running', retire_after=-5)))

    def test_overdue_launch_waits_for_delayed_file_deletion_before_stable_observation(self):
        pending_polls = []

        def flush_preferences(_seconds):
            self.assertFalse(observe.called)
            pending_polls.append(True)
            if len(pending_polls) == 2:
                self.preferences.unlink()

        def observe_cleared(assertion):
            self.assertFalse(self.preferences.exists())
            assertion()
            assertion()

        with patch.object(self.check, 'simctl'), \
                patch.object(self.check, 'events', return_value=launch_events('none')), \
                patch.object(self.check, 'observe', side_effect=observe_cleared) as observe, \
                patch.object(self.check, 'collect'), patch.object(self.check, 'save'), \
                patch.object(smoke.time, 'sleep', side_effect=flush_preferences):
            launch_id = self.check.launch('overdue-retired', 'classProgress', 'none', None)
        self.assertEqual(len(pending_polls), 2)
        self.assertEqual(launch_id, 'new')
        observe.assert_called_once()
        self.assertEqual(self.check.seen, {'new'})
        self.assertTrue(self.check.report['launches'][0]['savedStateVerified'])

    def test_runtime_start_while_waiting_for_preferences_still_fails_immediately(self):
        for name in ('automatic_restart_attempt', 'start_requested', 'runtime_started'):
            with self.subTest(name=name):
                initial = launch_events('none')
                with patch.object(self.check, 'simctl'), \
                        patch.object(self.check, 'events', side_effect=[initial, initial + [event(name, .5)]]), \
                        patch.object(self.check, 'observe') as observe, \
                        patch.object(self.check, 'collect') as collect, \
                        patch.object(smoke.time, 'sleep'):
                    with self.assertRaises(AssertionError):
                        self.check.launch('overdue-retired', 'classProgress', 'none', None)
                observe.assert_not_called()
                collect.assert_not_called()
                self.assertTrue(self.preferences.exists())
                self.assertEqual(self.check.report['launches'], [])


class JournalContinuityChecks(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.check = smoke.Smoke(self.root / 'unused.app', self.root / 'evidence')
        self.check.container = self.root / 'container'
        self.documents = self.check.container / 'Documents'
        self.documents.mkdir(parents=True)

    def write(self, name, rows):
        path = self.documents / (name + '.json')
        path.write_text(json.dumps(rows))
        return path

    def test_journals_may_be_initially_absent_and_append_independently(self):
        self.assertEqual(self.check.events(), [])
        launched = event('app_launched')
        self.write('RuntimeDiagnostics', [launched])
        self.assertEqual(self.check.events(), [launched])
        started = event('start_requested', 2, runtimeID='runtime-new')
        self.write('RuntimeDiagnostics', [launched, started])
        awake_row = event('scene_state_changed', 1, sceneState='active', luminanceReduced='false')
        self.write('InterfaceDiagnostics', [awake_row])
        self.assertEqual(self.check.events(), [launched, awake_row, started])

    def test_an_observed_journal_cannot_disappear(self):
        for name in ('RuntimeDiagnostics', 'InterfaceDiagnostics'):
            with self.subTest(name=name):
                self.check.journals = {}
                path = self.write(name, [event('app_launched')])
                self.check.events()
                path.unlink()
                with self.assertRaises(OSError):
                    self.check.events()

    def test_malformed_json_and_journal_rows_cannot_be_treated_as_no_events(self):
        path = self.documents / 'RuntimeDiagnostics.json'
        for contents in ('{', '{}', '[null]', '[{"event":"runtime_started"}]',
                         '[{"event":"runtime_started","details":[]}]', '[{"details":{}}]'):
            with self.subTest(contents=contents):
                path.write_text(contents)
                with self.assertRaises((ValueError, AssertionError)):
                    self.check.events()

    def test_observed_prefix_cannot_be_truncated_reordered_or_changed(self):
        original = [event('app_launched'), event('start_requested', 1, runtimeID='runtime-new')]
        mutations = [original[:1], list(reversed(original)),
                     [original[0], event('start_requested', 1, runtimeID='different-runtime')]]
        for changed in mutations:
            with self.subTest(changed=changed):
                self.check.journals = {}
                self.write('RuntimeDiagnostics', original)
                self.check.events()
                self.write('RuntimeDiagnostics', changed)
                with self.assertRaisesRegex(AssertionError, 'lost or changed'):
                    self.check.events()


class AwakeRetirementIntervalChecks(unittest.TestCase):
    def test_active_interval_reaches_retirement(self):
        rows = [event('scene_state_changed', 11, sceneState='active'),
                event('luminance_changed', 12, luminanceReduced='false'),
                event('stop_requested', 90, source='class_retired')]
        smoke.assert_awake_interval(rows, 'new', 10)

    def test_even_transient_inactive_or_dimmed_state_invalidates_interval(self):
        for name, details in [('scene_state_changed', {'sceneState': 'inactive'}),
                              ('scene_state_changed', {'sceneState': 'background'}),
                              ('scene_state_changed', {'sceneState': 'active', 'luminanceReduced': 'true'}),
                              ('luminance_changed', {'luminanceReduced': 'true'})]:
            with self.subTest(name=name, details=details), self.assertRaises(AssertionError):
                rows = [event(name, 11, **details),
                        event('scene_state_changed', 12, sceneState='active', luminanceReduced='false'),
                        event('stop_requested', 90, source='class_retired')]
                smoke.assert_awake_interval(rows, 'new', 10)

    def test_other_launches_and_events_outside_observed_interval_are_ignored(self):
        rows = [event('scene_state_changed', 9, sceneState='inactive'),
                event('luminance_changed', 10, luminanceReduced='true'),
                event('scene_state_changed', 11, 'old', sceneState='background'),
                event('stop_requested', 90, source='class_retired'),
                event('scene_state_changed', 91, sceneState='inactive'),
                event('luminance_changed', 92, luminanceReduced='true')]
        smoke.assert_awake_interval(rows, 'new', 10)

    def test_other_launch_or_manual_stop_does_not_end_interval(self):
        for launch, source in [('old', 'class_retired'), ('new', 'runtime_button')]:
            with self.subTest(launch=launch, source=source), self.assertRaises(AssertionError):
                rows = [event('stop_requested', 11, launch, source=source),
                        event('luminance_changed', 12, luminanceReduced='true')]
                smoke.assert_awake_interval(rows, 'new', 10)


class SmokeMatrixChecks(unittest.TestCase):
    def run_main(self, results, size=None):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'matrix'
            arguments = ['simulator-smoke.py', '--app', str(Path(directory) / 'unused.app'),
                         '--output', str(output)]
            if size is not None:
                arguments.extend(['--watch-size', size])
            with patch.object(sys, 'argv', arguments), patch.object(smoke, 'run_one', side_effect=results) as run, \
                    patch('builtins.print'):
                status = smoke.main()
            report = json.loads((output / 'smoke.json').read_text())
            return status, report, [call.args[0].size for call in run.call_args_list]

    def result(self, complete=True, runtime_build='24S118', device='small-device'):
        return dict(complete=complete, runtime=dict(identifier='watchOS-27.2', version='27.2',
                                                  buildversion=runtime_build),
                    deviceType=device, elapsedSeconds=1)

    def test_default_matrix_requires_both_sizes_on_the_same_runtime(self):
        status, report, sizes = self.run_main([self.result(), self.result(device='large-device')])
        self.assertEqual(status, 0)
        self.assertTrue(report['complete'])
        self.assertEqual(sizes, ['small', 'large'])
        self.assertEqual([item['size'] for item in report['devices']], sizes)

    def test_failure_in_either_size_cannot_complete_matrix(self):
        for results in ([self.result(False)], [self.result(), self.result(False, device='large-device')]):
            with self.subTest(results=results):
                status, report, sizes = self.run_main(results)
                self.assertEqual(status, 1)
                self.assertFalse(report['complete'])
                self.assertEqual(len(sizes), len(results))

    def test_runtime_change_between_sizes_cannot_complete_matrix(self):
        status, report, _ = self.run_main([self.result(), self.result(runtime_build='24S120', device='large-device')])
        self.assertEqual(status, 1)
        self.assertFalse(report['complete'])
        self.assertIn('runtime changed', report['error'])

    def test_explicit_size_runs_once(self):
        status, report, sizes = self.run_main([self.result(device='large-device')], size='large')
        self.assertEqual(status, 0)
        self.assertEqual(sizes, ['large'])
        self.assertEqual(report['sizes'], ['large'])

    def test_two_models_with_one_geometry_cannot_create_a_false_size_matrix(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'test.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier=smoke.BUNDLE,
                CFBundleSupportedPlatforms=['WatchSimulator'], CFBundleVersion='1')))
            check = smoke.Smoke(app, root / 'evidence', size='large')
            available = runtime([watch('Apple Watch Ultra 2 (49mm)', 'older'),
                                 watch('Apple Watch Ultra 4 (49mm)', 'newer')])
            with patch.object(check, 'command', return_value='test'), \
                    patch.object(check, 'simctl', return_value=json.dumps({'runtimes': [available]})) as simctl, \
                    patch.object(smoke.platform, 'machine', return_value='arm64'):
                with self.assertRaisesRegex(RuntimeError, 'two distinct screen sizes'):
                    check.run()
            simctl.assert_called_once_with('list', 'runtimes', '--json')


if __name__ == '__main__':
    unittest.main()
