#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Check published repository structure without accessing devices or the network.

Only tracked files are inspected: private work/ evidence and build outputs are
intentionally excluded. Markdown fragments and remote URLs are not validated.
"""
import json
from pathlib import Path
import plistlib
import re
import shlex
import subprocess
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r'!?\[[^\]\n]*\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+"[^"\n]*")?\s*\)')
SOURCE_SUFFIXES = {'.swift', '.py', '.sh', '.yml', '.yaml'}


def check_files(root, paths):
    """Return actionable errors; paths are repository-relative tracked names."""
    errors = []
    published = set(paths)
    for name in sorted(published):
        path = root / name
        if not path.is_file():
            errors.append(f'{name}: tracked file missing')
            continue
        if name.startswith(('work/', 'outputs/')) or any(part in {'xcuserdata', '__pycache__'} for part in path.parts) or path.suffix in {'.p12', '.p8', '.mobileprovision', '.provisionprofile'}:
            errors.append(f'{name}: private/generated artifact must not be published')
        try:
            if path.suffix == '.json':
                json.loads(path.read_text())
            elif path.suffix in {'.plist', '.xcprivacy'}:
                plistlib.loads(path.read_bytes())
            elif path.suffix in SOURCE_SUFFIXES:
                if path.suffix == '.py':
                    compile(path.read_text(), str(path), 'exec')
                if 'SPDX-License-Identifier: MPL-2.0' not in '\n'.join(path.read_text().splitlines()[:10]):
                    errors.append(f'{name}: missing MPL source notice')
            elif path.suffix == '.md':
                # Examples inside fenced code are not links in the rendered document.
                body = re.sub(r'^```[^\n]*\n.*?^```\s*$', '', path.read_text(), flags=re.M | re.S)
                for match in LINK.finditer(body):
                    target = match[1].strip('<>')
                    url = urlsplit(target)
                    if url.scheme or url.netloc or not url.path:
                        continue
                    resolved = (path.parent / unquote(url.path)).resolve()
                    try:
                        relative = resolved.relative_to(root.resolve()).as_posix()
                    except ValueError:
                        errors.append(f'{name}: local link leaves repository: {target}')
                        continue
                    if relative not in published and not any(p.startswith(relative.rstrip('/') + '/') for p in published):
                        errors.append(f'{name}: link is not in published repository: {target}')
        except (ValueError, OSError, UnicodeError, SyntaxError, plistlib.InvalidFileException) as error:
            errors.append(f'{name}: {type(error).__name__}: {error}')
    # A newly added standalone Swift suite must not silently miss CI execution.
    runner = root / 'scripts/check.sh'
    if runner.is_file():
        commands = set(shlex.split(runner.read_text(), comments=True))
        for name in sorted(published):
            if name.startswith('Tests/') and name.endswith('Checks.swift') and name not in commands:
                errors.append(f'{name}: standalone suite is not wired into scripts/check.sh')
    return errors


def main():
    paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    errors = check_files(ROOT, [p for p in paths if p])
    if errors:
        raise SystemExit('\n'.join(errors))
    print('Repository checks passed: tracked local Markdown links, JSON/plists, source notices and private-artifact exclusions.')


if __name__ == '__main__':
    main()
