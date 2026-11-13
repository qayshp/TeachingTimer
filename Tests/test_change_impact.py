# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts/change-impact.py"
SPEC = importlib.util.spec_from_file_location("change_impact", MODULE_PATH)
change_impact = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(change_impact)


class ChangeImpactChecks(unittest.TestCase):
    def test_release_verification_only_repeats_for_app_candidates(self):
        cases = [
            (['README.md'], False, False),
            (['scripts/testflight-release.py'], False, False),
            (['scripts/reuse-watch-verification.py'], True, False),
            (['tools/simulator-regression/ControlOutline.swift'], True, False),
            (['Tests/TimerFaceLayoutChecks.swift'], True, False),
            (['.github/workflows/testflight-release.yml'], False, False),
            (['TeachingTimer/ContentView.swift'], True, True),
            (['PhoneSupport/SupportView.swift'], True, True),
            (['TeachingTimerComplications/TeachingTimerComplication.swift'], True, True),
            (['docs/PRIVACY.md'], True, True),
            (['unknown-build-input'], True, True),
            (['TeachingTimer/ContentView.swift', 'README.md'], True, True),
        ]
        for paths, watch_verify, release_verify in cases:
            with self.subTest(paths=paths):
                result = change_impact.classify_paths(paths)
                self.assertEqual(result['mac_verify'], watch_verify)
                self.assertEqual(result['release_verify'], release_verify)

    def test_manual_rehearsal_and_publish_keep_complete_verification(self):
        output = subprocess.check_output([sys.executable, str(MODULE_PATH), '--all'], text=True)
        values = dict(line.split('=', 1) for line in output.splitlines())
        for key in ('mac_verify', 'release_verify', 'publish'):
            self.assertEqual(values[key], 'true')

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

    def test_embedded_documents_and_build_phase_script_publish(self):
        for path in ["LICENSE", "docs/PRIVACY.md", "scripts/build-metadata.sh"]:
            with self.subTest(path=path):
                result = change_impact.classify_paths([path])
                self.assertTrue(result["app_changed"])
                self.assertTrue(result["mac_verify"])
                self.assertTrue(result["publish"])

    def test_ci_and_python_tooling_changes_run_tool_tests_without_release(self):
        result = change_impact.classify_paths([
            ".github/workflows/check.yml", ".github/actionlint.yaml",
            "scripts/change-impact.py", "Tests/test_change_impact.py", ".editorconfig"
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

    def test_mac_build_harness_and_probe_edits_verify_without_publishing(self):
        for path in ["scripts/prepare-ci-watch-runtime.py", "scripts/simulator-smoke.py", "scripts/check.sh", "scripts/check-archive.sh", "scripts/check-simulator-tools.sh", "scripts/verify-build.py",
                     "scripts/prepare-testflight.py", "scripts/prepare-testflight.sh",
                     "scripts/inspect-artifact.py", "tools/native-volume-probe/build.sh",
                     "tools/phone-audio-probe/Info.plist", "tools/timeline-clock-probe/TimelineClockProbe.swift",
                     "tools/diagnostic-share-probe/DiagnosticShareProbe.swift",
                     "tools/simulator-regression/ScreenText.swift", "scripts/information-qr.swift"]:
            with self.subTest(path=path):
                result = change_impact.classify_paths([path])
                self.assertTrue(result["tooling_changed"])
                self.assertTrue(result["mac_verify"])
                self.assertFalse(result["publish"])

    def test_outline_helper_fixture_and_wrapper_require_mac_without_release(self):
        for path in ('tools/simulator-regression/ControlOutline.swift',
                     'scripts/check-control-outline.swift', 'scripts/check-control-outline.sh'):
            with self.subTest(path=path):
                result = change_impact.classify_paths([path])
                self.assertTrue(result['mac_verify'])
                self.assertFalse(result['publish'])

    def test_probe_readme_still_skips_mac_build(self):
        result = change_impact.classify_paths(["tools/native-volume-probe/README.md"])
        self.assertTrue(result["docs_changed"])
        self.assertFalse(result["mac_verify"])
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
