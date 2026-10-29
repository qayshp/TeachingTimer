# SPDX-License-Identifier: MPL-2.0
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/simulator-regression'))
import relaunch


def event(name, state='running', launch='new'):
    return dict(event=name, details=dict(savedRuntimeIntent=state, launchID=launch))


class RelaunchEvidenceChecks(unittest.TestCase):
    def test_running_recovery_requires_start_from_same_new_launch(self):
        rows = [event('app_launched'), event('runtime_intent_restored'), event('runtime_started')]
        self.assertTrue(relaunch.running_recovery(rows))
        rows[-1] = event('runtime_started', launch='previous')
        self.assertFalse(relaunch.running_recovery(rows))
        self.assertFalse(relaunch.running_recovery([]))

    def test_stopped_recovery_cannot_pass_with_automatic_attempt(self):
        rows = [event('app_launched', 'stopped'), event('runtime_intent_restored', 'stopped')]
        self.assertTrue(relaunch.stopped_recovery(rows))
        for name in ['automatic_restart_attempt', 'start_requested', 'runtime_started']:
            self.assertFalse(relaunch.stopped_recovery(rows + [event(name)]))
        self.assertFalse(relaunch.stopped_recovery([]))
        self.assertFalse(relaunch.stopped_recovery([event('app_launched', 'stopped'), event('runtime_intent_restored', 'stopped', launch='previous')]))


class RelaunchAwakePreflightChecks(unittest.TestCase):
    def observation(self, name, elapsed, **details):
        return dict(event=name, details=dict(launchID='new', launchElapsedSeconds=str(elapsed), **details))

    def test_native_active_does_not_override_inactive_dimmed_scene(self):
        rows = [self.observation('app_launched', 0, appState='active'),
                self.observation('interface_appeared', .05, appState='active', scenePhase='inactive', luminanceReduced='true')]
        self.assertFalse(relaunch.awake_state(rows, [])['awake'])

    def test_interface_journal_wake_is_checked_in_monotonic_order(self):
        rows = [self.observation('app_launched', 0), self.observation('interface_appeared', .05, scenePhase='inactive', luminanceReduced='true')]
        interface = [self.observation('scene_state_changed', 3, sceneState='active', luminanceReduced='false'),
                     self.observation('scene_state_changed', 2, sceneState='inactive', luminanceReduced='true')]
        self.assertTrue(relaunch.awake_state(rows, interface)['awake'])

    def test_old_launch_or_missing_luminance_cannot_confirm_awake(self):
        rows = [self.observation('app_launched', 0), self.observation('interface_appeared', .05, scenePhase='active')]
        old = self.observation('scene_state_changed', 100, sceneState='active', luminanceReduced='false')
        old['details']['launchID'] = 'old'
        self.assertFalse(relaunch.awake_state(rows, [old])['awake'])
