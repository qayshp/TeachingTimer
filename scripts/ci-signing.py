#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Install/clean temporary CI credentials. Never exports a developer's keychain."""
import argparse
import base64
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shlex
import subprocess
import sys

TEAM = 'QV8ZH37356'
CONTAINER = 'net.qays.TeachingTimer'
WATCH = CONTAINER + '.watchkitapp'
REQUIRED = ('ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_PRIVATE_KEY_BASE64',
            'DISTRIBUTION_CERTIFICATE_BASE64', 'DISTRIBUTION_CERTIFICATE_PASSWORD',
            'CONTAINER_PROFILE_BASE64', 'WATCH_PROFILE_BASE64')


def run(*args):
    # Password-bearing commands and arbitrary security-tool output stay private.
    result = subprocess.run(args, capture_output=True, timeout=60)
    if result.returncode:
        raise ValueError('Credential operation failed: ' + Path(args[0]).name + ' ' + args[1])
    return result.stdout


def profile_valid(profile, identifier):
    ent = profile.get('Entitlements', {})
    expires = profile.get('ExpirationDate')
    return (profile.get('TeamIdentifier') == [TEAM]
        and ent.get('application-identifier') == TEAM + '.' + identifier
        and ent.get('get-task-allow') is False and ent.get('beta-reports-active') is True
        and 'ProvisionedDevices' not in profile and not profile.get('ProvisionsAllDevices', False)
        and bool(expires and expires.replace(tzinfo=timezone.utc) > datetime.now(timezone.utc))
        and re.fullmatch(r'[A-Fa-f0-9-]{36}', profile.get('UUID', '')) is not None)


def cleanup(folder):
    state_file = folder / 'state.json'
    if not state_file.exists():
        return
    state = json.loads(state_file.read_text())
    if state.get('searchListChanged'):
        run('security', 'list-keychains', '-d', 'user', '-s', *state['priorKeychains'])
    keychain = folder / 'release.keychain-db'
    if keychain.exists():
        run('security', 'delete-keychain', str(keychain))
    for value in state.get('createdProfiles', []):
        Path(value).unlink(missing_ok=True)
    for value in folder.iterdir():
        if value.is_file():
            value.unlink()
    folder.rmdir()


def setup(folder):
    missing = [name for name in REQUIRED if not os.environ.get(name)]
    if missing:
        raise ValueError('Missing GitHub environment secrets: ' + ', '.join(missing))
    folder.mkdir(parents=True, exist_ok=False, mode=0o700)
    state = dict(priorKeychains=shlex.split(run('security', 'list-keychains', '-d', 'user').decode()),
                 createdProfiles=[], searchListChanged=False)
    def save():
        (folder / 'state.json').write_text(json.dumps(state))
    save()
    def decode(name, file):
        value = base64.b64decode(''.join(os.environ[name].split()), validate=True)
        destination = folder / file
        destination.write_bytes(value)
        destination.chmod(0o600)
        return destination
    try:
        key = decode('ASC_PRIVATE_KEY_BASE64', 'AuthKey.p8')
        certificate = decode('DISTRIBUTION_CERTIFICATE_BASE64', 'distribution.p12')
        mapping = {}
        for variable, identifier, name in [('CONTAINER_PROFILE_BASE64', CONTAINER, 'container.mobileprovision'),
                                           ('WATCH_PROFILE_BASE64', WATCH, 'watch.mobileprovision')]:
            file = decode(variable, name)
            profile = plistlib.loads(run('security', 'cms', '-D', '-i', str(file)))
            if not profile_valid(profile, identifier):
                raise ValueError('Invalid/expired App Store distribution profile for ' + identifier)
            mapping[identifier] = profile['UUID']
            # Xcode changed profile locations; install the identical profile for either path.
            for relative in ['Library/MobileDevice/Provisioning Profiles',
                             'Library/Developer/Xcode/UserData/Provisioning Profiles']:
                directory = Path.home() / relative
                directory.mkdir(parents=True, exist_ok=True)
                destination = directory / (profile['UUID'] + '.mobileprovision')
                if destination.exists():
                    if destination.read_bytes() != file.read_bytes():
                        raise ValueError('Refusing to replace an existing different profile')
                else:
                    destination.write_bytes(file.read_bytes())
                    destination.chmod(0o600)
                    state['createdProfiles'].append(str(destination))
                    save()
        keychain = folder / 'release.keychain-db'
        password = secrets.token_urlsafe(32)
        run('security', 'create-keychain', '-p', password, str(keychain))
        run('security', 'set-keychain-settings', '-lut', '7200', str(keychain))
        run('security', 'unlock-keychain', '-p', password, str(keychain))
        run('security', 'import', str(certificate), '-k', str(keychain), '-P',
            os.environ['DISTRIBUTION_CERTIFICATE_PASSWORD'], '-T', '/usr/bin/codesign')
        run('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:', '-k', password, str(keychain))
        state['searchListChanged'] = True
        save()
        run('security', 'list-keychains', '-d', 'user', '-s', str(keychain), *state['priorKeychains'])
        config = folder / 'signing.xcconfig'
        config.write_text('CODE_SIGN_STYLE = Manual\nCODE_SIGN_IDENTITY = Apple Distribution\n'
            + 'DEVELOPMENT_TEAM = ' + TEAM + '\n'
            + 'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*] = ' + mapping[CONTAINER] + '\n'
            + 'PROVISIONING_PROFILE_SPECIFIER[sdk=watchos*] = ' + mapping[WATCH] + '\n')
        (folder / 'signing.json').write_text(json.dumps(dict(teamID=TEAM, profiles=mapping, xcconfig=str(config))))
        print('Temporary signing identity and both distribution profiles installed.')
        return key
    except BaseException:
        cleanup(folder)
        raise


if __name__ == '__main__':
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['setup', 'cleanup'])
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    try:
        (setup if args.operation == 'setup' else cleanup)(args.directory.resolve())
    except Exception as error:
        print(str(error) if isinstance(error, ValueError) else type(error).__name__, file=sys.stderr)
        sys.exit(1)
