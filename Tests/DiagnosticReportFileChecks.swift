// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@main struct DiagnosticReportFileChecks {
    static func main() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? manager.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let bytes = Data("{\"fixture\":true}".utf8)
        let first = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: root, now: now)
        assert(first.byteCount == bytes.count)
        assert(first.sha256 == "ffbc2dfc402782325da71132100e74ff511d1585dd80e4ea196ed4bcace3fef2")
        assert(first.createdAt == now)
        assert(first.url.deletingLastPathComponent().lastPathComponent == DiagnosticReportFile.directoryName)
        let firstBytes = try Data(contentsOf: first.url)
        assert(firstBytes == bytes)
        let excluded = try first.url.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey])
        assert(excluded.isExcludedFromBackup == true)

        // Preparing another file must not rewrite the one handed to sharing.
        let next = try DiagnosticReportFile.prepare(data: Data("{\"second\":true}".utf8),
                                                    cachesDirectory: root, now: now, preserving: [first.url])
        assert(first.url != next.url)
        let stillOriginal = try Data(contentsOf: first.url)
        assert(stillOriginal == bytes)

        // Exact names can collide in a test; a reservation must never overwrite.
        let id = UUID()
        let collision = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: root, now: now,
                                                         identifier: { id })
        expect(DiagnosticReportFile.Failure.filenameCollision) {
            _ = try DiagnosticReportFile.prepare(data: Data("changed".utf8), cachesDirectory: root,
                                                  now: now, identifier: { id })
        }
        let collisionBytes = try Data(contentsOf: collision.url)
        assert(collisionBytes == bytes)

        // Retention is based on the name's captured time, not filesystem dates.
        let boundaryRemoved = try DiagnosticReportFile.purgeExpired(
            cachesDirectory: root, now: now.addingTimeInterval(DiagnosticReportFile.retention))
        assert(boundaryRemoved == 0) // Exactly 24 hours is not older than 24 hours.
        let later = now.addingTimeInterval(DiagnosticReportFile.retention + 1)
        let ownedDirectory = first.url.deletingLastPathComponent()
        let unrelated = ownedDirectory.appendingPathComponent("LandmarkDiagnostics.json")
        try bytes.write(to: unrelated)
        let malformed = ownedDirectory.appendingPathComponent("TeachingTimer-report-0-not-a-uuid.json")
        try bytes.write(to: malformed)
        let subdirectory = ownedDirectory.appendingPathComponent("TeachingTimer-report-0-\(UUID().uuidString.lowercased()).json")
        try manager.createDirectory(at: subdirectory, withIntermediateDirectories: false)
        let nested = subdirectory.appendingPathComponent("keep.json")
        try bytes.write(to: nested)
        let link = ownedDirectory.appendingPathComponent("TeachingTimer-report-0-\(UUID().uuidString.lowercased()).json")
        try manager.createSymbolicLink(at: link, withDestinationURL: unrelated)
        let removed = try DiagnosticReportFile.purgeExpired(cachesDirectory: root, now: later,
                                                            preserving: [first.url])
        assert(removed == 2)
        assert(manager.fileExists(atPath: first.url.path))
        assert(!manager.fileExists(atPath: next.url.path))
        assert(!manager.fileExists(atPath: collision.url.path))
        assert(manager.fileExists(atPath: unrelated.path))
        assert(manager.fileExists(atPath: malformed.path))
        assert(manager.fileExists(atPath: nested.path))
        assert(tryLinkExists(link))
        let future = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: root, now: later)
        assert(!manager.fileExists(atPath: first.url.path)) // No longer protected.
        let futureRemoved = try DiagnosticReportFile.purgeExpired(cachesDirectory: root, now: now)
        assert(futureRemoved == 0 && manager.fileExists(atPath: future.url.path))

        expect(DiagnosticReportFile.Failure.emptyReport) {
            _ = try DiagnosticReportFile.prepare(data: Data(), cachesDirectory: root)
        }
        let maximum = try DiagnosticReportFile.prepare(
            data: Data(repeating: 0, count: DiagnosticReportFile.maximumBytes), cachesDirectory: root)
        assert(maximum.byteCount == DiagnosticReportFile.maximumBytes)
        expect(DiagnosticReportFile.Failure.tooLarge) {
            _ = try DiagnosticReportFile.prepare(data: Data(repeating: 0, count: DiagnosticReportFile.maximumBytes + 1),
                                                  cachesDirectory: root)
        }
        expect(DiagnosticReportFile.Failure.invalidDate) {
            _ = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: root, now: Date(timeIntervalSince1970: .infinity))
        }
        // A file obstructing the cache root fails without deleting or rewriting it.
        let blocked = root.appendingPathComponent("blocked")
        try bytes.write(to: blocked)
        do {
            _ = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: blocked)
            assertionFailure("Expected write failure")
        } catch { }
        let blockedAfter = try Data(contentsOf: blocked)
        assert(blockedAfter == bytes)

        // The owned directory itself may never be a link to another directory.
        let linkedRoot = root.appendingPathComponent("linked", isDirectory: true)
        try manager.createDirectory(at: linkedRoot, withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        try manager.createDirectory(at: outside, withIntermediateDirectories: true)
        try manager.createSymbolicLink(at: linkedRoot.appendingPathComponent(DiagnosticReportFile.directoryName),
                                      withDestinationURL: outside)
        expect(DiagnosticReportFile.Failure.invalidCacheDirectory) {
            _ = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: linkedRoot)
        }
        let outsideContents = try manager.contentsOfDirectory(atPath: outside.path)
        assert(outsideContents.isEmpty)

        // Fresh preparations have a total bound without evicting shared files.
        let capacityRoot = root.appendingPathComponent("capacity", isDirectory: true)
        var saved: [DiagnosticReportFile.Prepared] = []
        for _ in 0..<DiagnosticReportFile.maximumFiles {
            saved.append(try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: capacityRoot, now: now))
        }
        assert(saved.count == 8)
        expect(DiagnosticReportFile.Failure.cacheFull) {
            _ = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: capacityRoot, now: now)
        }
        for prepared in saved {
            let unchanged = try Data(contentsOf: prepared.url)
            assert(unchanged == bytes)
        }
        let active = saved[0]
        let capacityDirectory = active.url.deletingLastPathComponent()
        let spare = capacityDirectory.appendingPathComponent("unrelated.json")
        try bytes.write(to: spare)
        let extraFolder = capacityDirectory.appendingPathComponent("TeachingTimer-report-0-\(UUID().uuidString.lowercased()).json")
        try manager.createDirectory(at: extraFolder, withIntermediateDirectories: false)
        let extraLink = capacityDirectory.appendingPathComponent("TeachingTimer-report-0-\(UUID().uuidString.lowercased()).json")
        try manager.createSymbolicLink(at: extraLink, withDestinationURL: spare)
        let renewed = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: capacityRoot,
                                                       now: later, preserving: [active.url])
        let activeBytes = try Data(contentsOf: active.url)
        assert(activeBytes == bytes && renewed.url != active.url)
        assert(saved.dropFirst().allSatisfy { !manager.fileExists(atPath: $0.url.path) })
        // Only the active report and renewed report count; unrelated entries do not.
        for _ in 0..<(DiagnosticReportFile.maximumFiles - 2) {
            _ = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: capacityRoot,
                                                  now: later, preserving: [active.url])
        }
        expect(DiagnosticReportFile.Failure.cacheFull) {
            _ = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: capacityRoot,
                                                  now: later, preserving: [active.url])
        }
        assert(manager.fileExists(atPath: spare.path) && manager.fileExists(atPath: extraFolder.path))
        assert(tryLinkExists(extraLink))

        // A canceled view's detached preparation can overlap a new view. The
        // utility must enforce capacity internally, not rely on UI serialization.
        let concurrentRoot = root.appendingPathComponent("concurrent", isDirectory: true)
        let concurrent = ConcurrentResults()
        DispatchQueue.concurrentPerform(iterations: 12) { _ in
            do {
                let prepared = try DiagnosticReportFile.prepare(data: bytes, cachesDirectory: concurrentRoot, now: now)
                concurrent.record(prepared: prepared)
            } catch {
                concurrent.record(error: error)
            }
        }
        let results = concurrent.snapshot()
        assert(results.prepared.count == 8 && Set(results.prepared.map(\.url)).count == 8)
        assert(results.full == 4 && results.unexpected == 0)
        for prepared in results.prepared {
            let untouched = try Data(contentsOf: prepared.url)
            assert(untouched == bytes)
        }
        print("Diagnostic share-file checks passed")
    }

    private static func tryLinkExists(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func expect(_ failure: DiagnosticReportFile.Failure, _ operation: () throws -> Void) {
        do { try operation(); assertionFailure("Expected \(failure)") }
        catch { assert((error as? DiagnosticReportFile.Failure) == failure, "Unexpected error: \(error)") }
    }
}

/// Test-only result aggregation; all mutable fields are protected by this lock.
private final class ConcurrentResults: @unchecked Sendable {
    private let lock = NSLock()
    private var prepared: [DiagnosticReportFile.Prepared] = []
    private var full = 0
    private var unexpected = 0

    func record(prepared value: DiagnosticReportFile.Prepared) {
        lock.lock()
        defer { lock.unlock() }
        prepared.append(value)
    }

    func record(error: Error) {
        lock.lock()
        defer { lock.unlock() }
        if (error as? DiagnosticReportFile.Failure) == .cacheFull { full += 1 }
        else { unexpected += 1 }
    }

    func snapshot() -> (prepared: [DiagnosticReportFile.Prepared], full: Int, unexpected: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (prepared, full, unexpected)
    }
}
