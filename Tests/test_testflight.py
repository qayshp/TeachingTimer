# SPDX-License-Identifier: MPL-2.0
from datetime import datetime, timedelta
import hashlib
import importlib.util
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('pilot', ROOT / 'scripts/prepare-testflight.py')
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


class TestFlightChecks(unittest.TestCase):
    def package(self):
        container = dict(CFBundleIdentifier=pilot.CONTAINER_ID, CFBundleVersion='28', CFBundleShortVersionString='1.0',
                         ITSAppUsesNonExemptEncryption=False)
        watch = dict(container, CFBundleIdentifier=pilot.WATCH_ID, WKWatchOnly=True,
                     WKApplication=True, WKBackgroundModes=['mindfulness'])
        return container, watch

    def profile(self):
        return dict(TeamIdentifier=['TEAM'], ExpirationDate=datetime.now() + timedelta(days=30),
                    Entitlements={'application-identifier': 'TEAM.' + pilot.WATCH_ID,
                                  'get-task-allow': False, 'beta-reports-active': True})

    def exported_package(self, root):
        ipa = root / 'candidate.ipa'
        container, watch = self.package()
        with zipfile.ZipFile(ipa, 'w') as archive:
            archive.writestr('Payload/TeachingTimerDistribution.app/Info.plist', plistlib.dumps(container))
            archive.writestr('Payload/TeachingTimerDistribution.app/Watch/TeachingTimer.app/Info.plist',
                             plistlib.dumps(watch))
        return ipa

    def export_command(self, *args):
        """Synthetic tool responses; never inspect a real signing identity."""
        app = Path(args[-1])
        identifier = pilot.WATCH_ID if 'Watch' in app.parts else pilot.CONTAINER_ID
        output = b''
        if args[:4] == ('security', 'cms', '-D', '-i'):
            profile = self.profile()
            profile['Entitlements']['application-identifier'] = 'TEAM.' + identifier
            output = plistlib.dumps(profile)
        elif args[:4] == ('codesign', '-d', '--entitlements', ':-'):
            output = plistlib.dumps({'application-identifier': 'TEAM.' + identifier,
                                      'com.apple.developer.team-identifier': 'TEAM',
                                      'get-task-allow': False, 'beta-reports-active': True})
        else:
            self.assertEqual(args[:4], ('codesign', '--verify', '--deep', '--strict'))
        return subprocess.CompletedProcess(args, 0, output, b'')

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

    def test_both_payloads_require_explicit_export_compliance_declaration(self):
        for kind in ('container', 'watch'):
            for value in (None, True, 0):
                with self.subTest(kind=kind, value=value):
                    container, watch = self.package()
                    payload = container if kind == 'container' else watch
                    if value is None:
                        payload.pop('ITSAppUsesNonExemptEncryption')
                    else:
                        payload['ITSAppUsesNonExemptEncryption'] = value
                    checks = pilot.package_checks(container, watch)
                    self.assertFalse(checks[kind + 'ExportComplianceDeclared'])
                    other = 'watch' if kind == 'container' else 'container'
                    self.assertTrue(checks[other + 'ExportComplianceDeclared'])

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

    def test_export_checks_both_signed_apps_and_parses_xml_entitlements(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            ipa = self.exported_package(root)
            with patch.object(pilot.artifact, 'command', side_effect=self.export_command) as command:
                result = pilot.export_checks(ipa, root, 'TEAM')
            self.assertTrue(result['passed'])
            self.assertEqual(result['sha256'], hashlib.sha256(ipa.read_bytes()).hexdigest())
            self.assertEqual(result['signatures'], {'container': True, 'watch': True})
            self.assertEqual(command.call_count, 6)
            # ':' requests plist output. A bare '-' can return human-readable
            # text on current codesign, which broke the first real export audit.
            entitlement_calls = [call.args for call in command.call_args_list
                                 if call.args[:3] == ('codesign', '-d', '--entitlements')]
            self.assertEqual(len(entitlement_calls), 2)
            self.assertTrue(all(call[3] == ':-' for call in entitlement_calls))

    def test_export_rejects_bad_signature_or_signed_entitlements_on_either_app(self):
        for kind in ('container', 'watch'):
            for failure in ('signature', 'entitlements'):
                with self.subTest(kind=kind, failure=failure), tempfile.TemporaryDirectory() as folder:
                    root = Path(folder)
                    ipa = self.exported_package(root)
                    def command(*args):
                        result = self.export_command(*args)
                        actual_kind = 'watch' if 'Watch' in Path(args[-1]).parts else 'container'
                        if actual_kind != kind:
                            return result
                        if failure == 'signature' and args[1] == '--verify':
                            return subprocess.CompletedProcess(args, 1, b'', b'synthetic invalid signature')
                        if failure == 'entitlements' and args[1] == '-d':
                            values = plistlib.loads(result.stdout)
                            values['get-task-allow'] = True
                            return subprocess.CompletedProcess(args, 0, plistlib.dumps(values), b'')
                        return result
                    with patch.object(pilot.artifact, 'command', side_effect=command):
                        result = pilot.export_checks(ipa, root, 'TEAM')
                    self.assertFalse(result['passed'])
                    # Good profiles must not mask the actual signature failure.
                    self.assertTrue(all(all(values.values()) for values in result['profiles'].values()))

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
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            ipa = root / 'bad.ipa'
            with zipfile.ZipFile(ipa, 'w') as archive:
                archive.writestr('../../escape', 'no')
            with self.assertRaises(ValueError):
                pilot.export_checks(ipa, root, 'TEAM')
            self.assertFalse((root / 'escape').exists())
