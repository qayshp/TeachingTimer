# SPDX-License-Identifier: MPL-2.0
import importlib.util
import json
from pathlib import Path
import plistlib
import tempfile
import sys
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('simulator_smoke', Path(__file__).resolve().parents[1] / 'scripts/simulator-smoke.py')
smoke = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(smoke)


def runtime(number='27.2', build='24S118', available=True, devices=None):
    return dict(version=number, buildversion=build, isAvailable=available, platform='watchOS',
                supportedArchitectures=['arm64'], identifier='watchOS-' + number,
                supportedDeviceTypes=devices if devices is not None else [
                    dict(name='Apple Watch Ultra 4 (49mm)', productFamily='Apple Watch', identifier='ultra'),
                    dict(name='Apple Watch SE 3 (40mm)', productFamily='Apple Watch', identifier='se')])


def event(name, launch='new', **details):
    return dict(event=name, details=dict(launchID=launch, **details))


def complete_launch(launch='new', page='classProgress'):
    return [event('app_launched', launch), event('runtime_intent_restored', launch, savedRuntimeIntent='stopped'),
            event('interface_appeared', launch, selectedPage=page), event('page_appeared', launch, observedPage=page)]


class SimulatorSmokeChecks(unittest.TestCase):
    def test_newest_available_runtime_and_small_watch_are_selected(self):
        selected, device = smoke.select_watch([runtime('26.0'), runtime(), runtime('28.0', available=False)], '26.0', 'arm64')
        self.assertEqual(selected['version'], '27.2')
        self.assertEqual(device['identifier'], 'se')

    def test_runtime_version_accepts_equivalent_trailing_zero_components(self):
        selected, _ = smoke.select_watch([runtime('27.2')], '27.2.0', 'arm64')
        self.assertEqual(selected['version'], '27.2')

    def test_runtime_build_sort_is_numeric_and_architecture_compatible(self):
        incompatible = runtime('28.0')
        incompatible['supportedArchitectures'] = ['x86_64']
        selected, _ = smoke.select_watch([runtime(build='24S9'), runtime(build='24S118'), incompatible], '26.0', 'arm64')
        self.assertEqual(selected['buildversion'], '24S118')

    def test_missing_or_old_watch_runtime_fails_instead_of_skipping(self):
        for values in ([], [runtime('25.0')], [dict(runtime(), platform='iOS')]):
            with self.subTest(values=values), self.assertRaisesRegex(RuntimeError, 'No available compatible'):
                smoke.select_watch(values, '26.0', 'arm64')

    def test_newest_runtime_without_watch_type_does_not_fall_back(self):
        with self.assertRaisesRegex(RuntimeError, 'refusing older fallback'):
            smoke.select_watch([runtime('26.0'), runtime(devices=[])], '26.0', 'arm64')

    def test_missing_se_chooses_smallest_supported_watch(self):
        values = [dict(name='Apple Watch Series 12 (42mm)', productFamily='Apple Watch', identifier='small'),
                  dict(name='Apple Watch Ultra 4 (49mm)', productFamily='Apple Watch', identifier='large')]
        _, device = smoke.select_watch([runtime(devices=values)], '26.0', 'arm64')
        self.assertEqual(device['identifier'], 'small')

    def test_fixture_preserves_exact_anchor_and_explicit_stop(self):
        values = smoke.fixture(1800000000.125)
        context, intent = (json.loads(values[key]) for key in (smoke.CLASS_KEY, smoke.INTENT_KEY))
        self.assertEqual(context['initialStartPressedAt'], 1800000000.125 - smoke.REFERENCE_DATE_OFFSET)
        self.assertEqual(context['scheduledStart'], intent['classID'])
        self.assertEqual(context['durationMinutes'], 60)
        self.assertEqual(intent['state'], 'stopped')

    def test_old_launches_and_wrong_page_do_not_pass(self):
        events = complete_launch('old') + complete_launch('new', 'nowPlaying')
        self.assertIsNone(smoke.launch_evidence(events, {'old'}, 'classProgress'))
        self.assertEqual(smoke.launch_evidence(events, {'old'}, 'nowPlaying'), 'new')
        self.assertIsNone(smoke.launch_evidence(events, {'old', 'new'}, 'nowPlaying'))

    def test_missing_page_appearance_and_recovery_evidence_do_not_pass(self):
        self.assertIsNone(smoke.launch_evidence(complete_launch()[:-1], set(), 'classProgress'))
        self.assertIsNone(smoke.launch_evidence([e for e in complete_launch() if e['event'] != 'runtime_intent_restored'], set(), 'classProgress'))

    def test_unexpected_runtime_start_fails_and_multiple_launches_are_ambiguous(self):
        with self.assertRaisesRegex(AssertionError, 'Intentional Stop'):
            smoke.launch_evidence(complete_launch() + [event('start_requested')], set(), 'classProgress')
        self.assertIsNone(smoke.launch_evidence(complete_launch('one') + complete_launch('two'), set(), 'classProgress'))

    def test_saved_class_and_stop_are_checked_byte_for_byte(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            preferences = root / 'Library/Preferences' / (smoke.BUNDLE + '.plist')
            preferences.parent.mkdir(parents=True)
            expected = smoke.fixture(1800000000)
            preferences.write_bytes(plistlib.dumps(expected))
            smoke.assert_saved_state(root, expected)
            changed = dict(expected)
            changed[smoke.INTENT_KEY] = b'{"state":"running"}'
            preferences.write_bytes(plistlib.dumps(changed))
            with self.assertRaisesRegex(AssertionError, smoke.INTENT_KEY):
                smoke.assert_saved_state(root, expected)

    def test_cleanup_only_deletes_the_owned_device_even_after_shutdown_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            check = smoke.Smoke(Path('not-used.app'), Path(directory))
            with patch.object(check, 'simctl') as simctl:
                check.cleanup()
                simctl.assert_not_called()
                check.owned_device = 'owned-disposable-id'
                check.report['complete'] = True
                simctl.side_effect = [RuntimeError('shutdown failed'), '']
                check.cleanup()
                self.assertEqual([c.args for c in simctl.call_args_list],
                                 [('shutdown', 'owned-disposable-id'), ('delete', 'owned-disposable-id')])
                self.assertFalse(check.report['complete'])
                self.assertEqual(check.report['cleanup']['errors'], ['shutdown failed'])


class SmokeVerificationChecks(unittest.TestCase):
    def test_ci_runtime_preparation_precedes_smoke(self):
        spec = importlib.util.spec_from_file_location('smoke_verify_prepare', Path(__file__).resolve().parents[1] / 'scripts/verify-build.py')
        verify = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(verify)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'verify'
            with patch.object(sys, 'argv', ['verify-build.py', str(output), '--simulator-smoke', '--prepare-ci-runtime']), \
                    patch.object(verify.subprocess, 'check_output', side_effect=['a' * 40, '', 'a' * 40, '']), \
                    patch.object(verify, 'run_step', side_effect=lambda name, *args: dict(name=name, status='passed')):
                verify.main()
            report = json.loads((output / 'verification.json').read_text())
            names = [step['name'] for step in report['steps']]
            self.assertEqual(names[names.index('simulator-smoke') - 1], 'prepare-watch-runtime')
            self.assertTrue(report['hostedRuntimePreparationRequested'])

    def test_opt_in_runs_smoke_after_build_and_before_archives(self):
        spec = importlib.util.spec_from_file_location('smoke_verify', Path(__file__).resolve().parents[1] / 'scripts/verify-build.py')
        verify = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(verify)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'verify'
            with patch.object(sys, 'argv', ['verify-build.py', str(output), '--simulator-smoke']), \
                    patch.object(verify.subprocess, 'check_output', side_effect=['a' * 40, '', 'a' * 40, '']), \
                    patch.object(verify, 'run_step', side_effect=lambda name, *args: dict(name=name, status='passed')):
                verify.main()
            report = json.loads((output / 'verification.json').read_text())
            names = [step['name'] for step in report['steps']]
            self.assertEqual(names[names.index('simulator') + 1], 'simulator-smoke')
            self.assertLess(names.index('simulator-smoke'), names.index('archive'))
            self.assertTrue(report['complete'])
            self.assertTrue(report['bootedSimulatorRequested'])

    def test_smoke_failure_stops_verification_before_archiving(self):
        spec = importlib.util.spec_from_file_location('smoke_verify_fail', Path(__file__).resolve().parents[1] / 'scripts/verify-build.py')
        verify = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(verify)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'verify'
            with patch.object(sys, 'argv', ['verify-build.py', str(output), '--simulator-smoke']), \
                    patch.object(verify.subprocess, 'check_output', side_effect=['a' * 40, '', 'a' * 40, '']), \
                    patch.object(verify, 'run_step', side_effect=lambda name, *args: dict(name=name, status='failed' if name == 'simulator-smoke' else 'passed')):
                with self.assertRaisesRegex(SystemExit, 'Failed simulator-smoke'):
                    verify.main()
            report = json.loads((output / 'verification.json').read_text())
            self.assertFalse(report['complete'])
            self.assertEqual(report['steps'][-1]['name'], 'simulator-smoke')


if __name__ == '__main__':
    unittest.main()
