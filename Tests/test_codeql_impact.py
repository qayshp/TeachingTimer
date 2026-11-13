# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts/codeql-impact.py"
SPEC = importlib.util.spec_from_file_location("codeql_impact", MODULE_PATH)
codeql_impact = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(codeql_impact)


class CodeQLImpactChecks(unittest.TestCase):
    def test_complete_production_dependency_and_project_scans(self):
        for path in (
            "TeachingTimer/ContentView.swift", "PhoneSupport/SupportView.swift",
            "TeachingTimer/Assets.xcassets/AppIcon.png", "Configurations/TestFlight.xcconfig",
            "TeachingTimer.xcodeproj/project.pbxproj", "TeachingTimer.xcodeproj/xcshareddata/xcschemes/TeachingTimer.xcscheme",
            "TeachingTimer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
            "Package.swift", "Package.resolved", "Cartfile.lock", "Podfile.lock",
            "tools/new-package/Package.swift", "tools/new-package/Package.resolved",
            "LICENSE", "docs/PRIVACY.md", "scripts/build-metadata.sh", "App.entitlements",
        ):
            with self.subTest(path=path):
                self.assertTrue(codeql_impact.classify_paths([path])["swift_changed"])

    def test_documentation_tests_and_routine_tooling_skip_swift(self):
        for path in (
            "README.md", "docs/ROADMAP.md", ".github/ISSUE_TEMPLATE/bug_report.yml",
            "Tests/ClockGeometryChecks.swift", "Tests/test_codeql_impact.py",
            "tools/simulator-regression/ControlOutline.swift", "scripts/information-qr.swift",
            "tools/native-volume-probe/VolumeProbe.swift", "scripts/check.sh",
            ".github/workflows/watch-checks.yml", ".github/workflows/testflight-release.yml",
            ".editorconfig", "SECURITY.md",
        ):
            with self.subTest(path=path):
                self.assertFalse(codeql_impact.classify_paths([path])["swift_changed"])

    def test_codeql_configuration_and_router_edits_force_swift(self):
        for path in (
            "scripts/codeql-impact.py", "scripts/change-impact.py",
            ".github/workflows/codeql.yml", ".github/workflows/codeql.yaml",
            ".github/codeql-config.yml", ".github/codeql-config.yaml",
            ".github/codeql/swift-config.yml", ".github/codeql/queries/Custom.ql",
            ".github/CodeQL/README.md", "scripts/CodeQL-Impact.py",
        ):
            with self.subTest(path=path):
                self.assertEqual(codeql_impact.classify_paths([path]), {
                    "swift_changed": True, "reason": "codeql-inputs",
                })

    def test_mixed_changes_unknown_paths_and_mis_cased_app_paths_scan(self):
        for paths in (
            ["docs/ROADMAP.md", "PhoneSupport/SupportView.swift"],
            ["Tests/ClockGeometryChecks.swift", "TeachingTimer/ClockView.swift"],
            ["new-build-input.json"], ["Teachingtimer/README.md"],
            ["phonesupport/README.md"], ["configurations/README.md"],
            ["docs/privacy.md"], ["scripts/build-Metadata.sh"],
            ["../docs/README.md"], ["/docs/README.md"], ["tools/bad\npath.md"],
        ):
            with self.subTest(paths=paths):
                self.assertTrue(codeql_impact.classify_paths(paths)["swift_changed"])

    def test_classifier_failure_cannot_skip_swift(self):
        with patch.object(codeql_impact.importlib.util, "spec_from_file_location", side_effect=OSError):
            self.assertEqual(codeql_impact.classify_paths(["README.md"]), {
                "swift_changed": True, "reason": "classifier-unavailable",
            })

    def test_git_errors_and_missing_ranges_force_full_scan(self):
        for error in (OSError("git missing"), subprocess.CalledProcessError(128, "git"),
                      subprocess.TimeoutExpired("git", 30)):
            with self.subTest(error=type(error).__name__):
                with patch.object(codeql_impact, "changed_paths", side_effect=error):
                    self.assertEqual(codeql_impact.classify_range("base", "head"), {
                        "swift_changed": True, "reason": "diff-unavailable",
                    })
        for base, head in ((None, None), ("HEAD", None), (None, "HEAD")):
            self.assertEqual(codeql_impact.classify_range(base, head), {
                "swift_changed": True, "reason": "missing-range",
            })

    def test_real_git_diff_preserves_deletions_and_valid_empty_ranges(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, text=True, stderr=subprocess.PIPE).strip()

            git("init", "--quiet")
            git("config", "user.name", "CodeQL Routing Test")
            git("config", "user.email", "test@example.invalid")
            source = root / "TeachingTimer/DeletedView.swift"
            source.parent.mkdir()
            source.write_text("struct DeletedView {}\n", encoding="utf-8")
            git("add", ".")
            git("commit", "--no-gpg-sign", "--quiet", "-m", "Initial fixture")
            base = git("rev-parse", "HEAD")
            source.unlink()
            git("add", "-u")
            git("commit", "--no-gpg-sign", "--quiet", "-m", "Delete production fixture")
            head = git("rev-parse", "HEAD")
            with patch.object(codeql_impact, "ROOT", root):
                paths = codeql_impact.changed_paths(base, head)
                self.assertEqual(paths, ["TeachingTimer/DeletedView.swift"])
                self.assertEqual(codeql_impact.classify_range(head, head), {
                    "swift_changed": False, "reason": "empty-diff",
                })
            self.assertTrue(codeql_impact.classify_paths(paths)["swift_changed"])

    def test_cli_force_all_invalid_ref_and_empty_paths(self):
        cases = (
            (["--all"], "true", "forced-full"),
            (["--base", "does-not-exist-codeql-test", "--head", "HEAD"], "true", "diff-unavailable"),
            ([], "true", "missing-range"),
            (["--paths"], "false", "empty-diff"),
            (["--paths", "README.md"], "false", "no-production-inputs"),
        )
        for args, scan, reason in cases:
            with self.subTest(args=args):
                output = subprocess.check_output([sys.executable, str(MODULE_PATH), *args], text=True)
                self.assertEqual(dict(line.split("=", 1) for line in output.splitlines()), {
                    "swift_changed": scan, "reason": reason,
                })

    def test_cli_appends_github_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "github-output"
            destination.write_text("existing=value\n", encoding="utf-8")
            subprocess.check_call([sys.executable, str(MODULE_PATH), "--all", "--output", str(destination)])
            self.assertEqual(destination.read_text(encoding="utf-8"),
                             "existing=value\nswift_changed=true\nreason=forced-full\n")


if __name__ == "__main__":
    unittest.main()
