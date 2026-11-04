#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Explicit, internal-only release; never invites testers or submits review.

Rehearsal uses a real unsigned archive and never calls the App Store Connect API. Publishing
requires separate API/signing credentials. Reports exclude tokens and signing
materials; readiness means server-side eligibility, not a Watch installation.
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse
from urllib.request import Request, build_opener, HTTPRedirectHandler

ROOT = Path(__file__).resolve().parents[1]
APP_ID = '6829905117'
BUNDLE_ID = 'net.qays.TeachingTimer'
GROUP_ID = 'cf1d9287-bb4b-49cc-a93f-5b6b28e3de84'
GROUP_NAME = 'Maintainer pilot'
API = 'https://api.appstoreconnect.apple.com/v1/'


class ReleaseError(Exception):
    pass


def now():
    return datetime.now(timezone.utc).isoformat()


def build_number(value):
    if not (re.fullmatch(r'[1-9][0-9]{0,8}', value)
            or re.fullmatch(r'[0-9]{6}\.[0-9]{4}\.[1-9][0-9]{0,8}', value)):
        raise ReleaseError('Build number must be a positive integer or YYMMDD.HHmm.sequence')
    return value


class NoRedirect(HTTPRedirectHandler):
    # Never forward an API Authorization header to another destination.
    def redirect_request(self, *args, **kwargs):
        return None


class Token:
    def __init__(self, helper, key_path, key_id, issuer):
        self.arguments = [str(helper), str(key_path), key_id, issuer]
        self.value = None
        self.until = 0

    def __call__(self):
        if time.monotonic() >= self.until:
            result = subprocess.run(self.arguments, capture_output=True, text=True, timeout=15)
            if result.returncode or len(result.stdout.strip().split('.')) != 3:
                raise ReleaseError('API token creation failed; check the private key configuration')
            self.value = result.stdout.strip()
            self.until = time.monotonic() + 600
        return self.value


class Apple:
    def __init__(self, token, opener=None, sleep=time.sleep):
        self.token = token
        self.opener = opener or build_opener(NoRedirect())
        self.sleep = sleep

    def request(self, method, path, payload=None):
        url = path if urlparse(path).scheme else API + path
        if not url.startswith(API) or urlparse(url).fragment:
            raise ReleaseError('Refusing an API request outside the App Store Connect API')
        for attempt in range(4):
            request = Request(url, method=method, data=None if payload is None else json.dumps(payload).encode(),
                headers={'Authorization': 'Bearer ' + self.token(), 'Content-Type': 'application/json'})
            try:
                with self.opener.open(request, timeout=30) as response:
                    data = response.read()
                    return json.loads(data) if data else {}
            except HTTPError as error:
                if method == 'GET' and (error.code == 429 or error.code >= 500) and attempt < 3:
                    retry = error.headers.get('Retry-After', '') if error.headers else ''
                    self.sleep(min(30, max(1, int(retry))) if retry.isdigit() else 2 ** attempt)
                    continue
                # Do not store arbitrary server response bodies or request headers.
                raise ReleaseError('App Store Connect returned HTTP ' + str(error.code)) from None
            except (URLError, TimeoutError):
                raise ReleaseError('App Store Connect connection failed; resume the recorded release') from None
        raise ReleaseError('API retry limit reached')

    def pages(self, path):
        seen = set()
        while path:
            if path in seen or len(seen) >= 100:
                raise ReleaseError('Unexpected API pagination loop/limit')
            seen.add(path)
            response = self.request('GET', path)
            yield response
            path = response.get('links', {}).get('next')

    def validate_destination(self):
        app = self.request('GET', 'apps/' + APP_ID)['data']
        group = self.request('GET', 'betaGroups/' + GROUP_ID)['data']
        owner = self.request('GET', 'betaGroups/' + GROUP_ID + '/app')['data']
        if app['id'] != APP_ID or app['attributes']['bundleId'] != BUNDLE_ID:
            raise ReleaseError('App identity does not match Teaching Timer')
        if (group['id'] != GROUP_ID or group['attributes'].get('isInternalGroup') is not True
                or group['attributes'].get('name') != GROUP_NAME or owner['id'] != APP_ID):
            raise ReleaseError('Destination must be the existing internal Maintainer pilot for this app')

    def find_build(self, version, number):
        query = urlencode({'filter[app]': APP_ID, 'filter[version]': number,
                           'include': 'preReleaseVersion', 'limit': 200})
        matches = []
        for page in self.pages('builds?' + query):
            prereleases = {p['id']: p['attributes'] for p in page.get('included', []) if p['type'] == 'preReleaseVersions'}
            for item in page['data']:
                relationship = item['relationships']['preReleaseVersion']['data']['id']
                info = prereleases.get(relationship)
                if info is None:
                    info = self.request('GET', 'preReleaseVersions/' + relationship)['data']['attributes']
                if info.get('version') == version and info.get('platform') == 'IOS':
                    matches.append(item)
        if len(matches) > 1:
            raise ReleaseError('Ambiguous Apple build identity')
        return matches[0] if matches else None

    def group_contains(self, identifier):
        for page in self.pages('betaGroups/' + GROUP_ID + '/relationships/builds?limit=200'):
            if any(b['id'] == identifier for b in page['data']):
                return True
        return False

    def assign(self, identifier):
        if not self.group_contains(identifier):
            self.request('POST', 'betaGroups/' + GROUP_ID + '/relationships/builds',
                         {'data': [{'type': 'builds', 'id': identifier}]})

    def notes(self, identifier):
        for page in self.pages('builds/' + identifier + '/betaBuildLocalizations?limit=200'):
            for item in page['data']:
                if item['attributes']['locale'] == 'en-US':
                    return item
        return None

    def set_notes(self, identifier, text):
        existing = self.notes(identifier)
        if existing and existing['attributes'].get('whatsNew') == text:
            return
        data = {'type': 'betaBuildLocalizations', 'attributes': {'whatsNew': text}}
        if existing:
            data['id'] = existing['id']
            self.request('PATCH', 'betaBuildLocalizations/' + existing['id'], {'data': data})
        else:
            data['attributes']['locale'] = 'en-US'
            data['relationships'] = {'build': {'data': {'type': 'builds', 'id': identifier}}}
            self.request('POST', 'betaBuildLocalizations', {'data': data})

    def testing_state(self, identifier):
        return self.request('GET', 'builds/' + identifier + '/buildBetaDetail')['data']['attributes']['internalBuildState']


class Journal:
    def __init__(self, folder, identity, resume=False):
        self.folder = Path(folder)
        self.file = self.folder / 'release.json'
        if resume:
            self.data = json.loads(self.file.read_text())
            if self.data['identity'] != identity:
                raise ReleaseError('Resume source, build number, mode or notes differ from the saved release')
            for stage in self.data['stages']:
                if stage['status'] == 'running':
                    stage['status'] = 'interrupted'
        else:
            self.folder.mkdir(parents=True, exist_ok=False)
            self.data = dict(schemaVersion=1, identity=identity, startedAt=now(), status='running',
                uploaded=False, installed=False, physicalDeviceContact=False, stages=[], observations=[])
        self.data['status'] = 'running'
        self.data.pop('error', None)
        self.save()

    def save(self):
        temporary = self.file.with_suffix('.tmp')
        temporary.write_text(json.dumps(self.data, indent=2) + '\n')
        temporary.replace(self.file)
        lines = ['# TestFlight release', '', '**Status:** ' + self.data['status'], '',
                 '| Step | Started (UTC) | Seconds | Result |', '| --- | --- | ---: | --- |']
        for stage in self.data['stages'] + self.data.get('preparationSteps', []):
            lines.append('| {name} | {startedAt} | {elapsedSeconds} | {status} |'.format(
                **dict(stage, elapsedSeconds=stage.get('elapsedSeconds', 'unknown'))))
        lines += ['', 'Build: ' + self.data['identity']['build'],
                  'Source: ' + self.data['identity']['source'], '',
                  'Readiness is first observed server-side availability, not device download or installation.',
                  'Interrupted/resumed runs retain separate attempts; durations do not invent time for interrupted steps.']
        ci = self.data.get('github', {})
        if ci:
            lines += ['', 'Workflow created (UTC): ' + str(ci.get('workflowCreatedAt')),
                      'Workflow started (UTC): ' + str(ci.get('workflowStartedAt')),
                      'Xcode: ' + str(ci.get('xcode', '')).replace('\n', ' / ')]
            for job in ci.get('jobs', []):
                lines.append('Job ' + job['name'] + ': ' + str(job['startedAt']) + ' → ' + str(job['completedAt']))
        if self.data.get('uploadCommandSucceededAt') and self.data.get('availabilityConfirmedAt'):
            elapsed = (datetime.fromisoformat(self.data['availabilityConfirmedAt'])
                       - datetime.fromisoformat(self.data['uploadCommandSucceededAt'])).total_seconds()
            lines += ['', 'Upload completion to first confirmed availability: ' + str(round(elapsed, 3)) + ' seconds.']
        (self.folder / 'summary.md').write_text('\n'.join(lines) + '\n')

    @contextmanager
    def stage(self, name):
        started = time.monotonic()
        stage = dict(name=name, startedAt=now(), status='running')
        self.data['stages'].append(stage)
        self.save()
        try:
            yield
            stage['status'] = 'passed'
        except BaseException:
            stage['status'] = 'failed'
            raise
        finally:
            stage.update(endedAt=now(), elapsedSeconds=round(time.monotonic() - started, 3))
            self.save()

    def observe(self, kind, state):
        self.data['observations'].append(dict(kind=kind, state=state, at=now()))
        self.save()


def wait_for(journal, kind, sample, ready, failed, timeout, interval, sleep=time.sleep, clock=time.monotonic):
    until = clock() + timeout
    while True:
        value = sample()
        journal.observe(kind, value)
        if failed(value):
            raise ReleaseError(kind + ' reported a terminal failure: ' + str(value))
        if ready(value):
            return value
        remaining = until - clock()
        if remaining <= 0:
            raise ReleaseError(kind + ' timed out; the saved release can be resumed')
        sleep(min(interval, remaining))


def publish_metadata(apple, journal, notes, timeout, interval, sleep=time.sleep, clock=time.monotonic):
    identity = journal.data['identity']
    journal.data['pollIntervalSeconds'] = interval
    identifier = journal.data.get('appleBuildID')
    def processing():
        nonlocal identifier
        item = apple.find_build(identity['version'], identity['build'])
        if item is None:
            return 'NOT_YET_VISIBLE'
        if identifier and identifier != item['id']:
            raise ReleaseError('Apple build identity changed while resuming')
        identifier = item['id']
        if item['attributes'].get('buildAudienceType') != 'INTERNAL_ONLY':
            raise ReleaseError('Apple build is not marked internal-only; refusing automatic distribution')
        journal.data['appleBuildID'] = identifier
        if item['attributes'].get('uploadedDate'):
            journal.data['appleReportedUploadDate'] = item['attributes']['uploadedDate']
        journal.save()
        return item['attributes']['processingState']
    with journal.stage('apple_processing'):
        wait_for(journal, 'processing', processing, lambda s: s == 'VALID',
                 lambda s: s in {'FAILED', 'INVALID'}, timeout, interval, sleep, clock)
    with journal.stage('testing_notes'):
        apple.set_notes(identifier, notes)
        wait_for(journal, 'notes_verified', lambda: (apple.notes(identifier) or {}).get('attributes', {}).get('whatsNew') == notes,
                 bool, lambda _: False, timeout, interval, sleep, clock)
    with journal.stage('maintainer_assignment'):
        apple.assign(identifier)
        wait_for(journal, 'group_verified', lambda: apple.group_contains(identifier), bool, lambda _: False,
                 timeout, interval, sleep, clock)
    with journal.stage('testflight_availability'):
        wait_for(journal, 'internal_testing', lambda: apple.testing_state(identifier),
                 lambda s: s == 'IN_BETA_TESTING',
                 lambda s: s in {'EXPIRED', 'PROCESSING_EXCEPTION', 'MISSING_EXPORT_COMPLIANCE'},
                 timeout, interval, sleep, clock)
        if not apple.group_contains(identifier):
            raise ReleaseError('Group association disappeared before final verification')
    journal.data.update(status='available', availabilityConfirmedAt=now(), completedAt=now())
    journal.save()


def command(journal, name, arguments, cwd):
    with journal.stage(name):
        with (journal.folder / (name + '.log')).open('wb') as log:
            process = subprocess.Popen(list(map(str, arguments)), cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                code = process.wait(timeout=3600 if name == 'archive_and_export' else 1800)
            except BaseException:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                except ProcessLookupError:
                    pass
                raise
        if code:
            raise ReleaseError(name + ' failed; inspect the private runner log')


def source_identity(source):
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=source, text=True).strip()
    if git('status', '--porcelain=v1', '--untracked-files=all'):
        raise ReleaseError('Application checkout must be clean')
    return git('rev-parse', 'HEAD')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--build-number', required=True, type=build_number)
    parser.add_argument('--notes-file', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--rehearsal', action='store_true')
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--signing-config', type=Path)
    parser.add_argument('--ci-timing-file', type=Path)
    parser.add_argument('--poll-seconds', type=int, default=15)
    parser.add_argument('--timeout-seconds', type=int, default=1200)
    args = parser.parse_args(argv)
    if not 5 <= args.poll_seconds <= 60 or not 30 <= args.timeout_seconds <= 3600:
        parser.error('Polling must be 5–60 seconds; timeout must be 30–3600 seconds')
    source = args.source.resolve()
    notes = args.notes_file.read_text()
    if not notes.strip() or len(notes) > 4000:
        parser.error('Testing notes must contain 1–4000 characters')
    # Marketing version is read from the reviewed source, never supplied separately.
    project = (source / 'TeachingTimer.xcodeproj/project.pbxproj').read_text()
    versions = set(re.findall(r'MARKETING_VERSION = ([0-9.]+);', project))
    if len(versions) != 1:
        parser.error('Expected one consistent marketing version in the application project')
    identity = dict(source=source_identity(source), version=versions.pop(), build=args.build_number,
                    app=APP_ID, group=GROUP_ID, notesSHA256=hashlib.sha256(notes.encode()).hexdigest(),
                    rehearsal=args.rehearsal)
    journal = Journal(args.output.resolve(), identity, args.resume)
    if args.ci_timing_file:
        journal.data['github'] = json.loads(args.ci_timing_file.read_text())
        journal.save()
    try:
        apple = None
        if not args.rehearsal:
            with journal.stage('destination_preflight'):
                values = [os.environ.get(n) for n in ['ASC_TOKEN_HELPER', 'ASC_KEY_PATH', 'ASC_KEY_ID', 'ASC_ISSUER_ID']]
                if not all(values):
                    raise ReleaseError('Publishing requires API credentials')
                apple = Apple(Token(*values))
                apple.validate_destination()
                if apple.find_build(identity['version'], identity['build']) and not journal.data.get('uploadStartedAt'):
                    raise ReleaseError('This build number already exists at Apple; choose an unused number')
            if journal.data.get('uploadStartedAt'):
                if not journal.data.get('uploadCommandSucceededAt'):
                    raise ReleaseError('Previous upload outcome is uncertain; inspect its log before retrying. No upload repeated.')
                # A downloaded report is enough to resume metadata after upload;
                # distribution keys and the private IPA need not be retained.
                if not journal.data.get('localExportSHA256'):
                    raise ReleaseError('Saved release has no verified artifact fingerprint')
                publish_metadata(apple, journal, notes, args.timeout_seconds, args.poll_seconds)
                return
            if not args.signing_config:
                raise ReleaseError('A new publication requires private CI signing configuration')
        preparation = journal.folder / 'preparation'
        if not (preparation / 'readiness.json').exists() or not args.resume:
            arguments = [sys.executable, ROOT / 'scripts/prepare-testflight.py', '--source', source,
                         '--build-number', args.build_number]
            if not args.rehearsal:
                arguments += ['--signed', '--signing-config', args.signing_config.resolve()]
            command(journal, 'archive_and_export', arguments + [preparation], source)
        report = json.loads((preparation / 'readiness.json').read_text())
        if source_identity(source) != identity['source']:
            raise ReleaseError('Application source changed during preparation')
        if report.get('failed') or report.get('build') != identity['build'] or report.get('revision') != identity['source']:
            raise ReleaseError('Preparation failed or does not match the recorded source/build')
        journal.data['preparationSteps'] = [{k: s[k] for k in ['name', 'startedAt', 'elapsedSeconds', 'status']}
                                           for s in report['steps']]
        if args.rehearsal:
            journal.data.update(status='rehearsal_complete', uploaded=False, completedAt=now())
            journal.save()
            return
        if (report.get('stage') != 'signed_internal_testflight_export_verified'
                or report.get('sourceRevisionVerified') is not True or report['export']['passed'] is not True):
            raise ReleaseError('Publishing requires the verified internal-only signed export')
        fingerprint = report['export']['sha256']
        packages = list((preparation / 'export').glob('*.ipa'))
        if len(packages) != 1 or hashlib.sha256(packages[0].read_bytes()).hexdigest() != fingerprint:
            raise ReleaseError('Exported package differs from the verified artifact')
        if journal.data.get('localExportSHA256', fingerprint) != fingerprint:
            raise ReleaseError('Resume artifact differs from the saved release')
        journal.data['localExportSHA256'] = fingerprint
        if not journal.data.get('uploadStartedAt'):
            options = plistlib.loads((preparation / 'ExportOptions.plist').read_bytes())
            if options.get('testFlightInternalTestingOnly') is not True:
                raise ReleaseError('Refusing a non-internal-only release')
            options['destination'] = 'upload'
            upload_options = journal.folder / 'UploadOptions.plist'
            upload_options.write_bytes(plistlib.dumps(options))
            journal.data['uploadStartedAt'] = now()
            journal.save()  # An interrupted upload must be reconciled, never blindly repeated.
            command(journal, 'upload', ['xcodebuild', '-exportArchive', '-archivePath', preparation / 'TeachingTimer.xcarchive',
                '-exportOptionsPlist', upload_options, '-exportPath', journal.folder / 'upload',
                '-authenticationKeyPath', os.environ['ASC_KEY_PATH'], '-authenticationKeyID', os.environ['ASC_KEY_ID'],
                '-authenticationKeyIssuerID', os.environ['ASC_ISSUER_ID']], source)
            journal.data['uploadCommandSucceededAt'] = now()
            journal.data['uploaded'] = True
            journal.save()
        publish_metadata(apple, journal, notes, args.timeout_seconds, args.poll_seconds)
    except BaseException as error:
        journal.data.update(status='failed', error=str(error) if isinstance(error, ReleaseError) else type(error).__name__)
        journal.save()
        raise


if __name__ == '__main__':
    os.umask(0o077)
    try:
        main()
    except (ReleaseError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(str(error) if isinstance(error, ReleaseError) else type(error).__name__, file=sys.stderr)
        sys.exit(1)
