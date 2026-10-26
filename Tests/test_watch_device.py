# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import contextlib
import io
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import watch_device as wd

EVENT = [{"timestamp": "2026-10-26T12:00:00Z", "event": "app_launched", "details": {"build": "17"}}]
EXPECTED = {"bundleIdentifier": "com.qayshp.TeachingTimer", "bundleVersion": "17", "version": "1.0"}


class Service:
    """Only a fake subprocess boundary: never invokes Apple tools or a device."""
    def __init__(self):
        self.calls = []
        self.copy_failures = 0
        self.invalid_copy = False
        self.install_ok = True
        self.query_ok = True
        self.installed_build = "17"
        self.launch_ok = True
        self.timeout = False

    def __call__(self, args, **kwargs):
        self.calls.append(args)
        if self.timeout:
            raise subprocess.TimeoutExpired(args, kwargs["timeout"])
        ok, result = True, {}
        if args[2:5] == ["device", "copy", "from"]:
            if self.copy_failures:
                self.copy_failures -= 1
                ok = False
            else:
                target = Path(args[args.index("--destination") + 1])
                target.write_text("broken" if self.invalid_copy else json.dumps(EVENT))
        elif args[2:5] == ["device", "install", "app"]:
            ok = self.install_ok
        elif args[2:5] == ["device", "info", "apps"]:
            ok = self.query_ok
            result = {"apps": [{**EXPECTED, "bundleVersion": self.installed_build}]}
        elif args[2:5] == ["device", "process", "launch"]:
            ok = self.launch_ok
            result = {"process": {"processIdentifier": 123}} if ok else {}
        Path(args[args.index("--json-output") + 1]).write_text(json.dumps({
            "info": {"outcome": "success" if ok else "failure"}, "result": result,
            **({} if ok else {"error": {"domain": "FakeConnection", "code": 1001}})}))
        return subprocess.CompletedProcess(args, 0 if ok else 1)


class WatchDeviceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name) / "capture"
        self.service = Service()
        self.mock = patch.object(wd.subprocess, "run", self.service)
        self.mock.start()
        self.addCleanup(self.mock.stop)
        self.stdout = io.StringIO()
        redirection = contextlib.redirect_stdout(self.stdout)
        redirection.__enter__()
        self.addCleanup(redirection.__exit__, None, None, None)

    def session(self):
        return wd.Session(self.output, "explicit-watch", timeout=30)

    def operations(self, operation):
        return [call for call in self.service.calls if call[2:5] == operation]

    def test_copy_all_files_without_launch_or_install(self):
        session = self.session()
        self.assertEqual(wd.collect_journals(session, EXPECTED["bundleIdentifier"], 1), 0)
        self.assertEqual(len(self.service.calls), 5)
        for name in wd.JOURNALS:
            self.assertEqual(json.loads((self.output / name).read_text()), EVENT)
        self.assertFalse(self.operations(["device", "process", "launch"]))
        self.assertFalse(self.operations(["device", "install", "app"]))
        self.assertIn("let the Watch sleep", self.stdout.getvalue())
        self.assertEqual(session.manifest["status"], "complete")

    def test_one_optional_retry_preserves_failed_evidence(self):
        self.service.copy_failures = 1
        session = self.session()
        self.assertEqual(wd.collect_journals(session, EXPECTED["bundleIdentifier"], 2), 0)
        self.assertEqual(len(self.operations(["device", "copy", "from"])), 4)
        failure = session.manifest["steps"][2]
        self.assertEqual(failure["status"], "failed_or_unconfirmed")
        self.assertEqual(json.loads((self.output / failure["result"]).read_text())["error"]["code"], 1001)

    def test_no_retry_by_default_and_partial_copy_retained(self):
        self.service.copy_failures = 1
        session = self.session()
        self.assertEqual(wd.collect_journals(session, EXPECTED["bundleIdentifier"], 1), 2)
        self.assertFalse((self.output / wd.JOURNALS[0]).exists())
        self.assertTrue((self.output / wd.JOURNALS[1]).exists())
        self.assertEqual(len(self.operations(["device", "copy", "from"])), 3)

    def test_corrupt_successful_transfer_not_reported_as_valid(self):
        self.service.invalid_copy = True
        session = self.session()
        self.assertEqual(wd.collect_journals(session, EXPECTED["bundleIdentifier"], 1), 2)
        self.assertTrue(all(row["status"] == "invalid_copy" for row in session.manifest["journals"].values()))
        self.assertFalse((self.output / wd.JOURNALS[0]).exists())
        self.assertTrue(list(self.output.glob("copy-*/*.json")))

    def test_install_verified_separately_and_launch_is_opt_in(self):
        session = self.session()
        self.assertEqual(wd.install(session, Path("fixture.app"), EXPECTED, 1, False), 0)
        self.assertEqual(session.manifest["status"], "installed")
        self.assertEqual(len(self.operations(["device", "info", "apps"])), 1)
        self.assertFalse(self.operations(["device", "process", "launch"]))

    def test_launch_success_requires_acknowledgement(self):
        session = self.session()
        self.assertEqual(wd.install(session, Path("fixture.app"), EXPECTED, 1, True), 0)
        self.assertEqual(session.manifest["status"], "installed_and_launched")

    def test_launch_failure_does_not_reinstall(self):
        self.service.launch_ok = False
        session = self.session()
        self.assertEqual(wd.install(session, Path("fixture.app"), EXPECTED, 2, True), 2)
        self.assertEqual(session.manifest["status"], "installed_launch_unconfirmed")
        self.assertEqual(len(self.operations(["device", "install", "app"])), 1)

    def test_failed_install_with_matching_version_is_not_retried_or_launched(self):
        self.service.install_ok = False
        session = self.session()
        self.assertEqual(wd.install(session, Path("fixture.app"), EXPECTED, 2, True), 2)
        self.assertEqual(session.manifest["status"], "version_present_install_unconfirmed")
        self.assertEqual(len(self.operations(["device", "install", "app"])), 1)
        self.assertFalse(self.operations(["device", "process", "launch"]))

    def test_unknown_install_and_failed_query_does_not_blindly_retry(self):
        self.service.install_ok = self.service.query_ok = False
        session = self.session()
        self.assertEqual(wd.install(session, Path("fixture.app"), EXPECTED, 2, False), 2)
        self.assertEqual(len(self.operations(["device", "install", "app"])), 1)

    def test_retry_install_only_after_query_shows_wrong_version(self):
        self.service.install_ok = False
        self.service.installed_build = "16"
        session = self.session()
        self.assertEqual(wd.install(session, Path("fixture.app"), EXPECTED, 2, False), 2)
        self.assertEqual(len(self.operations(["device", "install", "app"])), 2)
        self.assertEqual(session.manifest["status"], "install_failed")

    def test_acknowledged_install_but_wrong_version_is_not_success(self):
        self.service.installed_build = "16"
        session = self.session()
        self.assertEqual(wd.install(session, Path("fixture.app"), EXPECTED, 2, False), 2)
        self.assertEqual(session.manifest["status"], "install_verification_unconfirmed")
        self.assertEqual(len(self.operations(["device", "install", "app"])), 1)

    def test_process_timeout_is_uncertain_and_evidence_survives(self):
        self.service.timeout = True
        session = self.session()
        result = session.command("copy", ["device", "copy", "from"])
        self.assertFalse(result["ok"])
        self.assertEqual(result["status"], "client_timeout_outcome_unknown")
        self.assertTrue((self.output / "01-copy.txt").exists())

    def test_overall_budget_stops_new_device_commands(self):
        session = self.session()
        session.deadline = wd.time.monotonic() - 1
        self.assertEqual(wd.collect_journals(session, EXPECTED["bundleIdentifier"], 2), 2)
        self.assertFalse(self.service.calls)
        self.assertTrue(all(row["status"] == "budget_exhausted" for row in session.manifest["steps"]))

    def test_existing_output_rejected_without_device_contact(self):
        self.output.mkdir()
        with self.assertRaises(FileExistsError):
            self.session()
        self.assertFalse(self.service.calls)

    def test_reject_simulator_and_wrong_bundle_locally(self):
        app = Path(self.temp.name) / "Test.app"
        app.mkdir()
        info = {"CFBundleIdentifier": EXPECTED["bundleIdentifier"], "CFBundleVersion": "17",
                "CFBundleSupportedPlatforms": ["WatchSimulator"]}
        (app / "Info.plist").write_bytes(plistlib.dumps(info))
        with self.assertRaises(ValueError):
            wd.app_metadata(app, EXPECTED["bundleIdentifier"])
        with self.assertRaises(ValueError):
            wd.app_metadata(app, "wrong.bundle")
        self.assertFalse(self.service.calls)


if __name__ == "__main__":
    unittest.main()
