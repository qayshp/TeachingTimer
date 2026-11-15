// SPDX-License-Identifier: MPL-2.0
// One reviewed Device Hub action at a time. Never opens a developer connection.
import AppKit
import ApplicationServices

enum ControlError: Error { case invalid(String) }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw ControlError.invalid(message) }
}
// Device Hub repeats a device identifier on its icon and several text siblings.
// Resolve the unique owning row, not the number of matching descendants.
func owningRows(_ nodes: [([Int], String, String)], identifier: String) throws -> Set<[Int]> {
    var result = Set<[Int]>()
    for (path, _, id) in nodes where id == identifier {
        var prefix = path
        while !nodes.contains(where: { $0.0 == prefix && $0.1 == "AXRow" }) && !prefix.isEmpty { prefix.removeLast() }
        try require(nodes.contains { $0.0 == prefix && $0.1 == "AXRow" }, "Device identifier has no owning row")
        result.insert(prefix)
    }
    return result
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
    let displayCrop: [Double]?
    let reviewedAnchorFrame: [Double]?
    let reviewedAtUnix: Double?
    let crownPoint: [Double]?
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
        if let crop = r.displayCrop {
            try require(crop.count == 4 && crop.allSatisfy { $0.isFinite && (0...1).contains($0) } && crop[2] > 0 && crop[3] > 0 && crop[0] + crop[2] <= 1 && crop[1] + crop[3] <= 1, "Invalid reviewed display crop")
            try require(r.reviewedAnchorFrame?.count == 4 && r.reviewedAnchorFrame!.allSatisfy { $0.isFinite } && r.reviewedAtUnix?.isFinite == true, "Crop requires its screenshot-reviewed anchor frame and time")
        }
        if let point = r.crownPoint {
            try require(r.action == "crown" && r.displayCrop != nil && point.count == 2 && point.allSatisfy { $0.isFinite && (0...1).contains($0) }, "Crown point requires a reviewed crop")
        }
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
    var result = root?["result"] as? [String: Any]
    if let devices = result?["devices"] as? [[String: Any]] {
        let matches = devices.filter { device in
            let hardware = device["hardwareProperties"] as? [String: Any]
            return [device["identifier"] as? String, hardware?["udid"] as? String].compactMap { $0 }.contains { r.rowIdentifier == "TableRow.Device." + $0 }
        }
        try require(matches.count == 1, "Inventory must identify exactly one requested device")
        result = matches[0]
    }
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
// Pure geometry shared by execution and offline regression checks. Selection,
// live screen content and native input ownership remain separate observations.
func reviewedDisplayBounds(_ r: Request, anchor: CGRect, window: CGRect, at now: Double) throws -> CGRect {
    var bounds = anchor
    if let crop = r.displayCrop {
        let expected = r.reviewedAnchorFrame!
        try require(zip([anchor.minX, anchor.minY, anchor.width, anchor.height], expected).allSatisfy { abs($0 - $1) < 0.5 }, "Reviewed canvas moved or resized; inspect screenshot again")
        try require((0...180).contains(now - r.reviewedAtUnix!), "Screenshot review is stale")
        bounds = CGRect(x: anchor.minX + anchor.width * crop[0], y: anchor.minY + anchor.height * crop[1], width: anchor.width * crop[2], height: anchor.height * crop[3])
    }
    let aspect = bounds.width / bounds.height
    try require(bounds.width >= 100 && bounds.height >= 100 && window.contains(bounds) && (r.kind == "watch" ? (0.7...0.95).contains(aspect) : (0.4...0.55).contains(aspect)), "Reviewed display geometry is unsuitable")
    return bounds
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
    let rows = try owningRows(before.map { ($0.1, text($0.0, kAXRoleAttribute), text($0.0, kAXIdentifierAttribute)) }, identifier: r.rowIdentifier)
    try require(rows.count == 1, "Exact physical-device row not uniquely present")
    let row = try atPath(window, rows.first!)
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
        guard let anchor = frame(display), let windowBounds = frame(window) else { throw ControlError.invalid("Display bounds unavailable") }
        let bounds = try reviewedDisplayBounds(r, anchor: anchor, window: windowBounds, at: Date().timeIntervalSince1970)
        func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: bounds.minX + bounds.width * x, y: bounds.minY + bounds.height * y) }
        func mouse(_ kind: CGEventType, _ p: CGPoint) throws {
            guard let event = CGEvent(mouseEventSource: nil, mouseType: kind, mouseCursorPosition: p, mouseButton: .left) else { throw ControlError.invalid("Cannot create input") }
            event.flags = []; event.post(tap: .cghidEventTap)
        }
        if r.action == "crown" {
            let crowns = nodes.filter { text($0.0, kAXIdentifierAttribute) == "digitalcrown.press" }
            try require(crowns.count == 1, "Crown control unavailable")
            guard let crown = frame(crowns[0].0), let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: r.scrollUnits!, wheel2: 0, wheel3: 0) else { throw ControlError.invalid("Crown input unavailable") }
            let p = r.crownPoint.map { CGPoint(x: anchor.minX + anchor.width * $0[0], y: anchor.minY + anchor.height * $0[1]) } ?? CGPoint(x: crown.midX, y: crown.midY)
            try require(windowBounds.contains(p) && !bounds.contains(p), "Crown geometry is ambiguous")
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
    if args == ["--self-test"] {
        let siblings: [([Int], String, String)] = [([0], "AXRow", ""), ([0, 0], "AXImage", "target"), ([0, 1], "AXStaticText", "target"), ([0, 2], "AXStaticText", "target"), ([0, 3], "AXStaticText", "target")]
        try require(try owningRows(siblings, identifier: "target") == Set([[0]]), "Sibling row coalescing failed")
        try require(try owningRows(siblings + [([1], "AXRow", ""), ([1, 0], "AXImage", "target")], identifier: "target").count == 2, "Ambiguous rows were not retained")
        try require(try owningRows(siblings, identifier: "absent").isEmpty, "Absent identifier matched")
        var orphanRejected = false
        do { _ = try owningRows([([0], "AXGroup", ""), ([0, 0], "AXImage", "target")], identifier: "target") }
        catch { orphanRejected = true }
        try require(orphanRejected, "Identifier without an owning row was accepted")

        let base: [String: Any] = ["hubPID": 1, "deviceDetailsFile": "unused-offline",
            "rowIdentifier": "TableRow.Device.synthetic", "kind": "watch", "action": "tap",
            "displayPath": [0], "displayRole": "AXGroup", "displayIdentifier": "",
            "displayCrop": [0.1, 0.1, 0.4, 0.67], "reviewedAnchorFrame": [100, 200, 800, 600],
            "reviewedAtUnix": 900, "coordinates": [0.5, 0.5]]
        let originalAnchor = CGRect(x: 100, y: 200, width: 800, height: 600)
        let originalWindow = CGRect(x: 0, y: 0, width: 1400, height: 1100)
        var geometryCases = 0
        func checkGeometry(_ label: String, changes: [String: Any] = [:], anchor: CGRect? = nil,
                           window: CGRect? = nil, now: Double = 1000, shouldPass: Bool) throws {
            let value = base.merging(changes) { _, new in new }
            let request = try JSONDecoder().decode(Request.self, from: JSONSerialization.data(withJSONObject: value))
            try validate(request)
            let accepted: Bool
            do { _ = try reviewedDisplayBounds(request, anchor: anchor ?? originalAnchor, window: window ?? originalWindow, at: now); accepted = true }
            catch { accepted = false }
            try require(accepted == shouldPass, "Geometry guard mismatch: " + label)
            geometryCases += 1
        }
        try checkGeometry("valid Watch crop", shouldPass: true)
        try checkGeometry("valid phone crop", changes: ["kind": "phone", "displayCrop": [0.1, 0.1, 0.225, 0.65]], shouldPass: true)
        try checkGeometry("sub-tolerance move", anchor: originalAnchor.offsetBy(dx: 0.49, dy: 0), shouldPass: true)
        try checkGeometry("tolerance boundary", anchor: originalAnchor.offsetBy(dx: 0.5, dy: 0), shouldPass: false)
        try checkGeometry("resized canvas", anchor: CGRect(x: 100, y: 200, width: 801, height: 600), shouldPass: false)
        try checkGeometry("179-second review", now: 1079, shouldPass: true)
        try checkGeometry("180-second boundary", now: 1080, shouldPass: true)
        try checkGeometry("181-second review", now: 1081, shouldPass: false)
        try checkGeometry("future review", now: 899, shouldPass: false)
        try checkGeometry("outside window", window: CGRect(x: 0, y: 0, width: 250, height: 250), shouldPass: false)
        try checkGeometry("invalid Watch aspect", changes: ["displayCrop": [0.1, 0.1, 0.7, 0.3]], shouldPass: false)
        try checkGeometry("invalid phone aspect", changes: ["kind": "phone"], shouldPass: false)
        try checkGeometry("undersized display", changes: ["displayCrop": [0.1, 0.1, 0.1, 0.15]], shouldPass: false)
        let request = try JSONDecoder().decode(Request.self, from: JSONSerialization.data(withJSONObject: base))
        let bounds = try reviewedDisplayBounds(request, anchor: originalAnchor, window: originalWindow, at: 1000)
        try require(abs(bounds.minX - 180) < 0.0001 && abs(bounds.minY - 260) < 0.0001 && abs(bounds.width - 320) < 0.0001 && abs(bounds.height - 402) < 0.0001, "Normalized crop projection changed")
        try emit(["rowIdentitySelfTest": "passed", "geometrySelfTest": "passed", "geometryCases": geometryCases, "AXQueries": 0, "inputSent": false]); exit(0)
    }
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
