# SPDX-License-Identifier: MPL-2.0
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('regression', Path(__file__).resolve().parents[1] / 'tools/simulator-regression/run.py')
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
