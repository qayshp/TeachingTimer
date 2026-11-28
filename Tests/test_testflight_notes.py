# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Exact-source notes, override and real workflow handoff checks; no Apple API."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_verification_reuse_workflow import RELEASE, job, shell, step

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('testflight_notes', ROOT / 'scripts/testflight-notes.py')
notes = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(notes)


class TestFlightNotesChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.text = 'Recent changes\n• Clearer reports and connection details.\n\nPlease test\nCrown volume.\n'
        target = self.source / notes.NOTES_PATH
        target.parent.mkdir()
        target.write_text(self.text)
        self.git('init', '-q')
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'notes')
        self.sha = self.git('rev-parse', 'HEAD').strip()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.source), *args], text=True)

    def test_curated_notes_come_from_commit_not_dirty_working_copy(self):
        (self.source / notes.NOTES_PATH).write_text('Unreviewed replacement')
        payload = notes.prepare(self.source, self.sha)
        self.assertEqual(payload['text'], self.text)
        self.assertEqual(payload['origin'], 'repository')
        self.assertEqual(payload['notesSHA256'], notes.sha256(self.text))
        self.assertEqual(notes.decode(notes.encode(payload), self.sha), payload)

    def test_missing_file_symlink_and_wrong_revision_fail(self):
        with self.assertRaisesRegex(ValueError, 'differs'):
            notes.prepare(self.source, '0' * 40)
        target = self.source / notes.NOTES_PATH
        target.unlink()
        target.symlink_to('../elsewhere.txt')
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'symlink')
        with self.assertRaisesRegex(ValueError, 'regular'):
            notes.prepare(self.source, self.git('rev-parse', 'HEAD').strip())
        target.unlink()
        self.git('add', '.')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'missing')
        with self.assertRaisesRegex(ValueError, 'missing'):
            notes.prepare(self.source, self.git('rev-parse', 'HEAD').strip())

    def test_override_is_explicit_and_never_silently_falls_back(self):
        self.assertEqual(notes.prepare(self.source, self.sha, '')['text'], self.text)
        supplied = 'Fixes\nA multiline override with Unicode: 🧘\n'
        payload = notes.prepare(self.source, self.sha, supplied)
        self.assertEqual(payload['origin'], 'manual-override')
        self.assertIsNone(payload['sourcePath'])
        self.assertEqual(notes.decode(notes.encode(payload), self.sha)['text'], supplied)
        for invalid in (' \n\t', 'x' * 4001, 'x\x00y', 'x\ry'):
            with self.subTest(invalid=repr(invalid[:20])), self.assertRaises(ValueError):
                notes.prepare(self.source, self.sha, invalid)
        self.assertEqual(len(notes.prepare(self.source, self.sha, '🧘' * 4000)['text']), 4000)

    def test_invalid_reviewed_repository_content_fails_without_fallback(self):
        for invalid in (' \n', 'x' * 4001, 'x' * 20000):
            with self.subTest(characters=len(invalid)):
                (self.source / notes.NOTES_PATH).write_text(invalid)
                self.git('add', '.')
                self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'invalid')
                with self.assertRaises(ValueError):
                    notes.prepare(self.source, self.git('rev-parse', 'HEAD').strip())

    def test_invalid_or_mismatched_payload_cannot_materialize(self):
        payload = notes.prepare(self.source, self.sha)
        for key, replacement in (('sourceSHA', '0' * 40), ('locale', 'fr-FR'),
                                 ('schemaVersion', 2), ('schemaVersion', True), ('notesSHA256', '0' * 64),
                                 ('characterCount', 1), ('origin', 'unknown'),
                                 ('sourcePath', '../other.txt'), ('text', 'Changed content')):
            with self.subTest(key=key), self.assertRaises(ValueError):
                notes.decode(notes.encode(dict(payload, **{key: replacement})), self.sha)
        for invalid in ('', 'not base64!', 'a' * 40001):
            with self.subTest(invalid=invalid[:15]), self.assertRaises(ValueError):
                notes.decode(invalid, self.sha)

    def test_output_is_new_and_keeps_exact_text_with_receipt(self):
        payload = notes.prepare(self.source, self.sha)
        output = self.root / 'notes'
        notes.write(payload, output)
        self.assertEqual((output / 'notes.txt').read_text(), self.text)
        receipt = json.loads((output / 'notes.json').read_text())
        self.assertEqual(receipt['notesSHA256'], payload['notesSHA256'])
        self.assertNotIn('text', receipt)
        with self.assertRaises(FileExistsError):
            notes.write(dict(payload, text='new'), output)
        self.assertEqual((output / 'notes.txt').read_text(), self.text)

    def test_current_curated_copy_is_valid_and_not_a_generic_prompt(self):
        text = (ROOT / notes.NOTES_PATH).read_text(encoding='utf-8')
        notes.validate_text(text)
        self.assertIn('Recent changes', text)
        self.assertIn('Known issues', text)
        self.assertNotIn('Automatic main-branch build', text)

    def test_actual_workflow_source_to_release_handoff_for_auto_and_manual(self):
        automation = self.root / 'automation/scripts'
        automation.mkdir(parents=True)
        for name in ('testflight-notes.py', 'testflight-release.py', 'testflight_build_number.py'):
            shutil.copy(ROOT / 'scripts' / name, automation / name)
        binaries = self.root / 'bin'
        binaries.mkdir()
        github = binaries / 'gh'
        github.write_text('#!/bin/sh\n[ "$*" = "api repos/owner/repo/actions/runs/123" ] || exit 2\n'
                          'printf "%s\\n" "$FIXTURE_RUN"\n')
        github.chmod(0o755)
        source_code = shell(step(job(RELEASE, 'source'), 'Resolve source and validate inputs'))
        release_code = shell(step(job(RELEASE, 'release'), 'Materialize reviewed TestFlight notes'))
        common_env = dict(os.environ, GITHUB_SHA=self.sha, BUILD_NUMBER='42', WORKFLOW_RUN_NUMBER='90',
                          GITHUB_REPOSITORY='owner/repo', PATH=str(binaries) + os.pathsep + os.environ['PATH'])
        for event, attempt, override in (('push', 1, ''), ('push', 2, ''), ('workflow_dispatch', 1, ''),
                                         ('workflow_dispatch', 1, 'Specific fix\n$(touch SHOULD_NOT_EXIST) `echo literal`\n')):
            with self.subTest(event=event, attempt=attempt, override=bool(override)):
                run = Path(tempfile.mkdtemp(dir=self.root))
                output = run / 'github-output'
                run_metadata = dict(id=123, run_number=90, head_sha=self.sha, event=event, head_branch='main',
                                    created_at='2026-11-26T21:18:00Z', run_attempt=attempt,
                                    run_started_at=f'2026-11-{25 + attempt}T21:18:25Z')
                env = dict(common_env, RUNNER_TEMP=str(run), GITHUB_OUTPUT=str(output),
                           EVENT_NAME=event, TESTING_NOTES=override, GITHUB_RUN_ID='123',
                           FIXTURE_RUN=json.dumps(run_metadata))
                subprocess.run(['/bin/bash', '-e', '-c', source_code], cwd=self.root, env=env,
                               capture_output=True, text=True, timeout=15, check=True)
                values = dict(line.split('=', 1) for line in output.read_text().splitlines())
                release_dir = run / 'release'
                release_dir.mkdir()
                env.update(RUNNER_TEMP=str(release_dir), NOTES_PAYLOAD=values['notes_payload'], SOURCE_SHA=values['sha'])
                subprocess.run(['/bin/bash', '-e', '-c', release_code], cwd=self.root, env=env,
                               capture_output=True, text=True, timeout=15, check=True)
                original = run / 'testflight-notes/notes.txt'
                final = release_dir / 'testflight-notes/notes.txt'
                self.assertEqual(original.read_bytes(), final.read_bytes())
                self.assertEqual(final.read_text(), override or self.text)
                self.assertEqual(values['sha'], self.sha)
                self.assertEqual(values['build_number'], '261126.1318.90' if event == 'push' else '42')
                self.assertFalse((self.root / 'SHOULD_NOT_EXIST').exists())

        for run_id, returned_sha in (('124', self.sha), ('123', 'a' * 40)):
            with self.subTest(run_api_failure=run_id != '123'):
                run = Path(tempfile.mkdtemp(dir=self.root))
                run_metadata = dict(id=123, run_number=90, head_sha=returned_sha, event='push',
                                    head_branch='main', created_at='2026-11-26T21:18:00Z')
                env = dict(common_env, RUNNER_TEMP=str(run), GITHUB_OUTPUT=str(run / 'github-output'),
                           EVENT_NAME='push', TESTING_NOTES='', GITHUB_RUN_ID=run_id,
                           FIXTURE_RUN=json.dumps(run_metadata))
                result = subprocess.run(['/bin/bash', '-e', '-c', source_code], cwd=self.root, env=env,
                                        capture_output=True, text=True, timeout=15)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((run / 'github-output').exists())
                self.assertFalse((run / 'testflight-notes').exists())

    def test_workflow_materializes_before_signing_and_never_overwrites_notes(self):
        release = job(RELEASE, 'release')
        self.assertLess(release.index('- name: Materialize reviewed TestFlight notes'),
                        release.index('- name: Install temporary signing credentials'))
        self.assertNotIn('TESTING_NOTES', release)
        self.assertNotIn('release-notes.txt', release)
        self.assertEqual(release.count('--notes-file "$RUNNER_TEMP/testflight-notes/notes.txt"'), 2)
        self.assertIn('${{ runner.temp }}/testflight-notes/notes.txt', release)
        self.assertIn('${{ runner.temp }}/testflight-notes/notes.json', release)
        self.assertIn('notes_payload: ${{ steps.source.outputs.notes_payload }}', job(RELEASE, 'source'))

    def test_actual_materialization_shell_fails_before_writing_mismatched_notes(self):
        automation = self.root / 'automation/scripts'
        automation.mkdir(parents=True)
        shutil.copy(ROOT / 'scripts/testflight-notes.py', automation / 'testflight-notes.py')
        code = shell(step(job(RELEASE, 'release'), 'Materialize reviewed TestFlight notes'))
        for changed in ({'sourceSHA': '0' * 40}, {'notesSHA256': '0' * 64}):
            with self.subTest(changed=changed):
                payload = dict(notes.prepare(self.source, self.sha), **changed)
                run = Path(tempfile.mkdtemp(dir=self.root))
                env = dict(os.environ, RUNNER_TEMP=str(run), NOTES_PAYLOAD=notes.encode(payload), SOURCE_SHA=self.sha)
                result = subprocess.run(['/bin/bash', '-e', '-c', code], cwd=self.root, env=env,
                                        capture_output=True, text=True, timeout=15)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((run / 'testflight-notes').exists())


if __name__ == '__main__':
    unittest.main()
