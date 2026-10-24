// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@main struct VolumeRefreshChecks {
    static func main() {
        var state = VolumeRefreshState()
        assert(!state.focusCallReturned(for: 0)) // Initial focus is not a refresh.
        assert(state.request() == 1)
        assert(state.request() == nil) // Rapid taps cannot replace an in-flight widget.
        assert(!state.focusCallReturned(for: 0)) // Removed widget callback is stale.
        assert(state.isRefreshing && state.confirmedGeneration == nil)
        assert(state.focusCallReturned(for: 1))
        assert(!state.isRefreshing && state.confirmedGeneration == 1)
        assert(!state.focusCallReturned(for: 1)) // Page return is not another completion.
        assert(state.request() == 2)
        assert(state.confirmedGeneration == nil)
        assert(!state.focusCallReturned(for: 1))
        assert(state.focusCallReturned(for: 2))
        state.dismissConfirmation(for: 1) // Old feedback task must not clear new feedback.
        assert(state.confirmedGeneration == 2)
        state.dismissConfirmation(for: 2)
        assert(state.confirmedGeneration == nil && state.generation == 2)
        print("PASS: explicit volume replacement, duplicate taps, stale callbacks, independent confirmation lifetime")
    }
}
