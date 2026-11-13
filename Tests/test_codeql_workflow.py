# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / '.github/workflows/codeql.yml').read_text(encoding='utf-8')


def run_script(step_name):
    """Execute the actual workflow shell, rather than duplicating its routing."""
    step = WORKFLOW.split(f'- name: {step_name}\n', 1)[1]
    match = re.search(r'        run: \|\n((?:          .*\n|\n)+)', step)
    if match is None:
        raise AssertionError(f'Missing workflow script: {step_name}')
    return textwrap.dedent(match[1])


class CodeQLWorkflowChecks(unittest.TestCase):
    def test_workflow_shell_routes_whole_push_and_pr_ranges(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'scripts').mkdir()
            for name in ('codeql-impact.py', 'change-impact.py'):
                shutil.copyfile(ROOT / 'scripts' / name, root / 'scripts' / name)

            def git(*args):
                return subprocess.check_output(['git', *args], cwd=root, text=True,
                                               stderr=subprocess.PIPE).strip()

            def commit(path, content):
                file = root / path
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text(content, encoding='utf-8')
                git('add', '.')
                git('commit', '--no-gpg-sign', '-qm', 'Routing fixture')
                return git('rev-parse', 'HEAD')

            git('init', '--quiet')
            git('config', 'user.name', 'Workflow Test')
            git('config', 'user.email', 'test@example.invalid')
            base = commit('README.md', 'Initial\n')
            app = commit('TeachingTimer/Face.swift', 'struct Face {}\n')
            docs = commit('README.md', 'Updated\n')
            # Moving production code into tools must retain its deleted old path.
            (root / 'tools').mkdir()
            git('mv', 'TeachingTimer/Face.swift', 'tools/Face.swift')
            git('commit', '--no-gpg-sign', '-qm', 'Move production fixture')
            moved = git('rev-parse', 'HEAD')
            cases = [
                ('push', base, app, '', '', 'true'),
                ('push', app, docs, '', '', 'false'),
                ('pull_request', '', docs, base, docs, 'true'),
                ('push', docs, moved, '', '', 'true'),
                ('push', '0' * 40, docs, '', '', 'true'),
                ('push', 'unavailable-history', docs, '', '', 'true'),
                ('push', '', docs, '', '', 'true'),
                ('pull_request', '', docs, '', '', 'true'),
                ('schedule', app, docs, app, docs, 'true'),
                ('workflow_dispatch', app, docs, app, docs, 'true'),
                ('unknown-event', app, docs, app, docs, 'true'),
            ]
            for index, (event, before, head, pr_base, pr_head, expected) in enumerate(cases):
                with self.subTest(event=event, before=before):
                    output = root / f'output-{index}'
                    environment = dict(os.environ, EVENT_NAME=event, PUSH_BEFORE=before,
                                       GITHUB_SHA=head, PR_BASE=pr_base, PR_HEAD=pr_head,
                                       GITHUB_OUTPUT=str(output))
                    subprocess.run(['bash', '-e', '-c', run_script('Classify complete change range')],
                                   cwd=root, env=environment, check=True, capture_output=True, text=True)
                    values = dict(line.split('=', 1) for line in output.read_text().splitlines())
                    self.assertEqual(values['swift_changed'], expected)
                    if event in ('schedule', 'workflow_dispatch', 'unknown-event'):
                        self.assertEqual(values['reason'], 'forced-full')

    def test_result_gate_accepts_only_successful_applicable_analyses(self):
        cases = [
            ('success', 'success', 'success', 'true', True),
            ('success', 'success', 'skipped', 'false', True),
            ('success', 'success', 'skipped', 'true', False),
            ('success', 'failure', 'skipped', 'false', False),
            ('failure', 'success', 'success', 'true', False),
            ('success', 'success', 'failure', 'true', False),
            ('success', 'success', 'cancelled', 'true', False),
            ('success', 'success', 'skipped', '', False),
            ('success', 'success', 'success', 'malformed', False),
            ('success', 'success', 'success', 'false', False),
        ]
        for routing, interpreted, swift, changed, expected in cases:
            with self.subTest(routing=routing, interpreted=interpreted, swift=swift, changed=changed):
                environment = dict(os.environ, CHANGES_RESULT=routing, INTERPRETED_RESULT=interpreted,
                                   SWIFT_RESULT=swift, SWIFT_CHANGED=changed, ROUTING_REASON='test')
                result = subprocess.run(['bash', '-e', '-c', run_script('Require all applicable analyses')],
                                        env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, expected)

    def test_security_and_coverage_workflow_bindings(self):
        self.assertIn("- cron: '23 9 * * 2'", WORKFLOW)
        self.assertIn('  workflow_dispatch:', WORKFLOW)
        self.assertIn('          fetch-depth: 0', WORKFLOW)
        self.assertIn('PR_BASE: ${{ github.event.pull_request.base.sha }}', WORKFLOW)
        self.assertIn('PR_HEAD: ${{ github.event.pull_request.head.sha }}', WORKFLOW)
        interpreted = WORKFLOW.split('  interpreted:\n', 1)[1].split('  swift:\n', 1)[0]
        self.assertNotIn('needs:', interpreted)
        self.assertIn('language: [actions, python]', interpreted)
        swift = WORKFLOW.split('  swift:\n', 1)[1].split('  required-result:\n', 1)[0]
        self.assertIn("needs.changes.result != 'success' || needs.changes.outputs.swift_changed != 'false'", swift)
        self.assertIn('build-mode: autobuild', swift)
        self.assertIn('github/codeql-action/autobuild@', swift)
        self.assertIn('category: /language:swift', swift)
        self.assertIn("github.event_name == 'pull_request' && github.ref || github.sha", WORKFLOW)
        self.assertIn('if: always()', WORKFLOW)
        for forbidden in ('pull_request_target:', 'secrets.', 'environment:', 'queries:',
                          'paths-ignore:', 'disable-default-queries:', 'source-root:'):
            self.assertNotIn(forbidden, WORKFLOW)


if __name__ == '__main__':
    unittest.main()
