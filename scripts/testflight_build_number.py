#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Generate stable, informative App Store Connect build strings."""
from datetime import datetime, timedelta, timezone

PACIFIC_STANDARD_TIME = timezone(timedelta(hours=-8), 'PST')


def automatic_build_number(run_number, instant):
    """Use fixed Pacific Standard Time plus the workflow run number.

    A fixed UTC offset avoids repeating an hour at daylight-saving fall-back.
    The workflow run number distinguishes builds generated in the same minute.
    """
    if isinstance(run_number, bool) or not isinstance(run_number, int) or run_number < 1:
        raise ValueError('Workflow run number must be a positive integer')
    if instant.tzinfo is None or instant.utcoffset() is None:
        raise ValueError('Build timestamp must include a timezone')
    standard_time = instant.astimezone(PACIFIC_STANDARD_TIME)
    return f'{standard_time:%y%m%d}.{standard_time:%H%M}.{run_number}'


def automatic_build_number_for_run(run, run_id, run_number, source_sha):
    """Bind the build to the first run creation, even on a later run attempt."""
    if (run.get('id') != run_id or run.get('run_number') != run_number
            or run.get('head_sha') != source_sha or run.get('event') != 'push'
            or run.get('head_branch') != 'main'):
        raise ValueError('GitHub release run identity does not match the selected main push')
    try:
        instant = datetime.fromisoformat(run['created_at'].replace('Z', '+00:00'))
    except (AttributeError, KeyError, ValueError) as error:
        raise ValueError('GitHub release run has no valid creation timestamp') from error
    return automatic_build_number(run_number, instant)
