# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Route complete Swift CodeQL scans without skipping unknown build inputs."""
import argparse
import importlib.util
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
CODEQL_FILES = {
    "scripts/codeql-impact.py", "scripts/change-impact.py",
    ".github/workflows/codeql.yml", ".github/workflows/codeql.yaml",
    ".github/codeql-config.yml", ".github/codeql-config.yaml",
}
CODEQL_PREFIXES = (".github/codeql/",)
DEPENDENCY_FILES = {
    "Package.swift", "Package.resolved", "Cartfile", "Cartfile.resolved",
    "Cartfile.lock", "Podfile", "Podfile.lock",
}


def result(scan, reason):
    return {"swift_changed": scan, "reason": reason}


def classify_paths(paths):
    """Keep production coverage intact; only recognized non-app changes skip Swift."""
    paths = [path.replace("\\", "/") for path in paths if path]
    if not paths:
        return result(False, "empty-diff")
    # A malformed or mis-cased input is not evidence that app inputs are unchanged.
    for path in paths:
        if (path.startswith("/") or any(part in {".", ".."} for part in path.split("/"))
                or any(character in path for character in "\r\n\0")):
            return result(True, "unknown-inputs")
        if (path.lower() in {item.lower() for item in CODEQL_FILES}
                or path.lower().startswith(tuple(item.lower() for item in CODEQL_PREFIXES))):
            return result(True, "codeql-inputs")
        if Path(path).name.lower() in {item.lower() for item in DEPENDENCY_FILES}:
            return result(True, "dependency-inputs")
    try:
        spec = importlib.util.spec_from_file_location("change_impact", ROOT / "scripts/change-impact.py")
        classifier = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(classifier)
        for prefix in classifier.APP_PREFIXES:
            if any(path.lower().startswith(prefix.lower()) and not path.startswith(prefix)
                   for path in paths):
                return result(True, "unknown-inputs")
        if any(path.lower() in {item.lower() for item in classifier.APP_FILES}
               and path not in classifier.APP_FILES for path in paths):
            return result(True, "unknown-inputs")
        values = classifier.classify_paths(paths)
    except (OSError, ImportError, SyntaxError, AttributeError, TypeError, ValueError):
        return result(True, "classifier-unavailable")
    if values["unknown_changed"]:
        return result(True, "unknown-inputs")
    if values["app_changed"]:
        return result(True, "production-inputs")
    return result(False, "no-production-inputs")


def changed_paths(base, head):
    """Resolve commits first and retain deleted/renamed paths using a NUL-safe diff."""
    commits = []
    for ref in (base, head):
        commits.append(subprocess.check_output(
            ["git", "rev-parse", "--verify", "--end-of-options", f"{ref}^{{commit}}"],
            cwd=ROOT, text=True, stderr=subprocess.PIPE, timeout=30,
        ).strip())
    output = subprocess.check_output(
        ["git", "diff", "--no-renames", "--name-only", "-z", *commits, "--"],
        cwd=ROOT, text=True, stderr=subprocess.PIPE, timeout=30,
    )
    return [path for path in output.split("\0") if path]


def classify_range(base, head):
    if not base or not head:
        return result(True, "missing-range")
    try:
        return classify_paths(changed_paths(base, head))
    except (OSError, subprocess.SubprocessError, UnicodeError, ValueError):
        # Unavailable history must trigger a scan, never an apparently clean diff.
        return result(True, "diff-unavailable")


def format_outputs(values):
    scan = "true" if values["swift_changed"] else "false"
    return f"swift_changed={scan}\nreason={values['reason']}\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="base commit for git diff")
    parser.add_argument("--head", help="head commit for git diff")
    parser.add_argument("--all", action="store_true", help="force a complete Swift scan")
    parser.add_argument("--paths", nargs="*", help="classify explicit paths instead of a git range")
    parser.add_argument("--output", help="append GitHub Actions output variables to this file")
    args = parser.parse_args()
    if args.all:
        values = result(True, "forced-full")
    elif args.paths is not None:
        values = classify_paths(args.paths)
    else:
        values = classify_range(args.base, args.head)
    output = format_outputs(values)
    if args.output:
        with open(args.output, "a", encoding="utf-8") as destination:
            destination.write(output)
    else:
        print(output, end="")


if __name__ == "__main__":
    main()
