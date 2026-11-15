#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Explicit isolated Crown binding calibration; no GUI or physical-device API.

Without --execute, validate local artifacts and write a private plan only.
Runtime mode owns its own bounded log capture and twelve fresh fixture launches.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import plistlib
import re
import signal
import subprocess
import sys
import time


def sibling(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


native = sibling("native_state_guards", "native-state.py")
analysis = sibling("calibration_analysis", "analyze-calibration.py")
BUNDLE = "net.qays.TeachingTimer.CrownProbe"
EXECUTABLE = "CrownEventProbe"
ORIGINAL = (1, -1, -1, 1, .25, -.25)
TRIAL_DELTAS = ORIGINAL + tuple(reversed(ORIGINAL))


def now():
    return datetime.now(timezone.utc).isoformat()


def validate_probe(path):
    path = path.resolve()
    with (path / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    if (path.suffix != ".app" or info.get("CFBundleIdentifier") != BUNDLE or
            info.get("CFBundleExecutable") != EXECUTABLE):
        raise ValueError("Only the public CrownProbe fixture is accepted; TeachingTimer is forbidden")
    native.watch_simulator_macho(path / EXECUTABLE)
    return path


def verify_binding_trials(trials):
    """Check sign repeatability, not exact velocity-dependent displacement."""
    if len(trials) != 12 or tuple(t["delta"] for t in trials) != TRIAL_DELTAS:
        raise ValueError("Expected the original six turns followed by reverse order")
    responsive_signs = {1: set(), -1: set()}
    orientations = []
    for trial in trials:
        if not math.isclose(trial["initialValue"], .5, rel_tol=0, abs_tol=1e-9) or trial["resetEvents"]:
            raise ValueError("Every trial requires a fresh 0.5 binding and no reset")
        if trial["profile"] not in ("upstream", "zero-began"):
            raise ValueError("Unrecognized Crown profile")
        if abs(trial["delta"]) == 1:
            change = trial["finalValue"] - trial["initialValue"]
            if not math.isfinite(change) or change == 0 or not trial["valueChanges"]:
                raise ValueError("A +/-1 reference turn did not move the public binding")
            responsive_signs[int(trial["delta"])].add(1 if change > 0 else -1)
        orientations.append(trial["orientation"])
    if any(len(signs) != 1 for signs in responsive_signs.values()) or responsive_signs[1] == responsive_signs[-1]:
        raise ValueError("Responsive +/-1 turns do not have repeatable opposite binding signs")
    if any(t["profile"] != trials[0]["profile"] for t in trials) or any(value != orientations[0] for value in orientations):
        raise ValueError("Profile or orientation changed between trials")
    if len({t["runID"] for t in trials}) != len(trials):
        raise ValueError("Each trial must have a distinct process journal run ID")
    return {"responsiveReferenceSigns": {str(key): sorted(value) for key, value in responsive_signs.items()},
            "fractionalNonresponses": [t["trial"] for t in trials if abs(t["delta"]) < 1 and
                                      t["finalValue"] == t["initialValue"]],
            "note": "Fractional nonresponse is retained as an observation, not an automatic failure"}


class CalibrationRun:
    def __init__(self, output, identifier, probe, bridge, profile, execute):
        self.output, self.identifier, self.probe, self.bridge = output, identifier, probe, bridge
        self.profile = profile
        self.manifest = {"schemaVersion": 1, "startedUTC": now(), "simulator": identifier,
                         "fixtureBundle": BUNDLE, "profile": profile, "executeRequested": execute,
                         "status": "prepared", "trialDeltas": TRIAL_DELTAS, "commands": [],
                         "artifacts": {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                                       for path in (probe / EXECUTABLE, bridge)}}
        self.save()

    def save(self):
        native.save(self.output / "run.json", self.manifest)

    def command(self, stage, argv, allow_failure=False):
        record = {"stage": stage, "argv": argv, "startedUTC": now(),
                  "hostMonotonicNanoseconds": time.monotonic_ns()}
        self.manifest["commands"].append(record)
        self.save()
        try:
            result = subprocess.run(argv, capture_output=True, text=True, timeout=25, check=False,
                                    env=native.clean_environment())
            record.update(returnCode=result.returncode, stdout=result.stdout, stderr=result.stderr)
        except (OSError, subprocess.TimeoutExpired) as error:
            record.update(returnCode=None, error=str(error))
            self.save()
            raise RuntimeError(stage + " failed or timed out; outcome is saved")
        record["endedUTC"] = now()
        self.save()
        if result.returncode and not allow_failure:
            raise RuntimeError(stage + " failed: " + result.stderr.strip())
        return result

    def sim(self, stage, *arguments, **kwargs):
        return self.command(stage, ["xcrun", "simctl", *arguments], **kwargs)


def read_journal(path):
    if path.stat().st_size > native.MAX_JOURNAL_BYTES:
        raise ValueError("Public fixture journal exceeds size bound")
    rows = json.loads(path.read_bytes())
    if not isinstance(rows, list) or not rows:
        raise ValueError("Public fixture journal is empty or malformed")
    return rows


def wait_fresh_journal(path, old_id, started):
    deadline = time.monotonic() + 8
    while True:
        try:
            rows = read_journal(path)
            if (rows[0]["runID"] != old_id and rows[0]["wallTimeSeconds"] >= started - .1 and
                    any(r["event"] == "focus_state_changed" and r["fields"].get("new") == "true" for r in rows)):
                return rows
        except (OSError, ValueError, KeyError):
            pass
        if time.monotonic() >= deadline:
            raise ValueError("Fresh public fixture journal/focus was not observed")
        time.sleep(.1)


def execute(run):
    inventory = json.loads(run.sim("inventory", "list", "devices", "--json").stdout)
    run.manifest["selectedTarget"] = native.booted_watch(inventory, run.identifier)
    run.save()
    capture, stdout, stderr, mutated = None, None, None, False
    trials, old_id = [], None
    try:
        # A local, wire-only self-test must confirm the expected lab helper.
        checked = run.command("host-wire-self-test", [str(run.bridge), "--profile", run.profile, "--self-test"])
        receipt = json.loads(checked.stdout)
        if receipt.get("CoreSimulatorLoaded") is not False or receipt.get("eventsSent") != 0:
            raise ValueError("Host helper self-test did not confirm zero Simulator events")
        mutated = True
        run.sim("stop-prior-public-fixture", "terminate", run.identifier, BUNDLE, allow_failure=True)
        run.sim("install-public-fixture", "install", run.identifier, str(run.probe))
        container = Path(run.sim("public-fixture-container", "get_app_container", run.identifier, BUNDLE, "data").stdout.strip()).resolve()
        device_root = (Path.home() / "Library/Developer/CoreSimulator/Devices" / run.identifier).resolve()
        if device_root not in container.parents:
            raise ValueError("Public fixture container is outside this explicit default-set simulator")
        journal = container / "Documents/CrownProbe.json"
        if journal.is_symlink() or container not in journal.resolve().parents:
            raise ValueError("Public fixture journal escapes its container")
        if journal.exists():
            previous = read_journal(journal)
            old_id = previous[0]["runID"]
            native.save(run.output / "prior-CrownProbe.json", previous)
        stdout = (run.output / "live-apps.ndjson").open("xb")
        stderr = (run.output / "live-apps.stderr").open("xb")
        capture_argv = ["xcrun", "simctl", "spawn", run.identifier, "log", "stream", "--timeout", "120",
                        "--level", "debug", "--style", "ndjson", "--predicate", 'process == "CrownEventProbe"']
        run.manifest["capture"] = {"argv": capture_argv, "startedUTC": now(), "guestTimeoutSeconds": 120}
        run.save()
        capture = subprocess.Popen(capture_argv, stdout=stdout, stderr=stderr,
                                   env=native.clean_environment(), start_new_session=True)
        time.sleep(.3)
        deadline = time.monotonic() + 110
        for number, delta in enumerate(TRIAL_DELTAS, 1):
            if time.monotonic() >= deadline or capture.poll() is not None:
                raise ValueError("Bounded capture ended or calibration exceeded its 110s input budget")
            trial = {"trial": number, "delta": delta, "profile": run.profile,
                     "block": "original" if number <= len(ORIGINAL) else "reverse-order", "startedUTC": now()}
            launched_at = time.time()
            launch = run.sim("launch-public-%02d" % number, "launch", "--terminate-running-process",
                             run.identifier, BUNDLE).stdout.strip()
            if not re.search(r":\s*\d+\s*$", launch):
                raise ValueError("Public fixture launch has no confirmed PID")
            trial["launch"] = launch
            before = wait_fresh_journal(journal, old_id, launched_at)
            if any(row["event"] == "value_changed" for row in before):
                raise ValueError("Public binding changed before the deliberate input")
            native.save(run.output / ("calibration-%02d-before.json" % number), before)
            trial["beforeInputUTC"] = now()
            bridged = run.command("crown-turn-%02d" % number,
                                  [str(run.bridge), "--profile", run.profile, "--send", run.identifier, str(delta)])
            trial["bridge"] = bridged.stdout + bridged.stderr
            trial["afterInputUTC"] = now()
            time.sleep(2)
            after = read_journal(journal)
            if any(row.get("runID") != before[0]["runID"] for row in after):
                raise ValueError("Public journal run ID changed across the input window")
            native.save(run.output / ("calibration-%02d-after.json" % number), after)
            changes = [r for r in after if r["event"] == "value_changed"]
            value = float(before[0]["fields"]["value"])
            trial.update(settledUTC=now(), runID=after[0]["runID"], initialValue=value,
                         finalValue=float(changes[-1]["fields"]["newValue"]) if changes else value,
                         valueChanges=len(changes), observedDeltas=[float(r["fields"]["delta"]) for r in changes],
                         resetEvents=sum(r["event"] == "reset_requested" for r in after),
                         orientation=after[0]["fields"])
            old_id = trial["runID"]
            trials.append(trial)
            native.save(run.output / "calibration-trials.json", trials)
            time.sleep(1)
        run.manifest["bindingOracle"] = verify_binding_trials(trials)
        run.manifest["status"] = "binding_trials_complete"
    except BaseException as error:
        run.manifest.update(status="failed_or_unsupported", error=str(error))
        raise
    finally:
        if capture is not None:
            try:
                if capture.poll() is None:
                    try:
                        os.killpg(capture.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    try:
                        capture.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(capture.pid, signal.SIGKILL)
                        capture.wait(timeout=5)
                run.manifest["capture"]["hostReturnCode"] = capture.returncode
            except (OSError, subprocess.SubprocessError) as error:
                run.manifest.update(status="cleanup_unconfirmed", captureCleanupError=str(error))
        for handle in (stdout, stderr):
            if handle is not None:
                handle.close()
        if mutated:
            try:
                stopped = run.sim("stop-public-fixture", "terminate", run.identifier, BUNDLE, allow_failure=True)
                run.manifest["fixtureTerminationAcknowledged"] = stopped.returncode == 0
                if stopped.returncode:
                    run.manifest["status"] = "cleanup_unconfirmed"
            except Exception as error:
                run.manifest.update(status="cleanup_unconfirmed", cleanupError=str(error))
        run.manifest["endedUTC"] = now()
        run.save()
    if run.manifest["status"] == "binding_trials_complete":
        result = analysis.analyze(run.output, trials, (run.output / "calibration-trials.json").read_bytes())
        native.save(run.output / "calibration-results.json", result)
        (run.output / "calibration-findings.md").write_text(analysis.findings(result))
        run.manifest["status"] = "calibration_passed" if result["responsiveSampleMappingObserved"] else "uikit_correlation_failed"
        run.save()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", required=True, type=native.canonical_uuid)
    parser.add_argument("--probe", required=True, type=Path, help="Ordinary CrownEventProbe.app")
    parser.add_argument("--bridge", required=True, type=Path, help="Built lab CrownHIDBridge executable")
    parser.add_argument("--profile", choices=("upstream", "zero-began"), default="upstream")
    parser.add_argument("--output", required=True, type=Path, help="NEW ignored private work/ directory")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args(argv)
    os.umask(0o077)
    run = None
    try:
        probe = validate_probe(args.probe)
        bridge = args.bridge.resolve()
        if bridge.name != "CrownHIDBridge" or not bridge.is_file() or not os.access(bridge, os.X_OK):
            raise ValueError("Expected the built executable lab CrownHIDBridge")
        repo = Path(__file__).resolve().parents[2]
        output = args.output.expanduser().resolve()
        if (repo / "work").resolve() not in output.parents:
            raise ValueError("Output must be a NEW child of the repository's ignored work/")
        ignored = subprocess.run(["git", "check-ignore", "--quiet", "--", str(output.relative_to(repo))],
                                 cwd=repo, capture_output=True, timeout=5, check=False)
        if ignored.returncode:
            raise ValueError("Cannot confirm output is Git-ignored")
        output.mkdir(parents=True, exist_ok=False, mode=0o700)
        run = CalibrationRun(output, args.simulator, probe, bridge, args.profile, args.execute)
        if args.execute:
            execute(run)
        print(json.dumps({"output": str(output), "status": run.manifest["status"]}))
        return 0 if run.manifest["status"] in ("prepared", "calibration_passed") else 2
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        if run is not None:
            if run.manifest["status"] != "cleanup_unconfirmed":
                run.manifest["status"] = "failed_or_unsupported"
            run.manifest["error"] = str(error)
            run.save()
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
