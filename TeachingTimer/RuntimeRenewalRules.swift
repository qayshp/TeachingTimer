// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Deliberately narrow experiment, not a general retry policy for OS errors.
enum RuntimeRenewalRules {
    static let expirationTolerance: TimeInterval = 2
    static let lateCallbackLimit: TimeInterval = 30
    static let earlyWindow: TimeInterval = 20

    static func canHandoff(warned: Bool, expiration: Date?, now: Date,
                           active: Bool, automatic: Bool, stopped: Bool) -> Bool {
        guard warned, active, automatic, !stopped, let expiration else { return false }
        let remaining = expiration.timeIntervalSince(now)
        return remaining > 0 && remaining <= earlyWindow
    }

    static func isExpirationError(warned: Bool, expiration: Date?, now: Date,
                                  domain: String?, code: Int?) -> Bool {
        guard warned, let expiration, domain == "RBSAssertionErrorDomain", code == 1 else { return false }
        let delta = now.timeIntervalSince(expiration)
        return delta >= -expirationTolerance && delta <= lateCallbackLimit
    }
}
