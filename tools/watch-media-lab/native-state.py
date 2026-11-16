#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Plan or explicitly execute eight fake-backend state arms in our Watch fixture.

No physical-device API, boot, pairing, TeachingTimer launch, playback or Crown
input. Without --execute, only local artifact checks and private plan writes run.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import plistlib
import re
import struct
import subprocess
import sys
import time
import uuid

BUNDLE = "net.qays.TeachingTimer.VolumeProbe"
EXECUTABLE = "NativeVolumeProbe"
MAX_JOURNAL_BYTES = 16 * 1024 * 1024
BAD_EVENTS = {"hook_exception", "unsupported_completion", "abi_validation_failed",
              "controller_setter_ABI_rejected", "command_rejected", "native_outgoing_setVolume"}
# Each expected tuple is (controller getter, inner slider, sequencer offset).
ARMS = (
    {"label": "seed_interior", "volume": .25, "notify": True, "available": True, "expected": (.25, .25, .25)},
    {"label": "silent_model_interior", "volume": .625, "notify": False, "available": True, "expected": (.625, .25, .25)},
    {"label": "repair_interior", "volume": .625, "notify": True, "available": True, "expected": (.625, .625, .625)},
    {"label": "seed_zero_enabled", "volume": 0, "notify": True, "available": True, "expected": (0, 0, 0)},
    {"label": "silent_model_zero", "volume": .625, "notify": False, "available": True, "expected": (.625, 0, 0)},
    {"label": "repair_zero", "volume": .625, "notify": True, "available": True, "expected": (.625, .625, .625)},
    {"label": "unavailable_zero", "volume": 0, "notify": True, "available": False, "expected": (0, 0, 0)},
    {"label": "ready_after_unavailable", "volume": .625, "notify": True, "available": True, "expected": (.625, .625, .625)},
)


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def save(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def canonical_uuid(value):
    try:
        parsed = uuid.UUID(value)
    except (ValueError, AttributeError):
        raise ValueError("Use an explicit canonical Watch Simulator UUID, never booted")
    if str(parsed).upper() != value.upper():
        raise ValueError("Use a canonical hyphenated UUID")
    return str(parsed).upper()


def watch_simulator_macho(path):
    """Read LC_BUILD_VERSION directly; reject physical, non-Watch and fat files."""
    with path.open("rb") as source:
        header = source.read(32)
        if len(header) != 32 or struct.unpack_from("<I", header)[0] != 0xFEEDFACF:
            raise ValueError("Expected a thin 64-bit Mach-O; rebuild with this Mac's SDK: " + str(path))
        count, size = struct.unpack_from("<II", header, 16)
        if count > 4096 or size > 4 * 1024 * 1024:
            raise ValueError("Unbounded Mach-O load commands")
        commands = source.read(size)
    if len(commands) != size:
        raise ValueError("Truncated Mach-O load commands")
    platforms, offset = [], 0
    for _ in range(count):
        if offset + 8 > size:
            raise ValueError("Truncated Mach-O command")
        command, length = struct.unpack_from("<II", commands, offset)
        if length < 8 or offset + length > size:
            raise ValueError("Invalid Mach-O command length")
        if command == 0x32:
            if length < 24:
                raise ValueError("Truncated build-version command")
            platforms.append(struct.unpack_from("<I", commands, offset + 8)[0])
        offset += length
    if offset != size or platforms != [9]:  # PLATFORM_WATCHOSSIMULATOR
        raise ValueError("Artifact is not exclusively watchOS Simulator: " + str(path))


def validate_artifacts(probe, hook):
    probe, hook = probe.resolve(), hook.resolve()
    with (probe / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    if (probe.suffix != ".app" or info.get("CFBundleIdentifier") != BUNDLE or
            info.get("CFBundleExecutable") != EXECUTABLE):
        raise ValueError("Only the native VolumeProbe fixture is accepted; TeachingTimer is forbidden")
    watch_simulator_macho(probe / EXECUTABLE)
    watch_simulator_macho(hook)
    return probe, hook


def booted_watch(inventory, identifier):
    matches = [(runtime, device) for runtime, devices in inventory.get("devices", {}).items()
               for device in devices if device.get("udid", "").upper() == identifier]
    if len(matches) != 1:
        raise ValueError("Explicit simulator UUID is missing or ambiguous")
    runtime, device = matches[0]
    if (device.get("state") != "Booted" or device.get("isAvailable") is not True or
            "watchOS" not in runtime or
            not device.get("deviceTypeIdentifier", "").startswith("com.apple.CoreSimulator.SimDeviceType.Apple-Watch")):
        raise ValueError("Explicit target must be an available Booted Apple Watch Simulator")
    return {"runtime": runtime, **device}


def native_snapshot(rows, revision):
    snapshots = [row for row in rows if row.get("revision") == revision and
                 row.get("event") == "native_state_changed"]
    if not snapshots or len(snapshots[-1].get("nativeViews", [])) != 1:
        raise ValueError("Exactly one measured native view is required")
    snapshot = snapshots[-1]["nativeViews"][0]
    for name in ("nativeModel", "viewValue", "sequencerOffset"):
        value = snapshot.get(name)
        if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value):
            raise ValueError("Native scalar is missing/nonfinite: " + name)
    if not snapshot.get("view") or not snapshot.get("controller"):
        raise ValueError("Native view/controller identity is missing")
    return snapshot


def evaluate_arm(rows, revision, arm, identity=None):
    bad = [row for row in rows if row.get("event") in BAD_EVENTS]
    if bad:
        raise ValueError("Unsupported fixture/error/outgoing setter: " + bad[0]["event"])
    applied = [row for row in rows if row.get("revision") == revision and row.get("event") == "command_applied"]
    if len(applied) != 1 or applied[0].get("label") != arm["label"]:
        raise ValueError("Command application is missing or ambiguous")
    if applied[0].get("feedback") is not False or applied[0].get("available") is not arm["available"]:
        raise ValueError("Applied backend settings differ from the arm")
    backend = applied[0].get("modelVolume")
    if (applied[0].get("notify") is not arm["notify"] or isinstance(backend, bool) or
            not isinstance(backend, (float, int)) or not math.isfinite(backend) or
            not math.isclose(backend, arm["volume"], rel_tol=0, abs_tol=1e-5)):
        raise ValueError("Applied backend value/notification differs from the arm")
    snapshot = native_snapshot(rows, revision)
    measured = tuple(snapshot[name] for name in ("nativeModel", "viewValue", "sequencerOffset"))
    if not all(math.isclose(actual, expected, rel_tol=0, abs_tol=1e-5)
               for actual, expected in zip(measured, arm["expected"])):
        raise ValueError("Measured getter/view/sequencer tuple differs: " + repr(measured))
    current_identity = (snapshot["view"], snapshot["controller"])
    if identity is not None and current_identity != identity:
        raise ValueError("Native view/controller changed between arms")
    return {"revision": revision, "label": arm["label"], "expected": arm["expected"],
            "measuredGetterViewSequencer": measured, "identity": current_identity, "snapshot": snapshot}


def clean_environment():
    return {key: value for key, value in os.environ.items()
            if not key.startswith("SIMCTL_CHILD_") and key != "DYLD_INSERT_LIBRARIES"}


class Run:
    def __init__(self, output, identifier, probe, hook, execute):
        self.output = output
        self.identifier, self.probe, self.hook = identifier, probe, hook
        self.manifest = {"schemaVersion": 1, "startedUTC": utc_now(), "simulator": identifier,
                         "fixtureBundle": BUNDLE, "executeRequested": execute, "status": "prepared",
                         "arms": list(ARMS), "commands": [], "results": [],
                         "artifacts": {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                                       for path in (probe / EXECUTABLE, hook)}}
        self.save()

    def save(self):
        save(self.output / "run.json", self.manifest)

    def command(self, stage, arguments, env=None, allow_failure=False):
        argv = ["xcrun", "simctl", *arguments]
        record = {"stage": stage, "argv": argv, "startedUTC": utc_now()}
        self.manifest["commands"].append(record)
        self.save()
        try:
            result = subprocess.run(argv, capture_output=True, text=True, timeout=25,
                                    check=False, env=env if env is not None else clean_environment())
            record.update(returnCode=result.returncode, stdout=result.stdout, stderr=result.stderr)
        except (OSError, subprocess.TimeoutExpired) as error:
            record.update(returnCode=None, error=str(error))
            self.save()
            raise RuntimeError(stage + " failed or timed out; inspect saved outcome")
        record["endedUTC"] = utc_now()
        self.save()
        if result.returncode and not allow_failure:
            raise RuntimeError(stage + " failed: " + result.stderr.strip())
        return result


def journal_rows(path, offset):
    if not path.exists():
        return []
    if path.stat().st_size > MAX_JOURNAL_BYTES:
        raise ValueError("Fixture journal exceeds bounded size")
    data = path.read_bytes()[offset:]
    # A concurrent append may expose its incomplete last row. Wait for newline.
    complete = data[:data.rfind(b"\n") + 1]
    return [json.loads(line) for line in complete.splitlines() if line.strip()]


def poll_journal(path, offset, predicate, timeout=8):
    deadline = time.monotonic() + timeout
    while True:
        rows = journal_rows(path, offset)
        bad = next((row["event"] for row in rows if row.get("event") in BAD_EVENTS), None)
        if bad:
            raise ValueError("Fixture is unsupported or produced an outgoing setter: " + bad)
        if predicate(rows):
            return rows
        if time.monotonic() >= deadline:
            raise ValueError("Required measured fixture state was not observed before timeout")
        time.sleep(.1)


def finish_fixture(run, documents, journal, offset, identity):
    """Terminate, preserve/audit the old container, THEN reinstall the fixture.

    Reinstallation may relocate the data container. Never read its old path
    after restoring the artifact, and always attempt restoration after audit.
    """
    cleanup = []
    try:
        result = run.command("terminate-injected-fixture", ["terminate", run.identifier, BUNDLE], allow_failure=True)
        cleanup.append({"stage": "terminate-injected-fixture", "acknowledged": result.returncode == 0})
    except Exception as error:
        cleanup.append({"stage": "terminate-injected-fixture", "acknowledged": False, "error": str(error)})
    if documents is not None:
        try:
            for name in ("NativeBaselineJournal.jsonl", "VolumeProbe.json", "NativeBaselineCommand.json"):
                path = documents / name
                if path.is_file() and not path.is_symlink() and path.stat().st_size <= MAX_JOURNAL_BYTES:
                    (run.output / name).write_bytes(path.read_bytes())
            if journal is not None:
                if not journal.is_file():
                    raise ValueError("Final fixture journal unavailable after termination; pre-cleanup observations preserved")
                final_rows = journal_rows(journal, offset)
                save(run.output / "current-process-journal.json", final_rows)
                if len(run.manifest["results"]) == len(ARMS):
                    for revision, arm in enumerate(ARMS, 1):
                        evaluate_arm(final_rows, revision, arm, identity)
        except (OSError, ValueError) as error:
            run.manifest.update(status="final_evidence_failed", finalEvidenceError=str(error))
    try:
        result = run.command("restore-ordinary-fixture", ["install", run.identifier, str(run.probe)], allow_failure=True)
        cleanup.append({"stage": "restore-ordinary-fixture", "acknowledged": result.returncode == 0})
    except Exception as error:
        cleanup.append({"stage": "restore-ordinary-fixture", "acknowledged": False, "error": str(error)})
    return cleanup


def execute(run):
    identifier = run.identifier
    inventory = json.loads(run.command("inventory", ["list", "devices", "--json"]).stdout)
    run.manifest["selectedTarget"] = booted_watch(inventory, identifier)
    run.save()
    documents, journal, offset, mutated, identity = None, None, 0, False, None
    try:
        mutated = True
        # The only install/launch target is the validated, isolated VolumeProbe.
        run.command("stop-prior-fixture", ["terminate", identifier, BUNDLE], allow_failure=True)
        run.command("install-ordinary-fixture", ["install", identifier, str(run.probe)])
        container = Path(run.command("fixture-container", ["get_app_container", identifier, BUNDLE, "data"]).stdout.strip()).resolve()
        device_root = (Path.home() / "Library/Developer/CoreSimulator/Devices" / identifier).resolve()
        if device_root not in container.parents:
            raise ValueError("Fixture container is outside this explicit default-set simulator")
        documents = (container / "Documents").resolve()
        if container not in documents.parents:
            raise ValueError("Fixture Documents escapes its container")
        documents.mkdir(exist_ok=True)
        for name in ("NativeBaselineCommand.json", "NativeBaselineJournal.jsonl", "VolumeProbe.json"):
            path = documents / name
            if path.is_symlink():
                raise ValueError("Fixture evidence file must not be a symlink")
            if path.exists():
                if path.stat().st_size > MAX_JOURNAL_BYTES:
                    raise ValueError("Prior fixture evidence exceeds size bound")
                (run.output / ("prior-" + name)).write_bytes(path.read_bytes())
        command_path = documents / "NativeBaselineCommand.json"
        if command_path.exists():
            command_path.unlink()  # Its exact prior bytes were saved above.
        journal = documents / "NativeBaselineJournal.jsonl"
        offset = journal.stat().st_size if journal.exists() else 0
        env = clean_environment()
        env.update(SIMCTL_CHILD_DYLD_INSERT_LIBRARIES=str(run.hook), SIMCTL_CHILD_TT_NATIVE_BASELINE_HOOK="1")
        run.command("launch-injected-fixture", ["launch", "--terminate-running-process", identifier,
                                                BUNDLE, "--staged", "--single-page"], env=env)
        poll_journal(journal, offset, lambda rows: any(r.get("event") == "fake_data_source_installed" for r in rows)
                     and any(r.get("event") == "native_state_changed" and len(r.get("nativeViews", [])) == 1 for r in rows))
        for revision, arm in enumerate(ARMS, 1):
            command = {key: arm[key] for key in ("label", "volume", "notify", "available")}
            command.update(revision=revision, feedback=False, muted=False)
            save(command_path, command)
            poll_journal(journal, offset, lambda rows: any(r.get("revision") == revision and
                         r.get("event") == "native_state_changed" for r in rows))
            time.sleep(.3)
            observed_rows = journal_rows(journal, offset)
            result = evaluate_arm(observed_rows, revision, arm, identity)
            save(run.output / "observed-current-process-journal.json", observed_rows)
            identity = result["identity"]
            run.manifest["results"].append(result)
            run.save()
        run.manifest["status"] = "eight_measured_state_arms_passed"
    except BaseException as error:
        run.manifest.update(status="failed_or_unsupported", error=str(error))
        raise
    finally:
        cleanup = []
        if mutated:
            cleanup = finish_fixture(run, documents, journal, offset, identity)
        run.manifest.update(cleanup=cleanup, endedUTC=utc_now())
        if cleanup and not all(item["acknowledged"] for item in cleanup):
            run.manifest["status"] = "cleanup_unconfirmed"
        run.save()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", required=True, type=canonical_uuid)
    parser.add_argument("--probe", required=True, type=Path, help="Ordinary NativeVolumeProbe.app")
    parser.add_argument("--hook", required=True, type=Path, help="Simulator-only NativeBaselineHook.dylib")
    parser.add_argument("--output", required=True, type=Path, help="NEW ignored private work/ directory")
    parser.add_argument("--execute", action="store_true", help="Explicitly install/launch only our fixture and run eight arms")
    args = parser.parse_args(argv)
    os.umask(0o077)
    try:
        probe, hook = validate_artifacts(args.probe, args.hook)
        output = args.output.expanduser().resolve()
        repo = Path(__file__).resolve().parents[2]
        work = (repo / "work").resolve()
        if work not in output.parents:
            raise ValueError("Output must be a NEW child of the repository's ignored work/")
        ignored = subprocess.run(["git", "check-ignore", "--quiet", "--", str(output.relative_to(repo))],
                                 cwd=repo, capture_output=True, timeout=5, check=False)
        if ignored.returncode:
            raise ValueError("Cannot confirm output is Git-ignored")
        output.mkdir(parents=True, exist_ok=False, mode=0o700)
        run = Run(output, args.simulator, probe, hook, args.execute)
        if args.execute:
            execute(run)
        print(json.dumps({"output": str(output), "status": run.manifest["status"],
                          "simulatorCommands": len(run.manifest["commands"])}))
        return 0 if run.manifest["status"] in ("prepared", "eight_measured_state_arms_passed") else 2
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
