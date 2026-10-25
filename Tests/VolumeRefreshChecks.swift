// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@main struct VolumeRefreshChecks {
    static func main() {
        var state = VolumeRefreshState()
        assert(!state.focusCallReturned(for: 0)) // Initial focus is not a refresh.
        assert(state.request() == 1)
        assert(state.request() == nil) // Rapid taps cannot overlap an in-flight request.
        assert(!state.focusCallReturned(for: 0)) // Earlier request callback is stale.
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
        // request's callback cannot complete it, and automatic setup has no checkmark.
        assert(state.request() == 3)
        assert(state.request(source: .backgroundReturn) == 4)
        assert(!state.focusCallReturned(for: 3))
        assert(state.focusCallReturned(for: 4))
        assert(state.confirmedGeneration == nil && !state.isRefreshing)

        var focus = VolumeFocusState()
        assert(focus.update(wantsFocus: false, generation: 1) == nil)
        assert(focus.update(wantsFocus: true, generation: 1)?.settlingSeconds == 0)
        for _ in 0..<120 { // Clock renders must not repeat native focus calls.
            assert(focus.update(wantsFocus: true, generation: 1) == nil)
        }
        assert(focus.update(wantsFocus: false, generation: 1)?.resignBeforeFocus == false)
        assert(focus.update(wantsFocus: true, generation: 1)?.settlingSeconds == 0)

        // Manual refresh cycles the retained widget once. If selection changes
        // before completion, the next page return remains immediate.
        let manual = focus.update(wantsFocus: true, generation: 2)!
        assert(manual.resignBeforeFocus && manual.settlingSeconds == 0.25)
        assert(focus.update(wantsFocus: true, generation: 2) == nil)
        assert(focus.update(wantsFocus: false, generation: 2)?.settlingSeconds == 0)
        assert(focus.update(wantsFocus: true, generation: 2)?.settlingSeconds == 0)

        // A new background setup also cycles focus; its ordinary inactive/active
        // and page transitions do not restart that cycle or add another delay.
        assert(focus.update(wantsFocus: false, generation: 2) != nil)
        let background = focus.update(wantsFocus: true, generation: 3)!
        assert(background.resignBeforeFocus && background.settlingSeconds == 0.25)
        assert(focus.update(wantsFocus: true, generation: 3) == nil)
        assert(focus.update(wantsFocus: false, generation: 3)?.settlingSeconds == 0)
        assert(focus.update(wantsFocus: true, generation: 3)?.settlingSeconds == 0)

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
        assert(activation.hasControl) // Existing widget survives the background return.
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
        print("PASS: retained-widget focus cycles, immediate media return, no per-frame calls, staged setup and cancellation")
    }
}
