# SPDX-License-Identifier: MPL-2.0
import importlib.util
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
