#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
set -eu
physical_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
physical_output=${1:?Pass a NEW output directory}
if [ -e "$physical_output" ]; then
    printf 'Output already exists: %s\n' "$physical_output" >&2
    exit 1
fi
mkdir -p "$physical_output"
for physical_helper in HubControl WindowList; do
    xcrun --sdk macosx swiftc -warnings-as-errors "$physical_source/$physical_helper.swift" -o "$physical_output/$physical_helper"
    codesign --force --sign - "$physical_output/$physical_helper"
    codesign --verify --strict "$physical_output/$physical_helper"
done
printf 'Physical input and read-only window helpers compiled only; no AX, window query or device action: %s\n' "$physical_output"
