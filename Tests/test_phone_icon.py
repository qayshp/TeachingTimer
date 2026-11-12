# SPDX-License-Identifier: MPL-2.0
"""Prevent iPhone icon transparency from reaching App Store uploads."""
import json
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PhoneIconChecks(unittest.TestCase):
    def test_phone_icons_have_no_alpha_channel_or_transparency_chunk(self):
        folder = ROOT / 'PhoneSupport/Assets.xcassets/AppIcon.appiconset'
        for image in json.loads((folder / 'Contents.json').read_text())['images']:
            data = (folder / image['filename']).read_bytes()
            if data.startswith(b'\xff\xd8\xff'):
                continue  # JPEG has no alpha channel.
            self.assertTrue(data.startswith(b'\x89PNG\r\n\x1a\n'), 'Expected PNG or JPEG icon')
            self.assertIn(data[25], (0, 2), 'PNG must use opaque grayscale or RGB')
            offset = 8
            while offset < len(data):
                length = struct.unpack('>I', data[offset:offset + 4])[0]
                self.assertNotEqual(data[offset + 4:offset + 8], b'tRNS', 'Icon must not declare transparency')
                offset += length + 12
            self.assertEqual(offset, len(data))
