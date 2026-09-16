import Foundation

/// Small on-device journal. No network, media metadata, or per-tick writes.
@MainActor
final class RuntimeDiagnostics {
    struct Event: Codable {
        let timestamp: Date
        let event: String
        let details: [String: String]
    }
    let fileURL: URL
    private let capacity: Int
    private var events: [Event]

    init(fileURL: URL = URL.documentsDirectory.appendingPathComponent("RuntimeDiagnostics.json"),
         capacity: Int = 1000) throws {
        self.fileURL = fileURL
        self.capacity = max(1, capacity)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            // Never silently overwrite an unreadable existing diagnostic file.
            events = try decoder.decode([Event].self, from: Data(contentsOf: fileURL))
        } else {
            events = []
        }
    }

    func record(_ name: String, details: [String: String], at date: Date = Date()) throws {
        var next = Array(events.suffix(capacity - 1))
        next.append(Event(timestamp: date, event: name,
                          details: details.mapValues { String($0.prefix(1000)) }))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                               withIntermediateDirectories: true)
        try encoder.encode(next).write(to: fileURL, options: .atomic)
        events = next
    }
}
