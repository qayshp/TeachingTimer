# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import importlib.util
import contextlib
import io
import json
from pathlib import Path
import plistlib
import shutil
import struct
import subprocess
import tempfile
import unittest
import uuid
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("native_state_lab", ROOT / "tools/watch-media-lab/native-state.py")
lab = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lab)
CAL_SPEC = importlib.util.spec_from_file_location("crown_calibration_lab", ROOT / "tools/watch-media-lab/analyze-calibration.py")
calibration = importlib.util.module_from_spec(CAL_SPEC)
CAL_SPEC.loader.exec_module(calibration)
RUN_SPEC = importlib.util.spec_from_file_location("crown_calibration_run", ROOT / "tools/watch-media-lab/calibrate.py")
calibrator = importlib.util.module_from_spec(RUN_SPEC)
RUN_SPEC.loader.exec_module(calibrator)


def macho(platform=9):
    return struct.pack("<IIIIIIII", 0xFEEDFACF, 0x100000C, 0, 2, 1, 24, 0, 0) + struct.pack("<IIIIII", 0x32, 24, platform, 0, 0, 0)


def arm_rows(revision, arm, view="synthetic-view", controller="synthetic-controller"):
    return [{"revision": revision, "label": arm["label"], "event": "command_applied",
             "feedback": False, "available": arm["available"],
             "notify": arm["notify"], "modelVolume": arm["volume"]},
            {"revision": revision, "event": "native_state_changed", "nativeViews": [{
                "view": view, "controller": controller,
                **dict(zip(("nativeModel", "viewValue", "sequencerOffset"), arm["expected"]))}]}]


class WatchMediaLabTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.identifier = str(uuid.uuid4()).upper()  # Deliberately synthetic test ID.

    def fixture(self, identifier=lab.BUNDLE, platform=9):
        app = self.root / "NativeVolumeProbe.app"
        app.mkdir()
        (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": identifier,
                                                       "CFBundleExecutable": lab.EXECUTABLE}))
        (app / lab.EXECUTABLE).write_bytes(macho(platform))
        hook = self.root / "NativeBaselineHook.dylib"
        hook.write_bytes(macho())
        return app, hook

    def test_artifact_guard_accepts_only_fixture_watch_simulator(self):
        app, hook = self.fixture()
        self.assertEqual(lab.validate_artifacts(app, hook), (app.resolve(), hook.resolve()))
        for platform in (4, 7, 8):
            (app / lab.EXECUTABLE).write_bytes(macho(platform))
            with self.assertRaisesRegex(ValueError, "not exclusively watchOS Simulator"):
                lab.validate_artifacts(app, hook)

    def test_production_identity_is_rejected_before_any_command(self):
        app, hook = self.fixture("com.qayshp.TeachingTimer")
        with patch.object(lab.subprocess, "run", side_effect=AssertionError("No tool should execute")):
            with self.assertRaisesRegex(ValueError, "TeachingTimer is forbidden"):
                lab.validate_artifacts(app, hook)

    def test_corrupt_macho_and_universal_or_unknown_platform_fail_closed(self):
        file = self.root / "binary"
        for data in (b"not a Mach-O", struct.pack("<I", 0xCAFEBABE) + b"\0" * 50,
                     macho()[:-3], macho()[:32] + struct.pack("<II", 0x32, 0) + b"\0" * 16):
            file.write_bytes(data)
            with self.assertRaises(ValueError):
                lab.watch_simulator_macho(file)

    def test_explicit_uuid_and_live_booted_watch_are_required(self):
        for alias in ("booted", "all", "", "not-a-device"):
            with self.assertRaises(ValueError):
                lab.canonical_uuid(alias)
        self.assertEqual(lab.canonical_uuid(self.identifier.lower()), self.identifier)
        device = {"udid": self.identifier, "state": "Booted", "isAvailable": True,
                  "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Unit-Test"}
        runtime = "com.apple.CoreSimulator.SimRuntime.watchOS-Synthetic"
        inventory = {"devices": {runtime: [device]}}
        self.assertEqual(lab.booted_watch(inventory, self.identifier)["udid"], self.identifier)
        for changed in ({"state": "Shutdown"}, {"isAvailable": False},
                        {"deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-Unit-Test"}):
            with self.assertRaises(ValueError):
                lab.booted_watch({"devices": {runtime: [{**device, **changed}]}}, self.identifier)
        with self.assertRaises(ValueError):
            lab.booted_watch({"devices": {runtime: [device, device]}}, self.identifier)

    def test_eight_arm_oracle_checks_getter_view_offset_and_same_identity(self):
        self.assertEqual(len(lab.ARMS), 8)
        rows = []
        identity = None
        for revision, arm in enumerate(lab.ARMS, 1):
            rows.extend(arm_rows(revision, arm))
            result = lab.evaluate_arm(rows, revision, arm, identity)
            self.assertEqual(tuple(result["measuredGetterViewSequencer"]), arm["expected"])
            identity = result["identity"]
        # The silent arms must detect real stale inner state, not substitute the getter.
        self.assertEqual(lab.ARMS[1]["expected"], (.625, .25, .25))
        self.assertEqual(lab.ARMS[4]["expected"], (.625, 0, 0))
        self.assertEqual(lab.ARMS[-1]["expected"], (.625, .625, .625))
        changed = arm_rows(8, lab.ARMS[-1], view="different-view")
        with self.assertRaisesRegex(ValueError, "changed between arms"):
            lab.evaluate_arm(changed, 8, lab.ARMS[-1], identity)

    def test_missing_wrong_or_nonfinite_measurement_is_not_a_pass(self):
        arm = lab.ARMS[1]
        for value in (None, "nonfinite", float("nan"), True, .625):
            rows = arm_rows(2, arm)
            rows[-1]["nativeViews"][0]["sequencerOffset"] = value
            with self.assertRaises(ValueError):
                lab.evaluate_arm(rows, 2, arm)
        rows = arm_rows(2, arm)
        rows[-1]["nativeViews"] *= 2
        with self.assertRaises(ValueError):
            lab.evaluate_arm(rows, 2, arm)

    def test_unsupported_abi_completion_exception_and_outgoing_setter_reject(self):
        for event in lab.BAD_EVENTS:
            rows = arm_rows(1, lab.ARMS[0]) + [{"event": event, "revision": 1, "outgoing": 0}]
            with self.assertRaisesRegex(ValueError, "Unsupported fixture"):
                lab.evaluate_arm(rows, 1, lab.ARMS[0])

    def test_partial_journal_append_is_waited_on_without_fabrication(self):
        path = self.root / "journal.jsonl"
        path.write_bytes(b'{"event":"first"}\n{"event":"unfinished"')
        self.assertEqual(lab.journal_rows(path, 0), [{"event": "first"}])
        self.assertEqual(lab.journal_rows(path, len(b'{"event":"first"}\n')), [])

    def test_injection_environment_does_not_leak_to_restoration(self):
        with patch.dict(lab.os.environ, {"SIMCTL_CHILD_DYLD_INSERT_LIBRARIES": "untrusted",
                                        "SIMCTL_CHILD_TT_NATIVE_BASELINE_CAPABILITIES": "override",
                                        "DYLD_INSERT_LIBRARIES": "host-injection", "PATH": "fixture-path"}):
            clean = lab.clean_environment()
        self.assertEqual(clean["PATH"], "fixture-path")
        self.assertFalse(any(key.startswith("SIMCTL_CHILD_") for key in clean))
        self.assertNotIn("DYLD_INSERT_LIBRARIES", clean)

    def test_calibration_parser_retains_subtype_without_claiming_phase(self):
        message = ("Evaluating dispatch of UIEvent: 0x123; type: 7; subtype: 201; backing type: 6; "
                   "tagged context: 0xABC; shouldSend: 1; ignoreInteractionEvents: 0, systemGestureStateChange: 0")
        parsed = calibration.EVALUATION.fullmatch(message)
        self.assertEqual(parsed["subtype"], "201")
        self.assertEqual(parsed["backing"], "6")
        self.assertNotIn("phase", parsed.groupdict())
        self.assertEqual(calibration.timestamp("2026-11-15 00:00:00.000000-0800"),
                         calibration.timestamp("2026-11-15T08:00:00+00:00"))

    def test_cleanup_is_attempted_after_install_failure(self):
        app, hook = self.fixture()
        output = self.root / "run"
        output.mkdir()
        run = lab.Run(output, self.identifier, app, hook, True)
        device = {"udid": self.identifier, "state": "Booted", "isAvailable": True,
                  "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Synthetic"}
        inventory = {"devices": {"watchOS-Synthetic": [device]}}
        stages = []
        def command(stage, arguments, **kwargs):
            stages.append(stage)
            if stage == "inventory":
                return type("Result", (), {"stdout": json.dumps(inventory)})()
            if stage == "install-ordinary-fixture":
                raise RuntimeError("Synthetic install failure")
            return type("Result", (), {"returncode": 0})()
        with patch.object(run, "command", command):
            with self.assertRaisesRegex(RuntimeError, "Synthetic install failure"):
                lab.execute(run)
        self.assertEqual(stages[-2:], ["terminate-injected-fixture", "restore-ordinary-fixture"])
        self.assertEqual(run.manifest["status"], "failed_or_unsupported")

    def test_non_watch_inventory_never_reaches_mutation_or_cleanup(self):
        app, hook = self.fixture()
        output = self.root / "run"
        output.mkdir()
        run = lab.Run(output, self.identifier, app, hook, True)
        inventory = {"devices": {"iOS-Synthetic": [{"udid": self.identifier, "state": "Booted",
                      "isAvailable": True, "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-Synthetic"}]}}
        stages = []
        def command(stage, arguments, **kwargs):
            stages.append(stage)
            return type("Result", (), {"stdout": json.dumps(inventory)})()
        with patch.object(run, "command", command):
            with self.assertRaisesRegex(ValueError, "Apple Watch Simulator"):
                lab.execute(run)
        self.assertEqual(stages, ["inventory"])

    def native_cleanup_fixture(self, extra_rows=()):
        app, hook = self.fixture()
        output = self.root / "run"
        output.mkdir()
        run = lab.Run(output, self.identifier, app, hook, True)
        documents = self.root / "Documents"
        documents.mkdir()
        journal = documents / "NativeBaselineJournal.jsonl"
        prefix = b'{"event":"synthetic_prior_process"}\n'
        rows = [row for revision, arm in enumerate(lab.ARMS, 1) for row in arm_rows(revision, arm)]
        rows.extend(extra_rows)
        journal.write_bytes(prefix + b"".join((json.dumps(row) + "\n").encode() for row in rows))
        run.manifest["results"] = [lab.evaluate_arm(rows[:16], revision, arm)
                                   for revision, arm in enumerate(lab.ARMS, 1)]
        run.manifest["status"] = "eight_measured_state_arms_passed"
        return run, documents, journal, len(prefix), rows

    def test_final_audit_precedes_reinstall_that_invalidates_old_container(self):
        run, documents, journal, offset, rows = self.native_cleanup_fixture()
        stages = []
        def command(stage, arguments, **kwargs):
            stages.append(stage)
            if stage == "restore-ordinary-fixture":
                # Models a successful reinstall relocating the previous container.
                shutil.rmtree(documents)
            return type("Result", (), {"returncode": 0})()
        with patch.object(run, "command", command):
            cleanup = lab.finish_fixture(run, documents, journal, offset,
                                         ("synthetic-view", "synthetic-controller"))
        self.assertEqual(stages, ["terminate-injected-fixture", "restore-ordinary-fixture"])
        self.assertEqual(json.loads((run.output / "current-process-journal.json").read_text()), rows)
        self.assertTrue((run.output / "NativeBaselineJournal.jsonl").is_file())
        self.assertEqual(run.manifest["status"], "eight_measured_state_arms_passed")
        self.assertTrue(all(step["acknowledged"] for step in cleanup))

    def test_final_audit_still_rejects_late_outgoing_setter_and_restores(self):
        late = {"event": "native_outgoing_setVolume", "revision": 8, "outgoing": 0}
        run, documents, journal, offset, _ = self.native_cleanup_fixture([late])
        stages = []
        def command(stage, arguments, **kwargs):
            stages.append(stage)
            return type("Result", (), {"returncode": 0})()
        with patch.object(run, "command", command):
            lab.finish_fixture(run, documents, journal, offset,
                               ("synthetic-view", "synthetic-controller"))
        self.assertEqual(run.manifest["status"], "final_evidence_failed")
        self.assertIn("native_outgoing_setVolume", run.manifest["finalEvidenceError"])
        self.assertEqual(stages[-1], "restore-ordinary-fixture")

    def calibration_trials(self):
        return [{"trial": index, "delta": delta, "profile": "upstream", "initialValue": .5,
                 "finalValue": .5 + (delta * .1 if abs(delta) == 1 else 0),
                 "valueChanges": 1 if abs(delta) == 1 else 0, "resetEvents": 0,
                 "orientation": {"crownOrientation": "synthetic-fixed"}, "runID": "synthetic-run-%d" % index}
                for index, delta in enumerate(calibrator.TRIAL_DELTAS, 1)]

    def test_calibration_original_reverse_order_and_fractional_nonresponse(self):
        trials = self.calibration_trials()
        result = calibrator.verify_binding_trials(trials)
        self.assertEqual(tuple(t["delta"] for t in trials[6:]), tuple(reversed(calibrator.ORIGINAL)))
        self.assertEqual(len(result["fractionalNonresponses"]), 4)
        self.assertEqual(result["responsiveReferenceSigns"], {"1": [1], "-1": [-1]})
        for trial in trials:
            trial["profile"] = "zero-began"
        self.assertEqual(calibrator.verify_binding_trials(trials)["fractionalNonresponses"], [5, 6, 7, 8])

    def test_calibration_missing_reference_wrong_order_or_profile_changes_fail(self):
        trials = self.calibration_trials()
        trials[0]["finalValue"] = .5
        with self.assertRaisesRegex(ValueError, "reference turn did not move"):
            calibrator.verify_binding_trials(trials)
        trials = self.calibration_trials()
        trials[-1]["finalValue"] = .4
        with self.assertRaisesRegex(ValueError, "repeatable opposite"):
            calibrator.verify_binding_trials(trials)
        trials = self.calibration_trials()
        trials[0]["profile"] = "zero-began"
        with self.assertRaisesRegex(ValueError, "Profile or orientation changed"):
            calibrator.verify_binding_trials(trials)
        trials = self.calibration_trials()
        trials[0]["delta"] = -1
        with self.assertRaisesRegex(ValueError, "original six"):
            calibrator.verify_binding_trials(trials)

    def test_calibrator_rejects_production_or_non_watch_artifact_without_commands(self):
        app, _ = self.fixture("com.qayshp.TeachingTimer")
        with patch.object(calibrator.subprocess, "run", side_effect=AssertionError("No commands permitted")):
            with self.assertRaisesRegex(ValueError, "TeachingTimer is forbidden"):
                calibrator.validate_probe(app)

    def test_calibrator_default_plan_never_runs_inventory_host_helper_or_fixture(self):
        app, _ = self.fixture(calibrator.BUNDLE)
        (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": calibrator.BUNDLE,
                                                       "CFBundleExecutable": calibrator.EXECUTABLE}))
        (app / calibrator.EXECUTABLE).write_bytes(macho())
        bridge = self.root / "CrownHIDBridge"
        bridge.write_text("not executed by plan mode")
        bridge.chmod(0o700)
        repo = self.root / "synthetic-repository"
        (repo / "work").mkdir(parents=True)
        output = repo / "work" / "plan"
        calls = []
        def local_only(argv, **kwargs):
            calls.append(argv)
            if argv[:4] != ["git", "check-ignore", "--quiet", "--"]:
                raise AssertionError("Plan attempted a device/helper command")
            return subprocess.CompletedProcess(argv, 0, b"", b"")
        with patch.object(calibrator, "__file__", str(repo / "tools/watch-media-lab/calibrate.py")), \
             patch.object(calibrator.subprocess, "run", local_only), \
             contextlib.redirect_stdout(io.StringIO()):
            code = calibrator.main(["--simulator", self.identifier, "--probe", str(app), "--bridge", str(bridge),
                                    "--output", str(output)])
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 1)
        manifest = json.loads((output / "run.json").read_text())
        self.assertEqual(manifest["status"], "prepared")
        self.assertFalse(manifest["executeRequested"])
        self.assertEqual(manifest["commands"], [])


if __name__ == "__main__":
    unittest.main()
