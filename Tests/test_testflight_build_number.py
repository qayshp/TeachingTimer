# SPDX-License-Identifier: MPL-2.0
import importlib.util
from datetime import datetime, timezone, tzinfo
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

    def test_uses_standard_time_even_during_summer(self):
        instant = datetime(2026, 7, 5, 17, 7, tzinfo=timezone.utc)
        self.assertEqual(build_number.automatic_build_number(8, instant), '260705.0907.8')

    def test_timestamp_advances_across_pacific_daylight_saving_fall_back(self):
        before = datetime(2026, 11, 1, 8, 59, tzinfo=timezone.utc)
        after = datetime(2026, 11, 1, 9, 0, tzinfo=timezone.utc)
        self.assertEqual(build_number.automatic_build_number(50, before), '261101.0059.50')
        self.assertEqual(build_number.automatic_build_number(51, after), '261101.0100.51')

    def test_year_rolls_over_at_midnight_pacific_standard_time(self):
        before = datetime(2027, 1, 1, 7, 59, tzinfo=timezone.utc)
        after = datetime(2027, 1, 1, 8, 0, tzinfo=timezone.utc)
        self.assertEqual(build_number.automatic_build_number(80, before), '261231.2359.80')
        self.assertEqual(build_number.automatic_build_number(81, after), '270101.0000.81')

    def test_run_number_disambiguates_same_minute_builds(self):
        instant = datetime(2026, 11, 4, 23, 59, tzinfo=timezone.utc)
        self.assertEqual(build_number.automatic_build_number(23, instant), '261104.1559.23')
        self.assertEqual(build_number.automatic_build_number(24, instant), '261104.1559.24')

    def test_rejects_invalid_run_number_or_naive_time(self):
        for value in (0, -1, True, '5'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                build_number.automatic_build_number(value, datetime(2026, 1, 1, tzinfo=timezone.utc))
        with self.assertRaises(ValueError):
            build_number.automatic_build_number(1, datetime(2026, 1, 1))

    def test_rejects_timezone_without_an_offset(self):
        class UnknownOffset(tzinfo):
            def utcoffset(self, instant):
                return None

        with self.assertRaises(ValueError):
            build_number.automatic_build_number(1, datetime(2026, 1, 1, tzinfo=UnknownOffset()))

    def test_reruns_use_the_original_creation_instant(self):
        run = dict(id=123, run_number=8, head_sha='b' * 40, event='push', head_branch='main',
                   created_at='2026-11-29T02:02:03Z', run_attempt=1, run_started_at='2026-11-29T02:03:04Z')
        self.assertEqual(build_number.automatic_build_number_for_run(run, 123, 8, 'b' * 40), '261128.1802.8')
        run.update(run_attempt=2, run_started_at='2026-11-30T16:03:04Z')
        self.assertEqual(build_number.automatic_build_number_for_run(run, 123, 8, 'b' * 40), '261128.1802.8')

    def test_run_metadata_must_match_and_provide_zoned_creation_time(self):
        run = dict(id=123, run_number=8, head_sha='b' * 40, event='push', head_branch='main',
                   created_at='2026-11-29T02:02:03Z')
        for key, value in (('id', 124), ('run_number', 9), ('head_sha', 'c' * 40), ('event', 'workflow_dispatch'),
                           ('head_branch', 'feature'), ('created_at', '2026-11-29T02:02:03'), ('created_at', None)):
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                build_number.automatic_build_number_for_run(dict(run, **{key: value}), 123, 8, 'b' * 40)
