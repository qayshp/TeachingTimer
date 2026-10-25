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

        // A foreground setup supersedes an unfinished manual request. An old
        // widget's callback cannot complete it, and automatic setup has no checkmark.
        assert(state.request() == 3)
        assert(state.request(source: .backgroundReturn) == 4)
        assert(!state.focusCallReturned(for: 3))
        assert(state.focusCallReturned(for: 4))
        assert(state.confirmedGeneration == nil && !state.isRefreshing)

        var activation = VolumeActivationState()
        assert(!activation.hasControl)
        assert(activation.begin(backgroundRevision: 0, isActive: false, timerIsSelected: true) == nil)
        assert(activation.begin(backgroundRevision: 0, isActive: true, timerIsSelected: false) == nil)
        let interrupted = activation.begin(backgroundRevision: 0, isActive: true, timerIsSelected: true)!
        assert(interrupted.source == .startup)
        assert(activation.cancel(interrupted))
        assert(!activation.complete(interrupted) && !activation.hasControl)
        let startup = activation.begin(backgroundRevision: 0, isActive: true, timerIsSelected: true)!
        assert(!activation.cancel(interrupted))
        assert(activation.complete(startup))
        assert(activation.hasControl && activation.isCurrent(backgroundRevision: 0))
        assert(!activation.complete(startup))

        // Wrist-down/wake, class-sheet dismissal, and media round trips keep
        // the same background revision. They must not replace a ready widget.
        for (active, selected) in [(false, true), (true, true), (true, false), (true, true)] {
            assert(activation.begin(backgroundRevision: 0, isActive: active, timerIsSelected: selected) == nil)
        }
        assert(!activation.isCurrent(backgroundRevision: 1))
        assert(activation.hasControl) // Existing display survives until replacement.
        assert(activation.begin(backgroundRevision: 1, isActive: false, timerIsSelected: true) == nil)
        assert(activation.begin(backgroundRevision: 1, isActive: true, timerIsSelected: false) == nil)
        let returning = activation.begin(backgroundRevision: 1, isActive: true, timerIsSelected: true)!
        assert(returning.source == .backgroundReturn)
        // Another background cycle while settling retires the older attempt.
        let latest = activation.begin(backgroundRevision: 2, isActive: true, timerIsSelected: true)!
        assert(!activation.complete(returning))
        assert(!activation.cancel(returning))
        assert(activation.complete(latest))
        assert(activation.isCurrent(backgroundRevision: 2))
        print("PASS: manual refresh, staged startup/background return, cancellation, stale callbacks, no wrist/page churn")
    }
}
