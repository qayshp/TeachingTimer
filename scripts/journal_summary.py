#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Summarize one local Watch journal snapshot; never contacts a device or uploads."""
import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import sys
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

KINDS = ("RuntimeDiagnostics", "InterfaceDiagnostics", "LandmarkDiagnostics")
FIELDS = ("source", "previousPage", "selectedPage", "observedPage", "previousSceneState",
          "sceneState", "phase", "reason", "reasonCode", "errorDomain", "errorCode",
          "savedRuntimeIntent", "stopRequested", "eligible", "trigger", "cause",
          "failureDetected", "actualFocus", "audioRecovery", "completion",
          "requestedFocus", "call", "settlingSeconds", "secondsSinceRequest",
          "landmark", "pulse", "count", "lateness", "action")


def date(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("timestamps require Z or an explicit UTC offset")
    return parsed.astimezone(timezone.utc)


def safe(value):
    # Keep arbitrary diagnostic values from becoming Markdown/HTML instructions.
    return str(value).replace("&", "&amp;").replace("<", "&lt;").replace(
        ">", "&gt;").replace("|", "\\|").replace("`", "'").replace("\n", " ").replace("\r", " ")[:500]


def number(value):
    try:
        result = float(value)
        return result if math.isfinite(result) else None
    except (TypeError, ValueError):
        return None


def load(paths):
    sources, rows, warnings = [], [], []
    seen = set()
    for path in paths:
        kind = next((kind for kind in KINDS if path.name.endswith(kind + ".json")), None)
        if kind is None:
            raise ValueError(f"Unrecognized journal filename: {path.name}")
        if kind in seen:
            raise ValueError(f"Choose one snapshot per journal, not multiple {kind} files")
        seen.add(kind)
        source = {"name": path.name, "kind": kind, "count": 0, "valid": 0}
        sources.append(source)
        try:
            raw = path.read_bytes()
            source.update(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
            events = json.loads(raw)
            if not isinstance(events, list):
                raise ValueError("journal is not an event array")
        except (OSError, ValueError) as error:
            warnings.append(f"{path.name}: unreadable/missing ({error.__class__.__name__}); no events inferred.")
            continue
        source["count"] = len(events)
        previous = None
        for index, event in enumerate(events, start=1):
            try:
                if not isinstance(event, dict) or not isinstance(event.get("event"), str):
                    raise ValueError("invalid event name")
                stamp = date(event["timestamp"])
                details = event["details"]
                if not isinstance(details, dict) or not all(isinstance(v, str) for v in details.values()):
                    raise ValueError("invalid details")
            except (KeyError, ValueError, TypeError, AttributeError):
                warnings.append(f"{path.name} row {index}: malformed; skipped, source unchanged.")
                continue
            if previous is not None and stamp < previous:
                warnings.append(f"{path.name} row {index}: timestamp moved backward in file order; "
                                "clock correction or out-of-order recording is possible, not diagnosed.")
            previous = stamp
            rows.append({"date": stamp, "name": event["event"], "details": details,
                         "kind": kind, "file": path.name, "row": index})
            source["valid"] += 1
        source_rows = [r for r in rows if r["kind"] == kind]
        if source_rows:
            source["first"] = min(r["date"] for r in source_rows)
            source["last"] = max(r["date"] for r in source_rows)
        if len(events) in (1000, 2000, 4000, 10000, 20000):
            warnings.append(f"{path.name}: count equals a known journal cap; possible earlier eviction, not proven.")
        if any(r["name"] == "journal_recovered" for r in source_rows):
            warnings.append(f"{path.name}: journal_recovered recorded; preceding history may be in a separate corrupt-file backup.")
    for kind in KINDS:
        if kind not in seen:
            warnings.append(f"{kind}.json not supplied; that evidence is unavailable.")
    return sources, rows, warnings


def groups(rows, key):
    result = defaultdict(list)
    for row in rows:
        value = row["details"].get(key)
        if value and value not in ("none", "unknown"):
            result[value].append(row)
    return result


def compact(row):
    name, details = row["name"], row["details"]
    if name in ("haptic_submitted", "landmark_pulse_late", "luminance_changed"):
        return False
    if name in ("volume_focus_requested", "volume_focus_call", "volume_focus_call_returned"):
        return False
    if name == "scene_state_changed":
        return "background" in (details.get("previousSceneState"), details.get("sceneState")) or details.get("previousSceneState") in (None, "unknown")
    return True


def summarize(paths, zone="UTC", start=None, end=None, limit=120, detail=False):
    tz = ZoneInfo(zone)
    if start and end and start > end:
        raise ValueError("--start must not follow --end")
    sources, all_rows, warnings = load(paths)
    rows = [r for r in all_rows if (start is None or r["date"] >= start) and (end is None or r["date"] <= end)]
    runtime = [r for r in rows if r["kind"] == "RuntimeDiagnostics"]
    landmark = [r for r in rows if r["kind"] == "LandmarkDiagnostics"]

    def stamp(value):
        return value.astimezone(tz).isoformat(timespec="seconds")

    out = ["# TeachingTimer incident summary", "",
           f"Display timezone: {safe(zone)}. Window: {stamp(start) if start else 'source beginning'} → {stamp(end) if end else 'source end'}.", "",
           "Private local report; review before sharing. No device access or uploads.",
           "App events do not prove actual Crown focus, rendered media, phone volume, audible sound, or physical haptic delivery.",
           "Missing callbacks do not establish a crash, cancellation, or cause. Copies may have been taken at different instants.", "",
           "## Source coverage", "", "| Journal | Valid / stored events | Observed timestamp range |", "| --- | --- | --- |"]
    for source in sources:
        span = f"{stamp(source['first'])} → {stamp(source['last'])}" if "first" in source else "Unavailable/empty"
        out.append(f"| {safe(source['name'])} | {source['valid']} / {source['count']} | {span} |")
    out += ["", f"Selected events: {len(rows)}. Observed ranges are not guarantees of continuous coverage or retained earlier history.", "",
            "## Builds", ""]
    launch_ids = {r["details"].get("launchID") for r in rows}
    builds = [r for r in all_rows if r["name"] == "app_launched" and
              (r in rows or (r["details"].get("launchID") and r["details"].get("launchID") in launch_ids))]
    if not builds:
        out.append("Build unknown: no matching app_launched event in the supplied snapshot.")
    for row in builds:
        d = row["details"]
        out.append(f"- {stamp(row['date'])}: version {safe(d.get('version', 'unknown'))}, build {safe(d.get('build', 'unknown'))}, revision {safe(d.get('revision', 'unknown'))}; {safe(row['file'])} row {row['row']}.")
    out += ["", "Build lookup can use a matching launch ID outside the selected window; no build is inferred merely from a nearby timestamp.", "",
            "## Class anchors", ""]
    classes = groups(runtime, "intentClassID")
    if not classes:
        out.append("No class anchor recorded in this window; that does not mean no class was active.")
    for anchor, entries in classes.items():
        last = entries[-1]
        out.append(f"- Initial Start anchor {safe(anchor)}: {len(entries)} events; last recorded intent {safe(last['details'].get('savedRuntimeIntent', 'unknown'))} at {stamp(last['date'])}.")
    for row in runtime:
        d = row["details"]
        if "classScheduledStart" in d:
            out.append(f"- Explicit recorded schedule: {safe(d['classScheduledStart'])} → {safe(d.get('classScheduledEnd', 'unknown'))}; {safe(d.get('classDurationMinutes', 'unknown'))} minutes ({safe(row['file'])} row {row['row']}).")
    out += ["", "The initial Start anchor is not the scheduled start. A schedule absent from these events is unknown; it is not re-inferred.", "",
            "## Runtime sessions", ""]
    sessions = groups(runtime, "runtimeID")
    if not sessions:
        out.append("No runtime ID recorded in the selected window.")
    for index, (identifier, entries) in enumerate(sessions.items(), 1):
        last = entries[-1]
        out.append(f"- R{index} ({safe(identifier)}): {stamp(entries[0]['date'])} → {stamp(last['date'])}; last recorded phase {safe(last['details'].get('phase', 'unknown'))}.")
        invalidations = [r for r in entries if r["name"] == "runtime_invalidated"]
        for row in invalidations:
            d = row["details"]
            out.append(f"  - Invalidation at {stamp(row['date'])}: {safe(d.get('reason', 'unknown'))}, raw reason {safe(d.get('reasonCode', 'unknown'))}; stopRequested={safe(d.get('stopRequested', 'unknown'))}; error={safe(d.get('errorDomain', 'none recorded'))}/{safe(d.get('errorCode', 'none recorded'))}.")
        if not invalidations:
            out.append("  - No invalidation callback in this window; current device state and eventual outcome are unknown.")
    out += ["", "Last-state descriptions above use source-file order, not an assumption that the session remains active now.", "",
            "## Landmark runs", ""]
    runs = groups(landmark, "runID")
    if not runs:
        out.append("No landmark run ID in the selected window.")
    for index, (identifier, entries) in enumerate(runs.items(), 1):
        counts = Counter(r["name"] for r in entries)
        submitted = [r for r in entries if r["name"] == "haptic_submitted" and r["details"].get("kind") == "landmark"]
        ack = sum(r["name"] == "haptic_submitted" and r["details"].get("kind") == "ack" for r in entries)
        lateness = [number(r["details"].get("lateness")) for r in submitted]
        lateness = [value for value in lateness if value is not None]
        ended = [r for r in entries if r["name"] == "landmark_ended"]
        outcome = safe(ended[-1]["details"].get("reason", "unknown")) if ended else "no end callback in window; outcome unknown"
        out.append(f"- L{index} ({safe(identifier)}): {len(submitted)} timing submissions + {ack} acknowledgements; {counts['landmark_pulse_late']} late notices; {counts['landmark_group_skipped']} skipped-group notices; max submitted lateness {f'{max(lateness):.3f}s' if lateness else 'unknown'}; end: {outcome}.")
    out += ["", "Submissions are API calls, not confirmed vibrations. Counts describe this window, which may contain only part of a run.", "",
            "## Native volume focus", ""]
    controls = groups(runtime, "controlID")
    if not controls:
        out.append("No native-control IDs recorded in this window.")
    for index, (identifier, entries) in enumerate(controls.items(), 1):
        counts = Counter(r["name"] for r in entries)
        requests = {r["details"].get("requestID") for r in entries if r["name"] == "volume_focus_requested"}
        terminals = {r["details"].get("requestID") for r in entries if r["name"] in ("volume_focus_call_returned", "volume_focus_call_skipped")}
        unresolved = requests - terminals - {None}
        out.append(f"- V{index} ({safe(identifier)}): {counts['volume_focus_requested']} focus/resign requests; {counts['volume_focus_call']} calls; {counts['volume_focus_call_returned']} returns; {counts['volume_focus_call_skipped']} skips; {len(unresolved)} requests without a terminal record in this window. Actual focus remains unobserved.")
    out += ["", "## Page / scene / media observations", ""]
    for name in ("page_selection_changed", "page_appeared", "page_disappeared", "scene_state_changed", "luminance_changed", "media_reload_requested", "volume_refresh_requested", "volume_refresh_completed"):
        entries = [r for r in rows if r["name"] == name]
        out.append(f"- {name}: {len(entries)}")
    out += ["", "Automatic media refresh is not a detected failure or proof of recovery.", "",
            "## Timeline", "", "Wall-clock sorted; equal timestamps across journals do not establish causal ordering. Source rows allow verification.", "",
            "| Time | Event | Recorded context | Source row |", "| --- | --- | --- | --- |"]
    timeline = sorted((r for r in rows if detail or compact(r)), key=lambda r: r["date"])
    for row in timeline[:limit]:
        context = "; ".join(f"{key}={safe(row['details'][key])}" for key in FIELDS if key in row["details"])
        out.append(f"| {stamp(row['date'])} | {safe(row['name'])} | {context} | {safe(row['file'])}:{row['row']} |")
    if len(timeline) > limit:
        out.append(f"\nTimeline limited to {limit} of {len(timeline)} entries; narrow --start/--end or raise --limit. Aggregates above cover the whole selected window.")
    out += ["", "Routine focus calls, wrist transitions and individual pulse submissions are summarized above; --detail includes them in the timeline.", "",
            "## Coverage cautions", ""]
    if not rows:
        warnings.append("No valid events in the requested window. No incident outcome can be inferred.")
    for warning in warnings:
        out.append("- " + safe(warning))
    if not warnings:
        out.append("- No parsing/ordering warnings. This does not establish complete capture.")
    ordered = sorted({r["date"] for r in rows})
    gaps = [(a, b) for a, b in zip(ordered, ordered[1:]) if (b - a).total_seconds() >= 300]
    for a, b in gaps[:5]:
        out.append(f"- No recorded events between {stamp(a)} and {stamp(b)} ({int((b-a).total_seconds())}s). Quiet time, retention or missing callbacks are possible; no cause inferred.")
    if len(gaps) > 5:
        out.append(f"- {len(gaps)-5} additional quiet intervals of at least five minutes; narrow the window for detail.")
    out += ["", "## Input fingerprints", ""]
    out += [f"- {safe(s['name'])}: {s.get('bytes', 0)} bytes; SHA-256 {s.get('sha256', 'unavailable')}." for s in sources]
    return "\n".join(out) + "\n", bool(rows)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", type=Path, nargs="+", help="One directory with canonical journal names, or explicit prefixed journal files")
    parser.add_argument("--timezone", default="UTC", help="IANA zone, e.g. America/Los_Angeles (default UTC)")
    parser.add_argument("--start", type=date, help="Inclusive ISO timestamp with Z or explicit offset")
    parser.add_argument("--end", type=date, help="Inclusive ISO timestamp with Z or explicit offset")
    parser.add_argument("--limit", type=int, default=120)
    parser.add_argument("--detail", action="store_true")
    parser.add_argument("--output", type=Path, help="New private Markdown file; otherwise stdout")
    args = parser.parse_args(argv)
    if args.limit < 1 or args.limit > 10000:
        parser.error("--limit must be 1–10000")
    os.umask(0o077)
    try:
        if len(args.inputs) == 1 and args.inputs[0].is_dir():
            paths = [args.inputs[0] / (kind + ".json") for kind in KINDS]
        else:
            paths = args.inputs
        report, has_events = summarize(paths, args.timezone, args.start, args.end, args.limit, args.detail)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            with args.output.open("x") as file:
                file.write(report)
            print(f"Local summary saved: {args.output}")
        else:
            print(report, end="")
        return 0 if has_events else 2
    except (OSError, ValueError, ZoneInfoNotFoundError) as error:
        print(f"Summary not completed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
