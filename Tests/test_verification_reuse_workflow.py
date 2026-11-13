# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Exercise the actual release workflow gates without GitHub, Xcode or credentials."""
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
RELEASE = (ROOT / '.github/workflows/testflight-release.yml').read_text()
WATCH = (ROOT / '.github/workflows/check.yml').read_text()
SPEC = importlib.util.spec_from_file_location('reuse_workflow_impact', ROOT / 'scripts/change-impact.py')
impact = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(impact)


def job(workflow, name):
    match = re.search(r'^  ' + re.escape(name) + r':\n(.*?)(?=^  [a-z][\w-]*:|\Z)', workflow, re.M | re.S)
    if match is None:
        raise AssertionError('Missing workflow job: ' + name)
    return match[1]


def field(block, name):
    match = re.search(r'^    ' + re.escape(name) + r':\s*([^\n]*)\n', block, re.M)
    if match is None:
        raise AssertionError('Missing job field: ' + name)
    value = match[1]
    if value in ('>-', '|', '>'):
        following = block[match.end():]
        return ' '.join(re.match(r'(?:      .*\n|\n)*', following)[0].split())
    return value


def step(block, name):
    match = re.search(r'^      - name: ' + re.escape(name) + r'\n(.*?)(?=^      - |\Z)', block, re.M | re.S)
    if match is None:
        raise AssertionError('Missing workflow step: ' + name)
    return match[1]


def shell(block):
    match = re.search(r'^        run: \|\n((?:          .*\n|\n)+)', block, re.M)
    if match is None:
        raise AssertionError('Missing workflow shell')
    return textwrap.dedent(match[1])


class Expression:
    """Small allowlisted GitHub-expression grammar, never Python eval.

    Only the operators/contexts used by these job gates are supported. Unknown
    syntax fails the test so a workflow edit cannot silently evade evaluation.
    """
    token = re.compile(r"\s*(?:('[^']*')|((?:needs|github|inputs)(?:\.[A-Za-z_][\w-]*)+)"
                       r"|(always|cancelled|success|failure)\(\)|(==|!=|&&|\|\||!|\(|\)))")

    def __init__(self, expression, context, statuses=()):
        expression = expression.strip()
        if expression.startswith('${{') and expression.endswith('}}'):
            expression = expression[3:-2].strip()
        self.tokens, self.index, self.status_function = [], 0, False
        position = 0
        while position < len(expression):
            match = self.token.match(expression, position)
            if match is None:
                raise AssertionError('Unsupported workflow expression: ' + expression[position:])
            quoted, reference, function, operator = match.groups()
            if quoted is not None:
                self.tokens.append(('value', quoted[1:-1]))
            elif reference is not None:
                value = context
                for part in reference.split('.'):
                    value = value.get(part, '') if isinstance(value, dict) else ''
                self.tokens.append(('value', value))
            elif function is not None:
                self.status_function = True
                value = {'always': True, 'cancelled': context.get('cancelled', False),
                         'success': all(s == 'success' for s in statuses),
                         'failure': any(s == 'failure' for s in statuses)}[function]
                self.tokens.append(('value', value))
            else:
                self.tokens.append((operator, operator))
            position = match.end()

    def take(self, kind):
        if self.index < len(self.tokens) and self.tokens[self.index][0] == kind:
            value = self.tokens[self.index][1]
            self.index += 1
            return True, value
        return False, None

    def value(self):
        value = self.disjunction()
        if self.index != len(self.tokens):
            raise AssertionError('Unconsumed workflow expression')
        return value

    def disjunction(self):
        value = self.conjunction()
        while self.take('||')[0]:
            other = self.conjunction()
            value = value if value else other
        return value

    def conjunction(self):
        value = self.comparison()
        while self.take('&&')[0]:
            other = self.comparison()
            value = other if value else value
        return value

    def comparison(self):
        value = self.primary()
        for operator in ('==', '!='):
            if self.take(operator)[0]:
                other = self.primary()
                # GitHub compares these string contexts without case sensitivity.
                left = value.casefold() if isinstance(value, str) else value
                right = other.casefold() if isinstance(other, str) else other
                return left == right if operator == '==' else left != right
        return value

    def primary(self):
        if self.take('!')[0]:
            return not self.primary()
        if self.take('(')[0]:
            value = self.disjunction()
            if not self.take(')')[0]:
                raise AssertionError('Missing workflow closing parenthesis')
            return value
        present, value = self.take('value')
        if not present:
            raise AssertionError('Missing workflow expression operand')
        return value


def eligible(workflow, name, context):
    block = job(workflow, name)
    needed = field(block, 'needs').strip('[]').replace(' ', '').split(',')
    statuses = [context.get('needs', {}).get(name, {}).get('result', '') for name in needed]
    expression = Expression(field(block, 'if'), context, statuses)
    value = expression.value()
    # GitHub implicitly applies success() unless an explicit status check is used.
    return bool(value) and (expression.status_function or all(s == 'success' for s in statuses))


def context(paths=('TeachingTimer/ContentView.swift',), event='push', mode=None):
    values = impact.classify_paths(paths)
    if event == 'workflow_dispatch':
        values.update(mac_verify=True, release_verify=True, publish=True)
    outputs = {key: 'true' if value else 'false' for key, value in values.items()}
    needed = {name: {'result': 'skipped'} for name in
              ('changes', 'source', 'verify-reused', 'verify', 'tooling-checks', 'workflow-lint')}
    needed['changes'] = {'result': 'success', 'outputs': outputs}
    if values['release_verify']:
        needed['source']['result'] = 'success'
        needed['verify-reused' if event == 'push' else 'verify']['result'] = 'success'
    if mode is None:
        mode = '' if event == 'push' else 'publish'
    return {'github': {'event_name': event}, 'inputs': {'mode': mode}, 'needs': needed}


class VerificationReuseRoutingChecks(unittest.TestCase):
    def test_production_and_unknown_pushes_require_only_reused_verification(self):
        for path in ('TeachingTimer/ContentView.swift', 'PhoneSupport/SupportApp.swift', 'new-build-input'):
            with self.subTest(path=path):
                data = context([path])
                self.assertTrue(eligible(RELEASE, 'source', data))
                self.assertTrue(eligible(RELEASE, 'verify-reused', data))
                self.assertFalse(eligible(RELEASE, 'verify', data))
                self.assertTrue(eligible(RELEASE, 'release', data))
                self.assertTrue(eligible(WATCH, 'verify', data))

    def test_docs_and_tooling_cannot_enter_source_reuse_or_signing_jobs(self):
        for path, watch_expected in (('README.md', False), ('scripts/testflight-release.py', False),
                                     ('tools/simulator-regression/ControlOutline.swift', True)):
            with self.subTest(path=path):
                data = context([path])
                for name in ('source', 'verify-reused', 'verify', 'release'):
                    self.assertFalse(eligible(RELEASE, name, data), name)
                self.assertEqual(eligible(WATCH, 'verify', data), watch_expected)
                self.assertEqual(eligible(RELEASE, 'tooling-checks', data), path != 'README.md')

    def test_manual_modes_require_a_fresh_full_check_and_skip_reuse(self):
        environment = field(job(RELEASE, 'release'), 'environment')
        for mode in ('rehearsal', 'publish'):
            with self.subTest(mode=mode):
                data = context(event='workflow_dispatch', mode=mode)
                self.assertTrue(eligible(RELEASE, 'source', data))
                self.assertFalse(eligible(RELEASE, 'verify-reused', data))
                self.assertTrue(eligible(RELEASE, 'verify', data))
                self.assertTrue(eligible(RELEASE, 'release', data))
                self.assertEqual(Expression(environment, data).value(),
                                 'testflight-rehearsal' if mode == 'rehearsal' else 'testflight-maintainer')
                self.assertIn('python3 scripts/change-impact.py --all', job(RELEASE, 'changes'))

    def test_rehearsal_cannot_execute_credential_or_publication_steps(self):
        release = job(RELEASE, 'release')
        credential_steps = ('Install temporary signing credentials', 'Compile API authentication helper',
                            'Publish, monitor processing, and assign only Maintainer pilot')
        for event, mode in (('push', ''), ('workflow_dispatch', 'publish'),
                            ('workflow_dispatch', 'rehearsal')):
            with self.subTest(event=event, mode=mode):
                data = context(event=event, mode=mode)
                publishes = event == 'push' or mode == 'publish'
                for name in credential_steps:
                    condition = re.search(r'^        if: (.+)$', step(release, name), re.M)[1]
                    self.assertEqual(bool(Expression(condition, data).value()), publishes)
                rehearsal = step(release, 'Rehearse without credentials or publishing API calls')
                condition = re.search(r'^        if: (.+)$', rehearsal, re.M)[1]
                self.assertEqual(bool(Expression(condition, data).value()), mode == 'rehearsal')
                self.assertEqual(Expression(field(release, 'environment'), data).value(),
                                 'testflight-maintainer' if publishes else 'testflight-rehearsal')

    def test_workflow_cancellation_blocks_release_even_after_successful_verification(self):
        for event in ('push', 'workflow_dispatch'):
            data = context(event=event)
            self.assertTrue(eligible(RELEASE, 'release', data))
            data['cancelled'] = True
            self.assertFalse(eligible(RELEASE, 'release', data))

    def test_failed_cancelled_skipped_or_missing_required_checks_block_signing(self):
        for event in ('push', 'workflow_dispatch'):
            required = ('changes', 'source', 'verify-reused' if event == 'push' else 'verify')
            for name in required:
                for result in ('failure', 'cancelled', 'skipped', '', 'in_progress'):
                    with self.subTest(event=event, name=name, result=result):
                        data = context(event=event)
                        data['needs'][name]['result'] = result
                        self.assertFalse(eligible(RELEASE, 'release', data))
                data = context(event=event)
                del data['needs'][name]
                self.assertFalse(eligible(RELEASE, 'release', data))

    def test_implicit_dependency_success_blocks_source_and_verification(self):
        for result in ('failure', 'cancelled', 'skipped', ''):
            with self.subTest(result=result):
                data = context()
                data['needs']['changes']['result'] = result
                self.assertFalse(eligible(RELEASE, 'source', data))
                self.assertFalse(eligible(RELEASE, 'verify-reused', data))
                data = context(event='workflow_dispatch')
                data['needs']['source']['result'] = result
                self.assertFalse(eligible(RELEASE, 'verify', data))

    def test_lint_and_tool_failures_and_inconsistent_verification_paths_block_signing(self):
        for event in ('push', 'workflow_dispatch'):
            for name in ('tooling-checks', 'workflow-lint'):
                for result in ('failure', 'cancelled', '', 'in_progress'):
                    with self.subTest(event=event, name=name, result=result):
                        data = context(event=event)
                        data['needs'][name]['result'] = result
                        self.assertFalse(eligible(RELEASE, 'release', data))
                for result in ('success', 'skipped'):
                    data = context(event=event)
                    data['needs'][name]['result'] = result
                    self.assertTrue(eligible(RELEASE, 'release', data))
            other = 'verify' if event == 'push' else 'verify-reused'
            for result in ('success', 'failure', 'cancelled', ''):
                data = context(event=event)
                data['needs'][other]['result'] = result
                self.assertFalse(eligible(RELEASE, 'release', data))

    def test_missing_publish_permission_cannot_release_a_push(self):
        for value in ('false', '', 'invalid'):
            data = context()
            data['needs']['changes']['outputs']['publish'] = value
            self.assertFalse(eligible(RELEASE, 'release', data))

    def test_immutable_source_full_manual_smoke_and_credential_boundaries(self):
        source = job(RELEASE, 'source')
        self.assertIn('source_sha: ${{ steps.source.outputs.sha }}', source)
        self.assertIn('ref: ${{ github.sha }}', source)
        self.assertIn("if sha != os.environ['GITHUB_SHA']:", source)
        for name in ('verify', 'release'):
            self.assertIn('ref: ${{ needs.source.outputs.source_sha }}', job(RELEASE, name))
        self.assertNotIn('needs.verify.outputs.', RELEASE)
        self.assertIn('--simulator-smoke --prepare-ci-runtime', job(RELEASE, 'verify'))
        self.assertIn('runs-on: xcode-27', job(RELEASE, 'verify'))
        reuse = job(RELEASE, 'verify-reused')
        self.assertIn('ref: ${{ github.workflow_sha }}', reuse)
        self.assertIn('SOURCE_SHA: ${{ needs.source.outputs.source_sha }}', reuse)
        self.assertIn('--repository-id "$GITHUB_REPOSITORY_ID"', reuse)
        self.assertIn('--sha "$SOURCE_SHA"', reuse)
        self.assertNotIn('secrets.', reuse)
        self.assertNotIn('environment:', reuse)
        self.assertNotIn('continue-on-error:', reuse)
        self.assertNotIn('workflow_run:', RELEASE)
        self.assertNotIn('pull_request_target:', RELEASE)
        self.assertIn('if-no-files-found: error', job(WATCH, 'verify'))
        self.assertIn('verification-${{ github.sha }}-${{ github.run_attempt }}', job(WATCH, 'verify'))


class VerificationReuseReceiptChecks(unittest.TestCase):
    def test_receipt_outputs_are_exported_only_after_successful_reuse(self):
        code = shell(step(job(RELEASE, 'verify-reused'),
                          'Require completed exact-source Watch checks and evidence'))
        for exit_code in (0, 3):
            with self.subTest(exit_code=exit_code), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'scripts').mkdir()
                (root / 'reused-verification').mkdir()
                receipt = dict(runID=123, runAttempt=2, artifactID=456, artifactDigest='sha256:' + 'a' * 64)
                (root / 'reused-verification/receipt.json').write_text(json.dumps(receipt))
                # Even a pre-existing receipt must not be exported when the gate fails.
                (root / 'scripts/reuse-watch-verification.py').write_text(f'raise SystemExit({exit_code})\n')
                output = root / 'github-output'
                env = dict(os.environ, GITHUB_REPOSITORY='owner/repo', GITHUB_REPOSITORY_ID='99',
                           SOURCE_SHA='b' * 40, RUNNER_TEMP=str(root), GITHUB_OUTPUT=str(output))
                result = subprocess.run(['/bin/bash', '-e', '-c', code], cwd=root, env=env,
                                        capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, exit_code, result.stderr)
                if exit_code:
                    self.assertFalse(output.exists())
                else:
                    values = dict(line.split('=', 1) for line in output.read_text().splitlines())
                    self.assertEqual(values, dict(run_id='123', run_attempt='2', artifact_id='456',
                                                  artifact_digest=receipt['artifactDigest']))

    def test_signing_preflight_records_exact_identity_and_rejects_missing_fields(self):
        timing = step(job(RELEASE, 'release'), 'Record workflow timings and prepare notes')
        script = re.search(r"python3 - <<'PY'\n(.*?)\nPY", shell(timing), re.S)[1]
        def command(args, **kwargs):
            if args[0] == 'xcodebuild':
                return 'Xcode fixture\n'
            return json.dumps({'jobs': []} if args[-1].endswith('/jobs') else
                              dict(created_at='start', run_started_at='start', html_url='https://example.invalid/run'))
        identity = dict(WATCH_VERIFY_RUN='123', WATCH_VERIFY_ATTEMPT='2',
                        WATCH_VERIFY_ARTIFACT='456', WATCH_VERIFY_DIGEST='sha256:' + 'a' * 64)
        for event in ('push', 'workflow_dispatch'):
            for missing in (None, *identity):
                if event == 'workflow_dispatch' and missing is not None:
                    continue
                with self.subTest(event=event, missing=missing), tempfile.TemporaryDirectory() as directory:
                    env = dict(os.environ, RUNNER_TEMP=directory, TESTING_NOTES='fixture',
                               GITHUB_REPOSITORY='owner/repo', GITHUB_RUN_ID='9',
                               GITHUB_EVENT_NAME=event, GITHUB_SHA='b' * 40, **identity)
                    if missing:
                        env[missing] = ''
                    if event == 'workflow_dispatch':
                        env.update({key: '' for key in identity})
                    target = Path(directory) / 'ci-timing.json'
                    with patch.dict(os.environ, env, clear=True), patch('subprocess.check_output', side_effect=command):
                        if missing:
                            with self.assertRaises(SystemExit):
                                exec(compile(script, 'workflow-timing-preflight', 'exec'), {})
                            self.assertFalse(target.exists())
                            continue
                        exec(compile(script, 'workflow-timing-preflight', 'exec'), {})
                    value = json.loads(target.read_text())['verification']
                    self.assertEqual(value['source'], 'b' * 40)
                    self.assertEqual(value['mode'], 'watch-checks' if event == 'push' else 'manual-full')
                    if event == 'push':
                        self.assertEqual((value['runID'], value['runAttempt'], value['artifactID']), (123, 2, 456))
                        self.assertEqual(value['artifactDigest'], identity['WATCH_VERIFY_DIGEST'])
        release = job(RELEASE, 'release')
        self.assertLess(release.index('- name: Record workflow timings and prepare notes'),
                        release.index('- name: Install temporary signing credentials'))


if __name__ == '__main__':
    unittest.main()
