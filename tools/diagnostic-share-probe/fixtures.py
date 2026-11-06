#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Generate harmless deterministic sharing fixtures and verify received bytes."""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import random
import sys
import zipfile

MAX_FIXTURE_BYTES = 2 * 1024 * 1024


def encode(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode('utf-8')


def generate(destination: Path) -> dict:
    destination.mkdir(parents=True, exist_ok=True)
    small = destination / 'synthetic-small.json'
    small.write_bytes(encode({
        'synthetic': True,
        'message': 'Harmless sharing fixture; not user diagnostics.',
        'events': [{'event': 'fixture_only', 'details': {'count': '1'}}],
    }))
    start = datetime(2000, 1, 1, tzinfo=timezone.utc)
    kinds = [('runtime', 2000), ('interface', 2000), ('landmark', 2000)]
    journals = []
    for kind, count in kinds:
        events = [{
            'timestamp': (start + timedelta(seconds=index)).isoformat(),
            'event': 'fixture_only',
            'details': {
                'synthetic': 'true', 'sequence': str(index),
                'launchID': 'launch-1', 'runtimeID': 'runtime-1',
                'message': 'Synthetic fixture only. No user, device, class or audio data.',
            },
        } for index in range(count)]
        journals.append({'name': kind, 'status': 'available', 'eventCount': count,
                         'firstEvent': events[0]['timestamp'],
                         'lastEvent': events[-1]['timestamp'], 'events': events})
    report = destination / 'synthetic-report.json'
    report.write_bytes(encode({
        'schemaVersion': 1,
        'synthetic': True,
        'fixtureFormat': 'representative-envelope-not-production-export',
        'metadata': {'appVersion': 'fixture', 'build': '1', 'osVersion': 'fixture'},
        'selection': 'lastTwoHours',
        'cutoff': (start + timedelta(hours=2)).isoformat(),
        'journals': journals,
    }))
    if report.stat().st_size > MAX_FIXTURE_BYTES:
        raise ValueError('Representative JSON exceeds the proposed 2 MiB export cap')

    # Preserve the original ZIP experiment for comparative sharing checks.
    archive_path = destination / 'synthetic-journals.zip'
    rng = random.Random(42)
    with zipfile.ZipFile(archive_path, 'w', compression=zipfile.ZIP_DEFLATED,
                         compresslevel=6) as archive:
        for kind, count in [('Runtime', 10000), ('Interface', 4000), ('Landmark', 20000)]:
            rows = [{'timestamp': (start + timedelta(seconds=index)).isoformat(),
                     'event': 'synthetic_' + kind.lower(),
                     'details': {'synthetic': 'true', 'sequence': str(index),
                                 'fixtureToken': '%032x' % rng.getrandbits(128),
                                 'message': 'Generated fixture. No user, device, class, or audio data.'}}
                    for index in range(count)]
            member = zipfile.ZipInfo('Synthetic' + kind + 'Diagnostics.json',
                                    date_time=(2000, 1, 1, 0, 0, 0))
            member.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(member, encode(rows))
    manifest = {
        'schemaVersion': 1,
        'syntheticOnly': True,
        'fixtures': [{'file': path.name, 'bytes': path.stat().st_size,
                      'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                     for path in (small, report, archive_path)],
    }
    for item in manifest['fixtures']:
        verify(manifest, destination / item['file'], item['file'])
    return manifest


def verify(manifest: dict, received: Path, expected_name: str) -> dict:
    if manifest.get('syntheticOnly') is not True:
        raise ValueError('Expected a trusted synthetic-fixture manifest')
    matches = [item for item in manifest['fixtures'] if item['file'] == expected_name]
    if len(matches) != 1:
        raise ValueError('Expected exactly one manifest entry for this fixture')
    expected = matches[0]
    if received.name != expected_name:
        raise ValueError(f'Filename mismatch: expected {expected_name}')
    size = received.stat().st_size
    if size != expected['bytes'] or size > MAX_FIXTURE_BYTES:
        raise ValueError('Received size does not match the fixture manifest')
    data = received.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != expected['sha256']:
        raise ValueError('Received SHA-256 does not match the fixture manifest')
    if received.suffix == '.json':
        value = json.loads(data)
        if value.get('synthetic') is not True:
            raise ValueError('Fixture is not marked synthetic')
        if expected_name == 'synthetic-report.json':
            if len(value['journals']) != 3:
                raise ValueError('Representative report must contain three journals')
            for journal in value['journals']:
                if len(journal['events']) != journal['eventCount']:
                    raise ValueError('Representative report event count is incorrect')
                if not all(event['details']['synthetic'] == 'true' for event in journal['events']):
                    raise ValueError('Non-synthetic event in representative report')
    elif received.suffix == '.zip':
        # Only inspect after exact byte verification against the trusted manifest.
        with zipfile.ZipFile(received) as archive:
            if archive.testzip() is not None or len(archive.namelist()) != 3:
                raise ValueError('Invalid synthetic ZIP')
            for name in archive.namelist():
                if not all(row['details']['synthetic'] == 'true' for row in json.loads(archive.read(name))):
                    raise ValueError('Non-synthetic event in ZIP')
    else:
        raise ValueError('Unexpected fixture extension')
    return {'verified': True, 'file': expected_name, 'bytes': size,
            'sha256': digest, 'parsed': True,
            'note': 'Bytes verified; transport and sender must be recorded separately.'}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest='action', required=True)
    create = actions.add_parser('generate')
    create.add_argument('--destination', type=Path, required=True)
    create.add_argument('--manifest', type=Path, required=True)
    check = actions.add_parser('verify')
    check.add_argument('--manifest', type=Path, required=True)
    check.add_argument('--received', type=Path, required=True)
    check.add_argument('--fixture', required=True,
                       choices=['synthetic-small.json', 'synthetic-report.json', 'synthetic-journals.zip'])
    args = parser.parse_args()
    try:
        if args.action == 'generate':
            result = generate(args.destination)
            args.manifest.write_bytes(encode(result))
        else:
            result = verify(json.loads(args.manifest.read_bytes()), args.received, args.fixture)
        print(json.dumps(result, indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        print(f'Fixture check failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
