#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Prepare a private physical-media notebook, mark events, or summarize it.

Never discovers, controls, installs, launches, plays audio or collects from a
device. Generated capture commands require separate supervised execution.
"""
import argparse
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time
import uuid
from zoneinfo import ZoneInfo

PACIFIC = ZoneInfo("America/Los_Angeles")
CATALOG = Path(__file__).with_name("physical-media-scenarios.json")
EVENTS = ("run_started", "devices_confirmed", "source_confirmed", "route_confirmed",
          "playback_started", "class_started", "watch_foreground", "ring_before",
          "crown_input", "ring_after", "incident", "recovery", "capture_started",
          "capture_saved", "audio_stopped", "run_stopped", "note")


def repository():
    return Path(__file__).resolve().parents[1]


def scenario_catalog():
    catalog = json.loads(CATALOG.read_text())
    if catalog.get("schemaVersion") != 1:
        raise ValueError("Unsupported physical-media scenario catalog")
    required = ("id", "hypothesisID", "title", "hypothesis", "changedFactor")
    lists = ("supports", "weakens", "requiredEvidence", "steps")
    scenarios = catalog.get("scenarios", [])
    seen = set()
    if not scenarios:
        raise ValueError("Physical-media scenario catalog is empty")
    for scenario in scenarios:
        if any(not isinstance(scenario.get(key), str) or not scenario[key].strip() for key in required):
            raise ValueError("Scenario requires a hypothesis and single changed factor")
        if scenario["id"] in seen:
            raise ValueError("Duplicate scenario ID: " + scenario["id"])
        seen.add(scenario["id"])
        if any(not isinstance(scenario.get(key), list) or not scenario[key] or
               any(not isinstance(item, str) or not item.strip() for item in scenario[key]) for key in lists):
            raise ValueError("Scenario requires predictions, counterevidence, evidence and ordered steps")
    for key in ("readiness", "commonControls", "stopConditions", "evidenceLimits"):
        if not catalog.get(key):
            raise ValueError("Scenario catalog is missing " + key)
    return catalog


def selected_scenario(catalog, identifier):
    return next((item for item in catalog["scenarios"] if item["id"] == identifier), None)


def catalog_command(args):
    catalog = scenario_catalog()
    if args.scenario:
        scenario = selected_scenario(catalog, args.scenario)
        if scenario is None:
            raise ValueError("Unknown scenario: " + args.scenario)
        catalog = {**catalog, "scenarios": [scenario]}
    if args.json:
        print(json.dumps(catalog, indent=2, ensure_ascii=False))
    else:
        for scenario in catalog["scenarios"]:
            print(scenario["id"], "|", scenario["hypothesisID"], "|", scenario["title"])
            if args.scenario:
                print("Hypothesis:", scenario["hypothesis"])
                print("Changed factor:", scenario["changedFactor"])
                for number, step in enumerate(scenario["steps"], 1):
                    print(str(number) + ".", step)
    return 0


def stamp():
    wall_ns = time.time_ns()
    monotonic_ns = time.monotonic_ns()
    wall = datetime.fromtimestamp(wall_ns / 1e9, timezone.utc)
    return {"wallUTC": wall.isoformat(timespec="microseconds"),
            "wallPacific": wall.astimezone(PACIFIC).isoformat(timespec="microseconds"),
            "pacificZone": wall.astimezone(PACIFIC).tzname(),
            "wallUnixNanoseconds": wall_ns, "hostMonotonicNanoseconds": monotonic_ns}


def local_query(argv, cwd):
    """Only called with the fixed local metadata queries below, never device APIs."""
    try:
        result = subprocess.run(argv, cwd=cwd, capture_output=True, text=True,
                                timeout=8, check=False)
        return {"argv": argv, "returnCode": result.returncode,
                "stdout": result.stdout.strip(), "stderr": result.stderr.strip()}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"argv": argv, "returnCode": None, "error": str(error)}


def write_json(path, value):
    with path.open("x", encoding="utf-8") as output:
        json.dump(value, output, indent=2, ensure_ascii=False)
        output.write("\n")


def private_run(path, repo):
    run = path.expanduser().resolve()
    work = (repo / "work").resolve()
    if run == work or work not in run.parents:
        raise ValueError("Run directory must be a new child of this repository's ignored work/")
    return run


def read_run(path):
    run = private_run(path, repository())
    manifest = json.loads((run / "run.json").read_text())
    if manifest.get("schemaVersion") != 1 or manifest.get("kind") != "physical-media-preparation":
        raise ValueError("Not a physical-media run notebook")
    return run, manifest


def append_event(run, event, fields):
    # Lock the actual append-only file so simultaneous operator marks do not
    # duplicate sequences or overwrite each other. A damaged tail fails closed.
    descriptor = os.open(run / "events.ndjson", os.O_RDWR | os.O_APPEND | os.O_CREAT, 0o600)
    with os.fdopen(descriptor, "a+", encoding="utf-8") as output:
        fcntl.flock(output, fcntl.LOCK_EX)
        output.seek(0)
        saved = output.read()
        if saved and not saved.endswith("\n"):
            raise ValueError("Event file has an incomplete tail; preserve it and inspect it")
        previous = [json.loads(line) for line in saved.splitlines() if line.strip()]
        if [row["sequence"] for row in previous] != list(range(1, len(previous) + 1)):
            raise ValueError("Event sequence is damaged; preserve the file and inspect it")
        row = {"sequence": len(previous) + 1, "event": event, **stamp(), "fields": fields}
        output.write(json.dumps(row, ensure_ascii=False) + "\n")
        output.flush()
        os.fsync(output.fileno())
    return row


def prepared_commands(repo, run, args):
    watch = args.watch or "<LIVE_WATCH_IDENTIFIER>"
    phone = args.phone or "<LIVE_PHONE_IDENTIFIER>"
    commands = []
    for phase in ("before", "after"):
        commands.append({"stage": "watch-journals-" + phase,
                         "argv": ["python3", str(repo / "scripts/watch_device.py"), "journals",
                                  "--device", watch, "--bundle", args.bundle,
                                  "--output", str(run / "captures" / ("watch-journals-" + phase)),
                                  "--timeout", "20", "--budget", "120"]})
        for name, target in (("watch", watch), ("phone", phone)):
            commands.append({"stage": name + "-details-" + phase,
                             "argv": ["xcrun", "devicectl", "device", "info", "details",
                                      "--device", target, "--timeout", "15", "--json-output",
                                      str(run / "snapshots" / (name + "-details-" + phase + ".json"))]})
    commands.append({"stage": "watch-journals-failure",
                     "argv": ["python3", str(repo / "scripts/watch_device.py"), "journals",
                              "--device", watch, "--bundle", args.bundle,
                              "--output", str(run / "captures/watch-journals-failure"),
                              "--timeout", "8", "--budget", "30"]})
    # These are reviewed future commands, not preparation actions. Resolve any
    # third-party app bundle from the live inventory rather than guessing it.
    commands.extend([
        {"stage": "phone-app-inventory", "argv": ["xcrun", "devicectl", "device", "info", "apps",
          "--device", phone, "--timeout", "15", "--json-output", str(run / "snapshots/phone-apps.json")]},
        {"stage": "open-phone-apple-music", "argv": ["xcrun", "devicectl", "device", "process", "launch",
          "--device", phone, "--timeout", "15", "com.apple.Music"],
         "condition": "Only after authorization and live app/source/output confirmation; opening does not prove playback."},
        {"stage": "open-watch-timer", "argv": ["xcrun", "devicectl", "device", "process", "launch",
          "--device", watch, "--timeout", "15", args.bundle],
         "condition": "Initial/open-return step only; do not relaunch to repair a failure before preserving it."},
        {"stage": "open-watch-standalone-now-playing", "argv": ["xcrun", "devicectl", "device", "process", "launch",
          "--device", watch, "--timeout", "15", "com.apple.NanoNowPlaying"],
         "condition": "Separate comparison only after embedded-failure evidence is saved; changes foreground/runtime."},
    ])
    for name, target in (("watch", watch), ("phone", phone)):
        commands.append({"stage": name + "-sysdiagnose-on-incident",
                         "argv": ["xcrun", "devicectl", "device", "sysdiagnose", "--device", target,
                                  "--destination", str(run / "captures" / (name + "-sysdiagnose")),
                                  "--timeout", "600", "--json-output",
                                  str(run / "snapshots" / (name + "-sysdiagnose.json"))],
                         "condition": "One incident capture after permission and preservation; do not run as routine playback. "
                         "A timeout may leave capture running: inspect existing captures before any retry. "
                         "Record acknowledgement/transfer/validation separately; native authentication may be needed."})
    return {"executed": False, "requiresSeparateSupervisedExecution": True,
            "placeholders": [value for value in (watch, phone) if value.startswith("<LIVE_")],
            "commands": commands}


def instructions(repo, run, commands, experiment=None):
    notebook = ["python3", str(repo / "scripts/physical-media-run.py")]
    def mark(event, *extra):
        return shlex.join(notebook + ["mark", "--run", str(run), "--event", event, *extra])
    lines = ["# Supervised physical media run", "",
             "Preparation is complete; no device operation has run. Keep this directory private. "
             "Run one reviewed command at a time only after the devices are available and the operator "
             "confirms the live Watch, phone, playback source and output. Replace every <LIVE_...> "
             "placeholder; do not reuse historical device IDs.", ""]
    if experiment:
        scenario = experiment["scenario"]
        lines += ["## " + scenario["hypothesisID"] + " — " + scenario["title"], "",
                  "Hypothesis: " + scenario["hypothesis"], "",
                  "Changed factor: " + scenario["changedFactor"], ""]
        for heading, items in (("Readiness — all unverified until the supervised session", experiment["readiness"]),
                               ("Keep fixed", experiment["commonControls"]),
                               ("Would support", scenario["supports"]), ("Would weaken", scenario["weakens"]),
                               ("Required evidence", scenario["requiredEvidence"]),
                               ("Evidence limits", experiment["evidenceLimits"] + scenario.get("limits", []))):
            lines += ["### " + heading, "", *["- " + item for item in items], ""]
        lines += ["### Ordered scenario actions — not executed", "",
                  *[str(number) + ". " + item for number, item in enumerate(scenario["steps"], 1)], "",
                  "### Stop, capture and restoration", "",
                  *["- " + item for item in experiment["stopConditions"]], ""]
    else:
        lines += ["This is an exploratory notebook without a selected hypothesis. Use --scenario "
                  "for a specified physical test; exploratory observations cannot become a passing hypothesis test.", ""]
    lines += ["## Common execution and preservation", "",
             "1. Confirm the planned arm/build, source, route, order and stop duration in run.json. "
             "Use one supervised GUI input owner. The Simulator HubInput helper and private Simulator "
             "Crown bridge are not physical input drivers.",
             "2. Copy pre-run journals and optional device details using the before commands below. "
             "watch_device.py has bounded discovery/details and journal copy; it never launches an app "
             "or starts sysdiagnose. Inspect its operation.json for transfer/validation results.",
             "3. Mark run_started, actual source/route confirmation, playback_started, class_started, "
             "and watch_foreground as they occur. An operator mark is not independent device proof. "
             "Verify actual order; the plan does not establish it.",
             "4. Save ring/phone-volume evidence before and after one known small Crown turn. "
             "Supply the intent, actual direction description and magnitude honestly; write unknown "
             "when unmeasured. Do not convert Simulator subtype numbers into physical direction.",
             "5. At a useful failure, mark incident and preserve ring, phone state, route, sound and "
             "timestamps before recovery. Save screenshots/short recording manually into snapshots/ "
             "and mark their evidence paths. Mirror pixels alone do not prove the physical display. "
             "One per-device sysdiagnose command is prepared for an incident only; it is not executed here. "
             "Request any required native authentication at that point, and inspect existing captures before retrying.",
             "6. Stop input on lock, lost connection, ambiguous UI or unexpected route. At the planned "
             "duration, stop audio, mark audio_stopped/run_stopped, then copy after journals and summarize.", "",
             "## Quick marks", "", "```sh", mark("run_started"),
             mark("crown_input", "--intent", "increase", "--direction", "operator describes direction",
                  "--magnitude", "one small turn; angular distance unmeasured", "--note", "mark just before turn"),
             mark("incident", "--note", "describe observed symptom before recovery"),
             mark("capture_saved", "--evidence", "snapshots/operator-recording.mov",
                  "--observed", "describe what the saved recording establishes"),
             mark("audio_stopped"), mark("run_stopped"),
             shlex.join(notebook + ["summary", "--run", str(run)]), "```", "",
             "UTC and Pacific wall time plus host monotonic nanoseconds are recorded for every mark. "
             "These are mark times, not inferred device-event times. Host monotonic intervals apply "
             "only within the same host boot; keep wall-clock and device-log alignment separate.", "",
             "## Prepared capture and app-open commands — not executed", "",
             "Each journal output must remain NEW. Do not rerun a command against an existing output "
             "or overwrite snapshot JSON. Prepare a new run for another arm. Device-info snapshots "
             "are metadata, not screen or audio captures.", ""]
    for command in commands["commands"]:
        lines += ["### " + command["stage"], ""]
        if command.get("condition"):
            lines += [command["condition"], ""]
        lines += ["```sh", shlex.join(command["argv"]), "```", ""]
    if experiment:
        lines += ["## Operator assessment — never an automatic pass", "",
                  "Compare the required evidence with both predictions. Missing request records, "
                  "unknown control identity, wrong output or protocol deviations can make the result "
                  "inconclusive. The command below is a template, not an observed outcome.", "", "```sh",
                  shlex.join(notebook + ["assess", "--run", str(run), "--result", "inconclusive",
                                         "--note", "describe the missing evidence or unresolved comparison"]),
                  "```", ""]
    return "\n".join(lines)


def prepare(args):
    repo = repository().resolve()
    experiment = None
    if args.scenario:
        catalog = scenario_catalog()
        scenario = selected_scenario(catalog, args.scenario)
        if scenario is None:
            raise ValueError("Unknown scenario: " + args.scenario)
        defaults = {**catalog["defaults"], **scenario.get("defaults", {})}
        for key in ("source", "route", "order", "order_note", "minutes"):
            default_key = "orderNote" if key == "order_note" else key
            if getattr(args, key) is None:
                setattr(args, key, defaults[default_key])
        args.arm = args.arm or scenario["id"]
        experiment = {key: catalog[key] for key in
                      ("readiness", "commonControls", "stopConditions", "evidenceLimits")}
        experiment.update(catalogSchemaVersion=catalog["schemaVersion"], scenario=scenario)
    args.minutes = 10 if args.minutes is None else args.minutes
    args.order_note = args.order_note or ""
    for name in ("arm", "source", "route"):
        if not getattr(args, name) or not getattr(args, name).strip():
            raise ValueError(name + " must describe the plan, or explicitly say unconfirmed")
    if args.order is None:
        raise ValueError("--order is required without --scenario")
    if args.order == "other" and not args.order_note.strip():
        raise ValueError("--order other requires --order-note")
    if not 1 <= args.minutes <= 30:
        raise ValueError("--minutes must be 1–30")
    default = repo / "work" / ("physical-media-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                               + "-" + uuid.uuid4().hex[:8])
    run = private_run(args.output or default, repo)
    if run.exists():
        raise FileExistsError("Run directory already exists; evidence will not be overwritten")
    ignored = local_query(["git", "check-ignore", "--quiet", "--", str(run.relative_to(repo))], repo)
    if ignored["returnCode"] != 0:
        raise ValueError("Cannot confirm output is Git-ignored; no run directory created")
    tools = {name: shutil.which(name) for name in ("python3", "git", "xcrun", "xcodebuild", "xcode-select")}
    queries = {"repoSHA": ["git", "rev-parse", "HEAD"],
               "trackedWorkingChanges": ["git", "status", "--short", "--untracked-files=no"],
               "xcode": ["xcodebuild", "-version"], "developerDirectory": ["xcode-select", "-p"],
               "devicectlPath": ["xcrun", "--find", "devicectl"]}
    metadata = {name: local_query(argv, repo) for name, argv in queries.items()}
    run.mkdir(parents=True, mode=0o700, exist_ok=False)
    for child in ("captures", "snapshots"):
        (run / child).mkdir(mode=0o700)
    manifest = {"schemaVersion": 1, "kind": "physical-media-preparation", "prepared": stamp(),
                "runID": uuid.uuid4().hex, "deviceOperationsExecuted": False,
                "plan": {"arm": args.arm, "source": args.source, "route": args.route,
                         "playbackClassOrder": args.order, "orderNote": args.order_note,
                         "durationMinutes": args.minutes, "expectedBuild": args.build,
                         "bundle": args.bundle, "watchIdentifier": args.watch,
                         "phoneIdentifier": args.phone},
                "localMetadata": metadata, "toolPaths": tools,
                "experiment": experiment,
                "freeBytesAtPreparation": shutil.disk_usage(run).free,
                "captureCapability": "Prepared argv only; GUI rehearsal and transfer remain unverified",
                "monotonicScope": "This Mac boot only; marks are operator records, not device timestamps"}
    commands = prepared_commands(repo, run, args)
    write_json(run / "run.json", manifest)
    write_json(run / "next-commands.json", commands)
    (run / "NEXT.md").write_text(instructions(repo, run, commands, experiment))
    append_event(run, "prepared", {"source": "offline preparation", "deviceOperationsExecuted": False})
    print(run)
    return 0


def assess(args):
    run, manifest = read_run(args.run)
    experiment = manifest.get("experiment")
    if not experiment:
        raise ValueError("An exploratory notebook has no selected hypothesis to assess")
    if not args.note.strip():
        raise ValueError("Assessment requires an explicit operator rationale")
    if args.evidence and any(not path.strip() for path in args.evidence):
        raise ValueError("Evidence references must name saved files, not blank values")
    if args.result != "inconclusive" and not args.evidence:
        raise ValueError("A supporting/weakening/mixed assessment requires evidence references")
    fields = {"source": "operator interpretation; not independently validated",
              "hypothesisID": experiment["scenario"]["hypothesisID"],
              "scenario": experiment["scenario"]["id"], "result": args.result,
              "rationale": args.note, "deviations": args.deviation or [],
              "evidenceReferences": [{"path": path, "validation": "reference only; not copied or validated"}
                                     for path in (args.evidence or [])]}
    print(json.dumps(append_event(run, "hypothesis_assessment", fields), ensure_ascii=False))
    return 0


def mark(args):
    run, _ = read_run(args.run)
    if args.event == "crown_input" and (not args.intent or not args.magnitude or not args.magnitude.strip()):
        raise ValueError("crown_input requires --intent and operator-supplied --magnitude (unknown is valid)")
    fields = {"source": "operator mark", "note": args.note, "observed": args.observed}
    for key in ("intent", "direction", "magnitude"):
        value = getattr(args, key)
        if value is not None:
            fields[key] = value
    if args.evidence:
        fields["evidenceReferences"] = [{"path": value, "validation": "reference only; not copied or validated"}
                                         for value in args.evidence]
    event = append_event(run, args.event, fields)
    print(json.dumps(event, ensure_ascii=False))
    return 0


def summary(args):
    run, manifest = read_run(args.run)
    events = [json.loads(line) for line in (run / "events.ndjson").read_text().splitlines() if line.strip()]
    result = {"run": str(run), "plan": manifest["plan"], "events": events,
              "experiment": manifest.get("experiment"),
              "operatorAssessments": [e for e in events if e["event"] == "hypothesis_assessment"],
              "testOutcome": "not automatically established; inspect evidence and operator assessments",
              "deviceOperationsExecutedByHelper": False,
              "audioStoppedMarked": any(e["event"] == "audio_stopped" for e in events),
              "runStoppedMarked": any(e["event"] == "run_stopped" for e in events)}
    starts = {name: next((e for e in events if e["event"] == name), None)
              for name in ("playback_started", "class_started")}
    if all(starts.values()):
        result["operatorMarkedOrder"] = ("playback-before-class" if
            starts["playback_started"]["wallUnixNanoseconds"] < starts["class_started"]["wallUnixNanoseconds"]
            else "class-before-playback")
    else:
        result["operatorMarkedOrder"] = "not established; both start marks required"
    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print("Run:", run)
        print("Plan:", json.dumps(manifest["plan"], ensure_ascii=False))
        print("Operator-marked order:", result["operatorMarkedOrder"])
        for event in events:
            print(event["sequence"], event["wallPacific"], event["event"],
                  json.dumps(event["fields"], ensure_ascii=False))
        print("Audio stopped marked:", result["audioStoppedMarked"], "| Run stopped marked:", result["runStoppedMarked"])
        print("Marks and evidence references are operator records; no physical outcome is inferred.")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="operation", required=True)
    listing = sub.add_parser("catalog", help="List hypothesis protocols without any device calls")
    listing.add_argument("--scenario", help="Show one protocol")
    listing.add_argument("--json", action="store_true")
    create = sub.add_parser("prepare", help="Offline metadata and command preparation only")
    create.add_argument("--scenario", help="Named hypothesis protocol; use catalog to list")
    create.add_argument("--output", type=Path, help="NEW ignored work/ child; defaults to a unique private run")
    for name in ("arm", "source", "route"):
        create.add_argument("--" + name)
    create.add_argument("--order", choices=("playback-before-class", "class-before-playback", "other"))
    create.add_argument("--order-note")
    create.add_argument("--minutes", type=int)
    create.add_argument("--build", default="unconfirmed; verify installed build before run")
    create.add_argument("--bundle", default="net.qays.TeachingTimer.watchkitapp")
    create.add_argument("--watch", help="Optional operator-selected live Watch identifier; otherwise placeholder")
    create.add_argument("--phone", help="Optional operator-selected live phone identifier; otherwise placeholder")
    add = sub.add_parser("mark", help="Append an operator event; never perform an action")
    add.add_argument("--run", required=True, type=Path)
    add.add_argument("--event", required=True, choices=EVENTS)
    add.add_argument("--intent", choices=("increase", "decrease", "neutral", "unknown"))
    add.add_argument("--direction", help="Operator's physical direction description; no inferred mapping")
    add.add_argument("--magnitude", help="Operator's amount/units description, or unknown")
    add.add_argument("--note", default="")
    add.add_argument("--observed", default="")
    add.add_argument("--evidence", action="append", help="Saved-file reference only; no copying/validation")
    assessment = sub.add_parser("assess", help="Record an operator hypothesis interpretation; no automatic pass")
    assessment.add_argument("--run", required=True, type=Path)
    assessment.add_argument("--result", required=True, choices=("supports", "weakens", "mixed", "inconclusive"))
    assessment.add_argument("--note", required=True, help="Explicit rationale; not a verified outcome")
    assessment.add_argument("--evidence", action="append", help="Saved-file reference; no copying/validation")
    assessment.add_argument("--deviation", action="append", help="Changed control, unknown state or protocol deviation")
    report = sub.add_parser("summary", help="Read the saved notebook; no device calls")
    report.add_argument("--run", required=True, type=Path)
    report.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    os.umask(0o077)
    try:
        return {"catalog": catalog_command, "prepare": prepare, "mark": mark,
                "assess": assess, "summary": summary}[args.operation](args)
    except (OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
