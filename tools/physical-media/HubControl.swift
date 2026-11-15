// SPDX-License-Identifier: MPL-2.0
// One reviewed Device Hub action at a time. Never opens a developer connection.
import AppKit
import ApplicationServices

enum ControlError: Error { case invalid(String) }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw ControlError.invalid(message) }
}
struct Request: Decodable {
    let hubPID: Int32
    let deviceDetailsFile: String
    let rowIdentifier: String
    let kind: String
    let action: String
    let displayPath: [Int]?
    let displayRole: String?
    let displayIdentifier: String?
    let coordinates: [Double]?
    let scrollUnits: Int32?
}
func validate(_ r: Request) throws {
    try require(r.hubPID > 0 && ["watch", "phone"].contains(r.kind), "Explicit Hub PID and watch/phone kind required")
    try require(["inspect", "tap", "swipe", "home", "crown"].contains(r.action), "Unsupported action")
    try require(r.rowIdentifier.hasPrefix("TableRow.Device."), "Exact Device Hub row identifier required")
    if ["tap", "swipe", "crown"].contains(r.action) {
        try require(r.displayPath != nil && r.displayPath!.count <= 25 && r.displayPath!.allSatisfy { $0 >= 0 }, "Reviewed display path required")
        try require(r.displayRole == "AXGroup" || r.displayRole == "AXImage", "Reviewed display role required")
        try require(r.displayIdentifier != nil, "Reviewed display identifier required, including empty if absent")
    }
    if ["tap", "swipe"].contains(r.action) {
        let values = r.coordinates ?? []
        try require(values.count == (r.action == "tap" ? 2 : 4) && values.allSatisfy { $0.isFinite && (0...1).contains($0) }, "Use normalized coordinates in 0...1")
    }
    if r.action == "crown" {
        try require(r.kind == "watch" && r.scrollUnits != nil && [-3, -2, -1, 1, 2, 3].contains(r.scrollUnits!), "Watch Crown requires one bounded, nonzero -3...3 scroll request")
    }
}
func physicalIdentity(_ r: Request, fresh: Bool) throws -> String {
    let url = URL(fileURLWithPath: r.deviceDetailsFile)
    let data = try Data(contentsOf: url)
    try require(data.count < 2_000_000, "Details receipt too large")
    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let info = root?["info"] as? [String: Any]
    let result = root?["result"] as? [String: Any]
    let hardware = result?["hardwareProperties"] as? [String: Any]
    try require(info?["outcome"] as? String == "success" && hardware?["reality"] as? String == "physical", "A successful physical-device details receipt is required")
    try require(hardware?["platform"] as? String == (r.kind == "watch" ? "watchOS" : "iOS"), "Details platform differs from requested device kind")
    let allowed = [result?["identifier"] as? String, hardware?["udid"] as? String].compactMap { $0 }
    try require(allowed.contains { r.rowIdentifier == "TableRow.Device." + $0 }, "Row identifier differs from attested physical device")
    if fresh {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let date = attributes[.modificationDate] as? Date else { throw ControlError.invalid("Details receipt has no modification date") }
        let age = Date().timeIntervalSince(date)
        try require((0...300).contains(age), "Collect a fresh details receipt after device authorization; stale receipts are not a live connection check")
    }
    return (result?["deviceProperties"] as? [String: Any])?["name"] as? String ?? "physical device"
}
func emit(_ value: [String: Any]) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data); print("")
}
func attr(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
    var result: CFTypeRef?
    AXUIElementCopyAttributeValue(e, key as CFString, &result)
    return result
}
func text(_ e: AXUIElement, _ key: String) -> String { attr(e, key) as? String ?? "" }
func children(_ e: AXUIElement) -> [AXUIElement] { attr(e, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func frame(_ e: AXUIElement) -> CGRect? {
    guard let position = attr(e, kAXPositionAttribute), let size = attr(e, kAXSizeAttribute),
          CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
    var p = CGPoint.zero; var s = CGSize.zero
    guard AXValueGetValue(position as! AXValue, .cgPoint, &p), AXValueGetValue(size as! AXValue, .cgSize, &s) else { return nil }
    return CGRect(origin: p, size: s)
}
func tree(_ e: AXUIElement, path: [Int] = [], deadline: Date, nodes: inout [(AXUIElement, [Int])]) throws {
    try require(Date() < deadline && nodes.count < 2500, "Accessibility inspection exceeded its bound")
    nodes.append((e, path))
    guard path.count < 25 else { return }
    for (i, child) in children(e).enumerated() { try tree(child, path: path + [i], deadline: deadline, nodes: &nodes) }
}
func press(_ e: AXUIElement) throws {
    try require((attr(e, kAXEnabledAttribute) as? Bool) != false, "Control is disabled")
    try require(AXUIElementPerformAction(e, kAXPressAction as CFString) == .success, "AX press failed")
}
func atPath(_ window: AXUIElement, _ path: [Int]) throws -> AXUIElement {
    var node = window
    for index in path {
        let list = children(node)
        try require(list.indices.contains(index), "Reviewed display path changed; inspect again")
        node = list[index]
    }
    return node
}
func execute(_ r: Request, name: String) throws {
    let session = CGSessionCopyCurrentDictionary() as? [String: Any]
    try require(session?[kCGSessionOnConsoleKey as String] as? Bool == true && session?["CGSSessionScreenIsLocked"] as? Bool != true, "Mac must be locally unlocked")
    try require(AXIsProcessTrusted(), "Accessibility access required; no input sent")
    guard let running = NSRunningApplication(processIdentifier: r.hubPID) else { throw ControlError.invalid("Hub PID no longer exists") }
    try require(running.bundleIdentifier == "com.apple.dt.Devices", "PID is not Device Hub")
    let app = AXUIElementCreateApplication(r.hubPID)
    AXUIElementSetMessagingTimeout(app, 1)
    guard let windows = attr(app, kAXWindowsAttribute) as? [AXUIElement], windows.count == 1 else { throw ControlError.invalid("Exactly one Device Hub window required") }
    let window = windows[0]
    func snapshot() throws -> [(AXUIElement, [Int])] {
        var nodes: [(AXUIElement, [Int])] = []
        try tree(window, deadline: Date().addingTimeInterval(8), nodes: &nodes)
        try require(!nodes.contains { text($0.0, kAXRoleAttribute) == "AXSheet" || text($0.0, kAXRoleAttribute) == "AXDialog" }, "Device Hub modal blocks action")
        return nodes
    }
    let before = try snapshot()
    let matches = before.filter { text($0.0, kAXIdentifierAttribute) == r.rowIdentifier }
    try require(matches.count == 1, "Exact physical-device row not uniquely present")
    // The identifier may be a row descendant. Select its closest AXRow ancestor.
    var rowPath = matches[0].1
    var row = try atPath(window, rowPath)
    while text(row, kAXRoleAttribute) != "AXRow" && !rowPath.isEmpty {
        rowPath.removeLast(); row = try atPath(window, rowPath)
    }
    try require(text(row, kAXRoleAttribute) == "AXRow", "Physical-device row unavailable")
    if r.action == "inspect" {
        try require(AXUIElementSetAttributeValue(row, kAXSelectedAttribute as CFString, kCFBooleanTrue) == .success, "Cannot select the exact physical row")
    } else {
        try require((attr(row, kAXSelectedAttribute) as? Bool) == true, "Inspect and review this target first; input never changes the selected device")
    }
    AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    Thread.sleep(forTimeInterval: 0.8)
    let nodes = try snapshot()
    try require((attr(row, kAXSelectedAttribute) as? Bool) == true && NSWorkspace.shared.frontmostApplication?.processIdentifier == r.hubPID, "Selection or foreground ownership changed")
    try require(!nodes.contains { node, _ in
        [kAXTitleAttribute, kAXValueAttribute].contains { key in
            ["Connecting display…", "Connecting display...", "View Screen"].contains(text(node, key))
        }
    }, "Screen sharing is not ready; inspect/rehearse it before input")
    if r.action == "inspect" {
        try emit(["action": "inspect", "selectedDevice": name, "inputSent": false, "nodes": nodes.map { e, p in
            var value: [String: Any] = ["path": p, "role": text(e, kAXRoleAttribute), "identifier": text(e, kAXIdentifierAttribute)]
            if let f = frame(e) { value["frame"] = [f.minX, f.minY, f.width, f.height] }
            return value
        }]); return
    }
    if r.action == "home" {
        let identifier = r.kind == "watch" ? "digitalcrown.press" : "homebutton.press"
        let homes = nodes.filter { text($0.0, kAXIdentifierAttribute) == identifier }
        try require(homes.count == 1, "Home control unavailable; use reviewed display navigation instead")
        try press(homes[0].0)
    } else {
        let display = try atPath(window, r.displayPath!)
        try require(text(display, kAXRoleAttribute) == r.displayRole! && text(display, kAXIdentifierAttribute) == r.displayIdentifier!, "Display identity changed; inspect again")
        guard let bounds = frame(display), let windowBounds = frame(window) else { throw ControlError.invalid("Display bounds unavailable") }
        let aspect = bounds.width / bounds.height
        try require(bounds.width >= 100 && bounds.height >= 100 && windowBounds.contains(bounds) && (r.kind == "watch" ? (0.7...0.95).contains(aspect) : (0.4...0.55).contains(aspect)), "Reviewed display geometry is unsuitable")
        func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: bounds.minX + bounds.width * x, y: bounds.minY + bounds.height * y) }
        func mouse(_ kind: CGEventType, _ p: CGPoint) throws {
            guard let event = CGEvent(mouseEventSource: nil, mouseType: kind, mouseCursorPosition: p, mouseButton: .left) else { throw ControlError.invalid("Cannot create input") }
            event.flags = []; event.post(tap: .cghidEventTap)
        }
        if r.action == "crown" {
            let crowns = nodes.filter { text($0.0, kAXIdentifierAttribute) == "digitalcrown.press" }
            try require(crowns.count == 1, "Crown control unavailable")
            guard let crown = frame(crowns[0].0), let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: r.scrollUnits!, wheel2: 0, wheel3: 0) else { throw ControlError.invalid("Crown input unavailable") }
            try require(windowBounds.contains(crown) && !bounds.contains(CGPoint(x: crown.midX, y: crown.midY)), "Crown geometry is ambiguous")
            let p = CGPoint(x: crown.midX, y: crown.midY)
            try mouse(.mouseMoved, p); event.location = p; event.flags = []; event.post(tap: .cghidEventTap)
        } else {
            let values = r.coordinates!
            let from = point(values[0], values[1])
            // Always release a submitted mouse-down if creating a later event fails.
            var released = false
            defer {
                if !released { try? mouse(.leftMouseUp, from) }
            }
            try mouse(.mouseMoved, from); try mouse(.leftMouseDown, from)
            if r.action == "swipe" {
                let to = point(values[2], values[3])
                for i in 1...12 {
                    let t = Double(i) / 12
                    try mouse(.leftMouseDragged, CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
                    Thread.sleep(forTimeInterval: 0.02)
                }
                try mouse(.leftMouseUp, to)
            } else { Thread.sleep(forTimeInterval: 0.08); try mouse(.leftMouseUp, from) }
            released = true
        }
    }
    try emit(["action": r.action, "selectedDevice": name, "inputSent": true, "delivery": "unverified; inspect device, native request and audible result separately", "timestampUnix": Date().timeIntervalSince1970])
}
do {
    let args = Array(CommandLine.arguments.dropFirst())
    try require(args.count == 1 || (args.count == 2 && args[1] == "--execute"), "Usage: HubControl request.json [--execute]")
    let data = try Data(contentsOf: URL(fileURLWithPath: args[0]))
    try require(data.count < 100_000, "Request too large")
    let request = try JSONDecoder().decode(Request.self, from: data)
    try validate(request)
    let executeRequested = args.count == 2
    let name = try physicalIdentity(request, fresh: executeRequested)
    if executeRequested { try execute(request, name: name) }
    else { try emit(["status": "plan_only", "device": name, "action": request.action, "deviceContact": false, "AXQueries": 0, "inputSent": false]) }
} catch {
    fputs("Physical Hub action rejected: \(error)\n", stderr); exit(2)
}
