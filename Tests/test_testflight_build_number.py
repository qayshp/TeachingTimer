# SPDX-License-Identifier: MPL-2.0
import importlib.util
from datetime import datetime, timezone
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    'testflight_build_number', Path(__file__).parents[1] / 'scripts' / 'testflight_build_number.py')
build_number = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(build_number)


class AutomaticBuildNumberTests(unittest.TestCase):
    def test_converts_utc_to_pacific_standard_time(self):
        instant = datetime(2026, 1, 5, 17, 7, tzinfo=timezone.utc)
        self.assertEqual(build_number.automatic_build_number(7, instant), '260105.0907.7')

    def test_converts_utc_to_pacific_daylight_time(self):
        instant = datetime(2026, 7, 5, 17, 7, tzinfo=timezone.utc)
        self.assertEqual(build_number.automatic_build_number(8, instant), '260705.1007.8')

    def test_run_number_disambiguates_same_minute_builds(self):
        instant = datetime(2026, 11, 4, 23, 59, tzinfo=timezone.utc)
        self.assertEqual(build_number.automatic_build_number(23, instant), '261104.1559.23')
        self.assertEqual(build_number.automatic_build_number(24, instant), '261104.1559.24')

    def test_rejects_invalid_run_number_or_naive_time(self):
        for value in (0, -1, True, '5'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                build_number.automatic_build_number(value)
        with self.assertRaises(ValueError):
            build_number.automatic_build_number(1, datetime(2026, 1, 1))
