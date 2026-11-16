// SPDX-License-Identifier: MPL-2.0
// Read-only Device Hub/iPhone Mirroring metadata. No AX, activation, input or device API.
import AppKit
import CoreGraphics
import Foundation

func fail(_ message: String) -> Never { fputs(message + "\n", stderr); exit(2) }
func target(_ args: [String]) -> (pid: Int32, bundle: String)? {
    let mirroring = args.count == 2 && args[0] == "--mirroring"
    guard args.count == 1 || mirroring, let last = args.last,
          let pid = Int32(last), pid > 0 else { return nil }
    return (pid, mirroring ? "com.apple.ScreenContinuity" : "com.apple.dt.Devices")
}
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
        guard target(["41"])?.bundle == "com.apple.dt.Devices",
              target(["--mirroring", "41"])?.bundle == "com.apple.ScreenContinuity",
              target(["--mirroring", "41"])?.pid == 41,
              target(["--bundle", "41"]) == nil,
              target(["--mirroring", "0"]) == nil,
              target(["41", "--mirroring"]) == nil else { fail("Window target routing failed") }
        try emit(["windowOwnerSelfTest": "passed", "windowTargetSelfTest": "passed",
                  "CGWindowListQueries": 0, "AXQueries": 0, "inputSent": false])
        exit(0)
    }
    guard let requested = target(args) else {
        fail("Usage: WindowList [--mirroring] HOST_APP_PID (positive explicit PID required)")
    }
    guard let app = NSRunningApplication(processIdentifier: requested.pid),
          app.bundleIdentifier == requested.bundle else {
        fail("PID does not match the requested host app; no window query performed")
    }
    guard let rows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        fail("Window metadata unavailable; no window IDs inferred")
    }
    var report: [String: Any] = ["hostPID": requested.pid, "bundleIdentifier": requested.bundle,
              "windows": ownedWindows(rows, pid: requested.pid), "CGWindowListQueries": 1,
              "AXQueries": 0, "inputSent": false, "deviceContact": false,
              "scope": "Current host window metadata only; manually review identity and visibility before a separate capture"]
    if requested.bundle == "com.apple.dt.Devices" { report["hubPID"] = requested.pid }
    try emit(report)
} catch {
    fail("Window metadata error: \(error)")
}
