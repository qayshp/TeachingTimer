# SPDX-License-Identifier: MPL-2.0
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

runner_path = Path(__file__).resolve().parents[1] / 'tools/simulator-regression'
sys.path.insert(0, str(runner_path))
spec = importlib.util.spec_from_file_location('regression', runner_path / 'run.py')
regression = importlib.util.module_from_spec(spec)
spec.loader.exec_module(regression)

class CheckedCommandChecks(unittest.TestCase):
    def test_failure_exposes_helper_diagnostics_and_preserves_exception(self):
        log = io.StringIO()
        with patch.object(regression.sys, 'stderr', log):
            with self.assertRaises(subprocess.CalledProcessError) as raised:
                regression.checked(sys.executable, '-c',
                    'import sys; print("selected test simulator"); '
                    'print("Device Hub window unavailable", file=sys.stderr); sys.exit(4)')
        self.assertEqual(raised.exception.returncode, 4)
        self.assertIn('Device Hub window unavailable', raised.exception.stderr)
        self.assertIn('Device Hub window unavailable', log.getvalue())
        self.assertIn('selected test simulator', log.getvalue())

    def test_verbose_failure_keeps_bounded_tail(self):
        log = io.StringIO()
        with patch.object(regression.sys, 'stderr', log):
            with self.assertRaises(subprocess.CalledProcessError):
                regression.checked(sys.executable, '-c',
                    'import sys; print("discard-this-prefix" + "x" * 10000 + "final diagnostic", '
                    'file=sys.stderr); sys.exit(1)')
        self.assertIn('last 4096 characters', log.getvalue())
        self.assertIn('final diagnostic', log.getvalue())
        self.assertNotIn('discard-this-prefix', log.getvalue())
        self.assertLess(len(log.getvalue()), 4200)

    def test_timeout_exposes_byte_diagnostics_without_replacing_error(self):
        error = subprocess.TimeoutExpired(['fixture'], 1, output=b'partial output', stderr=b'waiting \xff')
        log = io.StringIO()
        with patch.object(regression.subprocess, 'run', side_effect=error), \
                patch.object(regression.sys, 'stderr', log):
            with self.assertRaises(subprocess.TimeoutExpired) as raised:
                regression.checked('fixture', timeout=1)
        self.assertIs(raised.exception, error)
        self.assertIn('partial output', log.getvalue())
        self.assertIn('waiting', log.getvalue())

    def test_success_returns_output_without_emitting_helper_stderr(self):
        log = io.StringIO()
        with patch.object(regression.sys, 'stderr', log):
            output = regression.checked(sys.executable, '-c',
                'import sys; print(" result "); print("routine detail", file=sys.stderr)')
        self.assertEqual(output, 'result')
        self.assertEqual(log.getvalue(), '')

class SimulatorRegressionChecks(unittest.TestCase):
    def test_only_running_native_view_service_is_selected(self):
        label = 'UIKitApplication:com.apple.NanoNowPlayingViewService[123]'
        self.assertEqual(regression.select_service(f'- 0 {label}\n12 0 unrelated\n42 0 {label}'), label)
    def test_missing_service_is_rejected(self):
        with self.assertRaises(ValueError):
            regression.select_service('42 0 com.qayshp.TeachingTimer')
    def test_ambiguous_service_is_rejected(self):
        with self.assertRaises(ValueError):
            regression.select_service('42 0 UIKitApplication:com.apple.NanoNowPlayingViewService[a]\n43 0 UIKitApplication:com.apple.NanoNowPlayingViewService[b]')


class MediaResultChecks(unittest.TestCase):
    def test_helper_compile_failure_writes_review_result_before_exit_two(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(regression, 'checked', side_effect=RuntimeError('compiler unavailable')), \
                patch.object(regression.sys, 'stdout', io.StringIO()):
            with self.assertRaises(SystemExit) as raised:
                regression.finish_result(Path(folder), 'media', {'sameClassBytes': True})
            self.assertEqual(raised.exception.code, 2)
            result = json.loads((Path(folder) / 'result.json').read_text())
            self.assertEqual(result['checks'], {'sameClassBytes': True})
            self.assertEqual(result['visualResult'], 'VISUAL_REVIEW_REQUIRED')
            self.assertIs(result['mediaVisualReviewRequired'], True)
            self.assertEqual(len(result['mediaPixelEvidence']), 3)
            self.assertTrue(all('compiler unavailable' in r['error'] for r in result['mediaPixelEvidence']))

    def test_measurement_errors_remain_saved_review_failures(self):
        from media_evidence import DELAYED_MEDIA_CAPTURES
        failures = (subprocess.CalledProcessError(2, ['media-pixels']),
                    subprocess.TimeoutExpired(['media-pixels'], 30), 'invalid JSON',
                    '{"visibleFraction": NaN}')
        for failure in failures:
            with self.subTest(failure=str(failure)), tempfile.TemporaryDirectory() as folder, \
                    patch.object(regression.sys, 'stdout', io.StringIO()):
                root = Path(folder)
                for name in DELAYED_MEDIA_CAPTURES:
                    (root / name).write_bytes(b'original fixture')
                def command(*args, **kwargs):
                    if args[0] == 'swiftc':
                        return ''
                    if isinstance(failure, Exception):
                        raise failure
                    return failure
                with patch.object(regression, 'checked', side_effect=command):
                    with self.assertRaises(SystemExit) as raised:
                        regression.finish_result(root, 'media', {'sameClassBytes': True})
                self.assertEqual(raised.exception.code, 2)
                result = json.loads((root / 'result.json').read_text())
                self.assertIs(result['mediaVisualReviewRequired'], True)
                self.assertEqual(len(result['mediaPixelEvidence']), 3)
                self.assertTrue(result['mediaVisualErrors'])
                json.dumps(result, allow_nan=False)

    def test_blank_delayed_original_writes_metrics_and_lifecycle_results_before_failure(self):
        from media_evidence import DELAYED_MEDIA_CAPTURES, PIXEL_REGION
        with tempfile.TemporaryDirectory() as folder, patch.object(regression.sys, 'stdout', io.StringIO()):
            root = Path(folder)
            for name in DELAYED_MEDIA_CAPTURES:
                (root / name).write_bytes(('fixture ' + name).encode())
            def command(*args, **kwargs):
                if args[0] == 'swiftc':
                    return ''
                blank = Path(args[1]).name == DELAYED_MEDIA_CAPTURES[1]
                return json.dumps(dict(width=324, height=394, region=PIXEL_REGION,
                    visibleFraction=0 if blank else .04, brightFraction=0,
                    meanChannelMaximum=0 if blank else .01, peakChannel=0 if blank else 1))
            with patch.object(regression, 'checked', side_effect=command):
                with self.assertRaises(SystemExit) as raised:
                    regression.finish_result(root, 'media', {'sameClassBytes': True, 'noNewVolumeControl': True})
            self.assertEqual(raised.exception.code, 2)
            result = json.loads((root / 'result.json').read_text())
            self.assertTrue(all(result['checks'].values()))
            self.assertEqual(result['mediaPixelEvidence'][1]['pixels']['visibleFraction'], 0)
            self.assertEqual(len(result['mediaVisualErrors']), 1)
            self.assertIn('04b-media-return-after-five-seconds.png', result['mediaVisualErrors'][0])

    def test_focus_keeps_existing_assertions_without_media_measurement(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(regression, 'media_pixel_evidence') as measure, \
                patch.object(regression.sys, 'stdout', io.StringIO()):
            regression.finish_result(Path(folder), 'focus', {'sameClassBytes': True})
            measure.assert_not_called()
            result = json.loads((Path(folder) / 'result.json').read_text())
            self.assertNotIn('mediaPixelEvidence', result)
            with self.assertRaises(SystemExit):
                regression.finish_result(Path(folder), 'focus', {'sameClassBytes': False})

class JournalBoundaryChecks(unittest.TestCase):
    def test_retention_does_not_hide_new_events(self):
        first, last, new = {'event': 'first'}, {'event': 'last'}, {'event': 'new'}
        self.assertEqual(regression.events_after([first, last], [last, new]), [new])
    def test_lost_or_duplicate_boundary_is_not_success(self):
        event = {'event': 'old'}
        with self.assertRaises(ValueError):
            regression.events_after([event], [{'event': 'new'}])
        with self.assertRaises(ValueError):
            regression.events_after([event], [event, event])
    def test_empty_baseline_means_fresh_journal(self):
        self.assertEqual(regression.events_after([], [{'event': 'new'}]), [{'event': 'new'}])

class FreshResetChecks(unittest.TestCase):
    @staticmethod
    def convert_plist_to_json(command, **kwargs):
        import json
        import plistlib
        from types import SimpleNamespace
        if command[0] != 'plutil':
            raise AssertionError(f'Unexpected subprocess call: {command}')
        value = plistlib.loads(kwargs['input'].encode())
        return SimpleNamespace(stdout=json.dumps(value))

    def test_failed_uninstall_propagates_and_does_not_continue(self):
        import plistlib
        from unittest.mock import patch
        with patch.object(regression.subprocess, 'run', side_effect=self.convert_plist_to_json), \
                patch.object(regression, 'checked', side_effect=[plistlib.dumps({'app': {}}).decode(), RuntimeError('failed')]) as command:
            with self.assertRaises(RuntimeError):
                regression.reset_test_app('disposable', 'app')
            self.assertEqual(command.call_count, 2)
    def test_existing_app_requires_confirmed_removal(self):
        import plistlib
        from unittest.mock import patch
        installed = plistlib.dumps({'app': {}}).decode()
        with patch.object(regression.subprocess, 'run', side_effect=self.convert_plist_to_json), \
                patch.object(regression, 'checked', side_effect=[installed, '', installed]):
            with self.assertRaises(RuntimeError):
                regression.reset_test_app('disposable', 'app')
    def test_absent_app_skips_uninstall(self):
        import plistlib
        from unittest.mock import patch
        with patch.object(regression.subprocess, 'run', side_effect=self.convert_plist_to_json), \
                patch.object(regression, 'checked', return_value=plistlib.dumps({}).decode()) as command:
            regression.reset_test_app('disposable', 'app')
            self.assertTrue(all('uninstall' not in args.args for args in command.call_args_list))

    def test_real_plutil_accepts_simctl_openstep_inventory(self):
        import shutil
        from unittest.mock import patch
        if not shutil.which('plutil'):
            self.skipTest('Apple plist converter is macOS-only')
        openstep = '{ "com.qayshp.TeachingTimer" = { CFBundleVersion = 22; }; }'
        with patch.object(regression, 'checked', side_effect=[openstep, '', '{}']) as command:
            regression.reset_test_app('disposable', 'com.qayshp.TeachingTimer')
            self.assertIn('uninstall', command.call_args_list[1].args)
