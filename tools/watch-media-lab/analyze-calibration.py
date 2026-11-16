#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Offline Crown trial correlation. No device, Simulator, GUI or network calls."""
import argparse
import collections
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import re
import time


EVALUATION = re.compile(
    r"^Evaluating dispatch of UIEvent: (?P<object>0x[0-9a-fA-F]+); "
    r"type: (?P<type>\d+); subtype: (?P<subtype>\d+); "
    r"backing type: (?P<backing>\d+); "
    r"tagged context: (?P<context>0x[0-9a-fA-F]+); "
    r"shouldSend: (?P<send>\d+); ignoreInteractionEvents: (?P<ignore>\d+), "
    r"systemGestureStateChange: (?P<gesture>\d+)$"
)
LAUNCH_PID = re.compile(r":\s*(\d+)\s*$")


def timestamp(value):
    if isinstance(value, (int, float)):
        return float(value)
    normalized = value.replace("Z", "+00:00")
    # Python 3.9's fromisoformat requires a colon in UTC offsets; log uses -0800.
    normalized = re.sub(r"([+-]\d{2})(\d{2})$", r"\1:\2", normalized)
    parsed = dt.datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        raise ValueError("Timestamp has no timezone: " + value)
    return parsed.timestamp()


def sign(value):
    return "+" if value > 0 else "-" if value < 0 else "0"


def file_ref(path, content=None):
    data = path.read_bytes() if content is None else content
    return {"file": path.name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def read_completed_trials(root, expected, wait_seconds):
    deadline = time.monotonic() + wait_seconds
    last_issue = "trial file missing"
    while True:
        try:
            data = (root / "calibration-trials.json").read_bytes()
            trials = json.loads(data)
            if len(trials) != expected:
                raise ValueError("expected %d completed trials, found %d" % (expected, len(trials)))
            if [t.get("trial") for t in trials] != list(range(1, expected + 1)):
                raise ValueError("trial numbers are missing, duplicate or unordered")
            for trial in trials:
                if not trial.get("settledUTC"):
                    raise ValueError("trial lacks its settled marker")
                number = trial["trial"]
                for phase in ("before", "after"):
                    path = root / ("calibration-%02d-%s.json" % (number, phase))
                    journal = json.loads(path.read_bytes())
                    if not journal:
                        raise ValueError(str(path) + " is empty")
            return trials, data
        except (OSError, ValueError, KeyError) as error:
            last_issue = str(error)
        if time.monotonic() >= deadline:
            raise ValueError("Completed trial set unavailable: " + last_issue)
        time.sleep(min(0.5, max(0, deadline - time.monotonic())))


def bridge_receipt(text):
    events, extra = [], []
    for line in text.splitlines():
        try:
            record = json.loads(line)
        except ValueError:
            extra.append(line)
        else:
            events.append(record)
    names = [e.get("event") for e in events]
    completed = "ended_sent" in names and "gesture_finished" in names
    invalid = [line for line in extra if line == "XPC peer error: Connection invalid"]
    other = [line for line in extra if line not in invalid]
    return {
        "events": events,
        "completed": completed,
        "connectionInvalidLines": len(invalid),
        "otherNonJSONLines": other,
        "teardownInterpretation": (
            "Expected intentional cancellation receipt; merged stderr/stdout can place it before gesture_finished. "
            "Successful runner return and completed markers retained."
            if invalid and completed and not other else
            "No expected connection-invalid receipt" if not invalid else
            "Incomplete or unexpected receipt; inspect raw bridge output"
        ),
    }


def analyze(root, trials, trial_bytes):
    prepared, issues, sources = [], [], [file_ref(root / "calibration-trials.json", trial_bytes)]
    for trial in trials:
        number = trial["trial"]
        match = LAUNCH_PID.search(trial["launch"])
        if not match:
            raise ValueError("Cannot parse launched PID for trial %d" % number)
        start, end = timestamp(trial["beforeInputUTC"]), timestamp(trial["settledUTC"])
        if end <= start:
            raise ValueError("Invalid input window for trial %d" % number)
        before_path = root / ("calibration-%02d-before.json" % number)
        after_path = root / ("calibration-%02d-after.json" % number)
        before_bytes, after_bytes = before_path.read_bytes(), after_path.read_bytes()
        before, after = json.loads(before_bytes), json.loads(after_bytes)
        sources.extend([file_ref(before_path, before_bytes), file_ref(after_path, after_bytes)])
        run_id = trial["runID"]
        if any(e.get("runID") != run_id for e in before + after):
            raise ValueError("Mixed journal run IDs for trial %d" % number)
        previous_seq = max(e["sequence"] for e in before)
        new = [e for e in after if e["sequence"] > previous_seq]
        callbacks = [e for e in new if e["event"] == "value_changed"]
        out_of_window = [e["sequence"] for e in callbacks
                         if not start <= timestamp(e["wallTimeSeconds"]) <= end]
        if out_of_window:
            issues.append("trial %d has callbacks outside its exact input window: %s" % (number, out_of_window))
        callbacks = [e for e in callbacks if start <= timestamp(e["wallTimeSeconds"]) <= end]
        initial = float(before[0]["fields"]["value"])
        prior = [e for e in before if e["event"] == "value_changed"]
        if prior:
            initial = float(prior[-1]["fields"]["newValue"])
        final = float(callbacks[-1]["fields"]["newValue"]) if callbacks else initial
        net = final - initial
        if not math.isclose(initial, trial["initialValue"], abs_tol=1e-12):
            issues.append("trial %d initial value differs from runner summary" % number)
        if not math.isclose(final, trial["finalValue"], abs_tol=1e-12):
            issues.append("trial %d final value differs from runner summary" % number)
        resets = [e for e in new if e["event"] == "reset_requested"]
        if resets:
            issues.append("trial %d contains a reset" % number)
        receipt = bridge_receipt(trial["bridge"])
        if not receipt["completed"] or receipt["otherNonJSONLines"]:
            issues.append("trial %d bridge receipt is incomplete/unexpected" % number)
        prepared.append({
            "trial": number, "injectedDelta": trial["delta"], "launchedPID": int(match.group(1)),
            "runID": run_id, "beforeInputUTC": trial["beforeInputUTC"],
            "afterInputUTC": trial["afterInputUTC"], "settledUTC": trial["settledUTC"],
            "windowStartUnixSeconds": start, "windowEndUnixSeconds": end,
            "initialBinding": initial, "finalBinding": final, "bindingNetChange": net,
            "bindingCallbackCount": len(callbacks),
            "bindingCallbackSigns": dict(collections.Counter(sign(float(e["fields"]["delta"])) for e in callbacks)),
            "bindingCallbacks": callbacks, "resetCount": len(resets),
            "orientation": trial.get("orientation", {}), "bridge": receipt,
            "uikitEvaluations": [],
        })
    for left, right in zip(prepared, prepared[1:]):
        if left["windowEndUnixSeconds"] >= right["windowStartUnixSeconds"]:
            issues.append("Trial windows overlap")

    log_path = root / "live-apps.ndjson"
    digest = hashlib.sha256()
    snapshot_bytes, rows, malformed = 0, 0, []
    with log_path.open("rb") as source:
        for line_number, data in enumerate(source, 1):
            digest.update(data)
            snapshot_bytes += len(data)
            try:
                record = json.loads(data)
            except ValueError:
                malformed.append(line_number)
                continue
            rows += 1
            match = EVALUATION.match(record.get("eventMessage", ""))
            if not match or match["type"] != "7" or match["backing"] != "6":
                continue
            when = timestamp(record["timestamp"])
            for trial in prepared:
                if (record.get("processID") == trial["launchedPID"] and
                        trial["windowStartUnixSeconds"] <= when <= trial["windowEndUnixSeconds"]):
                    trial["uikitEvaluations"].append({
                        "sourceLine": line_number, "timestamp": record["timestamp"],
                        "machTimestamp": record.get("machTimestamp"), "processID": record["processID"],
                        "threadID": record.get("threadID"), "activityIdentifier": record.get("activityIdentifier"),
                        "senderImageUUID": record.get("senderImageUUID"),
                        "subtype": int(match["subtype"]), "shouldSend": int(match["send"]),
                        "ignoreInteractionEvents": int(match["ignore"]),
                        "systemGestureStateChange": int(match["gesture"]),
                        "object": match["object"], "context": match["context"],
                    })
    sources.append({"file": log_path.name, "bytesRead": snapshot_bytes,
                    "sha256OfReadPrefix": digest.hexdigest(), "JSONRows": rows,
                    "nonJSONOrPartialLineNumbers": malformed,
                    "snapshotNote": "Capture may continue growing; hash covers exactly the prefix read by this analysis."})
    mapping = {"+": set(), "-": set()}
    motion_mapping = {"+": set(), "-": set()}
    end_subtypes = collections.Counter()
    nonresponsive = []
    for trial in prepared:
        evaluations = trial["uikitEvaluations"]
        markers = [e for e in trial["bridge"]["events"]
                   if e.get("event") in ("began_sent", "sample_sent", "ended_sent")]
        for evaluation in evaluations:
            when = timestamp(evaluation["timestamp"])
            closest = sorted(((abs(when - marker["hostUnixSeconds"]), marker) for marker in markers),
                             key=lambda item: item[0])
            if closest and closest[0][0] <= 0.05:
                distance, marker = closest[0]
                evaluation["nearestBridgeSendMarker"] = {
                    "event": marker["event"], "phase": marker["phase"], "delta": marker["delta"],
                    "hostUnixSeconds": marker["hostUnixSeconds"],
                    "evaluationMinusMarkerSeconds": when - marker["hostUnixSeconds"],
                    "association": "Temporal nearest send marker within 50ms, not a UIKit phase field",
                }
                if marker["event"] == "ended_sent":
                    end_subtypes[str(evaluation["subtype"])] += 1
        sendable = [e for e in evaluations if e["shouldSend"] == 1]
        trial["uikitEvaluationCount"] = len(evaluations)
        trial["uikitSendableCount"] = len(sendable)
        trial["uikitSubtypeCounts"] = dict(collections.Counter(str(e["subtype"]) for e in evaluations))
        trial["uikitSendableSubtypeCounts"] = dict(collections.Counter(str(e["subtype"]) for e in sendable))
        if not sendable:
            issues.append("trial %d has no dispatchable UIKit type7/backing6 evaluations" % trial["trial"])
        mapping[sign(trial["injectedDelta"])].update(e["subtype"] for e in sendable)
        sample_rows = [e for e in sendable if e.get("nearestBridgeSendMarker", {}).get("event") == "sample_sent"]
        trial["sampleAssociatedSubtypeCounts"] = dict(collections.Counter(str(e["subtype"]) for e in sample_rows))
        trial["endedAssociatedSubtypeCounts"] = dict(collections.Counter(
            str(e["subtype"]) for e in sendable
            if e.get("nearestBridgeSendMarker", {}).get("event") == "ended_sent"))
        if trial["bindingNetChange"] == 0:
            nonresponsive.append(trial["trial"])
        else:
            if not sample_rows:
                issues.append("responsive trial %d has no send-associated evaluation within 50ms" % trial["trial"])
            motion_mapping[sign(trial["injectedDelta"])].update(e["subtype"] for e in sample_rows)
    consistent = (not issues and all(len(s) == 1 for s in mapping.values())
                  and mapping["+"] != mapping["-"])
    motion_consistent = (not issues and all(len(s) == 1 for s in motion_mapping.values())
                         and motion_mapping["+"] != motion_mapping["-"])
    return {
        "createdUTC": dt.datetime.now(dt.timezone.utc).isoformat(),
        "scope": "Simulator DTUHID signed-scroll injection versus public digitalCrownRotation binding and UIKit logs",
        "windowRule": "launched processID equality AND beforeInputUTC <= log timestamp <= settledUTC",
        "eventRule": "Only Evaluating dispatch rows with type7/backing6; each row retained, no pointer/traceID deduplication",
        "consistentMappingObserved": consistent,
        "subtypesByInjectedSign": {s: sorted(values) for s, values in mapping.items()},
        "responsiveSampleMappingObserved": motion_consistent,
        "responsiveSampleSubtypesByInjectedSign": {s: sorted(values) for s, values in motion_mapping.items()},
        "nonresponsiveTrialNumbers": nonresponsive,
        "endedAssociatedSubtypeCounts": dict(end_subtypes),
        "sendMarkerAssociationRule": "Nearest same-trial began_sent/sample_sent/ended_sent host timestamp within 50ms; temporal association only",
        "issues": issues, "sources": sources, "trials": prepared,
        "limits": [
            "Mapping applies to this Simulator runtime, orientation and DTUHID injection path.",
            "A signed guest scroll delta is not a physical Crown angle or detent count.",
            "Public Crown binding calibration does not establish native volume baseline, focus or phone audio outcome.",
            "UIKit subtype alone is not a scalar delta, magnitude, or proof of the user's intended gesture.",
        ],
    }


def findings(result):
    lines = ["# Crown calibration findings", "", result["scope"] + ".", "",
             "| Trial | Injected delta | PID | Binding before → after | All evaluations | Sample / ended subtype |",
             "|---:|---:|---:|---|---:|---|"]
    for trial in result["trials"]:
        lines.append("| %d | %+.2f | %d | %.9f → %.9f | %d | %s |" % (
            trial["trial"], trial["injectedDelta"], trial["launchedPID"],
            trial["initialBinding"], trial["finalBinding"], trial["uikitEvaluationCount"],
            json.dumps(trial["sampleAssociatedSubtypeCounts"], sort_keys=True) + " / " +
            json.dumps(trial["endedAssociatedSubtypeCounts"], sort_keys=True)))
    responsive = [t for t in result["trials"] if t["bindingNetChange"] != 0]
    responsive_groups = collections.defaultdict(list)
    for trial in responsive:
        responsive_groups[trial["injectedDelta"]].append(trial)
    descriptions = []
    for delta, group in sorted(responsive_groups.items(), reverse=True):
        directions = sorted({"increased" if t["bindingNetChange"] > 0 else "decreased" for t in group})
        subtypes = sorted({s for t in group for s in t["sampleAssociatedSubtypeCounts"]})
        descriptions.append("%d trial(s) at %+.3g %s the public binding; sample-associated subtype(s): %s" % (
            len(group), delta, "/".join(directions), ", ".join(subtypes)))
    nonresponsive = [t for t in result["trials"] if t["bindingNetChange"] == 0]
    lines += ["", "Responsive sample mapping observed: **%s**. Subtypes by injected sign for trials with a nonzero "
              "public binding change: `%s`." % (result["responsiveSampleMappingObserved"],
              json.dumps(result["responsiveSampleSubtypesByInjectedSign"], sort_keys=True)), "",
        "; ".join(descriptions) + ". Zero-delta ended-associated subtype counts: `%s`. " %
        json.dumps(result["endedAssociatedSubtypeCounts"], sort_keys=True) +
        "A whole-window unique-subtype mapping is therefore **%s** (`%s`)." % (
            result["consistentMappingObserved"], json.dumps(result["subtypesByInjectedSign"], sort_keys=True)), "",
        "Trials with no public binding net change: `%s`. Their complete callbacks and sample-associated subtype "
        "counts remain in the JSON report. Small-input resolution/threshold behavior remains unresolved; a zero binding "
        "change does not establish signed negative or positive motion." %
        json.dumps([{ "trial": t["trial"], "injectedDelta": t["injectedDelta"],
                      "callbacks": t["bindingCallbackCount"], "subtypes": t["sampleAssociatedSubtypeCounts"]}
                    for t in nonresponsive], sort_keys=True), "",
        "Each trial uses the exact launched PID and beforeInputUTC-to-settledUTC window. "
        "Only evaluated type7/backing6 dispatch records are counted; repeated UIEvent addresses are retained. "
        "The boundary/sample label is the nearest same-trial bridge send marker within 50ms; UIKit does not expose its phase "
        "in this log message. The JSON report preserves exact timestamps, source lines, association offsets, journal "
        "callbacks and bridge receipts.", "",
        "The successful bridge output can include `XPC peer error: Connection invalid` around its final completion "
        "marker. With ended_sent, gesture_finished and successful runner return, this records the intentional "
        "cancellation. Merged stdout/stderr ordering does not establish a delivery failure.", ""]
    if result["issues"]:
        lines += ["Issues: " + "; ".join(result["issues"]), ""]
    lines += result["limits"]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True, help="Private directory containing trial journals and live-apps.ndjson")
    parser.add_argument("--expected-trials", type=int, default=6)
    parser.add_argument("--wait-seconds", type=float, default=60)
    args = parser.parse_args()
    if not 0 <= args.wait_seconds <= 60 or not 1 <= args.expected_trials <= 100:
        parser.error("wait must be 0...60 seconds; expected trials must be 1...100")
    root = args.root.resolve()
    trials, trial_bytes = read_completed_trials(root, args.expected_trials, args.wait_seconds)
    result = analyze(root, trials, trial_bytes)
    (root / "calibration-results.json").write_text(json.dumps(result, indent=2) + "\n")
    (root / "calibration-findings.md").write_text(findings(result))
    print(json.dumps({"trials": len(result["trials"]),
                      "consistentMappingObserved": result["consistentMappingObserved"],
                      "subtypesByInjectedSign": result["subtypesByInjectedSign"],
                      "responsiveSampleMappingObserved": result["responsiveSampleMappingObserved"],
                      "responsiveSampleSubtypesByInjectedSign": result["responsiveSampleSubtypesByInjectedSign"],
                      "nonresponsiveTrialNumbers": result["nonresponsiveTrialNumbers"],
                      "issues": result["issues"]}))
    return 0 if result["responsiveSampleMappingObserved"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
