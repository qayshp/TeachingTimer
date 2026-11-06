# SPDX-License-Identifier: MPL-2.0
import importlib.util
from pathlib import Path
import tempfile
import shlex
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
        path.write_text(text if not text or text.endswith("\n") else text + "\n")
        return name

    def test_published_links_and_encoded_paths(self):
        names = [self.write('docs/readme.md', '## Section\n[source](../code.py#part) [image](<two words.png>) [section](#section) [site](https://example.com/missing) [folder](../docs/)'),
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

    def test_raw_captures_and_journals_cannot_escape_work_exclusion(self):
        names = [self.write('RuntimeDiagnostics.json', '[]'),
                 self.write('capture.tar.gz', 'private'),
                 self.write('system_logs.logarchive/metadata', 'private')]
        errors = checker.check_files(self.root, names)
        self.assertEqual(len(errors), 3)
        self.assertTrue(all('must not be published' in error for error in errors))

    def test_force_added_credentials_and_generated_products_are_rejected(self):
        cases = ['.env', 'config/.env.production', 'signing/login.keychain-db', 'signing/login.keychain',
                 'release.ipa', 'release.dSYM.zip', 'Results.xcresult/Info.plist',
                 'DerivedData-local/build-setting.txt', '.build/package-cache', 'build/product',
                 'workspace.xcuserstate', 'helper.pyc']
        for name in cases:
            with self.subTest(name=name):
                # The published-file guard must work even if git add --force
                # bypassed .gitignore. Do not place actual credentials here.
                self.assertTrue(checker.private_artifact(name))
        self.assertFalse(checker.private_artifact('config/.env.example'))
        self.assertFalse(checker.private_artifact('scripts/DerivedDataInfo.swift'))
        self.assertFalse(checker.private_artifact('TeachingTimer/Assets.xcassets/Contents.json'))
        self.assertFalse(checker.private_artifact('TeachingTimer.xcodeproj/xcshareddata/xcschemes/TeachingTimer.xcscheme'))

    def test_source_hygiene_reports_file_and_line(self):
        errors = checker.source_hygiene('source.swift', '\tlet value = 1 \r\nlet other = 2')
        self.assertEqual(len(errors), 4)
        self.assertTrue(any('LF line endings' in error for error in errors))
        self.assertTrue(any('final newline' in error for error in errors))
        self.assertTrue(any('source.swift:1: remove trailing' in error for error in errors))
        self.assertTrue(any('source.swift:1: use spaces' in error for error in errors))
        self.assertEqual(checker.source_hygiene('source.swift', '    let value = 1\n'), [])

    def test_tracked_shell_is_parsed_without_executing(self):
        marker = self.root / 'SHOULD_NOT_EXIST'
        name = self.write('script.sh', '# SPDX-License-Identifier: MPL-2.0\ntouch ' + shlex.quote(str(marker)))
        self.assertEqual(checker.check_files(self.root, [name]), [])
        self.assertFalse(marker.exists())
        self.write('script.sh', '# SPDX-License-Identifier: MPL-2.0\nif true; then')
        self.assertIn('shell syntax', checker.check_files(self.root, [name])[0])

    def test_source_hygiene_does_not_change_markdown_hard_breaks(self):
        name = self.write('README.md', 'A line  \nAnother line\n')
        self.assertEqual(checker.check_files(self.root, [name]), [])

    def test_python_syntax_errors_fail(self):
        name = self.write('tool.py', '# SPDX-License-Identifier: MPL-2.0\nif True print(1)')
        self.assertIn('SyntaxError', checker.check_files(self.root, [name])[0])

    def test_private_artifacts_and_missing_tracked_files_fail(self):
        names = [self.write('work/journal.json', '[]'), self.write('signing.mobileprovision', 'private'), 'absent.md']
        self.assertEqual(len(checker.check_files(self.root, names)), 3)


if __name__ == '__main__':
    unittest.main()
