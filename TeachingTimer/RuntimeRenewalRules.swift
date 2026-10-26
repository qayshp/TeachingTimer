// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Desired behavior survives process death; the WatchKit session itself does not.
/// Bound to the exact initial Start timestamp, not an editable scheduled time.
struct RuntimeIntent: Codable, Equatable {
    enum State: String, Codable { case running, stopped, manualRecovery }
    let classID: Date
    let state: State
}

@MainActor
final class RuntimeIntentStore {
    private let defaults: UserDefaults
    private let key = "teachingRuntimeIntent.v1"
    private(set) var value: RuntimeIntent?
    private var persistenceEvents: [PersistenceEvent] = []
    func takePersistenceEvents() -> [PersistenceEvent] {
        defer { persistenceEvents.removeAll() }; return persistenceEvents
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        value = PersistenceDiagnostics.load(RuntimeIntent.self, key: key, defaults: defaults, events: &persistenceEvents)
    }

    func save(_ intent: RuntimeIntent?) {
        guard intent != value else { return }
        value = intent
        if let intent {
            PersistenceDiagnostics.save(intent, key: key, defaults: defaults, events: &persistenceEvents)
        } else {
            defaults.removeObject(forKey: key)
            persistenceEvents.append(PersistenceEvent(name: "persistence_removed", details: ["store": key, "source": "class_cleared"]))
        }
    }
}

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
