# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import warnings
import zipfile
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('verification_reuse', ROOT / 'scripts/reuse-watch-verification.py')
reuse = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reuse)
REPOSITORY = 'qayshp/TeachingTimer'
REPOSITORY_ID = 123
SHA = 'a' * 40
RUN = dict(id=10, run_attempt=1, workflow_id=20, path=reuse.WORKFLOW, event='push',
           head_branch='main', head_sha=SHA, status='completed', conclusion='success',
           repository=dict(id=REPOSITORY_ID, full_name=REPOSITORY),
           head_repository=dict(id=REPOSITORY_ID, full_name=REPOSITORY))


def report():
    return dict(schemaVersion=2, revision=SHA, sourceDirty=False, sourceRevisionAfter=SHA,
                sourceDirtyAfter=False, complete=True, bootedSimulatorRequested=True,
                hostedRuntimePreparationRequested=True, distributionSigned=False, uploaded=False, installed=False,
                ci=dict(repository=REPOSITORY, repositoryID=str(REPOSITORY_ID),
                        workflowRef=REPOSITORY + '/' + reuse.WORKFLOW + '@refs/heads/main', workflowSHA=SHA,
                        runID='10', runAttempt='1', event='push', ref='refs/heads/main'),
                steps=[dict(name=name, status='passed', exitCode=0) for name in reuse.STEPS])


def archive_bytes(value=None, entries=None):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        if entries is None:
            archive.writestr('verification.json', json.dumps(report() if value is None else value))
            # Other evidence may include untrusted filenames; the consumer never extracts it.
            archive.writestr('../never-execute.sh', 'exit 99\n')
        else:
            for name, content in entries:
                archive.writestr(name, content)
    return stream.getvalue()


class Clock:
    def __init__(self):
        self.value = 0

    def __call__(self):
        return self.value

    def sleep(self, seconds):
        self.value += seconds


class GitHub:
    def __init__(self, value=None):
        self.data = archive_bytes(value)
        self.repo = dict(id=REPOSITORY_ID, full_name=REPOSITORY, default_branch='main')
        self.workflow = dict(id=20, path=reuse.WORKFLOW, state='active')
        self.runs = [[copy.deepcopy(RUN)]]
        self.current = copy.deepcopy(RUN)
        self.jobs = [dict(name=name, run_id=10, status='completed', conclusion='success')
                     for name in (*reuse.REQUIRED_JOBS, 'Lint GitHub workflows')]
        self.artifacts = [dict(id=30, name='verification-' + SHA + '-1', expired=False,
            size_in_bytes=len(self.data), digest='sha256:' + hashlib.sha256(self.data).hexdigest(),
            workflow_run=dict(id=10, repository_id=REPOSITORY_ID, head_repository_id=REPOSITORY_ID,
                              head_branch='main', head_sha=SHA))]
        self.calls = []
        self.downloads = 0
        self.after_download = None

    def get(self, endpoint):
        self.calls.append(endpoint)
        path = endpoint.split('?')[0]
        if not path:
            return copy.deepcopy(self.repo)
        if path == 'actions/workflows/check.yml':
            return copy.deepcopy(self.workflow)
        if path == 'actions/workflows/20/runs':
            assert 'event=push' in endpoint and 'branch=main' in endpoint and 'head_sha=' + SHA in endpoint
            values = self.runs.pop(0) if len(self.runs) > 1 else self.runs[0]
            return dict(total_count=len(values), workflow_runs=copy.deepcopy(values))
        if path == 'actions/runs/10/attempts/1/jobs':
            return dict(total_count=len(self.jobs), jobs=copy.deepcopy(self.jobs))
        if path == 'actions/runs/10/artifacts':
            return dict(total_count=len(self.artifacts), artifacts=copy.deepcopy(self.artifacts))
        if path == 'actions/runs/10':
            return copy.deepcopy(self.current)
        raise AssertionError('Unexpected API request: ' + endpoint)

    def download(self, endpoint, destination, limit):
        assert endpoint == 'actions/artifacts/30/zip' and limit == reuse.MAX_ARCHIVE_BYTES
        self.downloads += 1
        destination.write_bytes(self.data)
        if self.after_download:
            self.after_download()

    def replace_archive(self, data):
        self.data = data
        self.artifacts[0].update(size_in_bytes=len(data), digest='sha256:' + hashlib.sha256(data).hexdigest())


class VerificationReuseChecks(unittest.TestCase):
    def run_reuse(self, client, directory, clock=None, **arguments):
        clock = clock or Clock()
        return reuse.reuse(client, REPOSITORY, REPOSITORY_ID, SHA, Path(directory) / 'result',
                           clock=clock, sleep=clock.sleep, **arguments)

    def test_success_binds_source_attempt_jobs_and_verified_artifact(self):
        with tempfile.TemporaryDirectory() as directory:
            client = GitHub()
            result = self.run_reuse(client, directory)
            self.assertTrue(result['verified'])
            self.assertEqual(result['sourceSHA'], SHA)
            self.assertEqual((result['runID'], result['runAttempt'], result['artifactID']), (10, 1, 30))
            self.assertEqual(client.downloads, 1)
            self.assertIn('actions/runs/10/attempts/1/jobs?per_page=100&page=1', client.calls)
            root = Path(directory) / 'result'
            self.assertEqual(json.loads((root / 'verification.json').read_text()), report())
            self.assertIn('Status: verified', (root / 'summary.md').read_text())
            self.assertFalse((Path(directory) / 'never-execute.sh').exists())

    def test_waits_monotonically_for_queued_full_verification(self):
        with tempfile.TemporaryDirectory() as directory:
            client = GitHub()
            queued = dict(RUN, status='in_progress', conclusion=None)
            client.runs = [[], [queued], [RUN]]
            clock = Clock()
            result = self.run_reuse(client, directory, clock, timeout_seconds=31, poll_seconds=10)
            self.assertEqual(clock.value, 20)
            self.assertEqual(result['elapsedSeconds'], 20)
            self.assertEqual([value['status'] for value in result['observations']], ['in_progress', 'completed'])

    def test_missing_or_pending_run_times_out_without_download_and_saves_failure(self):
        for values in ([], [dict(RUN, status='queued', conclusion=None)]):
            with self.subTest(values=values), tempfile.TemporaryDirectory() as directory:
                client = GitHub()
                client.runs = [values]
                clock = Clock()
                with self.assertRaisesRegex(reuse.VerificationError, 'Timed out'):
                    self.run_reuse(client, directory, clock, timeout_seconds=31, poll_seconds=15)
                self.assertEqual(clock.value, 31)
                self.assertEqual(client.downloads, 0)
                saved = json.loads((Path(directory) / 'result/receipt.json').read_text())
                self.assertFalse(saved['verified'])
                self.assertEqual(saved['status'], 'failed')
                self.assertEqual(saved['elapsedSeconds'], 31)

    def test_newest_failed_or_cancelled_run_never_falls_back_to_old_success(self):
        for conclusion in ('failure', 'cancelled', 'timed_out', 'neutral', 'skipped', 'action_required'):
            with self.subTest(conclusion=conclusion), tempfile.TemporaryDirectory() as directory:
                client = GitHub()
                client.runs = [[RUN, dict(RUN, id=11, conclusion=conclusion)]]
                with self.assertRaisesRegex(reuse.VerificationError, 'did not succeed'):
                    self.run_reuse(client, directory)
                self.assertEqual(client.downloads, 0)

    def test_main_push_run_provenance_cannot_be_replaced_by_pr_fork_or_other_workflow(self):
        changes = (
            dict(event='pull_request'), dict(head_sha='b' * 40), dict(head_branch='feature'),
            dict(workflow_id=99), dict(path='.github/workflows/other.yml'), dict(run_attempt=0),
            dict(repository=dict(id=999, full_name=REPOSITORY)),
            dict(head_repository=dict(id=999, full_name=REPOSITORY)),
            dict(head_repository=dict(id=REPOSITORY_ID, full_name='someone/TeachingTimer')),
        )
        for change in changes:
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                client = GitHub()
                client.runs = [[dict(RUN, **change)]]
                with self.assertRaises(reuse.VerificationError):
                    self.run_reuse(client, directory)
                self.assertEqual(client.downloads, 0)

    def test_wrong_repository_or_workflow_configuration_fails_before_waiting(self):
        for target, changes in (
            ('repo', dict(id=99)), ('repo', dict(full_name='other/repository')),
            ('repo', dict(default_branch='development')), ('workflow', dict(state='disabled_manually')),
            ('workflow', dict(path='.github/workflows/untrusted.yml')),
        ):
            with self.subTest(target=target, changes=changes), tempfile.TemporaryDirectory() as directory:
                client = GitHub()
                getattr(client, target).update(changes)
                with self.assertRaises(reuse.VerificationError):
                    self.run_reuse(client, directory)
                self.assertEqual(client.downloads, 0)

    def test_docs_only_green_run_with_skipped_mac_or_required_result_is_not_reusable(self):
        for name in reuse.REQUIRED_JOBS:
            for conclusion in ('skipped', 'failure', 'cancelled'):
                with self.subTest(name=name, conclusion=conclusion), tempfile.TemporaryDirectory() as directory:
                    client = GitHub()
                    next(job for job in client.jobs if job['name'] == name)['conclusion'] = conclusion
                    with self.assertRaisesRegex(reuse.VerificationError, 'job did not pass'):
                        self.run_reuse(client, directory)
                    self.assertEqual(client.downloads, 0)

    def test_optional_workflow_lint_can_be_skipped_but_not_failed(self):
        with tempfile.TemporaryDirectory() as directory:
            client = GitHub()
            client.jobs[-1]['conclusion'] = 'skipped'
            self.assertTrue(self.run_reuse(client, directory)['verified'])
        with tempfile.TemporaryDirectory() as directory:
            client = GitHub()
            client.jobs[-1]['conclusion'] = 'failure'
            with self.assertRaises(reuse.VerificationError):
                self.run_reuse(client, directory)

    def test_duplicate_missing_or_mismatched_job_identity_is_rejected(self):
        for mutation in ('duplicate', 'missing', 'run-id', 'unfinished'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                client = GitHub()
                if mutation == 'duplicate':
                    client.jobs.append(client.jobs[0])
                elif mutation == 'missing':
                    client.jobs.pop(0)
                elif mutation == 'run-id':
                    client.jobs[0]['run_id'] = 999
                else:
                    client.jobs[0]['status'] = 'in_progress'
                with self.assertRaises(reuse.VerificationError):
                    self.run_reuse(client, directory)
                self.assertEqual(client.downloads, 0)

    def test_artifact_metadata_must_be_current_unique_and_bound_to_run(self):
        changes = (
            dict(id=0), dict(name='verification-' + SHA + '-2'), dict(expired=True),
            dict(size_in_bytes=0), dict(size_in_bytes=reuse.MAX_ARCHIVE_BYTES + 1),
            dict(digest=None), dict(digest='sha256:invalid'),
            dict(workflow_run=dict(id=999)), dict(workflow_run=dict(RUN, head_sha='b' * 40)),
        )
        for change in changes:
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                client = GitHub()
                client.artifacts[0].update(change)
                with self.assertRaises(reuse.VerificationError):
                    self.run_reuse(client, directory)
                self.assertEqual(client.downloads, 0)
        with tempfile.TemporaryDirectory() as directory:
            client = GitHub()
            client.artifacts *= 2
            with self.assertRaisesRegex(reuse.VerificationError, 'duplicate'):
                self.run_reuse(client, directory)

    def test_artifact_rejects_each_mismatched_source_identity_field(self):
        for key, value in (('id', 11), ('repository_id', 999), ('head_repository_id', 999),
                           ('head_sha', 'b' * 40), ('head_branch', 'branch')):
            with self.subTest(key=key), tempfile.TemporaryDirectory() as directory:
                client = GitHub()
                client.artifacts[0]['workflow_run'][key] = value
                with self.assertRaises(reuse.VerificationError):
                    self.run_reuse(client, directory)
                self.assertEqual(client.downloads, 0)

    def test_download_bytes_must_match_both_size_and_server_digest(self):
        for modification in ('size', 'digest'):
            with self.subTest(modification=modification), tempfile.TemporaryDirectory() as directory:
                client = GitHub()
                if modification == 'size':
                    client.artifacts[0]['size_in_bytes'] += 1
                else:
                    client.artifacts[0]['digest'] = 'sha256:' + '0' * 64
                with self.assertRaisesRegex(reuse.VerificationError, 'size differs|digest differs'):
                    self.run_reuse(client, directory)

    def test_invalid_archive_missing_duplicate_or_malformed_root_report_is_rejected(self):
        values = [b'not a zip', archive_bytes(entries=[('nested/verification.json', '{}')]),
                  archive_bytes(entries=[('verification.json', 'invalid JSON')]),
                  archive_bytes(entries=[('verification.json', '{"complete":true,"complete":false}')]),
                  archive_bytes(entries=[('verification.json', ' ' * (reuse.MAX_REPORT_BYTES + 1))])]
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            values.append(archive_bytes(entries=[('verification.json', '{}'), ('verification.json', '{}')]))
        for index, value in enumerate(values):
            with self.subTest(index=index), tempfile.TemporaryDirectory() as directory:
                client = GitHub()
                client.replace_archive(value)
                with self.assertRaises(reuse.VerificationError):
                    self.run_reuse(client, directory)

    def test_report_rejects_stale_dirty_incomplete_or_reduced_scope(self):
        changes = (
            dict(schemaVersion=1), dict(revision='b' * 40), dict(sourceDirty=True),
            dict(sourceRevisionAfter='b' * 40), dict(sourceDirtyAfter=True),
            dict(sourceDirtyAfter=None), dict(complete=False), dict(complete='true'),
            dict(bootedSimulatorRequested=False), dict(hostedRuntimePreparationRequested=False),
            dict(distributionSigned=True), dict(uploaded=True), dict(installed=True), dict(ci={}),
        )
        for change in changes:
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                value = report()
                value.update(change)
                with self.assertRaises(reuse.VerificationError):
                    self.run_reuse(GitHub(value), directory)

    def test_report_binds_each_provenance_field_to_api_identity(self):
        for key in report()['ci']:
            with self.subTest(key=key), tempfile.TemporaryDirectory() as directory:
                value = report()
                value['ci'][key] = 'wrong'
                with self.assertRaisesRegex(reuse.VerificationError, 'CI provenance'):
                    self.run_reuse(GitHub(value), directory)

    def test_every_expected_stage_must_finish_once_successfully(self):
        for mutation in ('missing', 'duplicate', 'extra', 'failed', 'wrong-exit', 'boolean-exit'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                value = report()
                if mutation == 'missing':
                    value['steps'].pop()
                elif mutation == 'duplicate':
                    value['steps'][-1] = value['steps'][0]
                elif mutation == 'extra':
                    value['steps'].append(dict(name='unrecognized', status='passed', exitCode=0))
                elif mutation == 'failed':
                    value['steps'][0]['status'] = 'failed'
                elif mutation == 'wrong-exit':
                    value['steps'][0]['exitCode'] = 1
                else:
                    value['steps'][0]['exitCode'] = False
                with self.assertRaises(reuse.VerificationError):
                    self.run_reuse(GitHub(value), directory)

    def test_rerun_or_newer_run_during_download_invalidates_old_results(self):
        for mutation in ('attempt', 'status', 'conclusion', 'new-run'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                client = GitHub()
                def change():
                    if mutation == 'attempt':
                        client.current['run_attempt'] = 2
                    elif mutation == 'status':
                        client.current['status'] = 'in_progress'
                    elif mutation == 'conclusion':
                        client.current['conclusion'] = 'failure'
                    else:
                        client.runs = [[RUN, dict(RUN, id=11, status='queued', conclusion=None)]]
                client.after_download = change
                with self.assertRaisesRegex(reuse.VerificationError, 'changed while checking'):
                    self.run_reuse(client, directory)
                self.assertFalse((Path(directory) / 'result/verification.json').exists())

    def test_network_error_is_not_converted_to_reusable_success(self):
        with tempfile.TemporaryDirectory() as directory:
            client = GitHub()
            client.get = lambda _: (_ for _ in ()).throw(reuse.VerificationError('API unavailable'))
            with self.assertRaisesRegex(reuse.VerificationError, 'API unavailable'):
                self.run_reuse(client, directory)
            saved = json.loads((Path(directory) / 'result/receipt.json').read_text())
            self.assertFalse(saved['verified'])

    def test_pagination_never_silently_ignores_later_matching_items(self):
        class Pages:
            def get(self, endpoint):
                page = int(endpoint.rsplit('=', 1)[1])
                return dict(total_count=101, values=[dict(id=n) for n in (range(100) if page == 1 else [100])])
        self.assertEqual(len(reuse.listing(Pages(), 'resource', 'values')), 101)

    def test_cli_identity_and_wait_limits_fail_before_network(self):
        for arguments in (
            dict(repository='../bad'), dict(repository_id=0), dict(sha='HEAD'),
            dict(timeout_seconds=0), dict(timeout_seconds=float('nan')), dict(poll_seconds=61),
        ):
            with self.subTest(arguments=arguments), tempfile.TemporaryDirectory() as directory:
                values = dict(repository=REPOSITORY, repository_id=REPOSITORY_ID, sha=SHA,
                              output=Path(directory) / 'result')
                values.update(arguments)
                client = GitHub()
                with self.assertRaises(reuse.VerificationError):
                    reuse.reuse(client, **values)
                self.assertFalse(client.calls)

    def test_client_uses_get_requests_and_bounded_commands_without_secrets(self):
        client = reuse.GitHubClient(REPOSITORY)
        with patch.object(reuse.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, b'{"id":1}')) as run:
            self.assertEqual(client.get(''), {'id': 1})
            self.assertEqual(run.call_args.args[0], ['gh', 'api', 'repos/' + REPOSITORY])
            self.assertEqual(run.call_args.kwargs['timeout'], 30)
        with patch.object(reuse.subprocess, 'run', side_effect=subprocess.TimeoutExpired('gh', 30)):
            with self.assertRaisesRegex(reuse.VerificationError, 'metadata request failed'):
                client.get('actions/workflows/check.yml')


if __name__ == '__main__':
    unittest.main()
