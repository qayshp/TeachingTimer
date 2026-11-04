#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Generate stable, informative App Store Connect build strings."""
from datetime import datetime
from zoneinfo import ZoneInfo

PACIFIC = ZoneInfo('America/Los_Angeles')


def automatic_build_number(run_number, instant=None):
    """Use Pacific wall time plus the workflow's unique increasing sequence.

    The suffix is GitHub Actions' monotonically increasing workflow run number.
    It makes same-minute builds distinct without relying on a racy API lookup.
    """
    if isinstance(run_number, bool) or not isinstance(run_number, int) or run_number < 1:
        raise ValueError('Workflow run number must be a positive integer')
    instant = instant or datetime.now().astimezone()
    if instant.tzinfo is None:
        raise ValueError('Build timestamp must include a timezone')
    local = instant.astimezone(PACIFIC)
    return f'{local:%y%m%d}.{local:%H%M}.{run_number}'
