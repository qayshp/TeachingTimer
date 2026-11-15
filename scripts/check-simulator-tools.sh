#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# Compile diagnostic fixtures/helpers and run host-only wire self-tests.
set -eu
cd "$(dirname "$0")/.."
tool_output=${1:?Pass a NEW output directory}
if [ -e "$tool_output" ]; then
    printf 'Output already exists: %s\n' "$tool_output" >&2
    exit 1
fi
mkdir -p "$tool_output"
tool_output=$(CDPATH= cd -- "$tool_output" && pwd)
for probe in phone-audio-probe native-volume-probe crown-event-probe timeline-clock-probe diagnostic-share-probe watch-audio-probe watch-local-volume-probe; do
    sh "tools/$probe/build.sh" "$tool_output/$probe"
done
# Reuse the two apps built above; the lab still compiles its host transport and
# Simulator hook, verifies signatures and exercises both local wire profiles.
sh tools/watch-media-lab/build.sh "$tool_output/watch-media-lab" "$tool_output"
for helper in HubInput ScreenText MediaPixels ControlOutline; do
    xcrun --sdk macosx swiftc -warnings-as-errors "tools/simulator-regression/$helper.swift" -o "$tool_output/$helper"
done
xcrun --sdk macosx swiftc -warnings-as-errors scripts/check-screen-text.swift -o "$tool_output/check-screen-text"
printf 'All seven Simulator fixtures, native lab, four inspection helpers and the OCR smoke fixture compiled; both host wire self-tests passed. No Simulator or app launched.\n'
