#!/bin/sh
# Xcode build phase: generated product metadata, never source-file mutation.
set -eu
revision=${SOURCE_REVISION:-$(git -C "$SRCROOT" rev-parse --short=12 HEAD 2>/dev/null || printf 'source-export')}
if test -n "$(git -C "$SRCROOT" status --porcelain --untracked-files=no 2>/dev/null)"; then
  revision="$revision-dirty"
fi
output="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/BuildInfo.plist"
mkdir -p "$(dirname "$output")"
/usr/libexec/PlistBuddy -c 'Clear dict' "$output" >/dev/null
/usr/libexec/PlistBuddy -c "Add :revision string $revision" "$output"
/usr/libexec/PlistBuddy -c "Add :builtAt string $(date -u +%Y-%m-%dT%H:%M:%SZ)" "$output"
