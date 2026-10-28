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
