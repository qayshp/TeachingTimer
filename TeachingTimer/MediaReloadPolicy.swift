// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// Bounded preventive refreshes, not a detector of native media-service failure.
/// Only explicit navigation and a real background return can trigger automation.
struct MediaReloadPolicy {
    enum Reason: String {
        case pageEntry = "page_entry"
        case backgroundReturn = "background_return"
        case manual = "class_options"
    }

    private var needsForegroundRefresh = false
    private var manualEntryAlreadyRefreshed = false

    mutating func didEnterBackground() {
        needsForegroundRefresh = true
    }

    mutating func didBecomeActive(mediaIsSelected: Bool) -> Reason? {
        guard needsForegroundRefresh else { return nil }
        needsForegroundRefresh = false
        return mediaIsSelected && !manualEntryAlreadyRefreshed ? .backgroundReturn : nil
    }

    mutating func didSelectMedia() -> Reason? {
        // A fresh page entry also satisfies any pending foreground refresh.
        needsForegroundRefresh = false
        if manualEntryAlreadyRefreshed {
            manualEntryAlreadyRefreshed = false
            return nil
        }
        return .pageEntry
    }

    mutating func manualReload(willSelectMedia: Bool) -> Reason {
        needsForegroundRefresh = false
        manualEntryAlreadyRefreshed = willSelectMedia
        return .manual
    }
}
