# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Classify a commit range for lightweight checks, app verification and release."""
import argparse
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
APP_PREFIXES = (
    "TeachingTimer/",
    "TeachingTimer.xcodeproj/",
    "Configurations/",
)
# These inputs live outside the app folder but are embedded in its bundle or run
# by an Xcode build phase. Treating them as documentation/tooling would ship stale
# in-app Privacy/About content or revision metadata.
APP_FILES = {"Package.swift", "Package.resolved", "LICENSE", "docs/PRIVACY.md",
             "scripts/build-metadata.sh"}
APP_SUFFIXES = {".xcconfig", ".entitlements", ".xcprivacy"}
DOC_PREFIXES = ("docs/", ".github/ISSUE_TEMPLATE/")
DOC_FILES = {"README", "README.md", "CHANGELOG.md", "SUPPORT.md", "LICENSE", "LICENSE.txt"}
TOOL_PREFIXES = (".github/", "scripts/", "Tests/", "tools/")
TOOL_FILES = {"AGENTS.md", "SECURITY.md", ".gitignore", ".gitattributes", ".editorconfig"}
MAC_TOOL_FILES = {
    "scripts/prepare-ci-watch-runtime.py", "scripts/simulator-smoke.py", "scripts/check.sh", "scripts/check-archive.sh", "scripts/check-simulator-tools.sh", "scripts/verify-build.py",
    "scripts/prepare-testflight.sh", "scripts/prepare-testflight.py",
    "scripts/inspect-artifact.py",
}
MAC_PROBE_PREFIXES = (
    "tools/phone-audio-probe/", "tools/native-volume-probe/",
    "tools/timeline-clock-probe/", "tools/diagnostic-share-probe/",
)


def classify_paths(paths):
    """Classify repository-relative paths; unknown paths fail safely as app inputs."""
    result = {
        "app_changed": False,
        "docs_changed": False,
        "tooling_changed": False,
        "workflow_changed": False,
        "unknown_changed": False,
        "mac_verify": False,
    }
    for raw_path in paths:
        path = raw_path.strip().replace("\\", "/")
        if not path:
            continue
        name = Path(path).name
        root_config = "/" not in path and Path(path).suffix in APP_SUFFIXES
        if path.startswith(APP_PREFIXES) or path in APP_FILES or root_config:
            result["app_changed"] = True
            result["mac_verify"] = True
        elif (path.startswith(DOC_PREFIXES) or name in DOC_FILES
              or name.lower().endswith((".md", ".mdx"))):
            result["docs_changed"] = True
        elif path.startswith(TOOL_PREFIXES) or path in TOOL_FILES:
            result["tooling_changed"] = True
            if (path.startswith((".github/workflows/", ".github/actions/"))
                    or path == ".github/actionlint.yaml"):
                result["workflow_changed"] = True
            if (path in MAC_TOOL_FILES or path.startswith(MAC_PROBE_PREFIXES)
                    or (path.startswith(("Tests/", "scripts/", "tools/"))
                        and path.endswith(".swift"))):
                result["mac_verify"] = True
        else:
            # A new or unrecognized build input must not silently bypass release checks.
            result["unknown_changed"] = True
            result["app_changed"] = True
            result["mac_verify"] = True
    result["publish"] = result["app_changed"] or result["unknown_changed"]
    return result


def changed_paths(base, head):
    output = subprocess.check_output(
        ["git", "diff", "--no-renames", "--name-only", base, head],
        cwd=ROOT,
        text=True,
    )
    return [line for line in output.splitlines() if line]


def write_outputs(values, destination):
    with open(destination, "a", encoding="utf-8") as output:
        for name, value in values.items():
            output.write(f"{name}={'true' if value else 'false'}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="base commit for git diff")
    parser.add_argument("--head", help="head commit for git diff")
    parser.add_argument("--all", action="store_true", help="force the full app verification/release path")
    parser.add_argument("--output", help="append GitHub Actions output variables to this file")
    parser.add_argument("--paths", nargs="*", help="classify explicit paths instead of a git range")
    args = parser.parse_args()
    if args.all:
        values = {"app_changed": True, "docs_changed": False, "tooling_changed": True,
                  "workflow_changed": False,
                  "unknown_changed": False, "mac_verify": True, "publish": True}
    elif args.paths is not None:
        values = classify_paths(args.paths)
    else:
        if not args.base or not args.head:
            parser.error("provide --all, --paths, or both --base and --head")
        values = classify_paths(changed_paths(args.base, args.head))
    if args.output:
        write_outputs(values, args.output)
    else:
        for name, value in values.items():
            print(f"{name}={'true' if value else 'false'}")


if __name__ == "__main__":
    main()
