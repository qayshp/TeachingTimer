// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

struct PersistenceEvent {
    let name: String
    let details: [String: String]
}

/// Diagnostic metadata only goes into the journal. The latest unreadable value
/// per store stays locally in preferences, before an explicit action replaces it.
/// UserDefaults read-back is not a guarantee of a durable disk flush.
@MainActor
enum PersistenceDiagnostics {
    static func load<Value: Decodable>(_ valueType: Value.Type, key: String,
        defaults: UserDefaults, events: inout [PersistenceEvent]) -> Value? {
        guard let object = defaults.object(forKey: key) else {
            events.append(PersistenceEvent(name: "persistence_loaded", details: ["store": key, "state": "absent"]))
            return nil
        }
        do {
            guard let bytes = object as? Data else {
                throw CocoaError(.coderReadCorrupt)
            }
            let value = try JSONDecoder().decode(valueType, from: bytes)
            events.append(PersistenceEvent(name: "persistence_loaded", details: ["store": key, "state": "restored"]))
            return value
        } catch {
            let backupKey = key + ".unreadable.v1"
            // Exactly one bounded recovery value per store. Repeated reads of
            // identical bytes do not replace the original capture timestamp.
            let previous = defaults.dictionary(forKey: backupKey)
            let bytes: Data?
            let format: String
            if let data = object as? Data {
                bytes = data; format = "original_data"
            } else {
                bytes = try? PropertyListSerialization.data(fromPropertyList: ["value": object], format: .binary, options: 0)
                format = "property_list_value"
            }
            var preserved = false
            if let bytes {
                if previous?["bytes"] as? Data != bytes {
                    defaults.set(["bytes": bytes, "format": format, "capturedAt": Date()], forKey: backupKey)
                }
                preserved = defaults.dictionary(forKey: backupKey)?["bytes"] as? Data == bytes
            }
            events.append(PersistenceEvent(name: "persistence_read_failed", details: [
                "store": key, "state": object is Data ? "unreadable" : "unexpected_type",
                "errorType": String(describing: type(of: error)),
                "backupKey": backupKey, "backupFormat": format,
                "backupReadBack": String(preserved), "byteCount": String(bytes?.count ?? 0),
                "previousBackupReplaced": String(previous != nil && previous?["bytes"] as? Data != bytes)
            ]))
            // Never remove the original merely because decoding failed.
            return nil
        }
    }

    static func save<Value: Encodable>(_ value: Value, key: String,
        defaults: UserDefaults, events: inout [PersistenceEvent]) {
        do {
            let bytes = try JSONEncoder().encode(value)
            defaults.set(bytes, forKey: key)
            events.append(PersistenceEvent(name: "persistence_saved", details: [
                "store": key, "readBackMatches": String(defaults.data(forKey: key) == bytes)
            ]))
        } catch {
            // Encoding failure must not silently remove a previous value.
            events.append(PersistenceEvent(name: "persistence_write_failed", details: [
                "store": key, "errorType": String(describing: type(of: error)), "previousValuePreserved": "true"
            ]))
        }
    }
}
