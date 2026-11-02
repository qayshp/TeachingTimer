# SPDX-License-Identifier: MPL-2.0
"""Published Markdown anchor regressions; no network or device access."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('repository_link_checks', Path(__file__).resolve().parents[1] / 'scripts/check-repository.py')
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class RepositoryLinkChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def write(self, name, body):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body)
        return name

    def test_clock_reproduction_fragment_rejects_a_misspelled_heading(self):
        names = [self.write('README.md', '[clock](docs/clock.md#november-2-watchos-272-reproduction)'),
                 self.write('docs/clock.md', '## November 2: watchOS 27.2 reproduction\n')]
        self.assertEqual(checker.check_files(self.root, names), [])
        # The first target is the actual stale V1-review link; the second checks
        # that punctuation is removed rather than turned into an extra hyphen.
        for fragment in ['november-2-watchos-272-comparison', 'november-2-watchos-27-2-reproduction']:
            with self.subTest(fragment=fragment):
                self.write('README.md', f'[clock](docs/clock.md#{fragment})')
                errors = checker.check_files(self.root, names)
                self.assertEqual(len(errors), 1)
                self.assertIn('heading fragment', errors[0])
                self.assertIn('README.md', errors[0])

    def test_same_document_fragment_is_case_sensitive(self):
        name = self.write('README.md', '# Class options\n[here](#class-options)\n')
        self.assertEqual(checker.check_files(self.root, [name]), [])
        self.write('README.md', '# Class options\n[wrong](#Class-options)\n')
        self.assertEqual(len(checker.check_files(self.root, [name])), 1)

    def test_duplicate_headings_and_colliding_numbered_heading(self):
        body = '# Runtime\n# Runtime\n# Runtime-1\n# Runtime\n'
        links = '[one](#runtime) [two](#runtime-1) [collision](#runtime-1-1) [three](#runtime-2)'
        name = self.write('README.md', body + links)
        self.assertEqual(checker.check_files(self.root, [name]), [])
        self.write('README.md', body + links + ' [missing](#runtime-3)')
        self.assertEqual(len(checker.check_files(self.root, [name])), 1)

    def test_inline_code_punctuation_and_repeated_spaces_match_github_slugs(self):
        name = self.write('README.md', '# `ClassContext` / Start\n## Count — visual-only ###\n'
                          '[class](#classcontext--start) [count](#count--visual-only)')
        self.assertEqual(checker.check_files(self.root, [name]), [])

    def test_encoded_paths_fragments_and_html_links(self):
        names = [self.write('README.md', '[encoded](docs/Two%20words.md#class%2Doptions) '
                            '<a href="docs/Two%20words.md#class-options">same</a>'),
                 self.write('docs/Two words.md', '## Class options\n')]
        self.assertEqual(checker.check_files(self.root, names), [])
        self.write('README.md', '<a href="docs/Two%20words.md#missing">bad</a>')
        self.assertEqual(len(checker.check_files(self.root, names)), 1)

    def test_fenced_examples_neither_supply_anchors_nor_create_broken_links(self):
        name = self.write('README.md', '# Visible\n```markdown\n# Visible\n[bad](#absent)\n```\n'
                          '~~~~\n# Also hidden\n[bad](missing.md#absent)\n~~~~\n[good](#visible)')
        self.assertEqual(checker.check_files(self.root, [name]), [])
        with (self.root / name).open('a') as file:
            file.write('\n[not-a-heading](#visible-1)')
        self.assertEqual(len(checker.check_files(self.root, [name])), 1)

    def test_external_urls_and_nonmarkdown_fragments_keep_existing_behavior(self):
        names = [self.write('README.md', '[site](https://example.com/guide.md#missing) '
                            '[mail](mailto:hello@example.com) [source](code.py#part)'),
                 self.write('code.py', '# SPDX-License-Identifier: MPL-2.0\n')]
        self.assertEqual(checker.check_files(self.root, names), [])


if __name__ == '__main__':
    unittest.main()
