#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
set -eu
lab_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
lab_output=${1:-"$lab_source/../../work/watch-media-lab"}
lab_reuse=${2:-}
mkdir -p "$lab_output"
lab_output=$(CDPATH= cd -- "$lab_output" && pwd)
lab_arch=$(uname -m)
lab_host_sdk=$(xcrun --sdk macosx --show-sdk-path)
lab_watch_sdk=$(xcrun --sdk watchsimulator --show-sdk-path)

xcrun --sdk macosx clang -isysroot "$lab_host_sdk" -fno-objc-arc -fblocks \
  -std=gnu11 -Wall -Wextra -Werror -O2 -framework Foundation \
  "$lab_source/CrownHIDBridge.m" -o "$lab_output/CrownHIDBridge"
codesign --force --sign - "$lab_output/CrownHIDBridge"
codesign --verify --strict "$lab_output/CrownHIDBridge"
# Local wire dictionaries only: these self-tests never load CoreSimulator.
"$lab_output/CrownHIDBridge" --self-test > "$lab_output/host-self-test.json"
"$lab_output/CrownHIDBridge" --profile zero-began --self-test > "$lab_output/host-zero-began-self-test.json"

xcrun --sdk watchsimulator clang -fobjc-arc -fblocks -Wall -Wextra -Werror \
  -dynamiclib -isysroot "$lab_watch_sdk" \
  -target "$lab_arch-apple-watchos26.0-simulator" -framework Foundation \
  "$lab_source/NativeBaselineHook.m" -o "$lab_output/NativeBaselineHook.dylib"
codesign --force --sign - "$lab_output/NativeBaselineHook.dylib"
codesign --verify --strict "$lab_output/NativeBaselineHook.dylib"

# Optional reuse is for the compile guard, which has just built both public
# apps from the same checkout. Copy into the lab layout without changing inputs.
if [ -n "$lab_reuse" ]; then
  lab_reuse=$(CDPATH= cd -- "$lab_reuse" && pwd)
  for lab_probe in native-volume-probe crown-event-probe; do
    if [ -e "$lab_output/$lab_probe" ]; then
      printf 'Reuse requires a new probe destination: %s\n' "$lab_output/$lab_probe" >&2
      exit 1
    fi
    codesign --verify --deep --strict "$lab_reuse/$lab_probe/"*.app
    cp -R "$lab_reuse/$lab_probe" "$lab_output/$lab_probe"
  done
else
  # Build ordinary uninjected fixtures for restoration; no Simulator is queried.
  sh "$lab_source/../native-volume-probe/build.sh" "$lab_output/native-volume-probe"
  sh "$lab_source/../crown-event-probe/build.sh" "$lab_output/crown-event-probe"
fi
codesign --verify --deep --strict "$lab_output/native-volume-probe/NativeVolumeProbe.app"
codesign --verify --deep --strict "$lab_output/crown-event-probe/CrownEventProbe.app"
python3 - "$lab_source" "$lab_output" "$lab_host_sdk" "$lab_watch_sdk" "$lab_reuse" <<'PY'
import hashlib, json, subprocess, sys
from pathlib import Path
source, output = map(Path, sys.argv[1:3])
names = ["CrownHIDBridge.m", "NativeBaselineHook.m", "native-state.py", "calibrate.py", "analyze-calibration.py"]
manifest = {"hostSDK": sys.argv[3], "watchSimulatorSDK": sys.argv[4],
            "reusedProbeRoot": sys.argv[5] or None,
            "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
            "sourceSHA256": {name: hashlib.sha256((source / name).read_bytes()).hexdigest() for name in names},
            "deviceOperations": 0, "simulatorOperations": 0,
            "runtimeValidation": "not performed by build; host wire self-tests only"}
(output / "build.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY
printf 'Host and Simulator-only lab artifacts: %s\n' "$lab_output"
