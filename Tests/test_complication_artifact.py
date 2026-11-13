# SPDX-License-Identifier: MPL-2.0
"""Structural archive checks for the Watch launcher, including older checkpoints."""
from contextlib import redirect_stdout
import importlib.util
import io
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('complication_artifact', ROOT / 'scripts/inspect-artifact.py')
artifact = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artifact)


class ComplicationArtifactChecks(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.app = Path(self.folder.name) / 'TeachingTimer.app'
        self.app.mkdir()
        self.watch = dict(CFBundleIdentifier='com.qayshp.TeachingTimer', CFBundleShortVersionString='1.0',
                          CFBundleVersion='18', CFBundleExecutable='TeachingTimer', WKWatchOnly=True,
                          MinimumOSVersion='26.0')
        (self.app / 'Info.plist').write_bytes(plistlib.dumps(self.watch))
        (self.app / 'TeachingTimer').write_bytes(b'fixture')
        (self.app / 'BuildInfo.plist').write_bytes(plistlib.dumps({'revision': 'fixture-source'}))
        shutil.copy2(ROOT / 'TeachingTimer/PrivacyInfo.xcprivacy', self.app / 'PrivacyInfo.xcprivacy')
        self.extension = self.app / 'PlugIns/TeachingTimerComplications.appex'
        self.info = dict(CFBundleIdentifier='com.qayshp.TeachingTimer.complications',
                         CFBundleShortVersionString='1.0', CFBundleVersion='18',
                         CFBundleExecutable='TeachingTimerComplications', CFBundlePackageType='XPC!',
                         MinimumOSVersion='26.0', CFBundleSupportedPlatforms=['WatchOS'],
                         NSExtension={'NSExtensionPointIdentifier': 'com.apple.widgetkit-extension'})

    def write_extension(self, info=None):
        self.extension.mkdir(parents=True, exist_ok=True)
        (self.extension / 'Info.plist').write_bytes(plistlib.dumps(self.info if info is None else info))
        (self.extension / 'TeachingTimerComplications').write_bytes(b'fixture')
        (self.extension / 'Assets.car').write_bytes(b'compiled-asset-fixture')

    def inspect(self, required=False):
        with patch.object(artifact, 'command', return_value=subprocess.CompletedProcess([], 1, b'', b'')):
            return artifact.inspect(self.app, require_complication=required)

    def test_historical_app_without_extension_remains_inspectable(self):
        self.assertTrue(all(self.inspect()['checks'].values()))
        checks = self.inspect(required=True)['checks']
        self.assertFalse(checks['complicationPresent'])
        self.assertFalse(all(checks.values()))

    def test_valid_development_distribution_and_simulator_complications(self):
        for identifier in ('com.qayshp.TeachingTimer', 'net.qays.TeachingTimer.watchkitapp'):
            for platform in ('WatchOS', 'WatchSimulator'):
                with self.subTest(identifier=identifier, platform=platform):
                    self.watch['CFBundleIdentifier'] = identifier
                    info = dict(self.info, CFBundleIdentifier=identifier + '.complications',
                                CFBundleSupportedPlatforms=[platform])
                    self.write_extension(info)
                    self.assertTrue(all(artifact.complication_checks(self.app, self.watch, required=True).values()))

    def test_existing_extension_is_checked_even_without_required_flag(self):
        self.write_extension(dict(self.info, CFBundleIdentifier='wrong.example'))
        self.assertFalse(self.inspect()['checks']['complicationIdentifier'])

    def test_historical_symbol_launcher_does_not_require_asset_catalog_by_default(self):
        self.write_extension()
        (self.extension / 'Assets.car').unlink()
        checks = self.inspect()['checks']
        self.assertNotIn('complicationAssetCatalogPresent', checks)
        self.assertTrue(all(checks.values()))
        self.assertFalse(self.inspect(required=True)['checks']['complicationAssetCatalogPresent'])

    def test_malformed_or_missing_extension_metadata_is_a_failed_check(self):
        self.write_extension()
        path = self.extension / 'Info.plist'
        for contents in (None, b'broken', b'<?xml version="1.0"?><plist><dict>', plistlib.dumps([])):
            with self.subTest(contents=contents):
                if contents is None:
                    path.unlink(missing_ok=True)
                else:
                    path.write_bytes(contents)
                self.assertFalse(self.inspect()['checks']['complicationMetadataValid'])

    def test_wrong_identity_versions_platform_type_or_minimum_os_fail(self):
        cases = [
            ('CFBundleIdentifier', self.watch['CFBundleIdentifier'], 'complicationIdentifier'),
            ('CFBundleShortVersionString', '2.0', 'complicationVersionsMatch'),
            ('CFBundleVersion', '19', 'complicationVersionsMatch'),
            ('CFBundlePackageType', 'APPL', 'complicationPackageType'),
            ('CFBundleSupportedPlatforms', ['iPhoneOS'], 'complicationPlatform'),
            ('NSExtension', {'NSExtensionPointIdentifier': 'other.extension'}, 'complicationExtensionPoint'),
            ('NSExtension', 'com.apple.widgetkit-extension', 'complicationExtensionPoint'),
            ('MinimumOSVersion', '25.0', 'complicationMinimumOS'),
            ('MinimumOSVersion', '27.0', 'complicationMinimumOS'),
            ('MinimumOSVersion', 'invalid', 'complicationMinimumOS'),
            ('CFBundleExecutable', '../TeachingTimer', 'complicationBinaryPresent'),
            ('CFBundleExecutable', '', 'complicationBinaryPresent'),
        ]
        for field, value, check in cases:
            with self.subTest(field=field, value=value):
                self.write_extension(dict(self.info, **{field: value}))
                self.assertFalse(self.inspect()['checks'][check])

    def test_missing_binary_and_unexpected_extension_fail(self):
        self.write_extension()
        (self.extension / 'TeachingTimerComplications').unlink()
        self.assertFalse(self.inspect()['checks']['complicationBinaryPresent'])
        (self.app / 'PlugIns/Unexpected.appex').mkdir()
        self.assertFalse(self.inspect()['checks']['complicationOnlyExpectedExtension'])

    def test_missing_empty_or_directory_asset_catalog_fails(self):
        self.write_extension()
        catalog = self.extension / 'Assets.car'
        catalog.unlink()
        self.assertFalse(self.inspect(required=True)['checks']['complicationAssetCatalogPresent'])
        catalog.touch()
        self.assertFalse(self.inspect()['checks']['complicationAssetCatalogPresent'])
        catalog.unlink()
        catalog.mkdir()
        self.assertFalse(self.inspect()['checks']['complicationAssetCatalogPresent'])

    def test_symlink_asset_catalog_fails_even_when_destination_is_valid(self):
        self.write_extension()
        catalog = self.extension / 'Assets.car'
        contents = catalog.read_bytes()
        catalog.unlink()
        for destination in (self.extension / 'actual-assets.car',
                            Path(self.folder.name) / 'outside-assets.car'):
            with self.subTest(destination=destination.name):
                destination.write_bytes(contents)
                catalog.symlink_to(destination)
                self.assertFalse(self.inspect()['checks']['complicationAssetCatalogPresent'])
                catalog.unlink()

    def test_symlink_outside_app_is_not_accepted_as_embedded_extension(self):
        outside = Path(self.folder.name) / 'Outside.appex'
        outside.mkdir()
        self.extension.parent.mkdir()
        self.extension.symlink_to(outside, target_is_directory=True)
        self.assertFalse(self.inspect()['checks']['complicationContainedInWatchApp'])

    def test_current_archive_cli_requires_complication_when_requested(self):
        with patch.object(sys, 'argv', ['inspect-artifact.py', str(self.app), '--require-complication']), \
                patch.object(artifact, 'command', return_value=subprocess.CompletedProcess([], 1, b'', b'')), \
                redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as stopped:
                artifact.main()
        self.assertEqual(stopped.exception.code, 1)


if __name__ == '__main__':
    unittest.main()
