# SPDX-License-Identifier: MPL-2.0
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('repository_checks', Path(__file__).resolve().parents[1] / 'scripts/check-repository.py')
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class RepositoryChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return name

    def test_published_links_and_encoded_paths(self):
        names = [self.write('docs/readme.md', '[source](../code.py#part) [image](<two words.png>) [section](#section) [site](https://example.com/missing) [folder](../docs/)'),
                 self.write('code.py', '# SPDX-License-Identifier: MPL-2.0'), self.write('docs/two words.png', '')]
        self.assertEqual(checker.check_files(self.root, names), [])
        self.write('docs/readme.md', '![encoded](two%20words.png)')
        self.assertEqual(checker.check_files(self.root, names), [])

    def test_untracked_existing_file_does_not_make_public_link_valid(self):
        self.write('secret.md', 'private')
        name = self.write('README.md', '[private](secret.md) [outside](../outside.md)')
        errors = checker.check_files(self.root, [name])
        self.assertEqual(len(errors), 2)
        self.assertIn('not in published repository', errors[0])
        self.assertIn('leaves repository', errors[1])

    def test_fenced_examples_are_not_links(self):
        name = self.write('README.md', '```markdown\n[example](not-real.md)\n```\n[real](missing.md)\n')
        errors = checker.check_files(self.root, [name])
        self.assertEqual(len(errors), 1)
        self.assertIn('missing.md', errors[0])

    def test_html_images_and_links_require_published_targets(self):
        names = [self.write('README.md', '<img src="docs/face.png"> <a href="docs/guide.md">Guide</a>'),
                 self.write('docs/face.png', '')]
        self.assertEqual(len(checker.check_files(self.root, names)), 1)
        names.append(self.write('docs/guide.md', 'Guide'))
        self.assertEqual(checker.check_files(self.root, names), [])

    def test_top_level_guides_must_be_indexed(self):
        names = [self.write('docs/README.md', '# Map'), self.write('docs/GUIDE.md', 'Guide')]
        self.assertIn('not linked', checker.check_files(self.root, names)[0])
        self.write('docs/README.md', '[Guide](GUIDE.md)')
        self.assertEqual(checker.check_files(self.root, names), [])

    def test_malformed_configuration_and_missing_notice(self):
        names = [self.write('config.json', '{bad'), self.write('Info.plist', 'broken'), self.write('tool.py', 'print(1)')]
        errors = checker.check_files(self.root, names)
        self.assertEqual(len(errors), 3)
        self.assertTrue(any('missing MPL' in e for e in errors))

    def test_new_swift_suite_must_be_wired_into_check_script(self):
        names = [self.write('Tests/NewChecks.swift', '// SPDX-License-Identifier: MPL-2.0'),
                 self.write('scripts/check.sh', '# SPDX-License-Identifier: MPL-2.0')]
        self.assertIn('not wired', checker.check_files(self.root, names)[0])
        self.write('scripts/check.sh', '# SPDX-License-Identifier: MPL-2.0\n# check New Tests/NewChecks.swift')
        self.assertIn('not wired', checker.check_files(self.root, names)[0])
        self.write('scripts/check.sh', '# SPDX-License-Identifier: MPL-2.0\ncheck New Tests/NewChecks.swift')
        self.assertEqual(checker.check_files(self.root, names), [])

    def test_python_syntax_errors_fail(self):
        name = self.write('tool.py', '# SPDX-License-Identifier: MPL-2.0\nif True print(1)')
        self.assertIn('SyntaxError', checker.check_files(self.root, [name])[0])

    def test_private_artifacts_and_missing_tracked_files_fail(self):
        names = [self.write('work/journal.json', '[]'), self.write('signing.mobileprovision', 'private'), 'absent.md']
        self.assertEqual(len(checker.check_files(self.root, names)), 3)


if __name__ == '__main__':
    unittest.main()
