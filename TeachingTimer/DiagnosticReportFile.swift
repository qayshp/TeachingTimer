// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CryptoKit
import Foundation

/// Immutable share files only. This utility never opens or changes a journal.
/// Call off the main actor. A native sharing sheet has no delivery/completion
/// callback, so files survive view dismissal and are cleaned on a later prepare.
/// Preparation and cleanup are serialized even if a dismissed view's task
/// overlaps a new view. The recursive lock permits prepare's cleanup step.
enum DiagnosticReportFile {
    static let directoryName = "TeachingTimerDiagnosticReports"
    static let maximumBytes = 2 * 1024 * 1024
    static let maximumFiles = 8 // At most 16 MiB of prepared report content.
    static let retention: TimeInterval = 24 * 60 * 60
    private static let prefix = "TeachingTimer-report-"
    private static let lock = NSRecursiveLock()

    struct Prepared: Sendable {
        let url: URL
        let byteCount: Int
        let sha256: String
        let createdAt: Date
    }

    enum Failure: Error, Equatable {
        case emptyReport
        case tooLarge
        case invalidDate
        case invalidCacheDirectory
        case filenameCollision
        case cacheFull
    }

    /// The optional override is a cache ROOT for isolated tests; the utility
    /// still works only in its own child directory. Protect any file that may
    /// still be in an active sharing interaction when preparing another report.
    static func prepare(data: Data, cachesDirectory: URL? = nil, now: Date = Date(),
                        preserving: Set<URL> = [], identifier: () -> UUID = UUID.init) throws -> Prepared {
        lock.lock()
        defer { lock.unlock() }
        guard !data.isEmpty else { throw Failure.emptyReport }
        guard data.count <= maximumBytes else { throw Failure.tooLarge }
        let epoch = try creationEpoch(now)
        let directory = try cacheDirectory(root: cachesDirectory, create: true)!
        try purgeExpired(cachesDirectory: cachesDirectory, now: now, preserving: preserving)
        // Do not evict fresh files: the system may still be sharing them.
        let existing = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        var ownedCount = 0
        for url in existing where ownedEpoch(url.lastPathComponent) != nil {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isRegularFile == true, values.isSymbolicLink != true { ownedCount += 1 }
        }
        guard ownedCount < maximumFiles else { throw Failure.cacheFull }
        for _ in 0..<3 {
            let name = "\(prefix)\(epoch)-\(identifier().uuidString.lowercased()).json"
            let url = directory.appendingPathComponent(name, isDirectory: false)
            do {
                // Reserve without replacing a file from another preparation.
                // The final atomic write only replaces this call's reservation.
                try Data().write(to: url, options: .withoutOverwriting)
            } catch CocoaError.fileWriteFileExists {
                continue
            }
            do {
                try data.write(to: url, options: .atomic)
                return Prepared(url: url, byteCount: data.count,
                                sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                                createdAt: now)
            } catch {
                try? FileManager.default.removeItem(at: url)
                throw error
            }
        }
        throw Failure.filenameCollision
    }

    /// Remove only correctly named, expired regular files in the owned cache.
    /// No file timestamp API, subdirectory traversal, or symlink following.
    /// Future-dated names survive a backward clock correction until they age.
    @discardableResult
    static func purgeExpired(cachesDirectory: URL? = nil, now: Date = Date(),
                             preserving: Set<URL> = []) throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        _ = try creationEpoch(now)
        guard let directory = try cacheDirectory(root: cachesDirectory, create: false) else { return 0 }
        let protected = Set(preserving.map(\.standardizedFileURL))
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        var removed = 0
        for url in files {
            guard !protected.contains(url.standardizedFileURL),
                  let epoch = ownedEpoch(url.lastPathComponent),
                  now.timeIntervalSince1970 - Double(epoch) > retention else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            try FileManager.default.removeItem(at: url)
            removed += 1
        }
        return removed
    }

    private static func creationEpoch(_ date: Date) throws -> Int64 {
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite, (0...253_402_300_799).contains(seconds) else { throw Failure.invalidDate }
        return Int64(seconds.rounded(.down))
    }

    private static func ownedEpoch(_ name: String) -> Int64? {
        guard name.hasPrefix(prefix), name.hasSuffix(".json") else { return nil }
        let value = name.dropFirst(prefix.count).dropLast(5)
        let parts = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let epoch = Int64(parts[0]), epoch >= 0,
              String(epoch) == parts[0], let id = UUID(uuidString: String(parts[1])),
              id.uuidString.lowercased() == parts[1] else { return nil }
        return epoch
    }

    private static func cacheDirectory(root: URL?, create: Bool) throws -> URL? {
        let manager = FileManager.default
        let base = try root ?? manager.url(for: .cachesDirectory, in: .userDomainMask,
                                           appropriateFor: nil, create: create)
        guard base.isFileURL else { throw Failure.invalidCacheDirectory }
        var directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if !manager.fileExists(atPath: directory.path) {
            guard create else { return nil }
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw Failure.invalidCacheDirectory
        }
        if create {
            var exclusion = URLResourceValues()
            exclusion.isExcludedFromBackup = true
            try directory.setResourceValues(exclusion)
        }
        return directory
    }
}
