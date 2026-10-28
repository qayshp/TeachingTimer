#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Read-only original PNG audit; no Simulator, physical device or app mutation.

Pass only screen-only media captures. Does not infer page selection or blank-page
cause from filenames, OCR absence, journal events or a black central region.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
from run import checked


def observation(rows, pixels):
    central = [r['text'].casefold() for r in rows
               if r['confidence'] >= .7 and .22 < r['y'] < .82 and .1 < r['x'] < .9]
    if any('not playing' in text for text in central):
        return 'NOT_PLAYING_TEXT_PRESENT'
    if pixels['visibleFraction'] < .001:
        return 'NEAR_BLACK_CONTENT_REVIEW_REQUIRED'
    return 'CONTENT_PRESENT_REVIEW_REQUIRED'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('images', nargs='+', type=Path)
    args = parser.parse_args()
    if any(p.suffix.lower() != '.png' or not p.is_file() for p in args.images):
        parser.error('Existing original PNG paths required')
    os.umask(0o077)
    args.output.mkdir(parents=True, exist_ok=False)
    out = args.output.resolve()
    for source, target in [('ScreenText.swift', 'screen-text'), ('MediaPixels.swift', 'media-pixels')]:
        checked('swiftc', Path(__file__).with_name(source), '-o', out / target, timeout=60)
    records = []
    for path in args.images:
        rows = json.loads(checked(out / 'screen-text', path.resolve()))
        pixels = json.loads(checked(out / 'media-pixels', path.resolve()))
        records.append(dict(file=str(path), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                            text=rows, pixels=pixels, observation=observation(rows, pixels)))
        (out / 'evidence.json').write_text(json.dumps(records, indent=2))
    counts = {value: sum(r['observation'] == value for r in records)
              for value in sorted({r['observation'] for r in records})}
    print(json.dumps(dict(images=len(records), observations=counts,
                         limitation='Review sequences and originals; these are not audio or recovery assertions.')))


if __name__ == '__main__':
    main()
