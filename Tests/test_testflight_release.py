# SPDX-License-Identifier: MPL-2.0
import base64
from datetime import datetime, timedelta
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]

def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

release = load('release', 'testflight-release.py')
signing = load('ci_signing', 'ci-signing.py')


class FakeClock:
    def __init__(self): self.value = 0
    def __call__(self): return self.value
    def sleep(self, value): self.value += value


class FakeApple:
    def __init__(self, states=None):
        self.states = list(states or ['VALID'])
        self.text = None; self.assigned = False; self.writes = 0; self.samples = 0
    def find_build(self, version, number):
        self.samples += 1
        state = self.states.pop(0) if len(self.states) > 1 else self.states[0]
        return None if state == 'MISSING' else dict(id='build-42', attributes=dict(processingState=state, buildAudienceType='INTERNAL_ONLY'))
    def set_notes(self, identifier, text):
        if self.text != text: self.writes += 1; self.text = text
    def notes(self, identifier): return dict(attributes=dict(whatsNew=self.text))
    def assign(self, identifier):
        if not self.assigned: self.writes += 1; self.assigned = True
    def group_contains(self, identifier): return self.assigned
    def testing_state(self, identifier): return 'IN_BETA_TESTING' if self.assigned else 'READY_FOR_BETA_TESTING'


class ReleaseChecks(unittest.TestCase):
    def journal(self, folder, resume=False, identity=None):
        return release.Journal(Path(folder) / 'report', identity or dict(source='a'*40, version='1.0', build='42',
            app=release.APP_ID, group=release.GROUP_ID, notesSHA256='test', rehearsal=False), resume)

    def test_waits_for_processing_and_only_then_distributes(self):
        with tempfile.TemporaryDirectory() as folder:
            journal = self.journal(folder); apple = FakeApple(['MISSING', 'PROCESSING', 'VALID']); clock = FakeClock()
            release.publish_metadata(apple, journal, 'Test notes', 60, 15, clock.sleep, clock)
            self.assertEqual(clock.value, 30)
            self.assertEqual(apple.writes, 2)
            self.assertEqual(journal.data['status'], 'available')
            self.assertFalse(journal.data['installed'])
            self.assertEqual(journal.data['appleBuildID'], 'build-42')
            self.assertEqual([o['state'] for o in journal.data['observations'][:3]], ['NOT_YET_VISIBLE', 'PROCESSING', 'VALID'])
            self.assertIn('not device download', (journal.folder / 'summary.md').read_text())

    def test_invalid_processing_never_writes_notes_or_group(self):
        for state in ['FAILED', 'INVALID']:
            with self.subTest(state=state), tempfile.TemporaryDirectory() as folder:
                apple = FakeApple([state]); journal = self.journal(folder); clock = FakeClock()
                with self.assertRaisesRegex(release.ReleaseError, 'terminal failure'):
                    release.publish_metadata(apple, journal, 'Notes', 30, 15, clock.sleep, clock)
                self.assertEqual(apple.writes, 0)
                self.assertEqual(journal.data['stages'][0]['status'], 'failed')

    def test_timeout_is_bounded_and_saved_for_resume(self):
        with tempfile.TemporaryDirectory() as folder:
            apple = FakeApple(['PROCESSING']); journal = self.journal(folder); clock = FakeClock()
            with self.assertRaisesRegex(release.ReleaseError, 'timed out'):
                release.publish_metadata(apple, journal, 'Notes', 31, 15, clock.sleep, clock)
            self.assertEqual(clock.value, 31)
            self.assertEqual(apple.writes, 0)
            saved = json.loads(journal.file.read_text())
            self.assertEqual(saved['appleBuildID'], 'build-42')
            resumed = self.journal(folder, resume=True)
            apple.states = ['VALID']
            release.publish_metadata(apple, resumed, 'Notes', 31, 15, clock.sleep, clock)
            self.assertEqual(resumed.data['status'], 'available')
            self.assertEqual(len([s for s in resumed.data['stages'] if s['name']=='apple_processing']), 2)

    def test_repeating_metadata_is_idempotent(self):
        with tempfile.TemporaryDirectory() as folder:
            journal = self.journal(folder); apple = FakeApple(); clock = FakeClock()
            for _ in range(2):
                release.publish_metadata(apple, journal, 'Notes', 30, 15, clock.sleep, clock)
            self.assertEqual(apple.writes, 2)

    def test_resume_rejects_changed_source_build_or_notes(self):
        with tempfile.TemporaryDirectory() as folder:
            journal = self.journal(folder)
            for key in ['source','build','notesSHA256','group','rehearsal']:
                identity = dict(journal.data['identity'], **{key: 'different'})
                with self.subTest(key=key), self.assertRaisesRegex(release.ReleaseError, 'Resume'):
                    self.journal(folder, resume=True, identity=identity)

    def test_interrupted_stage_does_not_invent_duration(self):
        with tempfile.TemporaryDirectory() as folder:
            journal = self.journal(folder)
            journal.data['stages'].append(dict(name='upload', startedAt=release.now(), status='running'))
            journal.save()
            resumed = self.journal(folder, resume=True)
            self.assertEqual(resumed.data['stages'][0]['status'], 'interrupted')
            self.assertNotIn('elapsedSeconds', resumed.data['stages'][0])
            self.assertIn('unknown', (resumed.folder/'summary.md').read_text())

    def test_changed_remote_build_or_external_audience_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            journal = self.journal(folder); apple = FakeApple(); clock = FakeClock()
            journal.data['appleBuildID']='another-build'
            with self.assertRaisesRegex(release.ReleaseError, 'identity changed'):
                release.publish_metadata(apple, journal, 'Notes', 30, 15, clock.sleep, clock)
            journal.data.pop('appleBuildID')
            apple.find_build=lambda *args: dict(id='build-42', attributes=dict(processingState='VALID', buildAudienceType='APP_STORE_ELIGIBLE'))
            with self.assertRaisesRegex(release.ReleaseError, 'not marked internal-only'):
                release.publish_metadata(apple, journal, 'Notes', 30, 15, clock.sleep, clock)

    def test_group_membership_alone_is_not_available(self):
        with tempfile.TemporaryDirectory() as folder:
            journal = self.journal(folder); apple=FakeApple(); clock=FakeClock()
            apple.testing_state=lambda _: 'READY_FOR_BETA_TESTING'
            with self.assertRaisesRegex(release.ReleaseError, 'timed out'):
                release.publish_metadata(apple, journal, 'Notes', 30, 15, clock.sleep, clock)
            self.assertNotEqual(journal.data['status'], 'available')

    def test_assignment_404_after_valid_processing_recovers_without_new_upload(self):
        with tempfile.TemporaryDirectory() as folder:
            journal = self.journal(folder); apple = FakeApple(); clock = FakeClock()
            assign = apple.assign; attempts = []
            def eventual(identifier):
                attempts.append(identifier)
                if len(attempts) == 1:
                    raise release.APIError(404, 'POST', 'betaGroups/' + release.GROUP_ID + '/relationships/builds')
                assign(identifier)
            apple.assign = eventual
            release.publish_metadata(apple, journal, 'Notes', 60, 15, clock.sleep, clock)
            self.assertEqual(clock.value, 15)
            self.assertEqual(attempts, ['build-42', 'build-42'])
            self.assertEqual(journal.data['status'], 'available')
            self.assertEqual(apple.writes, 2)  # One notes write and one assignment.
            self.assertFalse(journal.data['uploaded'])  # Metadata never uploads.

    def test_assignment_404_retry_is_bounded_and_recorded(self):
        with tempfile.TemporaryDirectory() as folder:
            journal = self.journal(folder); apple = FakeApple(); clock = FakeClock()
            def unavailable(_):
                raise release.APIError(404, 'POST', 'betaGroups/' + release.GROUP_ID + '/relationships/builds')
            apple.assign = unavailable
            with self.assertRaisesRegex(release.ReleaseError, 'group_verified timed out'):
                release.publish_metadata(apple, journal, 'Notes', 31, 15, clock.sleep, clock)
            self.assertEqual(clock.value, 31)
            self.assertEqual(journal.data['stages'][-1]['status'], 'failed')
            self.assertEqual(len([o for o in journal.data['observations'] if o['kind'] == 'assignment_not_yet_available']), 4)
            self.assertNotEqual(journal.data['status'], 'available')

    def test_other_assignment_errors_are_not_retried(self):
        path = 'betaGroups/' + release.GROUP_ID + '/relationships/builds'
        for status, method, resource in [(403, 'POST', path), (409, 'POST', path), (500, 'POST', path),
                                         (404, 'GET', path), (404, 'POST', 'other')]:
            with self.subTest(status=status, method=method, path=resource), tempfile.TemporaryDirectory() as folder:
                journal = self.journal(folder); apple = FakeApple(); clock = FakeClock()
                def rejected(_):
                    raise release.APIError(status, method, resource)
                apple.assign = rejected
                with self.assertRaises(release.APIError):
                    release.publish_metadata(apple, journal, 'Notes', 60, 15, clock.sleep, clock)
                self.assertEqual(clock.value, 0)

    def test_invalid_build_numbers(self):
        for value in ['0','-1','42; echo nope','42\n','00042','1.0','1234567890','nan','261104.1602.0']:
            with self.subTest(value=value), self.assertRaises(release.ReleaseError): release.build_number(value)
        self.assertEqual(release.build_number('42'), '42')
        self.assertEqual(release.build_number('261104.1602.1'), '261104.1602.1')


class APIchecks(unittest.TestCase):
    def test_only_matching_marketing_version_and_platform_is_selected(self):
        apple=release.Apple(lambda:'fixture')
        items=[]; included=[]
        for index,(version,platform_) in enumerate([('1.0','IOS'),('2.0','IOS'),('1.0','MAC_OS')]):
            items.append(dict(id=str(index), relationships={'preReleaseVersion':{'data':{'id':str(index)}}}))
            included.append(dict(id=str(index),type='preReleaseVersions', attributes=dict(version=version,platform=platform_)))
        apple.pages=lambda path: iter([dict(data=items,included=included)])
        self.assertEqual(apple.find_build('1.0','42')['id'],'0')
        items.append(items[0])
        with self.assertRaisesRegex(release.ReleaseError,'Ambiguous'): apple.find_build('1.0','42')

    def test_wrong_app_or_external_group_cannot_be_assigned(self):
        for failure in ['app','name','external','owner']:
            with self.subTest(failure=failure):
                apple=release.Apple(lambda:'fixture')
                data=[dict(id=release.APP_ID,attributes=dict(bundleId='wrong' if failure=='app' else release.BUNDLE_ID)),
                      dict(id=release.GROUP_ID,attributes=dict(name='wrong' if failure=='name' else release.GROUP_NAME,isInternalGroup=failure!='external')),
                      dict(id='wrong' if failure=='owner' else release.APP_ID)]
                apple.request=lambda *args: dict(data=data.pop(0))
                with self.assertRaises(release.ReleaseError): apple.validate_destination()

    def test_group_assignment_writes_only_existing_pinned_group(self):
        apple=release.Apple(lambda:'fixture'); calls=[]
        apple.group_contains=lambda _:False
        apple.request=lambda *args: calls.append(args)
        apple.assign('build-42')
        self.assertEqual(calls,[('POST','betaGroups/'+release.GROUP_ID+'/relationships/builds',{'data':[{'type':'builds','id':'build-42'}]})])
        apple.group_contains=lambda _:True
        apple.assign('build-42');self.assertEqual(len(calls),1)

    def test_pagination_cannot_forward_bearer_to_another_host(self):
        apple=release.Apple(lambda:self.fail('Token must not be requested'))
        for url in ['https://evil.example/v1/builds', 'https://api.appstoreconnect.apple.com.evil.example/v1/builds']:
            with self.subTest(url=url), self.assertRaises(release.ReleaseError): apple.request('GET',url)
        apple.request=lambda *args:dict(data=[],links={'next':'same'})
        with self.assertRaisesRegex(release.ReleaseError,'pagination'): list(apple.pages('same'))

    def test_get_retries_rate_limits_but_mutation_does_not_blindly_repeat(self):
        class Opener:
            def __init__(self): self.calls=0
            def open(self,*args,**kwargs):
                self.calls+=1
                raise HTTPError(release.API,429,'raw-private-server-body',{'Retry-After':'1'},None)
        for method,count in [('GET',4),('POST',1)]:
            opener=Opener();clock=FakeClock();apple=release.Apple(lambda:'secret-token',opener,clock.sleep)
            with self.assertRaisesRegex(release.ReleaseError,'HTTP 429') as error: apple.request(method,'builds')
            self.assertEqual(opener.calls,count)
            self.assertIsInstance(error.exception, release.APIError)
            self.assertEqual((error.exception.status, error.exception.method, error.exception.path), (429, method, 'builds'))
            self.assertNotIn('secret-token',str(error.exception));self.assertNotIn('private',str(error.exception))

    def test_notes_create_update_and_noop(self):
        apple=release.Apple(lambda:'fixture');calls=[]
        apple.notes=lambda _:None;apple.request=lambda *args:calls.append(args)
        apple.set_notes('build-42','Notes')
        self.assertEqual(calls[-1][0:2],('POST','betaBuildLocalizations'))
        self.assertEqual(calls[-1][2]['data']['relationships']['build']['data']['id'],'build-42')
        apple.notes=lambda _:dict(id='locale-id',attributes=dict(whatsNew='old'))
        apple.set_notes('build-42','Notes');self.assertEqual(calls[-1][0:2],('PATCH','betaBuildLocalizations/locale-id'))
        apple.notes=lambda _:dict(id='locale-id',attributes=dict(whatsNew='Notes'))
        apple.set_notes('build-42','Notes');self.assertEqual(len(calls),2)


class SigningChecks(unittest.TestCase):
    def test_profile_requires_distribution_both_exact_identity_and_validity(self):
        profile=dict(TeamIdentifier=[signing.TEAM],UUID='12345678-1234-1234-1234-123456789ABC',
            ExpirationDate=datetime.now()+timedelta(days=2),Entitlements={
                'application-identifier':signing.TEAM+'.'+signing.WATCH,'get-task-allow':False,'beta-reports-active':True})
        self.assertTrue(signing.profile_valid(profile,signing.WATCH))
        self.assertFalse(signing.profile_valid(profile,signing.CONTAINER))
        for field,value in [('ProvisionedDevices',['device']),('ProvisionsAllDevices',True),
                            ('ExpirationDate',datetime.now()-timedelta(seconds=1)),('UUID','../../escape')]:
            wrong=dict(profile,**{field:value});self.assertFalse(signing.profile_valid(wrong,signing.WATCH))

    def test_missing_credentials_fail_before_touching_keychain(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict('os.environ',{},clear=True), patch.object(signing,'run') as run:
            with self.assertRaisesRegex(ValueError,'Missing GitHub'): signing.setup(Path(folder)/'keys')
            run.assert_not_called()

    def test_missing_complication_profile_fails_before_touching_keychain(self):
        environment = {name: 'synthetic' for name in signing.REQUIRED if name != 'COMPLICATION_PROFILE_BASE64'}
        with tempfile.TemporaryDirectory() as folder, patch.dict('os.environ', environment, clear=True), \
                patch.object(signing, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'COMPLICATION_PROFILE_BASE64'):
                signing.setup(Path(folder) / 'keys')
            run.assert_not_called()


@unittest.skipUnless(platform.system()=='Darwin' and shutil.which('swiftc') and shutil.which('openssl'), 'Apple CryptoKit token helper')
class TokenChecks(unittest.TestCase):
    def test_real_es256_token_verifies_independently_with_openssl(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); helper=root/'token'; key=root/'key.p8'; public=root/'public.pem'
            subprocess.run(['swiftc',str(ROOT/'scripts/asc-token.swift'),'-o',str(helper)],check=True,capture_output=True)
            subprocess.run(['openssl','genpkey','-algorithm','EC','-pkeyopt','ec_paramgen_curve:P-256','-out',str(key)],check=True,capture_output=True)
            subprocess.run(['openssl','pkey','-in',str(key),'-pubout','-out',str(public)],check=True,capture_output=True)
            token=subprocess.check_output([str(helper),str(key),'KEYID','ISSUER'],text=True).strip();header,claims,signature=token.split('.')
            decode=lambda s:base64.urlsafe_b64decode(s+'='*(-len(s)%4))
            self.assertEqual(json.loads(decode(header)),dict(alg='ES256',kid='KEYID',typ='JWT'))
            values=json.loads(decode(claims));self.assertEqual(values['exp']-values['iat'],900)
            self.assertEqual(values['iss'],'ISSUER');self.assertEqual(values['aud'],'appstoreconnect-v1')
            raw=decode(signature);self.assertEqual(len(raw),64)
            def der_integer(value):
                value=value.lstrip(b'\0') or b'\0'
                if value[0]&128:value=b'\0'+value
                return b'\x02'+bytes([len(value)])+value
            sequence=der_integer(raw[:32])+der_integer(raw[32:]);der=b'\x30'+bytes([len(sequence)])+sequence
            (root/'signature').write_bytes(der);(root/'message').write_bytes((header+'.'+claims).encode())
            check=['openssl','dgst','-sha256','-verify',str(public),'-signature',str(root/'signature'),str(root/'message')]
            self.assertEqual(subprocess.run(check,capture_output=True).returncode,0)
            (root/'message').write_bytes(b'tampered')
            self.assertNotEqual(subprocess.run(check,capture_output=True).returncode,0)


class PublicationChecks(unittest.TestCase):
    def run_release(self, folder, apple, *, rehearsal=False, resume=False, upload_error=False, exported_stage=None):
        root=Path(folder);source=root/'source';source.mkdir(exist_ok=True)
        project=source/'TeachingTimer.xcodeproj';project.mkdir(exist_ok=True)
        (project/'project.pbxproj').write_text('MARKETING_VERSION = 1.0;\n')
        notes=root/'notes.txt';notes.write_text('Test notes')
        arguments=['--source',str(source),'--build-number','42','--notes-file',str(notes),
                   '--output',str(root/'report'),'--timeout-seconds','30']
        if rehearsal:arguments+=['--rehearsal']
        else:arguments+=['--signing-config',str(root/'signing.json')]
        if resume:arguments+=['--resume']
        commands=[]
        def command(journal,name,args,cwd):
            commands.append(name)
            with journal.stage(name):
                if name=='archive_and_export':
                    output=Path(args[-1]);(output/'export').mkdir(parents=True)
                    ipa=output/'export/candidate.ipa';ipa.write_bytes(b'fixture IPA')
                    data=dict(build='42',revision='a'*40,sourceRevisionVerified=True,steps=[],
                        stage=exported_stage or ('unsigned_archive_verified' if rehearsal else 'signed_internal_testflight_export_verified'),
                        export=dict(passed=True,sha256=hashlib.sha256(ipa.read_bytes()).hexdigest()))
                    (output/'readiness.json').write_text(json.dumps(data))
                    (output/'ExportOptions.plist').write_bytes(plistlib.dumps(dict(testFlightInternalTestingOnly=True)))
                elif upload_error:raise release.ReleaseError('Upload connection interrupted')
        apple.validate_destination=lambda:None
        environment=dict(ASC_TOKEN_HELPER='unused-helper',ASC_KEY_PATH='unused-key',ASC_KEY_ID='fixture',ASC_ISSUER_ID='fixture')
        with patch.object(release,'source_identity',return_value='a'*40),patch.object(release,'Apple',return_value=apple) as factory,\
             patch.object(release,'command',side_effect=command),patch.dict('os.environ',environment,clear=True):
            error=None
            try:release.main(arguments)
            except release.ReleaseError as failure:error=str(failure)
        return json.loads((root/'report/release.json').read_text()),error,commands,factory.call_count

    def test_full_publication_records_upload_and_availability(self):
        with tempfile.TemporaryDirectory() as folder:
            data,error,commands,_=self.run_release(folder,FakeApple(['MISSING','VALID']))
            self.assertIsNone(error);self.assertEqual(commands,['archive_and_export','upload'])
            self.assertTrue(data['uploaded']);self.assertEqual(data['status'],'available')
            self.assertFalse(data['installed']);self.assertIn('uploadCommandSucceededAt',data)

    def test_rehearsal_never_constructs_api_client_or_uploads(self):
        with tempfile.TemporaryDirectory() as folder:
            data,error,commands,clients=self.run_release(folder,FakeApple(),rehearsal=True)
            self.assertIsNone(error);self.assertEqual(clients,0)
            self.assertEqual(commands,['archive_and_export']);self.assertFalse(data['uploaded'])
            self.assertEqual(data['status'],'rehearsal_complete')

    def test_existing_apple_build_stops_before_any_build_or_upload(self):
        with tempfile.TemporaryDirectory() as folder:
            data,error,commands,_=self.run_release(folder,FakeApple())
            self.assertIn('already exists',error);self.assertEqual(commands,[])
            self.assertEqual(data['status'],'failed')

    def test_non_internal_export_is_not_uploaded(self):
        with tempfile.TemporaryDirectory() as folder:
            _,error,commands,_=self.run_release(folder,FakeApple(['MISSING']),exported_stage='signed_external_testflight_export_verified')
            self.assertIn('internal-only',error);self.assertEqual(commands,['archive_and_export'])

    def test_uncertain_upload_is_never_repeated_or_silently_accepted(self):
        with tempfile.TemporaryDirectory() as folder:
            data,error,commands,_=self.run_release(folder,FakeApple(['MISSING']),upload_error=True)
            self.assertIn('interrupted',error);self.assertIn('uploadStartedAt',data)
            self.assertNotIn('uploadCommandSucceededAt',data)
            data,error,commands,_=self.run_release(folder,FakeApple(),resume=True)
            self.assertIn('uncertain',error);self.assertEqual(commands,[])
            self.assertNotEqual(data['status'],'available')

    def test_metadata_resume_uses_only_downloaded_report_no_ipa_or_signing_keys(self):
        with tempfile.TemporaryDirectory() as folder:
            data,error,_,_=self.run_release(folder,FakeApple(['MISSING','VALID']))
            self.assertIsNone(error)
            shutil.rmtree(Path(folder)/'report/preparation')
            apple=FakeApple()
            data,error,commands,_=self.run_release(folder,apple,resume=True)
            self.assertIsNone(error);self.assertEqual(commands,[])
            self.assertEqual(data['status'],'available')


class CredentialCleanupChecks(unittest.TestCase):
    def test_setup_failure_restores_search_list_and_preserves_preexisting_profiles(self):
        with tempfile.TemporaryDirectory() as folder:
            home=Path(folder);private=home/'private'; calls=[]
            uuids=['12345678-1234-1234-1234-123456789ABC','12345678-1234-1234-1234-123456789ABD',
                   '12345678-1234-1234-1234-123456789ABE']
            profiles=[]
            for identifier,uuid in zip([signing.CONTAINER,signing.WATCH,signing.COMPLICATION],uuids):
                profiles.append(dict(TeamIdentifier=[signing.TEAM],UUID=uuid,ExpirationDate=datetime.now()+timedelta(days=2),
                    Entitlements={'application-identifier':signing.TEAM+'.'+identifier,'get-task-allow':False,'beta-reports-active':True}))
            existing=home/'Library/MobileDevice/Provisioning Profiles'/(uuids[0]+'.mobileprovision')
            existing.parent.mkdir(parents=True);existing.write_bytes(b'container-profile')
            env=dict(ASC_KEY_ID='key',ASC_ISSUER_ID='issuer',ASC_PRIVATE_KEY_BASE64=base64.b64encode(b'fixture-key').decode(),
                DISTRIBUTION_CERTIFICATE_BASE64=base64.b64encode(b'fixture-certificate').decode(),DISTRIBUTION_CERTIFICATE_PASSWORD='fixture-password',
                CONTAINER_PROFILE_BASE64=base64.b64encode(b'container-profile').decode(),
                WATCH_PROFILE_BASE64=base64.b64encode(b'watch-profile').decode(),
                COMPLICATION_PROFILE_BASE64=base64.b64encode(b'complication-profile').decode())
            def run(*args):
                calls.append(args)
                if args[1:]==('list-keychains','-d','user'):return b'"original.keychain-db"\n'
                if args[1:4]==('cms','-D','-i'):
                    index = 0 if 'container.mobileprovision' in args[-1] else 1 if 'watch.mobileprovision' in args[-1] else 2
                    return plistlib.dumps(profiles[index])
                if args[1]=='create-keychain':Path(args[-1]).touch()
                if args[1:5]==('list-keychains','-d','user','-s') and str(private/'release.keychain-db') in args:
                    raise ValueError('synthetic search-list installation failure')
                return b''
            with patch.dict('os.environ',env,clear=True),patch.object(signing.Path,'home',return_value=home),patch.object(signing,'run',side_effect=run):
                with self.assertRaisesRegex(ValueError,'synthetic'):signing.setup(private)
            self.assertFalse(private.exists())
            self.assertEqual(existing.read_bytes(),b'container-profile')
            self.assertIn(('security','list-keychains','-d','user','-s','original.keychain-db'),calls)
            remaining=list(home.rglob('*.mobileprovision'));self.assertEqual(remaining,[existing])

    def test_setup_assigns_distinct_profiles_to_watch_app_and_complication_then_cleans_all(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            private = home / 'private'
            identifiers = [signing.CONTAINER, signing.WATCH, signing.COMPLICATION]
            profiles = {}
            environment = {
                'ASC_KEY_ID': 'synthetic-key', 'ASC_ISSUER_ID': 'synthetic-issuer',
                'ASC_PRIVATE_KEY_BASE64': base64.b64encode(b'synthetic-api-key').decode(),
                'DISTRIBUTION_CERTIFICATE_BASE64': base64.b64encode(b'synthetic-p12').decode(),
                'DISTRIBUTION_CERTIFICATE_PASSWORD': 'synthetic-password'}
            for index, (identifier, variable, name) in enumerate(zip(identifiers,
                    ['CONTAINER_PROFILE_BASE64', 'WATCH_PROFILE_BASE64', 'COMPLICATION_PROFILE_BASE64'],
                    ['container', 'watch', 'complication'])):
                profiles[name + '.mobileprovision'] = dict(TeamIdentifier=[signing.TEAM],
                    UUID=f'12345678-1234-1234-1234-123456789AB{index}',
                    ExpirationDate=datetime.now() + timedelta(days=2), Entitlements={
                        'application-identifier': signing.TEAM + '.' + identifier,
                        'get-task-allow': False, 'beta-reports-active': True})
                environment[variable] = base64.b64encode((name + '-profile').encode()).decode()
            calls = []
            def run(*args):
                calls.append(args)
                if args[1:] == ('list-keychains', '-d', 'user'):
                    return b'"original.keychain-db"\n'
                if args[1:4] == ('cms', '-D', '-i'):
                    return plistlib.dumps(profiles[Path(args[-1]).name])
                if args[1] == 'create-keychain':
                    Path(args[-1]).touch()
                if args[1] == 'delete-keychain':
                    Path(args[-1]).unlink()
                return b''
            with patch.dict('os.environ', environment, clear=True), \
                    patch.object(signing.Path, 'home', return_value=home), patch.object(signing, 'run', side_effect=run):
                key = signing.setup(private)
                self.assertEqual(key.read_bytes(), b'synthetic-api-key')
                configuration = json.loads((private / 'signing.json').read_text())
                self.assertEqual(set(configuration['profiles']), set(identifiers))
                config = (private / 'signing.xcconfig').read_text()
                self.assertNotIn('PROVISIONING_PROFILE_SPECIFIER[sdk=', config)
                for variable, profile in zip(['CONTAINER', 'WATCH', 'COMPLICATION'], profiles.values()):
                    self.assertIn('TEACHINGTIMER_' + variable + '_PROFILE = ' + profile['UUID'], config)
                # Two installed locations plus the three private decoded inputs.
                self.assertEqual(len(list(home.rglob('*.mobileprovision'))), 9)
                signing.cleanup(private)
            self.assertFalse(private.exists())
            self.assertEqual(list(home.rglob('*.mobileprovision')), [])
            self.assertIn(('security', 'list-keychains', '-d', 'user', '-s', 'original.keychain-db'), calls)


class TimingAndProcessChecks(unittest.TestCase):
    def test_stage_duration_uses_monotonic_clock_despite_wall_clock_change(self):
        with tempfile.TemporaryDirectory() as folder:
            journal=release.Journal(Path(folder)/'report',dict(source='a'*40,build='42'))
            with patch.object(release.time,'monotonic',side_effect=[100,103.25]),patch.object(release,'now',side_effect=['2026-11-04T00:00:10+00:00','2026-11-04T00:00:01+00:00']):
                with journal.stage('upload'):pass
            self.assertEqual(journal.data['stages'][0]['elapsedSeconds'],3.25)

    def test_timed_out_upload_stops_its_process_group_and_retains_failed_stage(self):
        with tempfile.TemporaryDirectory() as folder:
            journal=release.Journal(Path(folder)/'report',dict(source='a'*40,build='42'))
            with patch.object(release.subprocess,'Popen') as popen,patch.object(release.os,'killpg') as kill:
                process=popen.return_value;process.pid=123
                process.wait.side_effect=[subprocess.TimeoutExpired('fixture',1),0]
                with self.assertRaises(subprocess.TimeoutExpired):
                    release.command(journal,'upload',['fixture'],folder)
                kill.assert_called_once_with(123,release.signal.SIGTERM)
                self.assertTrue(popen.call_args.kwargs['start_new_session'])
            self.assertEqual(journal.data['stages'][0]['status'],'failed')
