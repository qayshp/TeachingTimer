# SPDX-License-Identifier: MPL-2.0
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/simulator-regression'))
from media_evidence import observation


class MediaEvidenceTests(unittest.TestCase):
    def test_text_is_positive_evidence_not_audio_success(self):
        self.assertEqual(observation([dict(text='Not Playing', confidence=.99, x=.5, y=.4)],
                                     dict(visibleFraction=.04)), 'NOT_PLAYING_TEXT_PRESENT')

    def test_system_text_cannot_certify_content(self):
        self.assertEqual(observation([dict(text='Not Playing', confidence=.99, x=.5, y=.1)],
                                     dict(visibleFraction=0)), 'NEAR_BLACK_CONTENT_REVIEW_REQUIRED')

    def test_ocr_absence_is_not_blank(self):
        self.assertEqual(observation([], dict(visibleFraction=.1)), 'CONTENT_PRESENT_REVIEW_REQUIRED')

    def test_black_is_review_flag_not_failure(self):
        self.assertEqual(observation([], dict(visibleFraction=0)), 'NEAR_BLACK_CONTENT_REVIEW_REQUIRED')


if __name__ == '__main__':
    unittest.main()
