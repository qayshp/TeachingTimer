#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
set -eu
probe_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
probe_output=${1:?Pass a NEW output directory}
if [ -e "$probe_output" ]; then
    printf 'Output already exists: %s\n' "$probe_output" >&2
    exit 1
fi
probe_app="$probe_output/PhoneAudioProbe.app"
mkdir -p "$probe_app"
cp "$probe_source/Info.plist" "$probe_app/Info.plist"
# Generate a quiet local tone. No server, account or downloaded audio dependency.
python3 - "$probe_app/tone.wav" <<'PY'
import math,struct,sys,wave
with wave.open(sys.argv[1], 'wb') as f:
    f.setnchannels(1); f.setsampwidth(2); f.setframerate(22050)
    f.writeframes(b''.join(struct.pack('<h', round(120 * math.sin(2 * math.pi * 220 * i/22050))) for i in range(22050 * 30)))
PY
probe_sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
probe_arch=$(uname -m)
xcrun --sdk iphonesimulator swiftc -parse-as-library -swift-version 5 -sdk "$probe_sdk" \
    -target "$probe_arch-apple-ios26.0-simulator" "$probe_source/PhoneAudioProbe.swift" \
    -o "$probe_app/PhoneAudioProbe"
codesign --force --sign - "$probe_app"
printf 'Simulator-only app: %s\n' "$probe_app"
