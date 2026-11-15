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
xcrun --sdk macosx swiftc -warnings-as-errors "$physical_source/HubControl.swift" -o "$physical_output/HubControl"
codesign --force --sign - "$physical_output/HubControl"
codesign --verify --strict "$physical_output/HubControl"
printf 'Physical input helper compiled only; no AX or device action: %s\n' "$physical_output/HubControl"
