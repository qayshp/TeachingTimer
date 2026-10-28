#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
# Local, unsigned structural rehearsal only. No upload or provisioning changes.
set -eu
cd "$(dirname "$0")/.."
if [ "$#" -ne 1 ]; then
  printf 'Usage: sh scripts/prepare-testflight.sh NEW_OUTPUT_DIRECTORY\n' >&2
  exit 2
fi
if [ -e "$1" ]; then
  printf 'Use a new output directory; existing artifacts are never overwritten.\n' >&2
  exit 2
fi
umask 077
mkdir -p "$1"
output=$(CDPATH= cd -- "$1" && pwd)
xcodebuild -project TeachingTimer.xcodeproj -scheme TeachingTimer \
  -configuration Release -destination 'generic/platform=watchOS' \
  -xcconfig Configurations/TestFlight.xcconfig \
  -archivePath "$output/TeachingTimer.xcarchive" \
  CODE_SIGNING_ALLOWED=NO archive > "$output/build.log" 2>&1 || {
  tail -60 "$output/build.log"
  exit 1
}
python3 - "$output" <<'PY'
import json
from pathlib import Path
import plistlib
import sys
root = Path(sys.argv[1])
app = root / 'TeachingTimer.xcarchive/Products/Applications/TeachingTimer.app'
info = plistlib.loads((app / 'Info.plist').read_bytes())
checks = {
    'distributionIdentifier': info['CFBundleIdentifier'] == 'net.qays.TeachingTimer',
    'watchOnly': info.get('WKWatchOnly') is True,
    'watchApplication': info.get('WKApplication') is True,
    'mindfulnessRuntime': 'mindfulness' in info.get('WKBackgroundModes', []),
    'binaryPresent': (app / info['CFBundleExecutable']).is_file(),
    'symbolsPresent': (root / 'TeachingTimer.xcarchive/dSYMs/TeachingTimer.app.dSYM').is_dir(),
}
result = {'checks': checks, 'version': info['CFBundleShortVersionString'],
          'build': info['CFBundleVersion'], 'signed': False, 'uploaded': False,
          'appStoreValidation': 'not performed', 'journalAccess': 'not verified'}
(root / 'readiness.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
if not all(checks.values()):
    sys.exit(1)
PY

python3 scripts/inspect-artifact.py "$output/TeachingTimer.xcarchive" > "$output/artifact-inspection.json"
