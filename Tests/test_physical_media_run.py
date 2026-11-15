# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

from concurrent.futures import ThreadPoolExecutor
import contextlib
from datetime import datetime
import importlib.util
import io
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/physical-media-run.py"
SPEC = importlib.util.spec_from_file_location("physical_media_run", SCRIPT)
pmr = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pmr)


class PhysicalMediaRunTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / "repository"
        (self.repo / "work").mkdir(parents=True)
        self.run = self.repo / "work" / "supervised-run"
        self.calls = []
        self.ignored = True
        previous_umask = os.umask(0o077)
        self.addCleanup(os.umask, previous_umask)
        for name, replacement in (("repository", lambda: self.repo),):
            mock = patch.object(pmr, name, replacement)
            mock.start()
            self.addCleanup(mock.stop)
        mock = patch.object(pmr.subprocess, "run", self.local_service)
        mock.start()
        self.addCleanup(mock.stop)

    def local_service(self, argv, **kwargs):
        """Reject everything except the fixed, local-only metadata commands."""
        self.calls.append(argv)
        allowed = (["git", "rev-parse", "HEAD"],
                   ["git", "status", "--short", "--untracked-files=no"],
                   ["xcodebuild", "-version"], ["xcode-select", "-p"],
                   ["xcrun", "--find", "devicectl"])
        if argv[:4] == ["git", "check-ignore", "--quiet", "--"]:
            return subprocess.CompletedProcess(argv, 0 if self.ignored else 1, "", "")
        if argv not in allowed:
            raise AssertionError("Unexpected command, potentially contacting a device: " + repr(argv))
        answers = {"repo": "a" * 40, "xcode": "Xcode fixture\nBuild fixture"}
        text = answers["repo"] if argv[:2] == ["git", "rev-parse"] else answers["xcode"]
        return subprocess.CompletedProcess(argv, 0, text, "")

    def invoke(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = pmr.main(list(map(str, argv)))
        return code, out.getvalue(), err.getvalue()

    def prepare(self, *extra):
        result = self.invoke("prepare", "--output", self.run, "--arm", "retained native control",
                             "--source", "operator-selected player", "--route", "unconfirmed",
                             "--order", "playback-before-class", *extra)
        self.assertEqual(result[0], 0, result[2])
        return json.loads((self.run / "run.json").read_text())

    def test_prepare_is_local_only_and_generated_captures_are_not_run(self):
        manifest = self.prepare()
        self.assertEqual(manifest["localMetadata"]["repoSHA"]["stdout"], "a" * 40)
        self.assertEqual(manifest["plan"]["playbackClassOrder"], "playback-before-class")
        self.assertFalse(manifest["deviceOperationsExecuted"])
        self.assertEqual(self.run.stat().st_mode & 0o777, 0o700)
        commands = json.loads((self.run / "next-commands.json").read_text())
        self.assertFalse(commands["executed"])
        self.assertTrue(commands["requiresSeparateSupervisedExecution"])
        self.assertEqual(len(commands["placeholders"]), 2)
        journals = [c for c in commands["commands"] if "journals" in c["stage"]]
        self.assertEqual({item["stage"] for item in journals},
                         {"watch-journals-before", "watch-journals-failure", "watch-journals-after"})
        failure = next(item["argv"] for item in journals if item["stage"] == "watch-journals-failure")
        self.assertEqual(failure[failure.index("--timeout") + 1], "8")
        self.assertEqual(failure[failure.index("--budget") + 1], "30")
        for command in journals:
            argv = command["argv"]
            self.assertIn("journals", argv)
            self.assertNotIn("install", argv)
            self.assertNotIn("--launch", argv)
            output = Path(argv[argv.index("--output") + 1])
            self.assertFalse(output.exists(), "watch_device.py requires a NEW capture directory")
        self.assertIn("no device operation has run", (self.run / "NEXT.md").read_text())
        self.assertEqual(len(self.calls), 6)

    def test_catalog_covers_named_mechanisms_and_specific_counterevidence_without_device_queries(self):
        code, out, error = self.invoke("catalog", "--json")
        self.assertEqual(code, 0, error)
        catalog = json.loads(out)
        mechanisms = {item["hypothesisID"] for item in catalog["scenarios"]}
        self.assertEqual(mechanisms, {"H1", "H2", "H3", "H4", "H5", "H6", "H7"})
        scenarios = {item["id"]: item for item in catalog["scenarios"]}
        self.assertTrue({"phone-volume-change", "source-handoff", "startup-order", "focus-home",
                         "focus-refresh", "wake-timing", "crown-conversion", "host-isolation",
                         "route-feedback", "media-progress"}.issubset(scenarios))
        self.assertIn("first", scenarios["crown-conversion"]["hypothesis"])
        self.assertIn("standalone", " ".join(scenarios["media-progress"]["supports"]))
        self.assertIn("retained", scenarios["phone-volume-change"]["hypothesis"])
        for scenario in scenarios.values():
            for key in ("supports", "weakens", "requiredEvidence", "steps"):
                self.assertTrue(scenario[key], (scenario["id"], key))
            self.assertNotEqual(scenario["supports"], scenario["weakens"])
        self.assertFalse(self.calls)
        self.assertFalse(self.run.exists())

    def test_each_named_protocol_is_embedded_and_rendered_with_unverified_readiness(self):
        for scenario in pmr.scenario_catalog()["scenarios"]:
            with self.subTest(scenario=scenario["id"]):
                run = self.repo / "work" / scenario["id"]
                code, _, error = self.invoke("prepare", "--scenario", scenario["id"], "--output", run)
                self.assertEqual(code, 0, error)
                manifest = json.loads((run / "run.json").read_text())
                rendered = (run / "NEXT.md").read_text()
                experiment = manifest["experiment"]
                self.assertEqual(experiment["scenario"], scenario)
                self.assertFalse(manifest["deviceOperationsExecuted"])
                for key in ("supports", "weakens", "requiredEvidence", "steps"):
                    for expected in scenario[key]:
                        self.assertIn(expected, rendered)
                self.assertIn("all unverified until the supervised session", rendered)
                self.assertIn("not a physical input driver", rendered)
                self.assertNotIn("test passed", rendered.lower())

    def test_scenario_defaults_and_overrides_do_not_invent_observed_device_state(self):
        code, _, error = self.invoke("prepare", "--scenario", "phone-volume-change", "--output", self.run,
                                     "--source", "available Amazon Music", "--route", "verified later",
                                     "--minutes", "2", "--build", "operator will read")
        self.assertEqual(code, 0, error)
        manifest = json.loads((self.run / "run.json").read_text())
        self.assertEqual(manifest["plan"]["source"], "available Amazon Music")
        self.assertEqual(manifest["plan"]["route"], "verified later")
        self.assertEqual(manifest["plan"]["durationMinutes"], 2)
        self.assertEqual(manifest["plan"]["bundle"], "net.qays.TeachingTimer.watchkitapp")
        self.assertFalse(manifest["deviceOperationsExecuted"])
        events = [json.loads(line) for line in (self.run / "events.ndjson").read_text().splitlines()]
        self.assertEqual([row["event"] for row in events], ["prepared"])

    def test_unknown_or_incomplete_hypothesis_fails_before_metadata_or_output(self):
        code, _, error = self.invoke("prepare", "--scenario", "not-a-protocol", "--output", self.run)
        self.assertEqual(code, 2)
        self.assertIn("Unknown scenario", error)
        self.assertFalse(self.calls)
        self.assertFalse(self.run.exists())
        broken = pmr.scenario_catalog()
        broken["scenarios"][0]["weakens"] = []
        path = Path(self.temp.name) / "broken.json"
        path.write_text(json.dumps(broken))
        with patch.object(pmr, "CATALOG", path):
            code, _, error = self.invoke("prepare", "--scenario", "retained-idle", "--output", self.run)
        self.assertEqual(code, 2)
        self.assertIn("counterevidence", error)
        self.assertFalse(self.calls)
        self.assertFalse(self.run.exists())

    def test_duplicate_scenario_ids_fail_instead_of_selecting_an_ambiguous_protocol(self):
        catalog = pmr.scenario_catalog()
        catalog["scenarios"].append(catalog["scenarios"][0])
        path = Path(self.temp.name) / "duplicate.json"
        path.write_text(json.dumps(catalog))
        with patch.object(pmr, "CATALOG", path):
            code, _, error = self.invoke("catalog")
        self.assertEqual(code, 2)
        self.assertIn("Duplicate", error)
        self.assertFalse(self.calls)

    def test_future_app_open_commands_are_separate_argv_and_do_not_start_playback(self):
        self.invoke("prepare", "--scenario", "source-handoff", "--output", self.run)
        commands = json.loads((self.run / "next-commands.json").read_text())
        named = {item["stage"]: item for item in commands["commands"]}
        self.assertIn("apps", named["phone-app-inventory"]["argv"])
        self.assertEqual(named["open-phone-apple-music"]["argv"][-1], "com.apple.Music")
        self.assertEqual(named["open-watch-timer"]["argv"][-1], "net.qays.TeachingTimer.watchkitapp")
        self.assertNotIn("--terminate-existing", named["open-watch-timer"]["argv"])
        self.assertIn("does not prove playback", named["open-phone-apple-music"]["condition"])
        self.assertFalse(commands["executed"])
        self.assertFalse(any("device" in call or "simctl" in call for call in self.calls))

    def test_incident_captures_have_separate_targets_and_uncertainty_instructions(self):
        self.prepare("--watch", "chosen-watch", "--phone", "chosen-phone")
        commands = json.loads((self.run / "next-commands.json").read_text())
        for kind in ("watch", "phone"):
            item = next(c for c in commands["commands"] if c["stage"] == kind + "-sysdiagnose-on-incident")
            argv = item["argv"]
            self.assertEqual(argv[argv.index("--device") + 1], "chosen-" + kind)
            self.assertEqual(Path(argv[argv.index("--destination") + 1]), (self.run / "captures" / (kind + "-sysdiagnose")).resolve())
            self.assertIn("timeout may leave capture running", item["condition"])
            self.assertNotIn("sudo", argv)
        self.assertFalse(commands["executed"])
        self.assertFalse(any("device" in call or "simctl" in call for call in self.calls))

    def test_exploratory_runs_cannot_be_assessed_as_specified_hypothesis_tests(self):
        self.prepare()
        self.assertIn("exploratory notebook", (self.run / "NEXT.md").read_text())
        before = (self.run / "events.ndjson").read_bytes()
        code, _, error = self.invoke("assess", "--run", self.run, "--result", "supports",
                                     "--note", "unsupported interpretation", "--evidence", "pending.mov")
        self.assertEqual(code, 2)
        self.assertIn("no selected hypothesis", error)
        self.assertEqual(before, (self.run / "events.ndjson").read_bytes())

    def test_assessment_retains_inconclusive_and_does_not_infer_a_pass_from_clean_marks(self):
        self.invoke("prepare", "--scenario", "focus-home", "--output", self.run)
        calls = list(self.calls)
        for event in ("run_started", "crown_input", "audio_stopped", "run_stopped"):
            extra = ("--intent", "increase", "--magnitude", "one small turn") if event == "crown_input" else ()
            self.assertEqual(self.invoke("mark", "--run", self.run, "--event", event, *extra)[0], 0)
        code, output, error = self.invoke("summary", "--run", self.run, "--json")
        self.assertEqual(code, 0, error)
        summary = json.loads(output)
        self.assertEqual(summary["operatorAssessments"], [])
        self.assertIn("not automatically established", summary["testOutcome"])
        code, output, error = self.invoke("assess", "--run", self.run, "--result", "inconclusive",
            "--note", "Native request records missing", "--deviation", "Control identity unknown")
        self.assertEqual(code, 0, error)
        fields = json.loads(output)["fields"]
        self.assertEqual(fields["result"], "inconclusive")
        self.assertIn("not independently validated", fields["source"])
        self.assertEqual(fields["hypothesisID"], "H3")
        self.assertEqual(fields["deviations"], ["Control identity unknown"])
        self.assertEqual(self.calls, calls)

    def test_interpreted_results_require_rationale_and_references_but_never_validate_them(self):
        self.invoke("prepare", "--scenario", "crown-conversion", "--output", self.run)
        original = (self.run / "events.ndjson").read_bytes()
        for result, note in (("supports", "Native value observed"), ("weakens", "Normal turn"), ("mixed", "Mixed results"),
                             ("inconclusive", " ")):
            code, _, _ = self.invoke("assess", "--run", self.run, "--result", result, "--note", note)
            self.assertEqual(code, 2)
            self.assertEqual(original, (self.run / "events.ndjson").read_bytes())
        code, _, error = self.invoke("assess", "--run", self.run, "--result", "supports",
            "--note", "A claim with no named evidence", "--evidence", " ")
        self.assertEqual(code, 2)
        self.assertIn("blank", error)
        self.assertEqual(original, (self.run / "events.ndjson").read_bytes())
        code, output, error = self.invoke("assess", "--run", self.run, "--result", "supports",
            "--note", "Recorded known up turn versus first request", "--evidence", "snapshots/recording.mov")
        self.assertEqual(code, 0, error)
        fields = json.loads(output)["fields"]
        self.assertEqual(fields["result"], "supports")
        self.assertIn("not copied or validated", fields["evidenceReferences"][0]["validation"])

    def test_supplied_identifiers_are_arguments_not_shell_code(self):
        identifier = "Operator's Watch; $(this-is-not-executed)"
        self.prepare("--watch", identifier, "--phone", "Operator phone")
        commands = json.loads((self.run / "next-commands.json").read_text())
        self.assertEqual(commands["placeholders"], [])
        first = commands["commands"][0]["argv"]
        self.assertEqual(first[first.index("--device") + 1], identifier)
        self.assertEqual(shlex.split(shlex.join(first)), first)

    def test_existing_run_is_not_overwritten_or_queried_again(self):
        self.prepare()
        original = (self.run / "run.json").read_bytes()
        calls = list(self.calls)
        code, _, error = self.invoke("prepare", "--output", self.run, "--arm", "second",
                                     "--source", "player", "--route", "speaker",
                                     "--order", "class-before-playback")
        self.assertEqual(code, 2)
        self.assertIn("already exists", error)
        self.assertEqual((self.run / "run.json").read_bytes(), original)
        self.assertEqual(self.calls, calls)

    def test_output_escape_and_symlink_escape_fail_before_queries(self):
        outside = Path(self.temp.name) / "outside"
        outside.mkdir()
        (self.repo / "work" / "escape").symlink_to(outside, target_is_directory=True)
        for output in (outside / "direct", self.repo / "work" / "escape" / "indirect"):
            code, _, _ = self.invoke("prepare", "--output", output, "--arm", "arm",
                                     "--source", "player", "--route", "speaker",
                                     "--order", "class-before-playback")
            self.assertEqual(code, 2)
            self.assertFalse(output.exists())
        self.assertFalse(self.calls)

    def test_unconfirmed_git_ignore_fails_without_creating_run(self):
        self.ignored = False
        code, _, error = self.invoke("prepare", "--output", self.run, "--arm", "arm",
                                     "--source", "player", "--route", "speaker",
                                     "--order", "class-before-playback")
        self.assertEqual(code, 2)
        self.assertIn("Git-ignored", error)
        self.assertFalse(self.run.exists())
        self.assertEqual(len(self.calls), 1)

    def test_crown_mark_requires_operator_intent_and_magnitude_and_keeps_clocks(self):
        self.prepare()
        calls = list(self.calls)
        before = (self.run / "events.ndjson").read_bytes()
        code, _, error = self.invoke("mark", "--run", self.run, "--event", "crown_input",
                                     "--intent", "increase")
        self.assertEqual(code, 2)
        self.assertIn("--magnitude", error)
        self.assertEqual((self.run / "events.ndjson").read_bytes(), before)
        code, out, _ = self.invoke("mark", "--run", self.run, "--event", "crown_input",
                                   "--intent", "increase", "--direction", "unknown",
                                   "--magnitude", "one small turn; angle unmeasured")
        self.assertEqual(code, 0)
        event = json.loads(out)
        self.assertEqual(event["fields"]["intent"], "increase")
        self.assertEqual(event["fields"]["direction"], "unknown")
        self.assertIn("angle unmeasured", event["fields"]["magnitude"])
        self.assertEqual(datetime.fromisoformat(event["wallUTC"]).timestamp(),
                         datetime.fromisoformat(event["wallPacific"]).timestamp())
        self.assertIsInstance(event["hostMonotonicNanoseconds"], int)
        self.assertIn(event["pacificZone"], ("PST", "PDT"))
        self.assertEqual(self.calls, calls)

    def test_incident_and_summary_keep_intent_outcome_and_evidence_separate(self):
        self.prepare()
        calls = list(self.calls)
        for event in ("run_started", "playback_started", "class_started"):
            self.assertEqual(self.invoke("mark", "--run", self.run, "--event", event)[0], 0)
        self.assertEqual(self.invoke("mark", "--run", self.run, "--event", "incident",
                                    "--note", "ring appeared zero", "--observed", "audio outcome unconfirmed",
                                    "--evidence", "snapshots/pending.mov")[0], 0)
        before = {p.name: p.read_bytes() for p in self.run.iterdir() if p.is_file()}
        code, text, _ = self.invoke("summary", "--run", self.run, "--json")
        self.assertEqual(code, 0)
        result = json.loads(text)
        self.assertEqual(result["operatorMarkedOrder"], "playback-before-class")
        self.assertFalse(result["audioStoppedMarked"])
        self.assertFalse(result["deviceOperationsExecutedByHelper"])
        fields = result["events"][-1]["fields"]
        self.assertEqual(fields["observed"], "audio outcome unconfirmed")
        self.assertIn("not copied or validated", fields["evidenceReferences"][0]["validation"])
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.run.iterdir() if p.is_file()})
        self.assertEqual(self.calls, calls)

    def test_damaged_event_tail_is_preserved(self):
        self.prepare()
        path = self.run / "events.ndjson"
        damaged = path.read_bytes().rstrip(b"\n")
        path.write_bytes(damaged)
        code, _, error = self.invoke("mark", "--run", self.run, "--event", "note")
        self.assertEqual(code, 2)
        self.assertIn("incomplete tail", error)
        self.assertEqual(path.read_bytes(), damaged)

    def test_simultaneous_marks_do_not_lose_or_duplicate_events(self):
        self.prepare()
        with ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda number: pmr.append_event(self.run, "note", {"operatorMark": number}), range(12)))
        rows = [json.loads(line) for line in (self.run / "events.ndjson").read_text().splitlines()]
        self.assertEqual([row["sequence"] for row in rows], list(range(1, 14)))
        self.assertEqual({row["fields"]["operatorMark"] for row in rows[1:]}, set(range(12)))


if __name__ == "__main__":
    unittest.main()
