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
python3 "$probe_source/fixtures.py" generate --destination "$probe_app" \
    --manifest "$probe_output/fixtures.json"
printf '%s\n' "$probe_sdk" > "$probe_output/sdk-path.txt"
printf '%s\n' "$probe_sdk_version" > "$probe_output/sdk-version.txt"

xcodebuild -version > "$probe_output/xcode-version.txt"
xcrun --sdk watchsimulator swiftc -warnings-as-errors -parse-as-library -swift-version 6 -sdk "$probe_sdk" \
    -target "$probe_arch-apple-watchos26.0-simulator" \
    "$probe_source/DiagnosticShareProbe.swift" -o "$probe_app/DiagnosticShareProbe"
codesign --force --sign - "$probe_app"
codesign --verify --deep --strict "$probe_app"
printf 'Simulator-only app: %s\n' "$probe_app"
