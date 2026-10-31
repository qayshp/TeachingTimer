#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Inventory ignored local artifacts; never reads contents, deletes or follows links."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
from urllib.parse import quote

REPO = Path(__file__).resolve().parents[1]
MARKERS = {'RuntimeDiagnostics.json', 'InterfaceDiagnostics.json', 'LandmarkDiagnostics.json',
           'operation.json', 'verification.json', 'readiness.json', 'collection-status.json'}
GENERATED = {'DerivedData', 'DerivedDataSigned', 'DerivedDataSigned2', 'ModuleCache.noindex', '__pycache__'}


def inventory(root, exclude):
    """Collect metadata only; exclude output tree and preserve external symlink boundary."""
    rows = []
    for entry in sorted(root.iterdir()):
        if entry == exclude or exclude in entry.parents or entry.name == 'maintenance':
            continue
        row = {'path': entry.name, 'bytes': 0, 'files': 0, 'links': [],
               'evidence': [], 'notes': [], 'generatedDirectories': [], 'errors': []}
        def add(path):
            relative = path.relative_to(root).as_posix()
            if path.is_symlink():
                row['links'].append(relative)
                return
            try:
                row['bytes'] += path.stat().st_size
                row['files'] += 1
                if path.name in MARKERS or path.name.endswith(('.tar.gz', '.zip')):
                    row['evidence'].append(relative)
                elif path.suffix == '.md':
                    row['notes'].append(relative)
            except OSError as error:
                row['errors'].append(f'{relative}: {type(error).__name__}')
        if not entry.is_symlink() and entry.is_dir() and entry.name.startswith('DerivedData'):
            row['generatedDirectories'].append(entry.name)
        if entry.is_symlink() or entry.is_file():
            add(entry)
        else:
            for current, dirs, files in os.walk(entry, followlinks=False,
                    onerror=lambda error: row['errors'].append(type(error).__name__)):
                base = Path(current)
                dirs.sort(); files.sort()
                for name in list(dirs):
                    path = base / name
                    if path == exclude or path.name == 'maintenance':
                        dirs.remove(name)
                    elif path.is_symlink():
                        row['links'].append(path.relative_to(root).as_posix()); dirs.remove(name)
                    elif name in GENERATED or name.startswith('DerivedData'):
                        row['generatedDirectories'].append(path.relative_to(root).as_posix())
                for name in files:
                    add(base / name)
        rows.append(row)
    return rows


def write_catalog(root, output):
    output.mkdir(parents=True, exist_ok=False, mode=0o700)
    rows = inventory(root, output)
    report = {'createdAt': datetime.now(timezone.utc).isoformat(), 'root': str(root),
              'scope': 'metadata only; no archive validation or deletion', 'items': rows}
    (output / 'inventory.json').write_text(json.dumps(report, indent=2) + '\n')
    def link(relative):
        target = os.path.relpath(root / relative, output)
        return '[' + relative.replace('[', '').replace(']', '') + '](' + quote(target, safe='/') + ')'
    lines = ['# Private artifact index', '', report['createdAt'], '',
             'Metadata only. Counts exclude compatibility links and maintenance outputs.',
             'No content validation, deletion or device operation was performed.', '',
             '| Location | MiB | Files | Evidence files | Generated directories |',
             '| --- | ---: | ---: | ---: | ---: |']
    for row in rows:
        lines.append(f"| {link(row['path'])} | {row['bytes']/1048576:.1f} | {row['files']} | {len(row['evidence'])} | {len(row['generatedDirectories'])} |")
    for row in rows:
        lines += ['', '## ' + row['path'], '']
        for field in ['evidence', 'notes', 'generatedDirectories', 'links']:
            if row[field]:
                lines += ['**' + field + '**', ''] + ['- ' + link(p) for p in row[field]] + ['']
        lines += ['- Inventory error: ' + e for e in row['errors']]
    (output / 'README.md').write_text('\n'.join(lines) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=REPO / 'work')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root, output = args.root.resolve(), args.output.resolve()
    work = REPO / 'work'
    if not root.is_dir() or not root.is_relative_to(work) or not output.is_relative_to(work) or output == root:
        parser.error('Input and new output must be inside this checkout’s ignored work/ directory')
    check = subprocess.run(['git', 'check-ignore', '-q', str(output)], cwd=REPO)
    if check.returncode != 0:
        parser.error('Output must be ignored by Git')
    report = write_catalog(root, output)
    print(f"Private catalog: {output}; {len(report['items'])} groups")


if __name__ == '__main__':
    main()
