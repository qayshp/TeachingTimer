// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// Tracks widget replacement, never audio state or actual Crown focus.
struct VolumeRefreshState {
    enum Source: String { case timerTap = "timer_tap", startup, backgroundReturn = "background_return" }
    private(set) var generation = 0
    private(set) var isRefreshing = false
    private(set) var confirmedGeneration: Int?
    private(set) var source: Source?

    mutating func request(source: Source = .timerTap) -> Int? {
        // A foreground setup replaces any unfinished request on the old widget.
        // Repeated manual taps still cannot create concurrent replacements.
        guard !isRefreshing || source != .timerTap else { return nil }
        generation += 1
        isRefreshing = true
        confirmedGeneration = nil
        self.source = source
        return generation
    }

    mutating func focusCallReturned(for generation: Int) -> Bool {
        guard isRefreshing, generation == self.generation else { return false }
        isRefreshing = false
        confirmedGeneration = source == .timerTap ? generation : nil
        return true
    }

    mutating func dismissConfirmation(for generation: Int) {
        guard confirmedGeneration == generation else { return }
        confirmedGeneration = nil
    }
}

/// One staged setup per app launch / background epoch. A cancelled attempt
/// cannot finish a later attempt. Ordinary wrist wakes do not change the epoch.
struct VolumeActivationState {
    struct Attempt: Equatable {
        let id: Int
        let backgroundRevision: Int
        let source: VolumeRefreshState.Source
    }

    static let settlingSeconds = 1.0
    private(set) var completedBackgroundRevision: Int?
    private var nextAttemptID = 0
    private var pending: Attempt?

    var hasControl: Bool { completedBackgroundRevision != nil }

    func isCurrent(backgroundRevision: Int) -> Bool {
        completedBackgroundRevision == backgroundRevision
    }

    mutating func begin(backgroundRevision: Int, isActive: Bool, timerIsSelected: Bool) -> Attempt? {
        guard isActive, timerIsSelected, !isCurrent(backgroundRevision: backgroundRevision) else { return nil }
        nextAttemptID += 1
        let attempt = Attempt(id: nextAttemptID, backgroundRevision: backgroundRevision,
                              source: hasControl ? .backgroundReturn : .startup)
        pending = attempt
        return attempt
    }

    @discardableResult
    mutating func cancel(_ attempt: Attempt) -> Bool {
        guard pending == attempt else { return false }
        pending = nil
        return true
    }

    mutating func complete(_ attempt: Attempt) -> Bool {
        guard pending == attempt else { return false }
        completedBackgroundRevision = attempt.backgroundRevision
        pending = nil
        return true
    }
}
