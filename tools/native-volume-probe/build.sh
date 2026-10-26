#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
set -eu
probe_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
probe_output=${1:-"$probe_source/../../work/native-volume-probe"}
probe_app="$probe_output/NativeVolumeProbe.app"
mkdir -p "$probe_app"
probe_sdk=$(xcrun --sdk watchsimulator --show-sdk-path)
probe_arch=$(uname -m)
xcrun --sdk watchsimulator swiftc -parse-as-library -sdk "$probe_sdk" \
    -target "$probe_arch-apple-watchos26.0-simulator" \
    "$probe_source/NativeVolumeProbe.swift" -o "$probe_app/NativeVolumeProbe"
cp "$probe_source/Info.plist" "$probe_app/Info.plist"
codesign --force --sign - "$probe_app"
printf 'Simulator app: %s\n' "$probe_app"
