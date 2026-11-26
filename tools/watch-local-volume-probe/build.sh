#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
set -eu
probe_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
probe_output=${1:?Pass a NEW output directory}
if [ -e "$probe_output" ]; then
    printf 'Output already exists: %s\n' "$probe_output" >&2
    exit 1
fi
probe_app="$probe_output/WatchLocalVolumeProbe.app"
mkdir -p "$probe_app"
cp "$probe_source/Info.plist" "$probe_app/Info.plist"
python3 - "$probe_app/tone.wav" <<'PY'
import math, struct, sys, wave
# Same quiet pulsed 440-Hz PCM as the October 24 fixture, finite rather than looping.
block = b''.join(struct.pack('<h', round(2400 * math.sin(2 * math.pi * 440 * i / 44100)
                    * (0.55 + 0.45 * math.cos(2 * math.pi * i / 44100)))) for i in range(88200))
with wave.open(sys.argv[1], 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(44100)
    for _ in range(60):
        output.writeframesraw(block)
PY
probe_sdk=$(xcrun --sdk watchsimulator --show-sdk-path)
probe_arch=$(uname -m)
xcrun --sdk watchsimulator swiftc -warnings-as-errors -parse-as-library -swift-version 5 \
    -sdk "$probe_sdk" -target "$probe_arch-apple-watchos26.0-simulator" \
    "$probe_source/WatchLocalVolumeProbe.swift" -o "$probe_app/WatchLocalVolumeProbe"
codesign --force --sign - "$probe_app"
printf 'Simulator-only local-volume app: %s\n' "$probe_app"
