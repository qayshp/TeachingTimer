# SPDX-License-Identifier: MPL-2.0
"""Bound one OCR invocation and retain evidence before any UI target is used."""
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import subprocess
import time


EVIDENCE_LIMIT = 4096


def _text(value):
    return value.decode('utf-8', errors='replace') if isinstance(value, bytes) else value or ''


def _rows(output):
    def invalid_constant(value):
        raise ValueError(f'OCR output contains invalid JSON constant {value}')

    rows = json.loads(output, parse_constant=invalid_constant)
    if not isinstance(rows, list):
        raise ValueError('OCR output must be a JSON list')
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or not isinstance(row.get('text'), str):
            raise ValueError(f'OCR row {index} must contain string text')
        for field in ('x', 'y', 'confidence'):
            value = row.get(field)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not 0 <= value <= 1 or not math.isfinite(value):
                raise ValueError(f'OCR row {index} has invalid {field}')
        if 'recognitionLevel' in row and row['recognitionLevel'] not in ('fast', 'accurate'):
            raise ValueError(f'OCR row {index} has invalid recognitionLevel')
        if 'corroborated' in row and not isinstance(row['corroborated'], bool):
            raise ValueError(f'OCR row {index} has invalid corroborated')
    return rows


def readable_text(row):
    """Require corroboration for fast OCR without rewriting its raw confidence."""
    confidence = row.get('confidence')
    if isinstance(confidence, bool) or not isinstance(confidence, (int, float)) or not 0 <= confidence <= 1:
        return False
    level = row.get('recognitionLevel', 'accurate')
    if level == 'fast':
        return confidence >= .5 and row.get('corroborated') is True
    return level == 'accurate' and confidence >= .7


def recognize_text(helper: Path, screenshot: Path, timeout_seconds=30) -> list[dict]:
    """Return validated raw OCR rows; failures never become an empty match list.

    The screenshot's .ocr.json sidecar retains timing and bounded process output,
    including failures. Recognition confidence is left untouched for callers to
    apply their own target-selection policy.
    """
    if isinstance(timeout_seconds, bool) or not isinstance(timeout_seconds, (int, float)) or not math.isfinite(timeout_seconds) or timeout_seconds <= 0:
        raise ValueError('OCR timeout must be a finite positive number')
    helper, screenshot = Path(helper).resolve(), Path(screenshot).resolve()
    command = [str(helper), str(screenshot)]
    started = time.monotonic()
    evidence = dict(schemaVersion=1, helper=str(helper), screenshot=str(screenshot),
                    timeoutSeconds=timeout_seconds, startedAt=datetime.now(timezone.utc).isoformat())
    stdout, stderr = b'', b''
    return_code = None
    try:
        # This native helper does not create child processes. subprocess.run
        # kills and reaps it on timeout, while inherited group membership lets
        # the outer suite also clean it up when the entire stage is cancelled.
        try:
            result = subprocess.run(command, check=True, capture_output=True, timeout=timeout_seconds)
            stdout, stderr, return_code = result.stdout, result.stderr, result.returncode
        except subprocess.TimeoutExpired as error:
            stdout, stderr = error.stdout, error.stderr
            evidence['status'] = 'timeout'
            raise
        except subprocess.CalledProcessError as error:
            stdout, stderr, return_code = error.stdout, error.stderr, error.returncode
            evidence['status'] = 'failed'
            raise
        evidence['status'] = 'invalid-output'
        rows = _rows(stdout)
        evidence.update(status='succeeded', rowCount=len(rows))
        return rows
    except Exception as error:
        evidence.setdefault('status', 'launch-error')
        evidence['error'] = f'{type(error).__name__}: {error}'[:EVIDENCE_LIMIT]
        raise
    finally:
        evidence['durationSeconds'] = time.monotonic() - started
        evidence['returnCode'] = return_code
        for label, value in (('stdout', stdout), ('stderr', stderr)):
            text = _text(value)
            evidence[label + 'Tail'] = text[-EVIDENCE_LIMIT:]
            evidence[label + 'Truncated'] = len(text) > EVIDENCE_LIMIT
        sidecar = screenshot.with_suffix('.ocr.json')
        temporary = sidecar.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(evidence, indent=2, allow_nan=False) + '\n')
        temporary.replace(sidecar)
