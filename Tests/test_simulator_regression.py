import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('regression', Path(__file__).resolve().parents[1] / 'tools/simulator-regression/run.py')
regression = importlib.util.module_from_spec(spec)
spec.loader.exec_module(regression)

class SimulatorRegressionChecks(unittest.TestCase):
    def test_only_running_native_view_service_is_selected(self):
        label = 'UIKitApplication:com.apple.NanoNowPlayingViewService[123]'
        self.assertEqual(regression.select_service(f'- 0 {label}\n12 0 unrelated\n42 0 {label}'), label)
    def test_missing_service_is_rejected(self):
        with self.assertRaises(ValueError):
            regression.select_service('42 0 com.qayshp.TeachingTimer')
    def test_ambiguous_service_is_rejected(self):
        with self.assertRaises(ValueError):
            regression.select_service('42 0 UIKitApplication:com.apple.NanoNowPlayingViewService[a]\n43 0 UIKitApplication:com.apple.NanoNowPlayingViewService[b]')
