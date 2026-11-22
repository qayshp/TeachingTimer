#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Generate stable, informative App Store Connect build strings."""
from datetime import datetime, timedelta, timezone

PACIFIC_STANDARD_TIME = timezone(timedelta(hours=-8), 'PST')


def automatic_build_number(run_number, instant=None):
    """Use fixed Pacific Standard Time plus the workflow run number.

    A fixed UTC offset avoids repeating an hour at daylight-saving fall-back.
    The workflow run number distinguishes builds generated in the same minute.
    """
    if isinstance(run_number, bool) or not isinstance(run_number, int) or run_number < 1:
        raise ValueError('Workflow run number must be a positive integer')
    if instant is None:
        instant = datetime.now(timezone.utc)
    if instant.tzinfo is None or instant.utcoffset() is None:
        raise ValueError('Build timestamp must include a timezone')
    standard_time = instant.astimezone(PACIFIC_STANDARD_TIME)
    return f'{standard_time:%y%m%d}.{standard_time:%H%M}.{run_number}'
