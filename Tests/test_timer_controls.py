# SPDX-License-Identifier: MPL-2.0
import importlib.util
from pathlib import Path
import sys
import unittest

path = Path(__file__).resolve().parents[1] / 'tools/simulator-regression'
sys.path.insert(0, str(path))
spec = importlib.util.spec_from_file_location('timer_controls', path / 'timer_controls.py')
controls = importlib.util.module_from_spec(spec)
spec.loader.exec_module(controls)


class TimerControlEvidenceChecks(unittest.TestCase):
    def row(self, text, y, confidence=1):
        return dict(text=text, y=y, confidence=confidence)

    def test_visible_controls_have_no_text_warning(self):
        self.assertEqual(controls.missing_labels([
            self.row('Class v', .1), self.row('Stop count', .77)], True), [])

    def test_clock_only_frame_flags_both_controls(self):
        self.assertEqual(controls.missing_labels([self.row('00:30', .1)], True), ['Class', 'Stop count'])

    def test_wrong_region_and_uncertain_text_cannot_pass(self):
        self.assertEqual(controls.missing_labels([
            self.row('Class', .7), self.row('Stop count', .77, .5)], True), ['Class', 'Stop count'])

    def test_narrow_fallback_and_foreground_occlusion_are_distinct(self):
        self.assertEqual(controls.missing_labels([
            self.row('Class', .1), self.row('Count', .77)], False), [])
        self.assertEqual(controls.missing_labels([
            self.row('Class', .1), self.row('Sto', .77)], True), ['Stop count'])


def interface_event(name, elapsed, reduced, launch='launch'):
    # Same-second timestamps deliberately require monotonic ordering.
    return dict(event=name, timestamp='2026-11-02T22:53:46Z', details=dict(
        launchID=launch, launchElapsedSeconds=str(elapsed), luminanceReduced=str(reduced).lower()))


class FakeClock:
    def __init__(self):
        self.now = 0

    def sleep(self, seconds):
        self.now += seconds


class TimerDisplayTransitionChecks(unittest.TestCase):
    def setUp(self):
        self.clock = FakeClock()
        self.runtime = [interface_event('interface_appeared', 0.1, False)]
        self.interface = []
        self.toggles = 0
        self.report = {}

    def toggle(self):
        self.toggles += 1

    def ensure(self, reduced, toggle=None):
        return controls.ensure_luminance(reduced, lambda: (self.runtime, self.interface),
            toggle or self.toggle, 'launch', timeout=1, monotonic=lambda: self.clock.now,
            sleep=self.clock.sleep, report=self.report)

    def test_already_desired_observation_needs_no_toggle(self):
        self.assertEqual(self.ensure(False)['status'], 'already_observed')
        self.interface.append(interface_event('luminance_changed', 10.2, True))
        self.assertEqual(self.ensure(True)['status'], 'already_observed')
        self.assertEqual(self.toggles, 0)

    def test_one_toggle_requires_new_desired_observation(self):
        def toggle():
            self.toggle()
            self.interface.append(interface_event('luminance_changed', 0.2, True))
        report = self.ensure(True, toggle)
        self.assertEqual(report['status'], 'confirmed_transition')
        self.assertGreater(report['after']['launchElapsedSeconds'], report['before']['launchElapsedSeconds'])
        self.assertEqual(self.toggles, 1)
        # Requesting that state again must not toggle it back.
        self.assertEqual(self.ensure(True)['status'], 'already_observed')
        self.assertEqual(self.toggles, 1)

    def test_delayed_journal_observation_waits_without_repeated_input(self):
        def journals():
            if self.clock.now >= .4 and not self.interface:
                self.interface.append(interface_event('luminance_changed', 0.2, True))
            return self.runtime, self.interface
        report = controls.ensure_luminance(True, journals, self.toggle, 'launch', timeout=1,
            monotonic=lambda: self.clock.now, sleep=self.clock.sleep)
        self.assertEqual(report['status'], 'confirmed_transition')
        self.assertEqual(self.toggles, 1)
        self.assertEqual(self.clock.now, .4)

    def test_wake_uses_toggle_and_explicit_false_state(self):
        self.interface.append(interface_event('luminance_changed', 10.2, True))
        def toggle():
            self.toggle()
            self.interface.append(interface_event('scene_state_changed', 10.3, True))
            self.interface.append(interface_event('luminance_changed', 10.4, False))
        self.assertEqual(self.ensure(False, toggle)['status'], 'confirmed_transition')
        self.assertEqual(self.toggles, 1)

    def test_missing_or_foreign_launch_evidence_does_not_license_toggle(self):
        for runtime, interface in [([], []),
                ([interface_event('interface_appeared', 0.1, False, 'old')],
                 [interface_event('luminance_changed', 0.2, True, 'old')])]:
            with self.subTest(runtime=runtime):
                self.runtime, self.interface = runtime, interface
                self.clock.now = 0
                with self.assertRaisesRegex(RuntimeError, 'No current-launch'):
                    self.ensure(True)
                self.assertEqual(self.toggles, 0)
                self.assertEqual(self.report['status'], 'failed')

    def test_new_launch_prevents_reusing_stale_old_launch_observation(self):
        self.runtime.append(interface_event('interface_appeared', 0.1, False, 'new-launch'))
        with self.assertRaisesRegex(RuntimeError, 'No current-launch'):
            self.ensure(False)
        self.assertEqual(self.toggles, 0)

    def test_failed_transition_is_bounded_and_never_toggles_again(self):
        with self.assertRaisesRegex(RuntimeError, 'after one toggle'):
            self.ensure(True)
        self.assertEqual(self.toggles, 1)
        self.assertLessEqual(self.clock.now, 1)
        self.assertEqual(self.report['status'], 'failed')
        self.assertNotIn('after', self.report)

    def test_stale_desired_event_cannot_confirm_a_transition(self):
        self.interface.append(interface_event('luminance_changed', 5.2, False))
        def toggle():
            self.toggle()
            self.interface.append(interface_event('luminance_changed', 5.1, True))
        with self.assertRaisesRegex(RuntimeError, 'after one toggle'):
            self.ensure(True, toggle)
        self.assertEqual(self.toggles, 1)
        self.assertFalse(self.report['lastObservation']['luminanceReduced'])

    def test_scene_activity_or_unrelated_event_is_not_luminance_evidence(self):
        def toggle():
            self.toggle()
            self.interface.append(dict(event='scene_state_changed', details=dict(
                launchID='launch', launchElapsedSeconds='0.2', sceneState='inactive')))
            self.interface.append(interface_event('tap_requested', 0.3, True))
        with self.assertRaisesRegex(RuntimeError, 'after one toggle'):
            self.ensure(True, toggle)
        self.assertEqual(self.toggles, 1)

    def test_conflicting_same_elapsed_state_cannot_be_claimed(self):
        self.interface.extend([interface_event('luminance_changed', 2.1, True),
                               interface_event('luminance_changed', 2.1, False)])
        with self.assertRaisesRegex(RuntimeError, 'No current-launch'):
            self.ensure(True)
        self.assertEqual(self.toggles, 0)

    def test_failed_input_is_not_retried_or_marked_complete(self):
        def toggle():
            self.toggle()
            raise RuntimeError('Device Hub unavailable')
        with self.assertRaisesRegex(RuntimeError, 'Device Hub unavailable'):
            self.ensure(True, toggle)
        self.assertEqual(self.toggles, 1)
        self.assertEqual(self.report['status'], 'failed')
