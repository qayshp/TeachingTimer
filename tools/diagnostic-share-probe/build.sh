#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
set -eu
umask 077
probe_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
probe_output=${1:?Pass a NEW output directory}
if [ -e "$probe_output" ]; then
    printf 'Output already exists: %s\n' "$probe_output" >&2
    exit 1
fi
probe_sdk=$(xcrun --sdk watchsimulator --show-sdk-path)
probe_sdk_version=$(xcrun --sdk watchsimulator --show-sdk-version)
probe_arch=$(uname -m)
probe_app="$probe_output/DiagnosticShareProbe.app"
mkdir -p "$probe_app"
cp "$probe_source/Info.plist" "$probe_app/Info.plist"

# Fixed synthetic data only. No files are read from TeachingTimer or devices.
python3 - "$probe_app" "$probe_sdk" "$probe_sdk_version" <<'PY'
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import random
import sys
import zipfile

app = Path(sys.argv[1])
small = app / 'synthetic-small.json'
small.write_text(json.dumps({'synthetic': True, 'message': 'Harmless sharing fixture; not user diagnostics.',
                            'events': [{'event': 'fixture_only', 'details': {'count': '1'}}]}, indent=2) + '\n')
rng = random.Random(42)
start = datetime(2000, 1, 1, tzinfo=timezone.utc)
archive_path = app / 'synthetic-journals.zip'
with zipfile.ZipFile(archive_path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for kind, count in [('Runtime', 10000), ('Interface', 4000), ('Landmark', 20000)]:
        rows = [{'timestamp': (start + timedelta(seconds=index)).isoformat(),
                 'event': 'synthetic_' + kind.lower(),
                 'details': {'synthetic': 'true', 'sequence': str(index),
                             'fixtureToken': '%032x' % rng.getrandbits(128),
                             'message': 'Generated fixture. No user, device, class, or audio data.'}}
                for index in range(count)]
        member = zipfile.ZipInfo('Synthetic' + kind + 'Diagnostics.json', date_time=(2000, 1, 1, 0, 0, 0))
        member.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(member, json.dumps(rows, separators=(',', ':')) + '\n')
with zipfile.ZipFile(archive_path) as archive:
    assert archive.testzip() is None
    assert len(archive.namelist()) == 3
    for name in archive.namelist():
        assert all(row['details']['synthetic'] == 'true' for row in json.loads(archive.read(name)))
manifest = {'sdkPath': sys.argv[2], 'sdkVersion': sys.argv[3], 'syntheticOnly': True,
            'fixtures': [{'file': file.name, 'bytes': file.stat().st_size,
                          'sha256': hashlib.sha256(file.read_bytes()).hexdigest()}
                         for file in (small, archive_path)]}
(app.parent / 'fixtures.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
PY

xcodebuild -version > "$probe_output/xcode-version.txt"
xcrun --sdk watchsimulator swiftc -warnings-as-errors -parse-as-library -swift-version 6 -sdk "$probe_sdk" \
    -target "$probe_arch-apple-watchos26.0-simulator" \
    "$probe_source/DiagnosticShareProbe.swift" -o "$probe_app/DiagnosticShareProbe"
codesign --force --sign - "$probe_app"
codesign --verify --deep --strict "$probe_app"
printf 'Simulator-only app: %s\n' "$probe_app"
