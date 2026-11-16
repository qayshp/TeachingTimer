// SPDX-License-Identifier: MPL-2.0
// One reviewed host action; plan/self-test paths perform no process/AX/device calls.
import AppKit
import ApplicationServices
import Foundation

struct Request: Decodable {
    let pid: Int32; let bundle: String; let windowID: String; let title: String
    let frame: [Double]; let reviewedAt: Double; let action: String; let points: [Double]; let scroll: Int32?
}
enum InputError: Error { case invalid(String) }
func need(_ condition: Bool, _ message: String) throws {
    if !condition { throw InputError.invalid(message) }
}
func validate(_ r: Request) throws {
    try need(r.pid > 0 && r.frame.count == 4 && r.frame.allSatisfy { $0.isFinite }
             && r.frame[2] > 100 && r.frame[3] > 100 && r.reviewedAt.isFinite, "Invalid PID/reviewed geometry")
    let phone = r.bundle == "com.apple.ScreenContinuity" && r.windowID == "iphone-mirroring-main" && r.title == "iPhone Mirroring"
    let watch = r.bundle == "com.apple.dt.Devices" && r.windowID.hasPrefix("deviceWindow-")
        && r.windowID.count > "deviceWindow-".count && r.title.contains(" – watchOS ")
    try need(phone || watch, "Only exact reviewed Mirroring phone or detached Watch windows are supported")
    try need(["tap", "drag", "crown"].contains(r.action) && r.points.count == (r.action == "drag" ? 4 : 2)
             && r.points.allSatisfy { $0.isFinite && $0 > 0 && $0 < 1 }, "Invalid action/normalized interior points")
    if r.action == "crown" {
        try need(watch && [-3, -2, -1, 1, 2, 3].contains(r.scroll ?? 0), "One bounded Watch Crown scroll required")
    } else { try need(r.scroll == nil, "Scroll is only valid for Crown input") }
}
// Pure checks used by execution and offline tests. windowID is AX, not a CG capture ID.
func exactWindow(_ ids: [(String, String)], request: Request) throws -> Int {
    let matches = ids.indices.filter { ids[$0].0 == request.windowID && ids[$0].1 == request.title }
    try need(matches.count == 1, "Exact window identity missing or ambiguous"); return matches[0]
}
func reviewedFrame(_ current: [Double], request: Request, now: Double) throws -> CGRect {
    try need(now.isFinite && (0...180).contains(now - request.reviewedAt), "Review expired or from the future")
    try need(current.count == 4 && current.allSatisfy { $0.isFinite }
             && zip(current, request.frame).allSatisfy { abs($0 - $1) < 0.5 }, "Window moved; review again")
    return CGRect(x: current[0], y: current[1], width: current[2], height: current[3])
}
func point(_ r: Request, _ offset: Int, _ frame: CGRect) -> CGPoint {
    CGPoint(x: frame.minX + r.points[offset] * frame.width, y: frame.minY + r.points[offset + 1] * frame.height)
}
func maySkipRaise(frontmostPID: Int32?, targetPID: Int32, exactFocusedWindow: Bool) -> Bool {
    targetPID > 0 && frontmostPID == targetPID && exactFocusedWindow
}
func emit(_ value: [String: Any]) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data); print("")
}
func attr(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?; AXUIElementCopyAttributeValue(e, key as CFString, &value); return value
}
func frame(_ e: AXUIElement) -> [Double]? {
    guard let p = attr(e, kAXPositionAttribute), let s = attr(e, kAXSizeAttribute),
          CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var origin = CGPoint.zero; var size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &origin), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
    return [origin.x, origin.y, size.width, size.height]
}
var inputMayHaveBeenSent = false
func execute(_ r: Request) throws {
    _ = try reviewedFrame(r.frame, request: r, now: Date().timeIntervalSince1970)
    let session = CGSessionCopyCurrentDictionary() as? [String: Any]
    try need(session?[kCGSessionOnConsoleKey as String] as? Bool == true
             && session?["CGSSessionScreenIsLocked"] as? Bool != true, "Mac must be locally unlocked")
    try need(AXIsProcessTrusted(), "Accessibility access required; no permission prompt opened")
    guard let running = NSRunningApplication(processIdentifier: r.pid), running.bundleIdentifier == r.bundle else {
        throw InputError.invalid("Host app PID/bundle changed")
    }
    let app = AXUIElementCreateApplication(r.pid); AXUIElementSetMessagingTimeout(app, 1)
    func target() throws -> AXUIElement {
        guard let windows = attr(app, kAXWindowsAttribute) as? [AXUIElement], windows.count <= 50 else {
            throw InputError.invalid("App windows unavailable or inspection bound exceeded")
        }
        for window in windows {
            try need((attr(window, kAXModalAttribute) as? Bool) != true
                     && (attr(window, kAXSubroleAttribute) as? String) != "AXDialog"
                     && (attr(window, "AXSheets") as? [AXUIElement] ?? []).isEmpty, "App modal/sheet blocks input")
        }
        return windows[try exactWindow(windows.map {
            (attr($0, kAXIdentifierAttribute) as? String ?? "", attr($0, kAXTitleAttribute) as? String ?? "")
        }, request: r)]
    }
    let window = try target()
    try need((attr(window, kAXMinimizedAttribute) as? Bool) != true, "Reviewed window is minimized")
    running.activate()
    Thread.sleep(forTimeInterval: 0.3)
    let initialFocus = attr(app, kAXFocusedWindowAttribute)
    let alreadyFocused = maySkipRaise(frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
        targetPID: r.pid, exactFocusedWindow: initialFocus.map {
            CFGetTypeID($0) == AXUIElementGetTypeID() && CFEqual($0, window)
        } ?? false)
    if !alreadyFocused {
        let raiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        try need(raiseResult == .success, "Cannot raise exact window; AXError rawValue=\(raiseResult.rawValue)")
        Thread.sleep(forTimeInterval: 0.3)
    }
    func recheck() throws -> CGRect {
        let currentWindow = try target()
        guard let focused = attr(app, kAXFocusedWindowAttribute), let current = frame(window) else {
            throw InputError.invalid("Focused window/frame unavailable")
        }
        let bounds = try reviewedFrame(current, request: r, now: Date().timeIntervalSince1970)
        let exactFocusedReview = NSWorkspace.shared.frontmostApplication?.processIdentifier == r.pid
            && CFEqual(currentWindow, window) && CFGetTypeID(focused) == AXUIElementGetTypeID() && CFEqual(focused, window)
        try need(exactFocusedReview, "Exact reviewed window must own foreground focus")
        return bounds
    }
    let bounds = try recheck(); let from = point(r, 0, bounds)
    func mouse(_ type: CGEventType, _ location: CGPoint) throws {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: .left) else {
            throw InputError.invalid("Cannot create input")
        }
        event.flags = []; event.post(tap: .cghidEventTap); inputMayHaveBeenSent = true
    }
    try mouse(.mouseMoved, from); Thread.sleep(forTimeInterval: 0.15); _ = try recheck()
    if r.action == "crown" {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
                                  wheel1: r.scroll!, wheel2: 0, wheel3: 0) else { throw InputError.invalid("Cannot create scroll") }
        event.location = from; event.flags = []; event.post(tap: .cghidEventTap)
    } else {
        var down = false; var released = false; var last = from
        defer { if down && !released { try? mouse(.leftMouseUp, last) } }
        try mouse(.leftMouseDown, from); down = true
        if r.action == "drag" {
            let to = point(r, 2, bounds)
            for step in 1...12 {
                let fraction = Double(step) / 12
                last = CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction)
                try mouse(.leftMouseDragged, last); Thread.sleep(forTimeInterval: 0.025)
            }
        } else { Thread.sleep(forTimeInterval: 0.08) }
        try mouse(.leftMouseUp, last); released = true
    }
    try emit(["inputSent": true, "deviceAPICalls": 0, "raiseSkippedAlreadyFocused": alreadyFocused,
              "timestampUnix": Date().timeIntervalSince1970,
              "delivery": "unverified host submission; confirm device, volume and audible result separately"])
}
func selfTest() throws {
    let r = Request(pid: 7, bundle: "com.apple.ScreenContinuity", windowID: "iphone-mirroring-main",
                    title: "iPhone Mirroring", frame: [100, 200, 400, 800], reviewedAt: 1000,
                    action: "tap", points: [0.25, 0.5], scroll: nil)
    func rejects(_ operation: () throws -> Void) throws {
        do { try operation() } catch InputError.invalid { return }
        throw InputError.invalid("An offline rejection unexpectedly passed")
    }
    for age in [0.0, 179, 180] { _ = try reviewedFrame(r.frame, request: r, now: 1000 + age) }
    for age in [-0.001, 180.001] { try rejects { _ = try reviewedFrame(r.frame, request: r, now: 1000 + age) } }
    for index in 0..<4 {
        var changed = r.frame; changed[index] += 0.49; _ = try reviewedFrame(changed, request: r, now: 1010)
        changed[index] = r.frame[index] + 0.5; try rejects { _ = try reviewedFrame(changed, request: r, now: 1010) }
    }
    try rejects { _ = try reviewedFrame([100, 200, 400], request: r, now: 1010) }
    try rejects { _ = try reviewedFrame([100, .nan, 400, 800], request: r, now: 1010) }
    try rejects { _ = try reviewedFrame(r.frame, request: r, now: .infinity) }
    let match = (r.windowID, r.title)
    let selected = try exactWindow([("other", r.title), match, (r.windowID, "other")], request: r)
    try need(selected == 1, "Exact identity selection failed")
    try rejects { _ = try exactWindow([(r.windowID, "other")], request: r) }
    try rejects { _ = try exactWindow([match, match], request: r) }
    try need(point(r, 0, CGRect(x: -400, y: 200, width: 400, height: 800)) == CGPoint(x: -300, y: 600), "Point projection failed")
    try need(maySkipRaise(frontmostPID: 7, targetPID: 7, exactFocusedWindow: true), "Verified focus did not skip redundant raise")
    for frontmost: Int32? in [7, 8, nil] {
        try need(!maySkipRaise(frontmostPID: frontmost, targetPID: 7, exactFocusedWindow: false), "Other/missing focused window skipped raise")
    }
    try need(!maySkipRaise(frontmostPID: 8, targetPID: 7, exactFocusedWindow: true), "Foreign frontmost app skipped raise")
    try need(!maySkipRaise(frontmostPID: nil, targetPID: 7, exactFocusedWindow: true), "Missing frontmost app skipped raise")
    try need(!maySkipRaise(frontmostPID: 0, targetPID: 0, exactFocusedWindow: true), "Invalid PID skipped raise")
    try emit(["reviewedWindowSelfTest": "passed", "raiseDecisionSelfTest": "passed",
              "AXQueries": 0, "hostProcessLookups": 0, "inputSent": false, "deviceContact": false])
}
do {
    let args = Array(CommandLine.arguments.dropFirst())
    if args == ["--self-test"] { try selfTest(); exit(0) }
    try need(args.count == 1 || (args.count == 2 && args[1] == "--execute"), "Usage: ReviewedWindowInput request.json [--execute]")
    let url = URL(fileURLWithPath: args[0]); let properties = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    try need(properties.isRegularFile == true && (properties.fileSize ?? 65_537) <= 65_536, "Regular JSON file at most 64 KiB required")
    let data = try Data(contentsOf: url); try need(data.count <= 65_536, "Request grew beyond 64 KiB")
    let request = try JSONDecoder().decode(Request.self, from: data); try validate(request)
    if args.count == 1 {
        try emit(["status": "plan_only", "AXQueries": 0, "hostProcessLookups": 0, "inputSent": false, "deviceContact": false])
    } else { try execute(request) }
} catch {
    fputs("Reviewed window input rejected (inputMayHaveBeenSent=\(inputMayHaveBeenSent)): \(error)\n", stderr); exit(2)
}
