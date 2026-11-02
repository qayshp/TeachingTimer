#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Check published repository structure without accessing devices or the network.

Only tracked files are inspected: private work/ evidence and build outputs are
intentionally excluded. Local Markdown heading fragments are checked for the
repository's ATX headings (plain text and inline code), including duplicates.
Remote URLs, non-Markdown fragments, reference links and custom HTML anchors
are outside this bounded checker; it is not a general Markdown renderer.
"""
import json
from pathlib import Path
import plistlib
import re
import shlex
import subprocess
import unicodedata
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r'!?\[[^\]\n]*\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+"[^"\n]*")?\s*\)')
HTML_LINK = re.compile(r'<(?:img|a)\b[^>]*?\b(?:src|href)=["\']([^"\']+)["\']', re.I)
PRIVATE_NAMES = {'RuntimeDiagnostics.json', 'InterfaceDiagnostics.json', 'LandmarkDiagnostics.json', 'BuildInfo.plist'}
PRIVATE_SUFFIXES = ('.p12', '.p8', '.mobileprovision', '.provisionprofile', '.keychain', '.keychain-db',
                    '.ipa', '.dSYM.zip', '.tar', '.tar.gz', '.log', '.xcuserstate', '.xccheckout', '.xcscmblueprint')
GENERATED_DIRECTORIES = {'build', '.build', 'xcuserdata', '__pycache__'}
GENERATED_BUNDLES = ('.app', '.xcarchive', '.logarchive', '.dSYM', '.xcresult')
SOURCE_SUFFIXES = {'.swift', '.py', '.sh', '.yml', '.yaml'}
FENCE = re.compile(r'^ {0,3}(`{3,}|~{3,})(.*)$')
HEADING = re.compile(r'^ {0,3}#{1,6}(?:[ \t]+(.*)|[ \t]*)$')


def without_fenced_code(text):
    """Exclude fenced examples from both link and heading discovery."""
    rendered = []
    fence = None
    for line in text.splitlines():
        match = FENCE.match(line)
        if fence is not None:
            if (match and match[1][0] == fence[0] and len(match[1]) >= len(fence)
                    and not match[2].strip()):
                fence = None
            continue
        if match and (match[1][0] == '~' or '`' not in match[2]):
            fence = match[1]
            continue
        rendered.append(line)
    return '\n'.join(rendered)


def heading_fragments(body):
    """GitHub IDs for the ATX heading forms used in this repository.

    Formatting backticks and punctuation disappear; hyphens/underscores remain.
    Spaces become hyphens individually, so removing an em dash can leave two.
    Duplicate IDs are allocated in document order, including numbered collisions.
    The caller supplies text with fenced examples already removed.
    """
    fragments = set()
    for line in body.splitlines():
        match = HEADING.match(line)
        if not match:
            continue
        heading = re.sub(r'[ \t]+#+[ \t]*$', '', match[1] or '').strip()
        slug = ''.join(character for character in heading.lower()
                       if character in ' -_' or unicodedata.category(character)[0] in 'LMN')
        slug = slug.replace(' ', '-')
        candidate = slug
        suffix = 0
        while candidate in fragments:
            suffix += 1
            candidate = f'{slug}-{suffix}'
        fragments.add(candidate)
    return fragments


def private_artifact(name):
    """Catch accidentally force-added files as well as ordinary ignore rules."""
    path = Path(name)
    environment = path.name == '.env' or (path.name.startswith('.env.') and path.name != '.env.example')
    return (name.startswith(('work/', 'outputs/')) or environment or path.name in PRIVATE_NAMES
            or name.endswith(PRIVATE_SUFFIXES)
            or any(part in GENERATED_DIRECTORIES or part.startswith('DerivedData')
                   or part.endswith(GENERATED_BUNDLES) for part in path.parts[:-1])
            or path.suffix in {'.pyc', '.pyo', '.pyd'})


def check_files(root, paths):
    """Return actionable errors; paths are repository-relative tracked names."""
    errors = []
    published = set(paths)
    documents = {}

    def markdown(relative):
        if relative not in documents:
            body = without_fenced_code((root / relative).read_text())
            documents[relative] = (body, heading_fragments(body))
        return documents[relative]

    for name in sorted(published):
        path = root / name
        if not path.is_file():
            errors.append(f'{name}: tracked file missing')
            continue
        if private_artifact(name):
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
                body, _ = markdown(name)
                targets = [m[1].strip('<>') for m in LINK.finditer(body)]
                targets.extend(HTML_LINK.findall(body))
                for target in targets:
                    url = urlsplit(target)
                    if url.scheme or url.netloc:
                        continue
                    resolved = (path.parent / unquote(url.path)).resolve() if url.path else path.resolve()
                    try:
                        relative = resolved.relative_to(root.resolve()).as_posix()
                    except ValueError:
                        errors.append(f'{name}: local link leaves repository: {target}')
                        continue
                    if relative not in published and not any(p.startswith(relative.rstrip('/') + '/') for p in published):
                        errors.append(f'{name}: link is not in published repository: {target}')
                        continue
                    if url.fragment and relative in published and resolved.suffix == '.md':
                        _, fragments = markdown(relative)
                        if unquote(url.fragment) not in fragments:
                            errors.append(f'{name}: heading fragment not found in {relative}: {target}')
        except (ValueError, OSError, UnicodeError, SyntaxError, plistlib.InvalidFileException) as error:
            errors.append(f'{name}: {type(error).__name__}: {error}')
    # Every top-level guide needs an entry point; dated subdirectories remain archives.
    if 'docs/README.md' in published:
        index = (root / 'docs/README.md').read_text()
        indexed = {unquote(urlsplit(m[1].strip('<>')).path) for m in LINK.finditer(index)}
        for name in sorted(published):
            if name.startswith('docs/') and name.count('/') == 1 and name.endswith('.md') and name != 'docs/README.md':
                if name[len('docs/') :] not in indexed:
                    errors.append(f'{name}: guide is not linked from docs/README.md')
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
    print('Repository checks passed: tracked local Markdown links and heading fragments, JSON/plists, source notices and private-artifact exclusions.')


if __name__ == '__main__':
    main()
