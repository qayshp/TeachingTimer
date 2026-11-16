#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
set -eu
probe_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
probe_output=${1:?Pass a NEW output directory}
if [ -e "$probe_output" ]; then
    printf 'Output already exists: %s\n' "$probe_output" >&2
    exit 1
fi
probe_app="$probe_output/WatchAudioProbe.app"
mkdir -p "$probe_app"
cp "$probe_source/Info.plist" "$probe_app/Info.plist"
# Exactly 180 seconds of all-zero signed 16-bit PCM: no tone or audible sample.
python3 - "$probe_app/silence.wav" <<'PY'
import sys, wave
with wave.open(sys.argv[1], 'wb') as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(22050)
    f.writeframes(bytes(180 * 22050 * 2))
PY
probe_sdk=$(xcrun --sdk watchsimulator --show-sdk-path)
probe_arch=$(uname -m)
xcrun --sdk watchsimulator swiftc -warnings-as-errors -parse-as-library -swift-version 5 \
    -sdk "$probe_sdk" -target "$probe_arch-apple-watchos26.0-simulator" \
    "$probe_source/WatchAudioProbe.swift" -o "$probe_app/WatchAudioProbe"
codesign --force --sign - "$probe_app"
printf 'Simulator-only silent app: %s\n' "$probe_app"
