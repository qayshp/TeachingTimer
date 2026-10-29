#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Pure journal check for a count completing after a confirmed dim transition.

Timestamps in current JSON journals have one-second resolution. This verifies
recorded state transitions, not continuous screen observation or tactile delivery.
"""
from datetime import datetime


def locked_count_evidence(interface, start, completion):
    errors = []
    details, ended = start.get('details', {}), completion.get('details', {})
    runtime_id = details.get('runtimeID')
    run_id = details.get('runID')
    report = dict(verified=False, runID=run_id, runtimeID=runtime_id,
                  timestampResolutionSeconds=1, hapticDelivery='unverified', errors=errors)
    if (not runtime_id or runtime_id == 'none' or not run_id or run_id == 'none'
            or ended.get('runtimeID') != runtime_id or ended.get('runID') != run_id):
        errors.append('missing or mismatched runtime/count identity')
        return report
    if start.get('event') != 'landmark_started' or completion.get('event') != 'landmark_ended' or ended.get('reason') != 'completed':
        errors.append('matching normal count completion required')
        return report
    def instant(value):
        date = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if date.utcoffset() is None:
            raise ValueError('timestamps require an offset')
        return date.timestamp()
    try:
        begin, end = instant(start['timestamp']), instant(completion['timestamp'])
        if end < begin:
            raise ValueError('completion precedes activation')
        observations = [(instant(e['timestamp']), e.get('details', {})) for e in interface
                        if e.get('details', {}).get('runtimeID') == runtime_id
                        and e.get('event') in {'luminance_changed', 'scene_state_changed'}
                        and e.get('details', {}).get('luminanceReduced') in {'true', 'false'}]
    except (KeyError, TypeError, ValueError) as error:
        errors.append('invalid timestamp evidence: ' + str(error))
        return report
    reduced = [at for at, state in observations if begin <= at <= min(begin + 5, end)
               and state['luminanceReduced'] == 'true']
    if not reduced:
        errors.append('no same-runtime reduced-luminance observation within five seconds of activation')
        return report
    first_dim = min(reduced)
    report['dimObservedAfterSeconds'] = first_dim - begin
    # Same-second wake/completion cannot be ordered exactly; fail conservatively.
    if any(first_dim <= at <= end and state['luminanceReduced'] == 'false' for at, state in observations):
        errors.append('wake observed before or in the completion timestamp second')
    report['verified'] = not errors
    return report
