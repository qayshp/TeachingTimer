#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Capture native media frames beside real silent-player samples in a disposable Watch.

Default writes a plan only. --execute targets an already booted regression
Simulator and installed synthetic source; no physical devices, boot or install.
Native progress still requires visual review; a passing player gate is separate.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
BUNDLE = "net.qays.TeachingTimer.WatchAudioProbe"
HOSTS = {"fixture": BUNDLE, "teaching": "com.qayshp.TeachingTimer", "system": "com.apple.NanoNowPlaying"}


def checked(*args, timeout=20):
    return subprocess.check_output(list(map(str, args)), text=True, stderr=subprocess.STDOUT, timeout=timeout).strip()


def new_output(value):
    path = value.absolute()
    if path != path.resolve() or not path.is_relative_to(ROOT / "work"):
        raise ValueError("Use a new, nonsymlink directory under this checkout's ignored work/")
    if path.exists():
        raise ValueError("Output already exists; preserve earlier evidence")
    path.mkdir(parents=True, mode=0o700)
    return path


def player_gate(samples, frequent=False):
    """Observable player/metadata prerequisite, deliberately no native pixel claim."""
    errors = []
    if len(samples) < 2:
        return ["Need at least two source samples"]
    if any(item.get("playing") is not True for item in samples):
        errors.append("Player not reported playing at every sample")
    positions = [item.get("playerCurrentTime") for item in samples]
    valid_positions = all(type(value) in (int, float) and math.isfinite(value) and value >= 0 for value in positions)
    if not valid_positions:
        errors.append("Missing or invalid actual player time")
    elif any(after <= before for before, after in zip(positions, positions[1:])):
        errors.append("Actual player time did not advance between every frame")
    if len({item.get("runID") for item in samples}) != 1 or not samples[0].get("runID"):
        errors.append("Samples do not identify one source process run")
    counts = [item.get("metadataPublishCount") for item in samples]
    if any(type(value) is not int or value < 1 for value in counts):
        errors.append("Missing or invalid metadata submission count")
    elif not frequent and len(set(counts)) != 1:
        errors.append("Sparse comparison received additional metadata submissions")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--host", choices=HOSTS, default="fixture")
    parser.add_argument("--seconds", type=int, default=30, choices=range(10, 121))
    parser.add_argument("--interval", type=int, default=10, choices=range(5, 31))
    parser.add_argument("--seek-seconds", type=float, default=30)
    parser.add_argument("--session-api", action="store_true")
    parser.add_argument("--frequent-metadata", action="store_true")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    if not 0 <= args.seek_seconds <= 45:
        parser.error("Initial seek must be 0...45, leaving finite playback headroom")
    os.umask(0o077)
    out = new_output(args.output)
    flags = ["--autoplay", "--now-playing", "--playback-limit-seconds", str(args.seconds + 15),
             "--seek-seconds", str(args.seek_seconds)]
    if args.session_api:
        flags.append("--session-api")
    if args.frequent_metadata:
        flags.append("--frequent-metadata")
    plan = {"executeRequested": args.execute, "simulator": args.simulator, "sourceBundle": BUNDLE,
            "hostBundle": HOSTS[args.host], "sourceFlags": flags, "seconds": args.seconds,
            "interval": args.interval, "createdUTC": datetime.now(timezone.utc).isoformat(),
            "nativeProgressResult": "unverified_visual_review_required", "frames": []}

    def save():
        (out / "observation.json").write_text(json.dumps(plan, indent=2) + "\n")

    save()
    if not args.execute:
        print(json.dumps({"status": "PLAN_ONLY_NO_DEVICE_COMMANDS", "output": str(out)}, indent=2))
        return 0
    source_started = False
    result = 2
    try:
        inventory = json.loads(checked("xcrun", "simctl", "list", "devices", "--json"))
        matches = [d for ds in inventory["devices"].values() for d in ds if d["udid"] == args.simulator]
        if (len(matches) != 1 or matches[0]["state"] != "Booted"
                or not matches[0]["name"].startswith("TeachingTimer Regression")
                or "Apple-Watch" not in matches[0].get("deviceTypeIdentifier", "")):
            raise ValueError("Expected one booted disposable Watch named TeachingTimer Regression...")
        app = Path(checked("xcrun", "simctl", "get_app_container", args.simulator, BUNDLE, "app"))
        binary = app / "WatchAudioProbe"
        plan["sourceExecutableSHA256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
        container = Path(checked("xcrun", "simctl", "get_app_container", args.simulator, BUNDLE, "data"))
        journal = container / "Documents/WatchAudioProbe.jsonl"
        if journal.exists():
            (out / "source-before.jsonl").write_bytes(journal.read_bytes())
        launch_at = time.time()
        # A timed-out launch may still start the app; always attempt cleanup afterward.
        source_started = True
        plan["sourceLaunch"] = checked("xcrun", "simctl", "launch", "--terminate-running-process", args.simulator, BUNDLE, *flags)
        current = []
        for _ in range(60):
            if journal.exists():
                current = [json.loads(line) for line in journal.read_text().splitlines() if line.strip()]
                ready = [r for r in current if r.get("timestampUnix", 0) >= launch_at and r.get("playing")]
                if ready:
                    break
            time.sleep(0.1)
        else:
            raise RuntimeError("Source did not establish a current-run playing sample")
        run_id = ready[-1]["runID"]
        plan["sourceRunID"] = run_id
        if args.host != "fixture":
            host_flags = ["--show-now-playing"] if args.host == "teaching" else []
            plan["hostLaunch"] = checked("xcrun", "simctl", "launch", "--terminate-running-process", args.simulator,
                                         HOSTS[args.host], *host_flags)
        time.sleep(2)
        start = time.monotonic()
        frame_times = sorted(set([0, *range(args.interval, args.seconds, args.interval), args.seconds]))
        for number, offset in enumerate(frame_times):
            while time.monotonic() - start < offset:
                time.sleep(max(0, min(0.2, offset - (time.monotonic() - start))))
            name = f"frame-{number:02}-{offset:03}s.png"
            before = time.time()
            checked("xcrun", "simctl", "io", args.simulator, "screenshot", out / name)
            current = [json.loads(line) for line in journal.read_text().splitlines() if line.strip()]
            sample = [r for r in current if r.get("runID") == run_id][-1]
            plan["frames"].append({"image": name, "requestedOffsetSeconds": offset,
                                   "captureBeforeUnix": before, "captureAfterUnix": time.time(),
                                   "sourceSampleAgeSeconds": time.time() - sample["timestampUnix"],
                                   "source": sample})
            save()
        (out / "source-after.jsonl").write_bytes(journal.read_bytes())
        samples = [frame["source"] for frame in plan["frames"]]
        errors = player_gate(samples, args.frequent_metadata)
        if any(frame["sourceSampleAgeSeconds"] > 3 for frame in plan["frames"]):
            errors.append("At least one player sample is over three seconds old")
        plan["playerGateErrors"] = errors
        plan["playerGatePassed"] = not errors
        result = 0 if not errors else 2
    except (ValueError, OSError, RuntimeError, subprocess.SubprocessError) as error:
        plan["error"] = str(error)
    finally:
        if source_started:
            try:
                checked("xcrun", "simctl", "terminate", args.simulator, BUNDLE)
                plan["sourceStopped"] = True
            except (OSError, subprocess.SubprocessError) as error:
                plan["sourceStopped"] = False
                plan["cleanupError"] = str(error)
                result = 2
        save()
    print(json.dumps({"output": str(out), "playerGatePassed": plan.get("playerGatePassed", False),
                      "nativeProgressResult": plan["nativeProgressResult"], "error": plan.get("error")}, indent=2))
    return result


if __name__ == "__main__":
    raise SystemExit(main())
