#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Run the real compiled CLI's offline request guards; no AX/device interaction."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    binary = Path(sys.argv[1]).resolve()
    result = subprocess.run([str(binary), '--self-test'], capture_output=True, text=True, timeout=5, check=True)
    row_test = json.loads(result.stdout)
    assert row_test['rowIdentitySelfTest'] == 'passed' and row_test['AXQueries'] == 0
    assert row_test['geometrySelfTest'] == 'passed' and row_test['geometryCases'] >= 13
    windows = binary.with_name('WindowList')
    result = subprocess.run([str(windows), '--self-test'], capture_output=True, text=True, timeout=5, check=True)
    window_test = json.loads(result.stdout)
    assert window_test['windowOwnerSelfTest'] == 'passed'
    assert window_test['CGWindowListQueries'] == 0 and window_test['AXQueries'] == 0
    assert window_test['inputSent'] is False
    # Reject before looking up any running process or querying window metadata.
    # Do not test a real positive/live Device Hub PID in this offline suite.
    for arguments in ([], ['0'], ['-1'], ['not-a-pid'], ['2147483648'], ['1', '--execute']):
        result = subprocess.run([str(windows), *arguments], capture_output=True, text=True, timeout=5)
        assert result.returncode == 2 and not result.stdout, result.stdout
    with tempfile.TemporaryDirectory() as temporary:
        folder = Path(temporary)
        details = folder / 'details.json'
        request = folder / 'request.json'
        identifier = '11111111-1111-4111-8111-111111111111'
        receipt = {'info': {'outcome': 'success'}, 'result': {
            'identifier': identifier, 'hardwareProperties': {'reality': 'physical', 'platform': 'watchOS'},
            'deviceProperties': {'name': 'Synthetic offline device'}}}
        base = {'hubPID': 1, 'deviceDetailsFile': str(details),
                'rowIdentifier': 'TableRow.Device.' + identifier, 'kind': 'watch', 'action': 'inspect'}
        details.write_text(json.dumps(receipt))
        def run(value, passed):
            request.write_text(json.dumps(value))
            # Deliberately no --execute on any path, even invalid requests.
            result = subprocess.run([str(binary), str(request)], capture_output=True, text=True, timeout=5)
            if passed:
                assert result.returncode == 0, result.stderr
                data = json.loads(result.stdout)
                assert data['status'] == 'plan_only' and data['AXQueries'] == 0
                assert data['deviceContact'] is False and data['inputSent'] is False
            else:
                assert result.returncode == 2 and not result.stdout, result.stdout
        run(base, True)
        tap = {**base, 'action': 'tap', 'displayPath': [0, 1], 'displayRole': 'AXGroup',
               'displayIdentifier': '', 'coordinates': [.5, .4]}
        run(tap, True)
        run({**tap, 'action': 'swipe', 'coordinates': [.8, .5, .2, .5]}, True)
        run({**tap, 'action': 'crown', 'scrollUnits': 1}, True)
        crop = {**tap, 'displayCrop': [.1, .1, .4, .67],
                'reviewedAnchorFrame': [100, 200, 800, 600], 'reviewedAtUnix': 900}
        run(crop, True)
        run({**crop, 'action': 'crown', 'scrollUnits': -1, 'crownPoint': [.8, .3]}, True)
        for changed in [dict(action='unlock'), dict(kind='simulator'), dict(hubPID=0),
                        dict(rowIdentifier='TableRow.Device.other'), dict(action='tap'),
                        dict(action='crown', scrollUnits=0), dict(action='crown', scrollUnits=4)]:
            run({**base, **changed}, False)
        for changed in [dict(coordinates=[1.1, .5]), dict(coordinates=[.5]),
                        dict(coordinates=[float('nan'), .5]), dict(displayPath=[-1]),
                        dict(displayRole='AXButton'), dict(displayIdentifier=None)]:
            run({**tap, **changed}, False)
        for changed in [dict(displayCrop=[-.1, .1, .4, .67]), dict(displayCrop=[.8, .1, .4, .67]),
                        dict(displayCrop=[.1, .1, 0, .67]), dict(displayCrop=[.1, .1, .4, -.1]),
                        dict(displayCrop=[.1, .1, float('inf'), .67]), dict(displayCrop=[.1, .1, .4]),
                        dict(reviewedAnchorFrame=None), dict(reviewedAnchorFrame=[100, 200, 800]),
                        dict(reviewedAnchorFrame=[100, 200, float('nan'), 600]),
                        dict(reviewedAtUnix=None), dict(reviewedAtUnix=float('nan')),
                        dict(crownPoint=[.8, .3])]:
            run({**crop, **changed}, False)
        run({**tap, 'action': 'crown', 'scrollUnits': 1, 'crownPoint': [.8, .3]}, False)
        run({**crop, 'action': 'crown', 'scrollUnits': 1, 'crownPoint': [1.1, .3]}, False)
        run({**crop, 'action': 'crown', 'scrollUnits': 1, 'crownPoint': [.8]}, False)
        for changed in [dict(reality='simulated'), dict(platform='iOS')]:
            invalid = copy.deepcopy(receipt)
            invalid['result']['hardwareProperties'].update(changed)
            details.write_text(json.dumps(invalid)); run(base, False)
        failed = copy.deepcopy(receipt)
        failed['info']['outcome'] = 'failure'
        details.write_text(json.dumps(failed)); run(base, False)

        phone = copy.deepcopy(receipt)
        phone['result']['identifier'] = '22222222-2222-4222-8222-222222222222'
        phone['result']['hardwareProperties']['platform'] = 'iOS'
        inventory = {'info': {'outcome': 'success'},
                     'result': {'devices': [phone['result'], copy.deepcopy(receipt['result'])]}}
        details.write_text(json.dumps(inventory)); run(base, True)
        alias = '33333333-3333-4333-8333-333333333333'
        inventory['result']['devices'][1]['hardwareProperties']['udid'] = alias
        details.write_text(json.dumps(inventory))
        run({**base, 'rowIdentifier': 'TableRow.Device.' + alias}, True)
        run({**base, 'kind': 'phone'}, False)
        for devices in ([], [phone['result']], [receipt['result'], receipt['result']]):
            invalid = {'info': {'outcome': 'success'}, 'result': {'devices': devices}}
            details.write_text(json.dumps(invalid)); run(base, False)
        for changed in [dict(reality='simulated'), dict(platform='iOS')]:
            invalid = copy.deepcopy(inventory)
            invalid['result']['devices'][1]['hardwareProperties'].update(changed)
            details.write_text(json.dumps(invalid)); run(base, False)
        failed = copy.deepcopy(inventory)
        failed['info']['outcome'] = 'failure'
        details.write_text(json.dumps(failed)); run(base, False)

        phone['result']['identifier'] = identifier
        details.write_text(json.dumps(phone)); run({**base, 'kind': 'phone'}, True)
        run({**tap, 'kind': 'phone', 'action': 'crown', 'scrollUnits': 1}, False)
    print('Physical Hub/window offline guards passed; zero CG/AX queries, selections or input')


if __name__ == '__main__':
    main()
