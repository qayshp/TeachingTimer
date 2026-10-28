#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Read-only archive/app inspection. Does not sign, install, upload or contact a Watch."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import plistlib
import subprocess


def command(*args):
    return subprocess.run(list(map(str, args)), capture_output=True, timeout=30)


def inspect(path):
    archive = path if path.suffix == '.xcarchive' else None
    app = archive / 'Products/Applications/TeachingTimer.app' if archive else path
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    metadata = app / 'BuildInfo.plist'
    revision = plistlib.loads(metadata.read_bytes()).get('revision') if metadata.exists() else None
    checks = {'watchOnly': info.get('WKWatchOnly') is True,
              'binaryPresent': (app / info['CFBundleExecutable']).is_file(),
              'revisionRecorded': bool(revision)}
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
    return {'bundleIdentifier': info['CFBundleIdentifier'], 'version': info['CFBundleShortVersionString'],
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
