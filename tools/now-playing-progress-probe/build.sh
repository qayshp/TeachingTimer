#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
set -eu

probe_output=${1:?Pass a new output directory}
probe_destination=${2:-simulator}
case "$probe_destination" in
    simulator) probe_sdk=watchsimulator; probe_platform=WatchSimulator ;;
    device) probe_sdk=watchos; probe_platform=WatchOS ;;
    *) printf 'Expected simulator or device, got %s\n' "$probe_destination" >&2; exit 2 ;;
esac
if [ -e "$probe_output" ]; then
    printf 'Output already exists: %s\n' "$probe_output" >&2
    exit 1
fi

probe_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
probe_sdk_path=$(xcrun --sdk "$probe_sdk" --show-sdk-path)
probe_app="$probe_output/NowPlayingProgressProbe.app"
probe_binary="$probe_app/NowPlayingProgressProbe"
mkdir -p "$probe_app"
cp "$probe_source/Info.plist" "$probe_app/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleSupportedPlatforms array" \
    -c "Add :CFBundleSupportedPlatforms:0 string $probe_platform" "$probe_app/Info.plist"

compile_probe() {
    xcrun --sdk "$probe_sdk" swiftc -warnings-as-errors -parse-as-library -swift-version 6 \
        -sdk "$probe_sdk_path" "$@" "$probe_source/NowPlayingProgressProbe.swift"
}

if [ "$probe_destination" = simulator ]; then
    compile_probe -target "$(uname -m)-apple-watchos26.0-simulator" -o "$probe_binary"
    codesign --force --sign - "$probe_app"
    codesign --verify --deep --strict "$probe_app"
    printf 'Simulator app: %s\n' "$probe_app"
else
    for probe_arch in arm64 arm64_32; do
        compile_probe -target "$probe_arch-apple-watchos26.0" -Xlinker -no_adhoc_codesign \
            -o "$probe_output/$probe_arch"
    done
    xcrun --sdk "$probe_sdk" lipo -create "$probe_output/arm64" "$probe_output/arm64_32" \
        -output "$probe_binary"
    rm "$probe_output/arm64" "$probe_output/arm64_32"
    printf 'Unsigned device app: %s\n' "$probe_app"
fi
