# SPDX-License-Identifier: MPL-2.0
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('catalog', Path(__file__).resolve().parents[1] / 'scripts/catalog-local-artifacts.py')
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)


class CatalogChecks(unittest.TestCase):
    def test_metadata_preserves_originals_and_excludes_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            incident = root / 'support' / 'test'
            incident.mkdir(parents=True)
            original = incident / 'RuntimeDiagnostics.json'
            original.write_bytes(b'not parsed: private original')
            (incident / 'DerivedData').mkdir()
            before = original.stat().st_mtime_ns
            report = catalog.write_catalog(root, root / 'maintenance' / 'new')
            row = report['items'][0]
            self.assertEqual(row['files'], 1)
            self.assertEqual(row['evidence'], ['support/test/RuntimeDiagnostics.json'])
            self.assertEqual(row['generatedDirectories'], ['support/test/DerivedData'])
            self.assertEqual(original.stat().st_mtime_ns, before)
            self.assertEqual(original.read_bytes(), b'not parsed: private original')
            with self.assertRaises(FileExistsError):
                catalog.write_catalog(root, root / 'maintenance' / 'new')

    def test_symlinks_are_listed_without_external_traversal(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'work'; root.mkdir()
            outside = root.parent / 'private'; outside.mkdir()
            (outside / 'secret').write_text('do not read')
            (root / 'link').symlink_to(outside, target_is_directory=True)
            rows = catalog.inventory(root, root / 'output')
            self.assertEqual(rows[0]['files'], 0)
            self.assertEqual(rows[0]['links'], ['link'])


if __name__ == '__main__':
    unittest.main()
