# SPDX-License-Identifier: MPL-2.0
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('verify_build', Path(__file__).resolve().parents[1] / 'scripts/verify-build.py')
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)

class BuildEvidenceChecks(unittest.TestCase):
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
