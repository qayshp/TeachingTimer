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
        self.assertEqual(len(journals), 2)
        for command in journals:
            argv = command["argv"]
            self.assertIn("journals", argv)
            self.assertNotIn("install", argv)
            self.assertNotIn("--launch", argv)
            output = Path(argv[argv.index("--output") + 1])
            self.assertFalse(output.exists(), "watch_device.py requires a NEW capture directory")
        self.assertIn("no device operation has run", (self.run / "NEXT.md").read_text())
        self.assertEqual(len(self.calls), 6)

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
