import Foundation

@main
struct RuntimeDiagnosticsChecks {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("RuntimeDiagnostics.json")
        let journal = try RuntimeDiagnostics(fileURL: url, capacity: 3)
        try journal.record("start_requested", details: ["runtimeID": "test-session"])
        try journal.record("runtime_started", details: [:])
        try journal.record("runtime_invalidated", details: ["reason": "resigned_frontmost", "reasonCode": "2"])
        let reopened = try RuntimeDiagnostics(fileURL: url, capacity: 3)
        try reopened.record("app_launched", details: [:])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([RuntimeDiagnostics.Event].self, from: Data(contentsOf: url))
        assert(entries.map(\.event) == ["runtime_started", "runtime_invalidated", "app_launched"])
        assert(entries[1].details["reason"] == "resigned_frontmost")
        let bad = directory.appendingPathComponent("bad.json")
        try Data("unreadable".utf8).write(to: bad)
        do {
            _ = try RuntimeDiagnostics(fileURL: bad)
            assertionFailure("Corrupt history must not be silently discarded")
        } catch {}
        let preserved = try String(contentsOf: bad, encoding: .utf8)
        assert(preserved == "unreadable")
        print("PASS: durable events, relaunch/reopen, bounded retention, end reason and corrupt-file preservation")
    }
}
