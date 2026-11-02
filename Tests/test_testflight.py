# SPDX-License-Identifier: MPL-2.0
from datetime import datetime, timedelta
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('pilot', ROOT / 'scripts/prepare-testflight.py')
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


class TestFlightChecks(unittest.TestCase):
    def package(self):
        container = dict(CFBundleIdentifier=pilot.CONTAINER_ID, CFBundleVersion='28', CFBundleShortVersionString='1.0')
        watch = dict(container, CFBundleIdentifier=pilot.WATCH_ID, WKWatchOnly=True,
                     WKApplication=True, WKBackgroundModes=['mindfulness'])
        return container, watch

    def profile(self):
        return dict(TeamIdentifier=['TEAM'], ExpirationDate=datetime.now() + timedelta(days=30),
                    Entitlements={'application-identifier': 'TEAM.' + pilot.WATCH_ID,
                                  'get-task-allow': False, 'beta-reports-active': True})

    def test_only_separate_distribution_identity_is_accepted(self):
        container, watch = self.package()
        self.assertTrue(all(pilot.package_checks(container, watch).values()))
        watch['CFBundleIdentifier'] = 'com.qayshp.TeachingTimer'
        self.assertFalse(pilot.package_checks(container, watch)['watchIdentifier'])

    def test_incompatible_package_is_rejected(self):
        container, watch = self.package()
        watch.update(CFBundleVersion='27', WKCompanionAppBundleIdentifier=pilot.CONTAINER_ID,
                     WKWatchOnly=False, WKBackgroundModes=[])
        checks = pilot.package_checks(container, watch)
        for key in ('versionsMatch', 'noCompanionRequirement', 'watchOnly', 'mindfulnessRuntime'):
            self.assertFalse(checks[key], key)

    def test_app_store_profile_is_distinct_from_development(self):
        profile = self.profile()
        self.assertTrue(all(pilot.profile_checks(profile, pilot.WATCH_ID, 'TEAM').values()))
        profile['Entitlements']['get-task-allow'] = True
        profile['ProvisionedDevices'] = ['synthetic-device']
        profile['Entitlements'].pop('beta-reports-active')
        checks = pilot.profile_checks(profile, pilot.WATCH_ID, 'TEAM')
        for key in ('debuggingDisabled', 'testFlight', 'notDeviceLimited'):
            self.assertFalse(checks[key], key)

    def test_wrong_expired_and_enterprise_profiles_are_rejected(self):
        profile = self.profile()
        profile.update(ExpirationDate=datetime.now() - timedelta(days=1), ProvisionsAllDevices=True)
        checks = pilot.profile_checks(profile, pilot.CONTAINER_ID, 'OTHER')
        for key in ('explicitApplication', 'team', 'unexpired', 'notEnterprise'):
            self.assertFalse(checks[key], key)

    def test_signed_entitlements_must_match_distribution_not_just_profile(self):
        values = {'application-identifier': 'TEAM.' + pilot.WATCH_ID,
                  'com.apple.developer.team-identifier': 'TEAM',
                  'get-task-allow': False, 'beta-reports-active': True}
        self.assertTrue(all(pilot.entitlement_checks(values, pilot.WATCH_ID, 'TEAM').values()))
        values['get-task-allow'] = True
        self.assertFalse(pilot.entitlement_checks(values, pilot.WATCH_ID, 'TEAM')['debuggingDisabled'])
        self.assertFalse(pilot.entitlement_checks(values, pilot.CONTAINER_ID, 'OTHER')['application'])

    def test_archive_locates_watch_payload_without_changing_legacy_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'Pilot.xcarchive'
            container = archive / 'Products/Applications/TeachingTimerDistribution.app'
            watch = container / 'Watch/TeachingTimer.app'
            watch.mkdir(parents=True)
            (archive / 'Info.plist').write_bytes(plistlib.dumps({
                'ApplicationProperties': {'ApplicationPath': 'Applications/TeachingTimerDistribution.app'}}))
            self.assertEqual(pilot.artifact.application_paths(archive), (watch.resolve(), container.resolve()))
            (archive / 'Info.plist').unlink()
            self.assertEqual(pilot.artifact.application_paths(archive),
                             ((archive / 'Products/Applications/TeachingTimer.app').resolve(), None))

    def test_archive_rejects_ambiguous_and_escaping_application_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'Pilot.xcarchive'
            container = archive / 'Products/Applications/TeachingTimerDistribution.app'
            for name in ('One.app', 'Two.app'):
                (container / 'Watch' / name).mkdir(parents=True)
            metadata = archive / 'Info.plist'
            metadata.write_bytes(plistlib.dumps({'ApplicationProperties': {
                'ApplicationPath': 'Applications/TeachingTimerDistribution.app'}}))
            with self.assertRaises(ValueError):
                pilot.artifact.application_paths(archive)
            metadata.write_bytes(plistlib.dumps({'ApplicationProperties': {'ApplicationPath': '../../elsewhere'}}))
            with self.assertRaises(ValueError):
                pilot.artifact.application_paths(archive)

    def test_export_refuses_archive_traversal(self):
        import zipfile
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            ipa = root / 'bad.ipa'
            with zipfile.ZipFile(ipa, 'w') as archive:
                archive.writestr('../../escape', 'no')
            with self.assertRaises(ValueError):
                pilot.export_checks(ipa, root, 'TEAM')
            self.assertFalse((root / 'escape').exists())
