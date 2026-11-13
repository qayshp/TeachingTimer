#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Read-only original PNG audit; no Simulator, physical device or app mutation.

Pass only screen-only media captures. Does not infer page selection or blank-page
cause from filenames, OCR absence, journal events or a black central region.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
from ocr import readable_text, recognize_text

PIXEL_REGION = 'x=0.10...0.90, y=0.22...0.82 (top origin)'
MIN_VISIBLE_FRACTION = .001
DELAYED_MEDIA_CAPTURES = (
    '03b-media-before-fault-after-five-seconds.png',
    '04b-media-return-after-five-seconds.png',
    '06b-media-after-five-seconds.png',
)


def pixel_errors(pixels):
    """Reject missing/malformed measurements without inferring a rendering cause."""
    if not isinstance(pixels, dict):
        return ['pixel metrics must be an object']
    errors = []
    for key in ('width', 'height'):
        if type(pixels.get(key)) is not int or pixels[key] <= 0:
            errors.append(key + ' must be a positive integer')
    if pixels.get('region') != PIXEL_REGION:
        errors.append('unexpected or missing measured region')
    for key in ('visibleFraction', 'brightFraction', 'meanChannelMaximum', 'peakChannel'):
        value = pixels.get(key)
        if type(value) not in (int, float) or not 0 <= value <= 1 or not math.isfinite(value):
            errors.append(key + ' must be finite and within [0, 1]')
    if not errors:
        if pixels['brightFraction'] > pixels['visibleFraction']:
            errors.append('bright fraction exceeds visible fraction')
        if pixels['meanChannelMaximum'] > pixels['peakChannel']:
            errors.append('mean channel value exceeds peak')
    return errors


def observation(rows, pixels):
    if pixel_errors(pixels):
        return 'PIXEL_EVIDENCE_INVALID_REVIEW_REQUIRED'
    if pixels['visibleFraction'] < MIN_VISIBLE_FRACTION:
        return 'NEAR_BLACK_CONTENT_REVIEW_REQUIRED'
    central = [r['text'].casefold() for r in rows
               if readable_text(r) and .22 < r['y'] < .82 and .1 < r['x'] < .9]
    if any('not playing' in text for text in central):
        return 'NOT_PLAYING_TEXT_PRESENT'
    return 'CONTENT_PRESENT_REVIEW_REQUIRED'


def collect_media_pixels(folder, measure):
    """Measure every intended delayed original; retain failures as evidence too."""
    records = []
    for name in DELAYED_MEDIA_CAPTURES:
        record = {'file': name}
        records.append(record)
        try:
            image = folder / name
            record['sha256'] = hashlib.sha256(image.read_bytes()).hexdigest()
            pixels = measure(image)
            # JSON's permissive NaN/Infinity support must not poison result.json.
            json.dumps(pixels, allow_nan=False)
            record['pixels'] = pixels
            record['observation'] = observation([], pixels)
        except Exception as error:
            record['error'] = f'{type(error).__name__}: {error}'
            record['observation'] = 'PIXEL_EVIDENCE_INVALID_REVIEW_REQUIRED'
    return records


def media_sequence_errors(records, folder):
    """A known media sequence needs all delayed originals and usable metrics.

    Passing this narrow gate establishes visible content, not recovery, audio,
    control behavior or a rendering cause. Originals still require human review.
    """
    if not isinstance(records, list) or any(not isinstance(r, dict) for r in records):
        return ['visual review required: delayed media pixel evidence missing or malformed']
    names = [r.get('file') for r in records]
    if (any(not isinstance(name, str) for name in names)
            or len(names) != len(DELAYED_MEDIA_CAPTURES)
            or set(names) != set(DELAYED_MEDIA_CAPTURES)):
        return ['visual review required: exact delayed media capture sequence required']
    errors = []
    for record in records:
        name = record['file']
        prefix = 'visual review required: ' + name + ': '
        image = folder / name
        try:
            data = image.read_bytes()
            if not data:
                errors.append(prefix + 'empty original capture')
            if record.get('sha256') != hashlib.sha256(data).hexdigest():
                errors.append(prefix + 'missing or mismatched original capture digest')
        except OSError as error:
            errors.append(prefix + 'original capture unavailable: ' + str(error))
        if record.get('error'):
            errors.append(prefix + str(record['error']))
        invalid = pixel_errors(record.get('pixels'))
        errors.extend(prefix + error for error in invalid)
        if not invalid and record['pixels']['visibleFraction'] < MIN_VISIBLE_FRACTION:
            errors.append(prefix + 'near-black delayed media content')
    return errors


def main():
    from run import checked
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
        rows = recognize_text(out / 'screen-text', path.resolve())
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
