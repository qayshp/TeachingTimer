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
        for changed in [dict(action='unlock'), dict(kind='simulator'), dict(hubPID=0),
                        dict(rowIdentifier='TableRow.Device.other'), dict(action='tap'),
                        dict(action='crown', scrollUnits=0), dict(action='crown', scrollUnits=4)]:
            run({**base, **changed}, False)
        for changed in [dict(coordinates=[1.1, .5]), dict(coordinates=[.5]),
                        dict(displayPath=[-1]), dict(displayRole='AXButton'), dict(displayIdentifier=None)]:
            run({**tap, **changed}, False)
        for changed in [dict(reality='simulated'), dict(platform='iOS')]:
            invalid = copy.deepcopy(receipt)
            invalid['result']['hardwareProperties'].update(changed)
            details.write_text(json.dumps(invalid)); run(base, False)
        phone = copy.deepcopy(receipt)
        phone['result']['hardwareProperties']['platform'] = 'iOS'
        details.write_text(json.dumps(phone)); run({**base, 'kind': 'phone'}, True)
        run({**tap, 'kind': 'phone', 'action': 'crown', 'scrollUnits': 1}, False)
    print('Physical Hub offline guards passed; zero AX queries, selections or input')


if __name__ == '__main__':
    main()
