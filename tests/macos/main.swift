import AppKit
import CoreGraphics
import Foundation
import IOKit.hidsystem

func event(_ engine: FilterEngine, _ type: CGEventType, _ key: UInt16,
           flags: CGEventFlags = [], repeated: Bool = false) -> (passed: Bool, flags: CGEventFlags) {
    let input = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: type != .keyUp)!
    input.type = type
    input.flags = flags
    input.setIntegerValueField(.keyboardEventAutorepeat, value: repeated ? 1 : 0)
    return (engine.processKeyEvent(type, event: input), input.flags)
}

var now = 1_000.0
for key: UInt16 in [51, 123] { // Backspace and left arrow
    let engine = FilterEngine(clock: { now })
    precondition(event(engine, .keyDown, key).passed)
    precondition(event(engine, .keyDown, key, repeated: true).passed)
    precondition(event(engine, .keyUp, key).passed)
    now += 30
    precondition(!event(engine, .keyDown, key).passed)
    engine.mode = .advanced
    now += 300
    precondition(!event(engine, .keyDown, key, repeated: true).passed)
    precondition(!event(engine, .keyUp, key).passed)
    precondition(event(engine, .keyDown, key).passed)
    precondition(event(engine, .keyUp, key).passed)
}

for (left, right, aggregate, leftMask, rightMask):
    (UInt16, UInt16, CGEventFlags, Int32, Int32) in [
    (56, 60, .maskShift, NX_DEVICELSHIFTKEYMASK, NX_DEVICERSHIFTKEYMASK),
    (59, 62, .maskControl, NX_DEVICELCTLKEYMASK, NX_DEVICERCTLKEYMASK),
    (58, 61, .maskAlternate, NX_DEVICELALTKEYMASK, NX_DEVICERALTKEYMASK),
    (55, 54, .maskCommand, NX_DEVICELCMDKEYMASK, NX_DEVICERCMDKEYMASK)
] {
    for useSideFlags in [false, true] {
        let engine = FilterEngine(clock: { now })
        let leftSide = CGEventFlags(rawValue: UInt64(leftMask))
        let rightSide = CGEventFlags(rawValue: UInt64(rightMask))
        let leftOnly = useSideFlags ? aggregate.union(leftSide) : aggregate
        let rightOnly = useSideFlags ? aggregate.union(rightSide) : aggregate
        let both = leftOnly.union(rightOnly)
        precondition(event(engine, .flagsChanged, right, flags: rightOnly).passed)
        precondition(event(engine, .flagsChanged, left, flags: both).passed)
        precondition(event(engine, .flagsChanged, left, flags: rightOnly).passed)
        now += 20
        precondition(!event(engine, .flagsChanged, left, flags: both).passed)
        let forwarded = event(engine, .keyDown, 0, flags: both)
        precondition(forwarded.passed && forwarded.flags == rightOnly)
        let releasedRight = event(engine, .flagsChanged, right, flags: leftOnly)
        precondition(releasedRight.passed && !releasedRight.flags.contains(aggregate))
        precondition(!event(engine, .flagsChanged, left).passed)
    }
}

for (gap, expected) in [(34.0, 1), (35.0, 1), (36.0, 0)] {
    let engine = FilterEngine(clock: { now })
    engine.mode = .autoLearn
    precondition(event(engine, .keyDown, 0).passed)
    now += 10
    precondition(event(engine, .keyUp, 0).passed)
    now += gap
    precondition(event(engine, .keyDown, 0).passed)
    precondition(engine.autoStats[0].anomalyHits == expected)
}

let suite = "keyboard-filter-regression.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
defaults.set(20, forKey: "pressRate")
defaults.set(FilterMode.advanced.rawValue, forKey: "mode")
let secondInstance = SettingsStore(defaults: defaults)
secondInstance.persistNow()
precondition(defaults.integer(forKey: "pressRate") == 20)
precondition(defaults.integer(forKey: "mode") == FilterMode.advanced.rawValue)
secondInstance.load()
secondInstance.pressRate = 5
secondInstance.persistNow()
precondition(defaults.integer(forKey: "pressRate") == 5)

let directory = FileManager.default.temporaryDirectory.appendingPathComponent("keyboard-filter-test.\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: directory) }
let plist = directory.appendingPathComponent("agent.plist")
let domain = "gui/123"
var loaded = false
var bootstrapFails = false
var bootoutFails = false
var bootstrapCount = 0
var rejectedPath: String?
func run(_ args: [String]) -> Int32 {
    switch args[0] {
    case "print": return args[1] == domain || loaded ? 0 : 1
    case "bootstrap":
        bootstrapCount += 1
        if bootstrapFails { return 5 }
        if let rejectedPath = rejectedPath,
           let data = FileManager.default.contents(atPath: args[2]),
           let xml = String(data: data, encoding: .utf8), xml.contains(rejectedPath) { return 5 }
        loaded = true
        return 0
    case "bootout":
        if bootoutFails { return 5 }
        loaded = false
        return 0
    default: fatalError("unexpected launchctl command")
    }
}

func setAutostart(_ enable: Bool) throws {
    try AutoStartManager.apply(enabled: enable, plist: plist, domain: domain,
                              executablePath: "/test/Keyboard Filter", run: run)
}

bootstrapFails = true
do {
    try setAutostart(true)
    fatalError("bootstrap should fail")
} catch {
    precondition(!FileManager.default.fileExists(atPath: plist.path) && !loaded)
}
bootstrapFails = false
try setAutostart(true)
try setAutostart(true)
precondition(loaded && bootstrapCount == 2 && FileManager.default.fileExists(atPath: plist.path))
let installed = try Data(contentsOf: plist)
rejectedPath = "/test/Replacement"
do {
    try AutoStartManager.apply(enabled: true, plist: plist, domain: domain,
                              executablePath: rejectedPath, run: run)
    fatalError("replacement bootstrap should fail")
} catch {
    let restored = try Data(contentsOf: plist)
    precondition(loaded && restored == installed)
}
bootoutFails = true
do {
    try setAutostart(false)
    fatalError("bootout should fail")
} catch {
    precondition(loaded && FileManager.default.fileExists(atPath: plist.path))
}
bootoutFails = false
try setAutostart(false)
try setAutostart(false)
precondition(!loaded && !FileManager.default.fileExists(atPath: plist.path))

print("PASS macOS event pairing, modifiers, learning boundary, settings and autostart")
