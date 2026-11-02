# SPDX-License-Identifier: MPL-2.0
from datetime import datetime, timedelta
from contextlib import redirect_stdout
import hashlib
import importlib.util
import io
import json
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
    @staticmethod
    def package():
        container = dict(CFBundleIdentifier=pilot.CONTAINER_ID, CFBundleVersion='28', CFBundleShortVersionString='1.0',
                         ITSAppUsesNonExemptEncryption=False)
        watch = dict(container, CFBundleIdentifier=pilot.WATCH_ID, WKWatchOnly=True,
                     WKApplication=True, WKBackgroundModes=['mindfulness'])
        return container, watch

    def profile(self):
        return dict(TeamIdentifier=['TEAM'], ExpirationDate=datetime.now() + timedelta(days=30),
                    Entitlements={'application-identifier': 'TEAM.' + pilot.WATCH_ID,
                                  'get-task-allow': False, 'beta-reports-active': True})

    def exported_package(self, root, manifest=(ROOT / 'TeachingTimer/PrivacyInfo.xcprivacy').read_bytes()):
        ipa = root / 'candidate.ipa'
        container, watch = self.package()
        with zipfile.ZipFile(ipa, 'w') as archive:
            archive.writestr('Payload/TeachingTimerDistribution.app/Info.plist', plistlib.dumps(container))
            archive.writestr('Payload/TeachingTimerDistribution.app/Watch/TeachingTimer.app/Info.plist',
                             plistlib.dumps(watch))
            if manifest is not None:
                archive.writestr('Payload/TeachingTimerDistribution.app/Watch/TeachingTimer.app/PrivacyInfo.xcprivacy',
                                 manifest)
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

    def test_export_rejects_missing_malformed_or_unreviewed_watch_privacy_manifest(self):
        reviewed = plistlib.loads((ROOT / 'TeachingTimer/PrivacyInfo.xcprivacy').read_bytes())
        wrong_reason = plistlib.loads(plistlib.dumps(reviewed))
        wrong_reason['NSPrivacyAccessedAPITypes'][1]['NSPrivacyAccessedAPITypeReasons'] = ['8FFB.1']
        for manifest in (None, b'not a plist', b'<?xml version="1.0"?><plist><dict>',
                         plistlib.dumps(dict(reviewed, NSPrivacyTracking=True)), plistlib.dumps(wrong_reason)):
            with self.subTest(manifest=manifest), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                ipa = self.exported_package(root, manifest)
                with patch.object(pilot.artifact, 'command', side_effect=self.export_command):
                    result = pilot.export_checks(ipa, root, 'TEAM')
                self.assertFalse(result['passed'])
                self.assertFalse(result['checks']['watchPrivacyManifestMatchesPolicy'])
                self.assertTrue(all(value for key, value in result['checks'].items()
                                    if key != 'watchPrivacyManifestMatchesPolicy'))
                self.assertTrue(all(result['signatures'].values()))
                self.assertTrue(all(all(values.values()) for values in result['profiles'].values()))
                self.assertTrue(all(all(values.values()) for values in result['entitlements'].values()))

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


class SignedSourceChecks(unittest.TestCase):
    head = 'a' * 40

    def prepare(self, states, *, signed=True, archived_revision=None):
        """Exercise orchestration with fake Xcode/inspection; no account access."""
        commands = []
        inspection = dict(version='1.0', build='31', revision=archived_revision or self.head,
                          checks={'fixture': True}, signatureValid=True, unexpiredEmbeddedProfile=True)
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'release'
            def run(name, command, destination, timeout):
                commands.append((name, command))
                if name == 'build':
                    archive = destination / 'TeachingTimer.xcarchive'
                    container = archive / 'Products/Applications/TeachingTimerDistribution.app'
                    watch = container / 'Watch/TeachingTimer.app'
                    watch.mkdir(parents=True)
                    container_info, watch_info = TestFlightChecks.package()
                    (container / 'Info.plist').write_bytes(plistlib.dumps(container_info))
                    (watch / 'Info.plist').write_bytes(plistlib.dumps(watch_info))
                    (archive / 'Info.plist').write_bytes(plistlib.dumps({'ApplicationProperties': {
                        'ApplicationPath': 'Applications/TeachingTimerDistribution.app', 'Team': 'TEAM'}}))
                elif name == 'export':
                    (destination / 'export').mkdir()
                    (destination / 'export/candidate.ipa').touch()
                else:
                    self.fail('Unexpected account/build operation: ' + name)
                return dict(name=name, command=command, status='passed')
            with patch.object(pilot, 'source_state', side_effect=states) as state, \
                    patch.object(pilot.build, 'run_step', side_effect=run), \
                    patch.object(pilot.artifact, 'inspect', return_value=inspection), \
                    patch.object(pilot, 'export_checks', return_value={'passed': True}) as export, \
                    patch.object(pilot.os, 'umask'), redirect_stdout(io.StringIO()):
                error = None
                try:
                    pilot.main([str(output)] + (['--signed'] if signed else []))
                except SystemExit as failure:
                    error = str(failure)
                report = json.loads((output / 'readiness.json').read_text())
                return report, error, commands, state.call_count, export.call_count

    def test_signed_dirty_preflight_never_starts_account_or_build_operation(self):
        report, error, commands, states, exports = self.prepare([{'head': self.head, 'dirty': True}])
        self.assertIn('clean committed source', error)
        self.assertTrue(report['failed'])
        self.assertEqual(commands, [])
        self.assertEqual((states, exports), (1, 0))

    def test_signed_clean_source_pins_exact_revision_and_checks_again_before_export(self):
        clean = {'head': self.head, 'dirty': False}
        report, error, commands, states, exports = self.prepare([clean, clean])
        self.assertIsNone(error)
        self.assertEqual([name for name, _ in commands], ['build', 'export'])
        self.assertIn('SOURCE_REVISION=' + self.head, commands[0][1])
        self.assertEqual((states, exports), (2, 1))
        self.assertTrue(report['sourceRevisionVerified'])
        self.assertEqual(report['sourceBeforeBuild'], report['sourceAfterArchive'])
        self.assertFalse(report['uploaded'])

    def test_signed_export_stops_for_source_changes_or_wrong_archive_revision(self):
        clean = {'head': self.head, 'dirty': False}
        cases = [({'head': self.head, 'dirty': True}, self.head),
                 ({'head': 'b' * 40, 'dirty': False}, self.head),
                 (clean, self.head + '-dirty'), (clean, self.head[:12]), (clean, 'b' * 40)]
        for after, revision in cases:
            with self.subTest(after=after, revision=revision):
                report, error, commands, states, exports = self.prepare([clean, after], archived_revision=revision)
                self.assertIn('refusing export', error)
                self.assertTrue(report['failed'])
                self.assertEqual([name for name, _ in commands], ['build'])
                self.assertEqual((states, exports), (2, 0))
                self.assertNotIn('sourceRevisionVerified', report)

    def test_unsigned_rehearsal_still_allows_dirty_source(self):
        report, error, commands, states, exports = self.prepare([], signed=False,
                                                               archived_revision=self.head[:12] + '-dirty')
        self.assertIsNone(error)
        self.assertEqual(report['stage'], 'unsigned_archive_verified')
        self.assertEqual([name for name, _ in commands], ['build'])
        self.assertIn('CODE_SIGNING_ALLOWED=NO', commands[0][1])
        self.assertNotIn('-allowProvisioningUpdates', commands[0][1])
        self.assertEqual((states, exports), (0, 0))

    def test_git_state_detects_tracked_staged_and_untracked_edits_but_ignores_work(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            def git(*args):
                return subprocess.run(['git', '-C', str(root), *args], check=True, capture_output=True, text=True).stdout.strip()
            git('init')
            (root / '.gitignore').write_text('work/\n')
            tracked = root / 'source.swift'
            tracked.write_text('original\n')
            git('add', '.gitignore', 'source.swift')
            git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                '-c', 'commit.gpgsign=false', 'commit', '-m', 'fixture')
            with patch.object(pilot, 'ROOT', root):
                baseline = pilot.source_state()
                self.assertEqual(baseline, {'head': git('rev-parse', 'HEAD'), 'dirty': False})
                (root / 'work').mkdir()
                (root / 'work/build.log').write_text('ignored evidence\n')
                self.assertEqual(pilot.source_state(), baseline)
                tracked.write_text('changed\n')
                self.assertTrue(pilot.source_state()['dirty'])
                git('add', 'source.swift')
                self.assertTrue(pilot.source_state()['dirty'])
                tracked.write_text('original\n')
                git('add', 'source.swift')
                self.assertEqual(pilot.source_state(), baseline)
                (root / 'untracked.swift').write_text('new source\n')
                self.assertTrue(pilot.source_state()['dirty'])
