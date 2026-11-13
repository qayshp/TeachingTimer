# SPDX-License-Identifier: MPL-2.0
import sys
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/simulator-regression'))
from media_evidence import (DELAYED_MEDIA_CAPTURES, PIXEL_REGION, collect_media_pixels,
                            media_sequence_errors, observation, pixel_errors)


def metrics(visible=.04):
    return dict(width=324, height=394, region=PIXEL_REGION, visibleFraction=visible,
                brightFraction=min(.02, visible), meanChannelMaximum=.01, peakChannel=1.0)


class MediaEvidenceTests(unittest.TestCase):
    def test_text_is_positive_evidence_not_audio_success(self):
        self.assertEqual(observation([dict(text='Not Playing', confidence=.99, x=.5, y=.4)],
                                     metrics()), 'NOT_PLAYING_TEXT_PRESENT')

    def test_fast_text_cannot_certify_media_without_corroboration(self):
        row = dict(text='Not Playing', confidence=.5, x=.5, y=.4,
                   recognitionLevel='fast', corroborated=True)
        self.assertEqual(observation([row], metrics()), 'NOT_PLAYING_TEXT_PRESENT')
        self.assertEqual(observation([dict(row, corroborated=False)], metrics()), 'CONTENT_PRESENT_REVIEW_REQUIRED')

    def test_system_text_cannot_certify_content(self):
        self.assertEqual(observation([dict(text='Not Playing', confidence=.99, x=.5, y=.1)],
                                     metrics(0)), 'NEAR_BLACK_CONTENT_REVIEW_REQUIRED')

    def test_ocr_absence_is_not_blank(self):
        self.assertEqual(observation([], metrics(.1)), 'CONTENT_PRESENT_REVIEW_REQUIRED')

    def test_black_is_visual_review_flag_not_cause_or_audio_claim(self):
        self.assertEqual(observation([], metrics(0)), 'NEAR_BLACK_CONTENT_REVIEW_REQUIRED')

    def test_ocr_cannot_override_near_black_or_invalid_metrics(self):
        rows = [dict(text='Not Playing', confidence=.99, x=.5, y=.4)]
        self.assertEqual(observation(rows, metrics(0)), 'NEAR_BLACK_CONTENT_REVIEW_REQUIRED')
        self.assertEqual(observation(rows, {}), 'PIXEL_EVIDENCE_INVALID_REVIEW_REQUIRED')

    def test_missing_malformed_nonfinite_and_inconsistent_metrics_fail_closed(self):
        for key in metrics():
            missing = metrics()
            del missing[key]
            self.assertTrue(pixel_errors(missing), key)
        for key in ('visibleFraction', 'brightFraction', 'meanChannelMaximum', 'peakChannel'):
            for invalid in (None, True, '0.1', [], float('nan'), float('inf'), -float('inf'), -.1, 1.1, 10 ** 1000):
                self.assertTrue(pixel_errors(metrics() | {key: invalid}), (key, invalid))
        for key in ('width', 'height'):
            for invalid in (None, True, 0, -1, 324.0, '324'):
                self.assertTrue(pixel_errors(metrics() | {key: invalid}))
        self.assertTrue(pixel_errors(metrics() | {'region': 'full screen'}))
        self.assertTrue(pixel_errors(metrics() | {'brightFraction': .5}))
        self.assertTrue(pixel_errors(metrics() | {'meanChannelMaximum': 1, 'peakChannel': .5}))
        for invalid in (None, [], 'pixels'):
            self.assertTrue(pixel_errors(invalid))

    def test_exact_visible_threshold_is_inclusive(self):
        self.assertEqual(observation([], metrics(.001)), 'CONTENT_PRESENT_REVIEW_REQUIRED')
        self.assertEqual(observation([], metrics(.000999)), 'NEAR_BLACK_CONTENT_REVIEW_REQUIRED')


class MediaSequenceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.folder = Path(temporary.name)
        for name in DELAYED_MEDIA_CAPTURES:
            (self.folder / name).write_bytes(('original fixture ' + name).encode())

    def test_all_three_delayed_originals_pass_narrow_gate_with_no_ocr(self):
        records = collect_media_pixels(self.folder, lambda _: metrics())
        self.assertEqual(media_sequence_errors(records, self.folder), [])
        self.assertEqual([record['file'] for record in records], list(DELAYED_MEDIA_CAPTURES))
        self.assertTrue(all(record['observation'] == 'CONTENT_PRESENT_REVIEW_REQUIRED' for record in records))

    def test_blank_delayed_return_is_flagged_despite_two_visible_frames(self):
        records = collect_media_pixels(self.folder, lambda image: metrics(0 if image.name == DELAYED_MEDIA_CAPTURES[1] else .04))
        errors = media_sequence_errors(records, self.folder)
        self.assertEqual(len(errors), 1)
        self.assertIn(DELAYED_MEDIA_CAPTURES[1] + ': near-black', errors[0])
        self.assertIn('visual review required', errors[0])

    def test_missing_partial_duplicate_or_immediate_capture_cannot_pass(self):
        records = collect_media_pixels(self.folder, lambda _: metrics())
        for invalid in (None, {}, records[:2], records + [records[0]], [records[0], records[0], records[2]],
                        [records[0], records[1] | {'file': '04-media-return.png'}, records[2]]):
            self.assertTrue(media_sequence_errors(invalid, self.folder))
        (self.folder / DELAYED_MEDIA_CAPTURES[1]).unlink()
        self.assertTrue(media_sequence_errors(records, self.folder))
        missing = collect_media_pixels(self.folder, lambda _: metrics())
        self.assertEqual(len(missing), 3)
        self.assertIn('error', missing[1])

    def test_changed_or_empty_original_does_not_pass_with_old_metrics(self):
        records = collect_media_pixels(self.folder, lambda _: metrics())
        path = self.folder / DELAYED_MEDIA_CAPTURES[1]
        path.write_bytes(b'changed')
        self.assertTrue(media_sequence_errors(records, self.folder))
        path.write_bytes(b'')
        records[1]['sha256'] = hashlib.sha256(b'').hexdigest()
        self.assertTrue(media_sequence_errors(records, self.folder))

    def test_helper_error_invalid_json_and_nonfinite_metrics_remain_serializable(self):
        def fail(_):
            raise RuntimeError('helper decode failed')
        def invalid_json(_):
            return json.loads('not json')
        for measure in (fail, invalid_json, lambda _: metrics(float('nan')), lambda _: {}):
            records = collect_media_pixels(self.folder, measure)
            self.assertEqual(len(records), 3)
            json.dumps(records, allow_nan=False)
            self.assertTrue(media_sequence_errors(records, self.folder))


if __name__ == '__main__':
    unittest.main()
