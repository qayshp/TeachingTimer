#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Prepare exact-source TestFlight notes or materialize the same bounded payload.

No network, credentials, app builds or device operations. Empty manual input
selects curated notes; an explicit invalid override fails instead of falling back.
"""
import argparse
import base64
import binascii
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

NOTES_PATH = 'TestFlight/WhatToTest.en-US.txt'
MAX_CHARACTERS = 4000
MAX_PAYLOAD_BYTES = 40000


def validate_text(text):
    if not isinstance(text, str) or not text.strip() or len(text) > MAX_CHARACTERS:
        raise ValueError('Testing notes must contain 1–4000 characters')
    if any(ord(character) < 32 and character not in '\n\t' or ord(character) == 127 for character in text):
        raise ValueError('Testing notes contain unsupported control characters; use LF newlines')
    return text


def sha256(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def validate_sha(value):
    if not re.fullmatch('[0-9a-f]{40}', value):
        raise ValueError('Expected the full application source SHA')
    return value


def git(source, *arguments):
    return subprocess.check_output(['git', '-C', str(source), *arguments], timeout=10)


def prepare(source, expected_sha, override=''):
    validate_sha(expected_sha)
    actual = git(source, 'rev-parse', 'HEAD').decode().strip()
    if actual != expected_sha:
        raise ValueError('Application source differs from the selected workflow commit')
    if override != '':
        text, origin = override, 'manual-override'
    else:
        entry = git(source, 'ls-tree', expected_sha, '--', NOTES_PATH).decode().strip()
        if not entry.startswith('100644 blob ') and not entry.startswith('100755 blob '):
            raise ValueError('Reviewed source is missing a regular ' + NOTES_PATH)
        blob = expected_sha + ':' + NOTES_PATH
        if int(git(source, 'cat-file', '-s', blob)) > MAX_CHARACTERS * 4:
            raise ValueError('Reviewed notes exceed the bounded input size')
        text, origin = git(source, 'show', blob).decode('utf-8'), 'repository'
    validate_text(text)
    return dict(schemaVersion=1, sourceSHA=expected_sha, locale='en-US', origin=origin,
                sourcePath=NOTES_PATH if origin == 'repository' else None,
                text=text, notesSHA256=sha256(text), characterCount=len(text))


def encode(payload):
    return base64.b64encode(json.dumps(payload, ensure_ascii=False).encode('utf-8')).decode('ascii')


def decode(value, expected_sha):
    validate_sha(expected_sha)
    if len(value) > MAX_PAYLOAD_BYTES:
        raise ValueError('Notes payload exceeds its bounded size')
    try:
        payload = json.loads(base64.b64decode(value, validate=True).decode('utf-8'))
    except (ValueError, UnicodeError, binascii.Error) as error:
        raise ValueError('Invalid notes payload') from error
    if (not isinstance(payload, dict) or type(payload.get('schemaVersion')) is not int
            or payload.get('schemaVersion') != 1):
        raise ValueError('Unsupported notes payload schema')
    text = validate_text(payload.get('text'))
    if payload.get('sourceSHA') != expected_sha or payload.get('locale') != 'en-US':
        raise ValueError('Notes payload application source or locale differs')
    if payload.get('origin') not in ('repository', 'manual-override'):
        raise ValueError('Unknown notes origin')
    source_path = NOTES_PATH if payload['origin'] == 'repository' else None
    if payload.get('sourcePath') != source_path:
        raise ValueError('Notes source path differs')
    if (payload.get('notesSHA256') != sha256(text) or type(payload.get('characterCount')) is not int
            or payload.get('characterCount') != len(text)):
        raise ValueError('Notes content hash or character count differs')
    return payload


def write(payload, output):
    # New output only: do not overwrite an earlier reviewed release's notes.
    output.mkdir(parents=True, exist_ok=False)
    (output / 'notes.txt').write_text(payload['text'], encoding='utf-8')
    receipt = {key: value for key, value in payload.items() if key != 'text'}
    (output / 'notes.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--source', type=Path, help='Application checkout; read notes from its selected Git commit')
    mode.add_argument('--payload-env', help='Environment variable holding the source job’s prepared payload')
    parser.add_argument('--expected-sha', required=True)
    parser.add_argument('--override-env', help='Optional manual input environment variable; never shell-evaluated')
    parser.add_argument('--output', required=True, type=Path, help='NEW notes directory')
    parser.add_argument('--github-output', type=Path, help='Append a single-line bounded notes_payload output')
    args = parser.parse_args(argv)
    try:
        if args.payload_env:
            if args.override_env:
                raise ValueError('A prepared payload cannot be overridden during release')
            payload = decode(os.environ.get(args.payload_env, ''), args.expected_sha)
        else:
            override = os.environ.get(args.override_env, '') if args.override_env else ''
            payload = prepare(args.source, args.expected_sha, override)
        write(payload, args.output)
        if args.github_output:
            with args.github_output.open('a', encoding='utf-8') as output:
                output.write('notes_payload=' + encode(payload) + '\n')
        print(json.dumps({key: value for key, value in payload.items() if key != 'text'}))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.exit(2, str(error) + '\n')


if __name__ == '__main__':
    main()
