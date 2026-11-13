# SPDX-License-Identifier: MPL-2.0
"""Guard template-image packaging and WidgetKit's small-image size budget.

PNG headers establish dimensions and an alpha channel, not readable pixels or
actual transparent cutouts. Those still require rendering/alpha inspection.
"""
import json
from pathlib import Path
import struct
import unittest


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'TeachingTimerComplications/Assets.xcassets'
GLYPHS = {'MatClockGlyph': 40, 'MatClockInlineGlyph': 16}
SCALES = {'1x': 1, '2x': 2, '3x': 3}


class ComplicationGlyphChecks(unittest.TestCase):
    def image_sets(self):
        for name, maximum_points in GLYPHS.items():
            folder = CATALOG / (name + '.imageset')
            yield name, folder, json.loads((folder / 'Contents.json').read_text()), maximum_points

    def png_header(self, path):
        self.assertEqual(path.suffix, '.png', 'Use bounded PNG renditions, not an oversized embedded PDF raster')
        header = path.read_bytes()[:33]
        self.assertEqual(header[:8], b'\x89PNG\r\n\x1a\n', 'Expected a real PNG resource')
        self.assertEqual(len(header), 33, 'PNG header is incomplete')
        self.assertEqual(struct.unpack('>I', header[8:12])[0], 13)
        self.assertEqual(header[12:16], b'IHDR')
        width, height, depth, color_type, _, _, _ = struct.unpack('>IIBBBBB', header[16:29])
        self.assertGreater(width, 0)
        self.assertGreater(height, 0)
        self.assertIn(depth, (8, 16), 'Alpha-channel PNG requires 8- or 16-bit samples')
        return width, height, color_type

    def test_glyphs_declare_template_rendering(self):
        for name, _, metadata, _ in self.image_sets():
            with self.subTest(glyph=name):
                self.assertEqual(metadata.get('properties', {}).get('template-rendering-intent'), 'template')

    def test_each_glyph_has_complete_scale_renditions(self):
        for name, folder, metadata, _ in self.image_sets():
            with self.subTest(glyph=name):
                images = metadata['images']
                self.assertEqual(len(images), len(SCALES))
                self.assertEqual({image.get('scale') for image in images}, set(SCALES))
                for image in images:
                    self.assertTrue((folder / image['filename']).is_file(), image['filename'])

    def test_png_renditions_have_alpha_channels(self):
        for name, folder, metadata, _ in self.image_sets():
            for image in metadata['images']:
                with self.subTest(glyph=name, scale=image['scale']):
                    _, _, color_type = self.png_header(folder / image['filename'])
                    self.assertIn(color_type, (4, 6), 'Template glyph needs a grayscale or RGB alpha channel')

    def test_natural_size_is_consistent_and_within_small_slot_budget(self):
        for name, folder, metadata, maximum_points in self.image_sets():
            images = {image['scale']: image for image in metadata['images']}
            base_width, base_height, _ = self.png_header(folder / images['1x']['filename'])
            with self.subTest(glyph=name):
                self.assertLessEqual(max(base_width, base_height), maximum_points,
                    'Large natural images can make WidgetKit reject complication archival')
            for scale, multiplier in SCALES.items():
                with self.subTest(glyph=name, scale=scale):
                    width, height, _ = self.png_header(folder / images[scale]['filename'])
                    self.assertEqual((width, height), (base_width * multiplier, base_height * multiplier),
                        'All renditions must describe the same natural point size')


if __name__ == '__main__':
    unittest.main()
