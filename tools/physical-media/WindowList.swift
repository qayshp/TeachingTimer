// SPDX-License-Identifier: MPL-2.0
// Read-only Device Hub window metadata. No AX, activation, input or device API.
import AppKit
import CoreGraphics
import Foundation

func fail(_ message: String) -> Never { fputs(message + "\n", stderr); exit(2) }
func ownedWindows(_ windows: [[String: Any]], pid: Int32) -> [[String: Any]] {
    windows.filter {
        guard let owner = $0[kCGWindowOwnerPID as String] as? NSNumber,
              CFGetTypeID(owner) != CFBooleanGetTypeID() else { return false }
        return owner.int64Value == Int64(pid)
    }
}
func emit(_ value: [String: Any]) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data); print("")
}
do {
    let args = Array(CommandLine.arguments.dropFirst())
    if args == ["--self-test"] {
        let rows: [[String: Any]] = [
            [kCGWindowOwnerPID as String: 41, kCGWindowNumber as String: 10],
            [kCGWindowOwnerPID as String: 42, kCGWindowNumber as String: 11],
            [kCGWindowOwnerPID as String: 41, kCGWindowNumber as String: 12],
            [kCGWindowOwnerPID as String: "41", kCGWindowNumber as String: 13],
            [kCGWindowOwnerPID as String: true, kCGWindowNumber as String: 14],
            [kCGWindowNumber as String: 15]
        ]
        let selected = ownedWindows(rows, pid: 41)
        guard selected.compactMap({ $0[kCGWindowNumber as String] as? Int }) == [10, 12],
              ownedWindows(rows, pid: 99).isEmpty,
              ownedWindows(rows, pid: 1).isEmpty else { fail("Window owner filtering failed") }
        try emit(["windowOwnerSelfTest": "passed", "CGWindowListQueries": 0, "AXQueries": 0, "inputSent": false])
        exit(0)
    }
    guard args.count == 1, let pid = Int32(args[0]), pid > 0 else {
        fail("Usage: WindowList DEVICE_HUB_PID (positive explicit PID required)")
    }
    guard let app = NSRunningApplication(processIdentifier: pid),
          app.bundleIdentifier == "com.apple.dt.Devices" else {
        fail("PID is not a running Device Hub; no window query performed")
    }
    guard let rows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        fail("Window metadata unavailable; no window IDs inferred")
    }
    try emit(["hubPID": pid, "bundleIdentifier": "com.apple.dt.Devices",
              "windows": ownedWindows(rows, pid: pid), "CGWindowListQueries": 1,
              "AXQueries": 0, "inputSent": false, "deviceContact": false,
              "scope": "Current host window metadata only; manually review identity and visibility before a separate capture"])
} catch {
    fail("Window metadata error: \(error)")
}
