// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Bounded preventive refreshes, not a detector of native media-service failure.
/// Long dimmed intervals also refresh once on an eligible wake, never periodically.
struct MediaReloadPolicy {
    enum Reason: String {
        case longDimmedWake = "long_dimmed_wake"
        case pageEntry = "page_entry"
        case backgroundReturn = "background_return"
    }

    static let minimumDimmedSeconds: TimeInterval = 30
    static let wakeRefreshCooldownSeconds: TimeInterval = 60
    private var dimmedSince: TimeInterval?
    private var lastRefresh: TimeInterval?
    private var needsForegroundRefresh = false

    // Uptime is monotonic: clock corrections cannot trigger a false long sleep.
    // Retain the dim start until BOTH wake callbacks agree it is safe to refresh.
    mutating func displayChanged(isActive: Bool, isDimmed: Bool,
                                 mediaIsSelected: Bool,
                                 now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Reason? {
        if isDimmed {
            if dimmedSince == nil { dimmedSince = now }
            return nil
        }
        guard isActive else { return nil }
        guard let start = dimmedSince else { return nil }
        dimmedSince = nil // Consume even suppressed wakes; no later surprise reload.
        guard mediaIsSelected, now - start >= Self.minimumDimmedSeconds,
              lastRefresh.map({ now - $0 >= Self.wakeRefreshCooldownSeconds }) ?? true
        else { return nil }
        lastRefresh = now
        needsForegroundRefresh = false
        return .longDimmedWake
    }

    mutating func didEnterBackground() {
        needsForegroundRefresh = true
    }

    mutating func didBecomeActive(mediaIsSelected: Bool, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Reason? {
        guard needsForegroundRefresh else { return nil }
        needsForegroundRefresh = false
        if mediaIsSelected { dimmedSince = nil; lastRefresh = now }
        return mediaIsSelected ? .backgroundReturn : nil
    }

    mutating func didSelectMedia(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Reason? {
        // A fresh page entry also satisfies any pending foreground refresh.
        needsForegroundRefresh = false
        dimmedSince = nil
        lastRefresh = now
        return .pageEntry
    }
}
