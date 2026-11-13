# SPDX-License-Identifier: MPL-2.0
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest


path = Path(__file__).resolve().parents[1] / 'tools/simulator-regression/ocr.py'
spec = importlib.util.spec_from_file_location('simulator_ocr', path)
ocr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ocr)


class OCRInvocationChecks(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.screenshot = self.root / 'capture.png'
        self.screenshot.write_bytes(b'synthetic fixture; helper does not decode it')
        self.helper = self.root / 'screen-text'

    def script(self, source):
        import sys
        self.helper.write_text(f'#!{sys.executable}\n' + source + '\n')
        self.helper.chmod(0o700)

    def evidence(self):
        return json.loads(self.screenshot.with_suffix('.ocr.json').read_text())

    def test_success_preserves_rows_and_raw_confidence_with_evidence(self):
        rows = [dict(text='Settings', x=.25, y=.5, confidence=.5)]
        self.script(f'print({json.dumps(json.dumps(rows))})\nimport sys; print("backend note", file=sys.stderr)')
        self.assertEqual(ocr.recognize_text(self.helper, self.screenshot), rows)
        evidence = self.evidence()
        self.assertEqual(evidence['status'], 'succeeded')
        self.assertEqual(evidence['rowCount'], 1)
        self.assertEqual(evidence['returnCode'], 0)
        self.assertIn('backend note', evidence['stderrTail'])
        self.assertEqual(evidence['screenshot'], str(self.screenshot.resolve()))
        self.assertGreaterEqual(evidence['durationSeconds'], 0)
        self.assertIn('+00:00', evidence['startedAt'])

    def test_valid_empty_result_is_distinct_from_failure(self):
        self.script('print("[]")')
        self.assertEqual(ocr.recognize_text(self.helper, self.screenshot), [])
        self.assertEqual(self.evidence()['status'], 'succeeded')
        self.assertEqual(self.evidence()['rowCount'], 0)

    def test_valid_mode_and_corroboration_fields_are_preserved(self):
        rows = [dict(text='Settings', x=0, y=1, confidence=.5,
                     recognitionLevel='fast', corroborated=True),
                dict(text='Privacy', x=1, y=0, confidence=.8,
                     recognitionLevel='accurate', corroborated=False)]
        self.script(f'print({json.dumps(json.dumps(rows))})')
        self.assertEqual(ocr.recognize_text(self.helper, self.screenshot), rows)

    def test_invalid_output_raises_and_is_retained(self):
        row = dict(text='Start', x=.5, y=.5, confidence=1)
        bad_rows = ['not JSON', '{}', '[1]', '[{"text": 3}]',
                    json.dumps([dict(row, x=True)]), json.dumps([dict(row, y=-.1)]),
                    json.dumps([dict(row, confidence=1.1)]),
                    json.dumps([dict(row, confidence='1')]),
                    json.dumps([dict(row, x=10 ** 400)]),
                    json.dumps([dict(row, x=float('nan'))]),
                    json.dumps([dict(row, y=float('inf'))]),
                    json.dumps([dict(row, recognitionLevel='turbo')]),
                    json.dumps([dict(row, recognitionLevel=True)]),
                    json.dumps([dict(row, corroborated='true')]),
                    json.dumps([dict(row, corroborated=1)]),
                    '[{"text":"Start","x":0.5,"y":0.5}]']
        for raw in bad_rows:
            with self.subTest(raw=raw):
                self.script(f'print({raw!r})')
                with self.assertRaises(ValueError):
                    ocr.recognize_text(self.helper, self.screenshot)
                evidence = self.evidence()
                self.assertEqual(evidence['status'], 'invalid-output')
                self.assertEqual(evidence['stdoutTail'].strip(), raw)
                self.assertNotIn('rowCount', evidence)

    def test_nonzero_exit_preserves_error_and_bounded_stream_tails(self):
        self.script('import sys\nprint("prefix-" + "o" * 5000 + "-last-out")\n'
                    'print("prefix-" + "e" * 5000 + "-last-error", file=sys.stderr)\nsys.exit(4)')
        with self.assertRaises(subprocess.CalledProcessError) as raised:
            ocr.recognize_text(self.helper, self.screenshot)
        self.assertEqual(raised.exception.returncode, 4)
        evidence = self.evidence()
        self.assertEqual(evidence['status'], 'failed')
        for name, suffix in (('stdout', '-last-out'), ('stderr', '-last-error')):
            self.assertEqual(len(evidence[name + 'Tail']), ocr.EVIDENCE_LIMIT)
            self.assertTrue(evidence[name + 'Truncated'])
            self.assertTrue(evidence[name + 'Tail'].strip().endswith(suffix))
            self.assertNotIn('prefix-', evidence[name + 'Tail'])

    def test_timeout_is_bounded_and_keeps_partial_output(self):
        self.script('import sys, time\n'
                    'print("before perform", file=sys.stderr, flush=True)\n'
                    'print("partial", flush=True)\ntime.sleep(20)')
        with self.assertRaises(subprocess.TimeoutExpired) as raised:
            ocr.recognize_text(self.helper, self.screenshot, timeout_seconds=1)
        self.assertIn(b'partial', raised.exception.output)
        evidence = self.evidence()
        self.assertEqual(evidence['status'], 'timeout')
        self.assertIn('before perform', evidence['stderrTail'])
        self.assertLess(evidence['durationSeconds'], 5)
        self.assertIsNone(evidence['returnCode'])

    def test_missing_helper_is_recorded_as_launch_error(self):
        with self.assertRaises(FileNotFoundError):
            ocr.recognize_text(self.helper, self.screenshot)
        evidence = self.evidence()
        self.assertEqual(evidence['status'], 'launch-error')
        self.assertIsNone(evidence['returnCode'])

    def test_invalid_timeout_does_not_launch_helper(self):
        for timeout in (True, 0, -1, float('nan'), float('inf'), '30'):
            with self.subTest(timeout=timeout), self.assertRaises(ValueError):
                ocr.recognize_text(self.helper, self.screenshot, timeout)


class OCRConfidenceChecks(unittest.TestCase):
    def test_legacy_and_accurate_keep_the_existing_threshold(self):
        for level in (None, 'accurate'):
            for confidence, expected in ((.69, False), (.7, True), (1, True)):
                row = dict(confidence=confidence)
                if level is not None:
                    row['recognitionLevel'] = level
                self.assertEqual(ocr.readable_text(row), expected)

    def test_fast_requires_corroboration_and_raw_confidence(self):
        for confidence, corroborated, expected in ((.5, True, True), (.49, True, False),
                                                  (1, False, False), (1, None, False),
                                                  (.5, 1, False)):
            self.assertEqual(ocr.readable_text(dict(recognitionLevel='fast', confidence=confidence,
                                                    corroborated=corroborated)), expected)

    def test_invalid_confidence_or_mode_cannot_be_used_as_target(self):
        for confidence in (True, None, '1', -.1, 1.1, float('nan'), float('inf')):
            self.assertFalse(ocr.readable_text(dict(confidence=confidence)))
        self.assertFalse(ocr.readable_text(dict(confidence=1, recognitionLevel='unknown')))


if __name__ == '__main__':
    unittest.main()
