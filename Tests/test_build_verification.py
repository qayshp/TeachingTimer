# SPDX-License-Identifier: MPL-2.0
import importlib.util
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('verify_build', Path(__file__).resolve().parents[1] / 'scripts/verify-build.py')
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)

class BuildEvidenceChecks(unittest.TestCase):
    def run_verification(self, before=None, after=None, environment=None, failed_stage=None):
        before = before or ('a' * 40, False)
        after = after or before
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'verification'

            def run_step(name, command, output):
                failed = name == failed_stage
                return dict(name=name, command=command, status='failed' if failed else 'passed',
                            exitCode=7 if failed else 0, elapsedSeconds=0.01)

            with patch.object(sys, 'argv', ['verify-build.py', str(output), '--simulator-smoke', '--prepare-ci-runtime']), \
                    patch.dict(os.environ, environment or {}, clear=True), \
                    patch.object(build, 'source_state', side_effect=[before, after]) as source_state, \
                    patch.object(build, 'run_step', side_effect=run_step) as step, \
                    redirect_stdout(io.StringIO()):
                error = None
                try:
                    build.main()
                except SystemExit as stopped:
                    error = str(stopped)
            report = json.loads((output / 'verification.json').read_text())
            self.assertEqual(source_state.call_count, 2)
            return report, error, step.call_count

    def test_clean_source_before_and_after_produces_complete_v2_report(self):
        report, error, count = self.run_verification()
        self.assertIsNone(error)
        self.assertEqual(report['schemaVersion'], 2)
        self.assertEqual(report['revision'], 'a' * 40)
        self.assertEqual(report['sourceRevisionAfter'], report['revision'])
        self.assertIs(report['sourceDirty'], False)
        self.assertIs(report['sourceDirtyAfter'], False)
        self.assertIs(report['complete'], True)
        self.assertEqual(count, 17)
        self.assertNotIn('ci', report)

    def test_dirty_start_cannot_produce_success_even_if_final_source_is_clean(self):
        report, error, count = self.run_verification(before=('a' * 40, True), after=('a' * 40, False))
        self.assertIn('clean source checkout', error)
        self.assertEqual(count, 0)
        self.assertIs(report['sourceDirty'], True)
        self.assertIs(report['sourceDirtyAfter'], False)
        self.assertIs(report['complete'], False)

    def test_dirty_end_rejects_all_otherwise_successful_steps(self):
        report, error, count = self.run_verification(after=('a' * 40, True))
        self.assertIn('clean and unchanged', error)
        self.assertEqual(count, 17)
        self.assertTrue(all(step['status'] == 'passed' for step in report['steps']))
        self.assertIs(report['sourceDirtyAfter'], True)
        self.assertIs(report['complete'], False)

    def test_changed_head_rejects_a_clean_checkout_at_the_wrong_revision(self):
        report, error, count = self.run_verification(after=('b' * 40, False))
        self.assertIn('clean and unchanged', error)
        self.assertEqual(count, 17)
        self.assertEqual(report['sourceRevisionAfter'], 'b' * 40)
        self.assertIs(report['sourceDirtyAfter'], False)
        self.assertIs(report['complete'], False)

    def test_final_git_failure_is_not_success(self):
        report, error, count = self.run_verification(after=OSError('Git unavailable'))
        self.assertIn('clean and unchanged', error)
        self.assertEqual(count, 17)
        self.assertIsNone(report['sourceRevisionAfter'])
        self.assertIsNone(report['sourceDirtyAfter'])
        self.assertEqual(report['sourceVerificationError'], 'OSError')
        self.assertIs(report['complete'], False)

    def test_failed_stage_keeps_its_diagnostic_when_final_git_also_fails(self):
        report, error, count = self.run_verification(after=OSError('Git unavailable'), failed_stage='xcode')
        self.assertIn('Failed xcode', error)
        self.assertEqual(count, 1)
        self.assertEqual(report['steps'][0]['exitCode'], 7)
        self.assertEqual(report['steps'][0]['status'], 'failed')
        self.assertEqual(report['sourceVerificationError'], 'OSError')
        self.assertIs(report['complete'], False)

    def test_ci_metadata_uses_exact_github_environment_identity(self):
        environment = {
            'GITHUB_ACTIONS': 'true', 'GITHUB_REPOSITORY': 'qayshp/TeachingTimer',
            'GITHUB_REPOSITORY_ID': '1234',
            'GITHUB_WORKFLOW_REF': 'qayshp/TeachingTimer/.github/workflows/check.yml@refs/heads/main',
            'GITHUB_WORKFLOW_SHA': 'c' * 40,
            'GITHUB_RUN_ID': '5678', 'GITHUB_RUN_ATTEMPT': '2',
            'GITHUB_EVENT_NAME': 'push', 'GITHUB_REF': 'refs/heads/main',
            'GITHUB_SHA': 'd' * 40,
        }
        report, error, _ = self.run_verification(environment=environment)
        self.assertIsNone(error)
        self.assertEqual(report['ci'], {
            'repository': 'qayshp/TeachingTimer', 'repositoryID': '1234',
            'workflowRef': environment['GITHUB_WORKFLOW_REF'], 'workflowSHA': 'c' * 40,
            'runID': '5678', 'runAttempt': '2', 'event': 'push', 'ref': 'refs/heads/main',
        })
        self.assertEqual(report['revision'], 'a' * 40)

    def test_local_runs_do_not_claim_github_identity(self):
        for value in ('', 'false', 'True'):
            with self.subTest(github_actions=value):
                report, error, _ = self.run_verification(environment={
                    'GITHUB_ACTIONS': value, 'GITHUB_RUN_ID': '1234',
                })
                self.assertIsNone(error)
                self.assertNotIn('ci', report)

    def test_outline_regression_runs_before_slow_simulator_checks(self):
        output = Path('/synthetic/evidence')
        steps = build.verification_steps(output)
        names = [name for name, _ in steps]
        self.assertLess(names.index('control-outline-smoke'), names.index('simulator'))
        self.assertEqual(dict(steps)['control-outline-smoke'], [
            'sh', 'scripts/check-control-outline.sh', str(output / 'control-outline-smoke')])

    def test_real_ocr_check_runs_after_helper_compilation(self):
        output = Path('/synthetic/evidence')
        steps = build.verification_steps(output)
        names = [name for name, _ in steps]
        self.assertEqual(names.index('screen-text-smoke'), names.index('simulator-tools') + 1)
        self.assertEqual(dict(steps)['screen-text-smoke'], [
            str(output / 'simulator-tools/check-screen-text'),
            str(output / 'simulator-tools/ScreenText'), str(output / 'screen-text-smoke')])

    def test_companion_simulator_build_uses_per_target_sdk_selection(self):
        steps = dict(build.verification_steps(Path('/synthetic/evidence')))
        command = steps['companion-simulator']
        self.assertIn('TeachingTimerTestFlight', command)
        self.assertIn('generic/platform=iOS Simulator', command)
        self.assertNotIn('-sdk', command, 'A global iPhone SDK breaks the embedded Watch target')
        self.assertIn('CODE_SIGNING_ALLOWED=NO', command)
        self.assertIn('simulator', steps)
        self.assertIn('distribution-rehearsal', steps)

    def test_failure_preserves_diagnostic_and_exit_code(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            result = build.run_step('failure', [sys.executable, '-c', 'print("compile diagnostic"); raise SystemExit(7)'], root)
            self.assertEqual(result['status'], 'failed')
            self.assertEqual(result['exitCode'], 7)
            self.assertIn('compile diagnostic', (root / 'failure.log').read_text())
    def test_missing_command_and_timeout_are_not_success(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.assertEqual(build.run_step('missing', ['/nonexistent/teachingtimer-test'], root)['status'], 'failed')
            result = build.run_step('timeout', [sys.executable, '-c', 'import time; time.sleep(5)'], root, timeout=.05)
            self.assertEqual(result['error'], 'TimeoutExpired')
            self.assertEqual(result['status'], 'failed')

inspect_spec = importlib.util.spec_from_file_location('inspect_artifact', Path(__file__).resolve().parents[1] / 'scripts/inspect-artifact.py')
artifact = importlib.util.module_from_spec(inspect_spec)
inspect_spec.loader.exec_module(artifact)

class ArtifactChecks(unittest.TestCase):
    def test_privacy_manifest_requires_reviewed_policy_and_valid_schema(self):
        root = Path(__file__).resolve().parents[1]
        reviewed = plistlib.loads((root / 'TeachingTimer/PrivacyInfo.xcprivacy').read_bytes())
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder)
            path = app / 'PrivacyInfo.xcprivacy'
            path.write_bytes(plistlib.dumps(reviewed))
            self.assertTrue(artifact.privacy_manifest_matches_policy(app))
            reordered = dict(reviewed, NSPrivacyAccessedAPITypes=list(reversed(reviewed['NSPrivacyAccessedAPITypes'])))
            path.write_bytes(plistlib.dumps(reordered, fmt=plistlib.FMT_BINARY))
            self.assertTrue(artifact.privacy_manifest_matches_policy(app))
            cases = [
                [],
                {key: value for key, value in reviewed.items() if key != 'NSPrivacyTracking'},
                dict(reviewed, NSPrivacyTracking=True),
                dict(reviewed, NSPrivacyTracking=0),
                dict(reviewed, NSPrivacyTrackingDomains=['example.invalid']),
                dict(reviewed, NSPrivacyCollectedDataTypes=[{}]),
                dict(reviewed, NSPrivacyCollectedDataTypes={}),
                dict(reviewed, NSPrivacyAccessedAPITypes={}),
                dict(reviewed, NSPrivacyAccessedAPITypes=[]),
                dict(reviewed, NSPrivacyAccessedAPITypes=[reviewed['NSPrivacyAccessedAPITypes'][0]] * 2),
                dict(reviewed, unexpectedKey=[]),
            ]
            for field, value in [('NSPrivacyAccessedAPITypeReasons', []),
                                 ('NSPrivacyAccessedAPITypeReasons', 'CA92.1'),
                                 ('NSPrivacyAccessedAPITypeReasons', ['1C8F.1']),
                                 ('NSPrivacyAccessedAPITypeReasons', ['CA92.1', 'CA92.1']),
                                 ('NSPrivacyAccessedAPIType', 'NSPrivacyAccessedAPICategoryDiskSpace'),
                                 ('unexpectedKey', [])]:
                entries = [dict(item) for item in reviewed['NSPrivacyAccessedAPITypes']]
                entries[0][field] = value
                cases.append(dict(reviewed, NSPrivacyAccessedAPITypes=entries))
            for index, invalid in enumerate(cases):
                with self.subTest(case=index):
                    path.write_bytes(plistlib.dumps(invalid))
                    self.assertFalse(artifact.privacy_manifest_matches_policy(app))

    def test_archive_rejects_missing_or_malformed_bundled_privacy_manifest(self):
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'TeachingTimer.xcarchive'
            app = archive / 'Products/Applications/TeachingTimer.app'
            app.mkdir(parents=True)
            info = dict(CFBundleIdentifier='com.qayshp.TeachingTimer', CFBundleShortVersionString='1.0',
                        CFBundleVersion='31', CFBundleExecutable='TeachingTimer', WKWatchOnly=True)
            (app / 'Info.plist').write_bytes(plistlib.dumps(info))
            (app / 'TeachingTimer').touch()
            (app / 'BuildInfo.plist').write_bytes(plistlib.dumps({'revision': 'abcdef'}))
            shutil.copytree(root / 'TeachingTimer/Information', app / 'Information')
            shutil.copy2(root / 'LICENSE', app / 'LICENSE')
            shutil.copy2(root / 'docs/PRIVACY.md', app / 'PRIVACY.md')
            manifest = app / 'PrivacyInfo.xcprivacy'
            cases = [None, b'not a plist', b'<?xml version="1.0"?><plist><dict>',
                     plistlib.dumps({'NSPrivacyTracking': False}),
                     (root / 'TeachingTimer/PrivacyInfo.xcprivacy').read_bytes()]
            for index, contents in enumerate(cases):
                with self.subTest(case=index):
                    if contents is not None:
                        manifest.write_bytes(contents)
                    with patch.object(artifact, 'command', return_value=subprocess.CompletedProcess(
                            [], 0, b'UUID: FIXTURE (arm64) fixture\n', b'')):
                        result = artifact.inspect(archive)
                    expected = index == len(cases) - 1
                    self.assertEqual(result['checks']['privacyManifestMatchesPolicy'], expected)
                    self.assertEqual(all(result['checks'].values()), expected)
                    self.assertTrue(all(value for key, value in result['checks'].items()
                                        if key != 'privacyManifestMatchesPolicy'))

    def test_information_pages_require_documents_and_qr_assets(self):
        import shutil
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder)
            self.assertFalse(artifact.information_resources_present(app))
            shutil.copytree(root / 'TeachingTimer/Information', app / 'Information')
            shutil.copy2(root / 'LICENSE', app / 'LICENSE')
            shutil.copy2(root / 'docs/PRIVACY.md', app / 'PRIVACY.md')
            self.assertTrue(artifact.information_resources_present(app))
            (app / 'Information/support.png').unlink()
            self.assertFalse(artifact.information_resources_present(app))

    def test_information_page_rejects_broken_metadata(self):
        import shutil
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder)
            shutil.copytree(root / 'TeachingTimer/Information', app / 'Information')
            shutil.copy2(root / 'LICENSE', app / 'LICENSE')
            shutil.copy2(root / 'docs/PRIVACY.md', app / 'PRIVACY.md')
            (app / 'Information/WebLinks.json').write_text('{broken')
            self.assertFalse(artifact.information_resources_present(app))

    def test_unsigned_simulator_does_not_become_signed_release(self):
        import plistlib
        from unittest.mock import patch
        import subprocess
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder) / 'TeachingTimer.app'
            app.mkdir()
            info = dict(CFBundleIdentifier='com.qayshp.TeachingTimer', CFBundleShortVersionString='1.0',
                        CFBundleVersion='18', CFBundleExecutable='TeachingTimer', WKWatchOnly=True)
            (app / 'Info.plist').write_bytes(plistlib.dumps(info))
            (app / 'TeachingTimer').touch()
            (app / 'BuildInfo.plist').write_bytes(plistlib.dumps({'revision': 'abcdef-dirty'}))
            shutil.copy2(Path(__file__).resolve().parents[1] / 'TeachingTimer/PrivacyInfo.xcprivacy',
                         app / 'PrivacyInfo.xcprivacy')
            with patch.object(artifact, 'command', return_value=subprocess.CompletedProcess([], 1, b'', b'')):
                result = artifact.inspect(app)
            self.assertTrue(all(result['checks'].values()))
            self.assertFalse(result['signatureValid'])
            self.assertFalse(result['unexpiredEmbeddedProfile'])
            self.assertEqual(result['revision'], 'abcdef-dirty')
            self.assertEqual(result['distributionValidation'], 'not performed')

class RevisionMetadataChecks(unittest.TestCase):
    def test_untracked_source_marks_dirty_but_ignored_artifacts_do_not(self):
        import os
        import plistlib
        import subprocess
        if not Path('/usr/libexec/PlistBuddy').is_file():
            self.skipTest('Xcode build metadata writer is macOS-only')
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            repo = root / 'source'
            repo.mkdir()
            def git(*args):
                return subprocess.check_output(['git', '-C', str(repo), *args], stderr=subprocess.DEVNULL, text=True).strip()
            git('init')
            (repo / '.gitignore').write_text('work/\n')
            git('add', '.gitignore')
            git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-m', 'fixture')
            env = dict(os.environ, SRCROOT=str(repo), TARGET_BUILD_DIR=str(root / 'product'), UNLOCALIZED_RESOURCES_FOLDER_PATH='TeachingTimer.app')
            env.pop('SOURCE_REVISION', None)
            script = Path(__file__).resolve().parents[1] / 'scripts/build-metadata.sh'
            def metadata():
                subprocess.run(['sh', str(script)], env=env, check=True, capture_output=True)
                return plistlib.loads((root / 'product/TeachingTimer.app/BuildInfo.plist').read_bytes())['revision']
            self.assertEqual(metadata(), git('rev-parse', '--short=12', 'HEAD'))
            (repo / 'work').mkdir()
            (repo / 'work/artifact').touch()
            self.assertFalse(metadata().endswith('-dirty'))
            (repo / 'NewSource.swift').touch()
            self.assertTrue(metadata().endswith('-dirty'))
