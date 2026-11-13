#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# Run the synthetic screenshot measurement check without a Simulator.
set -eu
cd "$(dirname "$0")/.."
tool_output=${1:?Pass a NEW output directory}
if [ -e "$tool_output" ]; then
    printf 'Output already exists: %s\n' "$tool_output" >&2
    exit 1
fi
mkdir -p "$tool_output"
tool_output=$(CDPATH= cd -- "$tool_output" && pwd)
xcrun --sdk macosx swiftc -warnings-as-errors tools/simulator-regression/ControlOutline.swift -o "$tool_output/ControlOutline"
xcrun --sdk macosx swiftc -warnings-as-errors scripts/check-control-outline.swift -o "$tool_output/check-control-outline"
"$tool_output/check-control-outline" "$tool_output/ControlOutline" "$tool_output/fixtures"
