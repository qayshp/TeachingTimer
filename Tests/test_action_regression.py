# SPDX-License-Identifier: MPL-2.0
import importlib.util
import json
import plistlib
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

    def test_observed_icon_aliases_are_exact_and_still_reject_ambiguity(self):
        for name in ('Settings', 'About'):
            target = dict(self.row('O ' + name, confidence=.5), recognitionLevel='fast', corroborated=True)
            self.assertEqual(actions.choose_text([target], [name]), target)
            self.assertIsNone(actions.choose_text([dict(target, corroborated=False)], [name]))
            with self.assertRaises(ValueError):
                actions.choose_text([target, self.row(name)], [name])
        for text in ('O End class', 'O Other Settings', 'Do not Settings'):
            self.assertIsNone(actions.choose_text([self.row(text)], ['End class', 'Settings']))

    def test_fast_targets_require_exact_corroborated_unambiguous_labels(self):
        target = dict(self.row('Start class', confidence=.5), recognitionLevel='fast', corroborated=True)
        self.assertEqual(actions.choose_text([target], ['Start class']), target)
        for changed in (dict(corroborated=False), dict(confidence=.49), dict(text='Start classes'), dict(y=.98)):
            self.assertIsNone(actions.choose_text([dict(target, **changed)], ['Start class']))
        with self.assertRaises(ValueError):
            actions.choose_text([target, dict(target, y=.7)], ['Start class'])

class RetirementFixtureChecks(unittest.TestCase):
    def test_seed_has_one_fixed_future_retirement_and_stopped_intent(self):
        now = 1800000000.25
        values = plistlib.loads(plistlib.dumps(actions.retiring_preferences(now)))
        context = json.loads(values[actions.KEY])
        intent = json.loads(values['teachingRuntimeIntent.v1'])
        self.assertEqual(context['initialStartPressedAt'] + actions.REFERENCE_DATE_OFFSET, now)
        self.assertEqual(context['scheduledStart'] + 60 * 60 + 30 * 60 + actions.REFERENCE_DATE_OFFSET, now + 90)
        self.assertEqual(intent, dict(classID=context['initialStartPressedAt'], state='stopped'))

    def test_unbounded_or_unusable_deadlines_rejected(self):
        for delay in (-1, 0, 19, 91, 10000):
            with self.assertRaises(ValueError):
                actions.retiring_preferences(1800000000, delay)

    def test_each_fixture_is_a_different_class(self):
        first = json.loads(actions.retiring_preferences(1800000000)[actions.KEY])
        second = json.loads(actions.retiring_preferences(1800000090)[actions.KEY])
        self.assertNotEqual(first['initialStartPressedAt'], second['initialStartPressedAt'])
