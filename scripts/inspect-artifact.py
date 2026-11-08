#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Read-only archive/app inspection. Does not sign, install, upload or contact a Watch."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import plistlib
import subprocess
from xml.parsers.expat import ExpatError


def command(*args):
    return subprocess.run(list(map(str, args)), capture_output=True, timeout=30)


def privacy_manifest_matches_policy(app):
    """Check the bundled manifest against TeachingTimer's reviewed policy.

    This is deliberately narrower than Apple's schema. Revisit this check and
    TeachingTimer/PrivacyInfo.xcprivacy together if data use or required APIs
    change; passing it is not an API-usage audit or App Store approval.
    """
    try:
        manifest = plistlib.loads((app / 'PrivacyInfo.xcprivacy').read_bytes())
    except (OSError, ValueError, plistlib.InvalidFileException, ExpatError):
        return False
    if not isinstance(manifest, dict) or set(manifest) != {
            'NSPrivacyTracking', 'NSPrivacyTrackingDomains',
            'NSPrivacyCollectedDataTypes', 'NSPrivacyAccessedAPITypes'}:
        return False
    if (manifest['NSPrivacyTracking'] is not False
            or manifest['NSPrivacyTrackingDomains'] != []
            or manifest['NSPrivacyCollectedDataTypes'] != []):
        return False
    expected = [
        {'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults',
         'NSPrivacyAccessedAPITypeReasons': ['CA92.1']},
        {'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategorySystemBootTime',
         'NSPrivacyAccessedAPITypeReasons': ['35F9.1']},
    ]
    entries = manifest['NSPrivacyAccessedAPITypes']
    # Order is immaterial, but omissions, duplicates and additional declarations
    # require review rather than silently changing the shipped privacy policy.
    return (isinstance(entries, list) and len(entries) == len(expected)
            and all(entries.count(item) == 1 for item in expected))


def information_resources_present(app):
    try:
        if any(len((app / name).read_text()) < 1000 for name in ('PRIVACY.md', 'LICENSE')):
            return False
        links = json.loads((app / 'Information/WebLinks.json').read_text())
        if set(links) != {'privacy', 'support', 'source'}:
            return False
        return all(item['title'] and item['url'].startswith('https://')
                   and (app / 'Information' / (key + '.png')).read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
                   for key, item in links.items())
    except (OSError, ValueError, KeyError, TypeError):
        return False


def application_paths(path):
    """Return the Watch payload and optional Apple watch-only distribution stub."""
    if path.suffix != '.xcarchive':
        return path, None
    metadata_path = path / 'Info.plist'
    relative = (plistlib.loads(metadata_path.read_bytes()).get('ApplicationProperties', {})
                .get('ApplicationPath', 'Applications/TeachingTimer.app')) if metadata_path.exists() else 'Applications/TeachingTimer.app'
    products = (path / 'Products').resolve()
    top = (products / relative).resolve()
    if not top.is_relative_to(products):
        raise ValueError('Archive application path leaves Products')
    watches = list(top.glob('Watch/*.app'))
    if not watches:
        return top, None
    if len(watches) != 1:
        raise ValueError('Expected exactly one Watch app in the distribution container')
    return watches[0], top


def inspect(path):
    archive = path if path.suffix == '.xcarchive' else None
    app, container = application_paths(path)
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    metadata = app / 'BuildInfo.plist'
    revision = plistlib.loads(metadata.read_bytes()).get('revision') if metadata.exists() else None
    checks = {'independentWatch': (info.get('WKWatchOnly') is True or info.get('WKRunsIndependentlyOfCompanionApp') is True),
              'binaryPresent': (app / info['CFBundleExecutable']).is_file(),
              'revisionRecorded': bool(revision),
              'privacyManifestMatchesPolicy': privacy_manifest_matches_policy(app)}
    container_info = plistlib.loads((container / 'Info.plist').read_bytes()) if container else None
    if container_info:
        checks.update(containerIdentifierIsWatchPrefix=info['CFBundleIdentifier'].startswith(container_info['CFBundleIdentifier'] + '.'),
                      containerVersionMatches=all(info[key] == container_info[key] for key in ('CFBundleVersion', 'CFBundleShortVersionString')),
                      noCompanionRequirement=('WKCompanionAppBundleIdentifier' not in info or
                          (info.get('WKRunsIndependentlyOfCompanionApp') is True and
                           info.get('WKCompanionAppBundleIdentifier') == container_info['CFBundleIdentifier'])))
    # Preserve inspection of historical teaching checkpoints from before these pages.
    if int(info['CFBundleVersion'].split('.')[0]) >= 27:
        checks['informationResourcesPresent'] = information_resources_present(app)
    signature = command('codesign', '--verify', '--deep', '--strict', app).returncode == 0
    profile_path = app / 'embedded.mobileprovision'
    profile = None
    if profile_path.exists():
        decoded = command('security', 'cms', '-D', '-i', profile_path)
        if decoded.returncode == 0:
            profile = plistlib.loads(decoded.stdout)
    expires = profile.get('ExpirationDate') if profile else None
    valid_profile = bool(expires and expires.replace(tzinfo=timezone.utc) > datetime.now(timezone.utc))
    if archive:
        binary_uuids = command('dwarfdump', '--uuid', app / info['CFBundleExecutable'])
        symbol_uuids = command('dwarfdump', '--uuid', archive / 'dSYMs/TeachingTimer.app.dSYM')
        def uuids(result):
            return {line.split()[1] for line in result.stdout.decode().splitlines() if line.startswith('UUID:')}
        checks['symbolsMatchBinary'] = binary_uuids.returncode == symbol_uuids.returncode == 0 and bool(uuids(binary_uuids)) and uuids(binary_uuids) == uuids(symbol_uuids)
    return {'bundleIdentifier': info['CFBundleIdentifier'],
            'containerBundleIdentifier': container_info['CFBundleIdentifier'] if container_info else None,
            'version': info['CFBundleShortVersionString'],
            'build': info['CFBundleVersion'], 'revision': revision, 'checks': checks,
            'signatureValid': signature, 'unexpiredEmbeddedProfile': valid_profile,
            'profileExpires': expires.isoformat() + 'Z' if expires else None,
            'distributionValidation': 'not performed', 'deviceEligibility': 'not checked',
            'note': 'Signature/profile checks alone do not establish App Store acceptance, device membership, entitlements or launch success.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact', type=Path)
    parser.add_argument('--require-signed', action='store_true', help='Also reject missing/invalid signatures or expired/missing profiles')
    args = parser.parse_args()
    result = inspect(args.artifact.resolve())
    print(json.dumps(result, indent=2))
    if not all(result['checks'].values()) or (args.require_signed and not (result['signatureValid'] and result['unexpiredEmbeddedProfile'])):
        raise SystemExit(1)

if __name__ == '__main__':
    main()
