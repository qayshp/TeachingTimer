# SPDX-License-Identifier: MPL-2.0
"""Receipt verification uses bytes actually saved by a sharing recipient."""

import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

MODULE_PATH = Path(__file__).resolve().parents[1] / 'tools/diagnostic-share-probe/fixtures.py'
SPEC = importlib.util.spec_from_file_location('diagnostic_share_fixtures', MODULE_PATH)
assert SPEC and SPEC.loader
fixtures = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fixtures)


class SharingFixtureChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.source = Path(cls.directory.name) / 'source'
        cls.manifest = fixtures.generate(cls.source)

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def setUp(self):
        self.received_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.received_directory.cleanup)
        self.received = Path(self.received_directory.name)

    def copy_fixture(self, name='synthetic-report.json'):
        target = self.received / name
        shutil.copyfile(self.source / name, target)
        return target

    def test_exact_received_files_parse_and_match_manifest(self):
        for item in self.manifest['fixtures']:
            with self.subTest(name=item['file']):
                result = fixtures.verify(self.manifest, self.copy_fixture(item['file']), item['file'])
                self.assertTrue(result['verified'])
                self.assertTrue(result['parsed'])
                self.assertEqual(result['bytes'], item['bytes'])
                self.assertEqual(result['sha256'], item['sha256'])

    def test_fixture_generation_is_deterministic(self):
        repeated = fixtures.generate(self.received / 'second-generation')
        self.assertEqual(repeated, self.manifest)

    def test_report_is_realistically_sized_and_bounded(self):
        item = next(item for item in self.manifest['fixtures'] if item['file'] == 'synthetic-report.json')
        self.assertGreater(item['bytes'], 1024 * 1024)
        self.assertLessEqual(item['bytes'], fixtures.MAX_FIXTURE_BYTES)

    def test_changed_byte_fails_even_when_length_unchanged(self):
        path = self.copy_fixture()
        data = bytearray(path.read_bytes())
        data[-2] ^= 1
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            fixtures.verify(self.manifest, path, path.name)

    def test_truncated_received_file_fails(self):
        path = self.copy_fixture()
        path.write_bytes(path.read_bytes()[:-1])
        with self.assertRaisesRegex(ValueError, 'size'):
            fixtures.verify(self.manifest, path, path.name)

    def test_renamed_received_file_is_not_silently_accepted(self):
        path = self.copy_fixture()
        renamed = path.rename(self.received / 'renamed.json')
        with self.assertRaisesRegex(ValueError, 'Filename'):
            fixtures.verify(self.manifest, renamed, path.name)

    def test_unlisted_fixture_is_rejected(self):
        path = self.copy_fixture()
        with self.assertRaisesRegex(ValueError, 'exactly one'):
            fixtures.verify(self.manifest, path, 'unlisted.json')

    def test_manifest_requires_explicit_synthetic_marker(self):
        manifest = dict(self.manifest, syntheticOnly=False)
        path = self.copy_fixture()
        with self.assertRaisesRegex(ValueError, 'synthetic'):
            fixtures.verify(manifest, path, path.name)

    def test_missing_received_file_is_not_delivery(self):
        with self.assertRaises(FileNotFoundError):
            fixtures.verify(self.manifest, self.received / 'synthetic-report.json', 'synthetic-report.json')


if __name__ == '__main__':
    unittest.main()
