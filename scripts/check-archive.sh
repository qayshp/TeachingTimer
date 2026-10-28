#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Verify a real app is included. This is unsigned structural validation,
# not App Store validation or permission to install on a physical Watch.
set -eu
cd "$(dirname "$0")/.."
if [ "$#" -gt 1 ]; then
  printf 'Usage: sh scripts/check-archive.sh [NEW_OUTPUT_DIRECTORY]\n' >&2
  exit 2
fi
if [ "$#" -eq 1 ]; then
  test ! -e "$1" || { printf 'Output already exists\n' >&2; exit 2; }
  mkdir -p "$1"
  archive_dir=$(CDPATH= cd -- "$1" && pwd)
else
  archive_dir=$(mktemp -d /tmp/TeachingTimerArchive.XXXXXX)
fi
xcodebuild -project TeachingTimer.xcodeproj -scheme TeachingTimer \
  -configuration Release -destination 'generic/platform=watchOS' \
  -archivePath "$archive_dir/TeachingTimer.xcarchive" \
  CODE_SIGNING_ALLOWED=NO archive > "$archive_dir/build.log" 2>&1 || {
  tail -80 "$archive_dir/build.log"
  exit 1
}
app="$archive_dir/TeachingTimer.xcarchive/Products/Applications/TeachingTimer.app"
test -x "$app/TeachingTimer"
test -f "$app/Info.plist"
printf 'PASS: archive contains the Watch application: %s\n' "$app"

python3 scripts/inspect-artifact.py "$archive_dir/TeachingTimer.xcarchive" > "$archive_dir/readiness.json"
