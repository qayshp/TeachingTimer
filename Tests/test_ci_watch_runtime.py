# SPDX-License-Identifier: MPL-2.0
import importlib.util
import json
import re
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('ci_watch_runtime', Path(__file__).resolve().parents[1] / 'scripts/prepare-ci-watch-runtime.py')
runtime = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runtime)


def watch(version='27.2', available=True):
    return dict(version=version, buildversion='24S118', isAvailable=available, platform='watchOS',
                supportedArchitectures=['arm64'], identifier='watchOS-' + version,
                supportedDeviceTypes=[dict(name='Apple Watch SE 3 (40mm)', productFamily='Apple Watch', identifier='se')])


class CIWatchRuntimeChecks(unittest.TestCase):
    def test_pr_verification_uses_release_toolchain_and_preserves_real_smoke(self):
        root = Path(__file__).resolve().parents[1]
        workflows = [(root / '.github/workflows' / name).read_text()
                     for name in ('check.yml', 'testflight-release.yml')]
        verify = [re.search(r'^  verify:\n(.*?)(?=^  [a-z][\w-]*:|\Z)', text,
                            re.M | re.S).group(1) for text in workflows]
        runners = [re.search(r'runs-on: (.+)', text).group(1) for text in verify]
        self.assertEqual(runners, ['xcode-27', 'xcode-27'])
        for text in verify:
            self.assertIn('--simulator-smoke --prepare-ci-runtime', text)
            self.assertNotIn('continue-on-error', text)

    def test_refuses_local_self_hosted_and_non_temporary_output(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'evidence'
            for environment in ({}, {'GITHUB_ACTIONS': 'true'},
                                {'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'self-hosted'}):
                with self.subTest(environment=environment), self.assertRaisesRegex(ValueError, 'GitHub-hosted'):
                    runtime.hosted_output(output, environment)
            environment = dict(GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted', RUNNER_TEMP=folder)
            runtime.hosted_output(output, environment)
            with self.assertRaisesRegex(ValueError, 'RUNNER_TEMP'):
                runtime.hosted_output(Path(folder).parent / 'elsewhere', environment)

    def test_matching_usable_runtime_needs_no_download(self):
        calls = []
        def execute(name, command, timeout):
            calls.append(command)
            return '27.2\n' if name == 'sdk-version' else json.dumps({'runtimes': [watch()]})
        result = runtime.prepare(execute, 'arm64')
        self.assertFalse(result['downloaded'])
        self.assertEqual(len(calls), 2)

    def test_missing_or_older_runtime_gets_one_bounded_sdk_matched_download(self):
        calls = []
        def execute(name, command, timeout):
            calls.append((name, command, timeout))
            if name == 'sdk-version': return '27.2'
            if name == 'runtimes-before': return json.dumps({'runtimes': [watch('27.0')]})
            if name == 'runtimes-after': return json.dumps({'runtimes': [watch()]})
            return 'Downloaded and installed'
        result = runtime.prepare(execute, 'arm64')
        self.assertTrue(result['downloaded'])
        self.assertEqual(calls[2], ('download-watch-runtime', ['xcodebuild', '-downloadPlatform', 'watchOS',
                                                              '-buildVersion', '27.2', '-architectureVariant', 'arm64'], 600))
        self.assertEqual(len(calls), 4)

    def test_successful_command_without_runnable_runtime_is_failure(self):
        def execute(name, command, timeout):
            if name == 'sdk-version': return '27.2'
            return json.dumps({'runtimes': [watch(available=False)]})
        with self.assertRaisesRegex(RuntimeError, 'refusing to skip smoke'):
            runtime.prepare(execute, 'arm64')

    def test_download_failure_is_not_retried_or_treated_as_success(self):
        calls = []
        def execute(name, command, timeout):
            calls.append(name)
            if name == 'sdk-version': return '27.2'
            if name == 'download-watch-runtime': raise RuntimeError('download timeout')
            return json.dumps({'runtimes': []})
        with self.assertRaisesRegex(RuntimeError, 'download timeout'):
            runtime.prepare(execute, 'arm64')
        self.assertEqual(calls, ['sdk-version', 'runtimes-before', 'download-watch-runtime'])

    def test_invalid_sdk_output_fails_before_download(self):
        calls = []
        def execute(name, command, timeout):
            calls.append(name)
            return 'SDK unavailable'
        with self.assertRaisesRegex(ValueError, 'numeric version'):
            runtime.prepare(execute, 'arm64')
        self.assertEqual(calls, ['sdk-version'])


if __name__ == '__main__':
    unittest.main()
