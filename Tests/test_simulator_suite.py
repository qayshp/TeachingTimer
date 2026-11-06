# SPDX-License-Identifier: MPL-2.0
import importlib.util
import json
import hashlib
import plistlib
from unittest.mock import patch
from pathlib import Path
import tempfile
import unittest
import sys

runner_path = Path(__file__).resolve().parents[1] / 'tools/simulator-regression'
sys.path.insert(0, str(runner_path))
spec = importlib.util.spec_from_file_location('simulator_suite', runner_path / 'suite.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)


def media_fixture(folder):
    names = ('03b-media-before-fault-after-five-seconds.png',
             '04b-media-return-after-five-seconds.png', '06b-media-after-five-seconds.png')
    records = []
    for name in names:
        content = ('original fixture ' + name).encode()
        (folder / name).write_bytes(content)
        records.append(dict(file=name, sha256=hashlib.sha256(content).hexdigest(),
                            pixels=dict(width=324, height=394,
                                region='x=0.10...0.90, y=0.22...0.82 (top origin)',
                                visibleFraction=.04, brightFraction=.02,
                                meanChannelMaximum=.01, peakChannel=1)))
    (folder / '07-final.png').touch()
    return dict(checks={k: True for k in suite.LIFECYCLE}, mediaPixelEvidence=records,
                mediaVisualReviewRequired=False, mediaVisualErrors=[])


class SimulatorSuiteChecks(unittest.TestCase):
    def setUp(self):
        metadata = patch.object(suite, 'artifact_identity', return_value={'build': 'fixture'})
        metadata.start()
        self.addCleanup(metadata.stop)

    def test_lifecycle_scenarios_cannot_chain_incompatible_count_state(self):
        self.assertEqual([s[0] for s in suite.stage_plan('focus', True)], ['actions', 'focus', 'controls'])
        self.assertEqual([s[0] for s in suite.stage_plan('media', False)], ['actions', 'media'])

    def test_refresh_target_is_explicit_for_layout_comparisons(self):
        current = suite.stage_plan('focus', False)[1][2]
        legacy = suite.stage_plan('focus', False, .32)[1][2]
        self.assertEqual(current[-2:], ['--volume-refresh-y', '0.34'])
        self.assertEqual(legacy[-2:], ['--volume-refresh-y', '0.32'])
        for invalid in (0, 1, float('nan')):
            with self.assertRaises(ValueError):
                suite.stage_plan('focus', False, invalid)

    def test_empty_checks_and_non_boolean_success_fail_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / '07-final.png').touch()
            self.assertTrue(suite.evidence_errors('media', {'checks': {}}, root))
            self.assertTrue(suite.evidence_errors('media', {'checks': {k: 'true' for k in suite.LIFECYCLE}}, root))
            self.assertTrue(suite.evidence_errors('media', {'checks': {k: True for k in suite.LIFECYCLE}}, root))
            self.assertEqual(suite.evidence_errors('media', media_fixture(root), root), [])

    def test_media_success_claim_cannot_hide_blank_missing_or_invalid_pixel_evidence(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for invalid in (None, {}, {'visibleFraction': .04}):
                evidence = media_fixture(root)
                evidence['mediaPixelEvidence'][1]['pixels'] = invalid
                self.assertTrue(suite.evidence_errors('media', evidence, root))
            for invalid in (0, float('nan'), float('inf'), True, '0.04'):
                evidence = media_fixture(root)
                evidence['mediaPixelEvidence'][1]['pixels'].update(visibleFraction=invalid, brightFraction=0)
                self.assertTrue(suite.evidence_errors('media', evidence, root))
            evidence = media_fixture(root)
            evidence['mediaPixelEvidence'].pop()
            self.assertTrue(suite.evidence_errors('media', evidence, root))
            evidence = media_fixture(root)
            (root / evidence['mediaPixelEvidence'][1]['file']).unlink()
            self.assertTrue(suite.evidence_errors('media', evidence, root))
            for key, value in (('mediaVisualReviewRequired', True), ('mediaVisualReviewRequired', 0),
                               ('mediaVisualErrors', ['visual review required'])):
                evidence = media_fixture(root)
                evidence[key] = value
                self.assertTrue(suite.evidence_errors('media', evidence, root))

    def test_success_without_capture_is_incomplete(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertTrue(suite.evidence_errors('actions', dict(complete=True, passed=list(suite.ACTIONS)), Path(folder)))

    def test_current_action_result_includes_information_pages_and_settings(self):
        # Independent fixture: deriving results from suite.ACTIONS hid the old
        # 14-action wrapper / 21-action runner mismatch.
        passed = [
            'before-class-help-keeps-state', 'before-class-privacy-keeps-state',
            'before-class-about-keeps-state', 'cancel-new-keeps-no-class',
            'default-sixty-started', 'during-class-help-keeps-state',
            'during-class-privacy-keeps-state', 'during-class-about-keeps-state',
            'count-started', 'count-cancelled', 'stop-keeps-class',
            'resume-keeps-class', 'cancel-edit-keeps-schedule',
            'save-edits-only-schedule', 'settings-keeps-existing-class',
            'new-class-replaces-anchor', 'active-class-media-navigation',
            'active-class-timer-return', 'end-clears-class',
            'media-navigation', 'timer-return-keeps-class',
        ]
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for label in passed:
                (root / ('PASS-' + label + '.png')).touch()
            self.assertEqual(suite.evidence_errors('actions', dict(complete=True, passed=passed), root), [])
            for invalid in (passed[:-1], passed + [passed[-1]], passed[:-1] + [passed[0]]):
                self.assertTrue(suite.evidence_errors('actions', dict(complete=True, passed=invalid), root))

    def test_missing_result_stops_sequence_and_retains_manifest(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'suite'
            calls = []
            def fake(command, log, timeout):
                calls.append(command)
                log.write_text('returned success but no evidence')
                return 0
            self.assertFalse(suite.run_suite('fake', Path('fixture.app'), output, 'focus', execute_command=fake))
            self.assertEqual(len(calls), 1)
            report = json.loads((output / 'suite.json').read_text())
            self.assertFalse(report['complete'])
            self.assertEqual(report['stages'][0]['status'], 'failed')
            self.assertTrue((output / 'actions.log').is_file())

    def test_sequence_passes_only_after_all_expected_artifacts(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'suite'
            calls = []
            def fake(command, log, timeout):
                destination = Path(command[command.index('--output') + 1])
                destination.mkdir()
                calls.append(destination.name)
                if destination.name == 'actions':
                    data = dict(complete=True, passed=list(suite.ACTIONS))
                    for label in suite.ACTIONS:
                        (destination / ('PASS-' + label + '.png')).touch()
                else:
                    data = dict(checks={k: True for k in suite.LIFECYCLE | {'manualRefreshRequested'}})
                    (destination / '07-return-crown.png').touch()
                (destination / 'result.json').write_text(json.dumps(data))
                return 0
            self.assertTrue(suite.run_suite('fake', Path('fixture.app'), output, 'focus', execute_command=fake))
            self.assertEqual(calls, ['actions', 'focus'])
            report = json.loads((output / 'suite.json').read_text())
            self.assertTrue(report['complete'])
            self.assertEqual(report['physicalWatchAndPhoneAudio'], 'unverified')

    def test_existing_output_does_not_start_commands(self):
        with tempfile.TemporaryDirectory() as folder:
            def no_commands(*args):
                self.fail('existing output must not run commands')
            with self.assertRaises(FileExistsError):
                suite.run_suite('fake', Path('fixture.app'), Path(folder), execute_command=no_commands)


class SuitePreflightChecks(unittest.TestCase):
    def test_lock_prevents_overlapping_device_hub_suites(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'suite.lock'
            with suite.simulator_lock(path):
                with self.assertRaises(RuntimeError):
                    with suite.simulator_lock(path):
                        self.fail('second suite must not run')
            with suite.simulator_lock(path):
                pass  # Closing the first descriptor releases the lock.

    def test_record_identifies_exact_binary_and_source_metadata(self):
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder)
            (app / 'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleExecutable='TeachingTimer', CFBundleVersion='22')))
            (app / 'BuildInfo.plist').write_bytes(plistlib.dumps(dict(revision='abcd-dirty')))
            (app / 'TeachingTimer').write_bytes(b'fixture')
            metadata = suite.artifact_identity(app)
            self.assertEqual(metadata['build'], '22')
            self.assertEqual(metadata['sourceMetadata']['revision'], 'abcd-dirty')
            self.assertEqual(metadata['executableSHA256'], hashlib.sha256(b'fixture').hexdigest())
