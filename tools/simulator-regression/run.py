#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Bounded SE 3 regression capture. Requires an explicitly named disposable Simulator."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import time


def checked(*args, timeout=30):
    return subprocess.run([str(x) for x in args], check=True, capture_output=True, text=True, timeout=timeout).stdout.strip()


def reset_test_app(simulator, bundle):
    """An uninstall error must not silently turn a fresh-state test into a reuse."""
    def installed():
        raw = checked("xcrun", "simctl", "listapps", simulator)
        # simctl emits an OpenStep plist, not necessarily XML/binary. Python's
        # plistlib does not parse that format; Apple's plutil accepts all three.
        converted = subprocess.run(["plutil", "-convert", "json", "-o", "-", "--", "-"],
                                   input=raw, text=True, capture_output=True, check=True, timeout=30)
        return json.loads(converted.stdout)
    if bundle in installed():
        checked("xcrun", "simctl", "uninstall", simulator, bundle)
    if bundle in installed():
        raise RuntimeError("Test app remains installed after reset")


def events_after(baseline, current):
    """Use the last observed event, not a length offset invalidated by retention."""
    if not baseline:
        return current
    matches = [i for i, event in enumerate(current) if event == baseline[-1]]
    if len(matches) != 1:
        raise ValueError("Journal boundary lost or ambiguous; cannot establish fresh events")
    return current[matches[0] + 1:]


def select_service(output):
    labels = []
    for line in output.splitlines():
        fields = line.split()
        if len(fields) == 3 and fields[0].isdigit() and int(fields[0]) > 0 and fields[2].startswith("UIKitApplication:com.apple.NanoNowPlayingViewService["):
            labels.append(fields[2])
    if len(labels) != 1:
        raise ValueError(f"Expected exactly one running Now Playing view service, found {len(labels)}")
    return labels[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", required=True)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--scenario", required=True, choices=["focus", "media"])
    parser.add_argument("--allow-service-termination", action="store_true")
    args = parser.parse_args()
    if args.scenario == "media" and not args.allow_service_termination:
        parser.error("media scenario requires explicit --allow-service-termination")
    devices = json.loads(checked("xcrun", "simctl", "list", "devices", "--json"))
    selected = [d for ds in devices["devices"].values() for d in ds if d["udid"] == args.simulator]
    if len(selected) != 1 or selected[0]["state"] != "Booted" or not selected[0]["name"].startswith("TeachingTimer Regression") or "Apple-Watch-SE-3-40mm" not in selected[0].get("deviceTypeIdentifier", ""):
        parser.error("Use a booted disposable SE 3 40mm named 'TeachingTimer Regression…'; no physical devices or existing personal simulators")
    app_info = plistlib.loads((args.app / "Info.plist").read_bytes())
    if "WatchSimulator" not in app_info.get("CFBundleSupportedPlatforms", []):
        parser.error("Expected a Watch Simulator app")
    bundle = app_info["CFBundleIdentifier"]
    if bundle != "com.qayshp.TeachingTimer":
        parser.error("This coordinate sequence is only for the development TeachingTimer app")
    os.umask(0o077)
    args.output.mkdir(parents=True, exist_ok=False)
    helper = args.output.resolve() / "hub-input"
    checked("swiftc", Path(__file__).with_name("HubInput.swift"), "-o", helper, timeout=60)
    pid = checked("pgrep", "-x", "DeviceHub")
    if not pid.isdigit():
        raise RuntimeError("Expected one Device Hub process")
    actions = []
    def action(name, *command):
        item = {"at": datetime.now(timezone.utc).isoformat(), "action": name, "command": list(map(str, command)), "status": "started"}
        actions.append(item)
        (args.output / "actions.json").write_text(json.dumps(actions, indent=2))
        try:
            result = checked(*command)
            item.update(status="returned", output=result)
            return result
        finally:
            (args.output / "actions.json").write_text(json.dumps(actions, indent=2))
    def sim(name, *command):
        return action(name, "xcrun", "simctl", *command)
    def ui(name, *parameters):
        action(name, helper, pid, args.simulator, *parameters)
        time.sleep(0.6)
    sim("install", "install", args.simulator, args.app.resolve())
    launch = sim("launch", "launch", args.simulator, bundle)
    host_pid = launch.rsplit(":", 1)[-1].strip()
    time.sleep(2)
    container = Path(checked("xcrun", "simctl", "get_app_container", args.simulator, bundle, "data"))
    def preferences():
        path = container / "Library/Preferences" / (bundle + ".plist")
        return plistlib.loads(path.read_bytes()) if path.exists() else {}
    def capture(label):
        time.sleep(0.5)
        sim(label, "io", args.simulator, "screenshot", (args.output / (label + ".png")).resolve())
        for name in ("RuntimeDiagnostics", "InterfaceDiagnostics", "LandmarkDiagnostics"):
            source = container / "Documents" / (name + ".json")
            if source.exists():
                shutil.copy2(source, args.output / (label + "-" + name + ".json"))
        (args.output / (label + "-preferences.plist")).write_bytes(plistlib.dumps(preferences()))
    def journal():
        return json.loads((container / "Documents/RuntimeDiagnostics.json").read_text())
    ui("select/bounds", "bounds")
    capture("01-before")
    if "teachingClassContext.v1" not in preferences():
        ui("start-menu", "tap", .5, .76)
        ui("confirm-default-class", "tap", .5, .44)
        # UserDefaults can flush after the UI/journal has already accepted Start.
        # Wait only for this setup prerequisite; do not mistake disk lag for loss.
        deadline = time.monotonic() + 10
        while "teachingClassContext.v1" not in preferences() and time.monotonic() < deadline:
            time.sleep(0.25)
    original_class = preferences().get("teachingClassContext.v1")
    if not original_class:
        raise RuntimeError("Class was not established; inspect captures before continuing")
    capture("02-class")
    baseline = journal()
    controls = {e["details"]["controlID"] for e in baseline if e["event"] == "volume_control_created"}
    ui("start-count", "tap", .5, .76)
    if args.scenario == "focus":
        ui("crown-up-initial", "crown", 8); capture("03-initial-crown")
        ui("home", "home")
        time.sleep(1)
        returned = sim("reopen", "launch", args.simulator, bundle)
        time.sleep(2)
        ui("crown-down-home", "crown", -8); capture("04-home-crown")
        ui("refresh", "tap", .5, .32)
        time.sleep(1)
        ui("crown-up-refresh", "crown", 8); capture("05-refresh-crown")
        ui("media", "swipe", .85, .55, .15, .55); capture("06-media")
        ui("timer", "swipe", .15, .55, .85, .55)
        ui("crown-down-return", "crown", -8); capture("07-return-crown")
    else:
        ui("media", "swipe", .85, .55, .15, .55); capture("03-media-before-fault")
        time.sleep(5)
        capture("03b-media-before-fault-after-five-seconds")
        ui("home", "home")
        listing = sim("service-inventory", "spawn", args.simulator, "launchctl", "list")
        service = select_service(listing)
        sim("terminate-view-service", "spawn", args.simulator, "launchctl", "kill", "SIGKILL", "system/" + service)
        returned = sim("reopen", "launch", args.simulator, bundle)
        time.sleep(2)
        capture("04-media-return")
        time.sleep(5)
        capture("04b-media-return-after-five-seconds")
        ui("timer", "swipe", .15, .55, .85, .55); capture("05-timer")
        ui("media-reentry", "swipe", .85, .55, .15, .55); capture("06-media-reentry")
        time.sleep(5)
        capture("06b-media-after-five-seconds")
        ui("timer-finish", "swipe", .15, .55, .85, .55); capture("07-final")
    final = journal()
    new = events_after(baseline, final)
    checks = {
        "sameHostPID": returned.rsplit(":", 1)[-1].strip() == host_pid,
        "sameClassBytes": preferences().get("teachingClassContext.v1") == original_class,
        "noNewVolumeControl": not any(e["event"] == "volume_control_created" and e["details"].get("controlID") not in controls for e in new),
        "mediaPageSelected": any(e["event"] == "page_selection_changed" and e["details"].get("selectedPage") == "nowPlaying" for e in new),
        "automaticMediaRefreshRequested": any(e["event"] == "media_reload_requested" for e in new),
    }
    if args.scenario == "focus":
        checks["manualRefreshRequested"] = any(e["event"] == "volume_refresh_requested" for e in new)
    result = {"checks": checks, "visualResult": "REVIEW_SCREENSHOTS_REQUIRED", "actualPhoneVolume": "unverified", "note": "Lifecycle checks are not pixel, audio or haptic-delivery assertions."}
    (args.output / "result.json").write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    if not all(checks.values()):
        raise SystemExit(2)


if __name__ == "__main__":
    main()
