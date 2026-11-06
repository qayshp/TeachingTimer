// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Pure, transport-independent export. No preferences, paths, network, or writes.
/// Call off the main actor with snapshots from the three known journal writers.
/// Timestamps intentionally remain exact diagnostic data, not anonymous data.
enum DiagnosticReport {
    static let maximumBytes = 2 * 1024 * 1024
    private static let maximumSourceBytes = 32 * 1024 * 1024

    enum Source: String, CaseIterable, Codable, Sendable {
        case runtime, interface, landmarks
    }

    enum Window: String, CaseIterable, Codable, Sendable {
        case lastTwoHours, lastDay, allRetained
        func start(before cutoff: Date) -> Date? {
            switch self {
            case .lastTwoHours: cutoff.addingTimeInterval(-7200)
            case .lastDay: cutoff.addingTimeInterval(-86400)
            case .allRetained: nil
            }
        }
    }

    enum SnapshotStatus: String, Codable, Sendable {
        case available, missing, unreadable, writeFailed
    }

    struct Snapshot: Sendable {
        let data: Data?
        let events: [Event]?
        let status: SnapshotStatus
        let pendingEventCount: Int
        let lastWriteFailed: Bool

        /// Valid pending events may coexist with missing/unreadable saved history.
        /// A successful snapshot is not a claim that buffered events reached disk.
        init(data: Data? = nil, status: SnapshotStatus, pendingEventCount: Int = 0,
             lastWriteFailed: Bool = false) {
            self.data = data
            events = nil
            self.status = status
            self.pendingEventCount = pendingEventCount
            self.lastWriteFailed = lastWriteFailed
        }

        /// The live app uses exact immutable events, avoiding a lossy date
        /// serialization round trip and a second complete JSON allocation.
        init(events: [Event], status: SnapshotStatus, pendingEventCount: Int = 0,
             lastWriteFailed: Bool = false) {
            data = nil
            self.events = events
            self.status = status
            self.pendingEventCount = pendingEventCount
            self.lastWriteFailed = lastWriteFailed
        }
    }

    struct Metadata: Codable, Equatable, Sendable {
        let version: String
        let build: String
        let revision: String
        /// Numeric OS version, such as 27.2. Do not pass a device name.
        let osVersion: String
    }

    struct Event: Codable, Equatable, Sendable {
        let timestamp: Date
        let event: String
        let details: [String: String]
    }

    enum Status: String, Codable, Sendable {
        case available, missing, unreadable, writeFailed, malformed, oversized
    }

    struct Journal: Codable, Sendable {
        let source: Source
        let status: Status
        let pendingEventCount: Int
        let lastWriteFailed: Bool
        let availableEventCount: Int
        let excludedBeforeWindow: Int
        let excludedAfterCutoff: Int
        let omittedEvents: Int
        let omittedFields: Int
        let actualStart: Date?
        let actualEnd: Date?
        let events: [Event]
    }

    struct Report: Codable, Sendable {
        let schemaVersion: Int
        let generatedAt: Date
        let window: Window
        let requestedStart: Date?
        let metadata: Metadata
        let journals: [Journal]
        let eventCount: Int
        let actualStart: Date?
        let actualEnd: Date?
    }

    struct Prepared: Sendable {
        let data: Data
        let report: Report
    }

    enum Failure: Error, Equatable {
        case invalidCutoff
        case invalidMetadata
        case invalidSnapshot
        case tooLarge(bytes: Int, limit: Int)
    }

    /// Missing sources are reported as missing, never silently left out.
    /// Bounds are inclusive. A backward clock correction may leave future-dated
    /// entries on disk; count and exclude them rather than re-anchoring their dates.
    static func build(snapshots: [Source: Snapshot], metadata: Metadata,
                      window: Window = .lastTwoHours, cutoff: Date) throws -> Prepared {
        guard validDate(cutoff) else { throw Failure.invalidCutoff }
        guard numericVersion(metadata.version), numericVersion(metadata.build),
              numericVersion(metadata.osVersion), validRevision(metadata.revision)
        else { throw Failure.invalidMetadata }
        let start = window.start(before: cutoff)
        if let start, !validDate(start) { throw Failure.invalidCutoff }
        var identifiers = Identifiers()
        var journals: [Journal] = []
        for source in Source.allCases {
            let snapshot = snapshots[source] ?? Snapshot(status: .missing)
            guard (0...50_000).contains(snapshot.pendingEventCount) else { throw Failure.invalidSnapshot }
            var status = Status(rawValue: snapshot.status.rawValue)!
            var entries: [Event] = []
            if let current = snapshot.events {
                if current.count <= 50_000, current.allSatisfy({ validDate($0.timestamp) }) { entries = current }
                else { status = .malformed }
            } else if let bytes = snapshot.data {
                if bytes.count > maximumSourceBytes { status = .oversized }
                else if let decoded = try? decoder().decode([Event].self, from: bytes),
                        decoded.count <= 50_000, decoded.allSatisfy({ validDate($0.timestamp) }) {
                    entries = decoded
                } else { status = .malformed }
            } else if snapshot.status == .available { status = .unreadable }

            var before = 0, after = 0, omittedEvents = 0, omittedFields = 0
            var exported: [Event] = []
            for entry in entries {
                if entry.timestamp > cutoff { after += 1; continue }
                if let start, entry.timestamp < start { before += 1; continue }
                guard events.contains(entry.event) else { omittedEvents += 1; continue }
                var details: [String: String] = [:]
                // Sorting gives stable identifier assignment even if dictionary
                // iteration order changes across processes or input serialization.
                for key in entry.details.keys.sorted() {
                    if let value = sanitize(entry.details[key]!, key: key, identifiers: &identifiers) {
                        details[key] = value
                    } else { omittedFields += 1 }
                }
                exported.append(Event(timestamp: entry.timestamp, event: entry.event, details: details))
            }
            journals.append(Journal(source: source, status: status,
                pendingEventCount: snapshot.pendingEventCount, lastWriteFailed: snapshot.lastWriteFailed,
                availableEventCount: entries.count, excludedBeforeWindow: before,
                excludedAfterCutoff: after, omittedEvents: omittedEvents, omittedFields: omittedFields,
                actualStart: exported.map(\.timestamp).min(), actualEnd: exported.map(\.timestamp).max(),
                events: exported))
        }
        let report = Report(schemaVersion: 1, generatedAt: cutoff, window: window,
            requestedStart: start, metadata: metadata, journals: journals,
            eventCount: journals.reduce(0) { $0 + $1.events.count },
            actualStart: journals.compactMap(\.actualStart).min(),
            actualEnd: journals.compactMap(\.actualEnd).max())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(dateString(date))
        }
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        guard data.count <= maximumBytes else { throw Failure.tooLarge(bytes: data.count, limit: maximumBytes) }
        return Prepared(data: data, report: report)
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseDate(string) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                    debugDescription: "Invalid diagnostic date"))
            }
            return date
        }
        return decoder
    }

    private static func validDate(_ value: Date) -> Bool {
        // Avoid nonfinite or unrepresentable ISO-8601 values without assuming
        // a correct wall clock. Dates from 0001 through 9999 are representable.
        (-62_135_596_800...253_402_300_799).contains(value.timeIntervalSince1970)
    }

    /// Preserve available subsecond precision without retaining formatter
    /// instances across concurrency domains. The whole-second prefix is UTC.
    private static func dateString(_ date: Date) -> String {
        let interval = date.timeIntervalSinceReferenceDate
        var whole = floor(interval)
        var nanoseconds = Int(((interval - whole) * 1_000_000_000).rounded())
        if nanoseconds == 1_000_000_000 { whole += 1; nanoseconds = 0 }
        let prefix = Date(timeIntervalSinceReferenceDate: whole).formatted(.iso8601)
        guard nanoseconds > 0 else { return prefix }
        let digits = String(nanoseconds)
        return String(prefix.dropLast()) + "." + String(repeating: "0", count: 9 - digits.count) + digits + "Z"
    }

    private static func parseDate(_ value: String) -> Date? {
        guard value.utf8.count <= 40 else { return nil }
        let wholeSeconds = Date.ISO8601FormatStyle()
        let fractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        guard let date = (try? wholeSeconds.parse(value)) ?? (try? fractionalSeconds.parse(value)),
              validDate(date) else { return nil }
        return date
    }

    private static func matches(_ value: String, _ expression: String, maximum: Int = 64) -> Bool {
        value.utf8.count <= maximum && value.range(of: expression, options: .regularExpression) != nil
    }

    private static func numericVersion(_ value: String) -> Bool {
        matches(value, "^[0-9]+(?:\\.[0-9]+){0,3}$", maximum: 32)
    }

    private static func validRevision(_ value: String) -> Bool {
        value == "unknown" || matches(value, "^[0-9a-f]{7,40}(?:-dirty)?$")
    }

    private struct Identifiers {
        var values: [String: [UUID: String]] = [:]
        mutating func remap(_ value: String, category: String) -> String? {
            if value == "none" { return value }
            guard let uuid = UUID(uuidString: value) else { return nil }
            if let existing = values[category]?[uuid] { return existing }
            let next = "\(category)-\((values[category]?.count ?? 0) + 1)"
            values[category, default: [:]][uuid] = next
            return next
        }
    }

    /// Schema changes must opt in here. Known keys alone are insufficient:
    /// categorical values are enumerated and free text never passes through.
    private static func sanitize(_ value: String, key: String, identifiers: inout Identifiers) -> String? {
        if let category = identifierFields[key] { return identifiers.remap(value, category: category) }
        if booleanFields.contains(key) { return ["true", "false", "none"].contains(value) ? value : nil }
        if integerFields.contains(key), matches(value, "^-?[0-9]+$", maximum: 20),
           let integer = Int64(value), (-1_000_000_000...1_000_000_000).contains(integer) { return String(integer) }
        if numberFields.contains(key), matches(value, "^-?[0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$", maximum: 48),
           let number = Double(value), number.isFinite, abs(number) <= 1e12 { return String(number) }
        if dateFields.contains(key), let date = parseDate(value) { return dateString(date) }
        if key == "version" || key == "build" { return numericVersion(value) ? value : nil }
        if key == "revision" { return validRevision(value) ? value : nil }
        if key == "os" {
            // Preserve a known system-generated event OS/build across upgrades;
            // localized or otherwise unrecognized descriptions stay excluded.
            return matches(value, "^Version [0-9]+(?:\\.[0-9]+){0,3} \\(Build [0-9]{2}[A-Z][0-9]{1,6}[a-z]?\\)$") ? value : nil
        }
        if key == "phase" || key == "runtimePhase" {
            if phases.contains(value) { return value }
            // Swift's description of .failed embeds an arbitrary error message.
            return value.hasPrefix("failed(") && value.hasSuffix(")") ? "failed" : nil
        }
        if let allowed = categoricalFields[key], allowed.contains(value) { return value }
        return nil
    }

    private static let events: Set<String> = [
        "app_launched", "scene_state_changed", "interface_appeared", "interface_disappeared",
        "page_appeared", "page_disappeared", "page_selection_changed", "luminance_changed",
        "class_sheet_state_changed", "media_reload_requested", "start_requested",
        "start_deferred_until_invalidation", "start_rejected_inactive", "stop_requested",
        "automatic_restart_attempt", "automatic_restart_failed", "automatic_restart_succeeded",
        "runtime_intent_unavailable", "runtime_intent_restored", "deferred_explicit_start_ready",
        "early_handoff_requested", "early_handoff_deferred", "runtime_started", "runtime_will_expire",
        "runtime_invalidated", "renewal_decision", "runtime_restart_evaluated", "renewal_deferred_inactive",
        "volume_control_created", "volume_control_dismantled", "volume_focus_requested", "volume_focus_call",
        "volume_focus_call_skipped", "volume_focus_call_returned", "volume_refresh_completed",
        "volume_setup_focus_returned", "volume_refresh_requested", "volume_setup_scheduled",
        "volume_setup_cancelled", "volume_setup_requested", "landmark_started", "landmark_group_skipped",
        "landmark_pulse_late", "haptic_submitted", "landmark_ended", "journal_recovered",
        "persistence_loaded", "persistence_read_failed", "persistence_saved", "persistence_write_failed",
        "persistence_removed"
    ]
    private static let identifierFields = ["launchID": "launch", "runtimeID": "runtime", "replacesRuntimeID": "runtime",
        "runID": "count", "controlID": "control", "requestID": "request", "latestRequestID": "request"]
    private static let booleanFields: Set<String> = [
        "renewalPending", "stopRequested", "expirationWarningReceived", "earlyHandoffRequested", "automaticReplacement",
        "eligible", "luminanceReduced", "previousLuminanceReduced", "landmarksActive", "controlDismantled",
        "latestRequestedFocus", "requestedFocus", "supersededRequest", "controlReplaced", "hapticsEnabled",
        "lastViewTimerPageSelected", "lastViewClassSheetRequested", "lastViewClassRecoveryNotice",
        "lastViewLuminanceReduced", "backupReadBack", "previousBackupReplaced", "readBackMatches", "previousValuePreserved"
    ]
    private static let integerFields: Set<String> = [
        "appStateCode", "reasonCode", "errorCode", "underlyingErrorCode", "mediaViewGeneration",
        "previousMediaViewGeneration", "volumeRequestGeneration", "previousVolumeRequestGeneration",
        "setupAttemptID", "backgroundRevision", "groupsDelivered", "landmarkCount", "landmark", "pulse", "count",
        "hapticType", "byteCount", "classDurationMinutes"
    ]
    private static let numberFields: Set<String> = [
        "launchElapsedSeconds", "elapsedWallSeconds", "secondsRemaining", "settlingSeconds", "secondsSinceRequest",
        "landmarkProgress", "intervalSeconds", "pulseSpacing", "lateDiagnosticThresholdSeconds", "scheduledElapsed",
        "actualElapsed", "lateness", "windowEnd", "elapsedSeconds"
    ]
    private static let dateFields: Set<String> = [
        "intentClassID", "startedAt", "expirationDate", "builtAt", "classInitialStart", "classScheduledStart",
        "classScheduledEnd", "classRetirementDate", "classRetiredAt"
    ]
    private static let phases: Set<String> = ["idle", "starting", "running", "expiring", "expired", "interrupted", "stopped", "failed"]
    private static let states: Set<String> = ["active", "inactive", "background", "unknown"]
    private static let pages: Set<String> = ["classProgress", "nowPlaying"]
    private static let reasons: Set<String> = ["normal_end", "error", "expired", "resigned_frontmost", "suppressed_by_system",
        "session_already_in_progress", "unknown", "group_window_elapsed", "completed", "user_cancelled",
        "class_retired", "new_class", "new_class_reset", "eligibility_changed_or_view_removed"]
    private static let categoricalFields: [String: Set<String>] = [
        "appState": states, "sceneState": states, "previousSceneState": states, "scenePhase": states,
        "selectedPage": pages, "observedPage": pages, "previousPage": pages,
        "renewalPolicy": ["automatic", "userInitiated"], "savedRuntimeIntent": ["running", "stopped", "manualRecovery", "none"],
        "category": ["interface"], "origin": ["companion"], "call": ["focus", "resignFocus"],
        "actualFocus": ["unobserved"], "failureDetected": ["unobserved"], "audioRecovery": ["unobserved"],
        "completion": ["focus_call_returned"], "refreshMode": ["automatic"], "reason": reasons, "trigger": reasons,
        "source": ["runtime_button", "recovery_class_retired", "recovery_no_current_class", "class_retired",
            "new_class", "new_class_reset", "explicit_reset_or_retirement", "class_cleared", "interface_appearance", "page_entry",
            "background_return", "long_dimmed_wake", "refocus", "update", "dismantle", "timer_tap", "startup"],
        "cause": reasons.union(["inactive_before_start", "explicit_stop", "session_never_started", "early_handoff",
            "expiration_associated_error", "inactive_or_policy_or_outside_window"]),
        "kind": ["ack", "landmark"], "hapticName": ["start", "directionUp", "click", "stop"],
        "latePolicy": ["continue_spaced_skip_obsolete_groups"], "action": ["submit_and_continue"],
        "store": ["teachingClassContext.v1", "teachingRuntimeIntent.v1"],
        "state": ["absent", "restored", "unreadable", "unexpected_type"],
        "backupFormat": ["original_data", "property_list_value"],
        "errorType": ["DecodingError", "EncodingError", "CocoaError", "NSError"],
        "errorDomain": ["WKExtendedRuntimeSessionErrorDomain", "RBSAssertionErrorDomain", "NSCocoaErrorDomain", "NSPOSIXErrorDomain", "NSURLErrorDomain"],
        "underlyingErrorDomain": ["WKExtendedRuntimeSessionErrorDomain", "RBSAssertionErrorDomain", "NSCocoaErrorDomain", "NSPOSIXErrorDomain", "NSURLErrorDomain"]
    ]
}
