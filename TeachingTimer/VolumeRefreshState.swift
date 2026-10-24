// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// Tracks explicit widget replacement, never audio state or actual Crown focus.
struct VolumeRefreshState {
    private(set) var generation = 0
    private(set) var isRefreshing = false
    private(set) var confirmedGeneration: Int?

    mutating func request() -> Int? {
        guard !isRefreshing else { return nil }
        generation += 1
        isRefreshing = true
        confirmedGeneration = nil
        return generation
    }

    mutating func focusCallReturned(for generation: Int) -> Bool {
        guard isRefreshing, generation == self.generation else { return false }
        isRefreshing = false
        confirmedGeneration = generation
        return true
    }

    mutating func dismissConfirmation(for generation: Int) {
        guard confirmedGeneration == generation else { return }
        confirmedGeneration = nil
    }
}
