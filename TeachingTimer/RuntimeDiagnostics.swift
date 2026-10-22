import Foundation

/// Runtime events use the same ordered, off-main writer as landmark events.
/// Record returns after queuing; a sudden process kill may lose the last events.
final class RuntimeDiagnostics: @unchecked Sendable {
    typealias Event = LandmarkDiagnostics.Event
    let fileURL: URL
    private let writer: LandmarkDiagnostics

    init(fileURL: URL = URL.documentsDirectory.appendingPathComponent("RuntimeDiagnostics.json"),
         capacity: Int = 1000) {
        self.fileURL = fileURL
        writer = LandmarkDiagnostics(url: fileURL, capacity: capacity, label: "RuntimeJournal")
    }

    func record(_ name: String, details: [String: String], at date: Date = Date()) {
        writer.record(name, details: details, at: date, flush: true)
    }

    func flush() async { await writer.flush() }
}
