#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Reuse complete Watch checks for one immutable main-push revision, without secrets."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import time
import zipfile


WORKFLOW = '.github/workflows/check.yml'
MAX_ARCHIVE_BYTES = 128 * 1024 * 1024
MAX_REPORT_BYTES = 1024 * 1024
STEPS = (
    'xcode', 'developer-directory', 'sdks', 'swift', 'repository',
    'control-outline-smoke', 'models', 'tools', 'information-qr', 'simulator',
    'prepare-watch-runtime', 'simulator-smoke', 'companion-simulator',
    'simulator-tools', 'screen-text-smoke', 'archive', 'distribution-rehearsal',
)
REQUIRED_JOBS = ('changes', 'Repository and Python checks',
                 'Watch Simulator and archive verification', 'Required result')


class VerificationError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise VerificationError(message)


def identifier(value):
    return type(value) is int and value > 0


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'Duplicate JSON property in verification evidence')
        result[key] = value
    return result


class GitHubClient:
    """Only GET requests; never consumes an artifact's code or shell instructions."""
    def __init__(self, repository):
        self.repository = repository

    def get(self, endpoint):
        try:
            resource = 'repos/' + self.repository + ('/' + endpoint if endpoint else '')
            response = subprocess.run(['gh', 'api', resource],
                                      capture_output=True, check=True, timeout=30)
            return json.loads(response.stdout, object_pairs_hook=unique_object)
        except (subprocess.SubprocessError, OSError, UnicodeError, json.JSONDecodeError) as error:
            raise VerificationError('GitHub metadata request failed: ' + endpoint.split('?')[0]) from error

    def download(self, endpoint, destination, limit):
        try:
            with destination.open('wb') as stream:
                subprocess.run(['gh', 'api', 'repos/' + self.repository + '/' + endpoint],
                               stdout=stream, stderr=subprocess.PIPE, check=True, timeout=60)
            require(0 < destination.stat().st_size <= limit, 'Artifact download exceeds the size limit')
        except (subprocess.SubprocessError, OSError) as error:
            raise VerificationError('GitHub artifact download failed') from error


def listing(client, endpoint, key):
    """Paginate bounded result sets instead of silently trusting a partial first page."""
    items = []
    separator = '&' if '?' in endpoint else '?'
    for page in range(1, 11):
        result = client.get(f'{endpoint}{separator}per_page=100&page={page}')
        require(isinstance(result, dict) and isinstance(result.get(key), list)
                and type(result.get('total_count')) is int
                and 0 <= result['total_count'] <= 1000, 'Malformed or excessive GitHub listing')
        batch = result[key]
        require(all(isinstance(item, dict) for item in batch), 'Malformed GitHub listing item')
        items.extend(batch)
        if len(items) >= result['total_count']:
            require(len(items) == result['total_count'], 'Inconsistent GitHub listing count')
            return items
        require(bool(batch), 'Incomplete GitHub listing')
    raise VerificationError('GitHub listing exceeds the pagination limit')


def validate_run(run, repository, repository_id, sha, workflow_id):
    require(isinstance(run, dict), 'Malformed Watch-check run')
    require(identifier(run.get('id')) and identifier(run.get('run_attempt')),
            'Missing Watch-check run or attempt identity')
    require(run.get('workflow_id') == workflow_id and run.get('path') == WORKFLOW,
            'Unexpected verification workflow')
    require(run.get('event') == 'push' and run.get('head_branch') == 'main'
            and run.get('head_sha') == sha, 'Verification is not the exact main-push source')
    for name in ('repository', 'head_repository'):
        identity = run.get(name, {})
        require(isinstance(identity, dict) and identity.get('id') == repository_id
                and identity.get('full_name') == repository, 'Verification repository identity differs')


def newest_run(client, workflow_id, repository, repository_id, sha):
    runs = listing(client, f'actions/workflows/{workflow_id}/runs?event=push&branch=main&head_sha={sha}',
                   'workflow_runs')
    for run in runs:
        validate_run(run, repository, repository_id, sha, workflow_id)
    return max(runs, key=lambda run: run['id']) if runs else None


def validate_jobs(client, run):
    jobs = listing(client, f'actions/runs/{run["id"]}/attempts/{run["run_attempt"]}/jobs', 'jobs')
    for name in (*REQUIRED_JOBS, 'Lint GitHub workflows'):
        matches = [job for job in jobs if job.get('name') == name]
        require(len(matches) == 1, 'Missing or duplicate verification job: ' + name)
        job = matches[0]
        allowed = ('success', 'skipped') if name == 'Lint GitHub workflows' else ('success',)
        require(job.get('run_id') == run['id'] and job.get('status') == 'completed'
                and job.get('conclusion') in allowed, 'Verification job did not pass: ' + name)


def select_artifact(client, run, repository_id, sha):
    name = f'verification-{sha}-{run["run_attempt"]}'
    artifacts = listing(client, f'actions/runs/{run["id"]}/artifacts', 'artifacts')
    matches = [artifact for artifact in artifacts if artifact.get('name') == name]
    require(len(matches) == 1, 'Missing or duplicate exact-attempt verification artifact')
    artifact = matches[0]
    require(identifier(artifact.get('id')) and artifact.get('expired') is False,
            'Verification artifact is invalid or expired')
    require(type(artifact.get('size_in_bytes')) is int
            and 0 < artifact['size_in_bytes'] <= MAX_ARCHIVE_BYTES, 'Invalid verification artifact size')
    require(isinstance(artifact.get('digest'), str)
            and re.fullmatch(r'sha256:[0-9a-f]{64}', artifact['digest']) is not None,
            'Missing or invalid GitHub artifact digest')
    origin = artifact.get('workflow_run', {})
    require(isinstance(origin, dict) and origin.get('id') == run['id']
            and origin.get('repository_id') == repository_id
            and origin.get('head_repository_id') == repository_id
            and origin.get('head_branch') == 'main' and origin.get('head_sha') == sha,
            'Verification artifact source or repository differs')
    return artifact


def read_report(path):
    try:
        with zipfile.ZipFile(path) as archive:
            matches = [item for item in archive.infolist() if item.filename == 'verification.json']
            require(len(matches) == 1 and not matches[0].is_dir(),
                    'Missing or duplicate root verification report')
            require(0 < matches[0].file_size <= MAX_REPORT_BYTES, 'Verification report exceeds the size limit')
            return json.loads(archive.read(matches[0]), object_pairs_hook=unique_object)
    except (zipfile.BadZipFile, UnicodeError, json.JSONDecodeError, RuntimeError) as error:
        raise VerificationError('Malformed verification archive or JSON report') from error


def validate_report(report, run, repository, repository_id, sha):
    require(isinstance(report, dict) and report.get('schemaVersion') == 2,
            'Unsupported verification report schema')
    require(report.get('revision') == sha and report.get('sourceDirty') is False
            and report.get('sourceRevisionAfter') == sha and report.get('sourceDirtyAfter') is False,
            'Verification source was dirty, changed, or differs from the release source')
    require(report.get('complete') is True and report.get('bootedSimulatorRequested') is True
            and report.get('hostedRuntimePreparationRequested') is True,
            'Verification did not complete the full hosted Simulator scope')
    require(report.get('distributionSigned') is False and report.get('uploaded') is False
            and report.get('installed') is False, 'Unexpected signed, published or installed verification')
    expected_ci = dict(repository=repository, repositoryID=str(repository_id),
                       workflowRef=repository + '/' + WORKFLOW + '@refs/heads/main', workflowSHA=sha,
                       runID=str(run['id']), runAttempt=str(run['run_attempt']), event='push', ref='refs/heads/main')
    require(report.get('ci') == expected_ci, 'Verification report CI provenance differs')
    steps = report.get('steps')
    require(isinstance(steps, list) and all(isinstance(step, dict) for step in steps)
            and tuple(step.get('name') for step in steps) == STEPS,
            'Missing, duplicate or unexpected verification stages')
    require(all(step.get('status') == 'passed' and type(step.get('exitCode')) is int
                and step['exitCode'] == 0 for step in steps), 'A verification stage did not pass')


def reuse(client, repository, repository_id, sha, output, timeout_seconds=2400, poll_seconds=15,
          clock=time.monotonic, sleep=time.sleep):
    require(isinstance(repository, str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+', repository)
            is not None and repository.split('/')[1] not in ('.', '..'), 'Invalid repository name')
    require(identifier(repository_id) and isinstance(sha, str)
            and re.fullmatch(r'[0-9a-f]{40}', sha) is not None, 'Invalid source or repository identity')
    require(math.isfinite(timeout_seconds) and 0 < timeout_seconds <= 3600
            and math.isfinite(poll_seconds) and 0 < poll_seconds <= 60, 'Invalid bounded wait settings')
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    started = clock()
    deadline = started + timeout_seconds
    receipt = dict(schemaVersion=1, repository=repository, repositoryID=repository_id,
                   sourceSHA=sha, status='waiting', startedAt=datetime.now(timezone.utc).isoformat(), observations=[])

    def save():
        receipt['elapsedSeconds'] = round(clock() - started, 3)
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        lines = ['## Exact-source Watch verification', '', 'Status: ' + receipt['status'],
                 '', 'Source: `' + sha + '`', '', f'Elapsed: {receipt["elapsedSeconds"]} seconds.']
        if 'runID' in receipt:
            lines += ['', f'Origin: [{receipt["runID"]}, attempt {receipt["runAttempt"]}]({receipt["runURL"]}).']
        if 'artifactDigest' in receipt:
            lines += ['', 'Artifact digest: `' + receipt['artifactDigest'] + '`.']
        if 'error' in receipt:
            lines += ['', receipt['error']]
        lines += ['', 'No signing, upload, distribution or device operation is performed by this check.']
        (output / 'summary.md').write_text('\n'.join(lines) + '\n')

    save()
    try:
        repo = client.get('')
        require(isinstance(repo, dict) and repo.get('id') == repository_id
                and repo.get('full_name') == repository and repo.get('default_branch') == 'main',
                'Expected verification repository/default branch differs')
        workflow = client.get('actions/workflows/check.yml')
        require(isinstance(workflow, dict) and identifier(workflow.get('id'))
                and workflow.get('path') == WORKFLOW and workflow.get('state') == 'active',
                'Expected Watch-check workflow is unavailable')
        workflow_id = workflow['id']
        while True:
            require(clock() < deadline, 'Timed out waiting for exact-source Watch verification')
            run = newest_run(client, workflow_id, repository, repository_id, sha)
            if run is not None:
                receipt.update(runID=run['id'], runAttempt=run['run_attempt'],
                               runURL=f'https://github.com/{repository}/actions/runs/{run["id"]}')
                receipt['observations'].append(dict(runID=run['id'], runAttempt=run['run_attempt'],
                    status=run.get('status'), conclusion=run.get('conclusion'), elapsedSeconds=round(clock() - started, 3)))
                save()
                if run.get('status') == 'completed':
                    require(run.get('conclusion') == 'success', 'Newest exact-source Watch verification did not succeed')
                    break
                require(run.get('status') in ('queued', 'in_progress', 'waiting', 'pending', 'requested'),
                        'Unexpected Watch-check run state')
            sleep(min(poll_seconds, max(0, deadline - clock())))

        validate_jobs(client, run)
        artifact = select_artifact(client, run, repository_id, sha)
        receipt.update(artifactID=artifact['id'], artifactDigest=artifact['digest'])
        save()
        archive = output / 'verification-artifact.zip'
        client.download(f'actions/artifacts/{artifact["id"]}/zip', archive, MAX_ARCHIVE_BYTES)
        require(archive.stat().st_size == artifact['size_in_bytes'], 'Downloaded artifact size differs')
        digest = 'sha256:' + hashlib.sha256(archive.read_bytes()).hexdigest()
        require(digest == artifact['digest'], 'Downloaded artifact digest differs from GitHub')
        report = read_report(archive)
        validate_report(report, run, repository, repository_id, sha)
        current = client.get(f'actions/runs/{run["id"]}')
        validate_run(current, repository, repository_id, sha, workflow_id)
        newest = newest_run(client, workflow_id, repository, repository_id, sha)
        require(current.get('run_attempt') == run['run_attempt'] and current.get('status') == 'completed'
                and current.get('conclusion') == 'success' and newest is not None
                and newest.get('id') == run['id'] and newest.get('run_attempt') == run['run_attempt']
                and newest.get('status') == 'completed' and newest.get('conclusion') == 'success',
                'Watch verification changed while checking evidence; refusing stale results')
        require(clock() <= deadline, 'Verification evidence check exceeded its deadline')
        (output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
        receipt.update(status='verified', verified=True, completedAt=datetime.now(timezone.utc).isoformat())
        save()
        return receipt
    except Exception as error:
        receipt.update(status='failed', verified=False, error=str(error), completedAt=datetime.now(timezone.utc).isoformat())
        save()
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', required=True)
    parser.add_argument('--repository-id', required=True, type=int)
    parser.add_argument('--sha', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--timeout-seconds', type=float, default=2400)
    parser.add_argument('--poll-seconds', type=float, default=15)
    args = parser.parse_args()
    try:
        receipt = reuse(GitHubClient(args.repository), args.repository, args.repository_id, args.sha,
                        args.output, args.timeout_seconds, args.poll_seconds)
    except (VerificationError, OSError, KeyError, TypeError) as error:
        raise SystemExit('Watch verification reuse refused: ' + str(error)) from error
    print('Verified exact-source Watch run ' + str(receipt['runID']) + ', attempt ' + str(receipt['runAttempt']))


if __name__ == '__main__':
    main()
