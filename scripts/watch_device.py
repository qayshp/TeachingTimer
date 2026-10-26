#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Bounded, explicit Watch journal-copy or installation operations. No auto-repair."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import time

JOURNALS = ("RuntimeDiagnostics.json", "InterfaceDiagnostics.json", "LandmarkDiagnostics.json")


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def save_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    temporary.replace(path)


class Session:
    def __init__(self, output, device, budget=300, timeout=30):
        # Never overwrite evidence or mix captures from different attempts/devices.
        self.output = Path(output).resolve()
        self.output.mkdir(parents=True, exist_ok=False, mode=0o700)
        self.deadline = time.monotonic() + budget
        self.timeout = timeout
        self.device = device
        self.manifest = {"schemaVersion": 1, "startedAt": utc_now(), "device": device,
                         "budgetSeconds": budget, "steps": [], "status": "in_progress"}
        self.save()

    def save(self):
        save_json(self.output / "operation.json", self.manifest)

    def command(self, stage, arguments, device=True, limit=None):
        remaining = self.deadline - time.monotonic()
        step = {"stage": stage, "startedAt": utc_now(), "status": "not_started"}
        self.manifest["steps"].append(step)
        stem = f"{len(self.manifest['steps']):02d}-{stage}"
        result_path = self.output / (stem + ".json")
        console_path = self.output / (stem + ".txt")
        if remaining <= 4:
            step["status"] = "budget_exhausted"
            self.save()
            return {"ok": False, "data": {}, "status": step["status"]}
        timeout = min(self.timeout, limit or self.timeout, int(remaining - 3))
        command = ["xcrun", "devicectl", *arguments]
        if device:
            command += ["--device", self.device]
        command += ["--timeout", str(timeout), "--json-output", str(result_path)]
        step.update(command=command, status="running", timeoutSeconds=timeout,
                    console=console_path.name, result=result_path.name)
        self.save()
        start = time.monotonic()
        print(f"{stage} (at most {timeout}s)…", flush=True)
        with console_path.open("w") as console:
            try:
                process = subprocess.run(command, stdout=console, stderr=subprocess.STDOUT,
                                         timeout=timeout + 3, check=False)
                step["returnCode"] = process.returncode
                step["status"] = "returned"
            except subprocess.TimeoutExpired:
                # The command was stopped; an on-device action may still finish.
                step["status"] = "client_timeout_outcome_unknown"
            except OSError as error:
                step["status"] = "tool_unavailable"
                step["error"] = str(error)
        data = {}
        try:
            data = json.loads(result_path.read_text())
            if not isinstance(data, dict) or not isinstance(data.get("info"), dict) or not isinstance(data.get("result", {}), dict):
                raise ValueError("Invalid devicectl result envelope")
        except (OSError, ValueError) as error:
            step["resultReadError"] = str(error)
            data = {}
        ok = (step.get("returnCode") == 0 and data.get("info", {}).get("outcome") == "success")
        if step["status"] == "returned":
            step["status"] = "success" if ok else "failed_or_unconfirmed"
        step.update(endedAt=utc_now(), elapsedSeconds=round(time.monotonic() - start, 3))
        self.save()
        return {"ok": ok, "data": data, "status": step["status"]}

    def finish(self, status, message):
        self.manifest.update(status=status, endedAt=utc_now())
        self.save()
        print(message, flush=True)
        print("Device operations are finished; you can let the Watch sleep. "
              "Any further analysis uses saved files.", flush=True)
        print(f"Private evidence: {self.output}", flush=True)


def preflight(session):
    # Discovery/details may be cached. A successful query is not proof of a
    # working transfer/install service; failed discovery must not block a copy.
    session.command("discovery", ["list", "devices"], device=False, limit=10)
    session.command("details", ["device", "info", "details"], limit=15)


def validate_journal(path):
    data = json.loads(path.read_text())
    if not isinstance(data, list):
        raise ValueError("Journal is not an event array")
    for row in data:
        if not isinstance(row, dict) or not isinstance(row.get("event"), str):
            raise ValueError("Invalid event")
        timestamp = datetime.fromisoformat(str(row.get("timestamp", "")).replace("Z", "+00:00"))
        if timestamp.tzinfo is None:
            raise ValueError("Timestamp has no offset")
        if not isinstance(row.get("details"), dict):
            raise ValueError("Invalid event details")
    return len(data)


def collect_journals(session, bundle, attempts):
    preflight(session)
    results = {}
    # Complete the small operational files before any optional system capture.
    # This tool intentionally never starts a sysdiagnose or launches the app.
    for name in JOURNALS:
        results[name] = {"status": "unavailable_or_unconfirmed"}
        for attempt in range(1, attempts + 1):
            folder = session.output / f"copy-{name.removesuffix('.json')}-{attempt}"
            folder.mkdir()
            destination = folder / name
            result = session.command(f"copy-{name.removesuffix('.json')}-{attempt}", [
                "device", "copy", "from", "--source", "Documents/" + name,
                "--destination", str(destination), "--domain-type", "appDataContainer",
                "--domain-identifier", bundle])
            if result["ok"]:
                try:
                    count = validate_journal(destination)
                    shutil.copy2(destination, session.output / name)
                    results[name] = {"status": "copied_and_validated", "events": count,
                                     "bytes": destination.stat().st_size, "attempt": attempt}
                    break
                except (OSError, ValueError, TypeError) as error:
                    results[name] = {"status": "invalid_copy", "error": str(error)}
            if time.monotonic() >= session.deadline:
                break
        session.manifest["journals"] = results
        session.save()
    complete = all(value["status"] == "copied_and_validated" for value in results.values())
    session.finish("complete" if complete else "partial_or_failed",
                   "All three journals are saved and validated." if complete else
                   "Collection is incomplete; successful files and failed attempts are preserved. "
                   "A missing file is not automatically a connection failure or proof of no events.")
    return 0 if complete else 2


def app_metadata(path, bundle):
    path = Path(path).resolve()
    with (path / "Info.plist").open("rb") as file:
        info = plistlib.load(file)
    if path.suffix != ".app" or info.get("CFBundleIdentifier") != bundle:
        raise ValueError("App bundle identifier does not match --bundle")
    if "WatchOS" not in info.get("CFBundleSupportedPlatforms", []):
        raise ValueError("Expected a physical watchOS app, not a Simulator app")
    version = str(info.get("CFBundleVersion", ""))
    if not version:
        raise ValueError("App has no build number")
    executable = info.get("CFBundleExecutable", "")
    if not executable or Path(executable).name != executable or not (path / executable).is_file():
        raise ValueError("Missing or invalid app executable")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(path)],
                   check=True, capture_output=True, timeout=30)
    return path, {"bundleIdentifier": bundle, "bundleVersion": version,
                  "version": str(info.get("CFBundleShortVersionString", ""))}


def installed_match(result, expected):
    if not result["ok"]:
        return False
    apps = result["data"].get("result", {}).get("apps", [])
    return isinstance(apps, list) and any(isinstance(app, dict) and
        all(str(app.get(key, "")) == value for key, value in expected.items()) for app in apps)


def install(session, app, expected, attempts, launch):
    session.manifest.update(app=str(app), expectedApp=expected, launchRequested=launch)
    session.save()
    preflight(session)
    for attempt in range(1, attempts + 1):
        result = session.command(f"install-{attempt}", ["device", "install", "app", str(app)])
        # Always query after a failed/uncertain request before considering retry.
        query = session.command(f"verify-install-{attempt}", ["device", "info", "apps",
                                "--bundle-id", expected["bundleIdentifier"], "--include-default-apps"])
        matching = installed_match(query, expected)
        if matching and not result["ok"]:
            session.finish("version_present_install_unconfirmed",
                           "The requested version/build is present, but this install was not "
                           "acknowledged. No reinstall or launch attempted; inspect the saved result.")
            return 2
        if matching and result["ok"]:
            if launch:
                started = session.command("launch", ["device", "process", "launch",
                                                       expected["bundleIdentifier"]])
                pid = started["data"].get("result", {}).get("process", {}).get("processIdentifier")
                if not started["ok"] or not isinstance(pid, int) or pid <= 0:
                    session.finish("installed_launch_unconfirmed",
                                   "Installation/build verified; launch was not confirmed. Do not reinstall to retry launch.")
                    return 2
            session.finish("installed_and_launched" if launch else "installed",
                           f"Build {expected['bundleVersion']} installation and version verified. " +
                           ("Launch acknowledged by the device." if launch else "App was not launched."))
            return 0
        if result["ok"] or not query["ok"]:
            # Avoid another installation when success was acknowledged but the
            # query failed, or when the device cannot resolve an unknown outcome.
            session.finish("install_verification_unconfirmed",
                           "Install verification is incomplete. No blind reinstall attempted; inspect saved evidence.")
            return 2
    session.finish("install_failed", "Installation was not confirmed within the bounded attempts.")
    return 2


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["journals", "install"])
    parser.add_argument("--device", required=True, help="Explicit Watch identifier/name; never auto-selects")
    parser.add_argument("--bundle", default="com.qayshp.TeachingTimer")
    parser.add_argument("--output", type=Path, required=True, help="NEW private evidence directory, normally under work/")
    parser.add_argument("--retry", action="store_true", help="Allow one retry per failed copy/install, never an open loop")
    parser.add_argument("--timeout", type=int, help="Per-command seconds (default 30 copy / 90 install; max 120)")
    parser.add_argument("--budget", type=int, default=300, help="Overall device-operation budget, seconds (10–900)")
    parser.add_argument("--app", type=Path, help="Signed physical Watch .app; required for install")
    parser.add_argument("--launch", action="store_true", help="Explicitly launch after confirmed installation")
    args = parser.parse_args(argv)
    args.timeout = args.timeout if args.timeout is not None else (30 if args.operation == "journals" else 90)
    if not 1 <= args.timeout <= 120 or not 10 <= args.budget <= 900:
        parser.error("timeout must be 1–120; budget must be 10–900 seconds")
    if args.operation == "journals" and (args.app or args.launch):
        parser.error("journal collection never installs or launches")
    if args.operation == "install" and not args.app:
        parser.error("install requires --app")
    os.umask(0o077)
    session = None
    try:
        # Local validation does not wake/contact a device or consume its budget.
        app, expected = app_metadata(args.app, args.bundle) if args.app else (None, None)
        session = Session(args.output, args.device, args.budget, args.timeout)
        session.manifest["operation"] = args.operation
        session.save()
        if args.operation == "journals":
            return collect_journals(session, args.bundle, 2 if args.retry else 1)
        return install(session, app, expected, 2 if args.retry else 1, args.launch)
    except KeyboardInterrupt:
        if session:
            session.finish("interrupted_outcome_unknown", "Interrupted; an on-device operation may still finish. Inspect before retrying.")
        return 130
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        if session:
            session.finish("error", f"Stopped: {error}")
        else:
            print(f"No device operations started: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
