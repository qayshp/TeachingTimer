// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
import AppKit
import ApplicationServices

// Internal helper for the Simulator-only Python runner. Uses current AX bounds,
// never saved desktop coordinates. Unsupported UI hierarchy fails closed.
let args = CommandLine.arguments
func fail(_ message: String) -> Never { fputs(message + "\n", stderr); exit(2) }
guard args.count >= 4, let pid = pid_t(args[1]), pid > 0, AXIsProcessTrusted() else { fail("PID, simulator ID, action and Accessibility access required") }
let app = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(app, 2)
func attr(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
    var result: CFTypeRef?; AXUIElementCopyAttributeValue(e, key as CFString, &result); return result
}
func text(_ e: AXUIElement, _ key: String) -> String { attr(e,key) as? String ?? "" }
func children(_ e: AXUIElement) -> [AXUIElement] { attr(e,kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func find(_ e: AXUIElement, depth: Int = 0, where predicate: (AXUIElement) -> Bool) -> AXUIElement? {
    guard depth < 20 else { return nil }
    if predicate(e) { return e }
    for child in children(e) { if let match = find(child, depth: depth + 1, where: predicate) { return match } }
    return nil
}
guard let window = (attr(app,kAXWindowsAttribute) as? [AXUIElement])?.first else { fail("Device Hub window unavailable") }
let targetID = "TableRow.Device." + args[2]
guard let row = find(window, where: { text($0,kAXRoleAttribute) == "AXRow" && find($0, where: { text($0,kAXIdentifierAttribute) == targetID }) != nil }) else { fail("Simulator row not found") }
guard AXUIElementSetAttributeValue(row,kAXSelectedAttribute as CFString,kCFBooleanTrue) == .success else { fail("Cannot select simulator") }
AXUIElementSetAttributeValue(app,kAXFrontmostAttribute as CFString,kCFBooleanTrue)
AXUIElementPerformAction(window,kAXRaiseAction as CFString)
Thread.sleep(forTimeInterval: 0.3)
func press(_ e: AXUIElement) { guard AXUIElementPerformAction(e,kAXPressAction as CFString) == .success else { fail("AX press failed") } }
let action = args[3]
if action == "home" {
    guard let home = find(window, where: { text($0,kAXIdentifierAttribute) == "digitalcrown.press" }) else { fail("Home unavailable") }
    press(home); exit(0)
}
if action == "lock" {
    guard let bar = attr(app,kAXMenuBarAttribute), let menu = find(bar as! AXUIElement, where: { text($0,kAXRoleAttribute) == "AXMenuItem" && text($0,kAXTitleAttribute) == "Lock" }) else { fail("Controls Lock unavailable") }
    press(menu); exit(0)
}
func frame(_ e: AXUIElement) -> CGRect? {
    guard let position=attr(e,kAXPositionAttribute), let size=attr(e,kAXSizeAttribute) else { return nil }
    var p=CGPoint.zero; var s=CGSize.zero
    guard AXValueGetValue(position as! AXValue,.cgPoint,&p), AXValueGetValue(size as! AXValue,.cgSize,&s) else { return nil }
    return CGRect(origin:p,size:s)
}
guard let host = find(window, where: { children($0).contains { text($0,kAXIdentifierAttribute) == "digitalcrown.press" } }) else { fail("Watch display host unavailable") }
let candidates = children(host).filter { text($0,kAXRoleAttribute) == "AXGroup" }.compactMap(frame).filter { $0.width > 100 && $0.height > 100 && (0.7...0.95).contains($0.width/$0.height) }
guard let display = candidates.first, candidates.allSatisfy({ $0 == display }) else { fail("Ambiguous Watch display bounds") }
if action == "bounds" { print("\(display.minX) \(display.minY) \(display.width) \(display.height)"); exit(0) }
func post(_ e: CGEvent?) { e?.flags=[]; e?.post(tap:.cghidEventTap) }
func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x:display.minX + display.width*x,y:display.minY + display.height*y) }
func mouse(_ kind: CGEventType, _ p: CGPoint) { post(CGEvent(mouseEventSource:nil,mouseType:kind,mouseCursorPosition:p,mouseButton:.left)) }
if action == "crown" {
    guard args.count == 5, let amount=Int32(args[4]), abs(amount) <= 100 else { fail("Crown amount required, -100…100") }
    let p=point(1.055,0.28)
    mouse(.mouseMoved,p)
    let event=CGEvent(scrollWheelEvent2Source:nil,units:.line,wheelCount:1,wheel1:amount,wheel2:0,wheel3:0)
    event?.location=p; post(event); exit(0)
}
let numbers=args.dropFirst(4).compactMap(Double.init)
guard numbers.count == args.count-4, numbers.allSatisfy({ (0...1).contains($0) }) else { fail("Use normalized display coordinates 0…1") }
if action == "tap", numbers.count == 2 {
    let p=point(numbers[0],numbers[1]); mouse(.leftMouseDown,p); Thread.sleep(forTimeInterval:0.08); mouse(.leftMouseUp,p)
} else if ["swipe", "scroll"].contains(action), numbers.count == 4 {
    let from=point(numbers[0],numbers[1]), to=point(numbers[2],numbers[3]); mouse(.leftMouseDown,from)
    for i in 1...20 {
        let t=Double(i)/20; mouse(.leftMouseDragged,CGPoint(x:from.x+(to.x-from.x)*t,y:from.y+(to.y-from.y)*t)); Thread.sleep(forTimeInterval: action == "scroll" ? 0.04 : 0.015)
    }
    if action == "scroll" { Thread.sleep(forTimeInterval: 0.2) }
    mouse(.leftMouseUp,to)
} else { fail("Unknown action") }
