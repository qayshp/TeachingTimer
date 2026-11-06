#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# Compile the diagnostic fixtures and UI-inspection helpers without running them.
set -eu
cd "$(dirname "$0")/.."
tool_output=${1:?Pass a NEW output directory}
if [ -e "$tool_output" ]; then
    printf 'Output already exists: %s\n' "$tool_output" >&2
    exit 1
fi
mkdir -p "$tool_output"
tool_output=$(CDPATH= cd -- "$tool_output" && pwd)
for probe in phone-audio-probe native-volume-probe timeline-clock-probe diagnostic-share-probe; do
    sh "tools/$probe/build.sh" "$tool_output/$probe"
done
for helper in HubInput ScreenText MediaPixels ControlOutline; do
    xcrun --sdk macosx swiftc "tools/simulator-regression/$helper.swift" -o "$tool_output/$helper"
done
printf 'All four Simulator fixtures and four inspection helpers compiled. Nothing launched.\n'
