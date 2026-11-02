#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Create an unsigned rehearsal or a signed, internal-only TestFlight export.

Never uploads, installs, launches, or invites testers. --signed allows Xcode's
automatic provisioning and requires unchanged, committed source. Account
agreements must be accepted by the account owner.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CONTAINER_ID = 'net.qays.TeachingTimer'
WATCH_ID = CONTAINER_ID + '.watchkitapp'


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


artifact = module('pilot_artifact', 'inspect-artifact.py')
build = module('pilot_build', 'verify-build.py')


def source_state():
    """Read Git state without staging anything; ignored build evidence is allowed."""
    def git(*arguments):
        return subprocess.run(['git', *arguments], cwd=ROOT, check=True, text=True,
                              capture_output=True, timeout=30).stdout.strip()
    return dict(head=git('rev-parse', '--verify', 'HEAD'),
                dirty=bool(git('status', '--porcelain=v1', '--untracked-files=all')))


def verify_signed_source(before, after, archived_revision):
    if after['dirty']:
        raise ValueError('Source became dirty during signed preparation; refusing export')
    if after['head'] != before['head']:
        raise ValueError('Source HEAD changed during signed preparation; refusing export')
    if archived_revision != before['head']:
        raise ValueError('Archive revision does not exactly match the captured clean HEAD; refusing export')


def package_checks(container, watch):
    return dict(containerIdentifier=container.get('CFBundleIdentifier') == CONTAINER_ID,
                watchIdentifier=watch.get('CFBundleIdentifier') == WATCH_ID,
                containerExportComplianceDeclared=container.get('ITSAppUsesNonExemptEncryption') is False,
                watchExportComplianceDeclared=watch.get('ITSAppUsesNonExemptEncryption') is False,
                watchOnly=watch.get('WKWatchOnly') is True,
                watchApplication=watch.get('WKApplication') is True,
                noCompanionRequirement='WKCompanionAppBundleIdentifier' not in watch,
                versionsMatch=all(container.get(k) == watch.get(k) and bool(watch.get(k))
                                  for k in ('CFBundleVersion', 'CFBundleShortVersionString')),
                mindfulnessRuntime='mindfulness' in watch.get('WKBackgroundModes', []))


def profile_checks(profile, identifier, team):
    entitlements = profile.get('Entitlements', {})
    expires = profile.get('ExpirationDate')
    return dict(explicitApplication=entitlements.get('application-identifier') == team + '.' + identifier,
                team=profile.get('TeamIdentifier') == [team],
                debuggingDisabled=entitlements.get('get-task-allow') is False,
                testFlight=entitlements.get('beta-reports-active') is True,
                notDeviceLimited='ProvisionedDevices' not in profile,
                notEnterprise=profile.get('ProvisionsAllDevices') is not True,
                unexpired=bool(expires and expires.replace(tzinfo=timezone.utc) > datetime.now(timezone.utc)))


def entitlement_checks(entitlements, identifier, team):
    return dict(application=entitlements.get('application-identifier') == team + '.' + identifier,
                team=entitlements.get('com.apple.developer.team-identifier') == team,
                debuggingDisabled=entitlements.get('get-task-allow') is False,
                testFlight=entitlements.get('beta-reports-active') is True)


def export_checks(ipa, output, team):
    unpacked = output / 'verified-export'
    with zipfile.ZipFile(ipa) as archive:
        for member in archive.infolist():
            if not (unpacked / member.filename).resolve().is_relative_to(unpacked.resolve()):
                raise ValueError('Export contains a path outside its extraction directory')
        archive.extractall(unpacked)
    containers = list((unpacked / 'Payload').glob('*.app'))
    if len(containers) != 1:
        raise ValueError('Expected exactly one exported distribution container')
    container = containers[0]
    watches = list(container.glob('Watch/*.app'))
    if len(watches) != 1:
        raise ValueError('Expected exactly one exported Watch payload')
    watch = watches[0]
    checks = package_checks(plistlib.loads((container / 'Info.plist').read_bytes()),
                            plistlib.loads((watch / 'Info.plist').read_bytes()))
    signatures = {}
    profiles = {}
    entitlements = {}
    for kind, app, identifier in [('container', container, CONTAINER_ID), ('watch', watch, WATCH_ID)]:
        signatures[kind] = artifact.command('codesign', '--verify', '--deep', '--strict', app).returncode == 0
        decoded = artifact.command('security', 'cms', '-D', '-i', app / 'embedded.mobileprovision')
        if decoded.returncode != 0:
            raise ValueError('Cannot decode ' + kind + ' distribution profile')
        profiles[kind] = profile_checks(plistlib.loads(decoded.stdout), identifier, team)
        signed_entitlements = artifact.command('codesign', '-d', '--entitlements', ':-', app)
        if signed_entitlements.returncode != 0:
            raise ValueError('Cannot inspect ' + kind + ' signed entitlements')
        entitlements[kind] = entitlement_checks(plistlib.loads(signed_entitlements.stdout), identifier, team)
    return dict(checks=checks, signatures=signatures, profiles=profiles, entitlements=entitlements,
                sha256=hashlib.sha256(ipa.read_bytes()).hexdigest(),
                passed=all(checks.values()) and all(signatures.values())
                and all(all(values.values()) for values in profiles.values())
                and all(all(values.values()) for values in entitlements.values()))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path, help='New output directory; never overwrites')
    parser.add_argument('--signed', action='store_true', help='Permit automatic provisioning and export an internal-only IPA')
    args = parser.parse_args(argv)
    os.umask(0o077)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    archive = output / 'TeachingTimer.xcarchive'
    report = dict(stage='starting', signed=False, uploaded=False, installed=False,
                  appStoreValidation='not performed', journalAccess='not verified',
                  physicalPilot='not performed', steps=[])
    def save():
        (output / 'readiness.json').write_text(json.dumps(report, indent=2) + '\n')
    def run(name, command):
        step = build.run_step(name, command, output, timeout=900)
        report['steps'].append(step)
        save()
        if step['status'] != 'passed':
            raise RuntimeError(f'{name} failed; see {output / (name + ".log")}')
    save()
    try:
        if args.signed:
            report['sourceBeforeBuild'] = source_state()
            if report['sourceBeforeBuild']['dirty']:
                raise ValueError('Signed preparation requires a clean committed source tree; '
                                 'commit intended changes first and use an ignored or external output directory')
            save()
        command = ['xcodebuild', '-project', 'TeachingTimer.xcodeproj', '-scheme', 'TeachingTimerTestFlight',
                   '-configuration', 'TestFlight', '-destination', 'generic/platform=iOS',
                   '-archivePath', str(archive)]
        command += (['-allowProvisioningUpdates', 'SOURCE_REVISION=' + report['sourceBeforeBuild']['head']]
                    if args.signed else ['CODE_SIGNING_ALLOWED=NO'])
        run('build', command + ['archive'])
        inspection = artifact.inspect(archive)
        (output / 'artifact-inspection.json').write_text(json.dumps(inspection, indent=2) + '\n')
        watch, container = artifact.application_paths(archive)
        if container is None:
            raise ValueError('TestFlight requires the watch-only distribution container')
        container_info = plistlib.loads((container / 'Info.plist').read_bytes())
        watch_info = plistlib.loads((watch / 'Info.plist').read_bytes())
        report.update(checks=package_checks(container_info, watch_info), version=inspection['version'],
                      build=inspection['build'], revision=inspection['revision'])
        if not all(report['checks'].values()) or not all(inspection['checks'].values()):
            raise ValueError('Archive identity, packaging, resources or symbols failed validation')
        report['stage'] = 'unsigned_archive_verified'
        if args.signed:
            if not inspection['signatureValid'] or not inspection['unexpiredEmbeddedProfile']:
                raise ValueError('Signed Watch archive verification failed')
            report.update(stage='signed_archive_export_pending', signed=True)
            team = plistlib.loads((archive / 'Info.plist').read_bytes())['ApplicationProperties']['Team']
            options = dict(method='app-store-connect', destination='export', signingStyle='automatic',
                           teamID=team, manageAppVersionAndBuildNumber=False,
                           testFlightInternalTestingOnly=True, uploadSymbols=True)
            options_file = output / 'ExportOptions.plist'
            options_file.write_bytes(plistlib.dumps(options))
            # Recheck immediately before export. The build phase records the
            # exact captured HEAD (plus -dirty if it saw edits while archiving).
            report['sourceAfterArchive'] = source_state()
            verify_signed_source(report['sourceBeforeBuild'], report['sourceAfterArchive'], inspection['revision'])
            report['sourceRevisionVerified'] = True
            save()
            run('export', ['xcodebuild', '-exportArchive', '-archivePath', str(archive),
                           '-exportOptionsPlist', str(options_file), '-exportPath', str(output / 'export'),
                           '-allowProvisioningUpdates'])
            packages = list((output / 'export').glob('*.ipa'))
            if len(packages) != 1:
                raise ValueError('Expected one signed IPA export')
            report['export'] = export_checks(packages[0], output, team)
            if not report['export']['passed']:
                raise ValueError('Export signature, profile or identifier checks failed')
            report['stage'] = 'signed_internal_testflight_export_verified'
        save()
        print(json.dumps(report, indent=2))
    except Exception as error:
        report.update(failed=True, error=str(error))
        save()
        raise SystemExit(str(error))


if __name__ == '__main__':
    main()
