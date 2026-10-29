# SPDX-License-Identifier: MPL-2.0
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/simulator-regression'))
from count_evidence import locked_count_evidence


def event(name, seconds, **details):
    return dict(event=name, timestamp=f'2026-10-29T12:{seconds // 60:02}:{seconds % 60:02}Z',
                details=dict(runtimeID='runtime', runID='count', **details))


class CountLockEvidenceChecks(unittest.TestCase):
    def setUp(self):
        self.start = event('landmark_started', 0)
        self.end = event('landmark_ended', 65, reason='completed')

    def test_recent_dim_same_runtime_without_wake_passes(self):
        result = locked_count_evidence([event('luminance_changed', 2, luminanceReduced='true')], self.start, self.end)
        self.assertTrue(result['verified'])
        self.assertEqual(result['dimObservedAfterSeconds'], 2)
        self.assertEqual(result['hapticDelivery'], 'unverified')

    def test_lock_request_or_inactive_without_luminance_cannot_pass(self):
        self.assertFalse(locked_count_evidence([event('scene_state_changed', 2, sceneState='inactive')], self.start, self.end)['verified'])

    def test_late_dim_or_different_runtime_cannot_pass(self):
        self.assertFalse(locked_count_evidence([event('luminance_changed', 6, luminanceReduced='true')], self.start, self.end)['verified'])
        wrong = event('luminance_changed', 2, luminanceReduced='true')
        wrong['details']['runtimeID'] = 'different'
        self.assertFalse(locked_count_evidence([wrong], self.start, self.end)['verified'])

    def test_wake_before_or_same_second_as_completion_fails(self):
        for seconds in [5, 65]:
            rows = [event('luminance_changed', 2, luminanceReduced='true'), event('luminance_changed', seconds, luminanceReduced='false')]
            self.assertFalse(locked_count_evidence(rows, self.start, self.end)['verified'])
        rows[-1] = event('luminance_changed', 66, luminanceReduced='false')
        self.assertTrue(locked_count_evidence(rows, self.start, self.end)['verified'])

    def test_count_identity_and_normal_completion_required(self):
        self.end['details']['runID'] = 'old'
        self.assertFalse(locked_count_evidence([], self.start, self.end)['verified'])
        self.end['details']['runID'] = 'count'
        self.end['details']['reason'] = 'user_cancelled'
        self.assertFalse(locked_count_evidence([], self.start, self.end)['verified'])
