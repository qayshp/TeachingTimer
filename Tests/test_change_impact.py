# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
import importlib.util
from pathlib import Path
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts/change-impact.py"
SPEC = importlib.util.spec_from_file_location("change_impact", MODULE_PATH)
change_impact = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(change_impact)


class ChangeImpactChecks(unittest.TestCase):
    def test_documentation_only_skips_build_and_release(self):
        result = change_impact.classify_paths([
            "docs/ISSUE_TRACKER.md", "README.md", ".github/ISSUE_TEMPLATE/bug_report.yml"
        ])
        self.assertTrue(result["docs_changed"])
        self.assertFalse(result["app_changed"])
        self.assertFalse(result["mac_verify"])
        self.assertFalse(result["publish"])

    def test_app_source_and_assets_require_build_and_release(self):
        result = change_impact.classify_paths([
            "TeachingTimer/ContentView.swift", "TeachingTimer/Assets.xcassets/AppIcon.png"
        ])
        self.assertTrue(result["app_changed"])
        self.assertTrue(result["mac_verify"])
        self.assertTrue(result["publish"])

    def test_project_and_package_settings_are_app_inputs(self):
        result = change_impact.classify_paths([
            "TeachingTimer.xcodeproj/project.pbxproj", "Package.resolved", "Configurations/TestFlight.xcconfig"
        ])
        self.assertTrue(result["mac_verify"])
        self.assertTrue(result["publish"])

    def test_ci_and_python_tooling_changes_run_tool_tests_without_release(self):
        result = change_impact.classify_paths([
            ".github/workflows/check.yml", ".github/actionlint.yaml",
            "scripts/change-impact.py", "Tests/test_change_impact.py"
        ])
        self.assertTrue(result["tooling_changed"])
        self.assertTrue(result["workflow_changed"])
        self.assertFalse(result["app_changed"])
        self.assertFalse(result["publish"])
        self.assertFalse(result["mac_verify"])

    def test_swift_test_harness_requires_mac_verification_without_release(self):
        result = change_impact.classify_paths(["Tests/ClockGeometryChecks.swift"])
        self.assertTrue(result["tooling_changed"])
        self.assertTrue(result["mac_verify"])
        self.assertFalse(result["publish"])

    def test_unknown_path_fails_safe(self):
        result = change_impact.classify_paths(["new-build-input/settings.json"])
        self.assertTrue(result["unknown_changed"])
        self.assertTrue(result["mac_verify"])
        self.assertTrue(result["publish"])

    def test_mixed_app_and_documentation_changes_publish_once(self):
        result = change_impact.classify_paths(["TeachingTimer/ContentView.swift", "docs/README.md"])
        self.assertTrue(result["app_changed"])
        self.assertTrue(result["docs_changed"])
        self.assertTrue(result["publish"])


if __name__ == "__main__":
    unittest.main()
