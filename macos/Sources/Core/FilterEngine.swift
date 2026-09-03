import Cocoa
import Combine
import CoreGraphics
import Foundation
import QuartzCore

let kLearnBounceMs: Double = 35
let kAutoAnomalyToAdd = 5
let kAutoCleanStreakToRemove = 120
let kAutoAnomalyDecayEvery = 20
let kKeyCount = 128
let kRepeatIgnoreMs: Double = 180
let kKeyUpLostMs: Double = 500

struct KeyInfo {
    var lastPressMs: Double = 0
    var isBlocked = false
}

struct AutoKeyStats {
    var rawLastMs: Double = 0
    var downStartedMs: Double = 0
    var hasRaw = false
    var isDown = false
    var anomalyHits = 0
    var cleanStreak = 0
}

/// 热路径固定数组、无堆分配；算法对齐 Windows v2.5.4。
final class FilterEngine: ObservableObject {
    static let shared = FilterEngine()

    var mode: FilterMode = .quickAll
    var minIntervalMs: Double = 100
    var targetMask = [Bool](repeating: false, count: kKeyCount)
    var autoMask = [Bool](repeating: false, count: kKeyCount)
    var keyStates = [KeyInfo](repeating: KeyInfo(), count: kKeyCount)
    var autoStats = [AutoKeyStats](repeating: AutoKeyStats(), count: kKeyCount)
    var autoKeys = Set<Int>()
    var eventTap: CFMachPort?
    var onAutoKeysChanged: (() -> Void)?

    /// SwiftUI 观察自动名单变化。
    @Published private(set) var autoRevision: UInt64 = 0

    fileprivate var modifierDown = [Bool](repeating: false, count: kKeyCount)
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    func loadFromSettings(_ store: SettingsStore = .shared) {
        mode = store.mode
        setPressRate(store.pressRate, persist: false)
        autoKeys = store.autoKeys
        syncMasks(targetKeys: store.targetKeys)
    }

    func syncMasks(targetKeys: Set<Int> = SettingsStore.shared.targetKeys) {
        targetMask = [Bool](repeating: false, count: kKeyCount)
        autoMask = [Bool](repeating: false, count: kKeyCount)
        for key in targetKeys where key >= 0 && key < kKeyCount {
            targetMask[key] = true
        }
        for key in autoKeys where key >= 0 && key < kKeyCount {
            autoMask[key] = true
        }
    }

    func setPressRate(_ rate: Int, persist: Bool = true) {
        let clamped = SettingsStore.shared.clampPressRate(rate)
        SettingsStore.shared.pressRate = clamped
        minIntervalMs = 1000.0 / Double(clamped)
        if persist {
            SettingsStore.shared.requestDeferredSave()
        }
    }

    func setMode(_ newMode: FilterMode) {
        mode = newMode
        SettingsStore.shared.mode = newMode
        SettingsStore.shared.requestDeferredSave()
    }

    private func nowMs() -> Double {
        CACurrentMediaTime() * 1000
    }

    /// 返回 true 表示该次按下应被拦截。
    func applyDebounce(_ key: Int) -> Bool {
        guard key >= 0 && key < kKeyCount else { return false }
        let now = nowMs()
        if keyStates[key].isBlocked {
            if now - keyStates[key].lastPressMs < minIntervalMs { return true }
            keyStates[key].isBlocked = false
        }
        keyStates[key].lastPressMs = now
        keyStates[key].isBlocked = true
        return false
    }

    func analyzeRawKeyDown(_ key: Int) {
        guard key >= 0 && key < kKeyCount else { return }
        let now = nowMs()
        var listChanged = false

        func tryAdd() {
            if !autoMask[key] && autoStats[key].anomalyHits >= kAutoAnomalyToAdd {
                autoKeys.insert(key)
                autoMask[key] = true
                keyStates[key].lastPressMs = now
                keyStates[key].isBlocked = true
                listChanged = true
            }
        }

        func tryRemove() {
            if autoMask[key] && autoStats[key].cleanStreak >= kAutoCleanStreakToRemove {
                autoKeys.remove(key)
                autoMask[key] = false
                autoStats[key] = AutoKeyStats()
                keyStates[key] = KeyInfo()
                listChanged = true
            }
        }

        if autoStats[key].isDown {
            let sinceLast = now - autoStats[key].rawLastMs
            if sinceLast > kKeyUpLostMs {
                autoStats[key].isDown = false
            } else {
                let sinceDown = now - autoStats[key].downStartedMs
                autoStats[key].rawLastMs = now
                if sinceDown >= kRepeatIgnoreMs {
                    return
                }
                if sinceLast < kLearnBounceMs {
                    autoStats[key].anomalyHits += 1
                    autoStats[key].cleanStreak = 0
                    tryAdd()
                }
                if listChanged { persistAutoKeys() }
                return
            }
        }

        let dt = autoStats[key].hasRaw ? (now - autoStats[key].rawLastMs) : 1_000_000
        autoStats[key].isDown = true
        autoStats[key].downStartedMs = now
        autoStats[key].rawLastMs = now
        autoStats[key].hasRaw = true

        if dt < kLearnBounceMs {
            autoStats[key].anomalyHits += 1
            autoStats[key].cleanStreak = 0
            tryAdd()
        } else {
            autoStats[key].cleanStreak += 1
            if autoStats[key].cleanStreak % kAutoAnomalyDecayEvery == 0 && autoStats[key].anomalyHits > 0 {
                autoStats[key].anomalyHits -= 1
            }
            tryRemove()
        }
        if listChanged { persistAutoKeys() }
    }

    func analyzeRawKeyUp(_ key: Int) {
        guard key >= 0 && key < kKeyCount else { return }
        autoStats[key].isDown = false
        autoStats[key].rawLastMs = nowMs()
    }

    func toggleAutoKey(_ key: Int) {
        guard key >= 0 && key < kKeyCount else { return }
        if autoKeys.contains(key) {
            autoKeys.remove(key)
            autoMask[key] = false
            autoStats[key] = AutoKeyStats()
            keyStates[key] = KeyInfo()
        } else {
            autoKeys.insert(key)
            autoMask[key] = true
        }
        persistAutoKeys()
    }

    func clearAutoKeys() {
        autoKeys.removeAll()
        autoMask = [Bool](repeating: false, count: kKeyCount)
        autoStats = [AutoKeyStats](repeating: AutoKeyStats(), count: kKeyCount)
        keyStates = [KeyInfo](repeating: KeyInfo(), count: kKeyCount)
        persistAutoKeys()
    }

    private func persistAutoKeys() {
        SettingsStore.shared.autoKeys = autoKeys
        SettingsStore.shared.requestDeferredSave()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.autoRevision &+= 1
            self.onAutoKeysChanged?()
        }
    }

    func statusText() -> String {
        switch mode {
        case .quickAll:
            return "全盘"
        case .advanced:
            return "手动(\(SettingsStore.shared.targetKeys.count))"
        case .autoLearn:
            return "自动(\(autoKeys.count))"
        }
    }

    func shouldBlockKeyDown(key: Int) -> Bool {
        switch mode {
        case .quickAll:
            return applyDebounce(key)
        case .advanced:
            return key < kKeyCount && targetMask[key] && applyDebounce(key)
        case .autoLearn:
            analyzeRawKeyDown(key)
            return key < kKeyCount && autoMask[key] && applyDebounce(key)
        }
    }

    @discardableResult
    func installTap() -> Bool {
        removeTap()
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: nil
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func reenableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func removeTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func modifierIsDown(key: Int, flags: CGEventFlags) -> Bool {
        switch key {
        case 56, 60:
            return flags.contains(.maskShift)
        case 59, 62:
            return flags.contains(.maskControl)
        case 58, 61:
            return flags.contains(.maskAlternate)
        case 55, 54:
            return flags.contains(.maskCommand)
        case 63:
            return flags.contains(.maskSecondaryFn)
        default:
            return false
        }
    }
}

func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let engine = FilterEngine.shared
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        engine.reenableTap()
        return Unmanaged.passUnretained(event)
    }

    let key = Int(event.getIntegerValueField(.keyboardEventKeycode))

    if type == .flagsChanged {
        let down = engine.modifierIsDown(key: key, flags: event.flags)
        let wasDown = (key >= 0 && key < kKeyCount) ? engine.modifierDown[key] : false
        if key >= 0 && key < kKeyCount {
            engine.modifierDown[key] = down
        }
        if down && !wasDown {
            if engine.shouldBlockKeyDown(key: key) { return nil }
        } else if !down && wasDown {
            if engine.mode == .autoLearn { engine.analyzeRawKeyUp(key) }
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .keyUp {
        if engine.mode == .autoLearn { engine.analyzeRawKeyUp(key) }
        return Unmanaged.passUnretained(event)
    }
    guard type == .keyDown else { return Unmanaged.passUnretained(event) }

    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    if isRepeat { return Unmanaged.passUnretained(event) }

    if engine.shouldBlockKeyDown(key: key) { return nil }
    return Unmanaged.passUnretained(event)
}
