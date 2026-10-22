#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Verify a real app is included. This is unsigned structural validation,
# not App Store validation or permission to install on a physical Watch.
set -eu
cd "$(dirname "$0")/.."
archive_dir=$(mktemp -d /tmp/TeachingTimerArchive.XXXXXX)
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
