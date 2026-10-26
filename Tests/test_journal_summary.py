# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import journal_summary as js


def event(name, second=0, **details):
    return {"timestamp": f"2026-10-26T20:00:{second:02d}Z", "event": name, "details": details}


class SummaryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.paths = [self.root / (kind + ".json") for kind in js.KINDS]
        for path in self.paths:
            path.write_text("[]")

    def write(self, index, events):
        self.paths[index].write_text(json.dumps(events))

    def test_correlated_timeline_and_limits_not_invented_outcomes(self):
        self.write(0, [event("app_launched", launchID="launch", build="17", revision="abc"),
                       event("runtime_started", 1, runtimeID="run", intentClassID="2026-10-26T20:00:01Z", phase="running", savedRuntimeIntent="running", launchID="launch"),
                       event("page_selection_changed", 2, previousPage="classProgress", selectedPage="nowPlaying"),
                       event("media_reload_requested", 3, failureDetected="unobserved"),
                       event("runtime_invalidated", 4, runtimeID="run", reason="resigned_frontmost", reasonCode="3", stopRequested="false", phase="interrupted")])
        self.write(1, [event("scene_state_changed", 2, previousSceneState="active", sceneState="inactive")])
        self.write(2, [event("landmark_started", runID="count"),
                       event("haptic_submitted", 1, runID="count", kind="ack"),
                       event("haptic_submitted", 10, runID="count", kind="landmark", lateness="0.8"),
                       event("landmark_pulse_late", 10, runID="count"),
                       event("landmark_group_skipped", 20, runID="count")])
        report, valid = js.summarize(self.paths, "America/Los_Angeles")
        self.assertTrue(valid)
        for expected in ["build 17", "resigned_frontmost, raw reason 3", "2026-10-26T13:00:04-07:00",
                         "1 timing submissions + 1 acknowledgements", "0.800s", "1 skipped-group notices",
                         "no end callback in window; outcome unknown", "not the scheduled start",
                         "not a detected failure", "phone volume", "Source rows"]:
            self.assertIn(expected, report)
        self.assertNotIn("recovery succeeded", report)

    def test_window_build_lookup_uses_matching_launch_outside_window(self):
        self.write(0, [event("app_launched", build="16", launchID="unrelated"),
                       event("app_launched", 1, build="17", launchID="match"),
                       event("page_selection_changed", 15, launchID="match")])
        report, _ = js.summarize(self.paths, start=js.date("2026-10-26T20:00:10Z"), end=js.date("2026-10-26T20:00:20Z"))
        self.assertIn("build 17", report)
        self.assertNotIn("build 16", report)
        self.assertIn("Selected events: 1", report)

    def test_unknown_build_and_schedule_are_not_inferred(self):
        self.write(0, [event("runtime_started", runtimeID="r", phase="running", intentClassID="2026-10-26T20:00:00Z")])
        report, _ = js.summarize(self.paths)
        self.assertIn("Build unknown", report)
        self.assertIn("schedule absent", report)
        self.assertIn("No invalidation callback", report)
        self.assertIn("eventual outcome are unknown", report)

    def test_backward_clock_warning_and_last_state_in_file_order(self):
        self.write(0, [event("runtime_started", 20, runtimeID="r", phase="running"),
                       event("scene_state_changed", 10, runtimeID="r", phase="stopped")])
        report, _ = js.summarize(self.paths)
        self.assertIn("timestamp moved backward", report)
        self.assertIn("last recorded phase stopped", report)

    def test_empty_missing_and_corrupt_journals_do_not_crash(self):
        self.paths[0].unlink()
        self.paths[1].write_text("not json")
        report, valid = js.summarize(self.paths)
        self.assertFalse(valid)
        self.assertIn("unreadable/missing", report)
        self.assertIn("No incident outcome can be inferred", report)

    def test_bad_row_skipped_and_original_unchanged(self):
        self.write(0, [event("app_launched", build="17"), {"event": "bad", "timestamp": "bad", "details": {}}])
        original = self.paths[0].read_bytes()
        report, valid = js.summarize(self.paths)
        self.assertTrue(valid)
        self.assertIn("row 2: malformed", report)
        self.assertEqual(self.paths[0].read_bytes(), original)

    def test_partial_focus_request_is_not_classified_as_failed(self):
        self.write(0, [event("volume_focus_requested", controlID="v", requestID="req"),
                       event("volume_focus_requested", 1, controlID="v", requestID="req2"),
                       event("volume_focus_call_skipped", 2, controlID="v", requestID="req2")])
        report, _ = js.summarize(self.paths)
        self.assertIn("1 requests without a terminal record", report)
        self.assertIn("Actual focus remains unobserved", report)
        self.assertNotIn("focus failed", report)

    def test_cap_and_recovery_are_cautions_not_proof_of_loss(self):
        self.write(0, [event("journal_recovered")] + [event("page_appeared")] * 999)
        report, _ = js.summarize(self.paths, limit=2)
        self.assertIn("possible earlier eviction, not proven", report)
        self.assertIn("corrupt-file backup", report)
        self.assertIn("limited to 2 of 1000", report)

    def test_detailed_timeline_keeps_pulses_compact_timeline_does_not(self):
        self.write(2, [event("haptic_submitted", runID="r", kind="landmark", lateness="nan")])
        compact, _ = js.summarize(self.paths)
        detailed, _ = js.summarize(self.paths, detail=True)
        self.assertNotIn("| haptic_submitted |", compact)
        self.assertIn("| haptic_submitted |", detailed)
        self.assertIn("max submitted lateness unknown", detailed)

    def test_reject_mixed_snapshots_of_same_kind(self):
        copy = self.root / "after-RuntimeDiagnostics.json"
        copy.write_text("[]")
        with self.assertRaises(ValueError):
            js.summarize([self.paths[0], copy])

    def test_offset_required_and_window_checked(self):
        with self.assertRaises(ValueError):
            js.date("2026-10-26T20:00:00")
        with self.assertRaises(ValueError):
            js.summarize(self.paths, start=js.date("2026-10-27T00:00:00Z"), end=js.date("2026-10-26T00:00:00Z"))

    def test_dst_offset_is_explicit(self):
        self.write(0, [{"timestamp": "2026-11-01T08:30:00Z", "event": "page_appeared", "details": {}},
                       {"timestamp": "2026-11-01T09:30:00Z", "event": "page_appeared", "details": {}}])
        report, _ = js.summarize(self.paths, "America/Los_Angeles")
        self.assertIn("2026-11-01T01:30:00-07:00", report)
        self.assertIn("2026-11-01T01:30:00-08:00", report)
        self.assertIn("Quiet time, retention or missing callbacks", report)

    def test_output_cannot_overwrite_input_or_existing_evidence(self):
        self.write(0, [event("app_launched")])
        original = self.paths[0].read_bytes()
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(js.main([str(self.root), "--output", str(self.paths[0])]), 2)
        self.assertEqual(self.paths[0].read_bytes(), original)

    def test_values_are_not_rendered_as_raw_html_or_table_columns(self):
        self.write(0, [event("runtime_invalidated", runtimeID="r", reason="<script>x</script>|\nnext")])
        report, _ = js.summarize(self.paths)
        self.assertNotIn("<script>", report)
        self.assertIn("&lt;script&gt;", report)
        self.assertIn("\\|", report)


if __name__ == "__main__":
    unittest.main()
