# Source provenance

The host Crown transport uses protocol/connection details from Meta idb, pinned
to commit `feb60fd884e2bf22f9a8cf59111e0468e9039338` (resolved November 15, 2026).
The upstream MIT copyright and license are preserved in `LICENSE-idb.txt`.

- [Crown transport and phase tracking](https://github.com/meta/idb/blob/feb60fd884e2bf22f9a8cf59111e0468e9039338/FBSimulatorControl/HID/SimulatorCrownHIDTransport.swift)
- [Typed DTUHID wire models](https://github.com/meta/idb/blob/feb60fd884e2bf22f9a8cf59111e0468e9039338/FBSimulatorControl/HID/DTUHIDModels.swift)
- [CoreSimulator namespace and private XPC endpoint creation](https://github.com/meta/idb/blob/feb60fd884e2bf22f9a8cf59111e0468e9039338/FBSimulatorControl/XPC/SimulatorXPCConnection.swift)
- [Liveness barrier and drain](https://github.com/meta/idb/blob/feb60fd884e2bf22f9a8cf59111e0468e9039338/FBSimulatorControl/HID/SimulatorDTUHIDConnection.swift)
- [High-level Crown gesture](https://github.com/meta/idb/blob/feb60fd884e2bf22f9a8cf59111e0468e9039338/FBSimulatorControl/HID/SimulatorHIDEvent.swift#L141-L160)

The default `upstream` profile carries its first actual sample on began, later
actual samples on changed, and zero on ended. The explicit `zero-began` profile
is an experiment expressible by the low-level transport: began0, 50ms gap, every
actual sample on changed, ended0. It is not the upstream high-level default.
Both profiles retain the earlier experiment's 0.25s pacing parameter and one
second final drain; upstream's defaults were 0.15s and 80ms respectively.

The following original private source hashes document promotion from the
November 15 experiments. Raw journals, device IDs, paths, addresses and captures
are not embedded in this directory.

| Original source basename | SHA-256 before promotion |
| --- | --- |
| CrownHIDBridge.m (V1) | fd027ace66b6311302edfc59d5099c9ec247345d0db8a4bb0e4245bf510d813d |
| CrownHIDBridgeV2.m | cc37a3efc94540465c5190f49bf5de053f5a4d7db3c73fef0ddd5a6068602e7c |
| NativeBaselineHook.m | f67b697ec2c901c17212336e661661163cfe616454c2ec042c525983b2c1dc53 |
| run-calibration.py | 6af3b437c120568a5d5016436c73ba5bcaf483c140789280d82dccb6fe9b3dcc |
| run-native-state.py | 477d009f3bf091be9333288616b24e229a432fa72986046fda90dc36c1326f87 |
| analyze-calibration.py | c0c50fc0ea2467322657ceaf553f3a434abf086c98317af9213207c71d909213 |

The promoted source adds MPL notices, combines the two host profiles, and adds a
bounded fixture runner, offline result checking and build receipts. The native
hook's replacement, capability discovery, callback batch, scalar reads and
unsupported-completion behavior remain the validated experimental logic.
`build.json` records current source hashes and selected SDKs for each build.
