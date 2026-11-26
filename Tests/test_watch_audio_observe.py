# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Offline observer checks. No test invokes simctl or changes a Simulator."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "tools/watch-audio-probe/observe.py"
SPEC = importlib.util.spec_from_file_location("watch_audio_observe", SOURCE)
observe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(observe)


def sample(position, **changes):
    row = {"playerCurrentTime": position, "monotonicExpectedPosition": position,
           "playing": True, "runID": "one-process", "metadataPublishCount": 2}
    row.update(changes)
    return row


class PlayerGateTests(unittest.TestCase):
    def test_actual_player_advances_with_unchanged_sparse_metadata(self):
        self.assertEqual(observe.player_gate([sample(30), sample(40), sample(50)]), [])

    def test_monotonic_estimate_and_device_clock_cannot_replace_actual_progress(self):
        rows = [sample(30, monotonicExpectedPosition=30, playerDeviceCurrentTime=900),
                sample(30, monotonicExpectedPosition=40, playerDeviceCurrentTime=910)]
        self.assertIn("Actual player time did not advance between every frame", observe.player_gate(rows))

    def test_backward_or_repeated_actual_position_fails(self):
        for end in (29, 30):
            with self.subTest(end=end):
                self.assertTrue(observe.player_gate([sample(30), sample(end)]))

    def test_sparse_metadata_change_is_not_accepted_as_extrapolation(self):
        rows = [sample(30), sample(40, metadataPublishCount=3)]
        self.assertIn("Sparse comparison received additional metadata submissions", observe.player_gate(rows))
        self.assertEqual(observe.player_gate(rows, frequent=True), [])

    def test_not_playing_and_cross_run_fail_even_with_advancing_positions(self):
        self.assertIn("Player not reported playing at every sample", observe.player_gate([sample(30), sample(40, playing=False)]))
        self.assertIn("Samples do not identify one source process run", observe.player_gate([sample(30), sample(40, runID="new-process")]))
        self.assertIn("Samples do not identify one source process run", observe.player_gate([sample(30, runID=None), sample(40, runID=None)]))

    def test_truthy_nonboolean_playing_is_not_actual_player_evidence(self):
        self.assertIn("Player not reported playing at every sample", observe.player_gate([sample(30), sample(40, playing="false")]))

    def test_missing_nonfinite_or_wrong_typed_player_time_fails_closed(self):
        for bad in (None, float("nan"), float("inf"), -1, "40", True):
            with self.subTest(bad=bad):
                self.assertIn("Missing or invalid actual player time", observe.player_gate([sample(30), sample(bad)]))

    def test_missing_or_invalid_metadata_counts_fail_in_both_modes(self):
        for bad in (None, 0, -1, "2", True):
            for frequent in (False, True):
                with self.subTest(bad=bad, frequent=frequent):
                    self.assertIn("Missing or invalid metadata submission count", observe.player_gate([sample(30, metadataPublishCount=bad), sample(40, metadataPublishCount=bad)], frequent))

    def test_one_sample_cannot_establish_progress(self):
        self.assertTrue(observe.player_gate([]))
        self.assertTrue(observe.player_gate([sample(30)]))


class PlanAndGuardTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        (self.root / "work").mkdir()
        self.root_patch = patch.object(observe, "ROOT", self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        old_mask = os.umask(0o077)
        self.addCleanup(os.umask, old_mask)

    def invoke(self, *arguments):
        with patch.object(sys, "argv", ["observe.py", *map(str, arguments)]), contextlib.redirect_stdout(io.StringIO()):
            return observe.main()

    def test_default_only_writes_plan_and_never_queries_or_controls_devices(self):
        output = self.root / "work/plan"
        with patch.object(observe, "checked", side_effect=AssertionError("No device commands in default mode")) as command:
            self.assertEqual(self.invoke("--simulator", "plan-placeholder", "--output", output, "--session-api"), 0)
        command.assert_not_called()
        plan = json.loads((output / "observation.json").read_text())
        self.assertFalse(plan["executeRequested"])
        self.assertEqual(plan["sourceBundle"], observe.BUNDLE)
        self.assertEqual(plan["hostBundle"], observe.BUNDLE)
        self.assertIn("--session-api", plan["sourceFlags"])
        self.assertEqual(plan["nativeProgressResult"], "unverified_visual_review_required")
        self.assertEqual(plan["frames"], [])
        self.assertNotIn("playerGatePassed", plan)
        self.assertEqual(output.stat().st_mode & 0o777, 0o700)

    def test_output_must_be_new_and_under_this_checkouts_work(self):
        existing = self.root / "work/existing"
        existing.mkdir()
        marker = existing / "evidence"
        marker.write_text("keep")
        for invalid in (existing, self.root / "outside", self.root / "work/../escape"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                observe.new_output(invalid)
        self.assertEqual(marker.read_text(), "keep")
        self.assertFalse((self.root / "outside").exists())
        self.assertFalse((self.root / "escape").exists())

    def test_output_rejects_symlink_parent_and_symlink_destination(self):
        real = self.root / "work/real"
        real.mkdir()
        alias = self.root / "work/alias"
        alias.symlink_to(real, target_is_directory=True)
        dangling = self.root / "work/dangling"
        dangling.symlink_to(real / "absent")
        for invalid in (alias / "child", dangling):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                observe.new_output(invalid)
        self.assertFalse((real / "child").exists())
        self.assertFalse((real / "absent").exists())

    def test_invalid_host_and_nonfinite_seek_are_rejected_before_plan_creation(self):
        for extra in (("--host", "arbitrary-app"), ("--seek-seconds", "nan"), ("--seek-seconds", "inf")):
            with self.subTest(extra=extra), patch.object(observe, "checked", side_effect=AssertionError("No device commands")), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                self.invoke("--simulator", "unused", "--output", self.root / "work/rejected", *extra)
        self.assertFalse((self.root / "work/rejected").exists())

    def test_execute_rejects_nonregression_watch_before_launch(self):
        inventory = {"devices": {"runtime": [{"udid": "watch", "state": "Booted", "name": "Personal Watch", "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-SE-3"}]}}
        with patch.object(observe, "checked", return_value=json.dumps(inventory)) as command:
            self.assertEqual(self.invoke("--simulator", "watch", "--output", self.root / "work/blocked", "--execute"), 2)
        command.assert_called_once_with("xcrun", "simctl", "list", "devices", "--json")
        plan = json.loads((self.root / "work/blocked/observation.json").read_text())
        self.assertIn("booted disposable Watch", plan["error"])
        self.assertEqual(plan["frames"], [])

    def test_ambiguous_launch_timeout_still_attempts_only_fixture_cleanup(self):
        app = self.root / "installed-app"
        app.mkdir(); (app / "WatchAudioProbe").write_bytes(b"synthetic executable")
        container = self.root / "installed-data"
        container.mkdir()
        inventory = {"devices": {"runtime": [{"udid": "watch", "state": "Booted", "name": "TeachingTimer Regression Test", "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-SE-3"}]}}

        def fake_command(*args, **kwargs):
            if args[2:4] == ("list", "devices"):
                return json.dumps(inventory)
            if args[2] == "get_app_container":
                return str(app if args[-1] == "app" else container)
            if args[2] == "launch":
                raise subprocess.TimeoutExpired(args, 20)
            if args[2] == "terminate":
                return ""
            self.fail(f"Unexpected command: {args}")

        with patch.object(observe, "checked", side_effect=fake_command) as command:
            self.assertEqual(self.invoke("--simulator", "watch", "--output", self.root / "work/timeout", "--execute"), 2)
        self.assertEqual(command.call_args.args, ("xcrun", "simctl", "terminate", "watch", observe.BUNDLE))
        plan = json.loads((self.root / "work/timeout/observation.json").read_text())
        self.assertTrue(plan["sourceStopped"])
        self.assertEqual(plan["frames"], [])


if __name__ == "__main__":
    unittest.main()
