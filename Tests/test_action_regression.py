# SPDX-License-Identifier: MPL-2.0
import importlib.util
from pathlib import Path
import sys
import unittest

path = Path(__file__).resolve().parents[1] / 'tools/simulator-regression'
sys.path.insert(0, str(path))
spec = importlib.util.spec_from_file_location('essential_actions', path / 'actions.py')
actions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(actions)

class ActionTargetChecks(unittest.TestCase):
    def row(self, text, y=.5, confidence=1):
        return dict(text=text, x=.5, y=y, confidence=confidence)
    def test_title_and_clipped_rows_are_not_buttons(self):
        self.assertIsNone(actions.choose_text([self.row('Start', .15), self.row('Start', .98)], ['Start']))
    def test_ambiguous_and_uncertain_targets_fail_closed(self):
        with self.assertRaises(ValueError):
            actions.choose_text([self.row('End class', .5), self.row('End class', .7)], ['End class'])
        self.assertIsNone(actions.choose_text([self.row('End class', confidence=.5)], ['End class']))
    def test_confirmation_requires_lower_button(self):
        target = self.row('End class', .7)
        self.assertEqual(actions.choose_text([self.row('End class', .3), target], ['End class'], .45), target)
    def test_known_icon_prefix_is_not_arbitrary_fuzzy_matching(self):
        target = self.row('Il Stop session')
        self.assertEqual(actions.choose_text([target], ['Stop session']), target)
        self.assertIsNone(actions.choose_text([self.row('Do not Stop session')], ['Stop session']))
